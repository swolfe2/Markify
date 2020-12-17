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
*/
INSERT INTO ##tblChangelogTemp (LaneID,  Lane)
SELECT DISTINCT bar.LaneID,  bar.Lane FROM USCTTDEV.dbo.tblBidAppRatesRFP2021 bar
INNER JOIN (SELECT 'GAMCDONO-5CA92374' AS LANE UNION ALL
SELECT 'ILDESPLA-5CA92374' AS LANE UNION ALL
SELECT 'KCILROME-NOF-5CA92374' AS LANE UNION ALL
SELECT 'ALMOBILE-5CA92374' AS LANE UNION ALL
SELECT 'MSCORINT-5CA92374' AS LANE UNION ALL
SELECT 'NCOAKBOR-5CA92374' AS LANE UNION ALL
SELECT 'KCILROME-KCP-5CA92374' AS LANE UNION ALL
SELECT 'KCILROME-SKIN-5CA92374' AS LANE UNION ALL
SELECT 'CURAMOSA-5CA92374' AS LANE UNION ALL
SELECT 'EMCUAUTI-5CA92374' AS LANE
) remove ON remove.Lane = bar.Lane
ORDER BY bar.LaneID ASC

/*
Update Lane Level Deletions text
*/
UPDATE ##tblChangelogTemp
SET ChangeType = 'Lane Level',
ChangeReason = 'Mass Lane Delete',
Field = 'Lane',
PreviousValue = Lane,
UpdatedBy = 'B40962',
UpdatedByName = 'Stelios Chrysandreas',
UpdatedOn = GETDATE()

/*
Insert rates to be deleted
*/
INSERT INTO ##tblChangelogTemp (LaneID, Lane, ChangeType, ChangeReason, SCAC, Field, PreviousValue)
SELECT bar.LaneID,
bar.Lane, 
'Rate Level',
'Mass Rate Delete',
bar.SCAC, 
CASE WHEN bar.[Min Charge] IS NOT NULL THEN 'MIn Charge' ELSE 'CUR_RPM' END,
CASE WHEN bar.[Min Charge] IS NOT NULL THEN bar.[Min Charge] ELSE bar.CUR_RPM END
FROM USCTTDEV.dbo.tblBidAppRatesRFP2021 bar
INNER JOIN ##tblChangelogTemp clt ON clt.Lane = bar.Lane
ORDER BY bar.LaneID ASC, bar.SCAC ASC


DELETE FROM ##tblChangelogTemp WHERE UpdatedOn IS NULL

/*
Update UpdatedBy/Name/On by LaneID
*/
UPDATE clt
SET UpdatedBy = cltOne.UpdatedBy,
UpdatedByName = cltOne.UpdatedByName,
UpdatedOn = cltOne.UpdatedOn
FROM ##tblChangelogTemp clt
LEFT JOIN ##tblChangelogTemp cltOne ON cltOne.LaneID = clt.LaneID
WHERE cltOne.UpdatedBy IS NOT NULL

/*
Check table first
*/
SELECT * FROM ##tblChangelogTemp
ORDER BY LaneID ASC, SCAC ASC

/*
Delete from Bid App Lanes
*/
DELETE USCTTDEV.dbo.tblBidAppLanesRFP2021
FROM  USCTTDEV.dbo.tblBidAppLanesRFP2021 bal
INNER JOIN (SELECT DISTINCT LaneID FROM  ##tblChangelogTemp) clt ON clt.LaneID = bal.LaneID

/*
Delete from Bid App Rates
*/
DELETE USCTTDEV.dbo.tblBidAppRatesRFP2021
FROM  USCTTDEV.dbo.tblBidAppRatesRFP2021 bar
INNER JOIN (SELECT DISTINCT LaneID FROM  ##tblChangelogTemp) clt ON clt.LaneID = bar.LaneID

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
CASE WHEN clt.ChangeReason LIKE '%Lane%' THEN 'tblBidAppLanesRFP2021' ELSE 'tblBidAppRatesRFP2021' END
FROM ##tblChangelogTemp clt
LEFT JOIN USCTTDEV.dbo.tblBIdAppChangelog cl ON clt.LaneID = cl.LaneID
AND cl.SCAC = clt.SCAC
AND CAST(cl.UpdatedOn AS DATE) = CAST(clt.UpdatedOn AS DATE)
WHERE cl.LaneID IS NULL
AND cl.SCAC IS NULL
ORDER BY clt.LaneID ASC, clt.SCAC ASC

EXEC USCTTDEV.dbo.sp_AwardWeightedAveragesRFP

EXEC USCTTDEV.dbo.sp_BidAppRatesRank