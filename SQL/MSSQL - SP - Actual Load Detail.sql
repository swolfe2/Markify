USE [USCTTDEV]
GO
/****** Object:  StoredProcedure [dbo].[sp_ActualLoadDetail]    Script Date: 1/24/2020 11:48:05 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
-- =============================================
-- Author:		<Steve Wolfe, steve.wolfe@kcc.com, Central Transportation Team>
-- Create date: <9/30/2019>
-- Last modified: <1/24/2020>
-- Description:	<Executes query against Oracle, loads to temp table, then appends/updates dbo.tblCarriers>
-- 1/24/2020 - SW - Added l.last_shpg_loc_cd NOT LIKE ''LCL%'' to keep LCL shipments from being appended
-- 1/21/2020 - SW - Added update query to change the ShipMode to 'TRUCK' when the eqmt_typ is '53IM', but is less than 600 miles
Logic to handle KC-Romeoville based on origin zone logic
-- 1/16/2020 - SW - Update new broker flag. Also, on sp_CancelledLoads, will be deleting from USCTTDEV.dbo.tblActualLoadDetail where the CUR_OPTLSTAT_ID > 350
Updated entire stored procedure to segregate ZUSB charges into their own headers for both pre-rate, accessorials
Updated to include LTL volume, along with Unique SHIPMODE descriptionLike
Update tblBidAppLanes with current year's volume
-- 1/14/2020 - SW - Update new column, DestCity, with unique dest city value from dbo_tblZoneCities
-- 1/2/2020 - SW - Make sure query pulls in last calendar year's data, along with this year's
-- 12/2/2019 - SW - Added query to update BU if 'UNKNOWN', but has some other kind of Business Unit Cost
-- 10/31/2019 - SW - Added queries to update Name / SRVC_DESC based on Coupa Description, and if CARR_CD already exists
-- =============================================
*/
ALTER PROCEDURE [dbo].[sp_ActualLoadDetail]

AS
BEGIN
/*
This SQL file replicates the Freight Expenditures file currently running on USTCA097
AUTHOR: Steve Wolfe
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

	DELETE FROM USCTTDEV.dbo.tblActualLoadDetail
*/

/*
Declare Variables
*/
DECLARE @cols AS NVARCHAR(MAX),
@query AS NVARCHAR(MAX),
@fuelDifferential AS DECIMAL(5,5)

/*
Set fuel differential for use later in file
*/
SET @fuelDifferential = .032

/*
Drop all temp tables, and ensure a clean process
*/
DROP TABLE IF EXISTS
##tblActualBusinessUnits,
##tblActualLoadDetailsALD,
##tblActualLoadDetailsPRLD,
##tblActualLoadDetailsRaw,
##tblActualRateLoadDetailsPivot,
##tblActualRateLoadDetailsRaw,
##tblAwards,
##tblLaneOrigDest,
##tblBUWeightRaw,
##tblBUWeightPivot,
##tblCurrentAwards,
##tblLaneAwards,
##tblPreRateLoadDetailsPivot,
##tblPreRateLoadDetailsRaw,
##tblTMSMasterZones

/*
Create temp table for Actual Load Details
*/
DROP TABLE IF EXISTS ##tblActualLoadDetailsRaw

/*
Set query
*/
SET @query = '
SELECT
    z.*,
    shp_con.ship_condition
FROM
    (
        SELECT
            load_charge.*,
            CASE
                WHEN substr(frst_shpg_loc_cd, 1, 4) IN (
                    ''2358'',
                    ''2292''
                ) THEN
                    ''KCILROME-NOF''
                WHEN substr(frst_shpg_loc_cd, 1, 4) = ''2323'' THEN
                    ''KCILROME-KCP''
                WHEN substr(frst_shpg_loc_cd, 1, 4) = ''2474'' THEN
                    ''KCILROME-SKIN''
                ELSE
                    zone.zn_cd
            END origin_zone
        FROM
            (
                SELECT
                    l.carr_cd,
                    c.name,
                    l.srvc_cd,
                    mst.srvc_desc,
                    l.cur_optlstat_id,
                    s.stat_shrt_desc   AS status,
                    l.shpd_dtt,
                    CASE
                        WHEN l.strd_dtt IS NULL THEN
                            l.shpd_dtt
                        ELSE
                            l.strd_dtt
                    END strd_dtt,
                    l.ld_leg_id,
                    l.frst_shpg_loc_cd,
                    l.frst_shpg_loc_name,
                    l.frst_cty_name,
                    l.frst_sta_cd,
                    l.frst_pstl_cd,
                    l.frst_ctry_cd,
                    l.last_shpg_loc_cd,
                    l.last_shpg_loc_name,
                    l.last_cty_name,
                    l.last_sta_cd,
                    l.last_pstl_cd,
                    l.last_ctry_cd,
                    l.eqmt_typ,
                    l.ldd_dist         AS fixd_itnr_dist,
                    l.tot_tot_pce,
                    l.tot_scld_wgt,
                    l.tot_vol,
                    l.actl_chgd_amt_dlr,
                    la.corp1_id,
                    CASE
                        WHEN l.srvc_cd = ''HJBM''
                             AND substr(l.rate_cd, 1, 1) = ''C'' THEN
                            ''Y''
                        ELSE
                            ''N''
                    END AS marketplace_catchall,
                    CASE
                        WHEN COUNT(DISTINCT s.to_shpg_loc_cd) - 1 < 1 THEN
                            1
                        ELSE
                            COUNT(DISTINCT s.to_shpg_loc_cd)
                    END AS stops
                FROM
                    najdaadm.load_leg_r          l
                    INNER JOIN najdaadm.load_at_r           la ON l.frst_shpg_loc_cd = la.shpg_loc_cd
                    INNER JOIN najdaadm.status_r            s ON l.cur_optlstat_id = s.stat_id
                    INNER JOIN najdaadm.address_r           ad ON l.frst_addr_id = ad.addr_id
                    INNER JOIN najdaadm.address_r           ad1 ON l.last_addr_id = ad1.addr_id
                    INNER JOIN najdaadm.carrier_r           c ON l.carr_cd = c.carr_cd
                    INNER JOIN najdaadm.load_leg_detail_r   ld ON l.ld_leg_id = ld.ld_leg_id
                    INNER JOIN najdaadm.shipment_r          s ON ld.shpm_num = s.shpm_num
                    LEFT JOIN najdaadm.mstr_srvc_t         mst ON l.srvc_cd = mst.srvc_cd
                WHERE
                    EXTRACT(YEAR FROM
                        CASE
                            WHEN l.shpd_dtt IS NULL THEN
                                l.strd_dtt
                            ELSE
                                l.shpd_dtt
                        END
                    ) >= EXTRACT(YEAR FROM SYSDATE)-1
                    AND l.cur_optlstat_id IN (
                        300,
                        305,
                        310,
                        320,
                        325,
                        335,
                        345
                    )
                    AND l.eqmt_typ IN (
                        ''48FT'',
                        ''48TC'',
                        ''53FT'',
                        ''53TC'',
                        ''53IM'',
                        ''53RT'',
                        ''53HC'',
						''LTL''
                    )
                    AND l.last_ctry_cd IN (
                        ''USA'',
                        ''CAN'',
                        ''MEX''
                    )
					AND l.last_shpg_loc_cd NOT LIKE ''LCL%''
                GROUP BY
                    l.carr_cd,
                    c.name,
                    l.srvc_cd,
                    mst.srvc_desc,
                    l.cur_optlstat_id,
                    s.stat_shrt_desc,
                    l.shpd_dtt,
                    CASE
                            WHEN l.strd_dtt IS NULL THEN
                                l.shpd_dtt
                            ELSE
                                l.strd_dtt
                        END,
                    l.ld_leg_id,
                    l.frst_shpg_loc_cd,
                    l.frst_shpg_loc_name,
                    l.frst_cty_name,
                    l.frst_sta_cd,
                    l.frst_pstl_cd,
                    l.frst_ctry_cd,
                    l.last_shpg_loc_cd,
                    l.last_shpg_loc_name,
                    l.last_cty_name,
                    l.last_sta_cd,
                    l.last_pstl_cd,
                    l.last_ctry_cd,
                    l.eqmt_typ,
                    l.ldd_dist,
                    l.tot_tot_pce,
                    l.tot_scld_wgt,
                    l.tot_vol,
                    l.actl_chgd_amt_dlr,
                    la.corp1_id,
                    CASE
                            WHEN l.srvc_cd = ''HJBM''
                                 AND substr(l.rate_cd, 1, 1) = ''C'' THEN
                                ''Y''
                            ELSE
                                ''N''
                        END
            ) load_charge
            LEFT JOIN (
                SELECT
                    *
                FROM
                    najdaadm.zone_r
                WHERE
                    zn_cd NOT IN (
                        ''LARSV'',
                        ''CACITYIN''
                    )
                    AND substr(zn_cd, 1, 2) != ''C-''
            ) zone ON frst_cty_name
                      || '', ''
                      || frst_sta_cd = zn_desc
    ) z
    LEFT JOIN (
        SELECT DISTINCT
            ld_leg_id,
            CASE
                WHEN SUM(tl) > 0 THEN
                    ''TL''
                ELSE
                    CASE
                        WHEN SUM(open) > 0 THEN
                            ''OP''
                        ELSE
                            ''IM''
                    END
            END ship_condition
        FROM
            (
                SELECT
                    ld.ld_leg_id,
                    CASE
                        WHEN s.rfrc_num1 IN (
                            ''Intermodal'',
                            ''IM'',
                            ''TF''
                        ) THEN
                            1
                        ELSE
                            0
                    END AS im,
                    CASE
                        WHEN s.rfrc_num1 IN (
                            ''Truck'',
                            ''TL''
                        ) THEN
                            1
                        ELSE
                            0
                    END AS tl,
                    CASE
                        WHEN s.rfrc_num1 LIKE ( ''Open%'' )
                             OR s.rfrc_num1 = ''OP'' THEN
                            1
                        ELSE
                            0
                    END AS open
                FROM
                    najdaadm.load_leg_r          l
                    INNER JOIN najdaadm.load_leg_detail_r   ld ON ld.ld_leg_id = l.ld_leg_id
                    INNER JOIN najdaadm.shipment_r          s ON s.shpm_num = ld.shpm_num
                WHERE
                     EXTRACT(YEAR FROM
                        CASE
                            WHEN l.shpd_dtt IS NULL THEN
                                l.strd_dtt
                            ELSE
                                l.shpd_dtt
                        END
                    ) >= EXTRACT(YEAR FROM SYSDATE)-1
                    AND l.cur_optlstat_id IN (
                        300,
                        305,
                        310,
                        320,
                        325,
                        335,
                        345
                    )
                    AND l.eqmt_typ IN (
                        ''48FT'',
                        ''48TC'',
                        ''53FT'',
                        ''53TC'',
                        ''53IM'',
                        ''53RT'',
                        ''53HC'',
						''LTL''
                    )
                    AND l.last_ctry_cd IN (
                        ''USA'',
                        ''CAN'',
                        ''MEX''
                    )
            ) shp_con
        GROUP BY
            ld_leg_id
    ) shp_con ON z.ld_leg_id = shp_con.ld_leg_id'

/*
Create Temp table
*/
CREATE TABLE ##tblActualLoadDetailsRaw
  ( 
CARR_CD                       NVARCHAR(100),
NAME                          NVARCHAR(100),
SRVC_CD                       NVARCHAR(100), 
SRVC_DESC                     NVARCHAR(100),
CUR_OPTLSTAT_ID               NVARCHAR(100), 
STATUS                        NVARCHAR(100), 
SHPD_DTT                      DATETIME,
STRD_DTT                      DATETIME,  
LD_LEG_ID                     NVARCHAR(100),
FRST_SHPG_LOC_CD              NVARCHAR(100),
FRST_SHPG_LOC_NAME            NVARCHAR(100),
FRST_CTY_NAME                 NVARCHAR(100),
FRST_STA_CD                   NVARCHAR(100),
FRST_PSTL_CD                  NVARCHAR(100),
FRST_CTRY_CD                  NVARCHAR(100),
LAST_SHPG_LOC_CD              NVARCHAR(100),
LAST_SHPG_LOC_NAME            NVARCHAR(100),
LAST_CTY_NAME                 NVARCHAR(100),
LAST_STA_CD                   NVARCHAR(100),
LAST_PSTL_CD                  NVARCHAR(100),
LAST_CTRY_CD                  NVARCHAR(100),
EQMT_TYP                      NVARCHAR(100),
FIXD_ITNR_DIST                NUMERIC(18, 2),
TOT_TOT_PCE                   NUMERIC(18, 2),
TOT_SCLD_WGT                  NUMERIC(18, 2),
TOT_VOL                       NUMERIC(18, 2),
ACTL_CHGD_AMT_DLR             NUMERIC(18, 2),
CORP1_ID                      NVARCHAR(100),
MARKETPLACE_CATCHALL          NVARCHAR(100),
STOPS                         NUMERIC(18, 2),
ORIGIN_ZONE                   NVARCHAR(100),
SHIP_CONDITION                NVARCHAR(100)
)

/*
Append records from giant Oracle query into MSSQL temp table
*/
INSERT INTO ##tblActualLoadDetailsRaw
EXEC (@query) AT NAJDAPRD

