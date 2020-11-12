/*********************/
/* Macro Definitions */
/*********************/

/* CAS Connection */
%macro terminateAll();
   cas _ALL_ terminate ;
   %if (%symexist(graphId)) %then %do;
      %symdel graphId;
   %end;
%mend;

%macro reconnect(host=&CAS_SERVER_HOST, port=&CAS_SERVER_PORT, sessionName=mySession, timeout=1800);
   %terminateAll();
   
   /** Connect to the Cas Server **/
   options cashost="&host" casport=&port;
   cas &sessionName sessopts=(caslib=casuser timeout=&timeout locale="en_US");
   libname mycas cas sessref=&sessionName caslib="CASUSER";
%mend;


/***
   This macro converts wraps a long character variable onto
    multiple lines by inserting the \n newline character.
***/
%macro TEXTWRAP(
               varIn,
               varOut,
               LINELEN=80 /* [optional] maximum length of line of 
                               reformatted text                      */
               , MAXLEN=128
               ) ;

        length  textin textout $ 32767;

        textin = &varIn;
        if lengthn(textin) GT &MAXLEN then
           textin = substr(textin, 1, &MAXLEN);
        if lengthn( textin ) LE &LINELEN
           then &varOut = textin;
        else do;
           &varOut='';
           do while( lengthn( textin ) GT &LINELEN AND lengthn(&varOut) LT &MAXLEN) ;
               textout = reverse( substr( textin, 1, &LINELEN )) ;

               ndx = index( textout, ' ' ) ;

               if ndx LE &LINELEN and ndx GT 0
               then do ;
                   textout = reverse( substr( textout, ndx + 1 )) ;
                   &varOut = CATX('\n', &varOut, textout);
                   textin = substr( textin, &LINELEN - ndx + 1 ) ;
               end ;
               else do;
                   textout = substr(textin,1,&LINELEN);
                   &varOut = CATX('\n', &varOut, textout);
                   textin = substr(textin,&LINELEN+1);
               end;

               textin = strip(textin);
               if lengthn( textin ) le &LINELEN then &varOut = CATX('\n', &varOut, textin);
           end ;
        end;

%mend TEXTWRAP ;



/***
   This macro converts a graph specified by nodes and/or links table to
   graphViz format. Invoke graph2dot within a data step as shown in 
   visualization_ex.sas to write the graphViz output to a file.
***/
%macro graph2dot(
   nodes=_NULL_,
   links=_NULL_,
   nodesNode="node",
   linksFrom="from",
   linksTo="to",
   nodeAttrs="",
   linkAttrs="",
   directed=0,
   graphAttrs="",
   nodesAttrs="",
   linksAttrs="",
   nodesColorBy=_UNSUPPORTED_,
   linksColorBy=_UNSUPPORTED_,
   sort=_UNSUPPORTED_
);
   length line $10000 kv lhs rhs nodeId fromId toId $100
          nodeVarType attrVarType $1;
   if &directed then do;
      put "digraph G {";
      linkSep = " -> ";
   end;
   else do;
      put "graph G {";
      linkSep = " -- ";
   end;

   /** Replace graphAttrs commas with semicolons **/
   if find(&graphAttrs,';') EQ 0 
      AND find(&graphAttrs,',') NE 0 then do;
      graphAttrs = translate(&graphAttrs, ';', ',');
   end;
   else do;
      graphAttrs = &graphAttrs;
   end;

   /** Replace graphAttrs single quotes with double quotes **/
   if find(graphAttrs,'"') EQ 0 
      AND find(graphAttrs,"'") NE 0 then do;
      graphAttrs = translate(graphAttrs, '"', "'");
   end;


   /** Write graph attributes **/
   line = graphAttrs;
   put line;
   /** Write global node attributes **/
   if &nodesAttrs NE "" then do;
      line = "node[" || &nodesAttrs. || "]";
      put line;
   end;
   /** Write global link attributes **/
   if &linksAttrs NE "" then do;
      line = "edge[" || &linksAttrs. || "]";
      put line;
   end;

   /** Write nodes and per-node attributes **/
   if "&nodes." NE "_NULL_" then do;
      dsid=open("&nodes.") ;
      nodeVarNum=varnum(dsid, &nodesNode);
      nodeVarType=vartype(dsid, nodeVarNum);
      do while(fetch(dsid)=0);
         if nodeVarType EQ 'N' then nodeId=getvarn(dsid,nodeVarNum);
         else nodeId=getvarc(dsid,nodeVarNum);
         line=quote(strip(nodeId));
      
         nodeAttrs=&nodeAttrs;
         if nodeAttrs NE "" then do;
            /* Per-node attributes */
            line = CATS(line,"[");
            nAttr=countw(nodeAttrs,',');
            do i=1 to nAttr;
               kv=scan(nodeAttrs, i, ',');
               lhs = scan(kv, 1, '=');
               rhs = scan(kv, 2, '=');
               attrVarNum=varnum(dsid, rhs);
               attrVarType=vartype(dsid, attrVarNum);
               if attrVarType EQ 'N' then rhs=getvarn(dsid,attrVarNum);
               else rhs=getvarc(dsid,attrVarNum);
               line = CATS(line,lhs,' = "',rhs,'"');
               if i LT nAttr then line = CATS(line,",");
            end;
            line = CATS(line,"]");
         end;

         put line;
      end;

      dsid=close(dsid);
   end;

   /** Write links and per-link attributes **/ 
   if "&links." NE "_NULL_" then do;
      dsid=open("&links.") ;
      fromVarNum=varnum(dsid, &linksFrom);
      toVarNum=varnum(dsid, &linksTo);
      nodeVarType=vartype(dsid, fromVarNum);
      do while(fetch(dsid)=0);
         if nodeVarType EQ 'N' then do;
            fromId=getvarn(dsid,fromVarNum);
            toId=getvarn(dsid,toVarNum);
         end;
         else do;
            fromId=getvarc(dsid,fromVarNum);
            toId=getvarc(dsid,toVarNum);
         end;
         line=quote(strip(fromId)) || linkSep || quote(strip(toId));

         linkAttrs=&linkAttrs;
         if linkAttrs NE "" then do;
            /* Per-link attributes */
            line = CATS(line,"[");
            nAttr=countw(linkAttrs,',');
            do i=1 to nAttr;
               kv=scan(linkAttrs, i, ',');
               lhs = scan(kv, 1, '=');
               rhs = scan(kv, 2, '=');
               attrVarNum=varnum(dsid, rhs);
               attrVarType=vartype(dsid, attrVarNum);
               if attrVarType EQ 'N' then rhs=getvarn(dsid,attrVarNum);
               else rhs=getvarc(dsid,attrVarNum);
               line = CATS(line,lhs,' = "',rhs,'"');
               if i LT nAttr then line = CATS(line,",");
            end;
            line = CATS(line,"]");
         end;

         put line;
      end;
      dsid=close(dsid);
   end;

   put "}";

