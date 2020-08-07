/*if you have setup cas in unix, change the cassetup with your specifications*/

/*options casuser=xxx cashost=rdcgrdxxx casport=0;*/
/*cas sascas1  ;*/

/*or you could use casoperate to connect to cas directly from client:
proc casoperate host="rdcgrdxxx.unx.sas.com"
                install="/opt/vbviya/laxnd/TKGrid" 
                setupfile="/u/.../mycas.cfg"
                port=0 httpport=0 start=(term=yes);
run; quit;*/


/* Create a SAS Cloud Analytic Services session, xxx is your casuser name*/
cas mysess user=xxx; 

/* This statement associates the mycas libref with the Casuser caslib */
libname mycas cas caslib=casuser;

/* Specify the full local path where you store the data*/
libname hmmdoc "...\data";

data  trainData;
    set hmmdoc.trainData;
run;

/*after connecting to the cas server;*/
proc casutil incaslib="casuser" outcaslib="casuser";
  /*load a client-side file into memory on CAS*/
  load data=trainData casout="vwmi" replace;
  /*save the in-memory data as csv data on the server*/
  save casdata="vwmi" casout="vwmi" replace;
  contents casdata= "vwmi";
run;

%let ds = vwmi; /* dataset name */

* Run multi-start;
title "Multi-start for dataset &ds.";
%macro estimateRSAR(myds, inEstDs, kStart, kEnd, pStart, pEnd, method, maxiter, qMultiStart);
   proc cas;
	  hiddenMarkovModel.hmm result=r/
	  data = {caslib='casuser', name="&myds."},
	  id={time='date'},
	  outstat={name="&myds.&method.Stat_k&kStart.To&kEnd._p&pStart.To&pEnd.", caslib="casuser", replace=true},
	  model={depvars={'returnw'}, method="&method.", nState=&kStart., nStateTo=&kEnd., ylag=&pStart., yLagTo=&pEnd., type = 'AR'},
	  optimize = {algorithm='interiorpoint', printLevel=3, printIterFreq=1, maxiter=&maxiter., Multistart = &qMultiStart.},
	  score = {outmodel={name = "&myds.&method.Model_k&kStart.To&kEnd._p&pStart.To&pEnd.", caslib="casuser", replace=true}},
	  learn = {out={name = "&myds.&method.Learn_k&kStart.To&kEnd._p&pStart.To&pEnd.", caslib="casuser", replace=true} 
               %if %length(&inEstDs.)>0 %then %do; , in={name = "&inEstDs.", caslib="casuser"} %end;},
	  labelSwitch={sort="NONE"},
	  display = {names = {"Optimization.Algorithm", "ModelInfo", "ParameterMatrices.TPM", "Optimization.FinalParameterEstimates", "Optimization.IterHistory", "FitStatistics", "Optimization.InitialObjectiveFunction", "Optimization.FinalObjectiveFunction"}};
	  print r;
     run; quit;
	 CAS mysess listhistory;
%mend;

* First stage: enable multistart, use MAP, and get initial estimates of the parameters,
  It takes more than 15 hours to run;
%estimateRSAR(myds=vwmi, inEstDs=, kStart=2, kEnd=9, pStart=0, pEnd=0, method=MAP, maxiter=128, qMultiStart=1);

* Second stage: disable multi-start, use ML, and get final estimates of the parameters,
  It takes around 1 hour to run;
%estimateRSAR(myds=vwmi, inEstDs=vwmiMAPLEARN_K2TO9_P0TO0, kStart=2, kEnd=9, pStart=0, pEnd=5, method=ML, maxiter=128, qMultiStart=0);

* You can save files (learnt parameters and statistics) to cas sever for further use;
proc casutil incaslib="casuser" outcaslib="casuser";
  save casdata="&ds.MAPLEARN_K2TO9_P0TO0" casout="&ds.MAPLEARN_K2TO9_P0TO0" replace;
  contents casdata= "&ds.MAPLEARN_K2TO9_P0TO0";
  save casdata="&ds.MAPSTAT_K2TO9_P0TO0" casout="&ds.MAPSTAT_K2TO9_P0TO0" replace;
  contents casdata= "&ds.MAPSTAT_K2TO9_P0TO0";

  save casdata="&ds.MLLEARN_K2TO9_P0TO5" casout="&ds.MLLEARN_K2TO9_P0TO5" replace;
  contents casdata= "&ds.MLLEARN_K2TO9_P0TO5";
  save casdata="&ds.MLSTAT_K2TO9_P0TO5" casout="&ds.MLSTAT_K2TO9_P0TO5" replace;
  contents casdata= "&ds.MLSTAT_K2TO9_P0TO5";
