/* BEGINNING PART 1 */
/* === EDIT BELOW ====*/

/* account: CEPRIL */

/* Replace all occurrences of this project ID by yours and create a folder named after it */
%let project = cl_st1_querem ;

%let myfolder = &project ;

/* Replace all occurrences of this user ID by yours */
%let sasusername = u63529080 ;

%let whereisit = /home/&sasusername ;   /* online */

libname gelc "&whereisit/&myfolder";
/* files will NOT be saved to the folder above unless you put in 'gelc.'' before every destination */
/* otherwise files are going to the work library and not saved to the current folder */
/* this is needed to enable SGPLOT */
/* otherwise if your run SGPLOT, SAS will throw up an error message and stop working ... */

options fmtsearch=(work library);

/* enter number of factors to extract */
%let extractfactors = 8 ;

%let factorvars = fac1-fac&extractfactors ;

/* enter min loading cutoff */
%let minloading = .3 ;

/* enter min communality cutoff */
%let communalcutoff = .15 ;

DATA long1;
  INFILE "/home/&sasusername/&myfolder/data.txt" ;
  length file $ 8 word $ 8 count 8 ;
  input file $ word $ count ;
RUN;

proc sort data= long1; by file; run;
    
proc transpose data=long1 out=observed ;
    by file ;
    id word ;
    var count;
run;

data observed (DROP= _NAME_) ; set observed; run;

/* end read in data file in long format */

/* turn missing to zeros  */

proc stdize data = observed out=observed reponly missing=0; run;

proc datasets library=work nolist;
delete 
temp long1 rot  ;
run;

/* pearson correlation input */
/* matrix generated in Python */

proc datasets library=work nolist; delete corr  ; run;

DATA corr;
  INFILE "/home/&sasusername/&myfolder/corr.txt" ;
  length _TYPE_ $ 4 _NAME_ $ 8 v000001-v001000 8 ;
  input _TYPE_ $ _NAME_ $ v000001-v001000 ;
RUN;

/* turn missing correlation values to zeros */
proc stdize data = corr out=corr reponly missing=0; run;

data temp (DROP=_TYPE_); set corr; where _TYPE_="CORR" ; run;

PROC TRANSPOSE
DATA=temp (rename=_name_ = Name1)
OUT=temp2 (rename = (_name_ = Name2 col1=corr))
;
by name1;
var v000001-v001000;
RUN;

proc sort data=temp2 ; by corr ; run;
data neg ; set temp2 ; if corr < 0 ; if _N_ <=400 ; run;
proc sort data=temp2 ; by descending corr ; run;
data pos; set temp2; if corr < 1 and corr > 0; run;
/*data pos ; set temp2 ; if corr < 1 ; run;*/
data pos ; set pos ; if _N_ <= 400 ; run;
data temp3 (KEEP= Name1) ; set pos neg ; run ;
data temp4 ; set pos neg ; KEEP Name2; RENAME Name2=Name1 ; run ;
data temp5 ; set temp3 temp4 ; run;
proc sort data=temp5 out=selectedvars nodupkey; by Name1 ; run;

PROC EXPORT
  DATA= WORK.selectedvars
  DBMS=TAB
  OUTFILE="&whereisit/&myfolder/selectedvars.txt"
  REPLACE;
RUN;

%include "/home/&sasusername/&myfolder/word_labels_format.sas";

data topcorrs ; set pos neg ; format Name1 Name2 $lexlabels.; run ;

PROC EXPORT
  DATA= WORK.topcorrs
  DBMS=TAB
  OUTFILE="&whereisit/&myfolder/topcorrs.txt"
  REPLACE;
RUN;

/* tetrachoric correlation computation */

proc sql ;
    select Name1 into :names separated by ' ' from selectedvars ;
quit;

proc corr data = observed outplc = polychor polychoric noprint;
var &names ;
run;

proc stdize data = polychor out=polychor reponly missing=0; run;

/*
data GELC.polychor;
set  polychor;
run;

data WORK.polychor;
set  GELC.polychor;
run;
*/

PROC EXPORT
  DATA= WORK.polychor
  DBMS=TAB
  OUTFILE="&whereisit/&myfolder/polychor.tsv"
  REPLACE;
RUN;

/* number of observations IN THE DATA */
data _NULL_;
	if 0 then set observed nobs=n;
	call symputx('nobs',n);
	stop;
run;
%put nobs=&nobs ;

/* get variable list */

proc sql ;
    select Name1 into :names separated by ' ' from selectedvars ;
quit;

/* unrotated, before dropping low communalities */

proc datasets library=work nolist;
delete 
fout;
run;

ODS EXCLUDE NONE;
proc factor fuzz=0.3 data= polychor (type=corr) OUTSTAT= fout NOPRINT
method=principal 
plots=scree
mineigen=1
reorder 
heywood  
nfactors=100  
nobs=&nobs;  /* specify number of obs because this is missing from a corr matrix */
var &names  ;
run;

/* communalities ***/

data fout2;
    set fout (where=(_TYPE_="COMMUNAL"));
run;

proc transpose data=fout2 out=communal; id _TYPE_; run;

/* list vars to drop  */
proc sql ;
    select _name_ into :lowcomm separated by ' ' from communal
        where communal < &communalcutoff   ;
