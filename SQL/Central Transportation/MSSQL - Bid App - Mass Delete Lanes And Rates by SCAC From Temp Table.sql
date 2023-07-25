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

DECLARE @SCAC NVARCHAR(5)
SET @SCAC = 'TPGH'

/*
Insert rates to be deleted
SELECT * FROM ##tblChangelogTemp ORDER BY LaneID ASC
*/
INSERT INTO ##tblChangelogTemp (LaneID, Lane, ChangeType, ChangeReason, SCAC, Field, PreviousValue)
SELECT bar.LaneID,
bar.Lane, 
'Rate Level',
'Mass Rate Delete',
bar.SCAC, 
CASE WHEN bar.[Min Charge] IS NOT NULL THEN 'Min Charge' ELSE 'CUR_RPM' END,
CASE WHEN bar.[Min Charge] IS NOT NULL THEN bar.[Min Charge] ELSE bar.CUR_RPM END
FROM USCTTDEV.dbo.tblBidAppRates bar
WHERE bar.SCAC = @SCAC
ORDER BY bar.LaneID ASC, bar.SCAC ASC

/*
Insert awards that will be deleted
SELECT * FROM USCTTDEV.dbo.tblBidAppRates bar WHERE SCAC = 'TPGH' AND bar.AWARD_PCT IS NOT NULL
*/
INSERT INTO ##tblChangelogTemp (LaneID, Lane, ChangeType, ChangeReason, SCAC, Field, PreviousValue)
SELECT bar.LaneID,
bar.Lane, 
'Rate Level',
'Mass Rate Delete',
bar.SCAC, 
'AWARD_PCT',
bar.AWARD_PCT
FROM USCTTDEV.dbo.tblBidAppRates bar
WHERE bar.SCAC = @SCAC
AND bar.AWARD_PCT IS NOT NULL
ORDER BY bar.LaneID ASC, bar.SCAC ASC

/*
Final Changelog Updates
SELECT * FROM ##tblChangelogTemp WHERE Field <> 'AWARD_PCT'
SELECT * INTO ##tblBidAppRatesRFPTempy FROM USCTTDEV.dbo.tblBidAppRates 
SELECT DISTINCT UpdatedBy, UpdatedByName, MAX(UpdatedOn) AS MaxUpdated
FROM USCTTDEV.dbo.tblBidAppChangelog
GROUP BY UpdatedBy, UpdatedByName
ORDER BY MAX(UpdatedOn) DESC
*/
UPDATE ##tblChangelogTemp
SET
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
*/
DELETE USCTTDEV.dbo.tblBidAppRates
FROM  USCTTDEV.dbo.tblBidAppRates bar
INNER JOIN (SELECT DISTINCT LaneID, SCAC FROM  ##tblChangelogTemp) clt ON clt.LaneID = bar.LaneID
AND clt.SCAC = bar.SCAC

/*
Insert changes into changelog
SELECT * FROM USCTTDEV.dbo.tblBidAppChangelog WHERE UpdatedOn = '2020-12-18 11:57:35.610'
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
CASE WHEN clt.ChangeReason LIKE '%Lane%' THEN 'tblBidAppLanes' ELSE 'tblBidAppRates' END
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