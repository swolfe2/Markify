USE [USCTTDEV]
GO
/****** Object:  StoredProcedure [dbo].[sp_AAO]    Script Date: 6/15/2021 8:06:59 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Steve Wolfe, steve.wolfe@kcc.com, Central Transportation Team
-- Create date: 10/25/2019
-- Last modified: -- 6/15/2021 - Added logic to make sure only active AAO's are on each lane
-- 7/30/2020 - SW - Will now update Bid App RFP tables with AAO details
--7/29/2020 - SW - Overhaul from previous wipe/rebuild process to an append/update process. Also added queries to build tblLaneAAOLocation
--7/22/2020 - SW - Added AND UPPER(t7.EXTL_CD1) NOT LIKE ''%OBSOLETE%'' to for "OBSOLETE" strings
--11/5/2019 - SW - Complete overhaul. Moved to loading table directly from Oracle, and then updating Rates table with Carriage Return strings 
-- Description:	Update USCTTDEV.dbo.tblBidAppLanes and USCTTDEV.dbo.tblBidAppRates with AAO information
-- =============================================

ALTER PROCEDURE [dbo].[sp_AAO]

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

/*
What is this file doing?

1) Update LaneID of tblLaneAAO to match, where there's a match on tblBidAppLanes
2) Update tblBidAppRates to AAO + Description where there's a match to tblLaneAAO
3) Update tblBidAppRates to AAO + Description where there's a match to tblLaneAAO to the Origin
4) Update tblBidAppRates to AAO + Description where there's a match to tblLaneAAO to the Destination
5) Update tblBidAppLanes if there's a match to the lane ID from Bid App Rates
*/

/*
Delete dbo.tblLaneAAO
DELETE FROM USCTTDEV.dbo.tblLaneAAO
*/

DROP TABLE IF EXISTS ##tblLaneAAODetailTemp