quit;

/* list vars to keep  */

ODS EXCLUDE NONE ;
proc sql NOPRINT;
    select _name_ into :highcomm separated by ' ' from communal
        where communal >= &communalcutoff   ;
quit;

/* save communalities to spreadsheet */

PROC SORT data=communal (keep= _name_ communal);   BY communal ; RUN;

PROC EXPORT
  DATA= WORK.communal
  DBMS=TAB
  OUTFILE="&whereisit/&myfolder/communalities.tsv"
  REPLACE;
RUN;

/* scree plot */

data fout2;
  set fout (where=(_TYPE_="EIGENVAL"));
run;

proc transpose data=fout2 out= fout3 (drop = _NAME_);
id _TYPE_;
run;

data fout4 ;
set fout3 ;
factor = _n_;
if factor <= 20 ;
run;

/* create the scree files */

ods listing gpath="&whereisit/&myfolder/";
ods graphics on / reset imagename="scree_1" imagefmt=png;
title "Scree plot";
proc sgplot data= fout4 ;
  series x=factor y=EIGENVAL / markers datalabel=EIGENVAL 
  markerattrs=(symbol = circle color = blue size = 10px);
   xaxis grid values=(1 TO 20) label='Factor';
   yaxis grid label='Eigenvalue';
   refline &extractfactors / axis = x lineattrs = (color = red pattern = dash);
run;
title;

ods listing gpath="&whereisit/&myfolder/";
ods graphics on / reset imagename="scree_2" imagefmt=png;
title "Scree plot";
proc sgplot data= fout4 ;
  series x=factor y=EIGENVAL / markers datalabel=factor
  markerattrs=(symbol = circle color = blue size = 10px);
  yaxis grid label='Eigenvalue';
  xaxis grid values=(1 TO 20) label='Factor';
  refline &extractfactors / axis = x lineattrs = (color = red pattern = dash);
run;
title;

/* rotated w/o low communalities */
/* do not use msa in factor analysis, it will give an error: 'matrix is singular' */

proc datasets library=work nolist;
delete 
rotatedfinal fout ;
run;

proc factor fuzz=0.3 data= polychor (type=corr) OUTSTAT= rotatedfinal NOPRINT
method=principal
mineigen=0
nfactors= &extractfactors
rotate=promax
heywood
nobs=&nobs;  /* specify number of obs because this is missing from a corr matrix */
var &highcomm  ;
run;


/* loadings table */

/*
 
https://stats.idre.ucla.edu/sas/output/factor-analysis/ 
Rotated Factor Pattern – This table contains the rotated factor loadings, which are the correlations between the variable and the factor.  Because these are correlations, possible values range from -1 to +1. 
in the outstat data file, the rotated factor pattern appears as PREROTAT. The standardized regression coefficients appear as PATTERN.
Use PREROTAT in the outstat data file. 

https://documentation.sas.com/?docsetId=statug&docsetTarget=statug_factor_details02.htm&docsetVersion=15.1&locale=en

PREROTAT: prerotated factor pattern.
PATTERN: factor pattern. (regression coefficients)

PREROTAT: prerotated factor pattern. =>   Stat.Factor.OrthRotFactPat
PATTERN: factor pattern. =>  Stat.Factor.ObliqueRotFactPat

*/

/*END PART 14*/
/* BEGINNING PART 15*/

/* labeling: https://stats.idre.ucla.edu/sas/modules/labeling/ */

%include "/home/&sasusername/&myfolder/word_labels_format.sas";

OPTIONS VALIDVARNAME=ANY;
data rotated2;
  set rotatedfinal (where=(_TYPE_="PATTERN"));
run;

proc transpose data=rotated2 out= rotated2 ;
id _NAME_ ;
run;

/* PRIMARY AND SECONDARY LOADINGS */

data abs ;
    set rotated2 ;
    array v Factor1-Factor&extractfactors  ;
    do over v ; 
      v = abs( v ) ; 
    end ;
run;

data primary (KEEP= _NAME_ load  );
set abs ;
 max=largest(1,of Factor1-Factor&extractfactors );
      if max = Factor1 AND max >= &minloading then do; load = 'fac1' ; end ;
 else if max = Factor2 AND max >= &minloading then do; load = 'fac2' ; end ;
 else if max = Factor3 AND max >= &minloading then do; load = 'fac3' ; end ;
 else if max = Factor4 AND max >= &minloading then do; load = 'fac4' ; end ;
 else if max = Factor5 AND max >= &minloading then do; load = 'fac5' ; end ;
 else if max = Factor6 AND max >= &minloading then do; load = 'fac6' ; end ;
 else if max = Factor7 AND max >= &minloading then do; load = 'fac7' ; end ;
 else if max = Factor8 AND max >= &minloading then do; load = 'fac8' ; end ;
 else if max = Factor9 AND max >= &minloading then do; load = 'fac9' ; end ;
 else if max = Factor10 AND max >= &minloading then do; load = 'fac10' ; end ;
run;

