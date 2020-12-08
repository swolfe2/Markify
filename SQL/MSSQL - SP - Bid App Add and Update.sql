USE [USCTTDEV]
GO
/****** Object:  StoredProcedure [dbo].[sp_BidAppAddAndUpdate]    Script Date: 12/8/2020 12:21:27 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Steve Wolfe, steve.wolfe@kcc.com, Central Transportation Team
-- Create date: 3/25/2020
-- Last modified: 12/8/2020
-- 12/8/2020 - SW - Update the Dest City/State to match Actual Load Detail by the lane if different and available; else by the Dest Zone if different and available (email thread with John Hook), and insert into changelog
-- 9/11/2020 - SW -Update [Order Type] to match the one most used on USCTTDEV.dbo.tblActualLoadDetail if it's different than what's on tblBidAppLanes
-- 6/5/2020 - SW - Updates to logic to exclude ZAR-% Rates
-- Description:	Add new rates to Bid App tables, and update Bid App tables if rates are different
-- =============================================

ALTER PROCEDURE [dbo].[sp_BidAppAddAndUpdate]

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

/*
What does this procedure do?
1) Create temp table of all TM rates, where the Effective Date is <= todays date OR the Year of the Effective Date is this year
2) Compare rates against the Bid App Lanes table
3) If a lane exists in the TM Rates table, but not in the Bid App table, add to USCTTDEV.dbo.tblBidAppLanes
4) If a lane exists in the TM Rates table, but the rate is not in the Bid App Rates table, add to USCTTDEV.dbo.tblBidAppRates
5) If the rate from TM does not match the rate in USCTTDEV.dbo.tblBidAppRates, update with the new rate
6) Send HTML Formatted email to people who need to be aware of Bid App Updates
*/

/*
Make sure any previous temp tables are deleted
*/
DROP TABLE IF EXISTS ##tblTMRPMForBidApp,
##tblBidAppMissingLanes,
##tblBIdAppMissingRates,
##tblBidAppRateDifferences,
##tblChangelogTemp,
##tblChangelogTempFinal,
##tblLaneAAOTemp,
##tblCityStateTemp,
##tblBidAppDestUpdate/*,
##tblBidAppMissingRates,
##tblBidAppRateDifferences,
##tblChangelogTemp,
##tblChangelogTempFinal,
*/

/*
Create temp table for TM Rates
This is for lanes which are marked as 'MILE' or 'ZTEM'

SELECT * FROM ##tblTMRPMForBidApp WHERE [Origin City] like '%(%'
SELECT * FROM ##tblTMRPMForBidApp
*/

SELECT DISTINCT * INTO ##tblTMRPMForBidApp FROM OPENQUERY(NAJDAPRD,'SELECT
    *
FROM
    (
        SELECT DISTINCT
            t.carr_cd        AS Carrier,
            c.name           AS "Carrier Name",
            l.srvc_cd        AS Service,
            mst.srvc_desc    AS "Service Description",
            CASE
                WHEN upper(mst.srvc_desc) LIKE ''%INTERMODAL%'' THEN
                    ''INTERMODAL''
                WHEN upper(mst.srvc_desc) LIKE ''%TRAIN%'' THEN
                    ''INTERMODAL''
                WHEN upper(mst.srvc_desc) LIKE ''%TOFC%'' THEN
                    ''INTERMODAL''
                WHEN upper(mst.srvc_desc) LIKE ''%INTERMILL%'' THEN
                    ''INTERMODAL''
                ELSE
                    ''TRUCK''
            END AS shipmode,
            l.orig_zn_cd     AS "Origin Zone Code",
            org.zn_desc      AS "Origin City",
			org.ctry_cd		 AS "Origin Country",
            l.dest_zn_cd     AS "Dest Zone Code",
            dest.zn_desc     AS "Dest State/ZIP",
			dest.ctry_cd     AS "Dest Country",
            r.efct_dt        AS "TM Effective Date",
            r.expd_dt        AS "TM Expiration Date",
            rr.brk_amt_dlr   AS "Rate Per Mile",
            r.min_chrg_dlr   AS "Min Charge",
			r.bs_chrg_dlr    AS "BS Charge",
            r.chrg_cd        AS "Charge Code",
            RANK() OVER(
                PARTITION BY l.orig_zn_cd, l.dest_zn_cd
                ORDER BY
                    rr.brk_amt_dlr ASC, l.min_chrg_dlr ASC, l.tff_id ASC
            ) AS Rank,
            l.tff_id         AS "Tariff ID",
            t.tff_cd         AS "Tariff Code",
            r.rate_cd        AS "Rate Code",
            r.rate_id        AS "Rate ID",
            current_date     AS "Last Refreshed"
        FROM
            najdaadm.tff_t         t
            LEFT JOIN najdaadm.lane_assc_t   l ON l.tff_id = t.tff_id
            LEFT JOIN najdaadm.rate_t        r ON l.tff_id = r.tff_id
                                            AND l.rate_cd = r.rate_cd
            LEFT JOIN najdaadm.rng_rate_t    rr ON rr.rate_id = r.rate_id
            LEFT JOIN najdaadm.zone_r        org ON l.orig_zn_cd = org.zn_cd
            LEFT JOIN najdaadm.zone_r        dest ON l.dest_zn_cd = dest.zn_cd
            LEFT JOIN najdaadm.carrier_r     c ON t.carr_cd = c.carr_cd
            LEFT JOIN najdaadm.mstr_srvc_t   mst ON l.srvc_cd = mst.srvc_cd
        WHERE
            (r.efct_dt <= SYSDATE OR EXTRACT(YEAR FROM r.efct_dt) = EXTRACT(YEAR FROM SYSDATE))
			AND r.expd_dt >= SYSDATE
            /*AND rr.brk_amt_dlr >.01*/
            AND (r.chrg_cd = ''MILE'' OR CHRG_CD = ''ZTEM'')
            /*AND l.orig_zn_cd || ''-'' || l.dest_zn_cd LIKE ''%WIOSHKOS-5CA92831%''
            AND upper(mst.srvc_desc) NOT LIKE ''%INTERMODAL%''
            AND upper(mst.srvc_desc) NOT LIKE ''%TRAIN%''
            AND upper(mst.srvc_desc) NOT LIKE ''%TOFC%''
            AND upper(mst.srvc_desc) NOT LIKE ''%INTERMILL%''*/
			AND (substr(l.orig_zn_cd,1,1) <> ''9'' AND substr(l.orig_zn_cd,1,1) <> ''5'' AND l.orig_zn_cd NOT IN (''ALLUSA'',''ALLMEX'',''ALLCAN'') AND l.orig_zn_cd NOT LIKE ''US-%'' AND l.orig_zn_cd NOT LIKE ''5-%'' AND l.orig_zn_cd NOT LIKE ''ZAR-%''  AND l.orig_zn_cd NOT LIKE ''REGION%'')
			AND (substr(l.dest_zn_cd,1,1) <> ''9'' AND l.dest_zn_cd NOT IN (''ALLUSA'',''ALLMEX'',''ALLCAN'') AND l.dest_zn_cd NOT LIKE ''US-%'' AND l.dest_zn_cd NOT LIKE ''6%'' AND l.dest_zn_cd NOT LIKE ''REGION%'')
    ) rpm 

ORDER BY
    "Origin Zone Code",
    "Dest Zone Code",
    Shipmode,
    Rank,
    Service') RPM

/*
Base table updates to remove incorrect strings
SELECT * FROM ##tblTMRPMForBidApp WHERE [Origin Zone Code] = 'KCILROME-NOF'
SELECT DISTINCT [Origin Zone Code] FROM ##tblTMRPMForBidApp WHERE [Origin Zone Code] LIKE 'KC%'
SELECT DISTINCT [Dest Zone Code] FROM ##tblTMRPMForBidApp WHERE [Dest Zone Code] LIKE 'KC%'
*/
DELETE ##tblTMRPMForBidApp
FROM ##tblTMRPMForBidApp tmba
WHERE [Origin Zone Code] LIKE 'KC%'
AND [Origin Zone Code] NOT LIKE 'KCILROME%'

DELETE ##tblTMRPMForBidApp
FROM ##tblTMRPMForBidApp tmba
WHERE [Dest Zone Code] LIKE 'KC%'
AND [Dest Zone Code] NOT LIKE 'KCILROME%'

DELETE ##tblTMRPMForBidApp
FROM ##tblTMRPMForBidApp
WHERE [Origin Zone Code] LIKE '5%'

DELETE ##tblTMRPMForBidApp
FROM ##tblTMRPMForBidApp
WHERE [Origin Zone Code] LIKE 'ZAR%'

