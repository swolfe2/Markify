/*
Drop temp tables to ensure a clean process
*/
DROP TABLE IF EXISTS ##tblTMTariffTemp,
##tblBidAppRatesMissing

/*
Create temp table of TM Tariff Info
SELECT * FROM ##tblTMTariffTemp
*/
SELECT * INTO ##tblTMTariffTemp FROM OPENQUERY(NAJDAPRD,'SELECT
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
			org.sta_cd       AS "Origin State",
			org.ctry_Cd      AS "Origin Country",
            l.dest_zn_cd     AS "Dest Zone Code",
            dest.zn_desc     AS "Dest State/ZIP",
			CASE WHEN dest.ctry_Cd <> ''USA'' THEN l.dest_zn_cd ELSE SUBSTR(l.dest_zn_cd,-5) END AS "Dest Zip",
			dest.sta_cd      AS "Dest State",
			dest.ctry_Cd     AS "Dest Country",
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
            AND r.expd_dt > SYSDATE
            AND (r.chrg_cd = ''MILE'' OR CHRG_CD = ''ZTEM'')
			/*Exclude 9 digit ZIPS*/
			AND SUBSTR(l.orig_zn_cd,1,1) <> (''9'')
			AND SUBSTR(l.dest_zn_cd,1,1) <> (''9'')
			/*Exclude Catchall*/
			AND UPPER(SUBSTR(l.orig_zn_cd,1,3)) <> (''ALL'')
			AND UPPER(SUBSTR(l.dest_zn_cd,1,3)) <> (''ALL'')
			/*Exclude 3 digit ZIPS*/
			AND UPPER(SUBSTR(l.orig_zn_cd,1,3)) <> (''US-'')
			AND UPPER(SUBSTR(l.dest_zn_cd,1,3)) <> (''US-'')

			/*AND rr.brk_amt_dlr >.01*/
            /*AND l.orig_zn_cd || ''-'' || l.dest_zn_cd LIKE ''%WIOSHKOS-5CA92831%''
            AND upper(mst.srvc_desc) NOT LIKE ''%INTERMODAL%''
            AND upper(mst.srvc_desc) NOT LIKE ''%TRAIN%''
            AND upper(mst.srvc_desc) NOT LIKE ''%TOFC%''
            AND upper(mst.srvc_desc) NOT LIKE ''%INTERMILL%''*/
    ) rpm 

ORDER BY
    "Origin Zone Code",
    "Dest Zone Code",
    Shipmode,
    Rank,
    Service') RPM

/*
Add missing columns:
BidAppLaneID = If null, then lane is not in USCTTDEV.dbo.tblBidAppLanes
BidAppRate = If null, then rate is not in USCTTDEV.dbo.tblBidAppRates
BidAppFlatCharge = If null, then there is no flat charge
BidAppRateMatch = If "Y", then delete from raw table. All that should be left are changes.
SELECT * FROM ##tblTMTariffTemp
*/
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'BidAppLaneID'		AND TABLE_NAME LIKE '##tblTMTariffTemp') ALTER TABLE ##tblTMTariffTemp ADD BidAppLaneID		INT NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'BidAppRate'			AND TABLE_NAME LIKE '##tblTMTariffTemp') ALTER TABLE ##tblTMTariffTemp ADD BidAppRate		NUMERIC(18,2) NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'BidAppFlatCharge'	AND TABLE_NAME LIKE '##tblTMTariffTemp') ALTER TABLE ##tblTMTariffTemp ADD BidAppFlatCharge	NUMERIC(18,2) NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'BidAppRateType'		AND TABLE_NAME LIKE '##tblTMTariffTemp') ALTER TABLE ##tblTMTariffTemp ADD BidAppRateType	NVARCHAR(20) NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'BidAppRateMatch'	AND TABLE_NAME LIKE '##tblTMTariffTemp') ALTER TABLE ##tblTMTariffTemp ADD BidAppRateMatch	NVARCHAR(10) NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'LaneMissing'	    AND TABLE_NAME LIKE '##tblTMTariffTemp') ALTER TABLE ##tblTMTariffTemp ADD LaneMissing  	NVARCHAR(10) NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'RateMissing'    	AND TABLE_NAME LIKE '##tblTMTariffTemp') ALTER TABLE ##tblTMTariffTemp ADD RateMissing  	NVARCHAR(10) NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'ErrorType'    	    AND TABLE_NAME LIKE '##tblTMTariffTemp') ALTER TABLE ##tblTMTariffTemp ADD ErrorType  	    NVARCHAR(50) NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'Changelog'    	    AND TABLE_NAME LIKE '##tblTMTariffTemp') ALTER TABLE ##tblTMTariffTemp ADD Changelog  	    NVARCHAR(50) NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'ChangelogType' 	    AND TABLE_NAME LIKE '##tblTMTariffTemp') ALTER TABLE ##tblTMTariffTemp ADD ChangelogType    NVARCHAR(50) NULL