data secondary (KEEP= _NAME_ load secondary );
set abs ;
 max=largest(2,of Factor1-Factor&extractfactors );
      if max = Factor1 AND max >= &minloading then do; load = 'fac1' ; secondary = 1 ; end ;
 else if max = Factor2 AND max >= &minloading then do; load = 'fac2' ; secondary = 1 ; end ;
 else if max = Factor3 AND max >= &minloading then do; load = 'fac3' ; secondary = 1 ; end ;
 else if max = Factor4 AND max >= &minloading then do; load = 'fac4' ; secondary = 1 ; end ;
 else if max = Factor5 AND max >= &minloading then do; load = 'fac5' ; secondary = 1 ; end ;
 else if max = Factor6 AND max >= &minloading then do; load = 'fac6' ; secondary = 1 ; end ;
 else if max = Factor7 AND max >= &minloading then do; load = 'fac7' ; secondary = 1 ; end ;
 else if max = Factor8 AND max >= &minloading then do; load = 'fac8' ; secondary = 1 ; end ;
 else if max = Factor9 AND max >= &minloading then do; load = 'fac9' ; secondary = 1 ; end ;
 else if max = Factor10 AND max >= &minloading then do; load = 'fac10' ; secondary = 1 ; end ;
run;

proc sort data=rotated2 ; by _NAME_ ; run;
proc sort data=primary ; by _NAME_ ; run;
proc sort data=secondary ; by _NAME_ ; run;

data temp1 ;
merge rotated2 primary ;
by _NAME_ ;
run;

data temp2 ;
merge rotated2 secondary ;
by _NAME_ ;
run;

data temp3;
set temp2 temp1;
run;

/* loadtable with primary and secondary loadings */

ods html file="&whereisit/&myfolder/loadtable.html"; 
%macro create(howmany);
%do i=1 %to &howmany;

title "LOADINGS TABLE";
title2 "Factor &i pos" ;
data temp4;
  set temp3 ;
  where load= "fac&i" and Factor&i >= 0  ;
  if secondary = 1 then do; l = '(' ; r = ')' ; end; 
proc sort;
  by descending Factor&i ;
proc print ; FORMAT _NAME_ $lexlabels.; var l _NAME_ Factor&i r ;
run;

title "Factor &i neg" ;
data temp4;
  set temp3 ;
  where load= "fac&i" and Factor&i < 0  ;
  if secondary = 1 then do; l = '(' ; r = ')' ; end; 
proc sort;
  by  Factor&i ;
proc print ; FORMAT _NAME_ $lexlabels.; var l _NAME_ Factor&i r ;
run;

%end;
%mend create;
%create(&extractfactors) 
ods html close;
quit;

PROC EXPORT
  DATA= work.temp3
  DBMS=TAB
  OUTFILE="&whereisit/&myfolder/rotated.tsv"
  REPLACE;
RUN;

/* factor scores */
/* no standardizing the data because it is ranked */

/* the vars are all listed in a single column, so no need to rotate */

proc datasets library=work nolist;
delete 
fout fout2 fout3 fout4 ;
run;

/*begin macro*/
%macro create(howmany);
%do i=1 %to &howmany;

data fac&i.p;
  set temp3 ;
  where load= "fac&i" and Factor&i >= 0  ;
  pole = 1;
run;

data fac&i.n;
  set temp3 ;
  where load= "fac&i" and Factor&i < 0  ;
  pole = -1;
run;

%end;
%mend create;
%create(&extractfactors) 
quit;
/* end macro */

proc sql NOPRINT;
    select memname into :names separated by ' ' from dictionary.tables 
    where libname = 'WORK' AND  memname like "FAC%"  ;
quit;

/* discard variables loading as secondary to compute factor scores */
data poles ;
set &names ;
if secondary NE 1;
run;

proc transpose data=poles out=score;
  by load ;
  id _NAME_ ;
  var pole;
run;

data score;
  _type_='SCORE';
  set score;
  drop _name_;
  rename load=_name_;
run;

proc score data=observed score=score out=scores; run;

data scores_only 
(keep =  file &factorvars ) ; 
set scores ; 
run;

PROC EXPORT
  DATA= WORK.scores
  DBMS=TAB
  OUTFILE="&whereisit/&myfolder/&project._scores.tsv"
  REPLACE;
RUN;

PROC EXPORT
  DATA= WORK.scores_only
  DBMS=TAB
  OUTFILE="&whereisit/&myfolder/&project._scores_only.tsv"
  REPLACE;
RUN;

/* varclus , a kind of second-order factor analysis */

ods graphics on / reset imagename="varclus" imagefmt=png;
ods html path="&whereisit/&myfolder" gpath="&whereisit/&myfolder/" file="varclus.html";
PROC VARCLUS data=scores_only cov minclusters=1 outtree=tree ;
var fac1-fac&extractfactors ;
run;
ods html close;


/* pearson vs tetrachoric correlations */
/*
data pearson (DROP=_TYPE_); set corr; where _TYPE_="CORR" ; run;
data tetra (DROP=_TYPE_); set gelc.polychor ; where _TYPE_="CORR" ; 
rename v000001-v001000 = t000001-t001000 ;
run;

data temp ;
merge pearson tetra;
by _NAME_ ;
IF t000001 NE . ;
run;

proc corr ; 
var v000001 - v000010 v000999; 
with t000001 - t000010 t000999; 
run;
*/


/* dates */

