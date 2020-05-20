***************************************************************************************************************************;
**  THE PURPOSE OF THIS PROGRAM IS TO PROVIDE DAILY VOLUME AND FREIGHT SPEND                                                                                       *;
***************************************************************************************************************************;

ODS HTML CLOSE;
ODS HTML;
dm 'clear log';
dm 'clear output';

%let id  = 'NAI2PADM';
%let pwd = 'nai2padm';

*************************************************************************************************************************;
** GET BUSINESS UNIT FOR EACH LOAD FROM ABPP_LD_RFRC_T                                                                                                                             **;
*************************************************************************************************************************;


PROC SQL;
      connect to oracle (path='NAJDAPRD' user=&id password=&pwd);
      create table Bus_In as select * from connection to oracle

(SELECT DISTINCT 
	ABPP_LD_RFRC_T.LOAD_ID as Load_Number,
	CASE
		WHEN ABPP_LD_RFRC_T.BSN_UNITS IS NULL THEN ABPP_LD_RFRC_T.BSN_UNITS
		ELSE ABPP_LD_RFRC_T.BSN_UNITS END AS Bus_Unit_ID, 
	ABPP_LD_RFRC_T.BSN_UNIT_BY_WGT as Bus_Unit_Wgt, 
	ABPP_LD_RFRC_T.UNIT_DESC_BY_WGT as Business_Unit
FROM 
	NAJDATRN.ABPP_LD_RFRC_T ABPP_LD_RFRC_T, 
	NAJDAADM.LOAD_LEG_R LOAD_LEG_R
WHERE 
	ABPP_LD_RFRC_T.LOAD_ID = LOAD_LEG_R.LD_LEG_ID AND
	((LOAD_LEG_R.SHPD_DTT>=trunc(sysdate)-35 And 
	LOAD_LEG_R.SHPD_DTT<trunc(sysdate)) AND	
	(LOAD_LEG_R.EQMT_TYP In ('48FT','48TC','53FT','53TC','53HC','53IM','LTL','53RT')) AND  
	(LOAD_LEG_R.FRST_CTRY_CD In ('USA','CAN','MEX')) AND 
	(LOAD_LEG_R.LAST_CTRY_CD In ('USA','CAN','MEX')) AND 
	(ABPP_LD_RFRC_T.BSN_UNIT_BY_WGT Is Not Null))
ORDER BY 	
	ABPP_LD_RFRC_T.LOAD_ID
);

DISCONNECT FROM ORACLE;

QUIT; 

RUN; 



/*         ASSIGN BUSINESS WHEN MISSING       */



PROC SORT DATA = BUS_IN;
	BY LOAD_NUMBER;
RUN;

DATA BUSINESS;
	SET BUS_IN;
		BY LOAD_NUMBER;
	IF BUSINESS_UNIT = '' THEN DO;
		IF BUS_UNIT_ID = '2010' THEN BUSINESS_UNIT = 'CONSUMER';
		IF BUS_UNIT_ID = '2011' THEN BUSINESS_UNIT = 'KCP';
		IF BUS_UNIT_ID = '2020' THEN BUSINESS_UNIT = 'CONSUMER';
		IF BUS_UNIT_ID = '2021' THEN BUSINESS_UNIT = 'KCP';
		IF BUS_UNIT_ID = 'Z01' THEN BUSINESS_UNIT = 'CONSUMER';
		IF BUS_UNIT_ID = 'Z02' THEN BUSINESS_UNIT = 'KCP';
		IF BUS_UNIT_ID = 'Z04' THEN BUSINESS_UNIT = 'KCP';
		IF BUS_UNIT_ID = 'Z05' THEN BUSINESS_UNIT = 'NON WOVENS';
		IF BUS_UNIT_ID = 'Z06' THEN BUSINESS_UNIT = 'KCP';
		IF BUS_UNIT_ID = 'Z07' THEN BUSINESS_UNIT = 'KCP';		
	END;
	BUSINESS_UNIT = UPCASE(BUSINESS_UNIT);
	DROP BUS_UNIT_ID BUS_UNIT_WGT;
	IF FIRST.LOAD_NUMBER THEN OUTPUT BUSINESS;
RUN;

PROC SORT DATA = BUSINESS;
	BY LOAD_NUMBER;
RUN;
			

