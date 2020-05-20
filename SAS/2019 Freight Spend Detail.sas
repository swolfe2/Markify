/*AUTHOR: Thomas Fraser
Transport Cost
	1. Pull in current load volume and charges, and associated prerate charges. Pull in actual charges as well, and replace the prerate charge if actual exists.
	2. Pull in 2018 prerate and actual charges
	3. Add data metrics for 2018 and 2019 load detail tables:
		a. Week number, month, mileage, date, customer, customer hierarchy, customer tier
		b. lane (5 digit dest and 3 digit dest)
		c. award lane y/n and award carrier y/n
		d. mileage
		e. Bid target, award target weighted, award target per mode
	4. Roll up 2018 and 2019 by lane, week number, business unit (once we determine whether it is a 5 digit or 3 digit lane)
	5. combine 2018 and 2019 tables for comparisons
*/

/* To-Do's
	1. Fix WALM award targets to match 53RT
	2. Normalize volume and miles- this year or last year?
*/

%let id  = 'NAI2PADM';
%let pwd = 'nai2padm';

**Pull in the actual shipments since the beginning of the year in Tender Accepted status or beyond and their current pre-rate**;
**Do not exclude any shipments at this point**;
proc sql;
      connect to oracle (path='NAJDAPRD' user=&id password=&pwd);
      create table Actual_Load_Detail as select * from connection to oracle
      (
SELECT LOAD_CHARGE.*,
    CASE WHEN SUBSTR(FRST_SHPG_LOC_CD,1,4) IN ('2358','2292') THEN 'KCILROME-NOF' WHEN SUBSTR(FRST_SHPG_LOC_CD,1,4) = '2323' THEN 'KCILROME-KCP' WHEN SUBSTR(FRST_SHPG_LOC_CD,1,4) = '2474' THEN 'KCILROME-SKIN' ELSE ZONE.ZN_CD END ORIGIN_ZONE
FROM
    (SELECT L.CARR_CD, L.SRVC_CD, L.SHPD_DTT, CASE WHEN L.STRD_DTT IS NULL THEN L.SHPD_DTT ELSE L.STRD_DTT END STRD_DTT, L.LD_LEG_ID, L.FRST_SHPG_LOC_CD, L.FRST_SHPG_LOC_NAME, L.FRST_CTY_NAME, L.FRST_STA_CD, L.FRST_PSTL_CD, L.FRST_CTRY_CD, L.LAST_SHPG_LOC_CD, L.LAST_SHPG_LOC_NAME, L.LAST_CTY_NAME, L.LAST_STA_CD, L.LAST_PSTL_CD, L.LAST_CTRY_CD, L.EQMT_TYP, L.LDD_DIST AS FIXD_ITNR_DIST, L.TOT_TOT_PCE, L.TOT_SCLD_WGT, L.TOT_VOL, L.ACTL_CHGD_AMT_DLR, LA.CORP1_ID,
        CASE WHEN L.SRVC_CD = 'HJBM' AND SUBSTR(L.RATE_CD,1,1) = 'C' THEN 'Y' ELSE 'N' END AS MARKETPLACE_CATCHALL
    FROM ADDRESS_R AD, ADDRESS_R AD1, LOAD_AT_R LA, LOAD_LEG_R L
    WHERE L.FRST_SHPG_LOC_CD = LA.SHPG_LOC_CD
    AND L.FRST_ADDR_ID = AD.ADDR_ID
    AND L.LAST_ADDR_ID = AD1.ADDR_ID 
    AND (TO_CHAR(L.STRD_DTT,'YYYYMMDD') >= '20190101' OR STRD_DTT IS NULL)
    AND TO_CHAR(L.SHPD_DTT,'YYYYMMDD') >= '20190101'
    AND L.CUR_OPTLSTAT_ID in (320,325,335,345)
    AND L.EQMT_TYP In ('48FT','48TC','53FT','53TC','53IM','53RT')
    AND L.LAST_CTRY_CD In ('USA','CAN','MEX')) LOAD_CHARGE
LEFT JOIN (SELECT * FROM ZONE_R WHERE ZN_CD NOT IN ('LARSV','CACITYIN')) ZONE
ON FRST_CTY_NAME || ', ' || FRST_STA_CD = ZN_DESC
	);
	disconnect from oracle;
  quit;
run;

/* Remove Marketplace Catchalls
DATA Actual_Load_Detail;
	SET Actual_Load_Detail(WHERE=(MARKETPLACE_CATCHALL = 'N')); RUN;
*/

**Modify Dates to MM/DD/YYYY Format**;
data Actual_Load_Detail;
	set Actual_Load_Detail;
	format Strd_Dtt mmddyy10.;
	Strd_Dtt = datepart(Strd_Dtt); 
	format Shpd_Dtt mmddyy10.;
	Shpd_Dtt = datepart(Shpd_Dtt);
run;

