WITH LoadData AS (SELECT DISTINCT ald.LD_LEG_ID,
ald.Lane,
ald.CustomerHierarchy,
ald.BU,
ald.TotalWeight,
ald.TotalVolume,
/*ald.AwardLane,
ald.AwardCarrier,*/
ald.BUSegment,
/*ald.Dedicated, 
ald.RateType,
ald.LiveLoad,*/
ald.TotalCost,
CAST(CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END AS DATE) AS Date,

CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END AS DateTime,

DATEDIFF(SECOND, LAG(CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END) OVER (PARTITION BY ald.Lane, ald.CustomerHierarchy ORDER BY CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END ASC, ald.LD_LEG_ID ASC), CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END) AS MinuteLag,

DATEDIFF(DAY, LAG(CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END) OVER (PARTITION BY ald.Lane, ald.CustomerHierarchy ORDER BY CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END ASC, ald.LD_LEG_ID ASC), CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END) AS DayLag,

LAG(ald.LD_LEG_ID) OVER (PARTITION BY ald.Lane, ald.CustomerHierarchy ORDER BY CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END ASC, ald.LD_LEG_ID ASC) AS PreviousLD_LEG_ID,

LAG(CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END) OVER (PARTITION BY ald.Lane, ald.CustomerHierarchy ORDER BY CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END ASC, ald.LD_LEG_ID ASC) AS PreviousDateTime,

LAG(CAST(CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END AS DATE)) OVER (PARTITION BY ald.Lane, ald.CustomerHierarchy ORDER BY CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END ASC, ald.LD_LEG_ID ASC) AS PreviousDate,

LAG(ald.TotalWeight) OVER (PARTITION BY ald.Lane, ald.CustomerHierarchy ORDER BY CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END ASC, ald.LD_LEG_ID ASC) AS PreviousWeight,

LAG(ald.TotalVolume) OVER (PARTITION BY ald.Lane, ald.CustomerHierarchy ORDER BY CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END ASC, ald.LD_LEG_ID ASC) AS PreviousVolume,

LAG(ald.TotalCost) OVER (PARTITION BY ald.Lane, ald.CustomerHierarchy ORDER BY CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END ASC, ald.LD_LEG_ID ASC) AS PreviousCost,

LAG(ald.CustomerHierarchy) OVER (PARTITION BY ald.Lane, ald.CustomerHierarchy ORDER BY CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END ASC, ald.LD_LEG_ID ASC) AS PreviousCustomerHierarchy,

CASE WHEN LAG(ald.CustomerHierarchy) OVER (PARTITION BY ald.Lane, ald.CustomerHierarchy ORDER BY CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END ASC, ald.LD_LEG_ID ASC)  = ald.CustomerHierarchy 
AND ald.TotalVolume + LAG(ald.TotalVolume) OVER (PARTITION BY ald.Lane, ald.CustomerHierarchy ORDER BY CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END ASC, ald.LD_LEG_ID ASC) < 3250 
AND DATEDIFF(DAY, LAG(CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END) OVER (PARTITION BY ald.Lane, ald.CustomerHierarchy ORDER BY CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END ASC, ald.LD_LEG_ID ASC), CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END) <= 1

THEN 'Yes'

 ELSE 'No' END AS CanCombineWithPrevious,
 CASE WHEN LAG(ald.LD_LEG_ID) OVER (PARTITION BY ald.Lane, ald.CustomerHierarchy ORDER BY CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END ASC, ald.LD_LEG_ID ASC) IS NULL THEN 'New Lane or Customer'

WHEN DATEDIFF(DAY, LAG(CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END) OVER (PARTITION BY ald.Lane, ald.CustomerHierarchy ORDER BY CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END ASC, ald.LD_LEG_ID ASC), CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END) > 1 THEN 'More than 1 Day Apart'

WHEN ald.TotalVolume + LAG(ald.TotalVolume) OVER (PARTITION BY ald.Lane, ald.CustomerHierarchy ORDER BY CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END ASC, ald.LD_LEG_ID ASC) > 3250 THEN 'Over Cube Limit'
ELSE 'Can Combine' END AS CombineReason


FROM USCTTDEV.dbo.tblActualLoadDetail ald
WHERE ald.EQMT_TYP <> 'LTL'
AND ald.Lane = 'CAONTARI-5CA95330'
AND ald.TotalVolume < 2000
AND ald.SHPD_DTT IS NULL
AND ald.BUSegment NOT IN ('Wadding','NFG','NONWOVENS')
AND YEAR(CAST(CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.SHPD_DTT END AS DATE)) >= YEAR(GETDATE()) - 1
)

SELECT DISTINCT data.Lane,
data.BU,
data.CustomerHierarchy,
data.TheFirstOfWeekMon,
CAST(AVG(CAST(data.DayLag AS NUMERIC(10,2))) AS NUMERIC(10,2)) AS AvgDayLag,
CAST(AVG(CAST(data.MinuteLag AS NUMERIC(10,2))) AS INT) AS AvgMinuteLag,
COUNT(DISTINCT data.LD_LEG_ID) AS LoadCount,
SUM(TotalVolume) AS TotalVolume,
SUM(TotalCost) AS TotalCost,
CAST(ROUND(SUM(TotalVolume) / 3200,2) AS NUMERIC(10,2)) AS ShouldHaveBeenTrucks,
MIN(TotalCost) AS MinCost,
CAST(ROUND(MIN(TotalCost) * CAST(ROUND(SUM(TotalVolume) / 3200,2) AS NUMERIC(10,2)), 2) AS NUMERIC(10,2)) AS ShouldHaveBeenCost,
SUM(TotalCost) - CAST(ROUND(MIN(TotalCost) * CAST(ROUND(SUM(TotalVolume) / 3200,2) AS NUMERIC(10,2)), 2) AS NUMERIC(10,2)) AS ShouldHaveBeenCostCompare

FROM (
SELECT LoadData.LD_LEG_ID,
LoadData.Lane,
LoadData.BU,
LoadData.CustomerHierarchy,
LoadData.TotalWeight,
LoadData.TotalVolume,
LoadData.BUSegment,
LoadData.TotalCost,
LoadData.Date,
LoadData.DateTime,
da.TheFirstOfWeekMon,
LoadData.PreviousDate,
LoadData.PreviousDateTime,
LoadData.MinuteLag,
LoadData.DayLag,
LoadData.PreviousLD_LEG_ID,
LoadData.PreviousWeight,
LoadData.PreviousVolume,
LoadData.PreviousCost,
LoadData.PreviousCustomerHierarchy,
LoadData.CanCombineWithPrevious,
LoadData.CombineReason,
CASE WHEN CanCombineWIthPrevious = 'Yes' THEN 1 ELSE NULL END AS CanCombineCount,
CASE WHEN CanCombineWIthPrevious = 'Yes' THEN
	CASE WHEN LoadData.PreviousCost > LoadData.TotalCost THEN LoadData.PreviousCost ELSE LoadData.TotalCost END
ELSE NULL END AS CanCombineCost,
CASE WHEN CanCombineWIthPrevious = 'Yes' THEN LoadData.PreviousVolume + LoadData.TotalVolume ELSE NULL END AS CanCombineVolume

FROM LoadData
INNER JOIN USCTTDEV.dbo.tblDates da ON da.TheDate = LoadData.Date

) data
/*
ORDER BY LoadData.Lane ASC,
LoadData.CustomerHierarchy ASC, 
LoadData.DateTime ASC,
LoadData.LD_LEG_ID ASC
*/

GROUP BY data.Lane,
data.BU,
data.CustomerHierarchy,
data.TheFirstOfWeekMon