DATA dates ;
  INFILE "/home/&sasusername/&myfolder/dates.txt" ;
  length file $ 8 year 8 month $ 8 ;
  input file $ year month $ ;
  proc sort; by file ;
RUN;

/* all metadata */

data temp2;
merge scores (in=a) dates (in=b) ;
by file;
if (a and b) then output;
proc sort; by file;
run;

proc sort data=temp2 out=scores_metadata nodupkey; 
 by file ; 
run;

data scores_metadata;
set scores_metadata ;
IF year >= 2020;
IF month NE '2020-01' ;
run;


/*
proc print data= temp (firstobs=71 obs=72); run;
*/

/* fix variable order */
data scores_metadata ;
 retain file year month &factorvars v000001-v001000 ;
 set scores_metadata ;
run; 

proc datasets library=work nolist;
delete 
temp1-temp6 rot temp want fclus_1-fclus_20 ;
run;

/* GLM Analysis of variance */

/* begin macro */
ods html file="&whereisit/&myfolder/glm_meta.html"; 
%macro create(howmany);
%do i=1 %to &howmany;
ods graphics off; 
%macro repeat_glm(var=);
proc glm data=scores_metadata;
	title GLM for dataset = &project user &var f&i ;
	class &var ;
	model fac&i = &var ;
	means &var ;
ods table FitStatistics=rsq_&var._fac&i;
/*ods table Means=means_&var._fac&i;*/
run;
ods trace off;
%mend repeat_glm;

%repeat_glm(var=month)
%repeat_glm(var=year)

ods graphics on;
%end;
%mend create;
%create( &extractfactors ) /* number of factors extracted */ 
ods html close; 
quit;
/* end macro */


/* R-Square table */

ods html file="&whereisit/&myfolder/rsquare.html"; 

%let first = %scan(&factorvars, 1, '-');
%let last = %scan(&factorvars, 2, '-');

title "Month" ;
proc print data= temp NOOBS; format RSquare 8.3 ; run;
title ;

data temp (KEEP= Factor RSquare Percent);
retain Factor RSquare Percent;
set WORK.rsq_year_&first.-WORK.rsq_year_&last ;
Factor = substr(Dependent, 4, 1);
Percent = RSquare * 100;
run;

title "Year" ;
proc print data= temp NOOBS; format RSquare 8.3 ; run;
title ;

ods html close;


/* mean dimension scores bar charts */
/* https://blogs.sas.com/content/graphicallyspeaking/2016/11/27/getting-started-sgplot-part-2-vbar/ */

/* mean dimension scores charts for year */

ods html file="&whereisit/&myfolder/year_means.html"; 
%macro create(howmany);
%do i=1 %to &howmany;
ods output summary=m_&i; 
proc means data=scores_metadata mean; var fac&i ; class year ; run;
data m_&i;
set m_&i;
format fac&i._mean 8.2;
run;
%end;
%mend create;
%create( &extractfactors ) /* number of factors extracted */ 
ods html close;
quit;

/* begin macro */
%macro create(howmany);
%do i=1 %to &howmany;
%let var = year ;
proc sql noprint;
    select rsquare into :names separated by ' ' from rsq_&var._fac&i ;
quit;
data temp;
set rsq_&var._fac&i ;
Percent = RSquare * 100;
run;
proc sql noprint;
    select percent into :perc separated by ' ' from temp ;
quit;
ods listing gpath="&whereisit/&myfolder/";
ods graphics on / reset imagename="year_dim_&i" imagefmt=png;
title height=12pt "Mean dimension &i scores for year";
proc sgplot data = m_&i ;
series x = year y = Fac&i._mean / markers datalabel=Fac&i._mean smoothconnect datalabelattrs=(size=12);
refline 0 / axis = y lineattrs = (color = gray pattern = dash);
 YAXIS LABEL = 'Mean dim. score'  labelattrs=(size=12pt color="black") 
                           valueattrs=(size=12pt color="black");
 XAXIS LABEL = 'Year'  labelattrs=(size=12pt color="black") 
                           valueattrs=(size=12pt color="black") ;
 INSET  ( "R(*ESC*){sup '2'}" = "&names" "%" = "&perc" ) / BORDER TEXTATTRS = (SIZE=10 COLOR=black);
run; 

ods listing gpath="&whereisit/&myfolder/";
ods graphics on / reset imagename="year_confinterv_dim_&i" imagefmt=png;
title height=12pt "Mean dimension &i scores for year ";
proc sgplot data=scores_metadata;
   vline year / response=fac&i stat=mean limitstat=stderr markers ;
   yaxis label='Mean dim. score';
   INSET  ( "R(*ESC*){sup '2'}" = "&names" "%" = "&perc" ) / BORDER TEXTATTRS = (SIZE=10 COLOR=black);
run;
%end;
%mend create;
%create( &extractfactors ) /* number of factors extracted */ 
quit;
/* end macro */

/* mean dimension scores charts for month */

/* begin macro */
ods html file="&whereisit/&myfolder/month_means.html"; 
%macro create(howmany);
%do i=1 %to &howmany;
ods output summary=m_&i; 
proc means data=scores_metadata mean ; var fac&i ; class month ; run;
%end;
%mend create;
%create( &extractfactors ) /* number of factors extracted */ 
ods html close;
quit;
/* end macro */