**Pull in the pre-rate details for the shipments**;
**Do not exclude any shipments at this point**;
proc sql;
      connect to oracle (path='NAJDAPRD' user=&id password=&pwd);
      create table PreRate_Load_Charge as select * from connection to oracle
      (
SELECT L.LD_LEG_ID,
	CASE WHEN C.CHRG_CD IN ('ADLH','CATX','CONT','CUBE','CWF1','CWF2','CWF3','CWF4','CWT','CWTF','CWTM','DISC','DIST','DT2','FBED','FLAT','GRI','ISPT','LMIN','LTLD','MILE','OCFR','OCN1','PKG1','SPOT','TC','TCM','UPD','WGT','ZNFD','ZWND','ZJBH','ZSPT') THEN 'PreRate_Linehaul'
	WHEN C.CHRG_CD IN ('BAF','DFSC','FS01','FS02','FS03','FS04','FS05','FS06','FS07','FS08','FS09','FS10','FS11','FS12','FS13','FS14','FS15','FSCA','PFSC','RFSC','WCFS') THEN 'PreRate_Fuel'
	WHEN C.CHRG_CD IN ('ZREP','ZDHM') THEN 'PreRate_Repo'
	ELSE 'PreRate_Accessorials' END AS ChargeType, C.CHRG_AMT_DLR as ChargeAmount, C.PYMNT_AMT_DLR as PaymentAmount
FROM CHARGE_DETAIL_R C, LOAD_LEG_R L
WHERE L.LD_LEG_ID = C.LD_LEG_ID 
AND (TO_CHAR(L.STRD_DTT,'YYYYMMDD') >= '20190101' OR L.STRD_DTT IS NULL)
AND TO_CHAR(L.SHPD_DTT,'YYYYMMDD') >= '20190101' 
AND L.CUR_OPTLSTAT_ID IN (320,325,335,345)
AND L.EQMT_TYP In ('48FT','48TC','53FT','53TC','53IM','53RT')
AND L.SRVC_CD Not In ('OPAF','OPEC','OPEX','OPKG')
AND L.FRST_CTRY_CD In ('USA','CAN','MEX')
AND L.LAST_CTRY_CD In ('USA','CAN','MEX')
AND C.CHRG_CD Is Not Null AND C.CHRG_AMT_DLR<>0
	);
	disconnect from oracle;
  quit;
run;

**Roll up Pre-Rate Charges into summary table by LD_LEG_ID;
proc sql;
	create table PreRate_Load_Charge as (
		select LD_LEG_ID, ChargeType, Sum(ChargeAmount) as PaymentAmount from PreRate_Load_Charge
		group by LD_LEG_ID, ChargeType
			);
	quit;

** Tranposing into one table with multiple columns for chargetype **;
proc transpose data=PreRate_Load_Charge out=PreRate_Load_Charge;
 by ld_leg_id;
 var PaymentAmount;
 id ChargeType;
run; 

** Drop field that resulted for former field of ChargeType, which was renamed to "_Name_";
data PreRate_Load_Charge;
	set PreRate_Load_Charge;
	drop _Name_;
run;

**Merge Pre-Rate Linehaul, Fuel and Accessorials back into Actual_Load_Detail table;
proc sort data = Actual_Load_Detail; by LD_LEG_ID;
proc sort data = PreRate_Load_Charge; by LD_LEG_ID;
data Actual_Load_Detail;
	merge work.Actual_Load_Detail(in=a) work.PreRate_Load_Charge(in=b);
	by LD_LEG_ID;
	if a;
run;


**Pull in the shipments and their ACTUAL charges from TM**;
**Do not exclude any shipments at this point**;
proc sql;
      connect to oracle (path='NAJDAPRD' user=&id password=&pwd);
      create table Actual_Load_Charge as select * from connection to oracle
      (
SELECT L.LD_LEG_ID, 
	CASE WHEN C.CHRG_CD IN ('ADLH','CATX','CONT','CUBE','CWF1','CWF2','CWF3','CWF4','CWT','CWTF','CWTM','DISC','DIST','DT2','FBED','FLAT','GRI','ISPT','LMIN','LTLD','MILE','OCFR','OCN1','PKG1','SPOT','TC','TCM','UPD','WGT','ZNFD','ZWND','ZJBH','ZSPT') THEN 'Act_Linehaul'
	WHEN C.CHRG_CD IN ('BAF','DFSC','FS01','FS02','FS03','FS04','FS05','FS06','FS07','FS08','FS09','FS10','FS11','FS12','FS13','FS14','FS15','FSCA','PFSC','RFSC','WCFS') THEN 'Act_Fuel'
	WHEN C.CHRG_CD IN ('ZREP','ZDHM') THEN 'Act_Repo'
	ELSE 'Act_Accessorials' END AS ChargeType, C.CHRG_AMT_DLR as ChargeAmount, C.PYMNT_AMT_DLR as PaymentAmount
FROM CHARGE_DETAIL_R C, FREIGHT_BILL_R F, LOAD_LEG_R L, VOUCHER_AP_R V
WHERE F.FRHT_BILL_NUM = V.FRHT_BILL_NUM
AND	F.FRHT_INVC_ID = V.FRHT_INVC_ID
AND	V.VCHR_NUM = C.VCHR_NUM_AP
AND V.LD_LEG_ID = L.LD_LEG_ID
AND L.CUR_OPTLSTAT_ID IN (345)
AND (TO_CHAR(L.STRD_DTT,'YYYYMMDD') >= '20190101' OR L.STRD_DTT IS NULL)
AND TO_CHAR(L.SHPD_DTT,'YYYYMMDD') >= '20190101'
AND L.EQMT_TYP In ('48FT','48TC','53FT','53TC','53IM','53RT')
AND F.CUR_STAT_ID In (910,915,925,930)
AND C.CHRG_CD IS NOT NULL
	);
	disconnect from oracle;
  quit;
