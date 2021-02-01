DROP TABLE IF EXISTS ##tblChangelogTemp

/*
Create the temp table
*/
CREATE TABLE ##tblChangelogTemp(
LaneID NVARCHAR(20),
Lane NVARCHAR(50),
ChangeType NVARCHAR(20),
ChangeReason NVARCHAR(50),
SCAC NVARCHAR(10),
Field NVARCHAR(10),
PreviousValue NVARCHAR(50),
NewValue NVARCHAR(10),
UpdatedBy NVARCHAR(50),
UpdatedByName NVARCHAR(50),
UpdatedOn Datetime
)

/*
Add the lanes to be deleted
="SELECT '" & B3 & "' AS Lane, '" & O3 & "' AS SCAC UNION ALL"
*/
INSERT INTO ##tblChangelogTemp (LaneID,  Lane, SCAC, PreviousValue, Field)
SELECT DISTINCT bar.LaneID,  
remove.Lane, 
remove.SCAC, 
CASE WHEN bar.[Min Charge] IS NOT NULL THEN bar.[Min Charge] ELSE bar.CUR_RPM END AS PreviousValue,
CASE WHEN bar.[Min Charge] IS NOT NULL THEN 'Min Charge' ELSE 'CUR_RPM' END AS Field
FROM USCTTDEV.dbo.tblBidAppRatesRFP2021 bar
INNER JOIN (SELECT 'ALFAIRHO-5AL36610' AS Lane, 'SWOA' AS SCAC UNION ALL
SELECT 'KCILROME-SKIN-5IL60586' AS Lane, 'KNBK' AS SCAC 
) remove ON remove.Lane = bar.Lane
AND remove.SCAC = bar.SCAC
ORDER BY bar.LaneID ASC

/*
Update Lane Level Deletions text
*/
UPDATE ##tblChangelogTemp
SET ChangeType = 'Rate Level',
ChangeReason = 'Mass Rate Delete',
UpdatedBy = 'B40962',
UpdatedByName = 'Stelios Chrysandreas',
UpdatedOn = GETDATE()

/*
Check table first
*/
SELECT * FROM ##tblChangelogTemp
ORDER BY CAST(LaneID AS INT) ASC, SCAC ASC

/*
Delete from Bid App Rates
SELECT * INTO ##tblBidAppRates2021Tempy2 FROM USCTTDEV.dbo.tblBidAppRatesRFP2021 
*/
DELETE USCTTDEV.dbo.tblBidAppRatesRFP2021
FROM  USCTTDEV.dbo.tblBidAppRatesRFP2021 bar
INNER JOIN (SELECT DISTINCT LaneID, SCAC FROM  ##tblChangelogTemp) clt ON clt.LaneID = bar.LaneID
AND clt.SCAC = bar.SCAC

/*
Insert changes into changelog
DELETE FROM USCTTDEV.dbo.tblBidAppChangelog WHERE UpdatedOn = '2020-12-11 08:25:01.877'
*/
INSERT INTO USCTTDEV.dbo.tblBIdAppChangelog(LaneID, Lane, ChangeType, ChangeReason, SCAC, Field, PreviousValue, NewValue, UpdatedBy, UpdatedByName, UpdatedOn, ChangeTable)
SELECT clt.LaneID,
clt.Lane,
clt.ChangeType, 
clt.ChangeReason,
clt.SCAC,
clt.Field,
clt.PreviousValue,
clt.NewValue,
clt.UpdatedBy,
clt.UpdatedByName,
clt.UpdatedOn,
'tblBidAppRatesRFP2021'
FROM ##tblChangelogTemp clt
LEFT JOIN USCTTDEV.dbo.tblBIdAppChangelog cl ON clt.LaneID = cl.LaneID
AND cl.SCAC = clt.SCAC
AND CAST(cl.UpdatedOn AS DATE) = CAST(clt.UpdatedOn AS DATE)
WHERE cl.LaneID IS NULL
AND cl.SCAC IS NULL
ORDER BY CAST(clt.LaneID AS INT) ASC, clt.SCAC ASC

EXEC USCTTDEV.dbo.sp_AwardWeightedAveragesRFP

EXEC USCTTDEV.dbo.sp_BidAppRatesRank

DROP TABLE IF EXISTS ##tblChangelogTemp