/* Schools Table */
data work.INPUT_SCHOOL_DATA;
input School_Name $ 1-18  Grade $ 31-34 population;
datalines;
School1                       K       123
School1                       G01     120
School1                       G02     112
School1                       G03     110
School1                       G04     108
School1                       G05     124
;

/* Rooms Table */
data work.INPUT_ROOM_DATA;
input School_Name $ 1-18  roomID $ 31-34 capacity room_size_sqft;
datalines;
School1                       R1       15   923
School1                       R2       13   755
School1                       R3       13   755
School1                       R4       13   755
School1                       R5       13   755
School1                       R6       13   755
School1                       R7       12   705
School1                       R8       12   705
School1                       R9       12   705
School1                       R10      12   705
School1                       R11      12   705
School1                       R12      12   705
School1                       R13      12   705
School1                       R14      11   670
School1                       R15      11   670
School1                       R16      12   710
School1                       R17      15   1210
School1                       R18      15   1000
School1                       R19      12   710
School1                       R20      12   710
School1                       R21      12   710
School1                       R22      12   710
School1                       R23      12   710
School1                       R24      12   710
School1                       R25      12   710
School1                       R26      12   710
School1                       R27      13   750
School1                       R28      13   750
School1                       R29      12   720
School1                       R30      12   720
School1                       R31      12   720
School1                       R32      12   720
School1                       R33      12   720
School1                       R34      12   720
School1                       R35      12   720
School1                       R36      12   720
School1                       R37      12   720
School1                       R38      12   720
;

/* Blocks Table */
data work.INPUT_BLOCK_DATA;
input School_Name $ 1-18  block_id $ 31-38 block duration;
datalines;
School1                       Mon       1   1
School1                       Tue       2   1
School1                       Wed       3   1
School1                       Thu       4   1
School1                       Fri       5   1
;