/*
Create temp table for Pre-rate Load Details, will pivot in next query
*/
DROP TABLE IF EXISTS ##tblPreRateLoadDetailsRaw
Select * into ##tblPreRateLoadDetailsRaw from OPENQUERY(NAJDAPRD, 'SELECT
    l.ld_leg_id,
    CASE
        WHEN l.srvc_cd IN (
            ''HJBM'',
            ''OPEN'',
            ''NFIL'',
            ''WEDV'',
            ''WEND''
        )
             AND c.chrg_cd IN (
            ''ADLH'',
            ''CATX'',
            ''CONT'',
            ''CUBE'',
            ''CWF1'',
            ''CWF2'',
            ''CWF3'',
            ''CWF4'',
            ''CWT'',
            ''CWTF'',
            ''CWTM'',
            ''DISC'',
            ''DIST'',
            ''DT2'',
            ''FBED'',
            ''FLAT'',
            ''GRI'',
            ''ISPT'',
            ''LMIN'',
            ''LTLD'',
            ''MILE'',
            ''OCFR'',
            ''OCN1'',
            ''PKG1'',
            ''SPOT'',
            ''TC'',
            ''TCM'',
            ''UPD'',
            ''WGT'',
            ''ZNFD'',
            ''ZWND'',
            ''ZJBH'',
            ''ZSPT''
        ) THEN
            ''PreRate_Linehaul''
        WHEN l.srvc_cd NOT IN (
            ''HJBM'',
            ''OPEN'',
            ''NFIL'',
            ''WEDV'',
            ''WEND''
        )
             AND c.chrg_cd IN (
            ''ADLH'',
            ''CATX'',
            ''CONT'',
            ''CUBE'',
            ''CWF1'',
            ''CWF2'',
            ''CWF3'',
            ''CWF4'',
            ''CWT'',
            ''CWTF'',
            ''CWTM'',
            ''DISC'',
            ''DIST'',
            ''DT2'',
            ''FBED'',
            ''FLAT'',
            ''GRI'',
            ''ISPT'',
            ''LMIN'',
            ''LTLD'',
            ''MILE'',
            ''OCFR'',
            ''OCN1'',
            ''PKG1'',
            ''SPOT'',
            ''TC'',
            ''TCM'',
            ''UPD'',
            ''WGT'',
            ''ZNFD'',
            ''ZWND'',
            ''ZJBH'',
            ''ZSPT''
        ) THEN
            ''PreRate_Linehaul''
        WHEN c.chrg_cd IN (
            ''BAF'',
            ''DFSC'',
            ''FS01'',
            ''FS02'',
            ''FS03'',
            ''FS04'',
            ''FS05'',
            ''FS06'',
            ''FS07'',
            ''FS08'',
            ''FS09'',
            ''FS10'',
            ''FS11'',
            ''FS12'',
            ''FS13'',
            ''FS14'',
            ''FS15'',
            ''FSCA'',
            ''PFSC'',
            ''RFSC'',
            ''WCFS''
        ) THEN
            ''PreRate_Fuel''
        WHEN c.chrg_cd IN (
            ''ZREP'',
            ''ZDHM''
        ) THEN
            ''PreRate_Repo''
		WHEN c.chrg_cd IN (
            ''ZUSB''
        ) THEN
            ''PreRate_ZUSB''
        ELSE
            ''PreRate_Accessorials''
    END AS chargetype,
    c.chrg_amt_dlr    AS chargeamount,
    c.pymnt_amt_dlr   AS paymentamount
FROM
    najdaadm.charge_detail_r   c
	JOIN najdaadm.load_leg_r   l ON l.ld_leg_id = c.ld_leg_id
WHERE
  EXTRACT(YEAR FROM
        CASE
            WHEN l.shpd_dtt IS NULL THEN
                l.strd_dtt
            ELSE
                l.shpd_dtt
        END
    ) >= EXTRACT(YEAR FROM SYSDATE)-1
    AND l.cur_optlstat_id IN (
        300,
        305,
        310,
        320,
        325,
        335,
        345
    )
    AND l.eqmt_typ IN (
        ''48FT'',
        ''48TC'',
        ''53FT'',
        ''53TC'',
        ''53IM'',
        ''53RT'',
        ''53HC'',
		''LTL''
    )
    AND l.srvc_cd NOT IN (
        ''OPAF'',
        ''OPEC'',
        ''OPEX'',
        ''OPKG''
    )
    AND l.frst_ctry_cd IN (
        ''USA'',
        ''CAN'',
        ''MEX''
    )
    AND l.last_ctry_cd IN (
        ''USA'',
        ''CAN'',
        ''MEX''
    )
    AND c.chrg_cd IS NOT NULL
    AND c.chrg_amt_dlr <> 0
	AND l.last_shpg_loc_cd NOT LIKE ''LCL%''')

/*
Create temp table for Dynamically Pivoted Pre-rate Load Details
*/
DROP TABLE IF EXISTS ##tblPreRateLoadDetailsPivot

SET @cols = STUFF((
			SELECT DISTINCT ',' + QUOTENAME(c.CHARGETYPE)
			FROM ##tblprerateloaddetailsraw c
			FOR XML PATH(''),
				TYPE
			).value('.', 'NVARCHAR(MAX)'), 1, 1, '')

SET @query = 'SELECT LD_LEG_ID as prldLD_LEG_ID, ' + @cols + ' from 
            (
                select prdr.LD_LEG_ID
                    , prdr.CHARGEAMOUNT
                    , prdr.CHARGETYPE
                from ##tblprerateloaddetailsraw	prdr	
           ) x
            pivot 
            (
                 max(CHARGEAMOUNT)
                for CHARGETYPE in (' + @cols + ')
            ) p '
SET @query = 'select * into ##tblPreRateLoadDetailsPivot from (' + @query + ') y'

EXECUTE (@query)

/*
Add any missing columns to pivot table
SELECT * FROM ##tblPreRateLoadDetailsPivot
*/
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'PreRate_Repo' AND TABLE_NAME LIKE '##tblPreRateLoadDetailsPivot') ALTER TABLE ##tblPreRateLoadDetailsPivot ADD [PreRate_Repo] NUMERIC(18,2) NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'PreRate_ZUSB' AND TABLE_NAME LIKE '##tblPreRateLoadDetailsPivot') ALTER TABLE ##tblPreRateLoadDetailsPivot ADD [PreRate_ZUSB] NUMERIC(18,2) NULL

/*
Create temp table for Dynamically Pivoted Pre-rate Load Details
*/
DROP TABLE IF EXISTS ##tblActualLoadDetailsPRLD

/*
Create temp table with left-joined data
*/
Select * into ##tblActualLoadDetailsPRLD from 
##tblActualLoadDetailsRaw ald
LEFT JOIN ##tblPreRateLoadDetailsPivot prld on prld.prldld_leg_id = ald.ld_leg_id

/*
Add Pre-Rate Charge Exists Column
*/
ALTER TABLE ##tblActualLoadDetailsPRLD ADD PreRateCharge NVARCHAR(3)

/*
Update Pre-Rate Charge Exists String

select * from ##tblActualLoadDetailsPRLD
select * from ##tblActualLoadDetailsALD
*/
UPDATE ##tblActualLoadDetailsPRLD
SET PreRateCharge = case WHEN prldLD_LEG_ID is null then 'No' else 'Yes' end

/*
Remove Pre-Rate LD_LEG_ID column from dataset

ALTER TABLE ##tblActualLoadDetailsPRLD DROP COLUMN prldLD_LEG_ID
*/

/*
Create temp table for full Actual Rate Load Details

Select * FROM ##tblActualRateLoadDetailsRaw 
*/
DROP TABLE IF EXISTS ##tblActualRateLoadDetailsRaw

Select * into ##tblActualRateLoadDetailsRaw from OPENQUERY(NAJDAPRD,'SELECT
    l.ld_leg_id,
    CASE
        WHEN l.srvc_cd IN (
            ''HJBM'',
            ''OPEN'',
            ''NFIL'',
            ''WEDV'',
            ''WEND''
        )
             AND c.chrg_cd IN (
            ''ADLH'',
            ''CATX'',
            ''CONT'',
            ''CUBE'',
            ''CWF1'',
            ''CWF2'',
            ''CWF3'',
            ''CWF4'',
            ''CWT'',
            ''CWTF'',
            ''CWTM'',
            ''DISC'',
            ''DIST'',
            ''DT2'',
            ''FBED'',
            ''FLAT'',
            ''GRI'',
            ''ISPT'',
            ''LMIN'',
            ''LTLD'',
            ''MILE'',
            ''OCFR'',
            ''OCN1'',
            ''PKG1'',
            ''SPOT'',
            ''TC'',
            ''TCM'',
            ''UPD'',
            ''WGT'',
            ''ZNFD'',
            ''ZWND'',
            ''ZJBH'',
            ''ZSPT''
        ) THEN
            ''Act_Linehaul''
        WHEN l.srvc_cd NOT IN (
            ''HJBM'',
            ''OPEN'',
            ''NFIL'',
            ''WEDV'',
            ''WEND''
        )
             AND c.chrg_cd IN (
            ''ADLH'',
            ''CATX'',
            ''CONT'',
            ''CUBE'',
            ''CWF1'',
            ''CWF2'',
            ''CWF3'',
            ''CWF4'',
            ''CWT'',
            ''CWTF'',
            ''CWTM'',
            ''DISC'',
            ''DIST'',
            ''DT2'',
            ''FBED'',
            ''FLAT'',
            ''GRI'',
            ''ISPT'',
            ''LMIN'',
            ''LTLD'',
            ''MILE'',
            ''OCFR'',
            ''OCN1'',
            ''PKG1'',
            ''SPOT'',
            ''TC'',
            ''TCM'',
            ''UPD'',
            ''WGT'',
            ''ZNFD'',
            ''ZWND'',
            ''ZJBH'',
            ''ZSPT''
        ) THEN
            ''Act_Linehaul''
        WHEN c.chrg_cd IN (
            ''BAF'',
            ''DFSC'',
            ''FS01'',
            ''FS02'',
            ''FS03'',
            ''FS04'',
            ''FS05'',
            ''FS06'',
            ''FS07'',
            ''FS08'',
            ''FS09'',
            ''FS10'',
            ''FS11'',
            ''FS12'',
            ''FS13'',
            ''FS14'',
            ''FS15'',
            ''FSCA'',
            ''PFSC'',
            ''RFSC'',
            ''WCFS''
        ) THEN
            ''Act_Fuel''
        WHEN c.chrg_cd IN (
            ''ZREP'',
            ''ZDHM''
        ) THEN
            ''Act_Repo''
		WHEN c.chrg_cd IN (
            ''ZUSB''
        ) THEN
            ''Act_ZUSB''
        ELSE
            ''Act_Accessorials''
    END AS chargetype,
    c.chrg_amt_dlr    AS chargeamount,
    c.pymnt_amt_dlr   AS paymentamount
FROM
    NAJDAADM.charge_detail_r   c,
    NAJDAADM.freight_bill_r    f,
    NAJDAADM.load_leg_r        l,
    NAJDAADM.voucher_ap_r      v
WHERE
    f.frht_bill_num = v.frht_bill_num
    AND f.frht_invc_id = v.frht_invc_id
    AND v.vchr_num = c.vchr_num_ap
    AND v.ld_leg_id = l.ld_leg_id
    AND l.cur_optlstat_id > 320
    AND EXTRACT(YEAR FROM
        CASE
            WHEN l.shpd_dtt IS NULL THEN
                l.strd_dtt
            ELSE
                l.shpd_dtt
        END
    ) >= EXTRACT(YEAR FROM SYSDATE)-1
    AND l.eqmt_typ IN (
        ''48FT'',
        ''48TC'',
        ''53FT'',
        ''53TC'',
        ''53IM'',
        ''53RT'',
        ''53HC'',
		''LTL''
    )
    AND f.cur_stat_id IN (
        910,
        915,
        925,
        930
    )
    AND c.chrg_cd IS NOT NULL
	AND l.last_shpg_loc_cd NOT LIKE ''LCL%''')

/*
Create temp table for Dynamically Pivoted Actual Rate Load Details
*/
DROP TABLE IF EXISTS ##tblActualRateLoadDetailsPivot

SET @cols = STUFF((
			SELECT DISTINCT ',' + QUOTENAME(c.CHARGETYPE)
			FROM ##tblActualRateLoadDetailsRaw c
			FOR XML PATH(''),
				TYPE
			).value('.', 'NVARCHAR(MAX)'), 1, 1, '')

SET @query = 'SELECT LD_LEG_ID as arldLD_LEG_ID, ' + @cols + ' from 
            (
                select prdr.LD_LEG_ID
                    , prdr.PAYMENTAMOUNT
                    , prdr.CHARGETYPE
                from ##tblActualRateLoadDetailsraw	prdr	
           ) x
            pivot 
            (
                 SUM(PAYMENTAMOUNT)
                for CHARGETYPE in (' + @cols + ')
            ) p '
SET @query = 'select * into ##tblActualRateLoadDetailsPivot from (' + @query + ') y'

EXECUTE (@query)