run;

/*Print statistics tables*/
proc sort data=VWMIOMLSTAT_K2TO9_P0TO5; by modelIndex; run;
%macro printFitStat(fitStat);
   data trainData&fitStat.;
      set VWMIOMLSTAT_K2TO9_P0TO5 end=eof;
      array &fitStat.s{8,6} _TEMPORARY_;
      array yLags{6} yLag0-yLag5;
      &fitStat.s[nState-1,yLag+1] = &fitStat.;
      if eof then do;
         do i = 1 to 8;
            nState = i+1;
            do j = 1 to 6; yLags(j) = &fitStat.s[i,j]; end;
            output;
         end;
      end;
      keep nState yLag0-yLag5;
   run;
   proc print data=trainData&fitStat. label noobs
      style(header)={textalign=center};
      var nState yLag0-yLag5;
      label nState='k' yLag0='p = 0' yLag1='p = 1' yLag2='p = 2'
         yLag3='p = 3' yLag4='p = 4' yLag5='p = 5';
   run;
%mend;
%printFitStat(AIC);
%printFitStat(logLikelihood);



* Use Black-Box optimization solver to tune initial values instead of multi-start;
%macro hmmBlackboxTune(ns, nvars, pStart, maxiter, method, maxgeneration, delta);
title "Tuning using &method.: k = &ns., p = &pStart., lower bound on Covariance is &delta., maxiters = &maxiter.";

/* read datalines for linear constraints from txt files */
data mycas.lindata;
   infile "..\data\k&ns..txt" truncover;  /*need to specify the full path before you run*/
   input _id_ $_lb_ x1-x&nvars. _ub_;
run;

/* fetch linear constraints data for double check*/
proc cas;
table.fetch / table = {name = 'lindata', caslib = "casuser"};
run; quit;

