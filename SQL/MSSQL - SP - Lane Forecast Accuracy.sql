USE [USCTTDEV]
GO
/****** Object:  StoredProcedure [dbo].[sp_LaneForecast]    Script Date: 5/18/2021 11:34:59 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Steve Wolfe, steve.wolfe@kcc.com, Central Transportation Team
-- Create date: 5/18/2021
-- Last modified: 
-- Description:	Appends/Updates USCTTDEV.dbo.tblLaneForecastAccuracy
-- =============================================

ALTER PROCEDURE [dbo].[sp_LaneForecastAccuracy]

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
DROP TABLE IF EXISTS ##tblLaneForecastAccuracyTemp;

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

SELECT * INTO ##tblLaneForecastAccuracyTemp

FROM (
SELECT DISTINCT
  weeks.TheFirstOfWeekMon,
  forecastAgg.Lane,
  forecastAgg.SendingWeek,
  SUM(forecastAgg.MostRecentForecast) AS MostRecentForecast,
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
  END, 0) AS MostRecentForecast,
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
) data
WHERE data.TheFirstOfWeekMon = CAST(DATEADD(wk, DATEDIFF(wk,0,GETDATE()), 0) AS DATE)
ORDER BY data.Lane ASC, data.TheFirstOfWeekMon ASC;

SELECT * FROM ##tblLaneForecastAccuracyTemp;

/*
Delete from the table if the row is no longer in the raw data for the available weeks
*/
DELETE FROM USCTTDEV.dbo.tblLaneForecastAccuracy
WHERE SendingWeek IN (SELECT DISTINCT SendingWeek FROM ##tblLaneForecastAccuracyTemp)
AND Lane NOT IN (SELECT DISTINCT Lane FROM ##tblLaneForecastAccuracyTemp)

/*
Insert into the table where the sending week/lane doesn't already exist
SELECT * FROM USCTTDEV.dbo.tblLaneForecastAccuracy
DELETE FROM USCTTDEV.dbo.tblLaneForecastAccuracy
*/
DECLARE @Now DATETIME
SET @Now = GETDATE()
INSERT INTO USCTTDEV.dbo.tblLaneForecastAccuracy (AddedOn, UpdatedOn, SendingWeek, Lane, MostRecentForecast, TwoWeeksAgo, ThreeWeeksAgo, FourWeeksAgo, FiveWeeksAgo, SixWeeksAgo, SevenWeeksAgo, EightWeeksAgo, TotalLoadCount, NonLTLLoadCount)
SELECT @Now, @Now, lfat.SendingWeek, lfat.Lane, lfat.MostRecentForecast, lfat.TwoWeeksAgo, lfat.ThreeWeeksAgo, lfat.FourWeeksAgo, lfat.FiveWeeksAgo, lfat.SixWeeksAgo, lfat.SevenWeeksAgo, lfat.EightWeeksAgo, 
CASE WHEN lfat.TotalLoadCount IS NULL THEN 0 ELSE lfat.TotalLoadCount END, 
CASE WHEN lfat.NonLTLLoadCount IS NULL THEN 0 ELSE lfat.NonLTLLoadCount END
FROM ##tblLaneForecastAccuracyTemp lfat
LEFT JOIN USCTTDEV.dbo.tblLaneForecastAccuracy lfa ON CAST(lfa.SendingWeek AS DATE) = CAST(lfat.SendingWeek AS DATE)
AND lfa.Lane = lfat.Lane
WHERE lfa.Lane IS NULL
ORDER BY lfat.Lane ASC

/*
Update all existing rows that match
*/
UPDATE USCTTDEV.dbo.tblLaneForecastAccuracy
SET AddedOn = @Now, 
UpdatedOn = @Now, 
SendingWeek = lfat.SendingWeek, 
Lane = lfat.Lane, 
MostRecentForecast = lfat.MostRecentForecast, 
TwoWeeksAgo = lfat.TwoWeeksAgo, 
ThreeWeeksAgo = lfat.ThreeWeeksAgo, 
FourWeeksAgo = lfat.FourWeeksAgo,  
FiveWeeksAgo = lfat.FiveWeeksAgo, 
SixWeeksAgo = lfat.SixWeeksAgo, 
SevenWeeksAgo = lfat.SevenWeeksAgo, 
EightWeeksAgo = lfat.EightWeeksAgo,  
TotalLoadCount = CASE WHEN lfat.TotalLoadCount IS NULL THEN 0 ELSE lfat.TotalLoadCount END,
NonLTLLoadCount = CASE WHEN lfat.NonLTLLoadCount IS NULL THEN 0 ELSE lfat.NonLTLLoadCount END
FROM USCTTDEV.dbo.tblLaneForecastAccuracy lfa
INNER JOIN ##tblLaneForecastAccuracyTemp lfat ON lfat.SendingWeek = lfa.SendingWeek
AND lfat.Lane = lfa.Lane

END