run;

**Roll up Actual_Payments into summary table by LD_LEG_ID;
proc sql;
	create table Actual_Load_Charge as (
		select LD_LEG_ID, ChargeType, Sum(PaymentAmount) as PaymentAmount from Actual_Load_Charge
		group by LD_LEG_ID, ChargeType
			);
	quit;

** Transpose into one table by chargetype for columns ;
proc transpose data=Actual_Load_Charge out=Actual_Load_Charge;
 by ld_leg_id;
 var PaymentAmount;
 id ChargeType;
run; 

data Actual_Load_Charge;
	set Actual_Load_Charge;
	drop _Name_;
run;



**Merge Actual Linehaul, Fuel and Accessorials back into Actual_Load_Detail table;
proc sort data = Actual_Load_Detail; by LD_LEG_ID;
proc sort data = Actual_Load_Charge; by LD_LEG_ID;
data Actual_Load_Detail;
	merge work.Actual_Load_Detail(in=a) work.Actual_Load_Charge(in=b);
	by LD_LEG_ID;
	if a;
run;

**If Actuals are blank, default to pre-rate rates;
**Exclude FDCC carriers;
**If mileage = zero, change it to 1;
**Remove any load with Actual Linehaul = $1.00;
Data Actual_Load_Detail;
	set Actual_Load_Detail;
	if Srvc_Cd not in ('FDCC');
	if Act_Linehaul in ('','.',' ') and MARKETPLACE_CATCHALL = 'Y' then drop_it = 'Y';
	if Act_Linehaul in ('','.',' ') then Act_Fuel = PreRate_Fuel;
	if Act_Linehaul in ('','.',' ') then Act_Accessorials = PreRate_Accessorials;
	if Act_Linehaul in ('','.',' ') then Act_Linehaul = PreRate_Linehaul;
	if Act_Repo in ('','.',' ') then Act_Repo = PreRate_Repo;
	if FIXD_ITNR_DIST = 0 then FIXD_ITNR_DIST = 1;
	if Act_Linehaul not in (1);
	run;

DATA Actual_Load_Detail;
	SET Actual_Load_Detail(WHERE=(drop_it not in ('Y'))); RUN;


**Remove fuel from OPEN - CHECK CURRENT FUEL;
Data Actual_Load_Detail;
	set Actual_load_Detail;
	if SRVC_CD='OPEN' and EQMT_TYP not in ('53IM') then Act_Fuel = 0.32*FIXD_ITNR_DIST;
	if SRVC_CD='OPEN' and EQMT_TYP='53IM' then Act_Fuel = (0.32*FIXD_ITNR_DIST)/2;
	if SRVC_CD='OPEN' then Act_Linehaul = Act_Linehaul - Act_Fuel;
run;

**Determine order type for each Load;
Data Actual_Load_Detail;
	set Actual_Load_Detail;
	if Corp1_ID = 'RM' then OrderType = 'RM-INBOUND';
	else if Corp1_ID = 'RF' then OrderType = 'RF-INBOUND';
	else if substr(LAST_SHPG_LOC_CD,1,1)='R' THEN OrderType = 'RETURNS';
	else if substr(LAST_SHPG_LOC_CD,1,1) = '1' Then OrderType = 'INTERMILL';
	else if substr(LAST_SHPG_LOC_CD,1,1) = '2' Then OrderType = 'INTERMILL';
	else OrderType = 'CUSTOMER';
	frst_code = substr(frst_shpg_loc_cd,1,4);
	run;

**Determine Business Unit for each Load;
**Import master table for Inbound shipments to classify BU based on destination ID;
PROC IMPORT OUT= BU_Inbound
            DATAFILE= '\\uskvfn01\share\Transportation\Corporate Transportation\Fraser, Thomas\SAS\Inbound BU.xlsx'
            DBMS=EXCEL REPLACE;
     SHEET="Inbound Business Unit"; 
RUN;

Data BU_Inbound;
	set BU_Inbound;
	last_shpg_loc_cd=Ship_To_ID;
	IB_BU=Business;
	if Last_Shpg_Loc_Cd not in ('99999999');
	drop Ship_To_ID F6 F7 Business Ship_to_State Ship_to_City Ship_to_Name;
	run;

