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
Insert rates to be deleted
SELECT * FROM ##tblChangelogTemp ORDER BY LaneID ASC
="SELECT '" & B4 & "' AS Lane, '" & M4 & "' AS SCAC UNION ALL"
*/
INSERT INTO ##tblChangelogTemp (LaneID, Lane, ChangeType, ChangeReason, SCAC, Field, PreviousValue)
SELECT bar.LaneID,
bar.Lane, 
'Rate Level',
'Mass Rate Delete',
bar.SCAC, 
CASE WHEN bar.[Min Charge] IS NOT NULL THEN 'Min Charge' ELSE 'CUR_RPM' END,
CASE WHEN bar.[Min Charge] IS NOT NULL THEN bar.[Min Charge] ELSE bar.CUR_RPM END
FROM USCTTDEV.dbo.tblBidAppRatesRFP2021 bar
INNER JOIN (
SELECT 'ARCONWAY-5OK74116' AS Lane, 'AFXN' AS SCAC UNION ALL
SELECT 'MSCORINT-5NC28792' AS Lane, 'AFXN' AS SCAC UNION ALL
SELECT 'ARCONWAY-5TX75460' AS Lane, 'AFXN' AS SCAC UNION ALL
SELECT 'MSGRENAD-5AL36610' AS Lane, 'AFXN' AS SCAC UNION ALL
SELECT 'MSCORINT-5TX75460' AS Lane, 'AFXN' AS SCAC UNION ALL
SELECT 'ARFTSMIT-5AR72032' AS Lane, 'AFXN' AS SCAC UNION ALL
SELECT 'WIGERMAN-5IL62060' AS Lane, 'AFXN' AS SCAC
)remove ON remove.Lane = bar.Lane
AND remove.SCAC = bar.SCAC
ORDER BY bar.LaneID ASC, bar.SCAC ASC

/*
Delete where there's no Previous Value 
Lane was already not awarded
SELECT * FROM ##tblChangelogTemp WHERE PreviousValue IS NULL
*/
DELETE FROM ##tblChangelogTemp WHERE PreviousValue IS NULL

/*
Insert awards that will be deleted
SELECT * FROM USCTTDEV.dbo.tblBidAppRatesRFP2021 bar WHERE SCAC = 'TPGH' AND bar.AWARD_PCT IS NOT NULL
="SELECT '" & B4 & "' AS Lane, '" & M4 & "' AS SCAC UNION ALL"
*/
INSERT INTO ##tblChangelogTemp (LaneID, Lane, ChangeType, ChangeReason, SCAC, Field, PreviousValue)
SELECT bar.LaneID,
bar.Lane, 
'Rate Level',
'Mass Rate Delete',
bar.SCAC, 
'AWARD_PCT',
bar.AWARD_PCT
FROM USCTTDEV.dbo.tblBidAppRatesRFP2021 bar
INNER JOIN (
SELECT 'ARCONWAY-5OK74116' AS Lane, 'AFXN' AS SCAC UNION ALL
SELECT 'MSCORINT-5NC28792' AS Lane, 'AFXN' AS SCAC UNION ALL
SELECT 'ARCONWAY-5TX75460' AS Lane, 'AFXN' AS SCAC UNION ALL
SELECT 'MSGRENAD-5AL36610' AS Lane, 'AFXN' AS SCAC UNION ALL
SELECT 'MSCORINT-5TX75460' AS Lane, 'AFXN' AS SCAC UNION ALL
SELECT 'ARFTSMIT-5AR72032' AS Lane, 'AFXN' AS SCAC UNION ALL
SELECT 'WIGERMAN-5IL62060' AS Lane, 'AFXN' AS SCAC
)remove ON remove.Lane = bar.Lane
AND remove.SCAC = bar.SCAC
WHERE bar.AWARD_PCT IS NOT NULL
ORDER BY bar.LaneID ASC, bar.SCAC ASC

/*
Final Changelog Updates
SELECT * FROM ##tblChangelogTemp WHERE Field <> 'AWARD_PCT'
SELECT * INTO ##tblBidAppRatesRFPTempy FROM USCTTDEV.dbo.tblBidAppRatesRFP2021 
*/
UPDATE ##tblChangelogTemp
SET
UpdatedBy = 'B40962',
UpdatedByName = 'Stelios Chrysandreas',
UpdatedOn = GETDATE()

/*
Check table first
SELECT * FROM USCTTDEV.dbo.tblBidAppRatesRFP2021 WHERE LaneID = 20
*/
SELECT * FROM ##tblChangelogTemp
ORDER BY CAST(LaneID AS INT) ASC, SCAC ASC, Field ASC

/*
Delete from Bid App Rates
*/
DELETE USCTTDEV.dbo.tblBidAppRatesRFP2021
FROM  USCTTDEV.dbo.tblBidAppRatesRFP2021 bar
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
CASE WHEN clt.ChangeReason LIKE '%Lane%' THEN 'tblBidAppLanesRFP2021' ELSE 'tblBidAppRatesRFP2021' END
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