*************************************************************************************************************************;
** READ EXCEL BUSINESS TABLE TO REASSIGN BUSINESS UNIT ON NON WOVEN SHIPMENTS                                                                             **;
*************************************************************************************************************************;

proc import out=BUS_REASSIGN_TBL replace
	datafile="\\uskvfn01\share\Transportation\Corporate Transportation\Hammock, Darlene\Reassign Business Table.xlsx";
	range="'Reassign Bus Table$'"n;
	getnames=yes;
	mixed=no;
	scantext=yes;
	usedate=yes;
	scantime=yes;
	
run;
 
PROC SORT DATA = BUS_REASSIGN_TBL;
	BY DESTINATION_ID;
RUN;


DATA BUS_REASSIGN;
	SET BUS_REASSIGN_TBL;
		BY DESTINATION_ID;
		DROP DESTINATION_NAME DESTINATION_CITY DESTINATION_STATE;
 RUN;


*************************************************************************************************************************;
** READ EXCEL EXTERNAL CUSTOMER LEVEL 2                                                                                                                                                              **;
*************************************************************************************************************************;

proc import out=EXT_CUST_TBL replace
	datafile="\\uskvfn01\share\Transportation\Corporate Transportation\Hammock, Darlene\Ext Cust Lvl 2 Table.xlsx";
	range='ExtCusLvl2$'n;
	getnames=yes;
	mixed=no;
	scantext=yes;
	usedate=yes;
	scantime=yes;
	
run;
 

*************************************************************************************************************************;
** READ CARRIER SCAC TABLE                                                                                                                                                                                          **;
*************************************************************************************************************************;

proc import out=SCAC_IN replace
	datafile="\\uskvfn01\share\Transportation\Corporate Transportation\Hammock, Darlene\Carrier SCAC Code Listing.xlsx";
	range="'SCAC Table$'"n;
	getnames=yes;
	mixed=no;
	scantext=yes;
	usedate=yes;
	scantime=yes;
	
run;

PROC SORT DATA = SCAC_IN;
	BY SERVICE_ID;
RUN;

DATA SCAC_TBL (KEEP=SERVICE_ID SERVICE_NAME);
	SET SCAC_IN;
		BY SERVICE_ID;
RUN;


PROC SORT DATA = SCAC_IN;
	BY CARRIER_ID;
RUN;

DATA CARRIER_TBL (KEEP=CARRIER_ID CARRIER_NAME);
	SET SCAC_IN;
		BY CARRIER_ID;
RUN;


*************************************************************************************************************************;
** CHARGE CODE REFERENCE TABLE                                                                                                                                                                                **;
*************************************************************************************************************************;

proc import out=CHRG_XREF_TBL replace
	datafile="\\uskvfn01\share\Transportation\Corporate Transportation\Hammock, Darlene\Charge Code Xref.xlsx";
	range="'Charge Code Xref Table$'"n;
	getnames=yes;
	mixed=no;
	scantext=yes;
	usedate=yes;
	scantime=yes;
	
run;

**************************************************************************************************************************;
**  LOAD DETAIL                                                                                                         **;                                                                                                          
**************************************************************************************************************************;

PROC SQL;
      connect to oracle (path='NAJDAPRD' user=&id password=&pwd);
      create table Loads_In as select * from connection to oracle