Data BU_Inbound_2;
	set BU_Inbound;
	frst_code=substr(last_shpg_loc_cd,1,4);
	IB_BU2=IB_BU;
	drop last_shpg_loc_cd IB_BU;
	run;

proc sql;
	create table BU_Inbound_2 as (
		select Distinct Frst_Code, IB_BU2 from BU_Inbound_2
			);
	quit;

	/*
**Import business unit from TM for outbound shipments;
proc sql;
      connect to oracle (path='NAJDAPRD' user=&id password=&pwd);
      create table BU_Outbound as select * from connection to oracle
      (
SELECT DISTINCT L.LOAD_ID as LD_LEG_ID, L.UNIT_DESC_BY_WGT as OB_BU
FROM ABPP_LD_RFRC_T L
WHERE TO_CHAR(L.CRTD_DTT,'YYYYMMDD')>='20190101'
AND LOAD_ID NOT IN ('516727251')
	);
	disconnect from oracle;
  quit;
run;
*/

** Create another backup table to fill in gaps for business unit **;
PROC SQL;
      connect to oracle (path='NAJDAPRD' user=&id password=&pwd);
      create table LOAD_BU as select * from connection to oracle (
SELECT DISTINCT LD_LEG_ID, OB_BU
                    FROM
                        (SELECT LD_LEG_ID,
                            CASE WHEN BUSINESS IS NULL THEN BUS_UNIT ELSE BUSINESS END AS OB_BU, VOL_RANK
                        FROM
                            (SELECT DISTINCT L.LD_LEG_ID, SH.RFRC_NUM10 AS BU, SH.VOL,
                                CASE WHEN SUBSTR(LAST_SHPG_LOC_CD,1,4) IN ('2000','2019','2022','2023','2024','2026','2027','2028','2029','2031','2032','2035','2036','2038','2041','2049','2050','2054','2063','2075','2094','2100','2137','2138','2142','2170','2171','2172','2183','2187','2191','2197','2210','2213','2240','2275','2283','2291','2292','2300','2303','2307','2314','2320','2331','2336','2347','2353','2358','2359','2360','2369','2370','2385','2399','2408','2412','2414','2419','2422','2443','2463','2483','2487','2489','2496','2500','2510','2511','2822','2839') THEN 'Consumer'
                                WHEN SUBSTR(LAST_SHPG_LOC_CD,1,4) IN ('2034','2039','2040','2042','2043','2044','2048','2051','2079','2080','2091','2096','2099','2104','2106','2111','2112','2113','2124','2126','2161','2177','2200','2234','2299','2301','2302','2304','2310','2323','2325','2334','2348','2349','2350','2356','2362','2363','2375','2386','2415','2416','2425','2429','2446','2449','2459','2460','2467','2474','2476','2477','2485','2495','2505','2827','2833','2834','2837') THEN 'KCP' ELSE '' END BUS_UNIT,
                                CASE WHEN SH.RFRC_NUM10 IN ('2810','2820','Z01') THEN 'Consumer'
                                WHEN SH.RFRC_NUM10 IN ('2811','2821','Z02','Z04','Z06','Z07') THEN 'KCP'
                                WHEN SH.RFRC_NUM10 = 'Z05' THEN 'NON WOVENS' ELSE '' END BUSINESS,
                                RANK () OVER (PARTITION BY L.LD_LEG_ID ORDER BY SH.VOL DESC) AS VOL_RANK 
                            FROM LOAD_LEG_R L, LOAD_LEG_DETAIL_R LD, SHIPMENT_R SH
                            WHERE L.LD_LEG_ID = LD.LD_LEG_ID
                            AND LD.SHPM_NUM = SH.SHPM_NUM
                            AND L.CUR_OPTLSTAT_ID >= 320
                            AND (TO_CHAR(STRD_DTT,'YYYYMMDD') >= '20190101' OR STRD_DTT IS NULL)
							AND TO_CHAR(L.SHPD_DTT,'YYYYMMDD') >= '20190101'
                            AND L.EQMT_TYP IN ('53FT','53IM','53RT','53TC','53HC','48FT')
                            AND LAST_CTRY_CD IN ('MEX','CAN','USA')))
WHERE VOL_RANK = 1
);
DISCONNECT FROM ORACLE;
QUIT;
RUN;

/*
** combine tables **;
proc sql;
	create table bu_outbound as (
		select bu.*, load.ob_bu
		from bu_outbound bu
		full outer join load_bu load
		on bu.ld_leg_id = load.ld_leg_id);
	quit;
run;
*/


** if ABPP table has null business unit value, use value from ranking query table on shipment level **;
data bu_outbound;
	set LOAD_BU;
run;


**Merge BU tables into Actual_Load_Detail;
proc sort data = Actual_Load_Detail; by LD_LEG_ID;
proc sort data = BU_Outbound; by LD_LEG_ID;
data Actual_Load_Detail;
	merge work.Actual_Load_Detail(in=a) work.BU_Outbound(in=b);
	by LD_LEG_ID;
	if a;
