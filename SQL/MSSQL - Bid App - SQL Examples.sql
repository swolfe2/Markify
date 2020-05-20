/*
Update the EffectiveDate to this year
*/

UPDATE USCTTDEV.dbo.tblBidAppRates
SET EffectiveDate = CAST('2/9/2019' as DATE)
WHERE EffectiveDate = '2/9/2020'

/*
Update preaward to null if not already 'Y'
*/
UPDATE USCTTDEV.dbo.tblBidAppRates
SET PREAWARD = CASE WHEN LEN(PREAWARD) > 0 THEN 'Y' ELSE NULL END

/*
Update Confirmed to 'Y' if pre-award
*/
UPDATE USCTTDEV.dbo.tblBidAppRates
SET CONFIRMED = 'Y' WHERE PREAWARD = 'Y'

/*
Update Comment for if pre-award or Coupa award
*/
UPDATE USCTTDEV.dbo.tblBidAppRates
SET COMMENT = 
CASE WHEN PREAWARD IS NULL AND AWARD_LDS IS NOT NULL THEN 'Coupa Award - PCT: ' + REPLACE(FORMAT((AWARD_PCT),'P0'),' ','') + ' / Loads: ' + CAST(CAST(ROUND(AWARD_LDS, 0) as int) as varchar(40))
WHEN PREAWARD IS NOT NULL AND AWARD_LDS IS NOT NULL THEN 'Pre-Award - PCT: ' + REPLACE(FORMAT((AWARD_PCT),'P0'),' ','') + ' / Loads: ' + CAST(CAST(ROUND(AWARD_LDS, 0) as int) as varchar(40))
WHEN PREAWARD IS NOT NULL AND AWARD_LDS IS NULL THEN 'Pre-Award - NO LOADS!'
ELSE NULL
END

/*
This is how to insert into tblBidAppRates!
INSERT INTO USCTTDEV.dbo.tblBidAppRates (LaneID, Orig_City_State, Dest_City_State, Lane, Equipment, SCAC, Mode, LY_VOL, LY_RPM, Bid_RPM, Award_PCT, Award_LDS, Active_Flag, Comment, Confirmed, Service, Origin, Dest, EffectiveDate, ExpirationDate, Reason, [Rate Per Mile], [Min Charge], CUR_RPM, Rank_Num, ChargeType, PreAward)
SELECT ID, Orig_City_State, Dest_City_State, Lane, Equipment, SCAC, Mode, CASE WHEN LY_VOL = '0' THEN NULL ELSE LY_VOL END AS LY_VOL, CASE WHEN LEN(LY_RPM) > 0 THEN CONVERT(DECIMAL(20,5),LY_RPM) ELSE NULL END AS LY_RPM, Bid_RPM, CASE WHEN AWARD_PCT = '0' THEN NULL ELSE Award_PCT END AS Award_PCT, CASE WHEN Award_LDS = '0' THEN Null ELSE Award_LDS END AS Award_LDS, Active_Flag, Comment, Confirmed, CASE WHEN Service = 0 then Null else Service END AS Service, Origin, Dest, EffectiveDate, ExpirationDate, Reason, CASE WHEN LEN([Rate Per Mile]) > 0 THEN CONVERT(DECIMAL (12,4),[Rate Per Mile]) ELSE NULL END AS [Rate Per Mile], [Min Charge], CUR_RPM, Rank_Num, ChargeType, PreAward
FROM USCTTDEV.dbo.tblBidAppRatesTemp$
ORDER BY ID, RANK_NUM ASC
*/

/*
Set the [Rate Per Mile] value when there's a min charge
*/
UPDATE USCTTDEV.dbo.tblBidAppRates
SET [rate per mile] = Round([min charge] / bal.MILES,2)
from USCTTDEV.dbo.tblBidAppRates bar
INNER JOIN USCTTDEV.dbo.tblBidAppLanes bal on bar.laneid = bal.laneid
WHERE [Min Charge] IS NOT NULL

/*
Set the [Rate Per Mile] for Intermodal
*/
UPDATE USCTTDEV.dbo.tblBidAppRates
SET [Rate Per Mile] = CASE WHEN [MIN CHARGE] IS NULL THEN CUR_RPM - .15 ELSE Round([min charge] / bal.MILES,2) - .15 END
from USCTTDEV.dbo.tblBidAppRates bar
INNER JOIN USCTTDEV.dbo.tblBidAppLanes bal on bar.laneid = bal.laneid
WHERE mode = 'IM'

/*
Append one MSSQL table to another
*/
INSERT INTO USCTTDEV.dbo.tblBidAppRates1 (LaneID, ORIG_CITY_STATE, Lane, Equipment, SCAC, Mode, LY_VOL, LY_RPM, BID_RPM, AWARD_PCT, AWARD_LDS, ACTIVE_FLAG, COMMENT, Confirmed, Service, Origin, Dest, EffectiveDate, ExpirationDate, Reason, [Rate Per Mile], [Min Charge], CUR_RPM, Rank_Num, ChargeType, PreAward, AAO)
SELECT LaneID, ORIG_CITY_STATE, Lane, Equipment, SCAC, Mode, LY_VOL, LY_RPM, BID_RPM, AWARD_PCT, AWARD_LDS, ACTIVE_FLAG, COMMENT, Confirmed, Service, Origin, Dest, EffectiveDate, ExpirationDate, Reason, [Rate Per Mile], [Min Charge], CUR_RPM, Rank_Num, ChargeType, PreAward, AAO
FROM USCTTDEV.dbo.tblBidAppRates
ORDER BY LaneID, RANK_NUM ASC

/*
Update USCTTDEV.dbo.tblCarriers where the Name / SRVC_DESC is null
*/
UPDATE USCTTDEV.dbo.tblCarriers
SET NAME = carr.Name
FROM USCTTDEV.dbo.tblCarriers ca
INNER JOIN (SELECT DISTINCT CARR_CD, NAME FROM USCTTDEV.dbo.tblCarriers WHERE NAME IS NOT NULL) carr ON carr.CARR_CD = ca.carr_cd
WHERE ca.NAME IS NULL

/*
Update Name / SRVC DESC / Shipmode where Coupa Description is not null
*/
UPDATE USCTTDEV.dbo.tblCarriers
Set Name = CASE WHEN NAME IS NULL THEN SUBSTRING(CoupaDescription, COALESCE(NULLIF(CHARINDEX('-',CoupaDescription)+2,1),1),8000) ELSE NAME END,
SRVC_DESC = CoupaDescription, SHIPMODE = 'TRUCK'
FROM USCTTDEV.dbo.tblCarriers
WHERE SRVC_DESC IS NULL


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