(SELECT 
	LOAD_LEG_R.CARR_CD AS CARRIER_ID, 
	LOAD_LEG_R.SRVC_CD AS SERVICE_ID, 
	LOAD_LEG_R.SHPD_DTT AS SHIP_DATE, 
	LOAD_LEG_R.STRD_DTT AS START_DATE, 
	LOAD_LEG_R.LD_LEG_ID AS LOAD_NUMBER, 
	LOAD_LEG_R.FRST_SHPG_LOC_CD AS ORIGIN_ID, 
	LOAD_LEG_R.FRST_SHPG_LOC_NAME AS ORIGIN_NAME, 
	LOAD_LEG_R.FRST_CTY_NAME AS ORIGIN_CITY, 
	LOAD_LEG_R.FRST_STA_CD AS ORIGIN_STATE, 
	LOAD_LEG_R.FRST_PSTL_CD AS ORIGIN_POSTAL_CODE, 
	LOAD_LEG_R.FRST_CTRY_CD AS ORIGIN_COUNTRY, 
	LOAD_LEG_R.LAST_SHPG_LOC_CD DESTINATION_ID, 
	LOAD_LEG_R.LAST_SHPG_LOC_NAME DESTINATION_NAME, 
	LOAD_LEG_R.LAST_CTY_NAME DESTINATION_CITY, 
	LOAD_LEG_R.LAST_STA_CD DESTINATION_STATE, 
	LOAD_LEG_R.LAST_PSTL_CD AS DESTINATION_POSTAL_CODE, 
	LOAD_LEG_R.LAST_CTRY_CD AS DESTINATION_COUNTRY, 
	LOAD_LEG_R.EQMT_TYP AS EQUIP_TYPE, 
	LOAD_LEG_R.FIXD_ITNR_DIST AS MILES, 
	LOAD_LEG_R.TOT_TOT_PCE AS QTY, 
	LOAD_LEG_R.TOT_SCLD_WGT AS WEIGHT, 
	LOAD_LEG_R.TOT_VOL AS CUBE, 
	LOAD_LEG_R.ACTL_CHGD_AMT_DLR AS PRERATE_INCL_FUEL, 
	LOAD_AT_R.CORP1_ID AS CORP_ID
FROM 
	NAJDAADM.LOAD_AT_R LOAD_AT_R, 
	NAJDAADM.LOAD_LEG_R LOAD_LEG_R
WHERE 
	LOAD_LEG_R.FRST_SHPG_LOC_CD = LOAD_AT_R.SHPG_LOC_CD AND 
	((LOAD_LEG_R.SHPD_DTT>=trunc(sysdate)-35 And 
	LOAD_LEG_R.SHPD_DTT<trunc(sysdate)) AND  
	(LOAD_LEG_R.ACTL_CHGD_AMT_DLR>10) AND 
	(LOAD_LEG_R.CUR_OPTLSTAT_ID>=320 And 
		LOAD_LEG_R.CUR_OPTLSTAT_ID<355) AND 
	(LOAD_LEG_R.EQMT_TYP In ('48FT','48TC','53FT','53TC','53HC','53IM','LTL','53RT')) AND 
	(LOAD_LEG_R.SRVC_CD<>'OPEN') AND 
	(LOAD_LEG_R.FRST_CTRY_CD In ('USA','CAN','MEX')) AND
	(LOAD_LEG_R.LAST_CTRY_CD In ('USA','CAN','MEX')))

ORDER BY
	LOAD_LEG_R.LD_LEG_ID

);

DISCONNECT FROM ORACLE;

QUIT; 

RUN;

PROC SORT DATA = LOADS_IN;
	BY LOAD_NUMBER;
RUN;

DATA LOADS;
	SET LOADS_IN;
		BY LOAD_NUMBER;
	LENGTH SHIPMENT_TYPE $10
		   SHIP_MODE $10;
	IF SUBSTR(DESTINATION_ID,1,2)='58' THEN SHIPMENT_TYPE = 'CUSTOMER';
	ELSE
	IF SUBSTR(DESTINATION_ID,1,2) = '99' THEN SHIPMENT_TYPE = 'CUSTOMER';
	ELSE
	IF CORP_ID = 'RM' THEN SHIPMENT_TYPE = 'RM-INBOUND';
	ELSE
	IF CORP_ID = 'RF' THEN SHIPMENT_TYPE = 'RF-INBOUND';
	ELSE
	IF SUBSTR(ORIGIN_NAME,1,2) = 'RM' THEN SHIPMENT_TYPE = 'RM-INBOUND';
	ELSE
	IF SUBSTR(ORIGIN_NAME,1,2) = 'RF' THEN SHIPMENT_TYPE = 'RF-INBOUND';
	ELSE
	IF SUBSTR (ORIGIN_ID,1,1) = 'V' THEN SHIPMENT_TYPE = 'INBOUND';
	ELSE SHIPMENT_TYPE = 'INTERMILL';
	IF EQUIP_TYPE = 'LTL' THEN SHIP_MODE = 'LTL';
	ELSE
	IF EQUIP_TYPE = '53IM' AND SERVICE_ID NE 'HJBP' THEN SHIP_MODE = 'INTERMODAL';
	ELSE SHIP_MODE = 'TRUCK';
	IF SHIPMENT_TYPE = 'CUSTOMER' THEN EXT_CUST_LVL2 = SUBSTR(DESTINATION_ID,1,8);
	ELSE EXT_CUST_LVL2 = ' ';
	SHIPDT = DATEPART(SHIP_DATE);
	M = MONTH(SHIPDT);
	D = DAY(SHIPDT);
	Y = YEAR(SHIPDT);
	LOAD_CNT = 1;	 