/*
Add any missing columns to pivot table
SELECT * FROM ##tblActualRateLoadDetailsPivot
*/
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'Act_Repo' AND TABLE_NAME LIKE '##tblActualRateLoadDetailsPivot') ALTER TABLE ##tblPreRateLoadDetailsPivot ADD [Act_Repo] NUMERIC(18,2) NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'Act_ZUSB' AND TABLE_NAME LIKE '##tblActualRateLoadDetailsPivot') ALTER TABLE ##tblPreRateLoadDetailsPivot ADD [Act_ZUSB] NUMERIC(18,2) NULL

/*
Create temp table for Dynamically Pivoted Pre-rate Load Details
*/
DROP TABLE IF EXISTS ##tblActualLoadDetailsALD

/*
Create temp table with left-joined data
*/
Select * into ##tblActualLoadDetailsALD from 
##tblActualLoadDetailsPRLD ald
LEFT JOIN ##tblActualRateLoadDetailsPivot arld on arld.arldld_leg_id = ald.ld_leg_id

/*
Add Pre-Rate Charge Exists Column
*/
ALTER TABLE ##tblActualLoadDetailsALD ADD ActualRateCharge NVARCHAR(3)

/*
Update Pre-Rate Charge Exists String
*/
UPDATE ##tblActualLoadDetailsALD
SET ActualRateCharge = case WHEN arldLD_LEG_ID is null then 'No' else 'Yes' end

/*
Remove Pre-Rate LD_LEG_ID column from dataset

ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN arldLD_LEG_ID
*/

/*
Drop column from ##tblActualLoadDetailsALD if it exists
If it doesn't exist, then add it to the table
*/
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS Drop_It
ALTER TABLE ##tblActualLoadDetailsALD ADD Drop_It NVARCHAR(3)


/*
Update Actuals Charges to PreRate details, if no Actuals charges were recorded
*/
UPDATE ##tblActualLoadDetailsALD
SET Act_Fuel = PreRate_Fuel,
Act_Accessorials = PreRate_Accessorials,
Act_Linehaul = PreRate_Linehaul,
Act_Repo = PreRate_Repo,
Act_ZUSB = PreRate_ZUSB
WHERE SRVC_CD NOT IN ('FDCC')
AND ActualRateCharge = 'No'
AND PreRateCharge = 'Yes'

/*
Update Miles if distance is 0 or null to 1
*/
UPDATE ##tblActualLoadDetailsALD
SET FIXD_ITNR_DIST = 1
WHERE FIXD_ITNR_DIST <= 1 
or FIXD_ITNR_DIST is null

/*
Update Act_Linehaul if <1 or null to 1500
*/
UPDATE ##tblActualLoadDetailsALD
SET Act_Linehaul = 1500
WHERE Act_Linehaul < 1 
or Act_Linehaul is null

/*
Update Marketplace Catchall
*/
UPDATE ##tblActualLoadDetailsALD
Set Drop_it = 'Y'
WHERE SRVC_CD NOT IN ('FDCC')
AND MARKETPLACE_CATCHALL = 'Y'

/*
Update linehaul costs for intermodal, based on fuel differential cost
*/
UPDATE ##tblActualLoadDetailsALD
SET Act_Linehaul = CASE when EQMT_TYP not in ('53IM') THEN Act_Linehaul - (@fuelDifferential* FIXD_ITNR_DIST) 
	else 
Act_Linehaul - ((@fuelDifferential*FIXD_ITNR_DIST)/2) END
WHERE SRVC_CD='OPEN'
AND CAST(Act_Fuel as NVARCHAR(10)) in (' ','','.','-')

/*
Update fuel costs for intermodal, based on fuel differential cost
*/
UPDATE ##tblActualLoadDetailsALD
SET Act_Linehaul = CASE when EQMT_TYP not in ('53IM') THEN @fuelDifferential*FIXD_ITNR_DIST
	else 
(@fuelDifferential*FIXD_ITNR_DIST)/2 END
WHERE SRVC_CD='OPEN'
AND CAST(Act_Fuel as NVARCHAR(10)) in (' ','','.','-')

/*
Drop column from ##tblActualLoadDetailsALD if it exists
If it doesn't exist, then add it to the table
*/
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS OrderType
ALTER TABLE ##tblActualLoadDetailsALD ADD OrderType NVARCHAR(10)

/*
Determine order type for each Load
*/
UPDATE ##tblActualLoadDetailsALD
SET OrderType = 
CASE WHEN CORP1_ID = 'RM' Then 'RM-INBOUND'
WHEN CORP1_ID = 'RF' Then 'RF-INBOUND' 
WHEN substring(LAST_SHPG_LOC_CD,1,1) = 'R' then 'RETURNS'
WHEN substring(LAST_SHPG_LOC_CD,1,1) = '1' then 'INTERMILL'
WHEN substring(LAST_SHPG_LOC_CD,1,1) = '2' then 'INTERMILL'
WHEN substring(LAST_SHPG_LOC_CD,1,1) = '5' then 'CUSTOMER'
WHEN substring(LAST_SHPG_LOC_CD,1,1) = '9' then 'CUSTOMER'
ELSE NULL
END

/*
Drop column from ##tblActualLoadDetailsALD if it exists
If it doesn't exist, then add it to the table
*/
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS CarrierManager
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS Region
ALTER TABLE ##tblActualLoadDetailsALD ADD CarrierManager NVARCHAR(50)
ALTER TABLE ##tblActualLoadDetailsALD ADD Region NVARCHAR(10)

/*
Update Carrier Manager. If Inbound, use the destination state else use the origin state
*/
UPDATE ##tblactualloaddetailsald 
SET    carriermanager = RA.carriermanager, 
       region = RA.region 
FROM   ##tblactualloaddetailsald 
       LEFT JOIN uscttdev.dbo.tblregionalassignments RA 
              ON RA.stateabbv = CASE 
                                  WHEN ordertype LIKE ( '%INBOUND%' ) THEN 
                                  last_sta_cd 
                                  ELSE frst_sta_cd 
                                END 

/*
Get volume for each LD_LEG_ID, and set business units based off of volume share
*/

/*
Drop column from ##tblActualLoadDetailsALD if it exists
If it doesn't exist, then add it to the table
*/
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS BU
ALTER TABLE ##tblActualLoadDetailsALD ADD BU NVARCHAR(10)


/*
Create temp table of business units based off of shipment volume, ranked by volume
*/
DROP TABLE IF EXISTS ##tblActualBusinessUnits
Select * into ##tblActualBusinessUnits from OPENQUERY(NAJDAPRD,'SELECT DISTINCT
    ld_leg_id,
    ob_bu
FROM
    (
        SELECT
            ld_leg_id,
            CASE
                WHEN business IS NULL THEN
                    bus_unit
                ELSE
                    business
            END AS ob_bu,
            vol_rank
        FROM
            (
                SELECT DISTINCT
                    l.ld_leg_id,
                    sh.rfrc_num10 AS bu,
                    sh.vol,
                    CASE
                        WHEN substr(last_shpg_loc_cd, 1, 4) IN (
                            ''2000'',
                            ''2019'',
                            ''2022'',
                            ''2023'',
                            ''2024'',
                            ''2026'',
                            ''2027'',
                            ''2028'',
                            ''2029'',
                            ''2031'',
                            ''2032'',
                            ''2035'',
                            ''2036'',
                            ''2038'',
                            ''2041'',
                            ''2049'',
                            ''2050'',
                            ''2054'',
                            ''2063'',
                            ''2075'',
                            ''2094'',
                            ''2100'',
                            ''2137'',
                            ''2138'',
                            ''2142'',
                            ''2170'',
                            ''2171'',
                            ''2172'',
                            ''2183'',
                            ''2187'',
                            ''2191'',
                            ''2197'',
                            ''2210'',
                            ''2213'',
                            ''2240'',
                            ''2275'',
                            ''2283'',
                            ''2291'',
                            ''2292'',
                            ''2300'',
                            ''2303'',
                            ''2307'',
                            ''2314'',
                            ''2320'',
                            ''2331'',
                            ''2336'',
                            ''2347'',
                            ''2353'',
                            ''2358'',
                            ''2359'',
                            ''2360'',
                            ''2369'',
                            ''2370'',
                            ''2385'',
                            ''2399'',
                            ''2408'',
                            ''2412'',
                            ''2414'',
                            ''2419'',
                            ''2422'',
                            ''2443'',
                            ''2463'',
                            ''2483'',
                            ''2487'',
                            ''2489'',
                            ''2496'',
                            ''2500'',
                            ''2510'',
                            ''2511'',
                            ''2822'',
                            ''2839''
                        ) THEN
                            ''CONSUMER''
                        WHEN substr(last_shpg_loc_cd, 1, 4) IN (
                            ''2034'',
                            ''2039'',
                            ''2040'',
                            ''2042'',
                            ''2043'',
                            ''2044'',
                            ''2048'',
                            ''2051'',
                            ''2079'',
                            ''2080'',
                            ''2091'',
                            ''2096'',
                            ''2099'',
                            ''2104'',
                            ''2106'',
                            ''2111'',
                            ''2112'',
                            ''2113'',
                            ''2124'',
                            ''2126'',
                            ''2161'',
                            ''2177'',
                            ''2200'',
                            ''2234'',
                            ''2299'',
                            ''2301'',
                            ''2302'',
                            ''2304'',
                            ''2310'',
                            ''2323'',
                            ''2325'',
                            ''2334'',
                            ''2348'',
                            ''2349'',
                            ''2350'',
                            ''2356'',
                            ''2362'',
                            ''2363'',
                            ''2375'',
                            ''2386'',
                            ''2415'',
                            ''2416'',
                            ''2425'',
                            ''2429'',
                            ''2446'',
                            ''2449'',
                            ''2459'',
                            ''2460'',
                            ''2467'',
                            ''2474'',
                            ''2476'',
                            ''2477'',
                            ''2485'',
                            ''2495'',
                            ''2505'',
                            ''2827'',
                            ''2833'',
                            ''2834'',
                            ''2837''
                        ) THEN
                            ''KCP''
                        ELSE
                            ''UNKNOWN''
                    END bus_unit,
                    CASE
                        WHEN sh.rfrc_num10 IN (
                            ''2810'',
                            ''2820'',
                            ''Z01''
                        ) THEN
                            ''CONSUMER''
                        WHEN sh.rfrc_num10 IN (
                            ''2811'',
                            ''2821'',
                            ''Z02'',
                            ''Z04'',
                            ''Z06'',
                            ''Z07''
                        ) THEN
                            ''KCP''
                        WHEN sh.rfrc_num10 = ''Z05'' THEN
                            ''NON WOVENS''
                        ELSE
                            NULL
                    END business,
                    RANK() OVER(
                        PARTITION BY l.ld_leg_id
                        ORDER BY
                            sh.nmnl_wgt DESC
                    ) AS vol_rank
                FROM
                    najdaadm.load_leg_r          l,
                    najdaadm.load_leg_detail_r   ld,
                    najdaadm.shipment_r          sh
                WHERE
                    l.ld_leg_id = ld.ld_leg_id
                    AND ld.shpm_num = sh.shpm_num
                    AND l.cur_optlstat_id >= 320
                    AND EXTRACT(YEAR FROM
						CASE
							WHEN l.shpd_dtt IS NULL THEN
								l.strd_dtt
							ELSE
								l.shpd_dtt
						END
					) >= EXTRACT(YEAR FROM SYSDATE)-1
                    AND l.eqmt_typ IN (
                        ''48FT'',
                        ''48TC'',
                        ''53FT'',
                        ''53TC'',
                        ''53IM'',
                        ''53RT'',
                        ''53HC'',
						''LTL''
                    )
                    AND last_ctry_cd IN (
                        ''MEX'',
                        ''CAN'',
                        ''USA''
                    )
					AND l.last_shpg_loc_cd NOT LIKE ''LCL%''
            )
    )
WHERE
    vol_rank = 1')

/*
Update business unit for each load
If load is Inbound, use the Inbound Business Unit
If load isn't outbound, use the Actuals Business Unit

UPDATE ##tblActualLoadDetailsALD
SET BU = CASE WHEN ORDERTYPE LIKE ('%INBOUND%') THEN
		UPPER(IBU.BUSINESS)
	ELSE
		UPPER(ABU.OB_BU)
	END
FROM ##tblActualLoadDetailsALD ALD
	LEFT JOIN uscttdev.dbo.tblInboundBusinessUnits IBU on IBU.ShipToID = 
		CASE WHEN ALD.ORDERTYPE LIKE ('%INBOUND%') THEN 
				ALD.LAST_SHPG_LOC_CD 
			ELSE ALD.FRST_SHPG_LOC_CD 
		END
	LEFT JOIN ##tblActualBusinessUnits ABU on ABU.LD_LEG_ID = ALD.LD_LEG_ID
*/
UPDATE ##tblActualLoadDetailsALD
SET BU = CASE WHEN abu.OB_BU IS NULL THEN 'UNKNOWN' ELSE abu.OB_BU END
FROM ##tblActualLoadDetailsALD ald
LEFT JOIN ##tblActualBusinessUnits abu ON ald.ld_leg_id = abu.ld_leg_id


/*
Drop column from ##tblActualLoadDetailsALD if it exists
If it doesn't exist, then add it to the table
*/
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS ShipMode
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS Year
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS Month
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS Week_Beginning
ALTER TABLE ##tblActualLoadDetailsALD ADD ShipMode NVARCHAR(10)
ALTER TABLE ##tblActualLoadDetailsALD ADD Year INT
ALTER TABLE ##tblActualLoadDetailsALD ADD Month INT
ALTER TABLE ##tblActualLoadDetailsALD ADD Week_Beginning DATETIME


