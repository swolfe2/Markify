WITH Awards AS
(
SELECT DISTINCT 
arh.Carrier,
arh.CarrierName,
arh.SCAC, 
arh.SCACName,
arh.Lane,
arh.ORIG_CITY_STATE AS OriginZone,
arh.Origin,
arh.DEST_CITY_STATE AS DestZone,
arh.Dest,
CAST(AVG(arh.Miles) AS NUMERIC(10,2)) Miles,
CAST(ROUND(AVG(arh.AWARD_LDS),2) AS INT) AwardLoads,
CAST(arh.EffectiveDate AS DATE) AS EffectiveDate,
CAST(CASE WHEN YEAR(arh.ExpirationDate) = 2999 THEN '1/31/2021' ELSE arh.ExpirationDate END AS DATE) AS ExpirationDate,
DATEDIFF(day,CAST(arh.EffectiveDate AS DATE),CAST(CASE WHEN YEAR(arh.ExpirationDate) = 2999 THEN '1/31/2021' ELSE arh.ExpirationDate END AS DATE)) AS DateDiff
/*DATEDIFF("D", arh.EffectiveDate, MIN(arh2.EffectiveDate)) AS DaysDiff*/
FROM USCTTDEV.dbo.tblAwardRatesHistorical arh /*14,600*/
/*LEFT JOIN USCTTDEV.dbo.tblAwardRatesHistorical arh2 ON arh2.Lane = arh.Lane
	AND arh2.SCAC = arh.SCAC
	AND arh2.EffectiveDate > arh.EffectiveDate*/

WHERE CAST(arh.EffectiveDate AS DATE) >= CAST('2/1/2020' AS DATE)
AND arh.Carrier IS NOT NULL
AND arh.AWARD_LDS IS NOT NULL
/*AND arh.Lane = 'ONMILTON-ONETOBIC'*/
GROUP BY arh.Carrier,
arh.CarrierName,
arh.SCAC, 
arh.SCACName,
arh.Lane,
arh.ORIG_CITY_STATE,
arh.Origin,
arh.DEST_CITY_STATE,
arh.Dest,
arh.EffectiveDate,
arh.ExpirationDate

/*ORDER BY SCAC ASC, EffectiveDate ASC*/
),

aldInMem AS (
/*
SELECT TOP 10 * FROM USCTTDEV.dbo.tblActualLoadDetail
*/
SELECT DISTINCT ald.Lane,
ald.SRVC_CD,
COUNT(DISTINCT ald.LD_LEG_ID) AS LoadCount,
CAST(CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END AS DATE) AS TheDate
FROM USCTTDEV.dbo.tblActualLoadDetail ald
WHERE CAST(CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END AS DATE) BETWEEN CAST('2/1/2020' AS DATE) AND CAST('1/31/2021' AS DATE)
AND ald.SRVC_CD <> 'OPEN'
AND ald.EQMT_TYP <> 'LTL'
GROUP BY ald.Lane,
CAST(CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END AS DATE),
ald.SRVC_CD
)


/*
SELECT DATEDIFF(day,'2/1/2020','1/31/2021')
*/

SELECT DISTINCT data.Lane,
data.Carrier,
data.CarrierName,
data.SCAC,
data.SCACName,
data.AwardEffectiveDate,
data.AwardExpirationDate,
data.WeightedAwardLoads,
data.TotalAwardDays,
data.ActualMinDate,
data.ActualMaxDate,
data.ActualLoadCount,
CASE WHEN data.AwardEffectiveDate IS NULL THEN 'Never Awarded'
	WHEN data.AwardEffectiveDate = CAST('2/1/2020' AS DATE) THEN 'RFP Awarded'
	ELSE 'Awarded After RFP' END AS AwardFlag,
CASE WHEN data.ActualLoadCount IS NULL AND data.AwardEffectiveDate IS NOT NULL THEN 'Never Shipped'
	WHEN data.ActualLoadCount IS NOT NULL AND data.AwardEffectiveDate IS NULL THEN 'Non-Awarded'
	WHEN data.ActualLoadCount < data.WeightedAwardLoads THEN 'Under Award'
	ELSE 'Over Shipped' END AS VolumeFlag,
