SELECT DISTINCT LaneID,
Lane,
ORIG_CITY_STATE,
DEST_CITY_STATE,
UPDATED_LOADS,
AwardPCT,
AwardLoads,
WeeklyBase,
WeeklySurge,
LastWeekLoadCount,
MinShipDate,
MaxShipDate,
AwardLaneType,
CAST(ROUND((LastWeekLoadCount - WeeklySurge) / CAST(WeeklySurge AS NUMERIC(18,2)),4) AS NUMERIC(18,4)) AS PercentToSurge,
FORMAT(CAST(ROUND((LastWeekLoadCount - WeeklySurge) / CAST(WeeklySurge AS NUMERIC(18,2)),4) AS NUMERIC(18,4)),'P') AS PercentToSurgeText
FROM (SELECT DISTINCT bal.LaneID,
bal.Lane,
bal.ORIG_CITY_STATE,
bal.DEST_CITY_STATE,
bal.UPDATED_LOADS,
FORMAT(SUM(bar.AWARD_PCT),'P') as AwardPCT,
CAST(ROUND(bal.UPDATED_LOADS * SUM(bar.AWARD_PCT),0) AS INT) AS AwardLoads,
CASE WHEN CAST(ROUND(bal.UPDATED_LOADS * SUM(bar.AWARD_PCT),0) AS INT) / 52 < 1 THEN 1 ELSE CAST(ROUND(bal.UPDATED_LOADS * SUM(bar.AWARD_PCT),0) AS INT) / 52 END AS WeeklyBase,
CASE WHEN CAST(ROUND(CAST(ROUND(bal.UPDATED_LOADS * SUM(bar.AWARD_PCT),0) AS INT) / 52 * 1.15,0) AS INT) <= 1 THEN 1 ELSE CAST(ROUND(CAST(ROUND(bal.UPDATED_LOADS * SUM(bar.AWARD_PCT),0) AS INT) / 52 * 1.15,0) AS INT) END AS WeeklySurge,
lastWeekActuals.LoadCount AS LastWeekLoadCount,
lastWeekActuals.MinShipDate,
lastWeekActuals.MaxShipDate,
CASE WHEN SUM(bar.AWARD_PCT) IS NULL THEN 'Non-Award Lane' ELSE 'Award Lane' END AS AwardLaneType
FROM USCTTDEV.dbo.tblBidAppLanes bal
INNER JOIN USCTTDEV.dbo.tblBidAppRates bar ON bar.LaneID = bal.LaneID
INNER JOIN (
SELECT DISTINCT ald.Lane, MIN(CAST(ald.SHPD_DTT AS DATE)) AS MinShipDate, MAX(CAST(ald.SHPD_DTT AS DATE)) AS MaxShipDate, COUNT(DISTINCT ald.LD_LEG_ID) AS LoadCount
FROM USCTTDEV.dbo.tblActualLoadDetail ald
WHERE CAST(ald.SHPD_DTT AS DATE) >= DATEADD(week, DATEDIFF(week,0,GETDATE())-1,-1)
AND CAST(ald.SHPD_DTT AS DATE) < DATEADD(week, DATEDIFF(week,0,GETDATE()),-1)
AND ald.EQMT_TYP <> 'LTL'
GROUP BY ald.Lane
) lastWeekActuals ON lastWeekActuals.Lane = bal.Lane
GROUP BY bal.LaneID,
bal.Lane,
bal.ORIG_CITY_STATE,
bal.DEST_CITY_STATE,
bal.UPDATED_LOADS,
lastWeekActuals.LoadCount,
lastWeekActuals.MinShipDate,
lastWeekActuals.MaxShipDate) data
ORDER BY CAST(ROUND((LastWeekLoadCount - WeeklySurge) / CAST(WeeklySurge AS NUMERIC(18,2)),4) AS NUMERIC(18,4))  DESC

