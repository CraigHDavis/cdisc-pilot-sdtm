/*******************************************************************************************************
* Study:             CDISCPILOT01
* Program Name:      process_dm_raw_final.sas
* Purpose:           Recreate SDTM DM table from raw Pharmaverse input
*
* Input Datasets:    Imported raw datasets: dm_temp, ds_temp, ec_temp
* Source:            Pharmaverseraw R package,version 0.1.1
* Output Datasets:   my_data.dm
* Output Files:      None
*
* Macros Called:     None
*
* Author:            Craig Davis
* Date Created:      11/18/2026
* SAS Version:       9.4
*
* Details:           Program transforms the dm_raw data into the DM table and incorporates variables
                     from ds_temp and ec_temp into it.  Also, the program compares the recreated 
                     and official DM table and highlights differences.
*/            
options mprint mlogic symbolgen;

%let home_path=/<your-project-folder>;

libname my_data "&home_path/cdisc_pilot/sdtm/sdtm_my_tables";
libname actual "&home_path/cdisc_pilot/sdtm/sdtm_actual_tables";

proc format;
value $ armfmt
  'Placebo'='Placebo'
  'Screen Failure'='Screen Failure'
  'Xan High'='Xanomeline High Dose'	
  'Xan Low'='Xanomeline Low Dose'
;
run;
/* The datastep below tranforms the import raw dm table.*/
data dm_temp(drop=patnum study it_age it_sex it_ethnic it_race _country 
                  planned_arm planned_armcd actual_arm actual_armcd ic_dt);
attrib
 STUDYID  length=$12 label="Study Identifier"                                                 
 DOMAIN   length=$2  label="Domain Abbreviation"                                                                                                                 
 USUBJID  length=$11 label="Unique Subject Identifier"                                        
 SUBJID   length=$4  label="Subject Identifier for the Study"                                                                                                                                                                                                                                                     
 SITEID   length=$3  label="Study Site Identifier"                                                                                                                       
 AGE                 label="Age"                                                                                                                                         
 AGEU     length=$6  label="Age Units"                                                                                                                                    
 SEX      length=$1  label="Sex"                                                                                           
 RACE     length=$78 label="Race"                                                                                                                                                            
 ETHNIC   length=$25 label="Ethnicity"                                                                                                                                    
 ARMCD    length=$8  label="Planned Arm Code"                                                                                                                            
 ARM      length=$20 label="Description of Planned Arm"                                                                                                                  
 ACTARMCD length=$8  label="Actual Arm Code"                                                                                                                              
 ACTARM   length=$20 label="Description of Actual Arm"                                                                                                                  
 COUNTRY  length=$3  label="Country"                                                                                                                                   
 DMDTC    length=$10 label="Date/Time of Collection"                                                                                                                      
 RFICDTC  length=$20 label=label="Date/Time of Informed Consent"                                        
;
set my_data.dm_temp(rename=(country=_country));
country=_country;
domain='DM';
studyid=study;
usubjid=cats(substr(study,11,2),"-",patnum);
siteid=scan(patnum,1,"-");
subjid=scan(patnum,2,"-");
age=it_age;
ageu="YEARS";
sex=upcase(substr(it_sex,1,1));
ethnic=upcase(it_ethnic);
race=upcase(it_race);
arm=put(planned_arm, armfmt.);
armcd=planned_armcd;
actarm=put(actual_arm, armfmt.);
actarmcd=actual_armcd;
dmdtc=put(input(col_dt,mmddyy10.),e8601da.);
rficdtc=' ';
run;
/*Checks the col_dt to see if it includes partial dates*/
proc sql;
select
col_dt
from dm_temp
where index(col_dt,"T")>0;
quit;
/*Code below performs preliminary transformations of ds_temp variables*/
data ds_temp(keep=usubjid instance it_dsterm it_dsdecod othersp dsdtcoln dsdtcolc deathdtc 
dsstdatn dsstdatn dsstdatc dstmcol);
length usubjid $11.;
set my_data.ds_temp;
studyid=study;
usubjid=cats(substr(study,11,2),"-",patnum);
dsdtcoln=input(dsdtcol,mmddyy10.);
dsdtcolc=put(input(dsdtcol,mmddyy10.),e8601da.);
deathdtc=put(input(deathdt,mmddyy10.),e8601da.);
dsstdatn=input(it_dsstdat,mmddyy10.);
dsstdatc=put(input(it_dsstdat,mmddyy10.),e8601da.);
run;
/*Code below performs preliminary transformations of ec_temp variables*/
data ec_temp(keep=usubjid visitname ecstdatc ecendatc ecstdt ecendt);
length usubjid $11.;
set my_data.ec_temp;
studyid=study;
usubjid=cats(substr(study,11,2),"-",patnum);
ecstdt=input(it_ecstdat,date11.);
ecendt=input(it_ecendat,date11.);
ecstdatc=tranwrd(put(input(it_ecstdat,date11.),e8601da.),".","");
ecendatc=tranwrd(put(input(it_ecendat,date11.),e8601da.),".","");
run;
/*The two proc sorts order the ds and ec tables to ensure the records per subject
  are in ascending chronological order*/
proc sort data=ds_temp;
by usubjid dsstdatn;
run;

