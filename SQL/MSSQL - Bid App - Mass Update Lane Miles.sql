/*
Create temp table
DROP TABLE ##tblChangelogTemp
*/
CREATE TABLE ##tblChangelogTemp(
LaneID NVARCHAR(20),
Lane NVARCHAR(30),
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
="SELECT " & A2 & " AS LaneID, " & P2 &" AS Miles UNION ALL"
*/
INSERT INTO ##tblChangelogTemp (LaneID, Lane, PreviousValue, NewValue)
SELECT bal.LaneID, bal.Lane, CAST(bal.Miles AS NUMERIC(10,2)), CAST(miles.Miles AS NUMERIC(10,2)) FROM USCTTDEV.dbo.tblBidAppLanes bal
INNER JOIN (
SELECT 1660 AS LaneID, 1 AS Miles UNION ALL
SELECT 2251 AS LaneID, 1 AS Miles
) miles ON miles.LaneID = bal.LaneID
AND miles.Miles <> bal.MILES
ORDER BY bal.LaneID ASC

/*
Delete where New Value = Previous Value
*/
DELETE FROM ##tblChangelogTemp
WHERE PreviousValue = NewValue

/*
Update rate information on changelog table
SELECT DISTINCT UpdatedBy, UpdatedByName, MAX(UpdatedOn) AS MaxUpdated
FROM USCTTDEV.dbo.tblBidAppChangelog
GROUP BY UpdatedBy, UpdatedByName
ORDER BY MAX(UpdatedOn) DESC
*/
UPDATE ##tblChangelogTemp
SET ChangeType = 'Master Data',
ChangeReason = 'Mass Update Lane Miles',
Field = 'Miles',
UpdatedBy = 'B73503',
UpdatedByName = 'Scottie Carpenter',
UpdatedOn = GETDATE()

/*
Update Bid App Rates table to remove award loads/pct
*/
UPDATE USCTTDEV.dbo.tblBidAppLanes
SET Miles = clt.NewValue
FROM USCTTDEV.dbo.tblBidAppLanes bal
INNER JOIN ##tblChangelogTemp clt ON clt.LaneID = bal.LaneID

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
'tblBidAppRates'
FROM ##tblChangelogTemp clt
LEFT JOIN USCTTDEV.dbo.tblBIdAppChangelog cl ON clt.LaneID = cl.LaneID
AND cl.ChangeType = clt.ChangeType
AND cl.ChangeReason = clt.ChangeReason
AND CAST(cl.UpdatedOn AS DATE) = CAST(clt.UpdatedOn AS DATE)
WHERE cl.LaneID IS NULL
ORDER BY CAST(clt.LaneID AS INT) ASC, clt.SCAC ASC

/*
Execute stored procedures
*/
EXEC USCTTDEV.dbo.sp_AwardWeightedAveragesRFP

EXEC USCTTDEV.dbo.sp_BidAppRatesRank

DROP TABLE IF EXISTS ##tblChangelogTemp