RUN;


**************************************************************************************************************************;
**  CHARGE TABLE                                                                                                                                                                                                                **;                                                                                                          
**************************************************************************************************************************;


PROC SQL;
      connect to oracle (path='NAJDAPRD' user=&id password=&pwd);
      create table Charges_In as select * from connection to oracle

(SELECT
	LOAD_LEG_R.SHPD_DTT, 
	LOAD_LEG_R.LD_LEG_ID AS LOAD_NUMBER, 
	CHARGE_DETAIL_R.CHRG_CD, 
	CHARGE_DETAIL_R.CHRG_AMT_DLR
FROM 
	NAI2PADM.CHARGE_DETAIL_R CHARGE_DETAIL_R, 
	NAI2PADM.LOAD_LEG_R LOAD_LEG_R
WHERE 
	LOAD_LEG_R.LD_LEG_ID = CHARGE_DETAIL_R.LD_LEG_ID AND 
	((LOAD_LEG_R.SHPD_DTT>=trunc(sysdate)-35 And 
	LOAD_LEG_R.SHPD_DTT<trunc(sysdate)) AND 
	(LOAD_LEG_R.CUR_OPTLSTAT_ID>=320 And 
	LOAD_LEG_R.CUR_OPTLSTAT_ID<355) AND 
	(LOAD_LEG_R.SRVC_CD Not In ('OPAF','OPEC','OPEN','OPEX','OPKG')) AND 
	(LOAD_LEG_R.FRST_CTRY_CD In ('USA','CAN','MEX')) AND 
	(LOAD_LEG_R.LAST_CTRY_CD In ('USA','CAN','MEX')) AND 
	(CHARGE_DETAIL_R.CHRG_CD Is Not Null) AND 
	(CHARGE_DETAIL_R.CHRG_AMT_DLR<>0))
ORDER BY 
	LOAD_LEG_R.LD_LEG_ID
);

DISCONNECT FROM ORACLE;

QUIT; 

PROC SORT DATA = CHARGES_IN;
	BY CHRG_CD;
RUN;

PROC SORT DATA = CHRG_XREF_TBL;
	BY CHRG_CD;
RUN;

DATA CHARGE_TYPE;
	MERGE CHARGES_IN(IN=A) CHRG_XREF_TBL;
		BY CHRG_CD;
		IF A;
RUN;

PROC SORT DATA = CHARGE_TYPE;
	BY LOAD_NUMBER;
RUN;

DATA CHARGES (KEEP=LOAD_NUMBER LINEHAUL FUEL ACCESSORIALS TOTAL_PRERATE);
	SET CHARGE_TYPE;
		BY LOAD_NUMBER;
	FORMAT	LINEHAUL DOLLAR14.2
		FUEL DOLLAR14.2
		ACCESSORIALS 14.2;
	IF FIRST.LOAD_NUMBER THEN DO;
		LINEHAUL = 0;			
		FUEL = 0;
		ACCESSORIALS = 0;
	END;
	IF CHRG_TYPE = 'LINEHAUL' THEN LINEHAUL + CHRG_AMT_DLR;
	ELSE
	IF CHRG_TYPE = 'FUEL' THEN FUEL + CHRG_AMT_DLR;
	ELSE ACCESSORIALS + CHRG_AMT_DLR;
	DROP SHPD_DTT CHRG_CD CHRG_AMT_DLR;
	IF LAST.LOAD_NUMBER THEN DO;
		TOTAL_PRERATE = LINEHAUL + FUEL + ACCESSORIALS;
		 OUTPUT CHARGES;
	END;
	
RUN;


**************************************************************************************************************************;
**  CARRIER UNLOAD SERVICE                                                                                                                                                                                           **;                                                                                                          
**************************************************************************************************************************;


PROC SQL;
      connect to oracle (path='NAJDAPRD' user=&id password=&pwd);
      create table Carr_Svc_In as select * from connection to oracle

