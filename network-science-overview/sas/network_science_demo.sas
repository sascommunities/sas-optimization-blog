
/*****************************/
/* Network Science Blog Code */
/*****************************/

/*
Sections:dis
Visualize Whole Graph
Community Detection
Centrality of Nodes
Cliques
Node Similarity
Pattern Matching
Minimum Spanning Tree 
*/

/***
   This demo makes use of publicly available data from the source:
   The Network Data Repository with Interactive Graph Analytics and Visualization
   Ryan A. Rossi and Nesreen K. Ahmed
   http://networkrepository.com/fb-pages-government.php
***/


/***
   The first step in analyzing connected data is often data modeling. This step
   consists primarily of two tasks. The first is identifying which entities
   in your data to represent as nodes. The second task is identifying which
   associations in your data to represent as links. Furthermore, any data fields
   that provide additional information about the nodes or links that will be
   relevant to your analysis can be added to the graph as attributes.

   In the example presented here, the nodes are chosen to be social media pages
   of government-related entities. For links, we consider two nodes to be 
   associated if one or more sampled users "like" both pages.
***/

%INCLUDE "&_SASPROGRAMFILE/../environment.sas";
%INCLUDE "&_SASPROGRAMFILE/../macros.sas";

/* Connect to CAS server */
%reconnect();


/**************************************************/
/* Read Nodes and Links from delimited text files */
/**************************************************/
/*** Each node represents a government Facebook page ***/
data mycas.nodes(NCHARMULTIPLIER=3);
   infile "&LOCAL_DATA_DIR.fb-pages-government.nodes"
      dsd firstobs=2;
   length id $16 name $100 node $8;
   input id $ name $ node;
   name=tranwrd(name, '"', "'"); /* Cleanup: remove double quotes */
run;

/*** There are 89455 links betweek government Facebook pages ***/
data mycas.links;
   infile "&LOCAL_DATA_DIR.fb-pages-government.edges"
      dsd;
   length from $8 to $8;
   input from $ to $;
run;


/**************************************************/
/* To achieve nicer formatting, create a column,  */
/*  namewrap, that puts the longer names on       */
/*  multiple lines                                */
/**************************************************/
data mycas.nodes;
   set mycas.nodes;
   length namewrap $3000;
   %textWrap(name, namewrap, LINELEN=25);
run;

/*******************************/
/* Initial Network Exploration */
/*******************************/
proc network
   links              = mycas.links
   nodes              = mycas.nodes;
   summary
      out             = mycas.outSummary;
run;


/*****************************/
/* Visualize the Whole Graph */
/*****************************/
%displayWhere(mycas.nodes,
              mycas.links,
              fname=whole_graph.dot);

/***********************/
/* Community Detection */
/***********************/
proc network
   links              = mycas.links
   nodes              = mycas.nodes
   outNodes           = mycas.outCommNodes
   outLinks           = mycas.outCommLinks;
   nodesVar
      vars            = (name namewrap);
   community
      outCommunity    = mycas.outComm
      resolutionlist  = 10;
run;

/* Rank Communities by number of nodes */
/*    Adding small random perturbation to break ties */
data mycas.outCommPerturbed;
   set mycas.outComm; 
   nodes = nodes + rand('uniform', 0, 0.001);
run;
proc rank data=mycas.outCommPerturbed out=mycas.outCommRank descending;
   var nodes;
   ranks rank;
run; 

proc fedsql sessref=mySession;
   create table commNodes{options replace=true} as
   select a.*, b.rank
   from outCommNodes as a
   join outCommRank as b
   on a.community_1 = b.community
   ;
quit;
proc fedsql sessref=mySession;
   create table commLinks{options replace=true} as
   select a.*, b.rank
   from outCommLinks as a
   join outCommRank as b
   on a.community_1 = b.community
   ;
quit;


%displayWhere(mycas.commNodes,
              mycas.links,
              colorBy=rank,
              fname=whole_graph_comm.dot
);

%displayWhere(mycas.commNodes,
              mycas.commLinks,
              colorBy=rank,
              clause=(where=(rank LE &N_CLUSTERS_TO_SHOW)),
              fname=top_9_comm.dot
);

/***********************/
/* Centrality of Nodes */
/***********************/
proc network
   links              = mycas.commLinks
   outNodes           = mycas.outCentrNodes;
   centrality
      pagerank        = unweight;
