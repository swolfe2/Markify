/* AUTHOR: Thomas Fraser
I made this program for training purpose

The "/*" starts a block of code that is not readable by SAS
and the reverse will end it */;

/* whereas the "*********" will block out that code for a single line, ended by ";";
*/

***** code for next 2 lines assigns values to 'id' and 'pwd' to be used later to call it's value to fulfill ID and Password requirement in order to connect to Oracle and pull data via SQL ***************;
%let id  = 'NAI2PADM';
%let pwd = 'nai2padm';

**Run a query against JDA to pull in which load count for Paris, TX**;
proc sql;
      connect to oracle (path='NAJDAPRD' user=&id password=&pwd);
      create table table_From_oracle as select * from connection to oracle
      (
SELECT COUNT(LD_LEG_ID) AS LOAD_COUNT, TO_CHAR(STRD_DTT,'IW') AS WEEK_NUM, FRST_CTY_NAME, LAST_STA_CD, LAST_CTRY_CD, EQMT_TYP
FROM LOAD_LEG_R
WHERE CUR_OPTLSTAT_ID = '345'
AND TO_CHAR(STRD_DTT,'YYYYMMDD') > '20180211'
AND EQMT_TYP IN ('53FT','53IM','53RT','48FT')
AND FRST_CTY_NAME = 'PARIS'
GROUP BY TO_CHAR(STRD_DTT,'IW'), FRST_CTY_NAME, LAST_STA_CD, LAST_CTRY_CD, EQMT_TYP
ORDER BY TO_CHAR(STRD_DTT,'IW'), LAST_CTRY_CD, LAST_STA_CD
	);
	disconnect from oracle;
  quit;
run;

***** this data step creates a new table called "new_table" (you must use underscore) from existing table best_table_ever, and creates a new field called STATE_COUNTY that concatenates state and country while removing leading/trailing blanks;
data new_table;
	set table_From_oracle;
	STATE_COUNTRY = cats(LAST_STA_CD, " - ", LAST_CTRY_CD);
run;

/* This proc sql step creates a new talbe called "country_count" by taking the sum of load count by last country code from the table called "new_table", while renaming and relabeling last_ctry_cd to "country"
opening the table in SAS will show whatever label you assign it- if label option is not used, the column can stil be renamed, but it will not show in table view*/
proc sql;
	create table country_count as (
		select sum(load_count) as sum_of_loads, last_ctry_cd label='country' as country
		from new_table
		group by last_ctry_cd);
	quit;
run;

/* proc rank will give you a rank by a grouping and variable- in example below, origin table is country_count and output is country_rank, ties are low i.e. if there is a tie for 3rd place, both fields will show 3
by option is the grouping, and var option is what we are using to rank by. rank option creates the field of ranking */
proc rank data=country_count out=country_rank ties=low descending;
   by country;
   var sum_of_loads;
   ranks volume_rank;
run;

/* Date formatting, important to perform functions against- we are changing SAS default datetime to mm/dd/yyyy format */
data AwardLanesCorrectedDates;
	set AwardLanes;
	format EffectiveDate mmddyy10.;
	EffectiveDate = datepart(EffectiveDate); 
	format ExpirationDate mmddyy10.;
	ExpirationDate = datepart(ExpirationDate);
	if OriginZone not in ('','.',' ');
run;

/* creating another field, yes or no, whether an effective date is greater than Feb. 11, 2018 */
data recentaward;
	set AwardLanesCorrectedDates;
	if EffectiveDate > '11-FEB-2018'd then recent = 'Y'; else recent = 'N';
run;

/* filetering out the data set to what is a recent award effective date */
data recentaward; set recentaward(where=(recent = 'Y')); run;


**Import Table from Excel from a whole worksheet****;
PROC IMPORT OUT= ChargeCode
            DATAFILE= '\\Uskvfn01\share\Transportation\Corporate Transportation\Hammock, Darlene\Charge Code Xref.xlsx'
            DBMS=EXCEL REPLACE;
     SHEET="Charge Code Xref Table"; 
RUN;


** Import Table from Excel from a specific range on a worksheet **;
PROC IMPORT OUT= master_zone
            DATAFILE= '\\uskvfn01\share\Transportation\Corporate Transportation\Fraser, Thomas\SAS\Copy of TMS Master Zones List.xls'
            DBMS=EXCEL REPLACE;
     SHEET="CitySt Zone";
	 RANGE="A3:F10776";
RUN;

*** Import Table from Access, from the "Award_Lanes" table within the access database **;
PROC IMPORT OUT= AwardLanes
            DATATABLE= Award_Lanes
            DBMS=ACCESS REPLACE;
     DATABASE='\\uskvfn01\share\Transportation\Corporate Transportation\Award Strategy\Backup Files\Current Awards - TLIM.accdb'; 
     SCANMEMO=YES;
     USEDATE=NO;
     SCANTIME=YES;
RUN;

data awardlanes;
	set awardlanes;
	zone = originzone;
	zone2 = cats(zone," is awesome");
run;

/* Merge city-state into awardlanescarr table using data step. The first table will be your base table, think "left join" in SQL
Make sure that field name is the same, and that both tables are sorted on that field i.e. first 2 lines of proc sort */
proc sort data = AwardLanes; by zone;
proc sort data = master_zone; by zone;
data awardlanes_withcity;
	merge work.AwardLanes(in=a) work.master_zone(in=b);
	by Zone;
	if a;