(SELECT DISTINCT
	LOAD_LEG_R.LD_LEG_ID AS LOAD_NUMBER, 
	LOAD_LEG_R.SHPD_DTT, 
	LOAD_LEG_R.TOT_SCLD_WGT, 
	LOAD_LEG_R.TOT_VOL, 
	SHIPMENT_R.RFRC_NUM11 AS CARR_UNLD_SVC, 
	Sum(SHIPMENT_R.BS_WGT), 
	Sum(SHIPMENT_R.BS_VOL) AS CUBE
FROM 
	NAJDAADM.LOAD_LEG_DETAIL_R LOAD_LEG_DETAIL_R, 
	NAJDAADM.LOAD_LEG_R LOAD_LEG_R, 
	NAJDAADM.SHIPMENT_R SHIPMENT_R
WHERE 
	LOAD_LEG_R.LD_LEG_ID = LOAD_LEG_DETAIL_R.LD_LEG_ID AND 
	LOAD_LEG_DETAIL_R.SHPM_ID = SHIPMENT_R.SHPM_ID AND 
	LOAD_LEG_DETAIL_R.SHPM_NUM = SHIPMENT_R.SHPM_NUM AND 
	((LOAD_LEG_R.SHPD_DTT>=trunc(sysdate)-35 And 
	LOAD_LEG_R.SHPD_DTT<trunc(sysdate)) AND 
	(substr(LAST_SHPG_LOC_CD,1,2) In ('58','99')) AND 
	(LOAD_LEG_R.EQMT_TYP In ('48FT','48TC','53FT','53TC','53HC','53IM','LTL','53RT')))
GROUP BY 
	LOAD_LEG_R.LD_LEG_ID, 
	LOAD_LEG_R.SHPD_DTT, 
	LOAD_LEG_R.TOT_SCLD_WGT, 
	LOAD_LEG_R.TOT_VOL, 
	SHIPMENT_R.RFRC_NUM11
ORDER BY 
	LOAD_LEG_R.LD_LEG_ID

);

DISCONNECT FROM ORACLE;

QUIT; 

RUN;

PROC SORT DATA = CARR_SVC_IN;
	BY LOAD_NUMBER CUBE;
RUN;

DATA CARR_UNLD_SVC (KEEP=LOAD_NUMBER CARR_UNLD_SVC);
	SET CARR_SVC_IN;
		BY LOAD_NUMBER CUBE;
	IF LAST.LOAD_NUMBER THEN OUTPUT CARR_UNLD_SVC;
RUN;


**************************************************************************************************************************;
**  SPACEMAKERS                                                                                                                                                                                                                **;                                                                                                          
**************************************************************************************************************************;


PROC SQL;
      connect to oracle (path='NAJDAPRD' user=&id password=&pwd);
      create table SpaceMakers_In as select * from connection to oracle

(SELECT 
	LOAD_LEG_R.SHPD_DTT, 
	LOAD_LEG_R.LD_LEG_ID AS LOAD_NUMBER, 
	LOAD_LEG_DETAIL_R.SHPM_NUM, 
	SHIPMENT_R.RFRC_NUM6, 
	LOAD_LEG_R.FRST_SHPG_LOC_CD, 
	LOAD_LEG_R.LAST_SHPG_LOC_CD
FROM 
	NAJDAADM.LOAD_LEG_DETAIL_R LOAD_LEG_DETAIL_R, 
	NAJDAADM.LOAD_LEG_R LOAD_LEG_R, 
	NAJDAADM.SHIPMENT_R SHIPMENT_R
WHERE 
	LOAD_LEG_R.LD_LEG_ID = LOAD_LEG_DETAIL_R.LD_LEG_ID AND 
	LOAD_LEG_DETAIL_R.SHPM_ID = SHIPMENT_R.SHPM_ID AND 
	LOAD_LEG_DETAIL_R.SHPM_NUM = SHIPMENT_R.SHPM_NUM AND 
	((LOAD_LEG_R.SHPD_DTT>=trunc(sysdate)-35 And 
	LOAD_LEG_R.SHPD_DTT<trunc(sysdate)) AND 
	(SHIPMENT_R.RFRC_NUM6='ZUSM') AND 
	(LOAD_LEG_R.EQMT_TYP In ('48FT','48TC','53FT','53TC','53HC','53IM','LTL','53RT')))
ORDER BY 
	LOAD_LEG_R.LD_LEG_ID
);

DISCONNECT FROM ORACLE;