%mend;


/******************/
/* Parameters     */
/******************/
%let N_CLUSTERS_TO_SHOW=9;


/***
   This macro produces a graphviz visualization file for a given connected
   component
***/
%macro displayWhere(nodes,
                    links,
                    nodesLabel=namewrap,
                    fname=tmp.dot,
                    clause=,
                    colorBy=,
                    sizeBy=,
                    linkAttrs=,
                    directed=0);
%put "Doing display for &links.&clause.";

%if "&sizeBy" NE "" %then %do;
proc sql noprint;
   select max(&sizeBy.) into :max_size
   from &nodes.&clause.;
quit;
%end;

data mycas.tmpNodes;
   set &nodes.&clause.;
%if "&colorBy" NE "" %then %do;
   length color $12;
   if &colorBy. GT &N_CLUSTERS_TO_SHOW then color = 'gray';
   else color = put(&colorBy.,best12.);
%end;
%if "&sizeBy" NE "" %then %do;
   length size $12;
   size = &sizeBy./&max_size*10;
   fontsize = floor(&sizeBy./&max_size*100);
%end;
run;

data mycas.tmpLinks;
   set &links.&clause.;
run;

%let graphAttrs="outputorder='edgesfirst', layout=sfdp, overlap=prism, overlap_scaling=-5, labelloc='t', fontsize=30";

%if "&colorBy" NE "" %then %do;
   %let nodesAttrs=colorscheme=set19,style=filled,color=black;
   %let nodeAttrs=label=&nodesLabel,fillcolor=color;
%end;
%else %do;
   %let nodesAttrs=colorscheme=set19,style=filled;
   %let nodeAttrs=label=&nodesLabel;
%end;
%if "&sizeBy" NE "" %then %do;
   %let nodesAttrs=&nodesAttrs,shape=circle;
   %let nodeAttrs=&nodeAttrs,width=size,fontsize=fontsize;
%end;

data _NULL_;
   file "&_SASPROGRAMFILE/../../dot/&fname";
%graph2dot(
   nodes=mycas.tmpNodes,
   links=mycas.tmpLinks,
   nodesAttrs="&nodesAttrs",
   nodeAttrs="&nodeAttrs",
   linkAttrs="&linkAttrs",
   graphAttrs=&graphAttrs,
   directed=&directed
);
run;
%mend;


%macro displayClique(clique, nodes=mycas.nodes, links=mycas.links, cliqueNodes=mycas.outCliqueNodes);
%if "&VIYA_4"="1" %then %do;
   data mycas.reachSubset;
      set &cliqueNodes(where=(clique EQ &clique));
      reach = 1;
   run;
   
   /* Using reach to get the induced subgraph from the set of clique nodes */
   proc network
      nodes              = &nodes
      nodesSubset        = mycas.reachSubset
      links              = &links;
      nodesVar
         vars            = (namewrap);
      reach
         maxReach        = 0 /* requires Viya 4.0 */
         outReachNodes   = mycas.outReachNodes
         outReachLinks   = mycas.outReachLinks;
   run;
%end;
%else %do;
   data mycas.outReachNodes;
      set &cliqueNodes(where=(clique EQ &clique)) ;
      reach = 1;
   run;
   proc fedsql sessref=mySession;
      create table outReachLinks {options replace=true}  as
      select a.node as "from", b.node as "to"
      from outReachNodes as a
      cross join outReachNodes as b   
      where a.node < b.node
      ;
   quit;
%end;
%displayWhere(mycas.outReachNodes,
              mycas.outReachLinks,
              fname=clique_&clique..dot
);
%mend;



%macro displayReach(node, hops=1, nodes=mycas.nodes, links=mycas.links);
data mycas.reachSubset;
   node = "&node.";
   reach = 1;
   output;
   stop;
run;
proc network
   nodes              = &nodes
   nodesSubset        = mycas.reachSubset
   links              = &links;
   nodesVar
      vars            = (namewrap);
   reach
      maxReach         = &hops
      outReachNodes           = mycas.outReachNodes
      outReachLinks           = mycas.outReachLinks;
run;
%displayWhere(mycas.outReachNodes,
              mycas.outReachLinks,
              fname=reach_&node._&hops..dot
);
%mend;