DELETE ##tblTMRPMForBidApp
FROM ##tblTMRPMForBidApp
WHERE [SERVICE] LIKE 'ZAR%'

UPDATE ##tblTMRPMForBidApp
SET [Origin City] = REPLACE([Origin City], 'KC in ','')
WHERE [Origin City] LIKE 'KC in%'

UPDATE ##tblTMRPMForBidApp
SET [Origin City] = REPLACE([Origin City], ' KCP','')
WHERE [Origin City] LIKE '% KCP'

UPDATE ##tblTMRPMForBidApp
SET [Origin City] = REPLACE([Origin City], ' SKIN CARE','')
WHERE [Origin City] LIKE '% SKIN CARE'

UPDATE ##tblTMRPMForBidApp
SET [Origin City] = CASE
						WHEN CHARINDEX(' (', [Origin City]) > 0 THEN
							RTRIM(left([Origin City], CHARINDEX(' (', [Origin City]) - 1))
						ELSE
							[Origin City]
					END

UPDATE ##tblTMRPMForBidApp
SET [Dest State/ZIP] = REPLACE([Dest State/ZIP], 'KC in ','')
WHERE [Dest State/ZIP] LIKE 'KC in%'

UPDATE ##tblTMRPMForBidApp
SET [Dest State/ZIP] = REPLACE([Dest State/ZIP], ' KCP','')
WHERE [Dest State/ZIP] LIKE '% KCP'

UPDATE ##tblTMRPMForBidApp
SET [Dest State/ZIP] = REPLACE([Dest State/ZIP], ' SKIN CARE','')
WHERE [Dest State/ZIP] LIKE '% SKIN CARE'

UPDATE ##tblTMRPMForBidApp
SET [Dest State/ZIP] = CASE
						WHEN CHARINDEX(' (', [Dest State/ZIP]) > 0 THEN
							RTRIM(left([Dest State/ZIP], CHARINDEX(' (', [Dest State/ZIP]) - 1))
						ELSE
							[Dest State/ZIP]
					END
									   					 
UPDATE ##tblTMRPMForBidApp
SET [Origin City] = LTRIM(RTRIM([Origin City])),
[Dest State/ZIP] = LTRIM(RTRIM([Dest State/ZIP]))

/*
Add LaneID column to join against USCTTDEV.dbo.tblBidAppLanes
*/
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'LaneID'		AND TABLE_NAME LIKE '##tblTMRPMForBidApp') ALTER TABLE ##tblTMRPMForBidApp ADD [LaneID]	INT NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'LaneStatus'	AND TABLE_NAME LIKE '##tblTMRPMForBidApp') ALTER TABLE ##tblTMRPMForBidApp ADD LaneStatus	NVARCHAR(50) NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'RateStatus'	AND TABLE_NAME LIKE '##tblTMRPMForBidApp') ALTER TABLE ##tblTMRPMForBidApp ADD RateStatus	NVARCHAR(50) NULL

/*
Update ##tblTMRPMForBidApp with LaneID from USCTTDEV.dbo.tblBidAppLanes
SELECT * FROM USCTTDEV.dbo.tblBidAppLanes where ID <10
SELECT * FROM ##tblTMRPMForBidApp WHERE LaneStatus IS NULL
*/
UPDATE ##tblTMRPMForBidApp
SET LaneID = bal.LaneID,
LaneStatus = 'Exists'
FROM ##tblTMRPMForBidApp tm
INNER JOIN USCTTDEV.dbo.tblBidAppLanes bal ON bal.ORIG_CITY_STATE = tm.[Origin Zone Code]
AND bal.DEST_CITY_STATE = tm.[Dest Zone Code]
WHERE tm.LaneID IS NULL OR tm.LaneID <> bal.LaneID
AND bal.Lane NOT LIKE '%(TC)%'

/*
Create temp table of missing lanes
Where it's not an 'ALL' rate, and the effective date is > today's date
DROP TABLE IF EXISTS ##tblBidAppMissingLanes
SELECT * FROM ##tblBidAppMissingLanes ORDER BY LaneID ASC
*/
SELECT * INTO ##tblBidAppMissingLanes
FROM (
SELECT DISTINCT 
ROW_NUMBER() OVER (ORDER BY tm.[Origin Zone Code]) AS LaneID,
tm.[Origin Zone Code], 
tm.[Origin City],
tm.[Origin Country],
/*CASE
    WHEN CHARINDEX('-', tm.[Dest Zone Code]) > 0 THEN
        RTRIM(left(tm.[Dest Zone Code], CHARINDEX('-', tm.[Dest Zone Code]) - 1))
    ELSE
        tm.[Dest Zone Code]
	END AS 
[Dest Zone Code],*/
tm.[Dest Zone Code],
tm.[Dest Country],
COUNT(*) AS TMRateCount
FROM ##tblTMRPMForBidApp tm
WHERE tm.LaneID IS NULL
/*AND DATEPART(year,tm.[TM Effective Date]) >= DATEPART(year,GETDATE())
AND tm.[TM Expiration Date] > GETDATE()
AND [Dest Zone Code] NOT LIKE '%ALL%'
AND [Origin Zone Code] NOT LIKE '%ALL%'*/
GROUP BY tm.[Origin Zone Code], 
tm.[Origin City],
tm.[Origin Country],
/*CASE
    WHEN CHARINDEX('-', tm.[Dest Zone Code]) > 0 THEN
        RTRIM(left(tm.[Dest Zone Code], CHARINDEX('-', tm.[Dest Zone Code]) - 1))
    ELSE
        tm.[Dest Zone Code]
	END, */
tm.[Dest Zone Code],
tm.[Dest Country]) missing

/*
Update with new Index number, just in CASE the old one was duplicated for some unknown reason

SELECT * FROM ##tblBidAppMissingLanes order by LaneID ASC
*/
UPDATE ##tblBidAppMissingLanes
SET LaneID = row.row
FROM ##tblBidAppMissingLanes baml
INNER JOIN (SELECT ROW_NUMBER() OVER (ORDER BY [Origin Zone Code]+'-'+[Dest Zone Code]) as Row,
[Origin Zone Code]+'-'+[Dest Zone Code] AS Lane FROM ##tblBidAppMissingLanes) row ON row.Lane = baml.[Origin Zone Code]+'-'+baml.[Dest Zone Code]

/*
Update ##tblBidAppMissingLanes.LaneID to 1+Max(USCTTDEV.dbo.tblBidAppLanes.LaneID)
*/
UPDATE ##tblBidAppMissingLanes
SET LaneID = LaneID + (SELECT MAX(LaneID) AS MaxLaneID FROM USCTTDEV.dbo.tblBidAppLanes)

/*
Add LaneID column to join against USCTTDEV.dbo.tblBidAppLanes
SELECT * FROM ##tblBidAppMissingLanes
SELECT * FROM ##tblTMRPMForBidApp
SELECT * FROM USCTTDEV.dbo.tblTMSZones
*/
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'OriginZip'		AND TABLE_NAME LIKE '##tblBidAppMissingLanes')	 ALTER TABLE ##tblBidAppMissingLanes ADD OriginZip		NVARCHAR(100) NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'Dest'			AND TABLE_NAME LIKE '##tblBidAppMissingLanes')	 ALTER TABLE ##tblBidAppMissingLanes ADD Dest			NVARCHAR(100) NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'Order Type'		AND TABLE_NAME LIKE '##tblBidAppMissingLanes')	 ALTER TABLE ##tblBidAppMissingLanes ADD OrderType		NVARCHAR(100) NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'BusinessUnit'	AND TABLE_NAME LIKE '##tblBidAppMissingLanes')	 ALTER TABLE ##tblBidAppMissingLanes ADD BusinessUnit	NVARCHAR(100) NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'LoadCount'		AND TABLE_NAME LIKE '##tblBidAppMissingLanes')	 ALTER TABLE ##tblBidAppMissingLanes ADD [LoadCount]	INT NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'AddedBY'		AND TABLE_NAME LIKE '##tblBidAppMissingLanes')	 ALTER TABLE ##tblBidAppMissingLanes ADD AddedBy		NVARCHAR(100) NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'AddedOn'		AND TABLE_NAME LIKE '##tblBidAppMissingLanes')	 ALTER TABLE ##tblBidAppMissingLanes ADD AddedOn		DATETIME NULL

