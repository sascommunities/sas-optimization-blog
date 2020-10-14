%let cas_session = myCAS;
%let caslib = casuser;

/* Start cas session */
cas &cas_session.;
caslib _all_ assign;

proc casutil sessref=&cas_session outcaslib=&caslib;
   load data=work.INPUT_SCHOOL_DATA replace;
   load data=work.INPUT_ROOM_DATA replace;
   load data=work.INPUT_BLOCK_DATA replace;
quit;

/* compute the number of grades in a block */ 
    data &caslib.._tmp_grades_in_block / single = yes;
         set &caslib..input_school_data;
         by School_Name population;
         if first.School_Name then do;
           cum_population = population;
           grade_count = 1;
         end;
         else do;
           cum_population + population;
           grade_count+1;
         end; 
         keep School_Name grade population cum_population grade_count;
    run;

    proc fedsql sessref=&cas_session.;
        create table &caslib..output_grades_in_block {options replace=true} as
        select a.School_Name, max(grade_count) as grade_count
        from
        (
        select a.School_Name, a.cum_population, a.grade_count, b.tot_capacity
            from
               (select School_Name, cum_population, grade_count from &caslib.._tmp_grades_in_block)a
               inner join
               (select School_Name, sum(capacity) as tot_capacity from &caslib..input_room_data group by School_Name)b
               on a.School_Name = b.School_Name and a.cum_population <= b.tot_capacity
        )a
        group by a.School_Name
    ;
    quit;