/*
Insert Oracle AAO's into USCTTDEV.dbo.tblLaneAAO
SELECT * FROM ##tblLaneAAODetailTemp WHERE String = '5NC28273'
SELECT * FROM USCTTDEV.dbo.tblLaneAAO
*/
SELECT * INTO ##tblLaneAAODetailTemp FROM(
  SELECT DISTINCT
    CHRG_CD AS AAO,
    CHRG_DESC AS [AAO Description],
    SRVC_CD AS [Carrier Service],
    'Y' as Eligible,
    TypeDesc AS [OriginDestination],
    JoinString AS [String]
  FROM (SELECT DISTINCT CHRG_CD, CHRG_DESC, TFF_ID, TFF_CD, TFF_DESC, CARR_CD, SRVC_CD, TFF_STAT_ENU, CHRG_COND_YN, EXPD_DT, 
SYSDATE, shpg_loc_cd, NAME, CTRY_CD, CTY_NAME, STA_CD, CITYSTATE, PSTL5, TYPE, CASE WHEN TYPE = 'Load At' THEN 'ORIGIN' ELSE 'DESTINATION' END AS TypeDesc, EXTL_CD1, EXTL_CD2, Code, CityStateJoin,
CASE WHEN TYPE <> 'Load At' and CTRY_CD = 'USA' THEN '5'+Sta_Cd+Pstl5 ELSE Code END AS JoinString

FROM (
SELECT * FROM OPENQUERY(NAJDAPRD,'SELECT DISTINCT
    t3.chrg_cd,
    t3.chrg_desc,
    t2.tff_id,
    t2.tff_cd,
    t2.tff_desc,
    t2.carr_cd,
    t3.srvc_cd,
    t2.tff_stat_enu,
    t3.chrg_cond_yn,
    t2.expd_dt,
    SYSDATE,
    t4.shpg_loc_cd,
    t5.name,
    t6.ctry_cd,
    t6.cty_name,
    t6.sta_cd,
    t6.cty_name || '', '' || t6.sta_cd As CityState,
    CASE
        WHEN t6.ctry_cd = ''USA'' THEN
            substr(t6.pstl_cd, 1, 5)
        ELSE
            t6.pstl_cd
    END AS pstl5,
    ''Load At'' AS type,
    t7.extl_cd1 as extl_cd1,
    t7.extl_cd2 as extl_cd2
FROM
    najdaadm.carrier_r               t1
    JOIN najdaadm.tariff_r                t2 ON t2.carr_cd = t1.carr_cd
    JOIN najdaadm.tariff_charge_r         t3 ON t3.tff_id = t2.tff_id
    JOIN najdaadm.auto_applied_option_r   t4 ON t4.chrg_cd = t3.chrg_cd
    JOIN najdaadm.load_at_r               t5 ON t5.shpg_loc_cd = t4.shpg_loc_cd
    JOIN najdaadm.address_r               t6 ON t6.addr_id = t5.addr_id
    JOIN najdaadm.master_charges_r        t7 ON t7.chrg_cd = t3.chrg_cd 
WHERE
    ( ( t3.chrg_cond_yn = ''N'' )
      AND ( t2.tff_stat_enu = ''Active'' )
      AND ( t3.srvc_cd NOT IN (
        ''OPEN'',
        ''ZAR'',
        ''ZARL'',
        ''UYSN'',
        ''ASFH'',
        ''BEDF'',
        ''CNWY'',
        ''FXFE'',
        ''FXNL'',
        ''ODFL'',
        ''RETL'',
        ''UPGF'',
        ''VITY''
    ) )
      AND ( t2.expd_dt >= SYSDATE )
      AND ( substr(t3.chrg_cd, 1, 1) >= ''A''
            AND substr(t3.chrg_cd, 1, 1) <= ''W'' )
      AND t3.chrg_cd NOT IN (
        ''USPS'',
        ''SDSD'',
        ''HAZM''
    )
      AND t6.ctry_cd IN (
        ''USA'',
        ''CAN'',
  	''MEX''
    )
      AND t6.sta_cd NOT IN (
        ''00''
    )
      AND ( t1.carr_typ = ''Road'' )
      AND t4.aply_frm_ap_enu = ''Apply When Routing and Rating''
	  AND UPPER(t7.EXTL_CD1) NOT LIKE ''%OBSOLETE%''	  
	  )
UNION ALL
SELECT DISTINCT
    t3.chrg_cd,
    t3.chrg_desc,
    t2.tff_id,
    t2.tff_cd,
    t2.tff_desc,
    t2.carr_cd,
    t3.srvc_cd,
    t2.tff_stat_enu,
    t3.chrg_cond_yn,
    t2.expd_dt,
    SYSDATE,
    t4.shpg_loc_cd,
    t5.name,
    t6.ctry_cd,
    t6.cty_name,
    t6.sta_cd,
    t6.cty_name || '', '' || t6.sta_cd As CityState,
    CASE
        WHEN t6.ctry_cd = ''USA'' THEN
            substr(t6.pstl_cd, 1, 5)
        ELSE
            t6.pstl_cd
    END AS pstl5,
    ''Distribution Center'' AS type,
    t7.extl_cd1 as extl_cd1,
    t7.extl_cd2 as extl_cd2
FROM
    najdaadm.carrier_r               t1
    JOIN najdaadm.tariff_r                t2 ON t2.carr_cd = t1.carr_cd
    JOIN najdaadm.tariff_charge_r         t3 ON t3.tff_id = t2.tff_id
    JOIN najdaadm.auto_applied_option_r   t4 ON t4.chrg_cd = t3.chrg_cd
    JOIN najdaadm.distribution_center_r   t5 ON t5.shpg_loc_cd = t4.dc_shpg_loc_cd
    JOIN najdaadm.address_r               t6 ON t6.addr_id = t5.addr_id
    JOIN najdaadm.master_charges_r        t7 ON t7.chrg_cd = t3.chrg_cd 
WHERE
    ( ( t3.chrg_cond_yn = ''N'' )
      AND ( t2.tff_stat_enu = ''Active'' )
      AND ( t3.srvc_cd NOT IN (
        ''OPEN'',
        ''ZAR'',
        ''ZARL'',
        ''UYSN'',
        ''ASFH'',
        ''BEDF'',
        ''CNWY'',
        ''FXFE'',
        ''FXNL'',
        ''ODFL'',
        ''RETL'',
        ''UPGF'',
        ''VITY''
    ) )
      AND ( t2.expd_dt >= SYSDATE )
      AND ( substr(t3.chrg_cd, 1, 1) >= ''A''
            AND substr(t3.chrg_cd, 1, 1) <= ''W'' )
      AND t3.chrg_cd NOT IN (
        ''USPS'',
        ''SDSD'',
        ''HAZM''
    )
      AND t6.ctry_cd IN (
        ''USA'',
        ''CAN'',
		''MEX''
    )
      AND t6.sta_cd NOT IN (
        ''00''
    )
      AND ( t1.carr_typ = ''Road'' )
      AND t4.aply_frm_ap_enu = ''Apply When Routing and Rating''
	  AND UPPER(t7.EXTL_CD1) NOT LIKE ''%OBSOLETE%'')
ORDER BY
    chrg_cd,
    srvc_cd') data

LEFT JOIN (SELECT DISTINCT Code, CityStateJoin FROM (
SELECT DISTINCT ORIG_CITY_STATE as Code, ORIGIN as CityStateJoin
FROM USCTTDEV.dbo.tblBidAppLanes
UNION ALL
SELECT DISTINCT DEST_CITY_STATE as Code, Dest as CityStateJoin
FROM USCTTDEV.dbo.tblBidAppLanes
WHERE DESTCountry <> 'USA') NonUS) NonUs ON NonUs.CityStateJoin = data.CityState) data
GROUP BY 
CHRG_CD, CHRG_DESC, TFF_ID, TFF_CD, TFF_DESC, CARR_CD, SRVC_CD, TFF_STAT_ENU, CHRG_COND_YN, EXPD_DT, 
SYSDATE, shpg_loc_cd, NAME, CTRY_CD, CTY_NAME, STA_CD, CITYSTATE, PSTL5, TYPE, CASE WHEN TYPE = 'Load At' THEN 'ORIGIN' ELSE 'DESTINATION' END , EXTL_CD1, EXTL_CD2, Code, CityStateJoin,
CASE WHEN TYPE <> 'Load At' and CTRY_CD = 'USA' THEN '5'+Sta_Cd+Pstl5 ELSE Code END
) AAO) data