QUIT; 

RUN;

PROC SORT DATA = SPACEMAKERS_IN;
	BY LOAD_NUMBER;
RUN;

DATA SPACEMAKERS (KEEP=LOAD_NUMBER SPACEMAKER_YN);
	SET SPACEMAKERS_IN;
		BY LOAD_NUMBER;
	SPACEMAKER_YN = 'Y';
	OUTPUT SPACEMAKERS;
RUN;

*************************************************************************************************************************;
** MATERIAL TYPE                                                                                                                                                                                                                **;                                                                                                          
**************************************************************************************************************************;


PROC SQL;
      connect to oracle (path='NAJDAPRD' user=&id password=&pwd);
      create table Material_In as select * from connection to oracle

(SELECT 
	LOAD_LEG_R.SHPD_DTT AS SHIP_DATE, 
	LOAD_LEG_R.LD_LEG_ID AS LOAD_NUMBER, 
	REFERENCE_NUMBER_R.RFRC_NUM AS MATERIAL_TYPE, 
	COUNT(*) AS MATERIAL_CNT
FROM 
	NAJDAADM.LOAD_LEG_R LOAD_LEG_R, 
	NAJDAADM.REFERENCE_NUMBER_R REFERENCE_NUMBER_R, 
	NAJDAADM.SHIPMENT_ITEM_R SHIPMENT_ITEM_R, 
	NAJDAADM.SHIPMENT_R SHIPMENT_R
WHERE 
	LOAD_LEG_R.LD_LEG_ID = SHIPMENT_R.LD_LEG_ID AND 
	SHIPMENT_R.SHPM_ID = SHIPMENT_ITEM_R.SHPM_ID AND 
	SHIPMENT_ITEM_R.SHPM_ITM_ID = REFERENCE_NUMBER_R.SHPM_ITM_ID AND
	((LOAD_LEG_R.SHPD_DTT>=trunc(sysdate)-35 And 
	LOAD_LEG_R.SHPD_DTT<trunc(sysdate)) AND 
	(REFERENCE_NUMBER_R.RFRC_NUM_TYP='KC-Material Type') AND 
	(LOAD_LEG_R.EQMT_TYP In ('48FT','48TC','53FT','53TC','53HC','53IM','LTL','53RT')) AND 
	(LOAD_LEG_R.LAST_CTRY_CD In ('USA','CAN','MEX')))
GROUP BY 
	LOAD_LEG_R.SHPD_DTT, 
	LOAD_LEG_R.LD_LEG_ID, 
	REFERENCE_NUMBER_R.RFRC_NUM
ORDER BY 
	LOAD_LEG_R.LD_LEG_ID, 
	REFERENCE_NUMBER_R.RFRC_NUM
);

DISCONNECT FROM ORACLE;

QUIT; 

RUN;

PROC SORT DATA = MATERIAL_IN;
	BY LOAD_NUMBER DESCENDING MATERIAL_CNT MATERIAL_TYPE;
RUN;


 DATA MATERIAL_TYPE (KEEP=LOAD_NUMBER MATERIAL_TYPE MATERIAL_TYPE_DESC);
	SET MATERIAL_IN;
		BY LOAD_NUMBER DESCENDING MATERIAL_CNT MATERIAL_TYPE;
	LENGTH MATERIAL_TYPE_DESC $20;
	IF FIRST.LOAD_NUMBER THEN DO;
		IF MATERIAL_TYPE = 'N100' THEN MATERIAL_TYPE_DESC = 'FINISHED PRODUCT';
		ELSE MATERIAL_TYPE_DESC = 'NON FINISHED PRODUCT';
		OUTPUT MATERIAL_TYPE;
	END;
RUN;


*************************************************************************************************************************;
** COMBINE LOAD FILE WITH BUSINESS TABLE                                                                                                                                                             **;                                                                                                          
*************************************************************************************************************************;


PROC SORT DATA = LOADS;
	BY LOAD_NUMBER;
RUN;

PROC SORT DATA = BUSINESS;
	BY LOAD_NUMBER;
RUN;

DATA LOAD_BUS;
	MERGE LOADS(IN=A) BUSINESS;
		BY LOAD_NUMBER;
		IF A;
RUN;

*************************************************************************************************************************;
**  COMBINE ABOVE TABLE WITH REASSIGNED BUSINESS TABLE                                                                                                                                **;                                                                                                          
*************************************************************************************************************************;