proc cas noqueue;
   /*construct a dictionary of tuning variables*/
   myvars = {};
   do i = 1 to &ns.*&ns.;
      myvars[i] = {};
      myvars[i]['name'] = "x" || (String)i;
      myvars[i]['lb'] = 0;
      myvars[i]['ub'] = 1;
   end;
   do i = &ns.*&ns. + 1 to &ns.*(&ns.+ 1);
      myvars[i] = {};
   	  myvars[i]['name'] = "x" || (String)i;
   end;
   do i = &ns.*(&ns. + 1) + 1 to &ns.*(&ns.+ 2);
      myvars[i] = {};
   	  myvars[i]['name'] = "x" || (String)i;
	  myvars[i]['lb'] = 0;
   end;
   print myvars;
   run;

  /* use init function to make data available to all worker nodes*/
  source casInit;
  	loadTable / caslib='casuser', path='vwmi.sashdat', casout='vwmi';
  endsource;

  source caslEval;
      /* uncomment the following two lines to store all log files to a given path 
 	  filename="~/logfiles_hmm/k&ns.p&pStart._&method." ||'/hmm_log' || (String)_bbEvalTag_ || '.txt';
      file nodes filename;*/
	  hiddenMarkovModel.hmm result=r /
	  data = "vwmi",
	  id={time='date'},
	  outstat={name="&ds.&method.Stat_k&ns.p&pStart._" || (String) _bbEvalTag_ , caslib="casuser", promote=true},
	  model={depvars={'returnw'}, method="&method.", nState=&ns., ylag=&pStart., type = 'AR'},
	  /* specify initial values for a particular k using tuning vars*/
	  %if &ns. = 2 %then %do;
	  initial={'TPM={' || (String) x1 || ' ' || (String) x2 || ', ' || (String) x3 || ' ' || (String) x4 || '}',
	           'MU={'|| (String) x5 || ', ' || (String) x6 || '}',
	           'SIGMA={' || (String) x7 || ', ' || (String) x8 || '}'},
      %end;
	  %if &ns. = 3 %then %do;
	  initial={'TPM={' || (String) x1 || ' ' || (String) x2 || ' ' || (String) x3 || ', ' || (String) x4 || ' ' || (String) x5 || ' ' || (String) x6 ||', ' 
                       || (String) x7 || ' ' || (String) x8 || ' ' || (String) x9 || '}',
	           'MU={'|| (String) x10 || ', ' || (String) x11 || ', ' || (String) x12 || '}',
	           'SIGMA={' || (String) x13 || ', ' || (String) x14 || ', ' || (String) x15 || '}'},
      %end;
	  %if &ns. = 4 %then %do;
      initial={'TPM={' || (String) x1 || ' ' || (String) x2 || ' ' || (String) x3 || ' ' || (String) x4 || ', ' 
                       || (String) x5 || ' ' || (String) x6 || ' ' || (String) x7 || ' ' || (String) x8 || ', ' 
                       || (String) x9 || ' ' || (String) x10 || ' ' || (String) x11 || ' ' || (String) x12 || ', '
                       || (String) x13 || ' ' || (String) x14 || ' ' || (String) x15 || ' ' || (String) x16 || '}',
	           'MU={'  || (String) x17 || ', ' || (String) x18 || ', ' || (String) x19 || ', ' || (String) x20 || '}',
	           'SIGMA={' || (String) x21 || ', ' || (String) x22 || ', ' || (String) x23 || ', ' || (String) x24 || '}'},
      %end;
	  %if &ns. = 5 %then %do;
      initial={'TPM={' || (String) x1 || ' ' || (String) x2 || ' ' || (String) x3 || ' ' || (String) x4 || ' ' || (String) x5 || ', ' 
                       || (String) x6 || ' ' || (String) x7 || ' ' || (String) x8 || ' ' || (String) x9 || ' ' || (String) x10 || ', ' 
                       || (String) x11 || ' ' || (String) x12 || ' ' || (String) x13 || ' ' || (String) x14 || ' ' || (String) x15 ||', '
                       || (String) x16 || ' ' || (String) x17 || ' ' || (String) x18 || ' ' || (String) x19 || ' ' || (String) x20 ||', '
                       || (String) x21 || ' ' || (String) x22 || ' ' || (String) x23 || ' ' || (String) x24 || ' ' || (String) x25 ||'} ',
	           'MU={'  || (String) x26 || ', ' || (String) x27 || ', ' || (String) x28 || ', ' || (String) x29 || ', ' || (String) x30 ||'}',
	           'SIGMA={' || (String) x31 || ', ' || (String) x32 || ', ' || (String) x33 || ', ' || (String) x34 || ', ' || (String) x35 || '}'},
      %end;
	  %if &ns. = 6 %then %do;
      initial={'TPM={' || (String) x1 || ' ' || (String) x2 || ' ' || (String) x3 || ' ' || (String) x4 || ' ' || (String) x5 || ' ' || (String) x6 || ', ' 
                       || (String) x7 || ' ' || (String) x8 || ' ' || (String) x9 || ' ' || (String) x10 || ' ' || (String) x11 || ' ' || (String) x12 || ', ' 
                       || (String) x13 || ' ' || (String) x14 || ' ' || (String) x15 || ' ' || (String) x16 || ' ' || (String) x17 || ' ' || (String) x18 || ', '
                       || (String) x19 || ' ' || (String) x20 || ' ' || (String) x21 || ' ' || (String) x22 || ' ' || (String) x23 || ' ' || (String) x24 || ', '
                       || (String) x25 || ' ' || (String) x26 || ' ' || (String) x27 || ' ' || (String) x28 || ' ' || (String) x29 || ' ' || (String) x30 || ', '
                       || (String) x31 || ' ' || (String) x32 || ' ' || (String) x33 || ' ' || (String) x34 || ' ' || (String) x35 || ' ' || (String) x36 || '} ',
	           'MU={'  || (String) x37 || ', ' || (String) x38 || ', ' || (String) x39 || ', ' || (String) x40 || ', ' || (String) x41 || ', ' || (String) x42 ||'}',
	           'SIGMA={' || (String) x43 || ', ' || (String) x44 || ', ' || (String) x45 || ', ' || (String) x46 || ', ' || (String) x47 || ', ' || (String) x48 || '}'},
      %end;
	  %if &ns. = 7 %then %do;
      initial={'TPM={' || (String) x1 || ' ' || (String) x2 || ' ' || (String) x3 || ' ' || (String) x4 || ' ' || (String) x5 || ' ' || (String) x6 || ' ' || (String) x7 || ', ' 
                       || (String) x8 || ' ' || (String) x9 || ' ' || (String) x10 || ' ' || (String) x11 || ' ' || (String) x12 || ' ' || (String) x13 || ' ' || (String) x14 || ', ' 
                       || (String) x15 || ' ' || (String) x16 || ' ' || (String) x17 || ' ' || (String) x18 || ' ' || (String) x19 ||' ' || (String) x20 || ' ' || (String) x21 || ', '
                       || (String) x22 || ' ' || (String) x23 || ' ' || (String) x24 || ' ' || (String) x25 || ' ' || (String) x26 ||' ' || (String) x27 || ' ' || (String) x28 || ', '
                       || (String) x29 || ' ' || (String) x30 || ' ' || (String) x31 || ' ' || (String) x32 || ' ' || (String) x33 ||' ' || (String) x34 || ' ' || (String) x35 || ', '
                       || (String) x36 || ' ' || (String) x37 || ' ' || (String) x38 || ' ' || (String) x39 || ' ' || (String) x40 ||' ' || (String) x41 || ' ' || (String) x42 || ', ' 
                       || (String) x43 || ' ' || (String) x44 || ' ' || (String) x45 || ' ' || (String) x46 || ' ' || (String) x47 ||' ' || (String) x48 || ' ' || (String) x49 || '} ',
	           'MU={'  || (String) x50 || ', ' || (String) x51 || ', ' || (String) x52 || ', ' || (String) x53 || ', ' || (String) x54 || ', ' || (String) x55 || ', ' || (String) x56 ||'}',
	           'SIGMA={' || (String) x57 || ', ' || (String) x58 || ', ' || (String) x59 || ', ' || (String) x60 || ', ' || (String) x61 || ', ' || (String) x62 || ', ' || (String) x63 || '}'},
      %end;
	  %if &ns. = 8 %then %do;
      initial={'TPM={' || (String) x1 || ' ' || (String) x2 || ' ' || (String) x3 || ' ' || (String) x4 || ' ' || (String) x5 || ' ' || (String) x6 || ' ' || (String) x7 || ' ' || (String) x8 || ', ' 
                       || (String) x9 || ' ' || (String) x10 || ' ' || (String) x11 || ' ' || (String) x12 || ' ' || (String) x13 || ' ' || (String) x14 || ' ' || (String) x15 || ' ' || (String) x16 || ', ' 
                       || (String) x17 || ' ' || (String) x18 || ' ' || (String) x19 || ' ' || (String) x20 || ' ' || (String) x21 ||' ' || (String) x22 || ' ' || (String) x23 || ' ' || (String) x24 || ', '
                       || (String) x25 || ' ' || (String) x26 || ' ' || (String) x27 || ' ' || (String) x28 || ' ' || (String) x29 ||' ' || (String) x30 || ' ' || (String) x31 || ' ' || (String) x32 || ', '
                       || (String) x33 || ' ' || (String) x34 || ' ' || (String) x35 || ' ' || (String) x36 || ' ' || (String) x37 ||' ' || (String) x38 || ' ' || (String) x39 || ' ' || (String) x40 || ', '
                       || (String) x41 || ' ' || (String) x42 || ' ' || (String) x43 || ' ' || (String) x44 || ' ' || (String) x45 ||' ' || (String) x46 || ' ' || (String) x47 || ' ' || (String) x48 || ', ' 
                       || (String) x49 || ' ' || (String) x50 || ' ' || (String) x51 || ' ' || (String) x52 || ' ' || (String) x53 ||' ' || (String) x54 || ' ' || (String) x55 || ' ' || (String) x56 || ', '
                       || (String) x57 || ' ' || (String) x58 || ' ' || (String) x59 || ' ' || (String) x60 || ' ' || (String) x61 ||' ' || (String) x62 || ' ' || (String) x63 || ' ' || (String) x64 || '} ',
	           'MU={'  || (String) x65 || ', ' || (String) x66 || ', ' || (String) x67 || ', ' || (String) x68 || ', ' || (String) x69 || ', ' || (String) x70 || ', ' || (String) x71 || ', ' || (String) x72 ||'}',
	           'SIGMA={' || (String) x73 || ', ' || (String) x74 || ', ' || (String) x75 || ', ' || (String) x76 || ', ' || (String) x77 || ', ' || (String) x78 || ', ' || (String) x79 || ', ' || (String) x80 ||'}'},
      %end;
	  %if &ns. = 9 %then %do;
      initial={'TPM={' || (String) x1 || ' ' || (String) x2 || ' ' || (String) x3 || ' ' || (String) x4 || ' ' || (String) x5 || ' ' || (String) x6 || ' ' || (String) x7 || ' ' || (String) x8 || ' ' || (String) x9 || ', ' 
			           || (String) x10 || ' ' || (String) x11 || ' ' || (String) x12 || ' ' || (String) x13 || ' ' || (String) x14 || ' ' || (String) x15 || ' ' || (String) x16 || ' ' || (String) x17 || ' ' || (String) x18 || ', ' 
			           || (String) x19 || ' ' || (String) x20 || ' ' || (String) x21 || ' ' || (String) x22 || ' ' || (String) x23 ||' ' || (String) x24 || ' ' || (String) x25 || ' ' || (String) x26 || ' ' || (String) x27 ||', '
			           || (String) x28 || ' ' || (String) x29 || ' ' || (String) x30 || ' ' || (String) x31 || ' ' || (String) x32 ||' ' || (String) x33 || ' ' || (String) x34 || ' ' || (String) x35 || ' ' || (String) x36 ||', '
			           || (String) x37 || ' ' || (String) x38 || ' ' || (String) x39 || ' ' || (String) x40 || ' ' || (String) x41 ||' ' || (String) x42 || ' ' || (String) x43 || ' ' || (String) x44 || ' ' || (String) x45 ||', '
			           || (String) x46 || ' ' || (String) x47 || ' ' || (String) x48 || ' ' || (String) x49 || ' ' || (String) x50 ||' ' || (String) x51 || ' ' || (String) x52 || ' ' || (String) x53 || ' ' || (String) x54 ||', ' 
			           || (String) x55 || ' ' || (String) x56 || ' ' || (String) x57 || ' ' || (String) x58 || ' ' || (String) x59 ||' ' || (String) x60 || ' ' || (String) x61 || ' ' || (String) x62 || ' ' || (String) x63 ||', '
			           || (String) x64 || ' ' || (String) x65 || ' ' || (String) x66 || ' ' || (String) x67 || ' ' || (String) x68 ||' ' || (String) x69 || ' ' || (String) x70 || ' ' || (String) x71 || ' ' || (String) x72 ||', '
			           || (String) x73 || ' ' || (String) x74 || ' ' || (String) x75 || ' ' || (String) x76 || ' ' || (String) x77 ||' ' || (String) x78 || ' ' || (String) x79 || ' ' || (String) x80 || ' ' || (String) x81 || '} ',
			   'MU={'  || (String) x82 || ', ' || (String) x83 || ', ' || (String) x84 || ', ' || (String) x85 || ', ' || (String) x86 || ', ' || (String) x87 || ', ' || (String) x88 || ', ' || (String) x89 || ', ' || (String) x90 ||'}',
			   'SIGMA={' || (String) x91 || ', ' || (String) x92 || ', ' || (String) x93 || ', ' || (String) x94 || ', ' || (String) x95 || ', ' || (String) x96 || ', ' || (String) x97 || ', ' || (String) x98 || ', ' || (String) x99 ||'}'},
      %end;
	  optimize = {algorithm='interiorpoint', printLevel=3, printIterFreq=1, maxiter=&maxiter., Multistart = 0},
	  score= {outmodel={name = "&ds.&method.Model_k&ns.p&pStart._" || (String) _bbEvalTag_, caslib="casuser", replace=true}},
	  learn= {out={name = "&ds.&method.Learn_k&ns.p&pStart._" || (String) _bbEvalTag_, caslib="casuser", promote=true}},
	  labelSwitch={sort="NONE"};
	  /* specify tuning objectives */
	  if &ns. == 2 then do;
	    print "number of state is &ns.";
	     if ((r['ParameterMatrices.Cov'][1, 3] <  &delta.) OR (r['ParameterMatrices.Cov'][2, 3] <  &delta.) OR
	         (r['ParameterMatrices.Cov'][1, 3] > 1E3) OR (r['ParameterMatrices.Cov'][2, 3] > 1E3)) then do; 
			 f['obj2'] = -1E20; 
			 print "Infinity";
         end;
	     else do;
		     f['obj2'] = r.FitStatistics[1, 2];  /*Read loglikelihood from the FitStatistics table*/
	     end;
      end;
	  if &ns. == 3 then do;
	     print "number of state is &ns.";
	     if ((r['ParameterMatrices.Cov'][1, 3] <  &delta.) OR (r['ParameterMatrices.Cov'][2, 3] <  &delta.) OR
             (r['ParameterMatrices.Cov'][3, 3] <  &delta.) OR
	         (r['ParameterMatrices.Cov'][1, 3] > 1E3) OR (r['ParameterMatrices.Cov'][2, 3] > 1E3) OR
             (r['ParameterMatrices.Cov'][3, 3] > 1E3)) then do; 
			 f['obj2'] = -1E20; 
			 print "Infinity";
         end;
	     else do;
		     f['obj2'] = r.FitStatistics[1, 2]; /*Read loglikelihood from the FitStatistics table*/
	     end;
      end;
	  if &ns. == 4 then do;
	     print "number of state is &ns.";
	     if ((r['ParameterMatrices.Cov'][1, 3] <  &delta.) OR (r['ParameterMatrices.Cov'][2, 3] <  &delta.) OR
             (r['ParameterMatrices.Cov'][3, 3] <  &delta.) OR (r['ParameterMatrices.Cov'][4, 3] <  &delta.) OR
	         (r['ParameterMatrices.Cov'][1, 3] > 1E3) OR (r['ParameterMatrices.Cov'][2, 3] > 1E3) OR
             (r['ParameterMatrices.Cov'][3, 3] > 1E3) OR (r['ParameterMatrices.Cov'][4, 3] > 1E3)) then do; 
			 f['obj2'] = -1E20; 
			 print "Infinity";
         end;
	     else do;
		     f['obj2'] = r.FitStatistics[1, 2]; /*Read loglikelihood from the FitStatistics table*/
	     end;
      end;
	  if &ns. == 5 then do;
	     print "number of state is &ns.";
	     if ((r['ParameterMatrices.Cov'][1, 3] <  &delta.) OR (r['ParameterMatrices.Cov'][2, 3] <  &delta.) OR
             (r['ParameterMatrices.Cov'][3, 3] <  &delta.) OR (r['ParameterMatrices.Cov'][4, 3] <  &delta.) OR
             (r['ParameterMatrices.Cov'][5, 3] <  &delta.) OR 
	         (r['ParameterMatrices.Cov'][1, 3] > 1E3) OR (r['ParameterMatrices.Cov'][2, 3] > 1E3) OR
             (r['ParameterMatrices.Cov'][3, 3] > 1E3) OR (r['ParameterMatrices.Cov'][4, 3] > 1E3) OR
             (r['ParameterMatrices.Cov'][5, 3] > 1E3)) then do; 
			 f['obj2'] = -1E20; 
			 print "Infinity";
         end;
	   else do;
		     f['obj2'] = r.FitStatistics[1, 2]; /*Read loglikelihood from the FitStatistics table*/
	   end;
      end;
	  if &ns. == 6 then do;
	     print "number of state is &ns.";
	     if ((r['ParameterMatrices.Cov'][1, 3] <  &delta.) OR (r['ParameterMatrices.Cov'][2, 3] <  &delta.) OR
             (r['ParameterMatrices.Cov'][3, 3] <  &delta.) OR (r['ParameterMatrices.Cov'][4, 3] <  &delta.) OR
             (r['ParameterMatrices.Cov'][5, 3] <  &delta.) OR (r['ParameterMatrices.Cov'][6, 3] <  &delta.) OR
	         (r['ParameterMatrices.Cov'][1, 3] > 1E3) OR (r['ParameterMatrices.Cov'][2, 3] > 1E3) OR
             (r['ParameterMatrices.Cov'][3, 3] > 1E3) OR (r['ParameterMatrices.Cov'][4, 3] > 1E3) OR
             (r['ParameterMatrices.Cov'][5, 3] > 1E3) OR (r['ParameterMatrices.Cov'][6, 3] > 1E3)) then do; 
			 f['obj2'] = -1E20; 
			 print "Infinity";
         end;
	   else do;
		     f['obj2'] = r.FitStatistics[1, 2]; /*Read loglikelihood from the FitStatistics table*/
	   end;
      end;
	  if &ns. == 7 then do;
	     print "number of state is &ns.";
	     if ((r['ParameterMatrices.Cov'][1, 3] <  &delta.) OR (r['ParameterMatrices.Cov'][2, 3] <  &delta.) OR
             (r['ParameterMatrices.Cov'][3, 3] <  &delta.) OR (r['ParameterMatrices.Cov'][4, 3] <  &delta.) OR
             (r['ParameterMatrices.Cov'][5, 3] <  &delta.) OR (r['ParameterMatrices.Cov'][6, 3] <  &delta.) OR
			 (r['ParameterMatrices.Cov'][7, 3] <  &delta.) OR
	         (r['ParameterMatrices.Cov'][1, 3] > 1E3) OR (r['ParameterMatrices.Cov'][2, 3] > 1E3) OR
             (r['ParameterMatrices.Cov'][3, 3] > 1E3) OR (r['ParameterMatrices.Cov'][4, 3] > 1E3) OR
             (r['ParameterMatrices.Cov'][5, 3] > 1E3) OR (r['ParameterMatrices.Cov'][6, 3] > 1E3) OR 
             (r['ParameterMatrices.Cov'][7, 3] > 1E3)) then do; 
			 f['obj2'] = -1E20; 
			 print "Infinity";
         end;
	     else do;
		     f['obj2'] = r.FitStatistics[1, 2]; /*Read loglikelihood from the FitStatistics table*/
	     end;
      end;
	  if &ns. == 8 then do;
	     print "number of state is &ns.";
	     if ((r['ParameterMatrices.Cov'][1, 3] <  &delta.) OR (r['ParameterMatrices.Cov'][2, 3] <  &delta.) OR
             (r['ParameterMatrices.Cov'][3, 3] <  &delta.) OR (r['ParameterMatrices.Cov'][4, 3] <  &delta.) OR
             (r['ParameterMatrices.Cov'][5, 3] <  &delta.) OR (r['ParameterMatrices.Cov'][6, 3] <  &delta.) OR
			 (r['ParameterMatrices.Cov'][7, 3] <  &delta.) OR (r['ParameterMatrices.Cov'][8, 3] <  &delta.) OR
	         (r['ParameterMatrices.Cov'][1, 3] > 1E3) OR (r['ParameterMatrices.Cov'][2, 3] > 1E3) OR
             (r['ParameterMatrices.Cov'][3, 3] > 1E3) OR (r['ParameterMatrices.Cov'][4, 3] > 1E3) OR
             (r['ParameterMatrices.Cov'][5, 3] > 1E3) OR (r['ParameterMatrices.Cov'][6, 3] > 1E3) OR 
             (r['ParameterMatrices.Cov'][7, 3] > 1E3) OR (r['ParameterMatrices.Cov'][8, 3] > 1E3)) then do; 
			 f['obj2'] = -1E20; 
			 print "Infinity";
         end;
	     else do;
		     f['obj2'] = r.FitStatistics[1, 2]; /*Read loglikelihood from the FitStatistics table*/
	     end;
      end;
	  if &ns. == 9 then do;
	     print "number of state is &ns.";
	     if ((r['ParameterMatrices.Cov'][1, 3] <  &delta.) OR (r['ParameterMatrices.Cov'][2, 3] <  &delta.) OR
             (r['ParameterMatrices.Cov'][3, 3] <  &delta.) OR (r['ParameterMatrices.Cov'][4, 3] <  &delta.) OR
             (r['ParameterMatrices.Cov'][5, 3] <  &delta.) OR (r['ParameterMatrices.Cov'][6, 3] <  &delta.) OR
			 (r['ParameterMatrices.Cov'][7, 3] <  &delta.) OR (r['ParameterMatrices.Cov'][8, 3] <  &delta.) OR
			 (r['ParameterMatrices.Cov'][9, 3] <  &delta.) OR
	         (r['ParameterMatrices.Cov'][1, 3] > 1E3) OR (r['ParameterMatrices.Cov'][2, 3] > 1E3) OR
             (r['ParameterMatrices.Cov'][3, 3] > 1E3) OR (r['ParameterMatrices.Cov'][4, 3] > 1E3) OR
             (r['ParameterMatrices.Cov'][5, 3] > 1E3) OR (r['ParameterMatrices.Cov'][6, 3] > 1E3) OR 
             (r['ParameterMatrices.Cov'][7, 3] > 1E3) OR (r['ParameterMatrices.Cov'][8, 3] > 1E3) OR 
             (r['ParameterMatrices.Cov'][9, 3] > 1E3)) then do; 
			 f['obj2'] = -1E20; 
			 print "Infinity";
         end;
	   else do;
		     f['obj2'] = r.FitStatistics[1, 2]; /*Read loglikelihood from the FitStatistics table*/
	   end;
      end;

	  send_response(f);
	  print "Covariance: ";
      print r['ParameterMatrices.Cov'];
	  print "FitStatistics: ";
	  print r.FitStatistics;
	  print "Initial values: ";
	  print r['Optimization.InitialParameterEstimates'];
	  print "Final values: ";
	  print r['Optimization.FinalParameterEstimates'];
	  print "All results: ";
	  print r;
  endsource;

  /* Invoke the solveBlackbox action */
   optimization.solveBlackbox result=blackr/
      decVars = myvars,
      obj = {{name='obj2', type='max'}},
	  maxGen= &maxgeneration., /* by default 10 */
	  popSize=20,  /* by default 40 */
	  maxTime = 3600,
	  LOGLEVEL=1,
	  linCon={name = "lindata", caslib = "casuser"},
      func = {init=casInit, eval=caslEval},
      primalOut={name="p_out", replace=true, caslib = "casuser"},
	  nParallel=30; /*number of parallel sessions */
   print blackr;