/*
Add missing AAOs to dbo_tblLaneAAO
SELECT * FROM ##tblLaneAAODetailTemp
*/
INSERT INTO ##tblLaneAAODetailTemp (AAO, [AAO Description], [Carrier Service], Eligible, OriginDestination, String)
VALUES 
('2325','KCDC ADR ASSEMBLING CONTRACTORS','SCNN','Y','DESTINATION','AGSANFRA'),
('2325','KCDC ADR ASSEMBLING CONTRACTORS','SWFT','Y','DESTINATION','AGSANFRA'),
('2325','KCDC ADR ASSEMBLING CONTRACTORS','WENP','Y','DESTINATION','AGSANFRA')
;

/*
Update JBHunt SCACs since they didn't submit bids, but will on new SCAC
DELETE FROM USCTTDEV.dbo.tblLaneAAO WHERE [Carrier Service] = 'HMKD'
*/
INSERT INTO ##tblLaneAAODetailTemp (AAO, [AAO Description], [Carrier Service], Eligible, OriginDestination, String)
SELECT AAO, [AAO Description], 'HMKD', Eligible, OriginDestination, String
FROM(
SELECT DISTINCT AAO, [AAO Description], Eligible, OriginDestination, String
FROM ##tblLaneAAODetailTemp
WHERE [Carrier Service] = 'HJBT' OR [Carrier Service] = 'HJBT'
) Data
ORDER BY AAO Asc

/*
Add current date/time column
SELECT * FROM ##tblLaneAAODetailTemp
SELECT * FROM USCTTDEV.dbo.tblLaneAAO WHERE AAO = '2325'
*/
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'CurrentTime'	AND TABLE_NAME LIKE '##tblLaneAAODetailTemp') ALTER TABLE ##tblLaneAAODetailTemp ADD [CurrentTime]	DATETIME NULL
UPDATE ##tblLaneAAODetailTemp SET CurrentTime = GETDATE()


/*
Insert AAO's where they are not already on the table
SELECT * FROM USCTTDEV.dbo.tblLaneAAO WHERE String = '5NC28273'
*/
INSERT INTO USCTTDEV.dbo.tblLaneAAO (AddedOn, LastUpdated, AAO, [AAO Description], [Carrier Service], Eligible, OriginDestination, String)
SELECT ladt.CurrentTime, ladt.CurrentTime, ladt.AAO, ladt.[AAO Description], ladt.[Carrier Service], ladt.Eligible, ladt.OriginDestination, ladt.String
FROM ##tblLaneAAODetailTemp ladt
LEFT JOIN USCTTDEV.dbo.tblLaneAAO la ON la.AAO = ladt.AAO
AND la.[Carrier Service] = ladt.[Carrier Service]
WHERE la.AAO IS NULL
AND la.[Carrier Service] IS NULL
ORDER BY ladt.AAO ASC, ladt.[Carrier Service] ASC

/*
Update existing rows where they match
SELECT * FROM USCTTDEV.dbo.tblLaneAAO WHERE AAO = '2325'
*/
UPDATE USCTTDEV.dbo.tblLaneAAO
SET LastUpdated = ladt.CurrentTime,
[AAO Description] = ladt.[AAO Description],
Eligible = ladt.Eligible,
OriginDestination = ladt.OriginDestination,
String = ladt.String
FROM USCTTDEV.dbo.tblLaneAAO la
INNER JOIN ##tblLaneAAODetailTemp ladt ON ladt.AAO = la.AAO
AND ladt.[Carrier Service] = la.[Carrier Service]

/*
Set Eligible to N if it's no longer an active AAO
*/
UPDATE USCTTDEV.dbo.tblLaneAAO
SET Eligible = 'N',
LastUpdated = GETDATE()
FROM USCTTDEV.dbo.tblLaneAAO la
LEFT JOIN ##tblLaneAAODetailTemp ladt ON ladt.AAO = la.AAO
AND ladt.[Carrier Service] = la.[Carrier Service]
WHERE ladt.AAO IS NULL
AND ladt.[Carrier Service] IS NULL

/*
Drop all temp tables, and ensure a clean process
*/
DROP TABLE IF EXISTS ##tblLaneAAOTemp