run;

proc sort data = Actual_Load_Detail; by LAST_SHPG_LOC_CD;
proc sort data = BU_Inbound; by LAST_SHPG_LOC_CD;
data Actual_Load_Detail;
	merge work.Actual_Load_Detail(in=a) work.BU_Inbound(in=b);
	by LAST_SHPG_LOC_CD;
	if a;
run;

proc sort data = Actual_Load_Detail; by frst_code;
proc sort data = BU_Inbound_2; by frst_code;
data Actual_Load_Detail;
	merge work.Actual_Load_Detail(in=a) work.BU_Inbound_2(in=b);
	by frst_code;
	if a;
run;

**Determine final BU based on OrderType and IB_BU and OB_BU fields;
Data Actual_Load_Detail;
	set Actual_Load_Detail;
	if OrderType = 'RM-INBOUND' then BU = IB_BU; else if OrderType = 'RF-INBOUND' then BU = IB_BU; else BU = OB_BU;
	if BU in ('','.',' ') and OrderType = 'INTERMILL' then BU = IB_BU2;
	if BU in ('','.',' ') and OrderType not in ('INTERMILL') then BU = IB_BU;
	if BU in ('','.',' ') and IB_BU2 not in ('','.',' ') then BU = IB_BU2;
	if BU in ('','.',' ') and IB_BU not in ('','.',' ') then BU = IB_BU;
run;

Data Actual_Load_Detail;
	set Actual_Load_Detail;
	BU = UPCASE(BU);
	drop IB_BU OB_BU IB_BU2 frst_code;
run;

**Add additional fields to data set for analysis purposes;
Data Actual_Load_Detail;
	set Actual_Load_Detail;
	if eqmt_typ = '53IM' then ShipMode = 'INTERMODAL';
	else ShipMode = 'TRUCK'; 
	Year = Year(Strd_Dtt);
	Month = Month(Strd_dtt);
	Week_Beginning = Strd_Dtt - MOD((Strd_dtt-2),7);
	format Week_Beginning mmddyy10.;
run;

data no_bu; set Actual_Load_Detail(where=(BU in (' ','','.'))); run;

**Add DEST ZONE in the same naming convention as the rate structure (5+STATE+ZIP for US OR STATE + 6 CHARACTERS OF CITY for CAN/MEX);
Data Actual_Load_Detail;
	set Actual_Load_Detail;
	StCity = catt(Last_Sta_Cd,compress(Last_Cty_Name, , 's'));
	if LAST_CTRY_CD='USA' then DEST_ZONE = catt('5',LAST_STA_CD,substr(LAST_PSTL_CD,1,5));
	if LAST_CTRY_CD='USA' then dest3zip = catt('US-',LAST_STA_CD,substr(LAST_PSTL_CD,1,3));
	ORIGINSTCITY = catt(FRST_STA_CD, compress(FRST_CTY_NAME, , 'S'));
	RUN;

**Import master table for Zone Lookup for Canada/Mexico City;
PROC IMPORT OUT= CityStZone
            DATAFILE= '\\uskvfn01\share\Transportation\Corporate Transportation\Award Strategy\Backup Files\TMS Master Zones List.xlsx'
            DBMS=EXCEL REPLACE;
     SHEET="CitySt Zone";
	 RANGE="B1:F12000";
RUN;

data CityStZone; set CityStZone; keep StCity Zone; run;

Data OCityStZone;
	set CityStZone;
	ORIGINSTCITY = StCity;
	Origin_Zone2 = Zone;
	drop StCity Zone;
run;


**Merge CityStZone into Actual_Load_Detail to fill in the DEST_ZONE gaps for Canada & Mexico destinations;
proc sort data = Actual_Load_Detail; by ORIGINSTCITY;
proc sort data = OCityStZone; by ORIGINSTCITY;
data Actual_Load_Detail;
	merge work.Actual_Load_Detail(in=a) work.OCityStZone(in=b);
	by ORIGINSTCITY;
	if a;
run;

**Merge CityStZone into Actual_Load_Detail to fill in the ORIGIN_ZONE gaps for Canada & Mexico destinations;
proc sort data = Actual_Load_Detail; by StCity;
proc sort data = CityStZone; by StCity;
data Actual_Load_Detail;
	merge work.Actual_Load_Detail(in=a) work.CityStZone(in=b);
	by StCity;
	if a;
run;