/* begin macro */
%macro create(howmany);
%do i=1 %to &howmany;
data m_&i ;
set m_&i ;
format fac&i._mean 8.2 ;
run;
%end;
%mend create;
%create( &extractfactors ) /* number of factors extracted */ 
quit;
/* end macro */

/* begin macro */
%macro create(howmany);
%do i=1 %to &howmany;
%let var = month ;
proc sql noprint;
    select rsquare into :names separated by ' ' from rsq_&var._fac&i ;
quit;
data temp;
set rsq_&var._fac&i ;
Percent = RSquare * 100;
run;
proc sql noprint;
    select percent into :perc separated by ' ' from temp ;
quit;
ods listing gpath="&whereisit/&myfolder/";
ods graphics on / reset imagename="month_dim_&i" imagefmt=png;
title height=12pt "Mean dimension &i scores for month";
proc sgplot data = m_&i ;
series x = month y = Fac&i._mean / markers datalabel=Fac&i._mean smoothconnect ;
refline 0 / axis = y lineattrs = (color = gray pattern = dash);
refline "202003" / axis = x label="2020" lineattrs = (color = white pattern = dash);
refline "202101" / axis = x label="2021" lineattrs = (color = red pattern = dash);
refline "202201" / axis = x label="2022" lineattrs = (color = red pattern = dash);
 YAXIS LABEL = 'Mean dim. score'  labelattrs=(size=12pt color="black") 
                           valueattrs=(size=12pt color="black"); 
 XAXIS LABEL = 'Month'  labelattrs=(size=4pt color="black") 
                           valueattrs=(size=4pt color="black")  ;
 xaxis DISPLAY=(NOLABEL) grid type=discrete discreteorder=data valueattrs=(color=black size=8pt); 
 INSET  ( "R(*ESC*){sup '2'}" = "&names" "%" = "&perc" ) / BORDER TEXTATTRS = (SIZE=10 COLOR=black);
run; 
%end;
%mend create;
%create( &extractfactors ) /* number of factors extracted */ 
quit;
/* end macro */

/* mixed methods */
/* no fixed effect, all random effects -- ie 'model fac&i = ' line has no variable */ 
/* no fixed effect: https://www.stat.purdue.edu/~boli/stat512/lectures/topic9.pdf , pp.6-7*/
/* conversation removed because of error due to too many levels, insufficient memory */
ods html file="&whereisit/&myfolder/mixed.html"; 
ods graphics off;
%macro create(howmany);
%do i=1 %to &howmany;
ods select CovParms ;
ods output covparms=mixed&i; 
proc mixed data=scores_metadata covtest;
	title PROC MIXED = &project f&i ;
      class 
      followers_rank post_rank likes_rank replies_rank wcount_rank topic month year 
            ;
      model 
      fac&i = 
      ;
      random 
      followers_rank post_rank likes_rank replies_rank wcount_rank topic month year 
      ;
run;
%end;
%mend create;
%create( &extractfactors ) /* number of factors extracted */ 
ods html close; 
ods graphics on;
quit;

/* begin macro */
%macro create(howmany);
%do i=1 %to &howmany;
data mixed&i (KEEP= covparm estimate); set mixed&i ; format estimate 8.5 ; run;
proc transpose data= mixed&i out= covar&i; id covparm; run;
data covar&i (KEEP= month -- unaccountedperc ); 
  set covar&i; 
  sumcovar=(month + year + residual);
  monthperc=( (month / sumcovar ) * 100 );
  yearperc=( (year / sumcovar ) * 100 );
  unaccountedperc=( (residual/ sumcovar ) * 100 );
  
    label  
        monthperc = 'Month'  
        yearperc = 'Year'  
        unaccountedperc = 'Unaccounted for' 
        ;
run;
%end;
%mend create;
%create( &extractfactors ) /* number of factors extracted */ 
quit;
/* end macro */


/* begin macro */
%macro create(howmany);
%do i=1 %to &howmany;
proc transpose data= covar&i out= covar&i; run;
data covar&i; set covar&i ; format COL1 F8.2; run;

ods listing gpath="&whereisit/&myfolder/";
ods graphics on / reset imagename="covar_factor_&i" imagefmt=png;
proc SGPLOT data=covar&i ;
 vbarparm category=_LABEL_ response=COL1 / datalabel = COL1 datalabelattrs= (Size=12) ;
 title height=12pt "Random effects dim. &i ";
 YAXIS LABEL = '%' GRID VALUES = (0 TO 100 BY 10)
                           labelattrs=(size=12pt color="black") 
                           valueattrs=(size=12pt color="black"); 
 XAXIS LABEL = 'Variables' labelattrs=(size=12pt color="black") 
                           valueattrs=(size=12pt color="black") ;
run;

run;
%end;
%mend create;
%create( &extractfactors ) /* number of factors extracted */ 
quit;
/* end macro */

/* corpus size */

DATA wcount ;
  INFILE "/home/&sasusername/&myfolder/wcount.txt" ;
  length file $ 8 wcount 8 ;
  input file $ wcount ;
  proc sort; by file ;
RUN;

data scores_wcount ;
merge scores_metadata (in=a) wcount (in=b) ;
by file;
if (a and b) then output;
run;

/* 
%let var = year ;
*/