/*
Update ##tblTMTariffTemp with USCTTDEV.dbo.tblBidAppLanes.LaneID
SELECT * FROM USCTTDEV.dbo.tblBidAppLanes
SELECT * FROM ##tblTMTariffTemp
*/
UPDATE ##tblTMTariffTemp
SET BidAppLaneID = bal.LaneID
FROM ##tblTMTariffTemp ttt
INNER JOIN USCTTDEV.dbo.tblBidAppLanes bal ON bal.Lane = ttt.[Origin Zone Code]+'-'+ttt.[Dest Zone Code]

/*
Update ##tblTMTariffTemp with USCTTDEV.dbo.tblBidAppRates CUR_RPM and/or Min Charge
SELECT * FROM USCTTDEV.dbo.tblBidAppRates where LaneID = 1
SELECT * FROM ##tblTMTariffTemp where BidAppLaneID = 1
*/
UPDATE ##tblTMTariffTemp
SET BidAppRate = bar.CUR_RPM,
BidAppFlatCharge = bar.[Min Charge],
BidAppRateType = bar.[ChargeType]
FROM ##tblTMTariffTemp ttt
INNER JOIN USCTTDEV.dbo.tblBidAppRates bar ON bar.LaneID = ttt.BidAppLaneID
AND bar.SCAC = ttt.Service

/*
Update BidAppRateMatch to "Yes" if the rate from TM matches the rate currently in the Bid App

Flat Rate Example
SELECT * FROM USCTTDEV.dbo.tblBidAppRates where LaneID = 1
SELECT * FROM ##tblTMTariffTemp where BidAppLaneID = 1

RPM Example
SELECT * FROM USCTTDEV.dbo.tblBidAppRates where LaneID = 600
SELECT * FROM ##tblTMTariffTemp where BidAppLaneID = 600
SELECT * FROM ##tblTMTariffTemp WHERE BidAppRateMatch = 'ERROR'
UPDATE ##tblTMTariffTemp SET BIdAppRateMatch = Null
*/
UPDATE ##tblTMTariffTemp
SET BidAppRateMatch =	CASE WHEN [Rate Per Mile] = 0 AND [Min Charge] > 0 THEN
							CASE WHEN CAST(BidAppFlatCharge AS NUMERIC (18,2)) = CAST([Min Charge] AS NUMERIC(18,2)) THEN 'Yes' ELSE 'No' END
						WHEN [Rate Per Mile] > 0 AND [Min Charge] = 0 THEN
							CASE WHEN CAST(BidAppRate AS NUMERIC(18,2)) = CAST([Rate Per Mile] AS NUMERIC (18,2)) THEN 'Yes' ELSE 'No' END
						ELSE 'ERROR' END
FROM ##tblTMTariffTemp
WHERE BidAppLaneID IS NOT NULL
AND BidAppRate IS NOT NULL OR BIdAppFlatCharge IS NOT NULL
/*WHERE BidAppLaneID = 600*/

/*
Get lines from the USCTTDEV.dbo.tblBidAppRates where they no longer exist in the TM Data
DROP TABLE IF EXISTS ##tblBidAppRatesMissing
*/
SELECT bar.* INTO ##tblBidAppRatesMissing
/*SELECT **/
FROM USCTTDEV.dbo.tblBidAppRates bar
LEFT JOIN ##tblTMTariffTemp ttt ON ttt.BidAppLaneID = bar.LaneID
AND ttt.SERVICE = bar.SCAC
WHERE bar.SCAC IS NULL

/*
DELETE ##tblTMTariffTemp if everything matches Bid App Rates/Lanes table
SELECT * FROM ##tblTMTariffTemp
*/
DELETE FROM ##tblTMTariffTemp WHERE BidAppRateMatch = 'Yes'

/*
Update if Lane Does Not Exist
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'LaneMissing'	    AND TABLE_NAME LIKE '##tblTMTariffTemp') ALTER TABLE ##tblTMTariffTemp ADD LaneMissing  	NVARCHAR(10) NULL
*/
UPDATE ##tblTMTariffTemp SET LaneMissing = 'Yes' WHERE BidAppLaneID IS NULL

