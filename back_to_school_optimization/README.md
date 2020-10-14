# Back to School Optimization
This folder contains two SAS programs that create the data and run the optimization model for the Back to School Optimization problem described in the Operations Research blog post "Back to School Optimization."
1. create_data.sas: Program to create the three input data files - **INPUT_SCHOOL_DATA**, **INPUT_ROOM_DATA**, and **INPUT_BLOCK_DATA**. Note that the **INPUT_BLOCK_DATA** is for weekly rotation scenario. 
2. s2do_optimize.sas: Program to read the input files and run the optimization model 


## Steps to run the code
1. Open and run the create_data.sas program. This creates three input data sets in your WORK library.
2. Open the file s2do_optimize.sas. Change the first two lines to specify your own CAS session and caslib.
3. Modify the macro variables (**virtual_percent**,**transition_window**, and **plan_num**) depending on the scenario. As mentioned earlier, the sample data in the **INPUT_BLOCK_DATA** is for weekly rotation scenario. The user should modify the **INPUT_BLOCK_DATA** table and **plan_num** macro variable to run for a different time horizon scenario.
3. Run aso_optimize.sas, which loads the input data sets from WORK to your specified caslib and runs the optimization model. The optimization program creates an output CAS table called **OUTPUT_FULL_ASSIGNMENT** in your specified caslib.