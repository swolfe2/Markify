/*
Create temp table
*/
CREATE TABLE ##tblChangelogTemp(
LaneID NVARCHAR(20),
Lane NVARCHAR(20),
ChangeType NVARCHAR(20),
ChangeReason NVARCHAR(50),
SCAC NVARCHAR(10),
Field NVARCHAR(10),
PreviousValue NVARCHAR(10),
NewValue NVARCHAR(10),
UpdatedBy NVARCHAR(50),
UpdatedByName NVARCHAR(50),
UpdatedOn Datetime
)

/*
Insert lanes into Temp Table
*/
INSERT INTO ##tblChangelogTemp (LaneID, SCAC, Lane, PreviousValue)
SELECT bar.LaneID, bar.SCAC, bar.Lane, bar.AWARD_PCT FROM USCTTDEV.dbo.tblBidAppRatesRFP2021 bar
INNER JOIN (
SELECT 'CURAMOSA-5WI54956' AS Lane UNION ALL
SELECT 'CURAMOSA-5CA92374' AS Lane UNION ALL
SELECT 'AGSANFRA-5IL60446' AS Lane UNION ALL
SELECT 'AGAGUASC-5IL60446' AS Lane UNION ALL
SELECT 'AGSANFRA-5TX75236' AS Lane) remove ON remove.Lane = bar.Lane
WHERE bar.AWARD_PCT IS NOT NULL
ORDER BY bar.LaneID ASC, bar.SCAC ASC

/*
Update rate information on changelog table
*/
UPDATE ##tblChangelogTemp
SET ChangeType = 'Rate Level',
ChangeReason = 'Mass Update Award Percent',
Field = 'AWARD_PCT',
NewValue = '0',
UpdatedBy = 'B40962',
UpdatedByName = 'Stelios Chrysandreas',
UpdatedOn = GETDATE()

/*
Update Bid App Rates table to remove award loads/pct
*/
UPDATE USCTTDEV.dbo.tblBidAppRatesRFP2021
SET AWARD_LDS = NULL,
AWARD_PCT = NULL
FROM USCTTDEV.dbo.tblBidAppRatesRFP2021 bar
INNER JOIN ##tblChangelogTemp clt ON clt.LaneID = bar.LaneID
AND clt.SCAC = bar.SCAC

/*
View table just before appending!
*/
SELECT * FROM ##tblChangelogTemp
ORDER BY LaneID ASC, SCAC ASC

/*
Append changes into changelog
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

/*
Execute stored procedures
*/
EXEC USCTTDEV.dbo.sp_AwardWeightedAveragesRFP

EXEC USCTTDEV.dbo.sp_BidAppRatesRank

DROP TABLE IF EXISTS ##tblChangelogTemp