data work.ASO_employees;
   input id $ 1-18 type $ 25-33 skill cost off_days $ 42-48 max_volunteer_days;
   datalines;
Adam Knowland           Full-Time  4  30 Sat-Sun .
Alex Pie                Full-Time  3  25 Sat-Sun .
Alicia Day              Full-Time  2  18 Sat-Sun .
Alisa Right             Part-Time  2  18 Thu-Fri .
Amanda London           Full-Time  3  25 Mon-Tue .
Amelia Song             Part-Time  2  15 .       .
Andrew Stately          Volunteer  2   0 .       2
Aston Knight            Part-Time  2  18 Tue-Wed .
Bethany Scheuring       Volunteer  1   0 Tue-Wed 3
Bree Light              Part-Time  4  18 .       .
Britney Ontego          Volunteer  1   0 Sat-Sun 3
Charli Orza             Full-Time  2  18 Wed-Thu .
Darryl Lee              Part-Time  3  22 .       .
Dena Schaver            Part-Time  4  23 .       .
Devin Rice              Part-Time  3  21 Sat-Sun .
Elisha Wong             Part-Time  2  15 Fri-Sat .
Emanuel Sanchez         Full-Time  4  30 Thu-Fri .
Graeme Jones            Volunteer  2   0 .       2
Janet Riser             Part-Time  4  25 Sat-Sun .
Jenny Marsh             Full-Time  3  25 .       .
Joseph Rice             Full-Time  3  25 Thu-Fri .
Karen Freeman           Volunteer  2   0 Tue-Wed 2
Katalina Wright         Part-Time  4  24 Mon-Tue .
Katherine Radonich      Volunteer  2   0 .       3
Ken Farlow              Volunteer  1   0 Mon-Tue 3
Kennedy Lashly          Volunteer  2   0 Thu-Fri 2
Lexi Strong             Full-Time  2  18 Mon-Tue .
Loralee Conrad          Full-Time  3  23 Wed-Thu .
Marion Lake             Part-Time  4  18 .       .
Melinda Grand           Full-Time  3  20 Fri-Sat .
Morgan Sound            Full-Time  4  20 Wed-Thu .
Olivia Hong             Part-Time  2  17 .       .
Peter Rout              Part-Time  2  15 .       .
Randy Marsh             Volunteer  2   0 .       2
Ronny Ritz              Full-Time  4  28 Mon-Tue .
Ryan Besling            Volunteer  1   0 Sat-Sun 3
Ryan Zhang              Part-Time  3  20 .       .
Samatha Young           Part-Time  2  17 .       .
Simon Smith             Full-Time  3  21 Sun-Mon .
Tabatha Ramirez         Full-Time  4  30 Wed-Thu .
Tim Hardt               Full-Time  3  25 Mon-Tue .
;


data work.ASO_jobs;
   input job $ 1-14 req_skill;
   datalines;
Walking         1
Feeding         2
Administrative  3
Grooming        4
;


data work.ASO_demand;
   input day $ 1-3 col9-col19;
   datalines;
Mon 34 34 34 34 34 34 35 35 35 35 35
Tue 35 35 35 35 34 35 35 35 35 36 35
Wed 35 35 35 36 36 36 36 36 36 36 36
Thu 36 36 36 36 38 38 37 37 38 37 37
Fri 36 36 36 36 36 36 36 36 36 36 35
Sat 35 35 35 35 35 35 35 35 35 35 35
Sun 32 32 32 32 32 33 34 34 34 34 34
;


data work.ASO_demand_coef;
   input job $ 1-14 time demand_coef;
   datalines;
Administrative   9 0.04
Administrative  10 0.04
Administrative  11 0.04
Administrative  12 0.04
Administrative  13 0.04
Administrative  14 0.04
Administrative  15 0.04
Administrative  16 0.04
Administrative  17 0.04
Administrative  18 0.04
Administrative  19 0.04
Feeding          9 0.04
Feeding         10 0.04
Feeding         11 0.04
Feeding         12 0
Feeding         13 0
Feeding         14 0
Feeding         15 0
Feeding         16 0
Feeding         17 0.04
Feeding         18 0.04
Feeding         19 0.04
Grooming         9 0.1
Grooming        10 0.1
Grooming        11 0.1
Grooming        12 0.1
Grooming        13 0.1
Grooming        14 0.1
Grooming        15 0.1
Grooming        16 0.1
Grooming        17 0.1
Grooming        18 0.1
Grooming        19 0.1
Walking          9 0.2
Walking         10 0.2
Walking         11 0.2
Walking         12 0.2
Walking         13 0.2
Walking         14 0.2
Walking         15 0.2
Walking         16 0.2
Walking         17 0
Walking         18 0
Walking         19 0
;