/*
Update OriginZips from unique Bid App Lanes Origin Zips
*/
UPDATE ##tblBidAppMissingLanes
SET OriginZip = zips.OriginZip
FROM ##tblBidAppMissingLanes baml
INNER JOIN (SELECT DISTINCT bal.ORIG_CITY_STATE, bal.OriginZip FROM USCTTDEV.dbo.tblBidAppLanes bal) zips ON zips.ORIG_CITY_STATE = baml.[Origin Zone Code]
WHERE baml.OriginZip IS NULL

/*
Update ##tblBidAppMissingLanes.LoadCount with counts from USCTTDEV.dbo.tblActualLoadDetail where origin/dest zones match, and shipments are in this year

SELECT * FROM ##tblBidAppMissingLanes ORDER BY [Origin Zone Code] ASC, [Dest Zone Code] ASC
*/
UPDATE ##tblBidAppMissingLanes
SET LoadCount = ald.LoadCount
FROM ##tblBidAppMissingLanes ml
INNER JOIN (
SELECT DISTINCT ald.Origin_Zone, ald.Dest_Zone, COUNT(DISTINCT ald.LD_LEG_ID) AS LoadCount
FROM USCTTDEV.dbo.tblActualLoadDetail ald
WHERE DATEPART(year,CASE WHEN ald.SHPD_DTT IS NULL THEN ald.STRD_DTT ELSE ald.SHPD_DTT END) = DATEPART(year,GETDATE())
GROUP BY ald.Origin_ZOne, ald.Dest_Zone
) ald on ald.Origin_Zone = ml.[Origin Zone Code]
AND ald.Dest_Zone = ml.[Dest Zone Code]

/*
Update null strings to whatever matches in Actual Load Detail, if something matches
Only use which ZIP has the most loads
SELECT * FROM ##tblBidAppMissingLanes
*/
UPDATE ##tblBidAppMissingLanes
SET OriginZip = zips.Zip
FROM ##tblBidAppMissingLanes bal
INNER JOIN (
SELECT Origin, 
ZIP,
LoadCount,
Rank
FROM(
SELECT DISTINCT ald.FRST_CTY_NAME + ', ' +   ald.FRST_STA_CD AS Origin, 
CASE WHEN ald.FRST_CTRY_CD = 'USA' THEN LEFT(ald.FRST_PSTL_CD,5) ELSE ald.FRST_PSTL_CD END AS Zip,
COUNT(*) AS LoadCount,
ROW_NUMBER() OVER (PARTITION BY ald.FRST_CTY_NAME + ', ' +   ald.FRST_STA_CD ORDER BY COUNT(*) DESC) Rank
FROM USCTTDEV.dbo.tblActualLoadDetail ald
GROUP BY ald.FRST_CTY_NAME + ', ' +   ald.FRST_STA_CD,
CASE WHEN ald.FRST_CTRY_CD = 'USA' THEN LEFT(ald.FRST_PSTL_CD,5) ELSE ald.FRST_PSTL_CD END
) data
WHERE data.Rank = 1) zips ON zips.Origin = bal.[Origin City]
WHERE bal.OriginZip IS NULL

/*
Update ##tblMissingBidAppLanes with Dest details
SELECT * FROM ##tblBidAppMissingLanes
SELECT * FROM USCTTDEV.dbo.tblBidAPpLanes where ID <10
*/
UPDATE ##tblBidAppMissingLanes
SET Dest = dests.Dest
FROM ##tblBidAppMissingLanes baml
INNER JOIN (
SELECT DISTINCT Dest, DEST_CITY_STATE
FROM USCTTDEV.dbo.tblBidAppLanes
GROUP BY Dest, DEST_CITY_STATE
) dests ON dests.DEST_CITY_STATE = baml.[Dest Zone Code]

UPDATE ##tblBidAppMissingLanes
SET Dest = origins.[Origin]
FROM ##tblBidAppMissingLanes baml
INNER JOIN (
SELECT DISTINCT Origin, ORIG_CITY_STATE
FROM USCTTDEV.dbo.tblBidAppLanes
GROUP BY Origin, ORIG_CITY_STATE
) origins ON origins.ORIG_CITY_STATE = baml.[Dest Zone Code]

/*
IF the Dest is still null, update from tblTMRPMForBidApp where Dest State/ZIP has a comma, and does not include 'ZIP' in the string
*/
UPDATE ##tblBidAppMissingLanes
SET DEST = ba.[Dest State/ZIP]
FROM ##tblBidAppMissingLanes baml
INNER JOIN ##tblTMRPMForBidApp ba ON ba.[Dest Zone Code] = baml.[Dest Zone Code]
WHERE ba.[Dest State/Zip] LIKE '%, %'
AND baml.[Dest Country] <> 'USA'

/*
Some local values to update as
SELECT * FROM ##tblBidAppMissingLanes WHERE Dest IS NULL
*/
UPDATE ##tblBidAppMissingLanes
SET Dest = UPPER(CASE WHEN [Dest Zone Code] = 'QCMONT' THEN 'Mont-Tremblant, QC'
WHEN [Dest Zone Code] = 'KCILROME' THEN 'Romeoville, IL'
END)
WHERE Dest IS NULL