/* defining macro variables */
%let virtual_percent = 0;
%let transition_window = 1;
%let plan_num = 3; /*plan_num=2 : Students in each grade attends full day school , full week, once every n weeks;
       plan_num=3 : Students in each grade attends full day school, n days in a week;
       plan_num=4 : Students in each grade attends n hours a day, everyday; */

 proc cas;
      loadactionset 'optimization';
      run;
      source pgm;

        /*************************************************/
        /* Define sets                                   */
        /*************************************************/
        set <str> ROOMS;
        set <str> GRADES;
        set <num> BLOCKS;

        /*************************************************/
        /* Define inputs                                 */
        /*************************************************/
        str block_id {BLOCKS};
        num duration {BLOCKS};
        num capacity {ROOMS};
        num population {GRADES};

      /*************************************************/
      /* Read data                                     */
      /*************************************************/

        read data &caslib..input_room_data into ROOMS=[roomID] capacity;
        read data &caslib..input_school_data into GRADES=[grade] population; 
        read data &caslib..input_block_data into BLOCKS=[block] block_id duration;

        /*************************************************/
        /* Decision Variables                            */
        /*************************************************/
        var NumStudents {GRADES, ROOMS, BLOCKS} >=0;
        var AssignGrRmBl {GRADES, ROOMS, BLOCKS} binary;
        var AssignGrBl {GRADES, BLOCKS} binary;
        var AssignGrRm {GRADES, ROOMS} binary;
        var AvgNumStudents {GRADES} >=0;
        var ConsecutiveGrBl {GRADES, BLOCKS} binary; 

      /* compute the number of grades in a block and number of blocks for a grade*/ 
      num maxGradesinBlock init card(GRADES);
      num maxBlocksforGrade init card(BLOCKS);

      read data &caslib..output_grades_in_block
         into maxGradesinBlock = grade_count;

      maxBlocksforGrade = ceil(card(BLOCKS) / ceil(card(GRADES) / maxGradesinBlock));

      put maxGradesinBlock;
      put maxBlocksforGrade;

        /*************************************************/
        /* Constraints                                   */
        /*************************************************/
                        /********************  Room Capacity related constraints *******************/                                      
        /*Students assigned to a grade,block,room should not exceed the capacity the room.*/
        con GradeRoomBlockAssignment {g in GRADES, r in ROOMS, b in BLOCKS}:
          NumStudents[g, r, b] <= capacity[r]*AssignGrRmBl[g, r, b];

        /*Room/block assigned to a grade should be less than or equal to 1. - A room can be assigned to a max. of one grade in a time block*/
        con RoomBlockAssignment {r in ROOMS, b in BLOCKS}:
          sum {g in GRADES} AssignGrRmBl[g, r, b] <= 1;

                        /********************  Number of students constraints *******************/                                      
        /* Number of students in a grade, block across all rooms should be equal to the population in that grade */
        con GradePop {g in GRADES, b in BLOCKS}:
          sum {r in ROOMS} NumStudents[g, r, b] = (1 - input(&virtual_percent., best.)/100) * population[g] * AssignGrBl[g, b];

                        /********************  Student Equality constraints ******************** /                                         
        /* Computing average number students attending in a grade */
        con GradeAvg {g in GRADES}:  
          sum {r in ROOMS, b in BLOCKS} NumStudents[g, r, b] / (card(BLOCKS)* population[g] * (1 - input(&virtual_percent., best.)/100)) = AvgNumStudents[g];

        /* Ensuring that the AvgNumStu is same across all grades */
        con AvgNumStu {g1 in GRADES, g2 in GRADES: g1 ~=g2}:
          AvgNumStudents[g1] =  AvgNumStudents[g2];

                      /********************  Deriving Grade-Block and Grade-Room variables constraints ******************** /  
        /*Deducing grade, block assignment from grade,block,room assignment.*/
        con GradeBlockAssignment {g in GRADES, r in ROOMS, b in BLOCKS}:
          AssignGrRmBl[g, r, b] <= AssignGrBl[g, b];

        /*Deducing grade, room assignment from grade,block,room assignment.*/
        con GradeRoomAssignment {g in GRADES, r in ROOMS, b in BLOCKS}:
          AssignGrRmBl[g, r, b] <= AssignGrRm[g, r];

 
              /********************************* Constraints specific to Plan 4 ***********************************/
       /* Constraint that ensures a grade is assigned only to continuous blocks*/
        con ConsFirstBlock {g in GRADES}:
          ConsecutiveGrBl[g, 1] = AssignGrBl[g, 1];

        con ConsPattern {g in GRADES, b in 2..card(BLOCKS)}:
          ConsecutiveGrBl[g, b] >= AssignGrBl[g, b] - AssignGrBl[g, b-1];

        con ConsPatternRes {g in GRADES}:
          sum {b in BLOCKS} ConsecutiveGrBl[g, b] <= 1;

      /* If grade g is assigned to block b-1 and also assigned to block b, force ConsecutiveGrBl[g, b] to be 0. 
         If grade g is not assigned to block b-1 and also not assigned to block b, force ConsecutiveGrBl[g, b] to be 0.
         If grade g is assigned to block b-1 and is not assigned to block b, force ConsecutiveGrBl[g, b] to be 0. */
        con ConsAddCuts {g in GRADES, b in 2..card(BLOCKS)}:
          2 * ConsecutiveGrBl[g, b] <= 1 + AssignGrBl[g, b] - AssignGrBl[g, b-1];

     /* Breaks in between for cleaning */
        con Breakconstraint {g in GRADES, b in (1+&transition_window.) ..card(BLOCKS)}:
            sum {g1 in GRADES} AssignGrBl[g1, (b-&transition_window.)] <= 10000 * (1 - ConsecutiveGrBl[g, b]);

      /* Constraint that ensures students assigned to a room r in a grade g does not change rooms*/
        con NoRoomChanges {g in GRADES, r in ROOMS, b in BLOCKS}:
          AssignGrRmBl[g, r, b] + 1 >= AssignGrBl[g, b] + AssignGrRm[g, r];

        con NoRoomChanges2 {g in GRADES, r in ROOMS, b in BLOCKS}:
          AssignGrRmBl[g, r, b] <= NumStudents[g, r, b];

        /* Bounds on 'blocks in a grade' and 'grades for a block' */
        con MaxBlocksGrade {g in GRADES}:
          sum {b in BLOCKS} AssignGrBl[g, b] <= maxBlocksforGrade;

        con MaxGradeBlock {b in BLOCKS}:
          sum {g in GRADES} AssignGrBl[g, b] <= maxGradesinBlock;

        /* Constrain each of the objective functions to prevent worse solutions */
        num primary_objective_value init 0;

        con PrimaryObjConstraint:
          sum {g in GRADES, r in ROOMS, b in BLOCKS} NumStudents[g, r, b] * duration[b] >= primary_objective_value; 

       /*************************************************/
        /* Objective Functions                           */
        /*************************************************/
        /* Objective function returns the total student hours (weighted by duration of the block) in the classroom */
        max TotalStudentsHours = sum {g in GRADES, r in ROOMS, b in BLOCKS}  
            NumStudents[g, r, b] * duration[b];

        /* adding a small penalty for choosing different rooms or we can have it as another objective */
        min RoomChanges = sum {g in GRADES, r in ROOMS} AssignGrRm[g, r];

    /*************************************************/
    /*                  Solve                        */
    /*************************************************/
