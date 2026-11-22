/*******************************************************************************************************
* Study:             CDISCPILOT01
* Program Name:      read_dm_raw_final.sas
* Purpose:           Program imports Pharmaverse csv datasets into SAS.
*
* Input Datasets:    dm_raw, ds_raw, ec_raw from the pharmaverseraw R package,version 0.1.1; 
                     Raw data reverse-engineered by the pharmaverse project from the CDISC Pilot SDTM.  
  Source:            Pharmaverseraw R package,version 0.1.1
* Output Datasets:   my_data.dm_temp (Demographic Data) 
                     my_data,ds_temp (Disposition Data) 
                     my_data.ec_temp (Exposure Collected Data)
* Output Files:      None
*
* Macros Called:     read_raw(internal)
*
* Author:            Craig Davis
* Date Created:      11/18/2026
* SAS Version:       9.4
*
* Details:           The pharmaverseraw R package includes 5 datasets: ae_raw, dm_raw, ds_raw, ec_raw
                     and vs_raw.  The restricted set of raw data limits the ability to fully reconstruct
                     the SDTM and ADaM tables.  Ec_raw (Exposures Collected) serves as the progenitor for
                     the EX domain.  R code exports these R tables to CSV files. In this process,
                     Null values are coded as NA. These CSV files are imported into SAS. 
*/
options mprint mlogic symbolgen;

%let home_path=/<your-project-folder>;

libname my_data "&home_path/cdisc_pilot/sdtm/sdtm_my_tables";
/* This format is used in a data infile statement to replace NA with blanks*/
PROC FORMAT;
   INVALUE $nablank
      'NA'  = ' '
      OTHER = [$70.];
RUN;
option mprint mlogic symbolgen;
/*Data is read into SAS in a two part process using the following macro. 
  The first part serves as an exploratory import.
  The second part performs the actual import and refines the import process based on info from the first part.
  1.Proc import serves as a first cut to read in data and to ascribe attributes to the data.
    Proc contents outputs the attributes to a dataset. The attributes are written as strings 
    of the variable name and informat for a later datastep infile. Modifications are then performed.
    Character variables and date variables receive a informat $nablank while numeric variables
    receive a simple numeric informat. The NA values are converted to blanks and dates become character values.
    Proc SQL INTO saves the variable names and informats to macro variables.
  2.Datastep infile reads in the raw data and uses a loop to construct the input statement from 
    the macro variables */
%macro read_raw(var);

proc import datafile="&home_path/cdisc_pilot/data_inputs/&var._raw.csv"
out=&var._temp
dbms=csv
replace;
guessingrows=max;
run;


proc contents data=&var._temp varnum out=&var._raw_list(keep=name type length varnum format);
run;


proc sort data=&var._raw_list;
by varnum;
quit;


data &var._raw_list;
length name inform $50;
set &var._raw_list;
name=compress(tranwrd(name,'.', '_'));
if type= 2 then
  do;
     inform=cats(':$nablank',length,'.');
  end;
else
  do;
    if format="DATETIME" then
      do;
        inform=cats(':$nablank16','.');
      end;
    else
      do;
        inform=cats(':',length,'.');
      end;
  end;
run;

/*The following proc sql creates arrays of macro variables for the var names and corresonding formats
  Using a - allows for the creation of the arrays without an explicit dimension.
  The &sqlobs macro variable after the sql records the dimension of the record set*/

proc sql noprint;
select
name,
inform
into :name1- ,:inform1-
from &var._raw_list;
quit;

%let obs_count=&sqlobs;

/*The input statement is created dynamically by looping through macro arrays with the &obs_count as end point*/

data my_data.&var._temp;
infile "&home_path/cdisc_pilot/data_inputs/&var._raw.csv" firstobs=2 dsd truncover;
input
%do i=1 %to &obs_count;
&&name&i &&inform&i
%end;
;
run;
%mend read_raw;

%read_raw(dm);
%read_raw(ds);
%read_raw(ec);