Data Actual_Load_Detail;
	set Actual_Load_Detail;
	if Origin_Zone in ('','.',' ') then Origin_Zone = Origin_Zone2;
	if DEST_ZONE in ('','.',' ') then DEST_ZONE = Zone;
	IF FRST_CTY_NAME = 'GUILDERLAND CENTER' THEN ORIGIN_ZONE = 'NYGUICEN';
	ELSE IF FRST_CTY_NAME = 'COWPENS' AND FRST_STA_CD = 'SC' THEN ORIGIN_ZONE = 'SCCOWPEN';
	ELSE IF FRST_CTY_NAME = 'RANSOM' AND FRST_STA_CD = 'PA' THEN ORIGIN_ZONE = 'PARANSOM';
	ELSE IF FRST_CTY_NAME = 'HANOVER TOWNSHIP' AND FRST_STA_CD = 'PA' THEN ORIGIN_ZONE = 'PAHANOVT';
	ELSE IF FRST_CTY_NAME = 'HANOVER PARK' AND FRST_STA_CD = 'IL' THEN ORIGIN_ZONE = 'ILHANPAR';
	ELSE IF FRST_CTY_NAME = 'MT. HOLLY' AND FRST_STA_CD = 'NJ' THEN ORIGIN_ZONE = 'NJMOUNTH';
	ELSE IF FRST_CTY_NAME = 'CONNELLY SPINGS' AND FRST_STA_CD = 'NC' THEN ORIGIN_ZONE = 'NCCONNEL';
	ELSE IF FRST_CTY_NAME = 'MT VERNON' AND FRST_STA_CD = 'OH' THEN ORIGIN_ZONE = 'OHMOUNTV';
	ELSE IF FRST_CTY_NAME = 'FORT LAUDERDALE' THEN ORIGIN_ZONE = 'FLFTLAUD';
	ELSE IF FRST_CTY_NAME = 'FORT MYERS' THEN ORIGIN_ZONE = 'FLFTMYER';
	ELSE IF FRST_CTY_NAME = 'FORT MEYERS' THEN ORIGIN_ZONE = 'FLFTMYER';
	ELSE IF FRST_CTY_NAME = 'WINTER GARDEN' THEN ORIGIN_ZONE = 'FLWINGAR';
	ELSE IF FRST_CTY_NAME = 'EAST PEORIA' THEN ORIGIN_ZONE = 'ILEPEORI';
	ELSE IF FRST_CTY_NAME = 'WEST BERLIN' THEN ORIGIN_ZONE = 'NJWBERLI';
	ELSE IF FRST_CTY_NAME = 'CUYAHOGA HEIGHTS' THEN ORIGIN_ZONE = 'OHCUYHEI';
	ELSE IF FRST_CTY_NAME = 'SPRINGFIELD' AND FRST_STA_CD='OH' THEN ORIGIN_ZONE = 'OHSPRFIE';
	ELSE IF FRST_CTY_NAME = 'WILLIAMSPORT' THEN ORIGIN_ZONE = 'PAWILPOR';
	ELSE IF FRST_CTY_NAME = 'WEST ALLIS' THEN ORIGIN_ZONE = 'WIWALLIS';
	ELSE IF FRST_CTY_NAME = 'TERRACE BAY' THEN ORIGIN_ZONE = 'ONTERBAY';
	ELSE IF FRST_CTY_NAME = 'FRANKLIN PARK' THEN ORIGIN_ZONE = 'ILFRAPAR';
	ELSE IF FRST_CTY_NAME = 'LEBANON JUNCTION' THEN ORIGIN_ZONE = 'KYLEBJUN';
	ELSE IF FRST_CTY_NAME = 'ELIZABETHTOWN' THEN ORIGIN_ZONE = 'PAELITOW';
	Lane = catt(Origin_Zone, '-', DEST_ZONE);
	Lane3zip = catt(Origin_Zone, '-', dest3zip);
	drop StCity Zone ORIGINSTCITY Origin_Zone2;
run;



/* Keep table if we want to export 2018 table to import into 2019 price program
libname out '\\uskvfn01\share\Transportation\Corporate Transportation\Fraser, Thomas\SAS\';
proc datasets library=work nodetails nolist;
copy in=work out=out;
select Actual_Load_Detail;
run;quit;
*/

**Import Award Tables for award lane, award carrier, and award price metrics **;
PROC IMPORT OUT= Award_Lanes
            DATATABLE= Award_Lanes
            DBMS=ACCESS REPLACE;
     DATABASE='\\uskvfn01\share\Transportation\Corporate Transportation\Award Strategy\Current Awards - TLIM.accdb'; 
     SCANMEMO=YES;
     USEDATE=NO;
     SCANTIME=YES;
RUN;

Data Award_Lanes; set Award_Lanes(where=(ShipMode="TLIM")); run;

PROC IMPORT OUT= Award_Carr
            DATATABLE= Award_Carr
            DBMS=ACCESS REPLACE;
     DATABASE='\\uskvfn01\share\Transportation\Corporate Transportation\Award Strategy\Current Awards - TLIM.accdb'; 
     SCANMEMO=YES;
     USEDATE=NO;
     SCANTIME=YES;
RUN;

** Combine tables into one award table for lanes and carriers **;
proc sql;
	create table awards as (
		select OriginZone, DestZone, LaneAnnVol, LaneWkVol, Order_Type, ShipMode, al.EffectiveDate as LaneEff, al.ExpirationDate as LaneExp, PrimaryCustomer, al.Mileage, Service, Rank, AwardPct, CarrWkVol, CarrWkVol_Surge,
			ac.EffectiveDate as CarrEff, ac.ExpirationDate as CarrExp, EquipType, AwardRPM
		from award_lanes al
		join award_carr ac
		on al.laneid = ac.laneid
		where shipmode = 'TLIM');
	quit;