if &plan_num. = 2 or &plan_num. = 3 then do;
drop Breakconstraint;
drop ConsFirstBlock;
drop ConsPattern;
drop ConsPatternRes;
drop ConsAddCuts;
drop NoRoomChanges;
drop PrimaryObjConstraint;

for {g in GRADES, b in BLOCKS} AssignGrBl[g, b].priority=3;
for {g in GRADES, r in ROOMS} AssignGrRm[g, r].priority=2;
for {g in GRADES, r in ROOMS, b in BLOCKS} AssignGrRmBl[g, r, b].priority=1;

        solve obj TotalStudentsHours with milp / maxtime=60 loglevel=BASIC relobjgap=0.01 priority=true nodesel=depth
                                               heuristics=none symmetry=none probe=none;  
end;

if &plan_num. = 4 then do;
drop PrimaryObjConstraint;
if &transition_window. = 0 then do;
  drop Breakconstraint; 
  drop NoRoomChanges;
end;

for {g in GRADES, b in BLOCKS} AssignGrBl[g, b].priority=3;
for {g in GRADES, r in ROOMS} AssignGrRm[g, r].priority=2;
for {g in GRADES, r in ROOMS, b in BLOCKS} AssignGrRmBl[g, r, b].priority=1;

        solve obj TotalStudentsHours with milp / maxtime=60 loglevel=NONE relobjgap=0.01 heuristics=none symmetry=none probe=none
                                                 priority=true nodesel=depth
                                                 ;
/* Cleaning step - before primalin */
for {g in GRADES, r in ROOMS, b in BLOCKS} AssignGrRmBl[g, r, b] = round(AssignGrRmBl[g, r, b]);
for {g in GRADES, b in BLOCKS} AssignGrBl[g, b] = round(AssignGrBl[g, b]);
for {g in GRADES, r in ROOMS} AssignGrRm[g, r] = round(AssignGrRm[g, r]);
for {g in GRADES, b in BLOCKS} ConsecutiveGrBl[g, b] = round(ConsecutiveGrBl[g, b]);

    if &transition_window. = 0 then do;
            /* Solve for secondary objective only if primary objective solve was successful */
            if _solution_status_ in {'OPTIMAL', 'OPTIMAL_AGAP', 'OPTIMAL_RGAP', 
                'OPTIMAL_COND', 'CONDITIONAL_OPTIMAL', 'TIME_LIM_SOL'} then
                    do;
                    primary_objective_value=TotalStudentsHours.sol;
                    restore PrimaryObjConstraint;
                    solve obj RoomChanges with milp / primalin maxtime=60 loglevel=NONE relobjgap=0.01;
            end;
    end;
end;

        /*************************************************/
        /* Create output data                            */
        /*************************************************/
        num total_capacity = 6 * sum {r in ROOMS} capacity[r] ;
        num total_population = sum {g in GRADES} population[g] ;
        num StudentHoursDay = (TotalStudentsHours.sol * 6) / card(BLOCKS) ;
        num AvgHoursPerStuWeek = (StudentHoursDay*5) / total_population;
        num totHoursStuWeek = (StudentHoursDay*5);
        num num_blocks_scen = card(BLOCKS);

        num num_students {g in GRADES, r in ROOMS, b in BLOCKS} = round(NumStudents[g,r,b].sol);
        num grade_room_block_assignment {g in GRADES, r in ROOMS, b in BLOCKS} = round(AssignGrRmBl[g,r,b].sol);
        num AssignGrBlSol {g in GRADES, b in BLOCKS} =   round(AssignGrBl[g,b].sol);

        create data &caslib..output_full_assignment from [grade roomID block]={g in 
            GRADES, r in ROOMS, b in BLOCKS} 
            num_students = num_students[g,r,b] 
            grade_room_block_assignment=grade_room_block_assignment[g,r,b]
            AssignGrBl = AssignGrBlSol[g,b]
            block_id[b] 
            duration[b] 
            population[g]
            capacity[r]
            total_capacity
            StudentHoursDay
            AvgHoursPerStuWeek
            num_blocks_scen
            total_population
            totHoursStuWeek;

      endsource;
         runOptmodel / code=pgm groupBy='School_Name' nGroupByTasks='ALL';
      run;
   quit;