/* begin macro */
ods html file="&whereisit/&myfolder/corpus_size.html"; 
%macro repeat_do(var=);
title "Corpus size by &var" ;
ods output summary = size_&var;
proc means data = scores_wcount n sum mean std ; 
var wcount; 
class &var ;
run;
%mend repeat_do;
%repeat_do(var=year)
%repeat_do(var=month)
quit;
title "Corpus size : overall" ;
proc means data = scores_wcount n sum mean std ; 
var wcount; 
run;
ods html close;
/* end macro */

/* begin macro */
%macro repeat_do(var=);
ods listing gpath="&whereisit/&myfolder/";
ods graphics on / reset imagename="corpus_size_&var._texts" imagefmt=png;
proc sgplot data=size_&var ;
  vbar &var / response=nobs 
            barwidth=0.5
            fillattrs=graphdata4 
            baselineattrs=(thickness=0) 
            datalabel = nobs datalabelattrs=(size=12) ;
  title height=12pt "Corpus size by &var (texts)";
  yaxis label= "Texts"  ranges=(min-500 5000-max);
  xaxis label= "Year" labelattrs=(size=10);
run;
ods graphics on / reset imagename="corpus_size_&var._words" imagefmt=png;
proc sgplot data=size_&var ;
  vbar &var / response=wcount_sum 
            barwidth=0.5
            fillattrs=graphdata4 
            baselineattrs=(thickness=0) 
            datalabel = wcount_sum datalabelattrs=(size=12) DATALABELFITPOLICY=NONE;
  title height=12pt "Corpus size by &var (words)";
  yaxis label= "Words" ranges=(min-5000 500000-max) ;
  xaxis label= "Year" labelattrs=(size=10);
run;
%mend repeat_do;
%repeat_do(var=year)
quit;
/* end macro */

/* begin macro */
%macro repeat_do(var=);
ods listing gpath="&whereisit/&myfolder/";
ods graphics on / reset imagename="corpus_size_&var._texts" imagefmt=png;
proc sgplot data=size_&var ;
  refline "202003" / axis = x label="2020" lineattrs = (color = white pattern = dash);
  refline "202101" / axis = x label="2021" lineattrs = (color = red pattern = dash);
  refline "202201" / axis = x label="2022" lineattrs = (color = red pattern = dash);
  vbar &var / response=nobs 
            barwidth=0.5
            fillattrs=graphdata4 
            baselineattrs=(thickness=0) 
            datalabel = nobs datalabelattrs=(size=6) DATALABELFITPOLICY=rotate;
  title height=12pt "Corpus size by &var (texts)";
  yaxis label= "Texts" ranges=(min-10000 20000-max);
  xaxis label= "Month" labelattrs=(size=10);
run;
ods graphics on / reset imagename="corpus_size_&var._words" imagefmt=png;
proc sgplot data=size_&var ;
  refline "202003" / axis = x label="2020" lineattrs = (color = white pattern = dash);
  refline "202101" / axis = x label="2021" lineattrs = (color = red pattern = dash);
  refline "202201" / axis = x label="2022" lineattrs = (color = red pattern = dash);
  vbar &var / response=wcount_sum 
            barwidth=0.5
            fillattrs=graphdata4 
            baselineattrs=(thickness=0) 
            datalabel = wcount_sum datalabelattrs=(size=6) DATALABELFITPOLICY=rotate;
  title height=12pt "Corpus size by &var (words)";
  yaxis label= "Words" ranges=(min-2000 10000-max) ;
  xaxis label= "Month" labelattrs=(size=10);
run;
%mend repeat_do;
%repeat_do(var=month)
quit;
/* end macro */



/* factor vs topic correlations */

/* begin macro */
ods html file="&whereisit/&myfolder/mixed.html"; 
%macro create(howmany);
%do i=0 %to &howmany;

data temp;
set scores_metadata ;
if topic = "t&i" ;
run;

title "Correlations for topic &i with factors" ;
ods output PearsonCorr= corr&i ;
proc corr  data=temp; 
var topicscore ;
with &factorvars ;
run;

%end;
%mend create;
%create( 4 ) /* number of last topic  */ 
ods html close;
quit;
/* end macro */


/* begin macro */
%macro create(howmany);
%do i=0 %to &howmany;
data cat ;
set corr&i;
  nozero = substr(ptopicscore, 2, 4);
IF ptopicscore < .05 AND ptopicscore > .001 then character_var = put(nozero, 8.3);
IF ptopicscore >= .05 then character_var = 'NS';
IF ptopicscore <= .001 then character_var = '<.001';
var3 = catx('=', Variable, character_var);
run;
proc sql noprint;
    select var3 into :names separated by ', ' from cat ;
quit;
ods listing gpath="&whereisit/&myfolder/";
ods graphics on / reset imagename="topic_&i._factor_corr" imagefmt=png;
proc SGPLOT data=corr&i ;
 vbarparm category=Variable response=topicscore / fillattrs= (color=CX024ae6) datalabel = topicscore datalabelattrs= (Size=12) ;
 title height=12pt "Topic &i score correlations with factor scores ";
  YAXIS LABEL = 'Pearson corr.' GRID VALUES = (-1 TO 1 BY .1)
                           labelattrs=(size=12pt color="black") 
                           valueattrs=(size=12pt color="black"); 
 XAXIS LABEL = 'Factors' labelattrs=(size=12pt color="black") 
                           valueattrs=(size=12pt color="black") ;
                           
 INSET  ( "p" ="&names" ) / BORDER TEXTATTRS = (SIZE=10 COLOR=blue);
