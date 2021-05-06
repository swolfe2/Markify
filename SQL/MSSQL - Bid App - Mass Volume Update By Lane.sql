DROP TABLE IF EXISTS ##tblChangelogTemp

/*
Create the temp table
*/
CREATE TABLE ##tblChangelogTemp(
LaneID NVARCHAR(20),
Lane NVARCHAR(50),
ChangeType NVARCHAR(50),
ChangeReason NVARCHAR(50),
SCAC NVARCHAR(10),
Field NVARCHAR(20),
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

Excel Formula
="SELECT '" & B3 & "' AS LANE, CAST('" & H3 & "' AS INT) AS NewValue UNION ALL"
*/
INSERT INTO ##tblChangelogTemp (LaneID,  Lane, ChangeType, ChangeReason, Field, PreviousValue, NewValue)
SELECT DISTINCT bal.LaneID,  
bal.Lane, 
'Lane Level',
'Mass Volume Update',
'UPDATED_LOADS', 
bal.UPDATED_LOADS,
Change.NewValue
FROM (SELECT 'SCBEECIS-5GA30253' AS LANE, CAST('9705' AS INT) AS NewValue UNION ALL
SELECT 'WIAPPLET-5GA30253' AS LANE, CAST('2175' AS INT) AS NewValue UNION ALL
SELECT 'TXDALLAS-5CA91761' AS LANE, CAST('1979' AS INT) AS NewValue UNION ALL
SELECT 'TNLOUDON-5PA19013' AS LANE, CAST('1362' AS INT) AS NewValue UNION ALL
SELECT 'TXDALLAS-5TX78666' AS LANE, CAST('774' AS INT) AS NewValue UNION ALL
SELECT 'CTNEWMIL-5PA18517' AS LANE, CAST('767' AS INT) AS NewValue UNION ALL
SELECT 'SCBEECIS-5OK74037' AS LANE, CAST('3174' AS INT) AS NewValue UNION ALL
SELECT 'PATAYLOR-5CT06776' AS LANE, CAST('612' AS INT) AS NewValue UNION ALL
SELECT 'ALMOBILE-5PA19013' AS LANE, CAST('660' AS INT) AS NewValue UNION ALL
SELECT 'PATAYLOR-5PA19013' AS LANE, CAST('520' AS INT) AS NewValue UNION ALL
SELECT 'SCBEECIS-5PA18517' AS LANE, CAST('495' AS INT) AS NewValue UNION ALL
SELECT 'KCILROME-NOF-ONMILTON' AS LANE, CAST('445' AS INT) AS NewValue UNION ALL
SELECT 'KCILROME-NOF-5GA30253' AS LANE, CAST('330' AS INT) AS NewValue UNION ALL
SELECT 'SCBEECIS-5IL60446' AS LANE, CAST('2939' AS INT) AS NewValue UNION ALL
SELECT 'UTOGDEN-5IL60446' AS LANE, CAST('1065' AS INT) AS NewValue UNION ALL
SELECT 'KCILROME-NOF-5PA19555' AS LANE, CAST('300' AS INT) AS NewValue UNION ALL
SELECT 'OKJENKS-5IL60446' AS LANE, CAST('1452' AS INT) AS NewValue UNION ALL
SELECT 'SCBEECIS-5CT06776' AS LANE, CAST('3102' AS INT) AS NewValue UNION ALL
SELECT 'KCILROME-NOF-5AR72032' AS LANE, CAST('182' AS INT) AS NewValue UNION ALL
SELECT 'WINEENAH-5IL60446' AS LANE, CAST('3390' AS INT) AS NewValue UNION ALL
SELECT 'ONHUNTSV-5PA19013' AS LANE, CAST('529' AS INT) AS NewValue UNION ALL
SELECT 'ALMOBILE-5AL36582' AS LANE, CAST('1024' AS INT) AS NewValue UNION ALL
SELECT 'CTNEWMIL-5TX75236' AS LANE, CAST('208' AS INT) AS NewValue UNION ALL
SELECT 'OKJENKS-5GA30906' AS LANE, CAST('60' AS INT) AS NewValue UNION ALL
SELECT 'UTOGDEN-5GA30253' AS LANE, CAST('52' AS INT) AS NewValue UNION ALL
SELECT 'TXPARIS-5AR72032' AS LANE, CAST('216' AS INT) AS NewValue
) change
LEFT JOIN USCTTDEV.dbo.tblBidAppLanes bal ON bal.Lane = change.Lane
ORDER BY bal.LaneID ASC

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
SELECT * FROM ##tblChangelogTemp
SELECT * INTO ##tblBidAppRatesTemp FROM USCTTDEV.dbo.tblBidAppRates
SELECT * FROM ##tblChangelogTemp WHERE LaneID = 66 AND SCAC = 'HUBG'
SELECT * FROM USCTTDEV.dbo.tblBidAppRates WHERE LaneID = 66 AND SCAC = 'HUBG'
SELECT * INTO ##tblBidAppLanesTempy FROM USCTTDEV.dbo.tblBidAppLanes
*/
UPDATE USCTTDEV.dbo.tblBidAppLanes
SET UPDATED_LOADS = cl.NewValue
FROM USCTTDEV.dbo.tblBidAppLanes bal
INNER JOIN ##tblChangelogTemp cl ON cl.LaneID = bal.LaneID

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
'tblBidAppLanes'
FROM ##tblChangelogTemp clt
LEFT JOIN USCTTDEV.dbo.tblBIdAppChangelog cl ON clt.LaneID = cl.LaneID
AND cl.Field = clt.Field
AND CAST(cl.UpdatedOn AS DATE) = CAST(clt.UpdatedOn AS DATE)
WHERE cl.LaneID IS NULL
AND cl.Field IS NULL
ORDER BY CAST(clt.LaneID AS INT) ASC, clt.SCAC ASC

EXEC USCTTDEV.dbo.sp_AwardWeightedAveragesRFP

EXEC USCTTDEV.dbo.sp_BidAppRatesRank

DROP TABLE IF EXISTS ##tblChangelogTemp