proc sort data=ec_temp;
by usubjid ecstdt;
run;
/*This datastep below attempts to capture the sponsor-defined reference end date (RFENDTC) and the last
  date of participation (RFPENDTC) by subject in the disposition data set.  
  The data is arranged by subject record block and has multiple records.  The first row
  usually records the randomization event per subject. Subsequent rows record
  other disposition events such as adverse events and protocol completions.  The first record with
  a non-blank term after the randomization record usually holds the the RFENDTC. There are several
  records that don't follow this pattern but the code below works in capturing RFENDTC.
  The code attempts to capture RFPENDTC in the date of the last record in the record block. The code
  fails for 81 records and the reasons are described in the proc compare section below.  Finally
  the death date and death flag are set in this datastep.  Retained variables are used to carry values
  forward across records.  The last record in the record block is outputted.
  */
data ds_temp_2(keep=usubjid rfendtc rfpendtc dthfl dthdtc);
attrib
   USUBJID  length=$11 label="Unique Subject Identifier" 
   RFENDTC  length=$10 label="Subject Reference End Date/Time"   
   RFPENDTC length=$20 label="Date/Time of End of Participation"
   DTHFL    length=$1  label="Subject Death Flag"
   DTHDTC   length=$20 label="Date/Time of Death"
;
set ds_temp;
length endcheck $1;
retain  rfendtc dthfl dthdtc endcheck;
by usubjid;
if first.usubjid then
  do;
    dthfl="";
    dthdtc="";
    rfendtc=""; 
    endcheck="";
  end;
if endcheck='y' and not missing(it_dsterm) and instance^="Baseline" then
  do;
    rfendtc=dsdtcolc;
    endcheck='';
  end;
if it_dsterm="Randomized" or index(instance, "Screening")>0 then 
  do;
    endcheck='y';
  end;
if it_dsterm='Death' then 
  do;
    dthfl='Y';
    dthdtc=deathdtc;
  end;  
if last.usubjid then
  do;
    if not missing(dstmcol) then rfpendtc=cats(dsdtcolc,"T",dstmcol);
    else rfpendtc=dsdtcolc;
    output;
  end;
run;
/*This datastep below attempts to capture the sponsor-defined reference start date (RFSTDTC), the
  date of the actual first dose (RFXSTDTC) and the date of the actual last dose (RFXENDTC) by subject 
  in the exposures collected data set.  The data is arranged by subject record block and has multiple records.  
  The rows record the exposures to treatment in chronological order.  The first row records the first dose
  while the last record usually records the last dose.  LOCF is used for end doses that don't exist in last record.
  Retained variables are used to carry values forward across records.  The last record in the record block 
  is outputted.
  */
data ec_temp_2(keep=usubjid rfstdtc rfxstdtc rfxendtc);
attrib
  USUBJID  length=$11 label="Unique Subject Identifier" 
  RFSTDTC  length=$10 label="Subject Reference Start Date/Time"
  RFXSTDTC length=$20 label="Date/Time of First Study Treatment" 
  RFXENDTC length=$20 label="Date/Time of Last Study Treatment"  
;
set ec_temp;
retain rfstdtc rfxstdtc rfxendtc;
by usubjid;
if first.usubjid then
  do;
    rfstdtc=ecstdatc; 
    rfxstdtc=ecstdatc; 
    rfxendtc=ecendatc;  
  end;
else
  do;
    if not missing(ecendatc) then rfxendtc=ecendatc;
  end;
if last.usubjid then output;
run;

/*The following sql merges the dm_temp, ds_temp2 and ec_temp2 datasets.
  The first two are inner joined and the result left joined with ec_temp2*/

proc sql;
create table dm_temp2 as
select
a.*,
c.rfstdtc, 
b.rfendtc, 
c.rfxstdtc, 
c.rfxendtc, 
b.rfpendtc, 
b.dthfl,
b.dthdtc
from dm_temp as a inner join
     ds_temp_2 as b on a.usubjid=b.usubjid 
     left join ec_temp_2 as c on a.usubjid=c.usubjid;
quit;

/* The following finalizes the creation of the recreated DM table with the addition of the DMDY calculation.*/
data my_data.dm(drop=col_dt col_num_temp rf_num_temp);
attrib
 DMDY label="Study Day of Collection"
 ;
set dm_temp2;
  col_num_temp = input(col_dt, ?? mmddyy10.);
  rf_num_temp  = input(rfstdtc, ?? e8601da.);

   if nmiss(col_num_temp, rf_num_temp) = 0 then do;
      if col_num_temp >= rf_num_temp then dmdy = col_num_temp - rf_num_temp + 1;
      else dmdy = col_num_temp - rf_num_temp;
   end;
run;

/*The proc below compares the official DM and my recreated DM from raw data.
  Differences (81) were produced from the RFPENDTC variable and stored in an output table. */
proc compare base=actual.dm comp=my_data.dm outnoequal outdif outbase outcomp out=rfpendtc_diff
(keep=_type_ usubjid rfpendtc);
id usubjid;
quit;

/*The difference table is tranposed to produce the base and compare values per subject*/
proc transpose data=rfpendtc_diff out=rfpendtc_tran(keep=usubjid base compare);
by usubjid;
id _type_;
var rfpendtc;
run;

/* The base and compare date values are transformed into SAS dates and a difference is computed*/
data rfpendtc_tran;
set rfpendtc_tran;
base_value=datepart(input(strip(translate(base, ' ', 'T')), anydtdtm60.));
compare_value=datepart(input(strip(translate(compare, ' ', 'T')), anydtdtm60.));
diff=base_value-compare_value;
run;
/* Based on the proc means below, the dates with time component are all greater in base than compare.
   Thus 81 subjects have published RFPENDTCs later than their disposition date.  I found the correct 
   RFPENDTC values in the official SV SDTM table, which points to post-disposition contacts such as 
   visits that aren’t in the raw Pharmaverse package.  
*/
proc means data=rfpendtc_tran max min;
var diff;
run;