run;
quit;

proc print data=mycas.p_out; run;
%mend;

%let ns = 2; /* number of states k */
%let pStart = 0; /* order of regression p */
%let nvars = 8; /* number of variables to be tuned, equal to ns*(ns + 2) */
%let nworkers = 30; /*how many worker nodes are used*/
%let method = ML; /*tuning method could be MAP or ML*/

%hmmBlackboxTune(ns = &ns., nvars = &nvars., pStart = &pStart., maxiter = 128, method = &method., maxgeneration = 1, delta = 1E-3);

%let tag = 28; /* The tag number is read from p_out table, it corresponds to the best solution */
proc casutil incaslib="casuser" outcaslib="casuser";
  save casdata = "&ds.&method.Stat_k&ns.p&pStart._&tag." casout = "&ds.&method.Stat_k&ns.p&pStart._&tag." replace;
  contents casdata = "&ds.&method.Stat_k&ns.p&pStart._&tag.";
  save casdata= "&ds.&method.Learn_k&ns.p&pStart._&tag." casout="&ds.&method.Learn_k&ns.p&pStart._&tag." replace;
  contents casdata="&ds.&method.Learn_k&ns.p&pStart._&tag.";
run;

/* Need to skip 5 - p observations when only do the second stage for pStart = p*/
data mycas.vwmip0;
   set mycas.vwmi;