PROC SORT DATA = LOAD_BUS;
	BY DESTINATION_ID;
RUN;
	
PROC SORT DATA = BUS_REASSIGN_TBL;
	BY DESTINATION_ID;
RUN;

DATA LOAD_REASSIGN;
	MERGE LOAD_BUS(IN=A) BUS_REASSIGN_TBL;
		BY DESTINATION_ID;
		IF A;
RUN;

*************************************************************************************************************************;
** COMBINE ABOVE CREATED TABLE WITH EXTERNAL CUSTOMER TABLE                                                                                                                  **;                                                                                                          
*************************************************************************************************************************;

PROC SORT DATA = LOAD_REASSIGN;
	BY EXT_CUST_LVL2;
RUN;

PROC SORT DATA = EXT_CUST_TBL;
	BY EXT_CUST_LVL2;	
RUN;

DATA LOAD_CUST;
	MERGE LOAD_REASSIGN(IN=A) EXT_CUST_TBL;
		BY EXT_CUST_LVL2;
		IF A;
RUN;

*************************************************************************************************************************;
** COMBINE ABOVE CREATED TABLE WITH CARRIER TABLE                                                                                                                                         **;                                                                                                          
*************************************************************************************************************************;

PROC SORT DATA = LOAD_CUST;
	BY CARRIER_ID;
RUN;

PROC SORT DATA = CARRIER_TBL;
	BY CARRIER_ID;
RUN;

DATA LOAD_CARR;
	MERGE LOAD_CUST (IN=A) CARRIER_TBL;
		BY CARRIER_ID;
		IF A;
RUN;

*************************************************************************************************************************;
**  COMBINE ABOVE CREATED TABLE WITH SCAC TABLE                                                                                                                                              **;                                                                                                          
*************************************************************************************************************************;

PROC SORT DATA = LOAD_CARR;
	BY SERVICE_ID;
RUN;

PROC SORT DATA = SCAC_TBL;
	BY SERVICE_ID;
RUN;

DATA LOAD_SCAC;
	MERGE LOAD_CARR(IN=A) SCAC_TBL;
		BY SERVICE_ID;
		IF A;
RUN;

*************************************************************************************************************************;
**  COMBINE ABOVE CREATED TABLE WITH CHARGE TABLE                                                                                                                                         **;                                                                                                          
*************************************************************************************************************************;

PROC SORT DATA = LOAD_SCAC;
	BY LOAD_NUMBER;
RUN;

PROC SORT DATA = CHARGES;
	BY LOAD_NUMBER;
RUN;

DATA LOAD_CHRGS;
	MERGE LOAD_SCAC(IN=A) CHARGES;
		BY LOAD_NUMBER;
		IF A;
RUN;

*************************************************************************************************************************;
**  COMBINE ABOVE CREATED TABLE WITH CARRIER UNLOAD SERVICE TABLE                                                                                                         **;                                                                                                          
*************************************************************************************************************************;

PROC SORT DATA = LOAD_CHRGS;
	BY LOAD_NUMBER;
RUN;

PROC SORT DATA = CARR_UNLD_SVC;
	BY LOAD_NUMBER;
RUN;

DATA LOAD_UNLD;
	MERGE LOAD_CHRGS(IN=A) CARR_UNLD_SVC;
		BY LOAD_NUMBER;
		IF A;
RUN;

*************************************************************************************************************************;
**  COMBINE ABOVE CREATED TABLE WITH SPACEMAKER TABLE                                                                                                                                **;                                                                                                          
*************************************************************************************************************************;

PROC SORT DATA = LOAD_UNLD;
	BY LOAD_NUMBER;
RUN;

PROC SORT DATA = SPACEMAKERS;
	BY LOAD_NUMBER;
RUN;

DATA LOAD_SPACE;
	MERGE LOAD_UNLD(IN=A) SPACEMAKERS;
		BY LOAD_NUMBER;
		IF A;
RUN;

*************************************************************************************************************************;
**  COMBINE ABOVE CREATED TABLE WITH MATERIAL TYPE TABLE                                                                                                                             **;                                                                                                          
*************************************************************************************************************************;

PROC SORT DATA = LOAD_SPACE;
	BY LOAD_NUMBER;
RUN;

