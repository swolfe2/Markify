DROP TABLE IF EXISTS ##tblChangelogTemp

/*
Create temp table
*/
CREATE TABLE ##tblChangelogTemp(
LaneID NVARCHAR(20),
Lane NVARCHAR(50),
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
SELECT * FROM ##tblChangelogTemp WHERE PreviousValue IS NULL
SELECT DISTINCT ChangeType FROM USCTTDEV.dbo.tblBidAppChangelog
SELECT DISTINCT ChangeReason FROM USCTTDEV.dbo.tblBidAppChangelog
SELECT * FROM USCTTDEV.dbo.tblBidAppChangelog WHERE Lane = 'TXDALLAS-5IL60446' AND SCAC = 'CRPS'
SELECT TOP 10 * FROM USCTTDEV.dbo.tblBidAppChangelog
="SELECT '" & B2 & "' AS Lane, '" & P2 & "' AS SCAC " & IF(ISBLANK(B3),"","UNION ALL")
*/
INSERT INTO ##tblChangelogTemp (LaneID, Lane, ChangeType, ChangeReason, SCAC, Field, PreviousValue, NewValue, UpdatedBy, UpdatedByName, UpdatedOn)
SELECT bar.LaneID, remove.Lane, 'Rate Level - Mass', 'Mass Update Award Percent', remove.SCAC, 'AWARD_PCT', bar.AWARD_PCT, 0, 
'B40962', 'Stelios Chrysandreas', GETDATE()
FROM 
(
SELECT 'GAMCDONO-5GA30062' AS Lane, 'BRJF' AS SCAC UNION ALL
SELECT 'SCDUNCAN-5SC29842' AS Lane, 'BRJF' AS SCAC ) remove 
LEFT JOIN USCTTDEV.dbo.tblBidAppRatesRFP2021 bar ON bar.Lane = remove.Lane
AND bar.SCAC = remove.SCAC
ORDER BY bar.LaneID ASC, bar.SCAC ASC

/*
Delete where there's no Previous Value 
Lane was already not awarded
SELECT * FROM ##tblChangelogTemp WHERE PreviousValue IS NULL
*/
DELETE FROM ##tblChangelogTemp WHERE PreviousValue IS NULL

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

SELECT DISTINCT UpdatedBy, UpdatedByName, MAX(UpdatedOn) AS MaxUpdated FROM USCTTDEV.dbo.tblBidAppChangelog GROUP BY UpdatedBy, UpdatedByName ORDER BY MaxUpdated DESC
*/

UPDATE ##tblChangelogTemp
SET UpdatedByName = 'Scottie Carpenter',
UpdatedBy = 'B73503'

SELECT * FROM ##tblChangelogTemp
ORDER BY CAST(LaneID AS INT) ASC, SCAC ASC

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
AND cl.Field = clt.Field
AND CAST(cl.UpdatedOn AS DATE) = CAST(clt.UpdatedOn AS DATE)
WHERE cl.LaneID IS NULL
AND cl.SCAC IS NULL
AND cl.Field IS NULL
ORDER BY CAST(clt.LaneID AS INT) ASC, clt.SCAC ASC

/*
Execute stored procedures
*/
EXEC USCTTDEV.dbo.sp_AwardWeightedAveragesRFP

EXEC USCTTDEV.dbo.sp_BidAppRatesRank

DROP TABLE IF EXISTS ##tblChangelogTemp