run;

proc fedsql sessref=mySession;
   create table outCentrNodes{options replace=true} as
   select a.*, b.name
      , b.community_1
      , c.namewrap
   from outCentrNodes as a
   join outCommNodes as b
   on a.node = b.node
   join nodes as c
   on a.node = c.node
   ;
quit;

%let comm=25;
%displayWhere(mycas.outCentrNodes,
              mycas.outCommLinks,
              clause=(where=(community_1 EQ &comm)),
              sizeBy=centr_pagerank_unwt,
              fname=comm_&comm..dot);

%let comm=42;
%displayWhere(mycas.outCentrNodes,
              mycas.outCommLinks,
              clause=(where=(community_1 EQ &comm)),
              sizeBy=centr_pagerank_unwt,
              fname=comm_&comm..dot);

%let comm=18;
%displayWhere(mycas.outCentrNodes,
              mycas.outCommLinks,
              clause=(where=(community_1 EQ &comm)),
              sizeBy=centr_pagerank_unwt,
              fname=comm_&comm..dot);



/***********/
/* Cliques */
/***********/
proc network
   nodes              = mycas.nodes
   links              = mycas.links;
   nodesVar
      vars            = (namewrap);
   clique
      minNodeWeight    = 8
      maxCliques       = 5000
      out              = mycas.outCliqueNodes;
run;

%displayClique(1);
%displayClique(5000);

/*******************/
/* Node Similarity */
/*******************/
proc network
   nodes              = mycas.nodes
   links              = mycas.links;
   nodesimilarity
      source          = '4871' /* Node 4871 is 'NOAA NWS National Hurricane Center' */
      TOPK            = 10
      outSimilarity   = mycas.outSimilarity;
run;

proc fedsql sessref=mySession;
   create table outSim{options replace=true} as
   select a.*
      , b.name as "source_name"
      , c.name as "sink_name"
   from outSimilarity as a
   join nodes as b
   on a.source = b.node
   join nodes as c
   on a.sink = c.node
   ;
quit;

proc sort data=mycas.outSim out=outSim; 
   by order;
run;

proc print data=outSim; run;

%displayReach(4871, hops=1);

/********************/
/* Pattern Matching */
/********************/

/* Read Reddit links from delimited text file */
data mycas.redditLinks;
   infile "&LOCAL_DATA_DIR.soc-redditHyperlinks-title.tsv" firstobs=2dsd dlm='09'x;
   attrib timestamp informat=ANYDTDTM19. format=datetime20.;
   length from to $32 postid $8 sentiment 8 properties $1250;
   input from $ to $ postid $ timestamp sentiment properties $;
   sentiment_pos = input(scan(properties, 19, ','),best12.);
   sentiment_neg = input(scan(properties, 20, ','),best12.);
   sentiment_cmp = input(scan(properties, 21, ','),best12.);
   weight = (2 - sentiment - sentiment_cmp) / 4;
   drop properties;
run;

proc cas;
   loadactionset "deduplication";  
   action deduplication.deduplicate / 
     table={name="redditLinks",
           groupBy={{name="from"},{name="to"},{name="sentiment"}}, 
           orderBy={name="sentiment_pos"}},                         
     casOut={name="redditSimpleLinks"}, 
     noDuplicateKeys=true;
   run;
quit;

data mycas.nodesQuery;
   length node $8.;
   input node $ ordering;
   datalines;
A .
B 1
C 2
;
data mycas.LinksQuery;
   length from $8. to $8. sentiment 8;
   input from $ to $ sentiment;
   datalines;
A B 1
B C 1
C A 1
B A -1
C B -1
A C -1
;
proc cas;
   source myFilter;
   function symmetryBreak(node[*] $, ordering[*]);
      if(ordering[1] EQ . OR ordering[2] EQ .) then return (1);
      if(ordering[1] LT ordering[2]) then
         return (node[1] LT node[2]);
      return (1);
   endsub;
   function myNodePairFilter(node[*] $, ordering[*]);
      return (symmetryBreak(node, ordering));
   endsub;
   endsource;
   loadactionset "fcmpact";
   setSessOpt{cmplib="casuser.myRoutines"}; run;
   fcmpact.addRoutines /
      saveTable   = true,
      funcTable   = {name="myRoutines", caslib="casuser", replace=true},
      package     = "myPackage",
      routineCode = myFilter;
   run;