run;
%end;
%mend create;
%create( 4 ) /* number of last topic  */ 
ods html close;
quit;
/* end macro */

proc datasets library=work nolist;
delete 
corr0-corr19 covar1-covar8 mixed1-mixed8
fac1p fac2p fac3p fac4p fac5p fac6p fac7p fac8p
fac1n fac2n fac3n fac4n fac5n fac6n fac7n fac8n
;
run;

/* canonical correlation with user profiles */

OPTIONS VALIDVARNAME=ANY;
FILENAME IN "/home/&sasusername/cl_st1_querem_profiles/cl_st1_querem_profiles_scores_only.tsv";
PROC IMPORT OUT= users
     DATAFILE= IN
     DBMS=DLM REPLACE;
     GETNAMES=YES;
          delimiter='09'x;
          	   datarow=2;
          	        GUESSINGROWS=1000;
RUN;

/* select var names to rename , users */
data temp ;
set users;
if _N_ <= 1 ;
run;
proc transpose data= temp out= temp; 
run;
proc sql noprint;
    select cats(_name_,'= u',_name_) into :userren separated by ' ' from temp ;
quit;

/* select var names to rename , texts */
data temp (keep= fac1-fac&extractfactors );
set scores_metadata;
if _N_ <= 1 ;
run;
proc transpose data= temp out= temp; 
run;
proc sql noprint;
    select cats(_name_,'= t',_name_) into :textren separated by ' ' from temp ;
quit;

/* rename vars for user scores */
data users (RENAME= ( &userren ));
set users;
proc sort; by user;
run;

/* rename vars for text scores */
data texts (RENAME= ( &textren ));
set scores_metadata;
run;

data texts (KEEP= file user tfac1-tfac&extractfactors );
set texts;
proc sort ; by user;
run;

/* select last user factor number */
data temp ;
set users;
if _N_ <= 1 ;
run;
proc transpose data= temp out= temp; 
run;
data temp ;
set temp;
proc sort ; by descending _name_  ;
run;
data temp; set temp; if _N_ <= 1 ; run;
proc sql noprint;
    select substr(_NAME_, 5,1) into :lastcan from temp ;
quit;

/* prepare data */
data merged;
merge texts (in=a) users (in=b) ;
by user;
if (a and b) then output;
run;

proc means data=merged
    NMISS;
run;

data merged;
 set merged;
 if cmiss(of _all_) then delete;
run;

ods html file="&whereisit/&myfolder/canonical.html"; 
ods output CanStructureVCan=cv ;
ods output CanStructureWCan=cw ;
ods output cancorr=cc ;
ods output redundancy=redund ;
proc cancorr data=merged out=canout redundancy
  vprefix=text vname="Text dims." 
  wprefix=users wname="User dims." ;
  var tfac1-tfac&extractfactors ;
  with ufac1-ufac&lastcan ;
  run;
ods html close;

data temp (KEEP= number);
set cc;
if probf < .05 ;
run;

/* grab the number of significant correlations into a variable*/
proc sql noprint;
    select max(number) as sigcorr into :sigcorr from temp;
quit;

%put signficant correlations = &sigcorr ;

/* begin macro */
ods html file="&whereisit/&myfolder/canonical_pairs.html"; 
title1 "Signficant correlations = &sigcorr ";
%macro create(howmany);
%do i=1 %to &howmany;
data tempv&i (KEEP=corr dims variable);
set cv ;
IF _TYPE_ = 'VAR';
IF text&i >= .3 OR text&i <= -.3 ;
dims = 'text' ;
rename text&i = corr ;
run;
data tempw&i (KEEP=corr dims variable);
set cw ;
IF _TYPE_ = 'WITH';
IF users&i >= .3 OR users&i <= -.3;
dims = 'user' ;
rename users&i = corr ;
run;
data temp;
set tempv&i tempw&i ;
run;
title2 "Pair # &i of canonical variates";
proc print data=temp;
run;
title1;
title2;
%end;
%mend create;
%create( &sigcorr ) /* number of significant correlations */ 
ods html close;
quit;
/* end macro */


/* variation accounted for by canonical variates */

data redund ;
set redund ;
if canvarnumber = &sigcorr  ;
run;
data redund (KEEP= ownvar oppvar candim);
set redund (obs=2);
ownvar = cumproportion * 100 ;
oppvar = oppcumproportion * 100;
format ownvar 8.2 oppvar 8.2;
IF _N_ = 1 then candim = 'Text';
IF _N_ = 2 then candim = 'User';
label candim = 'Canonical variate';
run;

proc transpose data=redund out=long;
  by candim;
run;
data temp (KEEP= Variable Variation With);
set long;
rename COL1 = Variation ;
IF candim = 'Text' AND _NAME_ = 'ownvar' then With = 'Text'; 
IF candim = 'Text' AND _NAME_ = 'oppvar' then With = 'User'; 
IF candim = 'User' AND _NAME_ = 'ownvar' then With = 'User'; 
IF candim = 'User' AND _NAME_ = 'oppvar' then With = 'Text'; 
rename candim = Variable ;
run;

