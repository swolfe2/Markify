USE [USCTTDEV]
GO
/****** Object:  StoredProcedure [dbo].[sp_AAO]    Script Date: 1/17/2020 11:46:39 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Steve Wolfe, steve.wolfe@kcc.com, Central Transportation Team
-- Create date: 10/25/2019
-- Last modified: 11/5/2019 - Complete overhaul. Moved to loading table directly from Oracle, and then updating Rates table with Carriage Return strings 
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
*/
DELETE FROM USCTTDEV.dbo.tblLaneAAO

/*
Insert Oracle AAO's into USCTTDEV.dbo.tblLaneAAO
*/
INSERT INTO USCTTDEV.dbo.tblLaneAAO (AAO, [AAO Description], [Carrier Service], Eligible, OriginDestination, String)
  SELECT DISTINCT
    CHRG_CD,
    CHRG_DESC,
    SRVC_CD,
    'Y' as Eligible,
    TypeDesc,
    JoinString
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
      AND t4.aply_frm_ap_enu = ''Apply When Routing and Rating'' )
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
      AND t4.aply_frm_ap_enu = ''Apply When Routing and Rating'' )
ORDER BY
    chrg_cd,
    srvc_cd') data

LEFT JOIN (SELECT DISTINCT Code, CityStateJoin FROM (
SELECT DISTINCT ORIG_CITY_STATE as Code, ORIGIN as CityStateJoin
FROM USCTTDEV.dbo.tblBidAppLanes
UNION ALL
SELECT DISTINCT DEST_CITY_STATE as Code, Dest as CityStateJoin
FROM USCTTDEV.dbo.tblBidAppLanes
WHERE DESTCountry <> 'USA') NonUS) NonUs ON NonUs.CityStateJoin = data.CityState) data) AAO

/*
Add missing AAOs to dbo_tblLaneAAO
*/
INSERT INTO USCTTDEV.dbo.tblLaneAAO (AAO, [AAO Description], [Carrier Service], Eligible, OriginDestination, String)
VALUES 
('2325','KCDC ADR ASSEMBLING CONTRACTORS','SCNN','Y','DESTINATION','AGSANFRA'),
('2325','KCDC ADR ASSEMBLING CONTRACTORS','SWFT','Y','DESTINATION','AGSANFRA'),
('2325','KCDC ADR ASSEMBLING CONTRACTORS','WENP','Y','DESTINATION','AGSANFRA')
;

/*
Update JBHunt SCACs since they didn't submit bids, but will on new SCAC
DELETE FROM USCTTDEV.dbo.tblLaneAAO WHERE [Carrier Service] = 'HMKD'
*/
INSERT INTO USCTTDEV.dbo.tblLaneAAO (AAO, [AAO Description], [Carrier Service], Eligible, OriginDestination, String)
SELECT AAO, [AAO Description], 'HMKD', Eligible, OriginDestination, String
FROM(
SELECT DISTINCT AAO, [AAO Description], Eligible, OriginDestination, String
FROM USCTTDEV.dbo.tblLaneAAO
WHERE [Carrier Service] = 'HJBT' OR [Carrier Service] = 'HJBT'
) Data
ORDER BY AAO Asc

/*
Drop all temp tables, and ensure a clean process
*/
DROP 
  TABLE IF EXISTS ##tblLaneAAOTemp

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
*/
UPDATE USCTTDEV.dbo.tblBidAppLanes
SET AAO = CASE WHEN bar.aao is null then NULL else 'Y' END
FROM USCTTDEV.dbo.tblBidAppLanes bal
LEFT JOIN USCTTDEV.dbo.tblBidAppRates bar on bal.laneid = bar.LaneID

END