CASE WHEN data.ActualLoadCount IS NULL AND data.WeightedAwardLoads IS NOT NULL THEN 0 - data.WeightedAwardLoads
	WHEN data.ActualLoadCount IS NOT NULL AND data.AwardEffectiveDate IS NULL THEN 0 + data.ActualLoadCount
	ELSE data.ActualLoadCount - data.WeightedAwardLoads
END AS AwardLoadsToActuals

FROM(
SELECT DISTINCT awards.Lane,
ca.CARR_CD AS Carrier,
ca.Name AS CarrierName,
awards.SCAC,
ca.SRVC_DESC AS SCACName,
MIN(awards.EffectiveDate) AS AwardEffectiveDate,
MAX(awards.ExpirationDate) AS AwardExpirationDate,
(COUNT(DISTINCT CAST(CAST(awards.EffectiveDate AS DATE) AS NVARCHAR(20)) +'-'+ CAST(awards.SCAC AS NVARCHAR(20))) - 1) AS ChangeCount,
SUM(awards.AwardLoads * awards.DateDiff) / SUM(CASE WHEN awards.DateDiff = 0 THEN 1 ELSE awards.DateDiff END) AS WeightedAwardLoads,
SUM(awards.DateDiff) + (COUNT(DISTINCT CAST(CAST(awards.EffectiveDate AS DATE) AS NVARCHAR(20)) +'-'+ CAST(awards.SCAC AS NVARCHAR(20))) - 1) AS TotalAwardDays,
ald.MinDate as ActualMinDate,
ald.MaxDate AS ActualMaxDate,
ald.LoadCount AS ActualLoadCount
FROM Awards 
INNER JOIN USCTTDEV.dbo.tblCarriers ca ON ca.SRVC_CD = awards.SCAC
LEFT JOIN (
SELECT DISTINCT aldInMem.Lane, 
aldInMem.SRVC_CD,
MIN(aldInMem.TheDate) AS MinDate,
MAX(aldInMem.TheDate) AS MaxDate,
SUM(aldInMem.LoadCount)AS LoadCount
FROM aldInMem
GROUP BY aldInMem.Lane,
aldInMem.SRVC_CD
) ald ON ald.Lane = awards.Lane
AND ald.SRVC_CD = awards.SCAC
/*WHERE  awards.Lane = 'ONMILTON-ONETOBIC'*/
GROUP BY awards.Lane,
awards.SCAC,
ca.CARR_CD,
ca.Name,
ca.SRVC_DESC,
ald.MinDate,
ald.MaxDate,
ald.LoadCount

UNION ALL

/*
Union actuals where not already in awards
*/
SELECT DISTINCT aldInMem.Lane,
ca.CARR_CD AS Carrier,
ca.Name AS CarrierName,
aldInMem.SRVC_CD AS SCAC,
ca.SRVC_DESC AS SCACName,
Null AS MInEffectiveDate,
Null AS MaxExpirationDate,
0 AS ChangeCount,
Null As WeightedAwardLoads,
Null AS TotalAwardDays,
MIN(aldInMem.TheDate) AS ActualMinDate,
MAX(aldInMem.TheDate) AS ActualMaxDate,
SUM(aldInMem.LoadCount) AS ActualLoadCount
FROM aldInMem
INNER JOIN USCTTDEV.dbo.tblCarriers ca ON ca. SRVC_CD = aldInMem.SRVC_CD
LEFT JOIN awards ON awards.Lane = aldInMem.Lane
AND awards.SCAC = aldInMem.SRVC_CD
WHERE awards.Lane IS NULL
and awards.SCAC IS NULL
GROUP BY aldInMem.Lane,
ca.CARR_CD,
ca.Name,
aldInMem.SRVC_CD,
ca.SRVC_DESC
) data