ods listing gpath="&whereisit/&myfolder/";
ods graphics on / reset imagename="cancorr_variation" imagefmt=png;
proc sgplot data=temp;
  vbar Variable / response=Variation group=With nostatlabel groupdisplay=cluster  
         datalabel = Variation datalabelattrs= (Size=10) barwidth=0.6 ;
  xaxis label = '% Variation accounted for' labelattrs=(size =12);
  yaxis grid ;
  yaxis ranges=(min-1.5 71-max) grid values= (0 to 85 by 5);
  title height=12pt 'Canonical correlation';
run;

/*  xaxis display=(nolabel); */

/* collect var names */
data temp (DROP= file  user );
set canout ;
if _n_ <=1 ;
run;
proc transpose data=temp out= rot ; run;
data temp; set rot; 
  if substr(_NAME_,1,4) = 'text' then output;
  proc sort ; by descending _NAME_  ;
run;
data temp2  ; set temp; if _N_ = 1; 
lastcovar = substr(_NAME_,5,1);
run;
proc sql noprint;
    select lastcovar into :lastcovar  from temp2 ;
quit;

ods html file="&whereisit/&myfolder/canonical_pairs_correlation.html"; 
proc corr data = canout ;
var text1-text&lastcovar ;
with users1-users&lastcovar ;
run;
ods html close;

PROC EXPORT
  DATA= WORK.canout
  DBMS=TAB
  OUTFILE="&whereisit/&myfolder/canonical.tsv"
  REPLACE;
RUN;

proc datasets library=work nolist;
delete 
rsq_followers_rank_fac1-rsq_followers_rank_fac8  
rsq_likes_rank_fac1-rsq_likes_rank_fac8  
rsq_post_rank_fac1-rsq_post_rank_fac8  
rsq_replies_rank_fac1-rsq_replies_rank_fac8  
rsq_topic_fac1-rsq_topic_fac8  
rsq_wcount_rank_fac1-rsq_wcount_rank_fac8  
rsq_year_fac1-rsq_year_fac8  
rsq_month_fac1-rsq_month_fac8 
fac1p fac2p fac3p fac4p fac5p fac6p fac7p fac8p
fac1n fac2n fac3n fac4n fac5n fac6n fac7n fac8n
;
run;


/**** ZIP UP THE FILES INTO zip/<this folder>.zip ****/
/* list all files in your directory */

/* name the zip file you want to zip into, e.g. */
%let addcntzip = /home/u63529080/zip/output_&project..zip;

FILENAME temp "&addcntzip";
DATA _NULL_;
  rc=FDELETE('temp');
RUN;

data filelist;
run;
data filelist;
  length root dname $ 2048 filename $ 256 dir level 8;
  input root;
  retain filename dname ' ' level 0 dir 1;
cards4;
/home/u63529080/cl_st1_querem
;;;;
run;

data filelist;
  modify filelist;
  rc1=filename('tmp',catx('/',root,dname,filename));
  rc2=dopen('tmp');
  dir = 1 & rc2;
  if dir then 
    do;
      dname=catx('/',dname,filename);
      filename=' ';
    end;
  replace;

  if dir;

  level=level+1;

  do i=1 to dnum(rc2);
    filename=dread(rc2,i);
    output;
  end;
  rc3=dclose(rc2);
run;

proc sort data=filelist;
  by root dname filename;
run;

/* print out files list too see if you have all you want */
proc print data=filelist;
run;

data _null_;

  set filelist; /* loop over all files */
  if dir=0;

  rc1=filename("in" , catx('/',root,dname,filename), "disk", "lrecl=1 recfm=n");
  rc1txt=sysmsg();
  rc2=filename("out", "&addcntzip.", "ZIP", "lrecl=1 recfm=n member='" !! catx('/',dname,filename) !! "'");
  rc2txt=sysmsg();

  do _N_ = 1 to 6; /* push into the zip...*/
    rc3=fcopy("in","out");
    rc3txt=sysmsg();
    if fexist("out") then leave; /* if success leave the loop */
    else sleeprc=sleep(0.5,1); /* if fail wait half a second and retry (up to 6 times) */
  end;

  rc4=fexist("out");
  rc4txt=sysmsg();

/* just to see errors */
  put _N_ @12 (rc:) (=);

run;

/* delete all png, html and tsv files, because they've been zipped */

/* Read files in a folder */

%let path=&whereisit/&myfolder;
FILENAME _folder_ "%bquote(&path.)";
data filenames(keep=memname);
  handle=dopen( '_folder_' );
  if handle > 0 then do;
    count=dnum(handle);
    do i=1 to count;
      memname=dread(handle,i);
      if scan(memname, 2, '.')='png' 
      OR scan(memname, 2, '.')='html' 
      OR scan(memname, 2, '.')='tsv' 
      then output filenames;
    end;
  end;
  rc=dclose(handle);
run;
filename _folder_ clear;

/* delete files identified in above step */
data _null_;
set filenames;
fname = 'todelete';
rc = filename(fname, quote(cats("&path",'/',memname)));
rc = fdelete(fname);
rc = filename(fname);
run;



