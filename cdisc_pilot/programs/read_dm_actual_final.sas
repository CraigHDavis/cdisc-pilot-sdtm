/*******************************************************************************
* Study:             CDISCPILOT01
* Program Name:      read_dm_actual_final.sas
* Purpose:           Program converts the DM SAS transport file to a SAS dataset.
*
* Input Datasets:    SDTM Official Published DM from CDISC Pilot (cdiscpilot01), local file dm.xpt  
* Source:            https://github.com/cdisc-org/sdtm-adam-pilot-project/blob/master/updated-pilot-submission-package/900172/m5/datasets/cdiscpilot01/tabulations/sdtm/dm.xpt
* Output Datasets:   actual.dm
* Output Files:      None
*
* Macros Called:     None
*
* Author:            Craig Davis
* Date Created:      11/18/2026
* SAS Version:       9.4
* Details:           Program converts the DM SAS transport file to a SAS dataset.


*/
options mprint mlogic symbolgen;

%let home_path=/<your-project-folder>;

libname actual "&home_path/cdisc_pilot/sdtm/sdtm_actual_tables";

libname xptfile xport "&home_path/cdisc_pilot/data_inputs/dm.xpt" access=readonly;

proc copy inlib=xptfile outlib=actual;
run;

libname xptfile clear;