run;

/* Same thing as above, but with proc sql */
proc sql;
	create table awardlanes_withcity2 as (
		select al.*, mz.*
		from awardlanes al
		left join master_zone mz
		on al.originzone = mz.zone
		);
	quit;
run;

** export data table to excel, use "replace" option to overwrite. You don't have to have the excel file already created in order to export, i.e. it will create an excel file **;
proc export data=awardlanes_withcity
    outfile='\\uskvfn01\share\Transportation\Corporate Transportation\Cost Management Reports\example.xlsx'
    dbms=excel
    replace;
	Sheet="Detail";
run;


** Another way to export to excel, by deleting sheet within excel and then exporting to that same sheet name- naming the excel file extension as "xlsx" **;
LIBNAME xlsx EXCEL "\\USKVFN01\SHARE\Transportation\Corporate Transportation\Cost Management Reports\example.xlsx";
PROC Datasets lib = xlsx nolist;
delete Detail; /* sheet name you are trying to delete */
Quit;
Data xlsx.Detail; /* "xlsx" substitutes for file name, and ".Data" refers to sheet name */
set awardlanes_withcity; /* SAS data table you are wanting to export */
run;
LIBNAME xlsx clear; /* clears "xlsx" value */

/* Email example, using proc report to show data within an email body */
FILENAME output EMAIL
SUBJECT= "Open Status Loads Not Awarded"
FROM= 'OptimizationTeam.Trans@kcc.com' /* come only come from one email */
TO= ('scarpent@kcc.com' 'regina.s.black@kcc.com' 'erin.b.mentzer@kcc.com')
CC= 'thomas.g.fraser2@kcc.com'
BCC = 'thomas.g.fraser2@kcc.com'
REPLYTO = 'regina.s.black@kcc.com'
CT= "text/html" /* Required for HTML output */ ;
ODS HTML BODY=output STYLE=sasweb;
TITLE 'Loads In Open Not Awarded';
PROC REPORT DATA=work.recentaward NOWD
STYLE(REPORT)=[JUST=left outputwidth=100% fontsize=4 background=white]
STYLE(HEADER)=[JUST=center fontsize=3 background=red];
column OriginZone DestZone LaneAnnVol EffectiveDate ExpirationDate PrimaryCustomer;
define OriginZone / 'Origin Zone' group style(column)=[just=center];
define DestZone /'Dest Zone' display;
define EffectiveDate /'Lane Effective' display style(column)=[width=10%];
define ExpirationDate /'Lane Expiration' display;
define PrimaryCustomer /'Primary Customer' display;
RUN;
ODS HTML CLOSE;

/* Email example using attachment and also a link within the body text to the share drive file*/
	FILENAME output EMAIL
	SUBJECT= "Delivery Status Delay Report"
	ATTACH='\\uskvfn01\share\Transportation\Corporate Transportation\Cost Management Reports\example.xlsx'
	FROM= 'CarrierPerf@kcc.com'
	TO= ('scarpent@kcc.com' 'regina.s.black@kcc.com' 'erin.b.mentzer@kcc.com')
	CC= 'thomas.g.fraser2@kcc.com'
	CT= "text/html" /* Required for HTML output */ ;
	data _null_; 
	ODS HTML headtext= "<h2>Kimberly-Clark Corporation</h2><h1>Delivery Status Delay Report</h1><h2>Action Needed</h2><h3>Overview of Report:</h3>";
	ODS HTML BODY=output options(pagebreak="no") rs=none text=  "<p>This report contains load details about movements that you handled on behalf of Kimberly- Clark Transportation. In order to ensure our system is updated with information regarding the delivery, we require that you supply this information in a timely manner. Review the loads attached and ensure both the Arrived(X1) and Departed (D1) are populated if the load has delivered. If the Arrived (X1) column or Departed (D1) column is blank, please resend that information as we have not received the delivery information into our system. Failure to do so will impact carrier performance scoring and could result in failure to make payment for charges related to freight or hours of service. Please review and follow instructions below to ensure the loads are removed from the report.<br>
	Please note: For multi-stop loads, we require the X1 and D1 for each stop.</p><h3>Instructions:</h3><h3>EDI Carriers:</h3><p>•	If you are a certified EDI 214 carrier with Kimberly-Clark, we encourage you to resubmit the load below with the appropriate information ensuring that the load number, location number, and stop are all populated correctly. In the event you have previously submitted and the load remains on the report, please review the EDI Error Report to determine why it was unsuccessful, correct, and resend. If the load remains after that process, contact CarrierPerf@kcc.com and ask for assistance.</p><h3>Web Portal Carriers:</h3><p>•	Please log onto the Kimberly-Clark Web Portal and search for the load below in the Track and Trace section on the right hand side. Once you locate the load, select generate event and populate the Event Date/Time in conjunction with the appropriate status codes. If you have questions, please contact CarrierPerf@kcc.com and ask for assistance.</p>
	<a href='\\uskvfn01\share\Transportation\Corporate Transportation\Cost Management Reports\example.xlsx'>Scotties report</a>";
	run;
	ods _all_ close;
