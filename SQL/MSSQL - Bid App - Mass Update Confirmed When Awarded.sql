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
SELECT DISTINCT ChangeType FROM USCTTDEV.dbo.tblBidAppChangelog
SELECT DISTINCT ChangeReason FROM USCTTDEV.dbo.tblBidAppChangelog
SELECT DISTINCT Field FROM USCTTDEV.dbo.tblBidAppChangelog
SELECT * FROM ##tblChangelogTemp

SELECT * FROM USCTTDEV.dbo.tblBIdAppChangelog WHERE FIeld = 'Confirmed'
SELECT * FROM USCTTDEV.dbo.tblBidAppRatesRFP2021 WHERE Confirmed = 'N' AND AWARD_PCT IS NOT NULL

Excel Formula
="SELECT '" & E2 & "' AS Lane, CAST('" & ROUND(O2,2) & "' AS NUMERIC(10,2)) AS NewValue, '" & LEFT(B2,4) & "' AS SCAC UNION ALL"
*/
INSERT INTO ##tblChangelogTemp (LaneID,  Lane, ChangeType, ChangeReason, SCAC, Field, PreviousValue, NewValue)
SELECT DISTINCT bar.LaneID,  
bar.Lane, 
'Rate Level - Mass',
'Mass Update Confirmed',
bar.SCAC,  
'Confirmed',
bar.Confirmed, 
'Y'
FROM USCTTDEV.dbo.tblBIdAppLanesRFP2021 bal
INNER JOIN USCTTDEV.dbo.tblBidAppRatesRFP2021 bar ON bar.Lane = bal.Lane
WHERE bar.AWARD_PCT IS NOT NULL
AND bar.Confirmed = 'N'
ORDER BY bar.LaneID ASC, bar.SCAC ASC

/*
Remove from changelog temp where the LaneID does not exist
SELECT * FROM ##tblChangelogTemp WHERE LaneID IS NULL
*/
DELETE FROM ##tblChangelogTemp WHERE LaneID IS NULL

/*
Update Lane Level Deletions text
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
Update Bid App Rates with new rate info
SELECT * FROM ##tblChangelogTemp ORDER BY CAST(LaneID AS INT) ASC
SELECT * INTO ##tblBidAppRatesTemp FROM USCTTDEV.dbo.tblBidAppRatesRFP2021
SELECT * FROM ##tblChangelogTemp WHERE LaneID = 66 AND SCAC = 'HUBG'
SELECT * FROM USCTTDEV.dbo.tblBidAppRatesRFP2021 WHERE LaneID = 66 AND SCAC = 'HUBG'
*/
UPDATE USCTTDEV.dbo.tblBidAppRatesRFP2021
SET Confirmed = 'Y'
FROM USCTTDEV.dbo.tblBidAppRatesRFP2021 bar
INNER JOIN ##tblChangelogTemp cl ON cl.LaneID = bar.LaneID
AND cl.SCAC = bar.SCAC

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
AND cl.Field = clt.Field
AND CAST(cl.UpdatedOn AS DATE) = CAST(clt.UpdatedOn AS DATE)
WHERE cl.LaneID IS NULL
AND cl.SCAC IS NULL
AND cl.Field IS NULL

EXEC USCTTDEV.dbo.sp_AwardWeightedAveragesRFP

EXEC USCTTDEV.dbo.sp_BidAppRatesRank

DROP TABLE IF EXISTS ##tblChangelogTemp