/*
Update 
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'RateMissing'    	AND TABLE_NAME LIKE '##tblTMTariffTemp') ALTER TABLE ##tblTMTariffTemp ADD RateMissing  	NVARCHAR(10) NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'ErrorType'    	    AND TABLE_NAME LIKE '##tblTMTariffTemp') ALTER TABLE ##tblTMTariffTemp ADD ErrorType  	    NVARCHAR(10) NULL
*/
UPDATE ##tblTMTariffTemp SET RateMissing = 'Yes' WHERE BidAppRate IS NULL AND BidAppFlatCharge IS NULL

/*
Update Error Type
SELECT * FROM ##tblTMTariffTemp WHERE ERRORType IS NULL
*/
UPDATE ##tblTMTariffTemp SET ErrorType =
CASE WHEN LaneMissing = 'Yes' AND RateMissing = 'Yes' THEN 'Missing Lane And Rate'
WHEN LaneMissing = 'Yes' THEN 'Missing Lane'
WHEN RateMissing = 'Yes' THEN 'Missing Rate'
WHEN BidAppRateMatch = 'No' THEN 'TM Rate Does Not Match Bid App'
WHEN [Rate Per Mile] > 0 AND [Min Charge] > 0 THEN 'Has Min Charge and Flat Rate'
ELSE Null
END

/*
If the Error type is 'TM Rate Does Not Match Bid App' then look through the changelog, and see if there's an entry on it for CUR_RPM
SELECT * FROM USCTTDEV.dbo.tblBIdAppChangelog cl
INNER JOIN (SELECT DISTINCT LaneID, SCAC, Max(ID) as MaxID FROM USCTTDEV.dbo.tblBidAppChangelog WHERE Field = 'CUR_RPM' OR Field = 'Min Charge' GROUP BY LaneID, SCAC) max ON max.MaxID = cl.ID
WHERE Field = 'CUR_RPM' OR Field = 'Min Charge' 
SELECT * FROM ##tblTMTariffTemp WHERE ErrorType = 'Changelog Match'
*/
UPDATE ##tblTMTariffTemp 
SET ErrorType = CASE WHEN cl.Field = 'CUR_RPM' AND CAST(cl.NewValue AS NUMERIC(18,2)) = CAST([Rate Per Mile] AS NUMERIC(18,2)) THEN 'Changelog Match'
WHEN cl.Field = 'Min Charge' AND CAST(cl.NewValue AS NUMERIC(18,2)) = CAST([Min Charge] AS NUMERIC(18,2)) THEN 'Changelog Match'
ELSE ErrorType END
FROM ##tblTMTariffTemp ttt
INNER JOIN (SELECT * FROM USCTTDEV.dbo.tblBIdAppChangelog cl
INNER JOIN (SELECT DISTINCT LaneID AS LaneID2, SCAC AS SCAC2, Max(ID) AS MaxID FROM USCTTDEV.dbo.tblBidAppChangelog WHERE ChangeType = 'Rate Level - RPM' GROUP BY LaneID, SCAC) max ON max.MaxID = cl.ID
WHERE Field = 'CUR_RPM' OR Field = 'Min Charge') cl ON cl.LaneID = ttt.BidAppLaneID
AND cl.SCAC = ttt.Service

/*
Update Changelog To Match if in Changelog
SELECT * FROM ##tblTMTariffTemp WHERE Changelog iS NOT NULL
*/
UPDATE ##tblTMTariffTemp 
SET Changelog = cl.UpdatedByName+' / '+CAST(CAST(cl.UpdatedOn AS DATE) AS NVARCHAR(15))+' / '+cl.NewValue,
ChangelogType = CASE WHEN CAST(cl.UpdatedOn AS DATE) > CAST([TM Effective Date] AS DATE) THEN 'Changelog After TM Effective Date' ELSE 'Changelog Before TM Effective Date' END 
FROM ##tblTMTariffTemp ttt
INNER JOIN (SELECT * FROM USCTTDEV.dbo.tblBIdAppChangelog cl
INNER JOIN (SELECT DISTINCT LaneID AS LaneID2, SCAC AS SCAC2, Max(ID) AS MaxID FROM USCTTDEV.dbo.tblBidAppChangelog WHERE ChangeType = 'Rate Level - RPM' GROUP BY LaneID, SCAC) max ON max.MaxID = cl.ID
WHERE Field = 'CUR_RPM' OR Field = 'Min Charge') cl ON cl.LaneID = ttt.BidAppLaneID
AND cl.SCAC = ttt.Service