run;

** Format dates to mm/dd/yyyy- this is done to perform easier calculations in SAS **;
data awards;
	set awards;
	format LaneEff mmddyy10.;
	LaneEff = datepart(LaneEff); 
	format LaneExp mmddyy10.;
	LaneExp = datepart(LaneExp);
	format CarrEff mmddyy10.;
	CarrEff = datepart(CarrEff); 
	format CarrExp mmddyy10.;
	CarrExp = datepart(CarrExp);
	if OriginZone not in ('','.',' ');
run;

**Roll up award RPM into a table by lane and mode (equipment type)- this section will get the weighted RPM by mode;
proc sql;
	create table award_mode_targets as (
		select distinct OriginZone, DestZone, AwardRPM * AwardPct/sum(AwardPct) as Award_mode_RPM, EquipType, sum(CarrWkVol) as CarrWkVol, sum(CarrWkVol_Surge) as CarrWkVol_Surge
		from awards
		where CarrExp > today()
		group by OriginZone, DestZone, EquipType);
	quit;
run;

** this sections sums up the weighted RPM into lane and equipment type, from previous section **;
proc sql;
	create table award_mode_targets as (
		select distinct OriginZone, DestZone, EquipType, sum(Award_mode_RPM) as Award_mode_RPM label='Award_mode_RPM', CarrWkVol, CarrWkVol_Surge
		from award_mode_targets
		group by OriginZone, DestZone, EquipType);
	quit;
run;

data award_mode_targets;
	set award_mode_targets;
	lane = cats(OriginZone,'-',DestZone);
run;

** Create 5 digit and 3 digit lanes in actual load table **;
data Actual_Load_Detail;
	set Actual_Load_Detail;
	lanesrvc = cats(lane, srvc_cd);
	lanesrvc3zip = cats(lane3zip, srvc_cd);
	week_num = week(strd_dtt) + 1;
run;


** bring in 5 digit lane awards ;
proc sql;
	create table Actual_Load_Detail as (
		select distinct ald.*, LaneEff, LaneExp
		from Actual_Load_Detail ald
		left join awards
		on ald.lane = cats(awards.originzone,'-',awards.destzone));
	quit;
run;

** combine 3 digit lane awards ;
proc sql;
	create table Actual_Load_Detail as (
		select distinct ald.*, awards.LaneEff as laneeff3zip label='laneeff3zip', awards.LaneExp as laneexp3zip label='laneexp3zip'
		from Actual_Load_Detail ald
		left join awards
		on ald.lane3zip = cats(awards.originzone,'-',awards.destzone));
	quit;
run;

** if 5 digit lane, then use that. if 3 digit lane, use that, drop 3 digit fields ;
data Actual_Load_Detail;
	set Actual_Load_Detail;
	if laneeff in (' ','.','') and laneeff3zip not in (' ','.','') then awardlane=lane3zip; else if laneeff not in (' ','.','') then awardlane=lane; else awardlane='';
	if laneeff in (' ','.','') then laneeff=laneeff3zip; else laneeff=laneeff;
	if laneexp in (' ','.','') then laneexp=laneexp3zip; else laneexp=laneexp;
	drop lane3zip laneeff3zip laneexp3zip;
run;

** bring in award carrier effective dates and award RPM **;
proc sql;
	create table Actual_Load_Detail as (
		select distinct ald.*, CarrEff, CarrExp, AwardRPM
		from Actual_Load_Detail ald
		left join awards
		on cats(ald.awardlane, srvc_cd, eqmt_typ) = cats(awards.originzone,'-',awards.destzone, service, equiptype));
	quit;
run;

** calculate whether lane and carrier is effective on lane **;
data Actual_Load_Detail; set Actual_Load_Detail;
	if awardlane not in (' ','.','') and strd_dtt >= LaneEff and strd_dtt <= LaneExp then AwardLaneEff = 'Y'; else AwardLaneEff = 'N';
	if awardlane not in (' ','.','') and strd_dtt >= CarrEff and strd_dtt <= CarrExp then AwardCarrEff = 'Y'; else AwardCarrEff = 'N';
	drop LaneEff LaneExp CarrEff CarrExp dest3zip;
run; 
/*
** bring in award mode RPM targets **;
proc sql;
	create table Actual_Load_Detail as (
		select distinct ald.*, Award_mode_RPM, CarrWkVol, CarrWkVol_Surge
		from Actual_Load_Detail ald
		left join Award_Mode_Targets amt
		on cats(ald.awardlane, eqmt_typ) = cats(amt.lane, equiptype));
	quit;
run;
*/

** create weighted award targets as opposed to by equipment type **;



