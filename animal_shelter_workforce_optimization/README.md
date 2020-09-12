# Animal Shelter Workforce Optimization

This folder contains two SAS programs that create the data and run the optimization model for the Animal Shelter Workforce Optimization problem described in the Operations Research blog post "[Workforce Scheduling at an Animal Shelter](https://blogs.sas.com/content/operations/)." 

To run the code, follow these steps: 
1. Open and run the file called `aso_create_data.sas`, which creates four input data sets in your WORK library.
2. Open the file called `aso_optimize.sas`, and change the first two lines to specify your own CAS session and caslib. 
3. Run `aso_optimize.sas`, which loads the input data sets from WORK to your specified caslib and runs the optimization model. 

The optimization program creates two output CAS tables in your specified caslib:
* JOB_ASSIGNMENTS, which contains the employee job assignments for each hour of each day
* EMPLOYEE_COSTS, which contains the total weekly base time and overtime costs for each employee
