CDISC SDTM/ADaM Pilot – SAS Programming Exercise
This project independently rebuilds datasets from the CDISC SDTM/ADaM Pilot (study CDISCPILOT01) in SAS, starting from raw data in the pharmaverseraw R package (v0.1.1), and validates each result against the official CDISC Pilot datasets using PROC COMPARE.
Status: Phase 1 (SDTM DM) complete. Phases 2–4 (ADaM ADSL, SDTM AE, ADaM ADAE) are planned.
Documentation: See the documentation PDF for the project background, program descriptions and validation results, including an analysis of the RFPENDTC differences.
Data: Input data is not included. The raw data comes from the pharmaverseraw R package (install.packages("pharmaverseraw")), and the reference datasets come from the CDISC Pilot repository (https://github.com/cdisc-org/sdtm-adam-pilot-project). Update the home_path macro variable at the top of each program to point to your project folder.
