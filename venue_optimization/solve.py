import os.path
import json
import pandas as pd
from pathlib import Path
from swat import CAS


def solve_for_input(session, input='data/input.csv'):

    maxgroup = 4
    safety = 150.0
    seat_width = 46.0
    seat_depth = 65.0
    maxdist = safety / seat_width
    depth_to_width_ratio = seat_depth / seat_width

    all_seats = pd.read_csv(input, usecols=['row', 'seat_no'])
    all_seats['values'] = all_seats[['row', 'seat_no']].values.tolist()
    def get_seat_name(r):
        return f"L{r['row']:02d}{r['seat_no']:02d}"
    all_seats['seats'] = all_seats.apply(get_seat_name, axis=1)
    rows = all_seats.groupby(['row'])['values'].apply(list).to_dict()

    subsets = {}
    for n in range(1, maxgroup+1):
        groups = []
        for _, vals in rows.items():
            j = [vals[i:] for i in range(n)]
            e = [list(a) for a in zip(*j)]
            f = []
            for i in e:
                seat_name = [f'L{t[0]:02d}{t[1]:02d}' for t in i]
                f.append('n'.join(seat_name))
            groups.extend(f)
        subsets[n] = groups

    all_groups = [i for j in subsets.values() for i in j]

    seats_df = all_seats[['seats']].copy()
    session.upload_frame(seats_df, casout={'name': 'seats', 'replace': True})

    group_df = pd.DataFrame(all_groups, columns=['groups'])
    group_df['ncount'] = group_df['groups'].str.count('n') + 1
    session.upload_frame(group_df, casout={'name': 'groups', 'replace': True})
    
    session.loadactionset('fedSql')
    if session.table.tableexists('seat_groups').exists > 0:
        session.table.droptable('seat_groups')
    session.execdirect("""
        create table seat_groups as
        select S1.seats, S2.groups
        from seats as S1, groups as S2
        where index(groups, seats) > 0;
    """)

    if session.table.tableexists('combination').exists > 0:
        session.table.droptable('combination')
    session.execdirect(query="""
        create table combination as
        select s1.groups as g1, s2.groups as g2
        from (select * from groups) as s1,
             (select * from groups) as s2;
    """)

    session.runcode("""
        data combination;
        set combination;
        if g1 = g2 then delete;
        run;
    """)

    session.runcode(f"""
        data combination;
        set combination;
        dist = 1e+15;
        do i=1 to countw(g1, 'n');
            _g1 = scan(g1, i, 'n');
            _g1_x = input(substr(_g1, 2, 2), 4.);
            _g1_y = input(substr(_g1, 4, 2), 4.);
            do j=1 to countw(g2, 'n');
                _g2 = scan(g2, j, 'n');
                _g2_x = input(substr(_g2, 2, 2), 4.);
                _g2_y = input(substr(_g2, 4, 2), 4.);
                newdist = SQRT( ((_g1_x-_g2_x)*{depth_to_width_ratio})**2 + (_g1_y-_g2_y)**2);
                dist = min(dist, newdist);
            end;
        end;

        if dist > {maxdist} then delete;
        drop _g1 _g2 _g1_x _g1_y _g2_x _g2_y newdist i j;
        run;
    """)

    optmodel_code = """
        set <str> SEATS;
        read data seats into SEATS=[seats];

        set <str> GROUPS;
        num ncount {{GROUPS}};
        read data groups into GROUPS=[groups] ncount;

        set <str, str> SEAT_GROUP;
        read data seat_groups into SEAT_GROUP=[seats groups];
        SEAT_GROUP = {<s,g> in SEAT_GROUP: g in GROUPS};

        set <str, str> GROUP_NEIGHBOR;
        read data combination into GROUP_NEIGHBOR=[g1 g2];

        var x {{GROUPS}} binary;
        
        set CONFLICTS = {<g1,g2> in GROUP_NEIGHBOR: {g1, g2} within GROUPS and g1 < g2} union setof {s in SEATS, <(s),g1> in SEAT_GROUP, <(s),g2> in SEAT_GROUP: g1 < g2} <g1,g2>;

        set <num,str> ID_NODE;
        solve with network / links=(include=CONFLICTS) clique=(maxcliques=all) out=(cliques=ID_NODE);
        set CLIQUES init {};
        set <str> GROUPS_c {CLIQUES} init {};
        for {<c,g> in ID_NODE} do;
            CLIQUES = CLIQUES union {c};
            GROUPS_c[c] = GROUPS_c[c] union {g};
        end;
        con Clique {c in CLIQUES}:
            sum {g in GROUPS_c[c]} x[g] <= 1;

        max total_viewers = sum {i in GROUPS} (x[i] * ncount[i]);
        solve with milp;
        create data solution from [i]={i in GROUPS: x[i].sol > 0.5} var=x[i].name value=x[i].sol;
    """

    session.loadactionset("optimization")
    session.runOptmodel(optmodel_code)

    solutions = session.CASTable('solution').to_frame().copy()

    selected = []
    for _, i in solutions.iterrows():
        group = []
        seats = i['i'].split('n')
        seats = [( int(i[1:3]), int(i[3:5]) ) for i in seats]
        selected.append(seats)
    print(selected)

    e = Path(__file__)
    with open(e.resolve().parent / f'data/output.json', 'w') as f:
        f.write(json.dumps(selected))
    return selected


if __name__ == "__main__":
    with open('.env') as env_file: 
        env_options = json.load(env_file) 
    s = CAS(hostname=env_options['hostname'], port=env_options['port'], username=env_options['username'], password=env_options['password'])
    solve_for_input(s)