/*
Create table of City/States from TM ADDRESS_R
SELECT * FROM ##tblCityStateTemp WHERE PSTL_CD = '98303'
SELECT * FROM ##tblTMRPMForBidApp
SELECT * FROM ##tblBidAppMissingLanes WHERE Dest IS NULL
SELECT * FROM USCTTDEV.dbo.tblTMSZones WHERE CTY_CD LIKE 'ROMEO%'
*/
SELECT * INTO ##tblCityStateTemp 
FROM OPENQUERY(NAJDAPRD,'SELECT
    TRIM(ctry_cd) AS ctry_cd,
    TRIM(citystate) AS citystate,
    TRIM(cty_name) AS cty_name,
    TRIM(sta_cd) AS sta_cd,
    pstl_cd,
    ROW_NUMBER() OVER(
        PARTITION BY citystate
        ORDER BY
            count DESC
    ) AS rank,
    COUNT
FROM
    (
        SELECT DISTINCT
            ar.ctry_cd,
            ar.cty_name
            || '', ''
            || ar.sta_cd AS citystate,
            ar.cty_name,
            ar.sta_cd,
            CASE
                WHEN ar.ctry_cd = ''USA'' THEN
                    substr(ar.pstl_cd, 1, 5)
                ELSE
                    ar.pstl_cd
            END AS pstl_cd,
            COUNT(*) AS count
        FROM
            najdaadm.address_r ar
        WHERE
            ar.ctry_cd IN (
                ''USA'',
                ''CAN'',
                ''MEX''
            )
        GROUP BY
            ar.ctry_cd,
            ar.cty_name
            || '', ''
            || ar.sta_cd,
            ar.cty_name,
            ar.sta_cd,
            CASE
                    WHEN ar.ctry_cd = ''USA'' THEN
                        substr(ar.pstl_cd, 1, 5)
                    ELSE
                        ar.pstl_cd
                END
    ) zips') zips

/*
Update Missing CityState from TM data

SELECT * FROM ##tblCityStateTemp
SELECT * FROM ##tblBidAppMissingLanes WHERE Dest IS NULL
*/
UPDATE ##tblBidAppMissingLanes
SET DEST = cst.CITYSTATE
FROM ##tblBidAppMissingLanes baml
INNER JOIN ##tblCityStateTemp cst ON cst.PSTL_CD = SUBSTRING(baml.[Dest Zone Code],4,5)
WHERE baml.[Dest Country] = 'USA'
AND baml.DEST IS NULL
AND cst.Rank = 1

/*
Update to UNKNOWN, STATE if the dest zone code is still unknown
SELECT * FROM ##tblBidAppMissingLanes ORDER BY LaneID ASC
SELECT DISTINCT [Order Type], BusinessUnit FROM USCTTDEV.dbo.tblBidAppLanes
*/
UPDATE ##tblBidAppMissingLanes
SET Dest = 'UNKNOWN, ' + CASE WHEN [Dest Zone Code] LIKE '5%' THEN SUBSTRING([Dest Zone Code],2,2) ELSE SUBSTRING([Dest Zone Code],1,2) END,
OrderType = 'UNKNOWN',
BusinessUnit = 'UNKNOWN'
WHERE Dest IS NULL
AND [Dest Country] = 'USA'

/*
Update Default Order Type / BusinessUnit where not 'UNKNOWN'
SELECT * FROM ##tblBidAppMissingLanes WHERE Dest LIKE '%UNKNOWN%'
*/
UPDATE ##tblBidAppMissingLanes
SET OrderType = 'CUSTOMER', 
BusinessUnit = 'CONSUMER'
WHERE Dest NOT LIKE '%UNKNOWN%'

/*
Update AddedBy/AddedOn
*/
UPDATE ##tblBidAppMissingLanes
SET AddedBy = 'SYSTEM', 
AddedOn = GETDATE()

/*
Delete from ##tblTMRPMForBidApp where Origin/Dest zones start with KC, but do not have the -
SELECT * FROM ##tblBidAppMissingLanes WHERE ([Dest Zone Code] LIKE 'KC%' AND OrderType = 'UNKNOWN') OR ([Origin Zone Code] LIKE 'KC%' AND OrderType = 'UNKNOWN')
SELECT * FROM ##tblTMRPMForBidApp WHERE LaneStatus IS NULL
*/
DELETE ##tblTMRPMForBidApp
FROM ##tblTMRPMForBidApp tmbp
INNER JOIN ##tblBidAppMissingLanes baml ON baml.[Origin Zone Code] = tmbp.[Origin Zone Code]
AND baml.[Dest Zone Code] = tmbp.[Dest Zone Code]
WHERE ((baml.OrderType = 'UNKNOWN' AND baml.[Origin Zone Code] LIKE 'KC%') 
OR (baml.OrderType = 'UNKNOWN' AND baml.[Dest Zone Code] LIKE 'KC%'))
AND tmbp.LaneStatus IS NULL

/*
Delete from ##tblBidAppMissingLanes WHERE LaneID no longer exists
*/
DELETE ##tblBidAppMissingLanes
FROM ##tblBidAppMissingLanes baml
LEFT JOIN ##tblTMRPMForBidApp tmbp ON tmbp.[Origin Zone Code] = baml.[Origin Zone Code]
AND tmbp.[Dest Zone Code] = baml.[Dest Zone Code]
WHERE tmbp.[Origin Zone Code] IS NULL AND tmbp.[Dest Zone Code] IS NULL

/*
Final update for LaneID on ##tblBidAppMissingLanes
*/

/*
Set LaneID back to null, and start the whole match thing over again
*/
UPDATE ##tblBidAppMissingLanes SET LaneID = Null

/*
Update with new Index number, just in CASE the old one was duplicated for some unknown reason

SELECT * FROM ##tblBidAppMissingLanes order by LaneID ASC
*/
UPDATE ##tblBidAppMissingLanes
SET LaneID = row.row
FROM ##tblBidAppMissingLanes baml
INNER JOIN (SELECT ROW_NUMBER() OVER (ORDER BY [Origin Zone Code]+'-'+[Dest Zone Code]) as Row,
[Origin Zone Code]+'-'+[Dest Zone Code] AS Lane FROM ##tblBidAppMissingLanes) row ON row.Lane = baml.[Origin Zone Code]+'-'+baml.[Dest Zone Code]

/*
Update ##tblBidAppMissingLanes.LaneID to 1+Max(USCTTDEV.dbo.tblBidAppLanes.LaneID)
SELECT * FROM ##tblBidAppMissingLanes ORDER BY LaneID ASC
*/
UPDATE ##tblBidAppMissingLanes
SET LaneID = LaneID + (SELECT MAX(LaneID) AS MaxLaneID FROM USCTTDEV.dbo.tblBidAppLanes)

/*
Update ##tblTMRPMForBidApp, and set all LaneID's > the max value from BidAppLanes to null

UPDATE ##tblTMRPMForBidApp
SET LaneID = NULL
FROM ##tblTMRPMForBidApp tmba
WHERE LaneID > (SELECT MAX(LaneID) AS MaxLaneID FROM USCTTDEV.dbo.tblBidAppLanes)
*/

/*
Update ##tblTMRPMForBidApp with missing lane id's
SELECT * FROM ##tblTMRPMForBidApp ORDER BY LaneID DESC
SELECT MAX(LaneID) AS MaxLaneID FROM USCTTDEV.dbo.tblBidAppLanes
*/
UPDATE ##tblTMRPMForBidApp
SET LaneID = baml.LaneID,
LaneStatus = 'New Lane',
RateStatus = 'New Rate'
FROM ##tblTMRPMForBidApp tmba
INNER JOIN ##tblBidAppMissingLanes baml ON baml.[Origin Zone Code] = tmba.[Origin Zone Code]
AND baml.[Dest Zone Code] = tmba.[Dest Zone Code]
WHERE tmba.LaneID IS NULL  OR tmba.LaneID <> baml.LaneID
AND tmba.LaneStatus IS NULL

/*
FINAL CHECK
Update ##tblTMRPMForBidApp with LaneID from USCTTDEV.dbo.tblBidAppLanes
SELECT * FROM USCTTDEV.dbo.tblBidAppLanes where ID <10
*/
UPDATE ##tblTMRPMForBidApp
SET LaneID = bal.LaneID,
LaneStatus = 'Exists'
FROM ##tblTMRPMForBidApp tm
INNER JOIN USCTTDEV.dbo.tblBidAppLanes bal ON bal.ORIG_CITY_STATE = tm.[Origin Zone Code]
AND bal.DEST_CITY_STATE = tm.[Dest Zone Code]
WHERE tm.LaneID IS NULL OR tm.LaneID <> bal.LaneID

/*
Delete from ##tblBidAppMissingLanes if still on table, but exists on ##tblTMRPM ForBidAp as LaneStatus 'Exists'

SELECT * FROM ##tblBidAppMissingLanes ORDER BY LANEID ASC
SELECT TOP 10 * FROM USCTTDEV.dbo.tblBidAppLanes ORDER BY LaneID DESC
SELECT * FROM ##tblTMRPMFOrBidApp WHERE [Origin Zone Code] = 'NJSWEDES' AND [Dest Zone Code] = '5MD21061'
*/
DELETE ##tblBidAppMissingLanes
FROM ##tblBidAppMissingLanes baml
INNER JOIN ##tblTMRPMForBidApp tmba ON tmba.LaneID = baml.LaneID
WHERE tmba.LaneStatus = 'Exists'

/*
Add missing lanes to USCTTDEV.dbo.tblBidAppLanes
*/
INSERT INTO USCTTDEV.dbo.tblBidAppLanes(
LaneID,
Lane,
OriginCountry,
ORIG_CITY_STATE,
Origin,
OriginZip,
DestCountry,
DEST_CITY_STATE,
Dest,
Equipment,
Miles,
COMMENT,
[Order Type],
EffectiveDate,
ExpirationDate,
BusinessUnit
)
SELECT baml.LaneID, 
baml.[Origin Zone Code]+'-'+baml.[Dest Zone Code],
baml.[Origin Country],
baml.[Origin Zone Code],
baml.[Origin City],
baml.OriginZip,
baml.[Dest Country],
baml.[Dest Zone Code],
baml.Dest,
'D',
1,
FORMAT(GETDATE(), 'M/d/yyyy') + ' / Lane added by Stored Procedure',
baml.OrderType,
REPLACE('2/1/'+STR(YEAR(GETDATE())),' ',''),
'12/31/2999',
baml.BusinessUnit
FROM ##tblBidAppMissingLanes baml
WHERE baml.LaneID NOT IN (SELECT LaneID FROM USCTTDEV.dbo.tblBidAppLanes)

/*
Delete where there might be a duplicate lane, preserving the oldest one
*/
DELETE USCTTDEV.dbo.tblBidAppLanes 
FROM USCTTDEV.dbo.tblBidAppLanes bal
INNER JOIN (SELECT DISTINCT Lane, COUNT(*) AS COUNTa, MIN(ID) AS MinID
FROM USCTTDEV.dbo.tblBidAppLanes
GROUP BY Lane
HAVING COUNT(*) <> 1) dupe ON dupe.Lane = bal.Lane
WHERE ID <> dupe.MinID

/*
Delete where there might be duplicate rates, preserving the oldest one
*/
DELETE USCTTDEV.dbo.tblBidAppRates
FROM USCTTDEV.dbo.tblBidAppRates bar
INNER JOIN (
SELECT DISTINCT Lane, SCAC, COUNT(*) AS COUNT, MIN(ID) AS MinID
FROM USCTTDEV.dbo.tblBidAppRates
GROUP BY Lane, SCAC
HAVING COUNT(*) > 1) dupe ON dupe.Lane = bar.Lane
AND dupe.SCAC = bar.SCAC
WHERE ID <> dupe.MinID

/*
Update USCTTDEV.dbo.tblBidAppLanes where Miles = 1
*/
UPDATE USCTTDEV.dbo.tblBidAppLanes
SET MILES = miles.Miles
FROM USCTTDEV.dbo.tblBidAppLanes bal
INNER JOIN(
SELECT Lane, ShipmentCount, Miles, Row
FROM (SELECT DISTINCT Lane, 
COUNT(*) AS ShipmentCount,
FIXD_ITNR_DIST AS Miles,
ROW_NUMBER() OVER(PARTITION BY Lane ORDER BY COUNT(*) DESC) Row
FROM USCTTDEV.dbo.tblActualLoadDetail
WHERE LANE IS NOT NULL
/*AND LANE = 'CAFULLER-5CA91708'*/
GROUP BY Lane, FIXD_ITNR_DIST) miles
WHERE Row = 1
) miles ON miles.Lane = bal.Lane
WHERE bal.MILES <= 1

/*
Append to temp changelog table
*/
DROP TABLE IF EXISTS ##tblChangelogTemp
CREATE TABLE ##tblChangelogTemp
(
LaneID						int,
Lane							nvarchar(50),
ChangeType				nvarchar(50),
ChangeReason			nvarchar(50),
SCAC							nvarchar(5),
Field							nvarchar(50),
PreviousValue			nvarchar(2000),
NewValue					nvarchar(2000),
UpdatedBy					nvarchar(50),
UpdatedByName		nvarchar(50),
UpdatedOn				datetime,
TMEffectiveDate		datetime
)

/*
Add missing lanes to temp changelog table
SELECT * FROM ##tblChangelogTemp
*/
INSERT INTO ##tblChangelogTemp(LaneID, Lane, Changetype, ChangeReason, Field, NewValue, UpdatedBy, UpdatedByName, UpdatedOn)
SELECT baml.LaneID, baml.[Origin Zone Code]+'-'+baml.[Dest Zone Code], 'Master Data', 'New Lane', 'New Lane', baml.[Origin Zone Code]+'-'+baml.[Dest Zone Code], 'SYSTEM', 'Stored Procedure', GETDATE()
FROM ##tblBidAppMissingLanes baml
ORDER BY baml.LaneID ASC

/*
Delete from ChangelogTemp if LaneID no longer in dataset
DELETE ##tblChangelogTemp
FROM ##tblChangelogTemp  clt
INNER JOIN USCTTDEV.dbo.tblBidAppLanes bal ON bal.LaneID = clt.LaneID
WHERE bal.Comment NOT LIKE '%Stored Procedure%'
*/

/*
Get new SCAC rates from ##tblTMRPMFOrBidApp where not in USCTTDEV.dbo.tblBidAppRates
SELECT * FROM USCTTDEV.dbo.tblBidAppRates where ID <10
SELECT * FROM USCTTDEV.dbo.tblBidAppLanes WHERE ID <10
SELECT * FROM ##tblTMRPMForBidApp
SELECT * FROM ##tblBidAppMissingRates ORDER BY LaneID DESC
*/
DROP TABLE IF EXISTS ##tblBidAppMissingRates
SELECT * INTO ##tblBidAppMissingRates
FROM(
SELECT bal.LaneID,
tm.[Origin Zone Code],
tm.[Dest Zone Code],
tm.[Origin Zone Code] + '-' + tm.[Dest Zone Code] AS Lane,
tm.ShipMode,
CASE WHEN tm.ShipMode = 'INTERMODAL' THEN '53IM' ELSE '53FT' END AS Equipment,
tm.Service,
CASE WHEN tm.ShipMode = 'INTERMODAL' THEN 'IM' ELSE 'T' END AS Mode,
'Y' AS ActiveFlag,
'Y' AS Confirmed,
bal.Origin,
bal.Dest,
CAST(tm.[TM Effective Date] AS DATE) AS [TM Effective Date],
CAST(tm.[TM Expiration Date] AS DATE) AS [TM Expiration Date],
CASE WHEN CAST(tm.[Min Charge] AS NUMERIC (18,2)) >.01 THEN 0 ELSE CAST(tm.[Rate Per Mile] AS NUMERIC (18,2)) END AS [Rate Per Mile],
CASE WHEN CAST(tm.[Min Charge] AS NUMERIC(18,2))= .01 THEN 0 ELSE CAST(tm.[Min Charge] AS NUMERIC(18,2)) END AS [Min Charge],
tm.[BS Charge],
CASE WHEN tm.[Min Charge] >.01 THEN 'Flat Rate' ELSE 'Rate Per Mile' END AS ChargeType,
tm.LaneStatus,
tm.RateStatus,
'SYSTEM' AS AddedBy,
GETDATE() AS AddedOn
FROM ##tblTMRPMForBidApp tm 
INNER JOIN USCTTDEV.dbo.tblBidAppLanes bal ON bal.LaneID = tm.LaneID
LEFT JOIN USCTTDEV.dbo.tblBidAppRates bar ON bar.LaneID = tm.LaneID
AND bar.SCAC = tm.SERVICE
WHERE bar.SCAC IS NULL
AND tm.LaneID IS NOT NULL
AND bal.Lane NOT LIKE '%TC%'
AND CAST(tm.[TM Effective Date] AS DATE) >= CAST(bal.EffectiveDate AS DATE)
--ORDER BY tm.LaneID ASC, tm.SERVICE ASC
) missing

/*
Add missing rates to USCTTDEV.dbo.tblBidAppRates
*/
INSERT INTO USCTTDEV.dbo.tblBidAppRates(LaneID, 
ORIG_CITY_STATE, 
DEST_CITY_STATE, 
Lane, 
Equipment, 
SCAC,
MODE, 
Active_Flag, 
Confirmed, 
Origin, 
Dest, 
EffectiveDate, 
ExpirationDate, 
[Rate Per Mile], 
[Min Charge], 
CUR_RPM, 
ChargeType)
SELECT bamr.LaneID, 
bamr.[Origin Zone Code], 
bamr.[Dest Zone Code], 
bamr.Lane, 
bamr.Equipment, 
bamr.Service, 
bamr.MODE, 
bamr.ActiveFlag, 
bamr.Confirmed, 
bamr.Origin, 
bamr.Dest, 
bamr.[TM Effective Date], 
bamr.[TM Expiration Date], 
CASE WHEN bamr.ChargeType = 'Rate Per Mile' THEN CAST(bamr.[Rate Per Mile] AS NUMERIC(18,2)) END, 
CASE WHEN bamr.ChargeType <> 'Rate Per Mile' THEN CAST(bamr.[Min Charge] AS NUMERIC(18,2)) END, 
CASE WHEN bamr.ChargeType = 'Rate Per Mile' THEN CAST(bamr.[Rate Per Mile] AS NUMERIC(18,2)) END, 
bamr.ChargeType
FROM ##tblBidAppMissingRates bamr
LEFT JOIN USCTTDEV.dbo.tblBidAppRates bar ON bar.LaneID = bamr.LaneID
AND bar.SCAC = bamr.Service
WHERE bar.LaneID IS NULL
AND bar.SCAC IS NULL
ORDER BY bamr.LaneID ASC, bamr.Service ASC

/*
Add changes to temp changelog
SELECT * FROM ##tblBidAppMissingRates ORDER BY LaneID DESC
DELETE FROM ##tblChangelogTemp WHERE [TmEffectiveDate] IS NOT NULL
SELECT * FROM ##tblChangelogTemp
*/
INSERT INTO ##tblChangelogTemp(LaneID, Lane, ChangeType, ChangeReason, SCAC, Field, NewValue, UpdatedBy, UpdatedByName, UpdatedOn, TMEffectiveDate)
SELECT bamr.LaneID, bamr.Lane, 'Rate Level - RPM', 'New Carrier on Lane', bamr.Service, 
CASE WHEN bamr.ChargeType = 'Flat Rate' THEN 'Min Charge' ELSE 'CUR_RPM' END, 
CASE WHEN bamr.ChargeType = 'Flat Rate' THEN bamr.[Min Charge] ELSE bamr.[Rate Per Mile] END,
'SYSTEM',
'Stored Procedure',
GETDATE(),
CAST([TM Effective Date] AS DATE)
FROM ##tblBidAppMissingRates bamr
LEFT JOIN ##tblChangelogTemp clt ON clt.LaneID = bamr.LaneID
AND clt.SCAC = bamr.Service
WHERE clt.LaneID IS NULL
AND clt.SCAC IS NULL
ORDER BY bamr.LaneID, bamr.Service ASC

/*
Append rate differences into temp table

SELECT * FROM ##tblBidAppRateDifferences
*/

DROP TABLE IF EXISTS ##tblBidAppRateDifferences
SELECT * INTO ##tblBidAppRateDifferences
FROM(
SELECT bar.LaneID, 
bar.Lane,
tm.Service, 
CASE WHEN tm.[Min Charge] > .01 THEN 'Flat Charge' ELSE 'Rate Per Mile' END AS TMRateType,
CAST(CASE WHEN tm.[Min Charge] > .01 THEN tm.[Min Charge] ELSE tm.[Rate Per Mile] END AS NUMERIC (18,2)) AS TMRate,
tm.[TM Effective Date],
bar.ChargeType AS BidAppRateType,
CAST(CASE WHEN tm.[Min Charge] > .01 THEN bar.[Min Charge] ELSE bar.[CUR_RPM] END AS NUMERIC (18,2)) AS BidAppRate,
bar.EffectiveDate AS BidAppEffectiveDate,
CASE WHEN CAST(CASE WHEN tm.[Min Charge] > .01 THEN tm.[Min Charge] ELSE tm.[Rate Per Mile] END AS NUMERIC (18,2)) 
= CAST(CASE WHEN tm.[Min Charge] > .01 THEN bar.[Min Charge] ELSE bar.[CUR_RPM] END AS NUMERIC (18,2)) THEN 'MATCH' ELSE 'Does Not Match' END AS MatchType,
CASE WHEN cl.SCAC IS NOT NULL THEN cl.UpdatedOn END AS ChangelogDate
FROM ##tblTMRPMForBidApp tm
INNER JOIN USCTTDEV.dbo.tblBidAppLanes bal ON bal.LaneID = tm.LaneID
INNER JOIN USCTTDEV.dbo.tblBidAppRates bar on bar.LaneID = tm.LaneID
AND tm.Service = bar.SCAC
AND CAST(tm.[TM Effective Date] AS DATE) >= CAST(bal.EffectiveDate AS DATE)

LEFT JOIN (
SELECT cl.LaneID, cl.Lane, cl.ChangeType, cl.SCAC, cl.PreviousValue, cl.NewValue, cl.UpdatedBy, cl.UpdatedByName, cl.UpdatedOn
FROM USCTTDEV.dbo.tblBidAppChangelog cl

INNER JOIN (
SELECT DISTINCT MAX(cl.ID) AS MaxID, 
Lane,
SCAC
FROM USCTTDEV.dbo.tblBidAppChangelog cl
WHERE ChangeType = 'Rate Level - RPM'
GROUP BY Lane, SCAC) MaxID ON MaxID.MaxID = cl.ID

)cl ON cl.LaneID = bar.LaneID
AND cl.SCAC = bar.SCAC
) match 
WHERE MatchType <> 'MATCH'
AND Lane NOT LIKE '%TC%'

ORDER BY LaneID ASC, Service ASC

/*
Update USCTTDEV.dbo.tblBidAppRates with new rates
SELECT * FROM ##tblBidAppRateDifferences WHERE Equipment = '53TC'

SELECT CUR_RPM, [Min Charge], ChargeType FROM USCTTDEV.dbo.tblBidAppRates where LaneID = 1137 AND SCAC = 'WENP'
*/

UPDATE USCTTDEV.dbo.tblBidAppRates
SET CUR_RPM = CAST(CASE WHEN bard.TMRateType = 'Flat Charge' THEN NULL ELSE bard.TMRate END AS NUMERIC(18,2)),
[Min Charge] = CAST(CASE WHEN bard.TMRateType = 'Flat Charge' THEN bard.TMRate ELSE NULL END AS NUMERIC(18,2)),
[Rate Per Mile] = CAST(CASE WHEN bard.TMRateType = 'Flat Charge' THEN NULL ELSE bard.TMRate END AS NUMERIC(18,2)),
ChargeType = CASE WHEN bard.TMRateType = 'Flat Charge' THEN 'Flat Rate' ELSE 'Rate Per Mile' END,
EffectiveDate = bard.[TM Effective Date],
ExpirationDate = '12/31/2999'
FROM USCTTDEV.dbo.tblBidAppRates bar
INNER JOIN ##tblBidAppRateDifferences bard ON bard.LaneID = bar.LaneID
AND bard.Service = bar.SCAC
WHERE bar.Lane NOT LIKE '%TC%'

/*
Add changes to temp changelog
SELECT * FROM ##tblBidAppRateDifferences ORDER BY LaneID, Service ASC

SELECT * FROM ##tblChangelogTemp
*/
INSERT INTO ##tblChangelogTemp(LaneID, Lane, ChangeType, ChangeReason, SCAC, Field, PreviousValue, NewValue, UpdatedBy, UpdatedByName, UpdatedOn, TMEffectiveDate)
SELECT bard.LaneID, bard.Lane, 'Rate Level - RPM', 'Stored Procedure Difference', bard.Service, 
CASE WHEN bard.TMRateType = 'Flat Charge' THEN 'Min Charge' ELSE 'CUR_RPM' END, 
bard.BidAppRate,
bard.TMRate,
'SYSTEM',
'Stored Procedure',
GETDATE(),
CAST([TM Effective Date] AS DATE)
FROM ##tblBidAppRateDifferences bard
LEFT JOIN ##tblChangelogTemp clt ON clt.LaneID = bard.LaneID
AND clt.SCAC = bard.Service
WHERE clt.LaneID IS NULL
AND clt.SCAC IS NULL
ORDER BY bard.LaneID, bard.Service ASC

/*
Create Row Number on Changelog
*/
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'ID'	AND TABLE_NAME LIKE '##tblChangelogTemp') ALTER TABLE ##tblChangelogTemp ADD ID	INT NULL

/*
Update Row Number on Changelog, where there's a SCAC
UPDATE ##tblChangelogTemp SET ID = Null
SELECT * FROM ##tblChangelogTemp ORDER BY ID ASC
*/
UPDATE ##tblChangelogTemp
SET ID = rows.Row
FROM ##tblChangelogTemp clt
INNER JOIN (
SELECT clt.*, ROW_NUMBER() OVER(ORDER BY
		LaneID ASC, ChangeType ASC, ChangeReason ASC, SCAC ASC
    ) AS Row
FROM ##tblChangelogTemp clt
)rows ON rows.LaneID = clt.LaneID
AND rows.ChangeType = clt.ChangeType
AND rows.ChangeReason = clt.ChangeReason
AND rows.SCAC = clt.SCAC
WHERE clt.ID IS NULL

/*
Update Row Number on Changelog, where there's NO SCAC

SELECT * FROM ##tblChangelogTemp ORDER BY ID ASC
UPDATE ##tblChangelogTemp SET ID = NULL

SELECT clt.*, ROW_NUMBER() OVER(ORDER BY
		LaneID ASC, ChangeType ASC, ChangeReason ASC, SCAC ASC
    ) AS Row
FROM ##tblChangelogTemp clt
*/
UPDATE ##tblChangelogTemp
SET ID = rows.Row
FROM ##tblChangelogTemp clt
INNER JOIN (
SELECT clt.*, ROW_NUMBER() OVER(ORDER BY
		LaneID ASC, ChangeType ASC, ChangeReason ASC, SCAC ASC
    ) AS Row
FROM ##tblChangelogTemp clt
)rows ON rows.LaneID = clt.LaneID
AND rows.ChangeType = clt.ChangeType
AND rows.ChangeReason = clt.ChangeReason
WHERE clt.ID IS NULL


/*
Create final changelog for outbound email

SELECT * FROM ##tblChangelogTemp
SELECT * FROM ##tblChangelogTempFinal ORDER BY ID ASC
*/
DROP TABLE IF EXISTS ##tblChangelogTempFinal
SELECT ID, LaneID, Lane, ChangeType, ChangeReason, SCAC, Field, PreviousValue, NewValue, UpdatedBy, UpdatedByName, GETDATE() AS UpdatedOn, TMEffectiveDate
INTO ##tblChangelogTempFinal
FROM ##tblChangelogTemp cl
ORDER BY cl.ID ASC

/*
Add records into USCTTDEV.dbo.tblBidAppChangelog
*/
INSERT INTO USCTTDEV.dbo.tblBidAppChangelog(LaneID, Lane, ChangeType, ChangeReason, SCAC, Field, PreviousValue, NewValue, UpdatedBY, UpdatedByName, UpdatedOn, ChangeTable)
SELECT cltf.LaneID, cltf.Lane, cltf.ChangeType, cltf.ChangeReason, cltf.SCAC, cltf.Field, cltf.PreviousValue, cltf.NewValue, cltf.UpdatedBY, cltf.UpdatedByName, cltf.UpdatedOn, CASE WHEN cltf.ChangeType LIKE 'RATE%' THEN 'tblBidAppRates' ELSE 'tblBidAppLanes' END
FROM ##tblChangelogTempFinal cltf
LEFT JOIN USCTTDEV.dbo.tblBidAppChangelog cl ON cl.LaneID = cltf.LaneID
AND cl.ChangeType = cltf.ChangeType
--AND cl.SCAC = cltf.SCAC
AND cl.ChangeReason = cltf.ChangeReason
AND cl.Field = cltf.Field
AND cl.NewValue = cltf.NewValue
WHERE cl.NewValue IS NULL
ORDER BY cltf.ID ASC

/*
Begin Email Processing
*/
DECLARE @ChangelogCount INT
SET @ChangelogCount = (SELECT COUNT(*) FROM ##tblChangelogTempFinal)
PRINT('Change log count: '+REPLACE(STR(@ChangelogCount),' ',''))

/*
If there's at least 1 record to send, send the email to carrier managers
*/
IF @ChangelogCount > 1
BEGIN
	--set variables
	DECLARE @xml NVARCHAR(MAX)
	DECLARE @NewLanes NVARCHAR(MAX)
	DECLARE @NewRates NVARCHAR(MAX)
	DECLARE @Updates NVARCHAR(MAX)
	DECLARE @Headers NVARCHAR(MAX)
	DECLARE @HeadersNewRates NVARCHAR(MAX)
	DECLARE @HeadersTM NVARCHAR(MAX)
	DECLARE @body NVARCHAR(MAX)
	DECLARE @subj NVARCHAR(MAX)

	DECLARE @NewLaneCount INT = (SELECT CASE WHEN COUNT(*) IS NULL THEN 0 ELSE COUNT(*) END FROM ##tblChangelogTempFinal WHERE ChangeReason = 'New Lane' 
	AND CAST(UpdatedOn AS DATE) = CAST(GETDATE() AS DATE)) 
	PRINT('New Lane count: '+REPLACE(STR(@NewLaneCount),' ',''))
	DECLARE @NewRateCount INT = (SELECT CASE WHEN COUNT(*) IS NULL THEN 0 ELSE COUNT(*) END FROM ##tblChangelogTempFinal WHERE ChangeReason = 'New Carrier on Lane' 
	AND CAST(UpdatedOn AS DATE) = CAST(GETDATE() AS DATE))
	PRINT('New Rate count: '+REPLACE(STR(@NewRateCount),' ',''))
	DECLARE @UpdateCount INT = (SELECT CASE WHEN COUNT(*) IS NULL THEN 0 ELSE COUNT(*) END FROM ##tblChangelogTempFinal WHERE ChangeReason = 'Stored Procedure Difference'
	AND CAST(UpdatedOn AS DATE) = CAST(GETDATE() AS DATE))
	PRINT('Update count: '+REPLACE(STR(@UpdateCount),' ',''))

	--SELECT @NewLaneCount, @NewRateCount, @UpdateCount


	-- creating an xml table to be used in html formatted email- this joins the data table and distinct analyst table where the id matches the @counter
	SET @xml = CAST(( SELECT ID AS 'td','', LaneID AS 'td','', Lane AS 'td','', ChangeType AS 'td','', ChangeReason as 'td','', SCAC as 'td','',
		Field as 'td','', CASE WHEN PreviousValue IS NULL THEN ' ' ELSE PreviousValue END as 'td','', NewValue as 'td','', UpdatedBy as 'td','', UpdatedByName as 'td','', FORMAT(UpdatedOn, 'M/d/yyyy') as 'td',''
	FROM ##tblChangelogTempFinal WHERE CAST(UpdatedOn AS DATE) = CAST(GETDATE() AS DATE) ORDER BY ID ASC 
	FOR XML PATH('tr'), ELEMENTS ) AS NVARCHAR(MAX))

	/*
	New Lanes Lines
	SELECT * FROM ##tblChangelogTempFinal WHERE ChangeReason = 'New Lane' 
	*/
	/*
	SET @NewLanes = CAST(( SELECT ID AS 'td','', LaneID AS 'td','', Lane AS 'td','', ChangeType AS 'td','', ChangeReason as 'td','', CASE WHEN SCAC IS NULL THEN ' ' ELSE SCAC END as 'td','',
		Field as 'td','', CASE WHEN PreviousValue IS NULL THEN ' ' ELSE PreviousValue END as 'td','', NewValue as 'td','', UpdatedBy as 'td','', UpdatedByName as 'td','', FORMAT(UpdatedOn, 'M/d/yyyy') as 'td',''
	FROM ##tblChangelogTempFinal WHERE ChangeReason = 'New Lane' 
	AND CAST(UpdatedOn AS DATE) = CAST(GETDATE() AS DATE) ORDER BY ID ASC
	FOR XML PATH('tr'), ELEMENTS ) AS NVARCHAR(MAX))
	*/
		SET @NewLanes = CAST(( SELECT ID AS 'td','', LaneID AS 'td','', Lane AS 'td','', ChangeType AS 'td','', ChangeReason as 'td','', UpdatedBy as 'td','', UpdatedByName as 'td','', FORMAT(UpdatedOn, 'M/d/yyyy') as 'td',''
	FROM ##tblChangelogTempFinal WHERE ChangeReason = 'New Lane' 
	AND CAST(UpdatedOn AS DATE) = CAST(GETDATE() AS DATE) ORDER BY ID ASC
	FOR XML PATH('tr'), ELEMENTS ) AS NVARCHAR(MAX))

	/*
	New Rates Lines
	SELECT * FROM ##tblChangelogTempFinal WHERE ChangeReason = 'New Carrier on Lane' 
	*/
	SET @NewRates = CAST(( SELECT ID AS 'td','', LaneID AS 'td','', Lane AS 'td','', ChangeType AS 'td','', ChangeReason as 'td','', CASE WHEN SCAC IS NULL THEN ' ' ELSE SCAC END as 'td','', Field as 'td','', 
	'$' + NewValue as 'td','', UpdatedBy as 'td','', UpdatedByName as 'td','', FORMAT(UpdatedOn, 'M/d/yyyy') as 'td','', FORMAT(TMEffectiveDate, 'M/d/yyyy') as 'td',''
	FROM ##tblChangelogTempFinal WHERE ChangeReason = 'New Carrier on Lane' 
	AND CAST(UpdatedOn AS DATE) = CAST(GETDATE() AS DATE) ORDER BY ID ASC
	FOR XML PATH('tr'), ELEMENTS ) AS NVARCHAR(MAX))

	/*
	Update Rates Lines
	SELECT * FROM ##tblChangelogTempFinal WHERE ChangeReason = 'Stored Procedure Difference'
	*/
	SET @Updates = CAST(( SELECT ID AS 'td','', LaneID AS 'td','', Lane AS 'td','', ChangeType AS 'td','', ChangeReason as 'td','', CASE WHEN SCAC IS NULL THEN ' ' ELSE SCAC END as 'td','', Field as 'td','', 
	CASE WHEN PreviousValue IS NULL THEN ' ' ELSE  '$' + PreviousValue END as 'td','', '$' + NewValue as 'td','', UpdatedBy as 'td','', UpdatedByName as 'td','', FORMAT(UpdatedOn, 'M/d/yyyy') as 'td','', FORMAT(TMEffectiveDate, 'M/d/yyyy') as 'td',''
	FROM ##tblChangelogTempFinal WHERE ChangeReason = 'Stored Procedure Difference'
	AND CAST(UpdatedOn AS DATE) = CAST(GETDATE() AS DATE) ORDER BY ID ASC
	FOR XML PATH('tr'), ELEMENTS ) AS NVARCHAR(MAX))

	/*
	Set table headers
	*/
	SET @Headers = '
	<tr>
	<th> ID </th> <th> LaneID </th> <th> Lane </th> <th> Change Type </th> <th> Change Reason </th> <th> Updated By </th> <th> Process </th> <th> Updated On </th> </tr> '  

	/*
	Set table headers
	*/
	SET @HeadersNewRates =  '
	<tr>
	<th> ID </th> <th> LaneID </th> <th> Lane </th> <th> Change Type </th> <th> Change Reason </th> <th> SCAC </th> <th> Field </th>
	 <th> New Value </th> <th> Updated By </th> <th> Process </th> <th> Updated On </th> <th> Rate Effective Date</th>  </tr> '  

	/*
	Set table headers
	*/
	SET @HeadersTM = '
	<tr>
	<th> ID </th> <th> LaneID </th> <th> Lane </th> <th> Change Type </th> <th> Change Reason </th> <th> SCAC </th> <th> Field </th>
	<th> Previous Value </th> <th> New Value </th> <th> Updated By </th> <th> Process </th> <th> Updated On </th> <th> Rate Effective Date</th>  </tr> '  

	-- create a body variable that houses the HTML code used to make a table of the data
	SET @body ='<html><head>
	<style>
	table {
	  border-collapse: collapse;
	}

	table, th, td {
	  border: 1px solid black;
	}

	th {
	  text-align: center;
	  vertical-align: center;
	  background-color: #3C93CB;
	  color: white;
	  padding: 10px;
	}

	td {
	  vertical-align: center;
	  font-size: 12px;
	  padding: 5px;
	}

	tr:nth-child(even){background-color: #f2f2f2}

	tr:hover {background-color: #3C93CB;}

	</style>
	<body>'

	--Greeting, and High Level Body
	SET @body = @body 
	+ 'Hello, <br><br> 
	Please see below for details for changes made today within the Bid App tables by Stored Procedure.'
	+ '<p><H3>High Level Change Count</H3>' 
	+ '<table border = 1>'
	+ '<tr><th>Change Type</th><th>Change Count</th></tr>'
	+ CASE WHEN @NewLaneCount > 0 THEN '<tr><td>New Lanes</td><td>' + CAST(@NewLaneCount AS VARCHAR) + '</td></tr>' ELSE '' END
	+ CASE WHEN @NewRateCount > 0 THEN'<tr><td>New Rates</td><td>' + CAST(@NewRateCount AS VARCHAR) + '</td></tr>' ELSE '' END
	+ CASE WHEN @UpdateCount > 0 THEN '<tr><td>Rate Updates</td><td>' + CAST(@UpdateCount AS VARCHAR) + '</td></tr>' ELSE '' END
	+'</table>'
  

	-- add the xml data into the body variable table template, and use closing html tags
	SET @body = @body 
	+ CASE WHEN @NewLaneCount > 0 THEN '<p><H3>New Lanes</H3><table border = 1>' +@Headers + @NewLanes + '</table></p>' ELSE '' END
	+ CASE WHEN @NewRateCount > 0 THEN '<p><H3>New Rates</H3> <table border = 1>' +@HeadersNewRates + @NewRates + '</table></p>' ELSE '' END
	+ CASE WHEN @UpdateCount > 0 THEN '<p><H3>Rate Updates</H3> <table border = 1>' +@HeadersTM + @Updates + '</table></p>' ELSE '' END
	+'</body></html>'

	SET @subj = 'Bid App Updates - ' + CONVERT(VARCHAR, GETDATE(), 101)
	-- send the email based on the email stored procedure
	EXEC msdb.dbo.sp_send_dbmail
	@profile_name = 'Transportation Analytics and Reporting - KCNA', -- replace with your SQL Database Mail Profile 
	@reply_to = 'StrategyAndAnalysis.ctt@kcc.com',
	@body = @body,
	@body_format ='HTML',
	@recipients = 'scarpent@kcc.com; slindsey@kcc.com; jbhook@kcc.com',  
	@copy_recipients = 'schrysan@kcc.com',
	@blind_copy_recipients =  'StrategyAndAnalysis.ctt@kcc.com',
	@subject =  @subj
	
END

/*
Update [Order Type] to match the one most used on USCTTDEV.dbo.tblActualLoadDetail if it's different than what's on tblBidAppLanes
*/
UPDATE USCTTDEV.dbo.tblBidAppLanes
SET [Order Type] = OrderType.OrderType
FROM USCTTDEV.dbo.tblBidAppLanes bal
LEFT JOIN (SELECT
  *
FROM (SELECT DISTINCT
  ald.Lane,
  ald.OrderType,
  COUNT(DISTINCT ald.LD_LEG_ID) AS LoadCount,
  ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC, ald.OrderType ASC) AS Rank
FROM USCTTDEV.dbo.tblActualLoadDetail ald
WHERE YEAR(ald.SHPD_DTT) = YEAR(GETDATE())
GROUP BY ald.Lane,
         ald.OrderType) OrderType
WHERE OrderType.Rank = 1) OrderType
  ON OrderType.Lane = bal.Lane
WHERE bal.[Order Type] <> OrderType.OrderType
OR bal.[Order Type] IS NULL

/*
Drop table to ensure clean process
*/
DROP TABLE IF EXISTS ##tblBidAppDestUpdate

/*
Create temp table for updating
SELECT * FROM ##tblBidAppDestUpdate ORDER BY LaneID ASC
*/
SELECT * INTO ##tblBidAppDestUpdate FROM (
SELECT
bal.LaneID,
bal.Lane,
'Lane Level' AS ChangeType,
'Dest Update / ' + CASE WHEN aldLane.Lane IS NULL THEN 'Dest Zone Aggregate' ELSE 'Actual Load Detail' END AS ChangeReason,
'DEST_CITY_STATE' AS Field,
bal.Dest AS PreviousValue, 
CASE WHEN aldLane.Lane IS NULL THEN DestCityState.CityState ELSE aldLane.CityState END AS NewValue,
'SYSTEM' AS UpdatedBy,
'SYSTEM' AS UpdatedByName,
GETDATE() AS UpdatedOn,
'tblBidAppLanes' AS ChangeTable
FROM USCTTDEV.dbo.tblBidAppLanes bal
INNER JOIN (
		SELECT DISTINCT ald.Dest_Zone,
		ald.LAST_CTY_NAME  + ', ' + ald.LAST_STA_CD AS CityState,
		COUNT(DISTINCT ald.LD_LEG_ID) AS LoadCount,
		ROW_NUMBER() OVER (PARTITION BY ald.Dest_Zone ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC ) AS CityStateRank
		FROM USCTTDEV.dbo.tblActualLoadDetail ald
		WHERE CAST(ald.SHPD_DTT AS DATE) >= CAST(GETDATE() - 180 AS DATE) 
		GROUP BY ald.Dest_Zone,
		ald.LAST_CTY_NAME  + ', ' + ald.LAST_STA_CD
) DestCityState ON DestCityState.Dest_Zone = bal.DEST_CITY_STATE
AND DestCityState.CityStateRank = 1
LEFT JOIN (
SELECT DISTINCT ald.Lane,
		ald.LAST_CTY_NAME  + ', ' + ald.LAST_STA_CD AS CityState,
		COUNT(DISTINCT ald.LD_LEG_ID) AS LoadCount,
		ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC ) AS CityStateRank
		FROM USCTTDEV.dbo.tblActualLoadDetail ald
		WHERE CAST(ald.SHPD_DTT AS DATE) >= CAST(GETDATE() - 180 AS DATE) 
		GROUP BY ald.Lane,
		ald.LAST_CTY_NAME  + ', ' + ald.LAST_STA_CD
) aldLane ON aldLane.Lane = bal.Lane
AND aldLane.CityStateRank = 1
WHERE bal.Dest <> CASE WHEN aldLane.Lane IS NULL THEN DestCityState.CityState ELSE aldLane.CityState END
)data
ORDER BY data.LaneID ASC

/*
Update USCTTDEV.dbo.tblBidAppLanes to the Dest City/State value in ##tblBidAppDestUpdate
*/
UPDATE USCTTDEV.dbo.tblBidAppLanes
SET Dest = badu.NewValue
FROM USCTTDEV.dbo.tblBidAppLanes bal
INNER JOIN ##tblBidAppDestUpdate badu ON badu.LaneID = bal.LaneID

/*
Insert changes into changelog
*/
INSERT INTO USCTTDEV.dbo.tblBidAppChangelog(LaneID, Lane, ChangeReason, Field, PreviousValue, NewValue, UpdatedBy, UpdatedByName, UpdatedOn, ChangeTable)
SELECT badu.LaneID, badu.Lane, badu.ChangeReason, badu.Field, badu.PreviousValue, badu.NewValue, badu.UpdatedBy, badu.UpdatedByName, badu.UpdatedOn, badu.ChangeTable
FROM ##tblBidAppDestUpdate badu
LEFT JOIN USCTTDEV.dbo.tblBidAppChangelog bacl ON bacl.LaneID = badu.LaneID
AND CAST(bacl.UpdatedOn AS DATE) = CAST(badu.UpdatedOn AS DATE)
AND bacl.NewValue = badu.NewValue
WHERE bacl.NewValue IS NULL
ORDER BY badu.LaneID ASC

/*
Don't really need to do this, but I do it anyway #yolo
*/
DROP TABLE IF EXISTS ##tblBidAppDestUpdate

/*
Execute BidAppLanesUpdateCountryZip, which also includes ranking functions
*/
EXEC USCTTDEV.dbo.sp_BidAppLanesUpdateCountryZip

/*
Execute sp_AAP to assign AAO's
*/
EXEC USCTTDEV.dbo.sp_AAO

/*
exec msdb.dbo.sysmail_configure_sp 'MaxFileSize','2000000'
*/

END