/*
Insert into USCTTDEV.dbo.tblLaneAAO with Line Broken AAO's by Join String / Type / Carrier Service

select * from ##tblLaneAAOTemp order by ID ASC
Select Distinct [Carrier Service], [OriginDestination],String, Count(AAO) as Count from ##tblLaneAAOTemp GROUP BY [Carrier Service], [OriginDestination],String
Select * from ##tblLaneAAOTemp WHERE [Carrier Service] = 'ANTT' and String = '5CO80538'
*/
SELECT * INTO ##tblLaneAAOTemp FROM (
select [Carrier Service], [OriginDestination], [String],
  replace(stuff((SELECT distinct '/' + cast(AAO + ' - ' + [AAO Description]  as nvarchar(max))
       FROM USCTTDEV.dbo.tblLaneAAO t2
       where t2.String = t1.String and t2.OriginDestination = t1.OriginDestination and t1.[Carrier Service] = t2.[Carrier Service]
       FOR XML PATH('')),1,1,''), '/', char(13) + char(10)) as AAOString
from USCTTDEV.dbo.tblLaneAAO t1
WHERE t1.Eligible = 'Y'
--WHERE [Carrier Service] = 'ANTT' and String = '5CO80538'
group by [Carrier Service], [OriginDestination], [String]
) AAOTemp

/*
Update USCTTDEV.dbo.tblBidAppRates, and set AAO to Null
*/
UPDATE USCTTDEV.dbo.tblBidAppRates SET AAO = Null

/*
Update AAO on USCTTDEV.dbo.tblBidAppRates where origin matches tblLaneAAO
SELECT LEFT(LANE,CHARINDEX('-',LANE)-1) as lefttrim, RIGHT(LANE,CHARINDEX('-',LANE)-1) as righttrim
*/

UPDATE USCTTDEV.dbo.tblBidAppRates
SET AAO = laao.AAOString
FROM USCTTDEV.dbo.tblBidAppRates bar
INNER JOIN ##tblLaneAAOTemp laao on laao.string = LEFT(bar.LANE,CHARINDEX('-',bar.LANE)-1)
AND laao.[carrier service] = bar.SCAC
AND laao.OriginDestination = 'Origin'
WHERE bar.AAO IS NULL

/*
Update AAO on USCTTDEV.dbo.tblBidAppRates where origin matches tblLaneAAO
SELECT * FROM ##tblLaneAAOTemp WHERE String = '5NC28273'
*/

UPDATE USCTTDEV.dbo.tblBidAppRates
SET AAO = laao.AAOString
FROM USCTTDEV.dbo.tblBidAppRates bar
INNER JOIN ##tblLaneAAOTemp laao on laao.string = RIGHT(LANE,CHARINDEX('-',LANE)-1)
AND laao.[carrier service] = bar.SCAC
AND laao.OriginDestination = 'Destination'
WHERE bar.AAO IS NULL

/*
Update USCTTDEV.dbo.tblBidApplanes where AAO is not null
SELECT * FROM USCTTDEV.dbo.tblBidApplanes where AAO is not null
SELECT * FROM USCTTDEV.dbo.tblLaneAAO1
*/
UPDATE USCTTDEV.dbo.tblBidAppLanes
SET AAO = CASE WHEN bar.aao is null then NULL else 'Y' END
FROM USCTTDEV.dbo.tblBidAppLanes bal
LEFT JOIN USCTTDEV.dbo.tblBidAppRates bar on bal.laneid = bar.LaneID

/*
This next process will build tblLaneAAOLocation, which has AAO's by SHPG_LOC_CD
Drop temp tables to ensure a clean process
*/
DROP TABLE IF EXISTS ##tblLaneAAOLocation

/*
Insert AAO data by SHPG_LOC_CD into ##tblLaneAAOLocation
*/
SELECT DISTINCT
	GETDATE() AS CurrentTime,
    CHRG_CD,
    CHRG_DESC,
    AAO.SRVC_CD,
    'Y' as Eligible,
	CAST(EFCT_DT AS DATE) EFCT_DT,
	CAST(EXPD_DT AS DATE) EXPD_DT,
    TypeDesc,
    JoinString,
	Shpg_Loc_Cd,
	Name /*9257*/,
	cu.Hierarchy,
	cu.HierarchyNum,
	totLaneVol.LoadCount AS TotalLocationVolume,
	LaneCarrVol.LoadCount AS CarrierVolume