quit;

proc network
   direction          = directed
   links              = mycas.redditLinks
   outNodes           = mycas.redditNodes;
run;

proc network
   direction          = directed
   nodes              = mycas.redditNodes 
   links              = mycas.redditSimpleLinks 
   nodesQuery         = mycas.nodesQuery
   linksQuery         = mycas.linksQuery;
   nodesQueryVar
      vars            = (ordering)
      varsmatch       = ();
   linksQueryVar
      vars            = (sentiment);
   linksVar
      vars            = (sentiment);
   patternMatch
      nodePairFilter  = myNodePairFilter(n.node, nQ.ordering)
      outMatchNodes   = mycas.outMatchNodes
      outMatchLinks   = mycas.outMatchLinks
   ;
run;

data mycas.matchNodesA;
   set mycas.outMatchNodes(where=(nodeQ='A'));
run;

proc fedsql sessref=mySession;
   create table ACounts {options replace=true} as
   select node, count(*)
   from matchNodesA
   group by node;
quit;
proc fedsql sessref=mySession;
   create table matchCounts {options replace=true} as
   select node, count(*)
   from outMatchNodes
   group by node;
quit;
proc fedsql sessref=mySession;
   create table matchScores {options replace=true} as
   select a.node,
          a.COUNT as "ACount",
          b.count as "matchCount",
          1.0*a.COUNT/b.COUNT as "score"
   from ACounts as a
   join matchCounts as b
   on a.node=b.node;
quit;

proc sort data=mycas.matchScores(where=(matchCount GT 20)) out=matchScores;
   by descending score;
run;

proc print data=matchScores(obs=10); run;

%let match=100;
%displayWhere(mycas.outMatchNodes,
              mycas.outMatchLinks,
              clause=(where=(match EQ &match)),
              nodesLabel=node,
              linkAttrs=label=sentiment,
              directed=1,
              fname=match_&match..dot);

/*************************/
/* Minimum Spanning Tree */
/*************************/
proc fedsql sessref=mySession;
   create table redditMeanLinks {options replace=true} as
   select a.from, a.to, mean(weight) as "weight"
   from redditLinks as a
   group by a.from, a.to;
quit;
proc fedsql sessref=mySession;
   create table redditCountLinks {options replace=true} as
   select a.from, a.to, count(*) as "count"
   from redditLinks as a
   group by a.from, a.to;
quit;
proc fedsql sessref=mySession;
   create table redditWeightedLinks {options replace=true} as
   select a.from, a.to, a.weight, b.count
   from redditMeanLinks as a
   join redditCountLinks as b
   on a.from = b.from and a.to = b.to;
quit;

proc network
   links              = mycas.redditWeightedLinks
   outNodes           = mycas.outCommNodes
   outLinks           = mycas.outCommLinks;
   linksVar
      vars            = (weight count);
   community
      outCommunity    = mycas.outComm
      resolutionlist  = 100;
run;

proc print data=mycas.outComm(obs=20 where=(intra_links GT 100)); by descending density; run;

%let comm=1310;
%displayWhere(mycas.outCommNodes,
              mycas.outCommLinks,
              nodesLabel=node,
              linkAttrs=label=weight,
              clause=(where=(community_1 EQ &comm)),
              directed=1,
              fname=reddit_comm_&comm..dot);

data mycas.redditCommunityLinks;
   set mycas.outCommLinks(where=(community_1 EQ &comm));
run;
proc network
   direction          = directed
   links              = mycas.redditCommunityLinks
   outNodes           = mycas.redditCommunityNodes;
run;

/* Find MST of a single community */
proc optnetwork
   links      = mycas.redditCommunityLinks;
   minSpanTree
      out     = mycas.redditSpanTree;
run;

%displayWhere(mycas.redditCommunityNodes,
              mycas.redditSpanTree,
              nodesLabel=node,
              linkAttrs=label=weight,
              directed=0,
              fname=reddit_mst_&comm..dot);

/* Find MST of entire network */
proc optnetwork
   links      = mycas.redditWeightedLinks;
   minSpanTree
      out     = mycas.redditSpanTree;
run;
