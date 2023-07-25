SELECT DISTINCT arh.Lane,
arh.LaneID,
/*arh.Mode,
arh.Equipment,*/
CAST(ROUND(
        SUM((arh.CUR_RPM - (CASE WHEN arh.Equipment = '53IM' THEN .15 ELSE 0 END)) * arh.AWARD_PCT) / SUM(arh.AWARD_PCT), 
        2
      ) AS NUMERIC(18,2)) AS WeightedCUR_RPM,
/*CAST(ROUND(
        SUM((arh.[Rate Per Mile] - (CASE WHEN arh.Equipment = '53IM' THEN .15 ELSE 0 END)) * arh.AWARD_PCT) / SUM(arh.AWARD_PCT), 
        2
      )AS NUMERIC(18,2)) AS WeightedRPM,*/
SUM(AWARD_PCT) AS AwardPercent,
MAX(dates.EffectiveDate) AS EffectiveDate,
dates.ExpirationDate
FROM USCTTDEV.dbo.tblAwardRatesHistorical arh
INNER JOIN (
SELECT DISTINCT
  arh.Lane,
  arh.EffectiveDate,
  MIN(Expiration.ExpirationDate) AS ExpirationDate
FROM USCTTDEV.dbo.tblAwardRatesHistorical arh
INNER JOIN (SELECT DISTINCT
  Lane,
  EffectiveDate,
  ExpirationDate
FROM USCTTDEV.dbo.tblAwardRatesHistorical) Expiration
  ON arh.Lane = Expiration.Lane
  AND arh.EffectiveDate = Expiration.EffectiveDate
  AND arh.ExpirationDate <= Expiration.ExpirationDate
  AND arh.EffectiveDate <= Expiration.ExpirationDate
GROUP BY arh.Lane,
         arh.EffectiveDate,
         expiration.EffectiveDate
)dates ON dates.Lane = arh.Lane
/*AND arh.EffectiveDate >= dates.EffectiveDate
AND arh.ExpirationDate <= dates.ExpirationDate*/
AND arh.ExpirationDate BETWEEN dates.EffectiveDate AND dates.ExpirationDate 
--WHERE arh.mode = 'IM'
--AND arh.LANE = 'GAAUGUST-5FL33811'
--WHERE arh.Lane = 'ALMOBILE-5CA92831'
GROUP BY arh.Lane,
arh.LaneID,
/*arh.Mode,
arh.Equipment,*/

dates.ExpirationDate
ORDER BY Lane ASC, EffectiveDate ASC, ExpirationDate ASC