INTO ##tblLaneAAOLocation

  FROM (SELECT DISTINCT CHRG_CD, CHRG_DESC, TFF_ID, TFF_CD, TFF_DESC, CARR_CD, SRVC_CD, TFF_STAT_ENU, CHRG_COND_YN, EFCT_DT, EXPD_DT, 
SYSDATE, shpg_loc_cd, NAME, CTRY_CD, CTY_NAME, STA_CD, CITYSTATE, PSTL5, TYPE, CASE WHEN TYPE = 'Load At' THEN 'ORIGIN' ELSE 'DESTINATION' END AS TypeDesc, EXTL_CD1, EXTL_CD2, Code, CityStateJoin,
CASE WHEN TYPE <> 'Load At' and CTRY_CD = 'USA' THEN '5'+Sta_Cd+Pstl5 ELSE Code END AS JoinString

FROM (
SELECT * FROM OPENQUERY(NAJDAPRD,'SELECT DISTINCT
    t3.chrg_cd,
    t3.chrg_desc,
    t2.tff_id,
    t2.tff_cd,
    t2.tff_desc,
    t2.carr_cd,
    t3.srvc_cd,
    t2.tff_stat_enu,
    t3.chrg_cond_yn,
	t2.EFCT_DT,
    t2.expd_dt,
    SYSDATE,
    t4.shpg_loc_cd,
    t5.name,
    t6.ctry_cd,
    t6.cty_name,
    t6.sta_cd,
    t6.cty_name || '', '' || t6.sta_cd As CityState,
    CASE
        WHEN t6.ctry_cd = ''USA'' THEN
            substr(t6.pstl_cd, 1, 5)
        ELSE
            t6.pstl_cd
    END AS pstl5,
    ''Load At'' AS type,
    t7.extl_cd1 as extl_cd1,
    t7.extl_cd2 as extl_cd2
FROM
    najdaadm.carrier_r               t1
    JOIN najdaadm.tariff_r                t2 ON t2.carr_cd = t1.carr_cd
    JOIN najdaadm.tariff_charge_r         t3 ON t3.tff_id = t2.tff_id
    JOIN najdaadm.auto_applied_option_r   t4 ON t4.chrg_cd = t3.chrg_cd
    JOIN najdaadm.load_at_r               t5 ON t5.shpg_loc_cd = t4.shpg_loc_cd
    JOIN najdaadm.address_r               t6 ON t6.addr_id = t5.addr_id
    JOIN najdaadm.master_charges_r        t7 ON t7.chrg_cd = t3.chrg_cd 
WHERE
    ( ( t3.chrg_cond_yn = ''N'' )
      AND ( t2.tff_stat_enu = ''Active'' )
      AND ( t3.srvc_cd NOT IN (
        ''OPEN'',
        ''ZAR'',
        ''ZARL'',
        ''UYSN'',
        ''ASFH'',
        ''BEDF'',
        ''CNWY'',
        ''FXFE'',
        ''FXNL'',
        ''ODFL'',
        ''RETL'',
        ''UPGF'',
        ''VITY''
    ) )
      AND ( t2.expd_dt >= SYSDATE )
      AND ( substr(t3.chrg_cd, 1, 1) >= ''A''
            AND substr(t3.chrg_cd, 1, 1) <= ''W'' )
      AND t3.chrg_cd NOT IN (
        ''USPS'',
        ''SDSD'',
        ''HAZM''
    )
      AND t6.ctry_cd IN (
        ''USA'',
        ''CAN'',
  	''MEX''
    )
      AND t6.sta_cd NOT IN (
        ''00''
    )
      AND ( t1.carr_typ = ''Road'' )
      AND t4.aply_frm_ap_enu = ''Apply When Routing and Rating''
	  AND UPPER(t7.EXTL_CD1) NOT LIKE ''%OBSOLETE%''
	  )
UNION ALL
SELECT DISTINCT
    t3.chrg_cd,
    t3.chrg_desc,
    t2.tff_id,
    t2.tff_cd,
    t2.tff_desc,
    t2.carr_cd,
    t3.srvc_cd,
    t2.tff_stat_enu,
    t3.chrg_cond_yn,
	t2.EFCT_DT,
    t2.expd_dt,
    SYSDATE,
    t4.shpg_loc_cd,
    t5.name,
    t6.ctry_cd,
    t6.cty_name,
    t6.sta_cd,
    t6.cty_name || '', '' || t6.sta_cd As CityState,
    CASE
        WHEN t6.ctry_cd = ''USA'' THEN
            substr(t6.pstl_cd, 1, 5)
        ELSE
            t6.pstl_cd
    END AS pstl5,
    ''Distribution Center'' AS type,
    t7.extl_cd1 as extl_cd1,
    t7.extl_cd2 as extl_cd2
FROM
    najdaadm.carrier_r               t1
    JOIN najdaadm.tariff_r                t2 ON t2.carr_cd = t1.carr_cd
    JOIN najdaadm.tariff_charge_r         t3 ON t3.tff_id = t2.tff_id
    JOIN najdaadm.auto_applied_option_r   t4 ON t4.chrg_cd = t3.chrg_cd
    JOIN najdaadm.distribution_center_r   t5 ON t5.shpg_loc_cd = t4.dc_shpg_loc_cd
    JOIN najdaadm.address_r               t6 ON t6.addr_id = t5.addr_id
    JOIN najdaadm.master_charges_r        t7 ON t7.chrg_cd = t3.chrg_cd 
WHERE
    ( ( t3.chrg_cond_yn = ''N'' )
      AND ( t2.tff_stat_enu = ''Active'' )
      AND ( t3.srvc_cd NOT IN (
        ''OPEN'',
        ''ZAR'',
        ''ZARL'',
        ''UYSN'',
        ''ASFH'',
        ''BEDF'',
        ''CNWY'',
        ''FXFE'',
        ''FXNL'',
        ''ODFL'',
        ''RETL'',
        ''UPGF'',
        ''VITY''
    ) )
      AND ( t2.expd_dt >= SYSDATE )
      AND ( substr(t3.chrg_cd, 1, 1) >= ''A''
            AND substr(t3.chrg_cd, 1, 1) <= ''W'' )
      AND t3.chrg_cd NOT IN (
        ''USPS'',
        ''SDSD'',
        ''HAZM''
    )
      AND t6.ctry_cd IN (
        ''USA'',
        ''CAN'',
		''MEX''
    )
      AND t6.sta_cd NOT IN (
        ''00''
    )
      AND ( t1.carr_typ = ''Road'' )
      AND t4.aply_frm_ap_enu = ''Apply When Routing and Rating''
	  AND UPPER(t7.EXTL_CD1) NOT LIKE ''%OBSOLETE%'')
ORDER BY
    chrg_cd,
    srvc_cd') data

LEFT JOIN (SELECT DISTINCT Code, CityStateJoin FROM (
SELECT DISTINCT ORIG_CITY_STATE as Code, ORIGIN as CityStateJoin
FROM USCTTDEV.dbo.tblBidAppLanes
UNION ALL
SELECT DISTINCT DEST_CITY_STATE as Code, Dest as CityStateJoin
FROM USCTTDEV.dbo.tblBidAppLanes
WHERE DESTCountry <> 'USA') NonUS) NonUs ON NonUs.CityStateJoin = data.CityState) data
) AAO
LEFT JOIN USCTTDEV.dbo.tblCustomers cu
ON cu.HierarchyNum = CASE WHEN LEFT(aao.SHPG_LOC_CD,1) = 'V' THEN SUBSTRING(aao.SHPG_LOC_CD,2,9) ELSE LEFT(aao.SHPG_LOC_CD,8) END

/*
Get total Lane Volume for each SHPG_LOC_CD; for both inbound and outbound
*/
LEFT JOIN (
SELECT DISTINCT CASE WHEN ald.OrderType LIKE '%INBOUND%' THEN ald.FRST_SHPG_LOC_CD ELSE ald.LAST_SHPG_LOC_CD END AS LocationCode,
COUNT(DISTINCT LD_LEG_ID) AS LoadCount
FROM USCTTDEV.dbo.tblActualLoadDetail ald
WHERE CAST(ald.SHPD_DTT AS DATE) >= '9/1/2019'
GROUP BY CASE WHEN ald.OrderType LIKE '%INBOUND%' THEN ald.FRST_SHPG_LOC_CD ELSE ald.LAST_SHPG_LOC_CD END
) totLaneVol ON totLaneVol.LocationCode = AAO.Shpg_Loc_Cd 

/*
Get carrier volume
*/
LEFT JOIN (
SELECT DISTINCT CASE WHEN ald.OrderType LIKE '%INBOUND%' THEN ald.FRST_SHPG_LOC_CD ELSE ald.LAST_SHPG_LOC_CD END AS LocationCode,
SRVC_CD,
COUNT(DISTINCT LD_LEG_ID) AS LoadCount
FROM USCTTDEV.dbo.tblActualLoadDetail ald
WHERE CAST(ald.SHPD_DTT AS DATE) >= '9/1/2019'
/*AND CASE WHEN ald.OrderType LIKE '%INBOUND%' THEN ald.FRST_SHPG_LOC_CD ELSE ald.LAST_SHPG_LOC_CD END = 'V50003206-0152'*/
GROUP BY CASE WHEN ald.OrderType LIKE '%INBOUND%' THEN ald.FRST_SHPG_LOC_CD ELSE ald.LAST_SHPG_LOC_CD END,
SRVC_CD
) LaneCarrVol ON LaneCarrVol.LocationCode = AAO.Shpg_Loc_Cd 
AND LaneCarrVol.SRVC_CD = AAO.SRVC_CD

/*WHERE aao.JoinString = '5CA93257'
OR aao.CHRG_CD LIKE 'W*'*/

/*WHERE aao.SHPG_LOC_CD = 'V50003206-0152'*/

GROUP BY 
	aao.CHRG_CD,
    aao.CHRG_DESC,
    aao.SRVC_CD,
	CAST(aao.EFCT_DT AS DATE),
	CAST(aao.EXPD_DT AS DATE),
    aao.TypeDesc,
    aao.JoinString,
	aao.Shpg_Loc_Cd,
	aao.Name /*9257*/,
	cu.Hierarchy,
	cu.HierarchyNum,
	totLaneVol.LoadCount,
	LaneCarrVol.LoadCount 

ORDER BY AAO.CHRG_CD, AAO.SHPG_LOC_CD, AAO.SRVC_CD

/*
Add new records to table where they don't exist
SELECT * FROM ##tblLaneAAOLocation
SELECT * FROM USCTTDEV.dbo.tblLaneAAOLocation
*/
INSERT INTO USCTTDEV.dbo.tblLaneAAOLocation (AddedOn, LastUpdated, CHRG_CD, CHRG_DESC, SRVC_CD, EFCT_DT, EXPD_DT, Eligible, TypeDesc, JoinString, SHPG_LOC_CD, Name, Hierarchy, HierarchyNum, TotalLocationVolume, CarrierVolume)
SELECT lalt.CurrentTime, lalt.CurrentTime, lalt.CHRG_CD, lalt.CHRG_DESC, lalt.SRVC_CD, lalt.EFCT_DT, lalt.EXPD_DT, lalt.Eligible, lalt.TypeDesc, lalt.JoinString, lalt.SHPG_LOC_CD, lalt.Name, lalt.Hierarchy, lalt.HierarchyNum, lalt.TotalLocationVolume, lalt.CarrierVolume
FROM ##tblLaneAAOLocation lalt 
LEFT JOIN USCTTDEV.dbo.tblLaneAAOLocation lal ON lal.CHRG_CD = lalt.CHRG_CD
AND lal.SRVC_CD = lalt.SRVC_CD
AND lal.SHPG_LOC_CD = lalt.SHPG_LOC_CD
WHERE lal.CHRG_CD IS NULL
AND lal.SRVC_CD IS NULL
AND lal.SHPG_LOC_CD IS NULL
ORDER BY lalt.CHRG_CD ASC, lalt.SRVC_CD ASC, lalt.SHPG_LOC_CD ASC

/*
Update existing records to match
*/
UPDATE USCTTDEV.dbo.tblLaneAAOLocation
SET LastUpdated = lalt.CurrentTime,
CHRG_DESC = lalt.CHRG_DESC,
Eligible = lalt.Eligible,
EFCT_DT = lalt.EFCT_DT,
EXPD_DT = lalt.EXPD_DT,
TypeDesc = lalt.TypeDesc,
JoinString = lalt.JoinString,
Name = lalt.Name,
Hierarchy = lalt.Hierarchy,
HierarchyNum = lalt.HierarchyNum,
TotalLocationVolume = lalt.TotalLocationVolume,
CarrierVolume = lalt.CarrierVolume
FROM USCTTDEV.dbo.tblLaneAAOLocation lal
INNER JOIN ##tblLaneAAOLocation lalt ON lalt.CHRG_CD = lal.CHRG_CD
AND lalt.SRVC_CD = lal.SRVC_CD
AND lalt.SHPG_LOC_CD = lal.SHPG_LOC_CD

/*
Update EXPD_DT and Elgible if no longer in temp table
*/
UPDATE USCTTDEV.dbo.tblLaneAAOLocation
SET LastUpdated = GETDATE(),
Eligible = 'N',
EXPD_DT = CAST(GETDATE() - 1 AS DATE)
FROM USCTTDEV.dbo.tblLaneAAOLocation lal
LEFT JOIN ##tblLaneAAOLocation lalt ON lalt.CHRG_CD = lal.CHRG_CD
AND lalt.SRVC_CD = lal.SRVC_CD
AND lalt.SHPG_LOC_CD = lal.SHPG_LOC_CD
WHERE lalt.CHRG_CD IS NULL
AND lalt.SRVC_CD IS NULL
AND lalt.SHPG_LOC_CD IS NULL
AND lal.EXPD_DT > GETDATE()

/*
Drop temp tables to ensure a clean process
*/
DROP TABLE IF EXISTS ##tblLaneAAOLocation

/*
Update Bid App Lanes RFP table to AAO, where the most loads have been shipped in the past 2 years
*/
UPDATE USCTTDEV.dbo.tblBidAppLanesRFP2021
SET AAO =
         CASE
           WHEN aao.CHRG_CD IS NULL THEN NULL
           ELSE 'Y'
         END
FROM USCTTDEV.dbo.tblBidAppLanesRFP2021 bal
LEFT JOIN (SELECT DISTINCT
  aao.CHRG_CD,
  CASE
    WHEN aao.DestLane IS NULL THEN aao.OrigLane
    ELSE aao.DestLane
  END AS Lane,
  CASE
    WHEN aao.DestLane IS NULL THEN aao.OrigLoadCount
    ELSE aao.DestLoadCount
  END AS LoadCount,
  ROW_NUMBER() OVER (PARTITION BY CASE
    WHEN aao.DestLane IS NULL THEN aao.OrigLane
    ELSE aao.DestLane
  END ORDER BY CASE
    WHEN aao.DestLane IS NULL THEN aao.OrigLoadCount
    ELSE aao.DestLoadCount
  END DESC) AS RowNum
FROM (SELECT DISTINCT
  lal.CHRG_CD,
  lal.SHPG_LOC_CD,
  aldDest.DestLane,
  aldDest.DestLoadCount,
  aldOrig.OrigLane,
  aldOrig.OrigLoadCount
FROM USCTTDEV.dbo.tblLaneAAOLocation lal
LEFT JOIN (SELECT DISTINCT
  ald.LAST_SHPG_LOC_CD,
  ald.Lane AS DestLane,
  COUNT(DISTINCT ald.LD_LEG_ID) AS DestLoadCount
FROM USCTTDEV.dbo.tblActualLoadDetail ald
WHERE YEAR(ald.SHPD_DTT) >= YEAR(GETDATE()) - 1
GROUP BY ald.LAST_SHPG_LOC_CD,
         ald.Lane) aldDest
  ON aldDest.LAST_SHPG_LOC_CD = lal.SHPG_LOC_CD
LEFT JOIN (SELECT DISTINCT
  ald.FRST_SHPG_LOC_CD,
  ald.Lane AS OrigLane,
  COUNT(DISTINCT ald.LD_LEG_ID) AS OrigLoadCount
FROM USCTTDEV.dbo.tblActualLoadDetail ald
WHERE YEAR(ald.SHPD_DTT) >= YEAR(GETDATE()) - 1
GROUP BY ald.FRST_SHPG_LOC_CD,
         ald.Lane) aldOrig
  ON aldOrig.FRST_SHPG_LOC_CD = lal.SHPG_LOC_CD
WHERE CAST(lal.EFCT_DT AS date) < CAST(GETDATE() AS date)
AND CAST(lal.EXPD_DT AS date) >= CAST(GETDATE() AS date)) aao
WHERE CASE
  WHEN aao.DestLane IS NULL THEN aao.OrigLoadCount
  ELSE aao.DestLoadCount
END IS NOT NULL
/*AND CASE WHEN aao.DestLane IS NULL THEN aao.OrigLane ELSE aao.DestLane END = 'ILEFFING-5KY42301'*/
) aao
  ON aao.Lane = bal.Lane
  AND aao.RowNum = 1

/*
Update Bid App Rates RFP table to AAO, where the most loads have been shipped in the past 2 years
*/
UPDATE USCTTDEV.dbo.tblBidAppRatesRFP2021
SET AAO =
         CASE
           WHEN aao.SRVC_CD IS NULL THEN NULL
           ELSE aao.AAODesc
         END
FROM USCTTDEV.dbo.tblBidAppRatesRFP2021 bar
LEFT JOIN (SELECT DISTINCT
  aao.CHRG_CD,
  UPPER(aao.AAODesc) AS AAODesc,
  aao.SRVC_CD,
  CASE
    WHEN aao.DestLane IS NULL THEN aao.OrigLane
    ELSE aao.DestLane
  END AS Lane,
  CASE
    WHEN aao.DestLane IS NULL THEN aao.OrigLoadCount
    ELSE aao.DestLoadCount
  END AS LoadCount,
  ROW_NUMBER() OVER (PARTITION BY CASE
    WHEN aao.DestLane IS NULL THEN aao.OrigLane
    ELSE aao.DestLane
  END, aao.SRVC_CD ORDER BY CASE
    WHEN aao.DestLane IS NULL THEN aao.OrigLoadCount
    ELSE aao.DestLoadCount
  END DESC) AS RowNum
FROM (SELECT DISTINCT
  lal.CHRG_CD,
  lal.CHRG_CD + ' - ' + lal.CHRG_DESC AS AAODesc,
  lal.SRVC_CD,
  lal.SHPG_LOC_CD,
  aldDest.DestLane,
  aldDest.DestLoadCount,
  aldOrig.OrigLane,
  aldOrig.OrigLoadCount
FROM USCTTDEV.dbo.tblLaneAAOLocation lal
LEFT JOIN (SELECT DISTINCT
  ald.LAST_SHPG_LOC_CD,
  ald.Lane AS DestLane,
  COUNT(DISTINCT ald.LD_LEG_ID) AS DestLoadCount
FROM USCTTDEV.dbo.tblActualLoadDetail ald
WHERE YEAR(ald.SHPD_DTT) >= YEAR(GETDATE()) - 1
GROUP BY ald.LAST_SHPG_LOC_CD,
         ald.Lane) aldDest
  ON aldDest.LAST_SHPG_LOC_CD = lal.SHPG_LOC_CD
LEFT JOIN (SELECT DISTINCT
  ald.FRST_SHPG_LOC_CD,
  ald.Lane AS OrigLane,
  COUNT(DISTINCT ald.LD_LEG_ID) AS OrigLoadCount
FROM USCTTDEV.dbo.tblActualLoadDetail ald
WHERE YEAR(ald.SHPD_DTT) >= YEAR(GETDATE()) - 1
GROUP BY ald.FRST_SHPG_LOC_CD,
         ald.Lane) aldOrig
  ON aldOrig.FRST_SHPG_LOC_CD = lal.SHPG_LOC_CD
WHERE CAST(lal.EFCT_DT AS date) < CAST(GETDATE() AS date)
AND CAST(lal.EXPD_DT AS date) >= CAST(GETDATE() AS date)) aao
WHERE CASE
  WHEN aao.DestLane IS NULL THEN aao.OrigLoadCount
  ELSE aao.DestLoadCount
END IS NOT NULL
/*AND CASE WHEN aao.DestLane IS NULL THEN aao.OrigLane ELSE aao.DestLane END = 'ILEFFING-5KY42301'*/) aao
  ON aao.Lane = bar.Lane
  AND aao.SRVC_CD = bar.SCAC
  AND aao.RowNum = 1

END