/*    where w ~= 1; */
/*    where w ~= 1 and w ~= 2;*/
/*    where w ~= 1 and w ~= 2 and w ~= 3;*/
/*    where w ~= 1 and w ~= 2 and w ~= 3 and w ~= 4;*/
    where w ~= 1 and w ~= 2 and w ~= 3 and w ~= 4 and w ~= 5;
run;

/* using ML and taking VWMIMLLEARN_K2P0_28_30 as initial parameter estimates for the second stage*/
%let porders = 5;
%estimateRSAR(myds=vwmiOp0, inEstDs=VWMIMLLEARN_K2P0_28, kStart=&nstates., kEnd=&nstates., pStart=&porders., pEnd=&porders.,
   method=ML, maxiter=128, qMultiStart=0);

proc casutil incaslib="casuser" outcaslib="casuser";
  save casdata="&ds.P&porders.MLSTAT_K&ns.TO&ns._P&porders.TO&porders." casout="&ds.P&porders.MLSTAT_K&ns.TO&ns._P&porders.TO&porders." replace;
  contents casdata="&ds.P&porders.MLSTAT_K&ns.TO&ns._P&porders.TO&porders.";
  save casdata="&ds.P&porders.MLLEARN_K&ns.TO&ns._P&porders.TO&porders." casout="&ds.P&porders.MLLEARN_K&ns.TO&ns._P&porders.TO&porders." replace;
  contents casdata="&ds.P&porders.MLLEARN_K&ns.TO&ns._P&porders.TO&porders.";
run;


proc casoperate host="rdcgrdxxx" port=xxxxx shutdown;
run;

