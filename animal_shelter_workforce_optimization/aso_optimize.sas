%let cas_session = myCAS;
%let caslib = casuser;

proc casutil sessref=&cas_session outcaslib=&caslib;
   load data=work.ASO_employees replace;
   load data=work.ASO_jobs replace;
   load data=work.ASO_demand replace;
   load data=work.ASO_demand_coef replace;
quit;

proc cas;
source pgm;

   num first_hour = 9;
   num last_hour = 19;
   set <str> EMPLOYEES;
   set <str> DAYS;
   set <str> JOBS;
   set TIMES={first_hour..last_hour};

   num demand{DAYS, TIMES};
   num demand_coef{JOBS, TIMES};
   num req_skill{JOBS};
   num base_cost init 1;
   num over_cost init 1.5;

   num skill{EMPLOYEES};
   num cost{EMPLOYEES};
   num min_shift{EMPLOYEES};
   num max_shift{EMPLOYEES};
   num min_hour{EMPLOYEES};
   num max_hour{EMPLOYEES};
   num max_volunteer_days{EMPLOYEES};
   str type{EMPLOYEES};
   str off_days{EMPLOYEES};

   read data &caslib..ASO_employees
      into EMPLOYEES=[id] skill type cost off_days max_volunteer_days;

   read data &caslib..ASO_jobs
      into JOBS=[job] req_skill;

   read data &caslib..ASO_demand
      into DAYS=[day] {t in TIMES} <demand[day,t]= col('col'||t)>;

   read data &caslib..ASO_demand_coef
      into [job time] demand_coef;


   set QUALIFIED_JOBS{i in EMPLOYEES} = {j in JOBS: skill[i] >= req_skill[j]};

   set EMPLOYEE_REGULAR_DAYS{i in EMPLOYEES} = DAYS diff {scan(off_days[i],1,'-')} diff {scan(off_days[i],2,'-')};

   set EMPLOYEE_OT_DAYS{i in EMPLOYEES} = if type[i]='Volunteer' then {}
                                          else (if missing(off_days[i]) then DAYS
                                                else DAYS diff EMPLOYEE_REGULAR_DAYS[i]);

   set EMPLOYEE_DAYS{i in EMPLOYEES} = EMPLOYEE_REGULAR_DAYS[i] union EMPLOYEE_OT_DAYS[i];


   for {i in EMPLOYEES} do;
      if type[i] = 'Full-Time' then do;
         min_shift[i] = 5;
         max_shift[i] = 6;
         min_hour[i] = 8;
         max_hour[i] = 10;
      end;
      else if type[i] = 'Part-Time' then do;
         min_shift[i] = 5;
         max_shift[i] = 6;
         min_hour[i] = 4;
         max_hour[i] = 7;
      end;
      else if type[i] = 'Volunteer' then do;
         min_shift[i] = 0;
         max_shift[i] = coalesce(max_volunteer_days[i],3);
         min_hour[i] = 0;
         max_hour[i] = 3;
      end;
   end;

   str next_day{DAYS};
   for {d in DAYS} do;
      if      d = 'Mon' then next_day[d] = 'Tue';
      else if d = 'Tue' then next_day[d] = 'Wed';
      else if d = 'Wed' then next_day[d] = 'Thu';
      else if d = 'Thu' then next_day[d] = 'Fri';
      else if d = 'Fri' then next_day[d] = 'Sat';
      else if d = 'Sat' then next_day[d] = 'Sun';
      else if d = 'Sun' then next_day[d] = 'Mon';
   end;


   /******************************** Variables *******************************/

   var Assign_To_Job {i in EMPLOYEES, QUALIFIED_JOBS[i], TIMES, EMPLOYEE_DAYS[i]} binary;

   var Assign_To_Regular_Day {i in EMPLOYEES, EMPLOYEE_REGULAR_DAYS[i]} binary;
   var Assign_To_Overtime_Day {i in EMPLOYEES, EMPLOYEE_OT_DAYS[i]} binary;

   var Is_Working_Hour {i in EMPLOYEES, TIMES, EMPLOYEE_DAYS[i]} binary;
   var Is_Working_Day {i in EMPLOYEES, EMPLOYEE_DAYS[i]} binary;

   var Two_Days_Off_Start_Day {i in EMPLOYEES, DAYS: missing(off_days[i]) and max_shift[i] > 3} binary;

   var Switch {i in EMPLOYEES, TIMES, EMPLOYEE_DAYS[i]} binary;

   for {i in EMPLOYEES: card(EMPLOYEE_REGULAR_DAYS[i])=min_shift[i]} do;
      for {d in EMPLOYEE_REGULAR_DAYS[i]} do;
         fix Assign_To_Regular_Day[i,d] = 1;
         fix Is_Working_Day[i,d] = 1;
      end;
   end;

   /******************************** Objective *******************************/

   min BaseCost
      = base_cost * sum{i in EMPLOYEES, t in TIMES, d in EMPLOYEE_DAYS[i]} cost[i] * Is_Working_Hour[i,t,d];

   min OverTimeCost
      = (over_cost - base_cost) * sum {i in EMPLOYEES}
                                       cost[i] * (sum {t in TIMES, d in EMPLOYEE_DAYS[i]} Is_Working_Hour[i,t,d]
                                                  - min_shift[i] * min_hour[i]);

   min TotalCost
      = BaseCost + OverTimeCost;


   /****************************** Blocks Setup ******************************/
   num block_id{EMPLOYEES, DAYS};
   num id init 0;
   for {i in EMPLOYEES, d in DAYS} do;
      block_id[i,d] = id;
      id = id + 1;
   end;


   /******************************* Constraints ******************************/

   con Define_Is_Working_Hour {i in EMPLOYEES, t in TIMES, d in EMPLOYEE_DAYS[i]}:
      Is_Working_Hour[i,t,d] = sum{j in QUALIFIED_JOBS[i]} Assign_To_Job[i,j,t,d]
         suffixes=(block=block_id[i,d]);

   con Define_Is_Working_Day {i in EMPLOYEES, d in EMPLOYEE_DAYS[i]}:
      Is_Working_Day[i,d] = (if d in EMPLOYEE_REGULAR_DAYS[i] then Assign_To_Regular_Day[i,d])
                          + (if d in EMPLOYEE_OT_DAYS[i] then Assign_To_Overtime_Day[i,d])
         suffixes=(block=block_id[i,d]);

   con Satisfy_Demand {j in JOBS, t in TIMES, d in DAYS}:
      sum {i in EMPLOYEES: j in QUALIFIED_JOBS[i] and d in EMPLOYEE_DAYS[i]} Assign_To_Job[i,j,t,d]
      >= demand_coef[j,t] * demand[d,t];

   con Assign_Day_If_Assign_Job {i in EMPLOYEES, j in QUALIFIED_JOBS[i], t in TIMES, d in EMPLOYEE_DAYS[i]}:
      Is_Working_Day[i,d] >= Assign_To_Job[i,j,t,d]
         suffixes=(block=block_id[i,d]);


   con Min_Num_Shifts {i in EMPLOYEES: min_shift[i] > 0}:
      sum {d in EMPLOYEE_REGULAR_DAYS[i]} Assign_To_Regular_Day[i,d] >= min_shift[i];

   con Max_Num_Shifts {i in EMPLOYEES}:
      sum{d in EMPLOYEE_DAYS[i]} Is_Working_Day[i,d] <= max_shift[i];

   con Min_Hours_Per_Shift {i in EMPLOYEES, d in EMPLOYEE_DAYS[i]: min_hour[i] > 0}:
      sum {t in TIMES} Is_Working_Hour[i,t,d] >= min_hour[i] * Is_Working_Day[i,d]
         suffixes=(block=block_id[i,d]);

   con Max_Hours_Per_Shift {i in EMPLOYEES, d in EMPLOYEE_DAYS[i]}:
      sum {t in TIMES} Is_Working_Hour[i,t,d] <= max_hour[i]
         suffixes=(block=block_id[i,d]);


   /* If employee is not working in time t but working in time t+1, force Switch[i,t,d] to be 1. */
   con Force_Switch_to_1 {i in EMPLOYEES, t in TIMES, d in EMPLOYEE_DAYS[i]: t+1 <= last_hour}:
      Is_Working_Hour[i,t,d] + Switch[i,t,d] >= Is_Working_Hour[i,t+1,d]
         suffixes=(block=block_id[i,d]);

   /* If employee is working in time t and also working in time t+1, force Switch[i,t,d] to be 0.
      If employee is not working in time t and also not working in time t+1, force Switch[i,t,d] to be 0.
      If employee is working in time t and not working in time t+1, force Switch[i,t,d] to be 0. */
   con Force_Switch_to_0 {i in EMPLOYEES, t in TIMES, d in EMPLOYEE_DAYS[i]: t+1 <= last_hour}:
      Is_Working_Hour[i,t,d] + 2 * Switch[i,t,d] <= 1 + Is_Working_Hour[i,t+1,d]
         suffixes=(block=block_id[i,d]);

   /* Allow at most one switch per day. But if the employee begins work in the first hour, don't allow
      any switches. */
   con Max_One_Switch_Per_Day {i in EMPLOYEES, d in EMPLOYEE_DAYS[i]}:
      sum{t in TIMES: t+1 <= last_hour} Switch[i,t,d] <= 1 - Is_Working_Hour[i,first_hour,d]
         suffixes=(block=block_id[i,d]);


   con Two_Days_Off_Zero_if_Working {i in EMPLOYEES, d in DAYS: missing(off_days[i]) and max_shift[i] > 3}:
      Assign_To_Regular_Day[i,d] + Assign_To_Regular_Day[i,next_day[d]] + 2*Two_Days_Off_Start_Day[i,d] <= 2;

   con Force_Two_Days_Off {i in EMPLOYEES: missing(off_days[i]) and max_shift[i] > 3}:
      sum{d in DAYS} Two_Days_Off_Start_Day[i,d] >= 1;

   /********************************** Solve *********************************/

   solve obj TotalCost with milp / maxtime=300 relobjgap=0.001 decomp=(hybrid=false);

   /****************************** Create Output *****************************/

   num regCost{EMPLOYEES}, OTCost{EMPLOYEES} init 0;
   for {i in EMPLOYEES} do;
      regCost[i] = base_cost * cost[i] * sum {t in TIMES, d in EMPLOYEE_DAYS[i]}
                                               round(Is_Working_Hour[i,t,d].sol,1);
      OTcost[i] = (over_cost - base_cost) * cost[i]
                   * (sum {t in TIMES, d in EMPLOYEE_DAYS[i]} round(Is_Working_Hour[i,t,d].sol,1)
                      - min_shift[i] * min_hour[i]);
   end;

   create data &caslib..job_assignments
      from [employee job time day] = {i in EMPLOYEES, j in QUALIFIED_JOBS[i], t in TIMES, d in EMPLOYEE_DAYS[i]:
                                      Assign_To_Job[i,j,t,d].sol > 0.9};

   create data &caslib..employee_costs
      from [employee] = {i in EMPLOYEES}
         base_cost = regCost[i]
         overtime_cost = OTcost[i];
         
endsource;

    action optimization.runOptmodel / code=pgm printlevel=2; run;

quit;