PROC SORT DATA = MATERIAL_TYPE;
	BY LOAD_NUMBER;
RUN;

DATA LOAD_MATL (KEEP=CARRIER_ID CARRIER_NAME SERVICE_ID SERVICE_NAME SHIP_DATE START_DATE LOAD_NUMBER 
		ORIGIN_ID ORIGIN_NAME ORIGIN_CITY ORIGIN_STATE ORIGIN_POSTAL_CODE ORIGIN_COUNTRY 
		EXT_CUST_LVL2 EXT_CUST_LVL2_NAME DESTINATION_ID DESTINATION_NAME DESTINATION_CITY 
		DESTINATION_STATE DESTINATION_POSTAL_CODE DESTINATION_COUNTRY EQUIP_TYPE MILES QTY 
		WEIGHT CUBE PRERATE_INCL_FUEL CORP_ID LINEHAUL FUEL ACCESSORIALS TOTAL_PRERATE 
		BUSINESS_UNIT SHIPMENT_TYPE SHIP_MODE CARR_UNLD_SVC SPACEMAKER_YN MATERIAL_TYPE_DESC Y M D LOAD_CNT);
	RETAIN	CARRIER_ID CARRIER_NAME SERVICE_ID SERVICE_NAME SHIP_DATE START_DATE LOAD_NUMBER 
		ORIGIN_ID ORIGIN_NAME ORIGIN_CITY ORIGIN_STATE ORIGIN_POSTAL_CODE ORIGIN_COUNTRY 
		EXT_CUST_LVL2 EXT_CUST_LVL2_NAME DESTINATION_ID DESTINATION_NAME DESTINATION_CITY 
		DESTINATION_STATE DESTINATION_POSTAL_CODE DESTINATION_COUNTRY EQUIP_TYPE MILES QTY 
		WEIGHT CUBE PRERATE_INCL_FUEL CORP_ID LINEHAUL FUEL ACCESSORIALS TOTAL_PRERATE 
		BUSINESS_UNIT SHIPMENT_TYPE SHIP_MODE CARR_UNLD_SVC SPACEMAKER_YN MATERIAL_TYPE_DESC Y M D LOAD_CNT;	
	MERGE LOAD_SPACE(IN=A) MATERIAL_TYPE;
		BY LOAD_NUMBER;
		IF A;
		IF SHIPMENT_TYPE = 'RM-INBOUND' THEN MATERIAL_TYPE_DESC = 'RAW MATERIALS';
		IF SHIPMENT_TYPE = 'RF-INBOUND' THEN MATERIAL_TYPE_DESC = 'RECYCLED FIBER';
		IF BUSINESS_UNIT = 'NON WOVENS' THEN BUSINESS_UNIT = UPCASE(REASSIGNED_BUSINESS);
		IF BUSINESS_UNIT = '' THEN BUSINESS_UNIT = UPCASE(REASSIGNED_BUSINESS);
		IF BUSINESS_UNIT = ' ' THEN BUSINESS_UNIT = UPCASE(REASSIGNED_BUSINESS);
		
		FORMAT	ORIGIN_ID			CHAR14.
			ORIGIN_POSTAL_CODE		CHAR9.
			DESTINATION_ID			CHAR16.
			DESTINATION_POSTAL_CODE	CHAR9.
			MILES					COMMA12.1			
			QTY						COMMA12.
			WEIGHT					COMMA12.
			CUBE					COMMA12.
			PRERATE_INCL_FUEL		DOLLAR14.2
			LINEHAUL				DOLLAR14.2
			FUEL					DOLLAR14.2
			ACCESSORIALS			DOLLAR14.2	
			TOTAL_PRERATE			DOLLAR14.2
			SHIP_DATE				DATETIME13.
			START_DATE				DATETIME13.;		
		DROP REASSIGNED_BUSINESS;	
RUN;

*************************************************************************************************************************;
** EXPORT                                                                                                              **;
*************************************************************************************************************************;


LIBNAME XLS EXCEL "\\uskvfn01\share\Transportation\Corporate Transportation\Freight Expenditure\MTD Freight Expenditure.xlsx";

PROC DATASETS LIB = XLS NOLIST;
DELETE DETAIL;
RUN;
QUIT;

DATA XLS.DETAIL;
SET LOAD_MATL;
RUN;

LIBNAME XLS CLEAR;