proc sql;
	create table award_targets as (
		select distinct OriginZone, DestZone, AwardRPM * AwardPct/sum(awardpct) as Award_weighted_RPM, CarrWkVol, CarrWkVol_Surge
		from awards
		where CarrExp > today()
		and ShipMode = "TLIM"
		group by OriginZone, DestZone);
	quit;
run;

proc sql;
	create table award_targets as (
		select distinct OriginZone, DestZone, sum(Award_weighted_RPM) as Award_weighted_RPM, sum(CarrWkVol) as CarrWkVol, sum(CarrWkVol_Surge) as CarrWkVol_Surge
		from award_targets
		group by OriginZone, DestZone);
	quit;
run;

data award_targets; set award_targets(where=(Award_weighted_RPM not in (' ','','.'))); run;


** bring in award weighted RPM to actual loads **;
proc sql;
	create table Actual_Load_Detail as (
		select distinct ald.*, at.Award_weighted_RPM, CarrWkVol, CarrWkVol_Surge
		from Actual_Load_Detail ald
		left join award_targets at
		on cats(ald.awardlane) = cats(at.OriginZone,'-',DestZone));
	quit;
run;


**Import in 2018 Bid Rates;
PROC IMPORT OUT= BidRates_2018
            DATATABLE= "Bid Targets"
            DBMS=ACCESS REPLACE;
     DATABASE='\\uskvfn01\share\Transportation\Corporate Transportation\Access Data Base\Previous Year Files\2018_Cost_Service_Database - Revised.accdb'; 
     SCANMEMO=YES;
     USEDATE=NO;
     SCANTIME=YES;
RUN;

**rename field **;
data BidRates_2018;
	set BidRates_2018;
	Bid_2018_RPM = BID_RPM;
	drop BID_RPM;
run;

**Import in 2019 Bid Rates;
PROC IMPORT OUT= BidRates
            DATATABLE= "Bid Targets"
            DBMS=ACCESS REPLACE;
     DATABASE='\\uskvfn01\share\Transportation\Corporate Transportation\Access Data Base\Current_Cost_Service_Database - TLIM.accdb'; 
     SCANMEMO=YES;
     USEDATE=NO;
     SCANTIME=YES;
RUN;

** rename field ;
data BidRates;
	set BidRates;
	AwardLane = Lane;
	drop Lane;
run;

**Merge in Bid Rates;
proc sort data = Actual_Load_Detail; by AwardLane;
proc sort data = Bidrates; by AwardLane;
data Actual_Load_Detail;
	merge work.Actual_Load_Detail(in=a) work.Bidrates(in=b);
	by AwardLane;
	if a;
run;

**Merge in 2018 Bid Rates for January & early February **;
proc sort data = Actual_Load_Detail; by Lane;
proc sort data = Bidrates_2018; by Lane;
data Actual_Load_Detail;
	merge work.Actual_Load_Detail(in=a) work.Bidrates_2018(in=b);
	by Lane;
	if a;
run;

**If earlier than Feb. 10th, use last year's bid rpm **;
data Actual_Load_Detail;
	set Actual_Load_Detail;
	if strd_dtt < '10-FEB-2019'd then bid_rpm = bid_2018_rpm; else bid_rpm=bid_rpm;
	drop bid_2018_rpm;
run;

**Add Y/N Flag if there is a Bid Rate;
Data Actual_Load_Detail;
	set Actual_Load_Detail;
	if Bid_RPM in ('.') then BidCheck = 'N';
	else BidCheck = 'Y';
run;

/*
data load_detail;
	set actual_load_detail;
	act_rpm = act_linehaul/fixd_itnr_dist;
	bid_norm = bid_rpm * fixd_itnr_dist;
	award_norm = award_weighted_rpm * fixd_itnr_dist;
	overspend_bid = act_linehaul - bid_norm;
	overspend_award = act_linehaul - award_norm;
	drop drop_it lanesrvc lanesrvc3zip other_eqmt;
run;
*/

DATA load_detail;
	set actual_load_detail;
	drop CORP1_ID ACTL_CHGD_AMT_DLR drop_it lanesrvc lanesrvc_3zip awardrpm;
run;

PROC EXPORT
    DATA=work.load_detail
    OUTTABLE="Actual Load Detail"
    DBMS=ACCESS2000 REPLACE;
    DATABASE="\\uskvfn01\share\Transportation\Corporate Transportation\Access Data Base\2019 Load Detail.accdb";
RUN;



PROC EXPORT
    DATA=work.planner_detail
    OUTTABLE="Actual Load Detail"
    DBMS=ACCESS2000 REPLACE;
    DATABASE="\\uskvfn01\share\Transportation\Corporate Transportation\Access Data Base\Planners - Award vs Actual.accdb";
RUN;

PROC EXPORT
    DATA=work.Awards
    OUTTABLE="Awards"
    DBMS=ACCESS2000 REPLACE;
    DATABASE="\\uskvfn01\share\Transportation\Corporate Transportation\Access Data Base\Award Summary.accdb";
RUN;
