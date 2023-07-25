WITH forecast
AS (SELECT DISTINCT
  lfwa.Lane,
  lfwa.SnapshotWeek,
  DATEDIFF(ww, lfwa.SnapshotWeek, GETDATE()) AS SnapshotWeekDiff,
  RANK() OVER (PARTITION BY lfwa.Lane ORDER BY lfwa.SnapshotWeek DESC) AS SnapshotRank,
  lfwa.SendingWeek,
  DATEDIFF(ww, lfwa.SendingWeek, GETDATE()) AS SendingWeekDiff,
  SUM(COALESCE(lfwa.FCSTTL, 0)) AS TotalForecastLoads,
  ROW_NUMBER() OVER (PARTITION BY lfwa.Lane ORDER BY lfwa.SnapshotWeek DESC, lfwa.SendingWeek ASC) AS Rownumber
FROM USCTTDEV.dbo.tblLaneForecastWeekly lfwa
WHERE lfwa.SendingWeek < GETDATE()
AND lfwa.Lane IS NOT NULL
/*AND lfwa.Lane = 'UTOGDEN-5TX75236'*/
GROUP BY lfwa.Lane,
         lfwa.SendingWeek,
         lfwa.SnapshotWeek
HAVING DATEDIFF(ww, lfwa.SnapshotWeek, GETDATE()) <= 8)

SELECT DISTINCT
  weeks.TheFirstOfWeekMon,
  forecastAgg.Lane,
  forecastAgg.SendingWeek,
  SUM(forecastAgg.ThisWeeksLoads) AS ThisWeeksLoads,
  SUM(forecastAgg.TwoWeeksAgo) AS TwoWeeksAgo,
  SUM(forecastAgg.ThreeWeeksAgo) AS ThreeWeeksAgo,
  SUM(forecastAgg.FourWeeksAgo) AS FourWeeksAgo,
  SUM(forecastAgg.FiveWeeksAgo) AS FiveWeeksAgo,
  SUM(forecastAgg.SixWeeksAgo) AS SixWeeksAgo,
  SUM(forecastAgg.SevenWeeksAgo) AS SevenWeeksAgo,
  SUM(forecastAgg.EightWeeksAgo) AS EightWeeksAgo,
  actuals.TotalLoadCount,
  actuals.NonLTLLoadCount

FROM (SELECT DISTINCT
  da.TheFirstOfWeekMon
FROM USCTTDEV.dbo.tblDates da
GROUP BY da.TheFirstOfWeekMon
HAVING DATEDIFF(ww, da.TheFirstOfWeekMon, GETDATE()) BETWEEN 0 AND 8) weeks

LEFT JOIN (SELECT DISTINCT
  forecast.Lane,
  forecast.SendingWeek,
  COALESCE(CASE
    WHEN forecast.SnapshotWeekDiff = 1 THEN TotalForecastLoads
  END, 0) AS ThisWeeksLoads,
  COALESCE(CASE
    WHEN forecast.SnapshotWeekDiff = 2 THEN forecast.TotalForecastLoads
  END, 0) AS TwoWeeksAgo,
  COALESCE(CASE
    WHEN forecast.SnapshotWeekDiff = 3 THEN forecast.TotalForecastLoads
  END, 0) AS ThreeWeeksAgo,
  COALESCE(CASE
    WHEN forecast.SnapshotWeekDiff = 4 THEN forecast.TotalForecastLoads
  END, 0) AS FourWeeksAgo,
  COALESCE(CASE
    WHEN forecast.SnapshotWeekDiff = 5 THEN forecast.TotalForecastLoads
  END, 0) AS FiveWeeksAgo,
  COALESCE(CASE
    WHEN forecast.SnapshotWeekDiff = 6 THEN forecast.TotalForecastLoads
  END, 0) AS SixWeeksAgo,
  COALESCE(CASE
    WHEN forecast.SnapshotWeekDiff = 7 THEN forecast.TotalForecastLoads
  END, 0) AS SevenWeeksAgo,
  COALESCE(CASE
    WHEN forecast.SnapshotWeekDiff = 8 THEN forecast.TotalForecastLoads
  END, 0) AS EightWeeksAgo
FROM forecast) forecastAgg
  ON forecastAgg.SendingWeek = weeks.TheFirstOfWeekMon

LEFT JOIN (SELECT DISTINCT
  ald.Lane,
  da.TheFirstOfWeekMon,
  COUNT(DISTINCT ald.LD_LEG_ID) AS TotalLoadCount,
  SUM(CASE
    WHEN ald.EQMT_TYP <> 'LTL' THEN 1
    ELSE 0
  END) AS NonLTLLoadCount
FROM USCTTDEV.dbo.tblActualLoadDetail ald
INNER JOIN USCTTDEV.dbo.tblDates da
  ON da.TheDate =
  CAST(CASE
    WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
    WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
    ELSE ald.CRTD_DTT
  END AS date)
/*WHERE ald.Lane = 'UTOGDEN-5TX75236'*/
GROUP BY ald.Lane,
         da.TheFirstOfWeekMon

HAVING DATEDIFF(ww, da.TheFirstOfWeekMon, GETDATE()) BETWEEN 0 AND 8) actuals
  ON actuals.Lane = forecastAgg.Lane
  AND actuals.TheFirstOfWeekMon = weeks.TheFirstOfWeekMon

GROUP BY weeks.TheFirstOfWeekMon,
         forecastAgg.Lane,
         forecastAgg.SendingWeek,
         actuals.TotalLoadCount,
         actuals.NonLTLLoadCount

ORDER BY weeks.TheFirstOfWeekMon ASC