/*
Update Shipmode and Date Fields
*/
SET DATEFIRST 1 --Set start date of week to Monday
UPDATE ##tblActualLoadDetailsALD
SET ShipMode = CASE WHEN EQMT_TYP = '53IM' THEN 'INTERMODAL' 
WHEN EQMT_TYP = 'LTL' THEN 'LTL' 
ELSE 'TRUCK' END,
YEAR = DATEPART(yyyy, CASE WHEN SHPD_DTT IS NULL THEN STRD_DTT ELSE SHPD_DTT END),
MONTH = DATEPART(mm, CASE WHEN SHPD_DTT IS NULL THEN STRD_DTT ELSE SHPD_DTT END),
Week_Beginning = CONVERT(VARCHAR,DATEADD(DD, 1 - DATEPART(DW, CASE WHEN SHPD_DTT IS NULL THEN STRD_DTT ELSE SHPD_DTT END), CASE WHEN SHPD_DTT IS NULL THEN STRD_DTT ELSE SHPD_DTT END),101)

/*
Create master TMS Zone table
*/
SELECT * INTO ##tblTMSMasterZones FROM OPENQUERY(NAJDAPRD,'SELECT DISTINCT
    TRIM(replace(concat(sta_cd, substr(zn_desc, 1, instr(zn_desc, '','') - 1)), '' '', '''')) AS stcity,
    zn_cd AS zone,
    zn_desc,
    ctry_cd,
    replace(replace(regexp_substr(zn_desc, '',[^,]+,''), '','', ''''), '' '', '''') AS countryqual,
    TRIM(replace(substr(zn_desc, 1, instr(zn_desc, '','') - 1), ''  '', '''')) AS city,
    sta_cd,
    crtd_dtt,
    crtd_usr_cd
FROM
    najdaadm.zone_r
WHERE
    ctry_cd IN (
        ''USA'',
        ''CAN'',
        ''MEX''
    ) AND
	zn_cd NOT LIKE ''%C-%''
ORDER BY
    ctry_cd,
    sta_cd,
    TRIM(replace(substr(zn_desc, 1, instr(zn_desc, '','') - 1), ''  '', '''')) ASC')

/*
Drop column from ##tblActualLoadDetailsALD if it exists
If it doesn't exist, then add it to the table
*/
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS Origin_Zone
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS Dest_Zone
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS Lane
ALTER TABLE ##tblActualLoadDetailsALD ADD Origin_Zone NVARCHAR(16)
ALTER TABLE ##tblActualLoadDetailsALD ADD Dest_Zone NVARCHAR(25)
ALTER TABLE ##tblActualLoadDetailsALD ADD Lane NVARCHAR(25)

/*
Update Zones to matching values from ##tblTMSMasterZones
*/
UPDATE ##tblActualLoadDetailsALD
SET Origin_Zone = TMZO.ZONE
FROM ##tblActualLoadDetailsALD ALD 
JOIN ##tblTMSMasterZones TMZO ON TMZO.CTRY_CD = ALD.FRST_CTRY_CD
								AND TMZO.STA_CD = ALD.FRST_STA_CD
								AND TMZO.CITY = ALD.FRST_CTY_NAME
/*
Overwrite with variables below in case something is wonky in the FRST_CTY_NAME
*/
UPDATE ##tblActualLoadDetailsALD
SET Origin_Zone = CASE WHEN FRST_CTY_NAME = 'GUILDERLAND CENTER' THEN 'NYGUICEN'
	WHEN FRST_CTY_NAME = 'COWPENS' AND FRST_STA_CD = 'SC' THEN 'SCCOWPEN'
	WHEN FRST_CTY_NAME = 'RANSOM' AND FRST_STA_CD = 'PA' THEN 'PARANSOM'
	WHEN FRST_CTY_NAME = 'HANOVER TOWNSHIP' AND FRST_STA_CD = 'PA' THEN 'PAHANOVT'
	WHEN FRST_CTY_NAME = 'HANOVER PARK' AND FRST_STA_CD = 'IL' THEN 'ILHANPAR'
	WHEN FRST_CTY_NAME = 'MT. HOLLY' AND FRST_STA_CD = 'NJ' THEN 'NJMOUNTH'
	WHEN FRST_CTY_NAME = 'CONNELLY SPINGS' AND FRST_STA_CD = 'NC' THEN 'NCCONNEL'
	WHEN FRST_CTY_NAME = 'MT VERNON' AND FRST_STA_CD = 'OH' THEN 'OHMOUNTV'
	WHEN FRST_CTY_NAME = 'FORT LAUDERDALE' THEN 'FLFTLAUD'
	WHEN FRST_CTY_NAME = 'FORT MYERS' THEN 'FLFTMYER'
	WHEN FRST_CTY_NAME = 'FORT MEYERS' THEN 'FLFTMYER'
	WHEN FRST_CTY_NAME = 'WINTER GARDEN' THEN 'FLWINGAR'
	WHEN FRST_CTY_NAME = 'EAST PEORIA' THEN 'ILEPEORI'
	WHEN FRST_CTY_NAME = 'WEST BERLIN' THEN 'NJWBERLI'
	WHEN FRST_CTY_NAME = 'CUYAHOGA HEIGHTS' THEN 'OHCUYHEI'
	WHEN FRST_CTY_NAME = 'SPRINGFIELD' AND FRST_STA_CD='OH' THEN 'OHSPRFIE'
	WHEN FRST_CTY_NAME = 'WILLIAMSPORT' THEN 'PAWILPOR'
	WHEN FRST_CTY_NAME = 'WEST ALLIS' THEN 'WIWALLIS'
	WHEN FRST_CTY_NAME = 'TERRACE BAY' THEN 'ONTERBAY'
	WHEN FRST_CTY_NAME = 'FRANKLIN PARK' THEN 'ILFRAPAR'
	WHEN FRST_CTY_NAME = 'LEBANON JUNCTION' THEN 'KYLEBJUN'
	WHEN FRST_CTY_NAME = 'ELIZABETHTOWN' THEN 'PAELITOW' 
	ELSE Origin_Zone END

/*
Updates for KC-Romeoville Origin Zone
*/
UPDATE ##tblActualLoadDetailsALD
SET Origin_Zone = CASE
                WHEN SUBSTRING(ald.FRST_SHPG_LOC_CD, 1, 4) IN (
                    '2358',
                    '2292'
                ) THEN
                    'KCILROME-NOF'
                WHEN SUBSTRING(ald.FRST_SHPG_LOC_CD, 1, 4) = '2323' THEN
                    'KCILROME-KCP'
                WHEN SUBSTRING(ald.FRST_SHPG_LOC_CD, 1, 4) = '2474' THEN
                    'KCILROME-SKIN'
                ELSE
                    ald.Origin_Zone
            END
FROM ##tblActualLoadDetailsALD ald
WHERE SUBSTRING(ald.FRST_SHPG_LOC_CD, 1, 4) IN ('2292','2323','2358','2474')

/*
Drop column from ##tblActualLoadDetailsALD if it exists
If it doesn't exist, then add it to the table
*/
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS OriginPlant
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS DestinationPlant
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS CustomerHierarchy
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS CustomerGroup
ALTER TABLE ##tblActualLoadDetailsALD ADD OriginPlant NVARCHAR(50)
ALTER TABLE ##tblActualLoadDetailsALD ADD DestinationPlant NVARCHAR(50)
ALTER TABLE ##tblActualLoadDetailsALD ADD CustomerHierarchy NVARCHAR(25)
ALTER TABLE ##tblActualLoadDetailsALD ADD CustomerGroup NVARCHAR(25)

/*
Update Origin/Destination plant, based off of first character of individual codes
*/
UPDATE ##tblActualLoadDetailsALD
SET OriginPlant = CASE 
WHEN SUBSTRING(FRST_SHPG_LOC_CD,1,1) = 'V' THEN SUBSTRING(FRST_SHPG_LOC_CD,1,9)
WHEN SUBSTRING(FRST_SHPG_LOC_CD,1,1) = '1' OR SUBSTRING(FRST_SHPG_LOC_CD,1,1) = '2' THEN SUBSTRING(FRST_SHPG_LOC_CD,1,4) + ' - ' + FRST_CTY_NAME
ELSE 'UNKNOWN' 
END,
DestinationPlant = CASE 
WHEN SUBSTRING(LAST_SHPG_LOC_CD,1,1) = '5' THEN SUBSTRING(LAST_SHPG_LOC_CD,1,8)
WHEN SUBSTRING(LAST_SHPG_LOC_CD,1,1) = '1' OR SUBSTRING(LAST_SHPG_LOC_CD,1,1) = '2' THEN SUBSTRING(LAST_SHPG_LOC_CD,1,4) + ' - ' + FRST_CTY_NAME
ELSE 'UNKNOWN' 
END

/*
Update CustomerHierarchy/Group based off of Origin/Destination
*/
UPDATE ##tblActualLoadDetailsALD
SET CustomerHierarchy = CASE WHEN CUST.Hierarchy IS NULL AND CUST1.Hierarchy IS NULL THEN [DestinationPlant]
WHEN CUST1.Hierarchy IS NULL THEN CUST.Hierarchy
ELSE CUST1.Hierarchy
END,
CustomerGroup = CASE WHEN CUST.Hierarchy IS NULL AND CUST1.Hierarchy IS NULL THEN NULL
WHEN CUST1.Hierarchy IS NULL THEN CUST.CustomerGroup
ELSE CUST1.CustomerGroup
END
FROM ##tblActualLoadDetailsALD AS ALD
LEFT JOIN USCTTDEV.dbo.tblCustomers CUST on CUST.HierarchyNum = ALD.DestinationPlant
LEFT JOIN USCTTDEV.dbo.tblCustomers CUST1 on CUST1.HierarchyNum = ALD.OriginPlant

/*
Update the Origin Plant to the vendor hierarchy name from NAJDAADM.CUST_TV
*/
UPDATE ##tblActualLoadDetailsALD
SET OriginPlant = cust.name
FROM ##tblActualLoadDetailsALD ald
INNER JOIN (SELECT * from OPENQUERY(NAJDAPRD,'
	SELECT DISTINCT CUST_CD, NAME
	FROM NAJDAADM.CUST_TV cust        
	GROUP BY CUST_CD, NAME
')) cust ON cust.cust_cd = SUBSTRING(ald.FRST_SHPG_LOC_CD,2,8)
WHERE SUBSTRING(FRST_SHPG_LOC_CD,1,1) = 'V'

/*
Create temp table of business units based off of shipment volume
Will pivot in next step

SELECT * FROM ##tblBUWeightRaw WHERE LD_LEG_ID = 516629280
SELECT * FROM USCTTDEV.dbo.tblActualLoadDetail WHERE LD_LEG_ID = 516629280
SELECT * FROM ##tblActualBusinessUnits WHERE LD_LEG_ID = 516629280
*/
DROP TABLE IF EXISTS ##tblBUWeightRaw
Select * into ##tblBUWeightRaw from OPENQUERY(NAJDAPRD,'SELECT DISTINCT
    ld_leg_id,
    ob_bu as OBBU,
    sum(vol) as TotalVolume,
    sum(nmnl_wgt) as TotalWeight,
    count(ld_leg_id) as Count
FROM
    (
        SELECT
            ld_leg_id,
            CASE
                WHEN business IS NULL THEN
                    bus_unit
                ELSE
                    business
            END AS ob_bu,
            vol,
            nmnl_wgt
        FROM
            (
                SELECT DISTINCT
                    l.ld_leg_id,
                    sh.rfrc_num10 AS bu,
                    sh.vol,
                    sh.nmnl_wgt,
                    CASE
                        WHEN substr(last_shpg_loc_cd, 1, 4) IN (
                            ''2000'',
                            ''2019'',
                            ''2022'',
                            ''2023'',
                            ''2024'',
                            ''2026'',
                            ''2027'',
                            ''2028'',
                            ''2029'',
                            ''2031'',
                            ''2032'',
                            ''2035'',
                            ''2036'',
                            ''2038'',
                            ''2041'',
                            ''2049'',
                            ''2050'',
                            ''2054'',
                            ''2063'',
                            ''2075'',
                            ''2094'',
                            ''2100'',
                            ''2137'',
                            ''2138'',
                            ''2142'',
                            ''2170'',
                            ''2171'',
                            ''2172'',
                            ''2183'',
                            ''2187'',
                            ''2191'',
                            ''2197'',
                            ''2210'',
                            ''2213'',
                            ''2240'',
                            ''2275'',
                            ''2283'',
                            ''2291'',
                            ''2292'',
                            ''2300'',
                            ''2303'',
                            ''2307'',
                            ''2314'',
                            ''2320'',
                            ''2331'',
                            ''2336'',
                            ''2347'',
                            ''2353'',
                            ''2358'',
                            ''2359'',
                            ''2360'',
                            ''2369'',
                            ''2370'',
                            ''2385'',
                            ''2399'',
                            ''2408'',
                            ''2412'',
                            ''2414'',
                            ''2419'',
                            ''2422'',
                            ''2443'',
                            ''2463'',
                            ''2483'',
                            ''2487'',
                            ''2489'',
                            ''2496'',
                            ''2500'',
                            ''2510'',
                            ''2511'',
                            ''2822'',
                            ''2839''
                        ) THEN
                            ''CONSUMER''
                        WHEN substr(last_shpg_loc_cd, 1, 4) IN (
                           ''2034'',
                            ''2039'',
                            ''2040'',
                            ''2042'',
                            ''2043'',
                            ''2044'',
                            ''2048'',
                            ''2051'',
                            ''2079'',
                            ''2080'',
                            ''2091'',
                            ''2096'',
                            ''2099'',
                            ''2104'',
                            ''2106'',
                            ''2111'',
                            ''2112'',
                            ''2113'',
                            ''2124'',
                            ''2126'',
                            ''2161'',
                            ''2177'',
                            ''2200'',
                            ''2234'',
                            ''2299'',
                            ''2301'',
                            ''2302'',
                            ''2304'',
                            ''2310'',
                            ''2323'',
                            ''2325'',
                            ''2334'',
                            ''2348'',
                            ''2349'',
                            ''2350'',
                            ''2356'',
                            ''2362'',
                            ''2363'',
                            ''2375'',
                            ''2386'',
                            ''2415'',
                            ''2416'',
                            ''2425'',
                            ''2429'',
                            ''2446'',
                            ''2449'',
                            ''2459'',
                            ''2460'',
                            ''2467'',
                            ''2474'',
                            ''2476'',
                            ''2477'',
                            ''2485'',
                            ''2495'',
                            ''2505'',
                            ''2827'',
                            ''2833'',
                            ''2834'',
                            ''2837''
                        ) THEN
                            ''KCP''
                        ELSE
                            ''UNKNOWN''
                    END bus_unit,
                    CASE
                        WHEN sh.rfrc_num10 IN (
                            ''2810'',
                            ''2820'',
                            ''Z01''
                        ) THEN
                            ''CONSUMER''
                        WHEN sh.rfrc_num10 IN (
                            ''2811'',
                            ''2821'',
                            ''Z02'',
                            ''Z04'',
                            ''Z06'',
                            ''Z07''
                        ) THEN
                            ''KCP''
                        WHEN sh.rfrc_num10 = ''Z05'' THEN
                            ''NON-WOVENS''
                        ELSE
                            NULL
                    END business
                FROM
                    najdaadm.load_leg_r          l,
                    najdaadm.load_leg_detail_r   ld,
                    najdaadm.shipment_r          sh
                WHERE
                    l.ld_leg_id = ld.ld_leg_id
                    AND ld.shpm_num = sh.shpm_num
                    AND (l.cur_optlstat_id >= 300 AND l.cur_optlstat_id < 350)
                    AND EXTRACT(YEAR FROM
						CASE
							WHEN l.shpd_dtt IS NULL THEN
								l.strd_dtt
							ELSE
								l.shpd_dtt
						END
					) >= EXTRACT(YEAR FROM SYSDATE)-1                 
                    AND l.eqmt_typ IN (
                        ''48FT'',
                        ''48TC'',
                        ''53FT'',
                        ''53TC'',
                        ''53IM'',
                        ''53RT'',
                        ''53HC'',
						''LTL''
                    )
                    AND last_ctry_cd IN (
                        ''MEX'',
                        ''CAN'',
                        ''USA''
                    )
					AND l.last_shpg_loc_cd NOT LIKE ''LCL%''
            )
    ) 
    --WHERE LD_LEG_ID = ''517901035''
    group by ld_leg_id, ob_bu
    order by ld_leg_id ASC')

/*
Create temp table for Aggregated Actual Rate Load Details

SELECT * FROM ##tblBUWeightRaw WHERE LD_LEG_ID = 517072170
SELECT * FROM ##tblActualBusinessUnits WHERE LD_LEG_ID = 517072170
SELECT * FROM ##tblBUWeightPivot WHERE LD_LEG_ID = 517072170
SELECT * FROM ##tblActualLoadDetailsALD WHERE LD_LEG_ID = 517072170
SELECT * FROM USCTTDEV.dbo.tblActualLoadDetail WHERE LD_LEG_ID = 516629280
*/
DROP TABLE IF EXISTS ##tblBUWeightPivot
CREATE TABLE ##tblBUWeightPivot
(
	LD_LEG_ID NVARCHAR(15),
	ConsumerWeight NUMERIC(18,2),
	KCPWeight NUMERIC(18,2),
	NonWovenWeight NUMERIC(18,2),
	UnknownWeight NUMERIC(18,2),
	ConsumerVolume NUMERIC(18,2),
	KCPVolume NUMERIC(18,2),
	NonWovenVolume NUMERIC(18,2),
	UnknownVolume NUMERIC(18,2),
	OrderCount INT,
	BUCount INT,
	TotalWeight NUMERIC(18,2),
	TotalVolume NUMERIC(18,2)
)

/*
Insert Unique LD_LEG_ID's into ##tblBUWeightPivot
*/
INSERT INTO ##tblBUWeightPivot (LD_LEG_ID)
SELECT DISTINCT LD_LEG_ID from ##tblBUWeightRaw
ORDER BY LD_LEG_ID ASC


UPDATE ##tblBUWeightPivot
SET ConsumerWeight = CONSUMER.TOTALWEIGHT,
ConsumerVolume = CONSUMER.TOTALVOLUME,
KCPWeight = KCP.TOTALWEIGHT,
KCPVolume = KCP.TOTALVOLUME,
NonWovenWeight = NW.TOTALWEIGHT,
NonWovenVolume = NW.TOTALVOLUME,
UnknownWeight = UK.TOTALWEIGHT,
UnknownVolume = UK.TOTALVOLUME,
BUCount = OTHER.OBBUCount,
OrderCount = OTHER.ORDERCOUNT,
TotalWeight = OTHER.TOTALWEIGHT,
TotalVolume = OTHER.TOTALVOLUME

FROM ##tblBUWeightPivot BUWP
LEFT JOIN 
(
	SELECT LD_LEG_ID,
	OBBU,
	SUM(TOTALWEIGHT) AS TOTALWEIGHT,
	SUM(TOTALVOLUME) AS TOTALVOLUME
	FROM ##tblBUWeightRaw
	WHERE OBBU = 'CONSUMER'
	GROUP BY LD_LEG_ID,
	OBBU

) AS CONSUMER
 ON CONSUMER.LD_LEG_ID = BUWP.LD_LEG_ID
LEFT JOIN
(
	SELECT LD_LEG_ID,
	OBBU,
	SUM(TOTALWEIGHT) AS TOTALWEIGHT,
	SUM(TOTALVOLUME) AS TOTALVOLUME
	FROM ##tblBUWeightRaw
	WHERE OBBU = 'KCP'
	GROUP BY LD_LEG_ID,
	OBBU

) AS KCP
 ON KCP.LD_LEG_ID = BUWP.LD_LEG_ID
LEFT JOIN
(
	SELECT LD_LEG_ID,
	OBBU,
	SUM(TOTALWEIGHT) AS TOTALWEIGHT,
	SUM(TOTALVOLUME) AS TOTALVOLUME
	FROM ##tblBUWeightRaw
	WHERE OBBU = 'NON-WOVENS'
	GROUP BY LD_LEG_ID,
	OBBU

) AS NW
 ON NW.LD_LEG_ID = BUWP.LD_LEG_ID
 LEFT JOIN
(
	SELECT LD_LEG_ID,
	OBBU,
	SUM(TOTALWEIGHT) AS TOTALWEIGHT,
	SUM(TOTALVOLUME) AS TOTALVOLUME
	FROM ##tblBUWeightRaw
	WHERE OBBU = 'UNKNOWN'
	GROUP BY LD_LEG_ID,
	OBBU

) AS UK
 ON UK.LD_LEG_ID = BUWP.LD_LEG_ID
  LEFT JOIN
(
	SELECT LD_LEG_ID,
	COUNT(OBBU) AS OBBUCount,
	SUM(COUNT) AS ORDERCOUNT,
    SUM(TOTALWEIGHT) AS TOTALWEIGHT,
	SUM(TOTALVOLUME) AS TOTALVOLUME
	FROM ##tblBUWeightRaw
	GROUP BY LD_LEG_ID
) AS OTHER
 ON OTHER.LD_LEG_ID = BUWP.LD_LEG_ID



/*
Drop column from ##tblActualLoadDetailsALD if it exists
If it doesn't exist, then add it to the table
*/
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS ConsumerWeight
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS KCPWeight
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS NonWovenWeight
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS UnknownWeight
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS ConsumerVolume
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS KCPVolume
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS NonWovenVolume
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS UnknownVolume
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS OrderCount
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS BUCount
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS TotalWeight
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS TotalVolume
ALTER TABLE ##tblActualLoadDetailsALD ADD ConsumerWeight NUMERIC(18,2)
ALTER TABLE ##tblActualLoadDetailsALD ADD KCPWeight NUMERIC(18,2)
ALTER TABLE ##tblActualLoadDetailsALD ADD NonWovenWeight NUMERIC(18,2)
ALTER TABLE ##tblActualLoadDetailsALD ADD UnknownWeight NUMERIC(18,2)
ALTER TABLE ##tblActualLoadDetailsALD ADD ConsumerVolume NUMERIC(18,2)
ALTER TABLE ##tblActualLoadDetailsALD ADD KCPVolume NUMERIC(18,2)
ALTER TABLE ##tblActualLoadDetailsALD ADD NonWovenVolume NUMERIC(18,2)
ALTER TABLE ##tblActualLoadDetailsALD ADD UnknownVolume NUMERIC(18,2)
ALTER TABLE ##tblActualLoadDetailsALD ADD OrderCount INT
ALTER TABLE ##tblActualLoadDetailsALD ADD BUCount INT
ALTER TABLE ##tblActualLoadDetailsALD ADD TotalWeight NUMERIC(18,2)
ALTER TABLE ##tblActualLoadDetailsALD ADD TotalVolume NUMERIC(18,2)

/*
Update ##tblActualLoadDetailsALD with data from ##tblBUWeightPivot
*/
UPDATE ##tblActualLoadDetailsALD
SET ConsumerWeight = buwp.ConsumerWeight,
KCPWeight = buwp.KCPWeight,
NonWovenWeight = buwp.NonWovenWeight,
UnknownWeight = buwp.UnknownWeight,
ConsumerVolume = buwp.ConsumerVolume,
KCPVolume = buwp.KCPVolume,
NonWovenVolume = buwp.NonWovenVolume,
UnknownVolume = buwp.UnknownVolume,
OrderCount = buwp.OrderCount,
BUCount = buwp.BUCount,
TotalWeight = CASE WHEN buwp.Totalweight <= .01 THEN .01 ELSE buwp.Totalweight END,
TotalVolume = buwp.TotalVolume
FROM ##tblActualLoadDetailsALD ald
INNER JOIN ##tblBUWeightPivot buwp ON ald.LD_LEG_ID = buwp.LD_LEG_ID

/*
Update ##tblActualLoadDetailsALD with Final Cost Calculations; weight by BU
*/
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS TotalCost
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS ConsumerTotalCost
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS ConsumerLinehaulCost
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS ConsumerFuelCost
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS ConsumerAccessorialsCost
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS KCPTotalCost
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS KCPLinehaulCost
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS KCPFuelCost
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS KCPAccessorialsCost
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS NonWovenTotalCost
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS NonWovenLinehaulCost
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS NonWovenFuelCost
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS NonWovenAccessorialsCost
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS UnknownTotalCost
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS UnknownLinehaulCost
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS UnknownFuelCost
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS UnknownAccessorialsCost
ALTER TABLE ##tblActualLoadDetailsALD ADD TotalCost NUMERIC(18,2)
ALTER TABLE ##tblActualLoadDetailsALD ADD ConsumerTotalCost NUMERIC(18,2)
ALTER TABLE ##tblActualLoadDetailsALD ADD ConsumerLinehaulCost NUMERIC(18,2)
ALTER TABLE ##tblActualLoadDetailsALD ADD ConsumerFuelCost NUMERIC(18,2)
ALTER TABLE ##tblActualLoadDetailsALD ADD ConsumerAccessorialsCost NUMERIC(18,2)
ALTER TABLE ##tblActualLoadDetailsALD ADD KCPTotalCost NUMERIC(18,2)
ALTER TABLE ##tblActualLoadDetailsALD ADD KCPLinehaulCost NUMERIC(18,2)
ALTER TABLE ##tblActualLoadDetailsALD ADD KCPFuelCost NUMERIC(18,2)
ALTER TABLE ##tblActualLoadDetailsALD ADD KCPAccessorialsCost NUMERIC(18,2)
ALTER TABLE ##tblActualLoadDetailsALD ADD NonWovenTotalCost NUMERIC(18,2)
ALTER TABLE ##tblActualLoadDetailsALD ADD NonWovenLinehaulCost NUMERIC(18,2)
ALTER TABLE ##tblActualLoadDetailsALD ADD NonWovenFuelCost NUMERIC(18,2)
ALTER TABLE ##tblActualLoadDetailsALD ADD NonWovenAccessorialsCost NUMERIC(18,2)
ALTER TABLE ##tblActualLoadDetailsALD ADD UnknownTotalCost NUMERIC(18,2)
ALTER TABLE ##tblActualLoadDetailsALD ADD UnknownLinehaulCost NUMERIC(18,2)
ALTER TABLE ##tblActualLoadDetailsALD ADD UnknownFuelCost NUMERIC(18,2)
ALTER TABLE ##tblActualLoadDetailsALD ADD UnknownAccessorialsCost NUMERIC(18,2)

/*
Update Total Cost - Sum of linehaul, accessorials, fuel, repo, ZUSB
*/
UPDATE ##tblActualLoadDetailsALD
SET TotalCost = ISNULL(CONVERT(NUMERIC(18,2),Act_Linehaul),0)
+ISNULL(CONVERT(NUMERIC(18,2),Act_Accessorials),0)
+ISNULL(CONVERT(NUMERIC(18,2),Act_Fuel),0)
+ISNULL(CONVERT(NUMERIC(18,2),Act_Repo),0)
+ISNULL(CONVERT(NUMERIC(18,2),Act_ZUSB),0)

/*
Now that we've got total cost, let's split out by the difference business units
If there's less than a volume (cube) of 2, then use Weight
*/
UPDATE ##tblActualLoadDetailsALD SET
/*
Total Cost
*/
ConsumerTotalCost = (CASE WHEN TOT_VOL < 2 THEN (ConsumerWeight/TotalWeight)*TotalCost ELSE (ConsumerVolume/TotalVolume)*TotalCost END),
KCPTotalCost = (CASE WHEN TOT_VOL < 2 THEN (KCPWeight/TotalWeight)*TotalCost ELSE (KCPVolume/TotalVolume)*TotalCost END),
NonWovenTotalCost = (CASE WHEN TOT_VOL < 2 THEN (NonWovenWeight/TotalWeight)*TotalCost ELSE (NonWovenVolume/TotalVolume)*TotalCost END),
UnKnownTotalCost = (CASE WHEN TOT_VOL < 2 THEN (UnknownWeight/TotalWeight)*TotalCost ELSE (UnknownVolume/TotalVolume)*TotalCost END),
/*
Linehaul
*/
ConsumerLinehaulCost = (CASE WHEN TOT_VOL < 2 THEN (ConsumerWeight/TotalWeight)*Act_Linehaul ELSE (ConsumerVolume/TotalVolume)*Act_Linehaul END),
KCPLinehaulCost = (CASE WHEN TOT_VOL < 2 THEN (KCPWeight/TotalWeight)*Act_Linehaul ELSE (KCPVolume/TotalVolume)*Act_Linehaul END),
NonWovenLinehaulCost = (CASE WHEN TOT_VOL < 2 THEN (NonWovenWeight/TotalWeight)*Act_Linehaul ELSE (NonWovenVolume/TotalVolume)*Act_Linehaul END),
UnknownLinehaulCost = (CASE WHEN TOT_VOL < 2 THEN (UnknownWeight/TotalWeight)*Act_Linehaul ELSE (UnknownVolume/TotalVolume)*Act_Linehaul END),
/*
Fuel
*/
ConsumerFuelCost = (CASE WHEN TOT_VOL < 2 THEN (ConsumerWeight/TotalWeight)*Act_Fuel ELSE (ConsumerVolume/TotalVolume)*Act_Fuel END),
KCPFuelCost = (CASE WHEN TOT_VOL < 2 THEN (KCPWeight/TotalWeight)*Act_Fuel ELSE (KCPVolume/TotalVolume)*Act_Fuel END),
NonWovenFuelCost = (CASE WHEN TOT_VOL < 2 THEN (NonWovenWeight/TotalWeight)*Act_Fuel ELSE (NonWovenVolume/TotalVolume)*Act_Fuel END),
UnknownFuelCost = (CASE WHEN TOT_VOL < 2 THEN (UnknownWeight/TotalWeight)*Act_Fuel ELSE (UnknownVolume/TotalVolume)*Act_Fuel END),
/*
Accessorials
*/
ConsumerAccessorialsCost = (CASE WHEN TOT_VOL < 2 THEN (ConsumerWeight/TotalWeight)*Act_Accessorials ELSE (ConsumerVolume/TotalVolume)*Act_Accessorials END),
KCPAccessorialsCost = (CASE WHEN TOT_VOL < 2 THEN (KCPWeight/TotalWeight)*Act_Accessorials ELSE (KCPVolume/TotalVolume)*Act_Accessorials END),
NonWovenAccessorialsCost = (CASE WHEN TOT_VOL < 2 THEN (NonWovenWeight/TotalWeight)*Act_Accessorials ELSE (NonWovenVolume/TotalVolume)*Act_Accessorials END),
UnknownAccessorialsCost = (CASE WHEN TOT_VOL < 2 THEN (UnknownWeight/TotalWeight)*Act_Accessorials ELSE (UnknownVolume/TotalVolume)*Act_Accessorials END)

/*
Update ##tblActualLoadDetailsALD with FRAN marker
*/
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS FRAN
ALTER TABLE ##tblActualLoadDetailsALD ADD FRAN NVARCHAR(20)

/*
If on the audit table as 'FRAN', and also 'OPEN' in srvc_cd, then mark FRAN as 'FRAN - Tendered' else 'FRAN - Attempted'
Also, yo dawg... I see you like FRAN, so I put a FRAN in your FRAN so you can FRAN while you FRAN
*/
UPDATE ##tblActualLoadDetailsALD
SET FRAN = (CASE WHEN ald.srvc_cd='OPEN' THEN 'FRAN - Tendered' ELSE 'FRAN - Attempted' END )
FROM ##tblActualLoadDetailsALD ald
INNER JOIN (SELECT * from OPENQUERY(NAJDAPRD,'
	SELECT DISTINCT LD_LEG_ID, ''FRAN'' AS FRAN
	FROM NAJDAADM.AUDIT_LOAD_LEG_R alr
	WHERE LD_CARR_CD = ''FRAN''                  
	GROUP BY LD_LEG_ID, ''FRAN''
')) fran ON ald.ld_leg_id = fran.ld_leg_id

/*
Update ##tblActualLoadDetailsALD with RFT marker
*/
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS RFT
ALTER TABLE ##tblActualLoadDetailsALD ADD RFT NVARCHAR(30)

/*
Update ##tblActualLoadDetailsALD to match the ManuallyTouchedReason from tblRFTDetailDataHistorical, which matches the Tableau reason
*/
UPDATE ##tblActualLoadDetailsALD
SET RFT = rft.ManuallyTouchedReason
FROM ##tblActualLoadDetailsALD ald
	INNER JOIN (
		SELECT rf.*, SUM(cnt.Count) as Count FROM (
			SELECT DISTINCT LOAD_NUMBER, ManuallyTouchedReason
			from USCTTDEV.dbo.tblRFTDetailDataHistorical
			) rf
				INNER JOIN (
					SELECT DISTINCT LOAD_NUMBER, 1 as Count 
					from USCTTDEV.dbo.tblRFTDetailDataHistorical 
					) cnt ON
						cnt.load_Number = rf.LOAD_NUMBER
						WHERE rf.ManuallyTouchedReason <> 'Automated'
						GROUP BY rf.LOAD_NUMBER, rf.ManuallyTouchedReason						
					) rft ON
			rft.LOAD_NUMBER = ald.LD_LEG_ID

/*
Create temp table for All Awards
*/
DROP TABLE IF EXISTS ##tblAwards
Select * into ##tblAwards from OPENQUERY(NAJDAQAX,'SELECT DISTINCT
    tbllanes.laneid,
    tbllanes.orig_city_state   AS OriginZone,
    tbllanes.dest_city_state   AS DestZone,
	tbllanes.orig_city_state || ''-'' || tbllanes.dest_city_state AS Lane,
	miles                      AS Mileage,
	brk_amt_dlr                AS RPM,
    min_chrg_dlr               AS MinCharge,
	CASE
        WHEN miles = 0 THEN
            ROUND(brk_amt_dlr,2)
        ELSE
            CASE
                WHEN ( brk_amt_dlr * miles ) > min_chrg_dlr THEN
                    ROUND(brk_amt_dlr,2)
                ELSE
                    Round(( min_chrg_dlr ) / miles,2)
            END
    END AS AwardRPM,
	CASE
        WHEN miles = 0 THEN
            ''Rate Per Mile''
        ELSE
            CASE
                WHEN ( brk_amt_dlr * miles ) > min_chrg_dlr THEN
                    ''Rate Per Mile''
                ELSE
                    ''Min Charge''
            END
    END AS ChargeType,
	'''' AS Rank,
	tblawards.scac AS Service,
	awardpct,
    CAST(tbllaneaudit.updated_loads AS VARCHAR(1000)) AS LaneAnnualVol,
	CASE
    WHEN round(awardpct *(updated_loads / 52), 1) < 1 THEN
        1
    ELSE
        round(awardpct *(updated_loads / 52), 1)
    END AS CarrWKVol,
	CASE
		WHEN round((awardpct *(updated_loads / 52)) * 1.15, 1) < 1 THEN
			1
		ELSE
			round((awardpct *(updated_loads / 52)) * 1.15, 1)
    END AS CarrWKVol_Surge,
    CASE
        WHEN ship_mode = ''IM'' THEN
            ''53IM''
        ELSE
            ''53FT''
    END AS EquipType,
	CASE
		WHEN ship_mode = ''IM'' THEN
			''Intermodal''
		ELSE
			''Truck''
    END AS ShipMode,
	CAST(laneeff AS date) AS LaneEff,
    CAST(laneexp AS date) AS LaneExp,
	CAST(awardeff as date) AS AwardEff,
    CAST(awardexp as date) AS AwardExp,
    CAST (efct_dt AS date) AS RateEff,
    CAST (expd_dt AS date) AS rateExp,
	CAST(tbllaneaudit.comments AS VARCHAR(1000)) AS LaneComments,
    CAST(tblawards.comments AS VARCHAR(1000)) AS AwardComments,
    reason
FROM
    nai2padm.tbllanes tbllanes
    INNER JOIN nai2padm.tbllaneaudit tbllaneaudit ON nai2padm.tbllanes.laneid = nai2padm.tbllaneaudit.laneid
    INNER JOIN nai2padm.tblawards tblawards ON nai2padm.tbllanes.laneid = nai2padm.tblawards.laneid
    INNER JOIN nai2padm.tbltmrates tbltmrates ON nai2padm.tbllanes.laneid = nai2padm.tbltmrates.laneid
    INNER JOIN nai2padm.tblcarriers tblcarriers ON nai2padm.tblawards.scac = nai2padm.tblcarriers.scac
                                       AND nai2padm.tblawards.scac = nai2padm.tblcarriers.scac
                                       AND nai2padm.tblawards.scac = nai2padm.tbltmrates.scac
WHERE
    tblawards.awardpct > 0
    AND tbllanes.laneid > 0
ORDER BY originzone, destzone, service ASC')

/*
Update ##tblActualLoadDetailsALD CARR_CD / NAME
*/
ALTER TABLE ##tblAwards DROP COLUMN IF EXISTS CARR_CD
ALTER TABLE ##tblAwards DROP COLUMN IF EXISTS NAME
ALTER TABLE ##tblAwards ADD CARR_CD NVARCHAR(50)
ALTER TABLE ##tblAwards ADD NAME NVARCHAR(50)

/*
Create temp table for Current Awards
*/
DROP TABLE IF EXISTS ##tblCurrentAwards
select * into ##tblCurrentAwards 
from ##tblawards
where laneexp >= getdate()
and awardexp >= getdate()
and rateexp >= getdate()
order by originzone, destzone, service ASC

/*
Create temp table for historic lane level awards
*/
DROP TABLE IF EXISTS ##tblLaneAwards
SELECT DISTINCT ORIGINZONE, DESTZONE, ORIGINZONE +'-'+DESTZONE as Lane, Min(RATEEFF) as EffectiveDate, MAX(RATEEXP) as ExpirationDate
INTO ##tblLaneAwards
FROM ##tblAwards
GROUP BY ORIGINZONE, DESTZONE, ORIGINZONE +'-'+DESTZONE
ORDER BY ORIGINZONE +'-'+DESTZONE ASC

/*
Update ##tblActualLoadDetailsALD with AwardLane and AwardCarrier
*/
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS AwardLane
ALTER TABLE ##tblActualLoadDetailsALD DROP COLUMN IF EXISTS AwardCarrier
ALTER TABLE ##tblActualLoadDetailsALD ADD AwardLane NVARCHAR(1)
ALTER TABLE ##tblActualLoadDetailsALD ADD AwardCarrier NVARCHAR(1)

/*
Create table for unique origin/destination by CityName from Thomas' Oracle tables
*/
DROP TABLE IF EXISTS ##tblLaneOrigDest
Select * into ##tblLaneOrigDest from OPENQUERY(NAJDAQAX,'
SELECT DISTINCT
    code,
    cityname,
    upper(order_type) AS type,
    origdest
FROM
    (
        SELECT DISTINCT
            orig_city_state   AS code,
            origin            AS cityname,
            order_type,
            ''ORIGIN'' AS origdest
        FROM
            nai2padm.tbllanes
        UNION ALL
        SELECT DISTINCT
            dest_city_state   AS code,
            dest              AS cityname,
            order_type,
            ''DEST'' AS origdest
        FROM
            nai2padm.tbllanes
    )
ORDER BY
    cityname ASC')

/*
Update ORIGIN_ZONE if it's null to match origdest
SELECT * FROM ##tblLaneOrigDest 
SELECT * FROM ##tblActualLoadDetailsALD where ORIGIN_ZONE is null
*/
UPDATE ##tblActualLoadDetailsALD
SET ORIGIN_ZONE = lod.CODE
FROM ##tblActualLoadDetailsALD ald
INNER JOIN ##tblLaneOrigDest lod ON ald.frst_cty_name +', '+ ald.frst_STA_CD = lod.CITYNAME
WHERE ald.ORIGIN_ZONE is null
AND lod.ORIGDEST = 'ORIGIN'

/*
If, for some unknown reason, the ORIGIN_ZONE is STILL null, update to the Frst_Cty_name
*/
UPDATE ##tblActualLoadDetailsALD
SET ORIGIN_ZONE = FRST_CTY_NAME
WHERE ORIGIN_ZONE is null and Lane is null

/*
Special Cause updating where city names don't match between the tables
SELECT * FROM ##tblActualLoadDetailsALD WHERE last_cty_name +', '+ last_STA_CD = 'NUEVO NOGALES, SO'
*/
UPDATE ##tblActualLoadDetailsALD
SET DEST_ZONE = CASE 
WHEN last_cty_name +', '+ last_STA_CD = 'NUEVO NOGALES, SO' THEN 'SONOGALE' 
WHEN last_cty_name +', '+ last_STA_CD = 'SAINT JOHN, NB' THEN 'NBSTJOHN'
WHEN last_cty_name +', '+ last_STA_CD = 'ST. JOHNS, NL' THEN 'NLSTJOHN' 
ELSE DEST_ZONE END

/*
If the LAST_CTRY_CD <> 'USA', update to the CTRY_CD String
SELECT * FROM ##tblLaneOrigDest where CITYNAME = 'MILTON, ON' and ORIGDEST = 'DEST'

UPDATE ##tblActualLoadDetailsALD 
SET DEST_ZONE = Null, LANE = Null
*/
UPDATE ##tblActualLoadDetailsALD 
SET DEST_ZONE = lod.CODE, LANE = ORIGIN_ZONE + '-' + lod.Code
FROM ##tblActualLoadDetailsALD ald
INNER JOIN ##tblLaneOrigDest lod ON ald.last_cty_name +', '+ ald.last_STA_CD = lod.CITYNAME
WHERE lod.ORIGDEST = 'DEST'
AND ald.LANE is null
AND ald.LAST_CTRY_CD <> 'USA'

/*
If the LAST_CTRY_CD <> 'USA', update to the CTRY_CD String, in case there's an origin that matches
*/
UPDATE ##tblActualLoadDetailsALD 
SET DEST_ZONE = lod.CODE, LANE = ORIGIN_ZONE + '-' + lod.Code
FROM ##tblActualLoadDetailsALD ald
INNER JOIN ##tblLaneOrigDest lod ON ald.last_cty_name +', '+ ald.last_STA_CD = lod.CITYNAME
WHERE lod.ORIGDEST = 'ORIGIN'
AND ald.LANE is null
AND ald.LAST_CTRY_CD <> 'USA'

/*
Update ##tblActualLoadDetailsALD DEST_ZONE / LANE if match to 5 digit zip
SELECT * FROM ##tblAwards
SELECT * FROM ##tblLaneOrigDest order by cityname asc
SELECT * FROM ##tblActualLoadDetailsALD WHERE LAST_CTRY_CD <> 'USA' and Lane is null

Select distinct last_cty_name +', '+ last_STA_CD FROM ##tblActualLoadDetailsALD WHERE LANE IS NULL ORDER BY last_cty_name +', '+ last_STA_CD ASC
SELECT * FROM ##tblLaneOrigDest order by cityname asc

*/
UPDATE ##tblActualLoadDetailsALD 
SET DEST_ZONE = lod.CODE, LANE = ORIGIN_ZONE + '-' + lod.Code
FROM ##tblActualLoadDetailsALD ald
INNER JOIN ##tblLaneOrigDest lod ON ald.last_cty_name +', '+ ald.last_STA_CD = lod.CITYNAME
AND lod.CODE = '5'+ald.last_sta_cd+left(last_pstl_cd,5)
WHERE lod.ORIGDEST = 'DEST'
AND ald.LANE is null
AND ald.LAST_CTRY_CD = 'USA'

/*
Update ##tblActualLoadDetailsALD DEST_ZONE / LANE if match to 3 digit zip
*/
UPDATE ##tblActualLoadDetailsALD 
SET DEST_ZONE = lod.CODE, LANE = ORIGIN_ZONE + '-' + lod.Code
FROM ##tblActualLoadDetailsALD ald
INNER JOIN ##tblLaneOrigDest lod ON ald.last_cty_name +', '+ ald.last_STA_CD = lod.CITYNAME
AND lod.CODE = 'US-'+ald.last_sta_cd+left(last_pstl_cd,3)
WHERE lod.ORIGDEST = 'DEST'
AND ald.LANE is null
AND ald.LAST_CTRY_CD = 'USA'

/*
If the DEST_ZONE / LANE is STILL null, update to the 5 digit, because there's just no hope at all for it
*/
UPDATE ##tblActualLoadDetailsALD
SET DEST_ZONE = '5'+last_sta_cd+left(last_pstl_cd,5), lane = ORIGIN_ZONE + '-' + '5'+last_sta_cd+left(last_pstl_cd,5)
WHERE DEST_ZONE is null
AND LANE is null
AND LAST_CTRY_CD = 'USA'

/*
Final lane string updating, if orig_zone / dest_zone are not null
*/
UPDATE ##tblActualLoadDetailsALD
SET Lane = ORIGIN_ZONE + '-' + DEST_ZONE
WHERE ORIGIN_ZONE is not null
AND DEST_ZONE is not null
AND LANE is null

/*
Update ##tblActualLoadDetailsALD.AwardLane to 'Y' if load was on an Award Lane
*/
UPDATE ##tblActualLoadDetailsALD
SET AwardLane = 'Y'
FROM ##tblActualLoadDetailsALD ald
INNER JOIN ##tblLaneAwards la on la.lane = ald.lane
WHERE SHPD_DTT BETWEEN la.EffectiveDate and la.ExpirationDate

/*
Update ##tblActualLoadDetailsALD.AwardCarrier to 'Y' if load was on an Award Lane and Award.Carrier

Select * from ##tblAwards where LANE = 'SCGREER-5UT84404'
*/
UPDATE ##tblActualLoadDetailsALD
SET AwardCarrier = 'Y'
FROM ##tblActualLoadDetailsALD ald
INNER JOIN ##tblAwards awards on awards.lane = ald.lane
AND awards.service = CASE WHEN ald.srvc_cd = 'OPEN' then ald.CARR_CD ELSE ald.SRVC_CD END
WHERE SHPD_DTT BETWEEN awards.RATEEFF and awards.RATEEXP

/*
Set current time variable
*/
DECLARE @now AS DATETIME
SET @now = GETDATE()

/*
Update All Fields on USCTTDEV.dbo.tblActualLoadDetail to match ##tblActualLoadDetailsALD
*/
UPDATE USCTTDEV.dbo.tblActualLoadDetail
SET CARR_CD = aldt.CARR_CD,
NAME = aldt.NAME,
SRVC_CD = aldt.SRVC_CD,
SRVC_DESC = aldt.SRVC_DESC,
CUR_OPTLSTAT_ID = aldt.CUR_OPTLSTAT_ID,
STATUS = aldt.STATUS,
SHPD_DTT = aldt.SHPD_DTT,
STRD_DTT = aldt.STRD_DTT,
FRST_SHPG_LOC_CD = aldt.FRST_SHPG_LOC_CD,
FRST_SHPG_LOC_NAME = aldt.FRST_SHPG_LOC_NAME,
FRST_CTY_NAME = aldt.FRST_CTY_NAME,
FRST_STA_CD = aldt.FRST_STA_CD,
FRST_PSTL_CD = aldt.FRST_PSTL_CD,
FRST_CTRY_CD = aldt.FRST_CTRY_CD,
LAST_SHPG_LOC_CD = aldt.LAST_SHPG_LOC_CD,
LAST_SHPG_LOC_NAME = aldt.LAST_SHPG_LOC_NAME,
LAST_CTY_NAME = aldt.LAST_CTY_NAME,
LAST_STA_CD = aldt.LAST_STA_CD,
LAST_PSTL_CD = aldt.LAST_PSTL_CD,
LAST_CTRY_CD = aldt.LAST_CTRY_CD,
EQMT_TYP = aldt.EQMT_TYP,
FIXD_ITNR_DIST = aldt.FIXD_ITNR_DIST,
TOT_TOT_PCE = aldt.TOT_TOT_PCE,
TOT_SCLD_WGT = aldt.TOT_SCLD_WGT,
TOT_VOL = aldt.TOT_VOL,
ACTL_CHGD_AMT_DLR = aldt.ACTL_CHGD_AMT_DLR,
CORP1_ID = aldt.CORP1_ID,
MARKETPLACE_CATCHALL = aldt.MARKETPLACE_CATCHALL,
STOPS = aldt.STOPS,
SHIP_CONDITION = aldt.SHIP_CONDITION,
PreRate_Accessorials = aldt.PreRate_Accessorials,
PreRate_Fuel = aldt.PreRate_Fuel,
PreRate_Linehaul = aldt.PreRate_Linehaul,
PreRate_Repo = aldt.PreRate_Repo,
PreRate_ZUSB = aldt.PreRate_ZUSB,
PreRateCharge = aldt.PreRateCharge,
Act_Accessorials = aldt.Act_Accessorials,
Act_Fuel = aldt.Act_Fuel,
Act_Linehaul = aldt.Act_Linehaul,
Act_Repo = aldt.Act_Repo,
Act_ZUSB = aldt.Act_ZUSB,
ActualRateCharge = aldt.ActualRateCharge,
Drop_It = aldt.Drop_It,
OrderType = aldt.OrderType,
CarrierManager = aldt.CarrierManager,
Region = aldt.Region,
BU = aldt.BU,
ShipMode = aldt.ShipMode,
Year = aldt.Year,
Month = aldt.Month,
Week_Beginning = aldt.Week_Beginning,
Origin_Zone = aldt.Origin_Zone,
Dest_Zone = aldt.Dest_Zone,
Lane = aldt.Lane,
OriginPlant = aldt.OriginPlant,
DestinationPlant = aldt.DestinationPlant,
CustomerHierarchy = aldt.CustomerHierarchy,
CustomerGroup = aldt.CustomerGroup,
ConsumerWeight = aldt.ConsumerWeight,
KCPWeight = aldt.KCPWeight,
NonWovenWeight = aldt.NonWovenWeight,
UnknownWeight = aldt.UnknownWeight,
ConsumerVolume = aldt.ConsumerVolume,
KCPVolume = aldt.KCPVolume,
NonWovenVolume = aldt.NonWovenVolume,
UnknownVolume = aldt.UnknownVolume,
OrderCount = aldt.OrderCount,
BUCount = aldt.BUCount,
TotalWeight = aldt.TotalWeight,
TotalVolume = aldt.TotalVolume,
TotalCost = aldt.TotalCost,
ConsumerTotalCost = aldt.ConsumerTotalCost,
ConsumerLinehaulCost = aldt.ConsumerLinehaulCost,
ConsumerFuelCost = aldt.ConsumerFuelCost,
ConsumerAccessorialsCost = aldt.ConsumerAccessorialsCost,
KCPTotalCost = aldt.KCPTotalCost,
KCPLinehaulCost = aldt.KCPLinehaulCost,
KCPFuelCost = aldt.KCPFuelCost,
KCPAccessorialsCost = aldt.KCPAccessorialsCost,
NonWovenTotalCost = aldt.NonWovenTotalCost,
NonWovenLinehaulCost = aldt.NonWovenLinehaulCost,
NonWovenFuelCost = aldt.NonWovenFuelCost,
NonWovenAccessorialsCost = aldt.NonWovenAccessorialsCost,
UnknownTotalCost = aldt.UnknownTotalCost,
UnknownLinehaulCost = aldt.UnknownLinehaulCost,
UnknownFuelCost = aldt.UnknownFuelCost,
UnknownAccessorialsCost = aldt.UnknownAccessorialsCost,
FRAN = aldt.FRAN,
RFT = aldt.RFT,
AwardLane = aldt.AwardLane,
AwardCarrier = aldt.AwardCarrier,
LastUpdated = @now
FROM USCTTDEV.dbo.tblActualLoadDetail ald
INNER JOIN ##tblActualLoadDetailsALD aldt ON CAST(ald.LD_LEG_ID AS INT) = CAST(aldt.LD_LEG_ID AS INT)

/*
Delete from temp table, which will leave only lines that need to be appended
SELECT * INTO ##tblActualLoadDetailsALDBackup FROM (SELECT * FROM ##tblActualLoadDetailsALD) DATA
DROP TABLE IF EXISTS ##tblActualLoadDetailsALD
SELECT * FROM ##tblActualLoadDetailsALD
SELECT * INTO ##tblActualLoadDetailsALD FROM (SELECT * FROM ##tblActualLoadDetailsALDBackup) DATA
*/
DELETE ##tblActualLoadDetailsALD
FROM ##tblActualLoadDetailsALD aldt
INNER JOIN USCTTDEV.dbo.tblActualLoadDetail ald ON CAST(aldt.LD_LEG_ID AS INT) = CAST(ald.LD_LEG_ID AS INT)
WHERE aldt.LD_LEG_ID = ald.LD_LEG_ID

/*
Append leftover records to USCTTDEV.dbo.tblActualLoadDetail
*/
INSERT INTO USCTTDEV.dbo.tblActualLoadDetail
(CARR_CD,
NAME,
SRVC_CD,
SRVC_DESC,
CUR_OPTLSTAT_ID,
STATUS,
SHPD_DTT,
STRD_DTT,
LD_LEG_ID,
FRST_SHPG_LOC_CD,
FRST_SHPG_LOC_NAME,
FRST_CTY_NAME,
FRST_STA_CD,
FRST_PSTL_CD,
FRST_CTRY_CD,
LAST_SHPG_LOC_CD,
LAST_SHPG_LOC_NAME,
LAST_CTY_NAME,
LAST_STA_CD,
LAST_PSTL_CD,
LAST_CTRY_CD,
EQMT_TYP,
FIXD_ITNR_DIST,
TOT_TOT_PCE,
TOT_SCLD_WGT,
TOT_VOL,
ACTL_CHGD_AMT_DLR,
CORP1_ID,
MARKETPLACE_CATCHALL,
STOPS,
SHIP_CONDITION,
PreRate_Accessorials,
PreRate_Fuel,
PreRate_Linehaul,
PreRate_Repo,
PreRate_ZUSB,
PreRateCharge,
Act_Accessorials,
Act_Fuel,
Act_Linehaul,
Act_Repo,
Act_ZUSB,
ActualRateCharge,
Drop_It,
OrderType,
CarrierManager,
Region,
BU,
ShipMode,
Year,
Month,
Week_Beginning,
Origin_Zone,
Dest_Zone,
Lane,
OriginPlant,
DestinationPlant,
CustomerHierarchy,
CustomerGroup,
ConsumerWeight,
KCPWeight,
NonWovenWeight,
UnknownWeight,
ConsumerVolume,
KCPVolume,
NonWovenVolume,
UnknownVolume,
OrderCount,
BUCount,
TotalWeight,
TotalVolume,
TotalCost,
ConsumerTotalCost,
ConsumerLinehaulCost,
ConsumerFuelCost,
ConsumerAccessorialsCost,
KCPTotalCost,
KCPLinehaulCost,
KCPFuelCost,
KCPAccessorialsCost,
NonWovenTotalCost,
NonWovenLinehaulCost,
NonWovenFuelCost,
NonWovenAccessorialsCost,
UnknownTotalCost,
UnknownLinehaulCost,
UnknownFuelCost,
UnknownAccessorialsCost,
FRAN,
RFT,
AwardLane,
AwardCarrier,
AddedOn,
LastUpdated)
SELECT aldt.CARR_CD,
aldt.NAME,
aldt.SRVC_CD,
aldt.SRVC_DESC,
aldt.CUR_OPTLSTAT_ID,
aldt.STATUS,
aldt.SHPD_DTT,
aldt.STRD_DTT,
aldt.LD_LEG_ID,
aldt.FRST_SHPG_LOC_CD,
aldt.FRST_SHPG_LOC_NAME,
aldt.FRST_CTY_NAME,
aldt.FRST_STA_CD,
aldt.FRST_PSTL_CD,
aldt.FRST_CTRY_CD,
aldt.LAST_SHPG_LOC_CD,
aldt.LAST_SHPG_LOC_NAME,
aldt.LAST_CTY_NAME,
aldt.LAST_STA_CD,
aldt.LAST_PSTL_CD,
aldt.LAST_CTRY_CD,
aldt.EQMT_TYP,
aldt.FIXD_ITNR_DIST,
aldt.TOT_TOT_PCE,
aldt.TOT_SCLD_WGT,
aldt.TOT_VOL,
aldt.ACTL_CHGD_AMT_DLR,
aldt.CORP1_ID,
aldt.MARKETPLACE_CATCHALL,
aldt.STOPS,
aldt.SHIP_CONDITION,
aldt.PreRate_Accessorials,
aldt.PreRate_Fuel,
aldt.PreRate_Linehaul,
aldt.PreRate_Repo,
aldt.PreRate_ZUSB,
aldt.PreRateCharge,
aldt.Act_Accessorials,
aldt.Act_Fuel,
aldt.Act_Linehaul,
aldt.Act_Repo,
aldt.Act_ZUSB,
aldt.ActualRateCharge,
aldt.Drop_It,
aldt.OrderType,
aldt.CarrierManager,
aldt.Region,
aldt.BU,
aldt.ShipMode,
aldt.Year,
aldt.Month,
aldt.Week_Beginning,
aldt.Origin_Zone,
aldt.Dest_Zone,
aldt.Lane,
aldt.OriginPlant,
aldt.DestinationPlant,
aldt.CustomerHierarchy,
aldt.CustomerGroup,
aldt.ConsumerWeight,
aldt.KCPWeight,
aldt.NonWovenWeight,
aldt.UnknownWeight,
aldt.ConsumerVolume,
aldt.KCPVolume,
aldt.NonWovenVolume,
aldt.UnknownVolume,
aldt.OrderCount,
aldt.BUCount,
aldt.TotalWeight,
aldt.TotalVolume,
aldt.TotalCost,
aldt.ConsumerTotalCost,
aldt.ConsumerLinehaulCost,
aldt.ConsumerFuelCost,
aldt.ConsumerAccessorialsCost,
aldt.KCPTotalCost,
aldt.KCPLinehaulCost,
aldt.KCPFuelCost,
aldt.KCPAccessorialsCost,
aldt.NonWovenTotalCost,
aldt.NonWovenLinehaulCost,
aldt.NonWovenFuelCost,
aldt.NonWovenAccessorialsCost,
aldt.UnknownTotalCost,
aldt.UnknownLinehaulCost,
aldt.UnknownFuelCost,
aldt.UnknownAccessorialsCost,
aldt.FRAN,
aldt.RFT,
aldt.AwardLane,
aldt.AwardCarrier,
@now,
@now
FROM ##tblActualLoadDetailsALD aldt
LEFT JOIN USCTTDEV.dbo.tblActualLoadDetail ald ON aldt.LD_LEG_ID = ald.LD_LEG_ID
WHERE ald.LD_LEG_ID IS NULL
ORDER BY LD_LEG_ID ASC

/*
Update Actual Load Details with new city names, when there's something weird
*/
UPDATE USCTTDEV.dbo.tblActualLoadDetail
SET DestCity =
              CASE
                WHEN zc.ZONE IS NOT NULL AND
                  zc.CityName IS NOT NULL THEN zc.UpdatedCityName
                ELSE ald.LAST_CTY_NAME
              END
FROM USCTTDEV.dbo.tblActualLoadDetail ald
LEFT JOIN USCTTDEV.dbo.tblZoneCities zc
  ON zc.Zone = ald.Dest_Zone
  AND zc.CityName = ald.LAST_CTY_NAME

/*
Update Actual Load Detail Broker Flag
*/
UPDATE USCTTDEV.dbo.tblActualLoadDetail
SET Broker = ca.Broker
FROM USCTTDEV.dbo.tblActualLoadDetail ald
INNER JOIN USCTTDEV.dbo.tblCarriers ca
  ON ca.SRVC_DESC = ald.SRVC_DESC
WHERE CONVERT(date, ald.LastUpdated) =
CONVERT(date, GETDATE())

/*
Update tblBidAppLanes with current year's volume
*/
UPDATE USCTTDEV.dbo.tblBidAppLanes
SET CurrentVolume = CASE WHEN vol.lane IS NULL THEN NULL ELSE vol.CurrentVol END
FROM USCTTDEV.dbo.tblBidAppLanes bal
LEFT JOIN (SELECT DISTINCT
  ald.Origin_Zone,
  ald.Dest_Zone,
  CASE
    WHEN ald.EQMT_TYP LIKE '%TC' THEN ald.Origin_Zone + '-' + ald.Dest_Zone + '(TC)'
    ELSE ald.Origin_Zone + '-' + ald.Dest_Zone
  END AS Lane,
  COUNT(DISTINCT ald.LD_LEG_ID) AS CurrentVol
FROM USCTTDEV.dbo.tblActualLoadDetail ald
WHERE YEAR((CASE
  WHEN ald.SHPD_DTT IS NULL THEN ald.STRD_DTT
  ELSE ald.SHPD_DTT
END)) = YEAR(GETDATE())
AND ald.CUR_OPTLSTAT_ID BETWEEN 300 and 345
AND ald.ShipMode <> 'LTL'
GROUP BY ald.Origin_Zone,
         ald.Dest_Zone,
         CASE
           WHEN ald.EQMT_TYP LIKE '%TC' THEN ald.Origin_Zone + '-' + ald.Dest_Zone + '(TC)'
           ELSE ald.Origin_Zone + '-' + ald.Dest_Zone
         END) vol ON vol.Lane = bal.Lane

/*
Update Bid App Rates with current year's volume
*/
UPDATE USCTTDEV.dbo.tblBidAppRates
SET CurrentVolume = CASE WHEN vol.Lane IS NULL THEN NULL ELSE vol.CurrentVol END
FROM USCTTDEV.dbo.tblBidAppRates bar
LEFT JOIN(
SELECT DISTINCT
  ald.Origin_Zone,
  ald.Dest_Zone,
  ald.SRVC_CD,
  CASE
    WHEN ald.EQMT_TYP LIKE '%TC' THEN ald.Origin_Zone + '-' + ald.Dest_Zone + '(TC)'
    ELSE ald.Origin_Zone + '-' + ald.Dest_Zone
  END AS Lane,
  COUNT(DISTINCT ald.LD_LEG_ID) AS CurrentVol
FROM USCTTDEV.dbo.tblActualLoadDetail ald
WHERE YEAR((CASE
  WHEN ald.SHPD_DTT IS NULL THEN ald.STRD_DTT
  ELSE ald.SHPD_DTT
END)) = YEAR(GETDATE())
AND ald.CUR_OPTLSTAT_ID BETWEEN 300 and 345
AND ald.ShipMode <> 'LTL'
GROUP BY ald.Origin_Zone,
         ald.Dest_Zone,
		 ald.SRVC_CD,
         CASE
           WHEN ald.EQMT_TYP LIKE '%TC' THEN ald.Origin_Zone + '-' + ald.Dest_Zone + '(TC)'
           ELSE ald.Origin_Zone + '-' + ald.Dest_Zone END
		   ) vol on vol.Lane = bar.Lane AND vol.SRVC_CD = bar.SCAC

/*
Update USCTTDEV.dbo.tblActualLoadDetail
Where the EQMT_TYP is Intermodal, but the distance is less than 600
since it's probably an Intermodal equipment but actually used OTR
*/
UPDATE USCTTDEV.dbo.tblActualLoadDetail
SET SHIPMODE = 'TRUCK'
WHERE EQMT_TYP = '53IM'
AND FIXD_ITNR_DIST < 600
AND SHIPMODE = 'INTERMODAL'

/*
Updates for KC Romeoville Origin Zone
*/
UPDATE USCTTDEV.dbo.tblActualLoadDetail
SET Origin_Zone = CASE
                WHEN SUBSTRING(ald.FRST_SHPG_LOC_CD, 1, 4) IN (
                    '2358',
                    '2292'
                ) THEN
                    'KCILROME-NOF'
                WHEN SUBSTRING(ald.FRST_SHPG_LOC_CD, 1, 4) = '2323' THEN
                    'KCILROME-KCP'
                WHEN SUBSTRING(ald.FRST_SHPG_LOC_CD, 1, 4) = '2474' THEN
                    'KCILROME-SKIN'
                ELSE
                    ald.Origin_Zone
            END
FROM USCTTDEV.dbo.tblActualLoadDetail ald
WHERE SUBSTRING(ald.FRST_SHPG_LOC_CD, 1, 4) IN ('2292','2323','2358','2474')
AND ald.Origin_Zone = 'ILROMEOV'

/*
Don't really need to do this, but I do it anyway because I like clean temp tables
*/
DROP TABLE IF EXISTS
##tblActualBusinessUnits,
##tblActualLoadDetailsALD,
##tblActualLoadDetailsPRLD,
##tblActualLoadDetailsRaw,
##tblActualRateLoadDetailsPivot,
##tblActualRateLoadDetailsRaw,
##tblAwards,
##tblLaneOrigDest,
##tblBUWeightRaw,
##tblBUWeightPivot,
##tblCurrentAwards,
##tblLaneAwards,
##tblPreRateLoadDetailsPivot,
##tblPreRateLoadDetailsRaw,
##tblTMSMasterZones
;


/*
SELECT LD_LEG_ID, BU, CONSUMERVolume, KCPVolume, NonWovenVolume, UnknownVolume, BUCount FROM ##tblActualLoadDetailsALD WHERE BUCount >1
select * FROM ##tblActualLoadDetailsALD WHERE UNKNOWNVOLUME IS NOT NULL
SELECT * FROM USCTTDEV.dbo.tblActualLoadDetail ORDER BY ID ASC
	SELECT * FROM ##tblBUWeightRaw WHERE LD_LEG_ID = 517072170
SELECT * FROM ##tblActualBusinessUnits WHERE LD_LEG_ID = 517072170
SELECT * FROM ##tblBUWeightPivot WHERE LD_LEG_ID = 517072170
SELECT * FROM ##tblActualLoadDetailsALD WHERE LD_LEG_ID = 517072170
*/
END
