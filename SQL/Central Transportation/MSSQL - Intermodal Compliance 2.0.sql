/*
Start with historical Intermodal Lane Awards

select * from USCTTDEV.dbo.tblActualLoadDetail where ID <10
*/
SELECT DISTINCT ald.Lane,
ald.LD_LEG_ID,
COUNT(*) AS CountOfLD_LEG_ID,
COUNT(*) AS TotalShipments,
CAST(CASE WHEN ald.DLVY_DTT IS NOT NULL THEN ald.DLVY_DTT
WHEN ald.SHPD_DTT IS NOT NULL THEN ald.DLVY_DTT
ELSE ald.STRD_DTT END AS DATE) Date,
DATEPART(year,CAST(CASE WHEN ald.DLVY_DTT IS NOT NULL THEN ald.DLVY_DTT
WHEN ald.SHPD_DTT IS NOT NULL THEN ald.DLVY_DTT
ELSE ald.STRD_DTT END AS DATE)) Year,
DATEPART(month,CAST(CASE WHEN ald.DLVY_DTT IS NOT NULL THEN ald.DLVY_DTT
WHEN ald.SHPD_DTT IS NOT NULL THEN ald.DLVY_DTT
ELSE ald.STRD_DTT END AS DATE)) Month,
ald.CARR_CD,
ald.NAME,
ald.SRVC_CD,
ald.BU,
ald.ShipMode,
ald.EQMT_TYP,
ald.OrderType,
ald.SHIP_CONDITION,
ald.FRST_SHPG_LOC_CD,
ald.FRST_SHPG_LOC_NAME,
ald.FRST_CTY_NAME,
ald.FRST_STA_CD,
CASE WHEN ald.FRST_CTRY_CD = 'USA' THEN LEFT(ald.frst_pstl_cd,5) ELSE ald.frst_pstl_cd END FRST_PSTL_CD,
ald.LAST_SHPG_LOC_CD,
CASE WHEN ald.LAST_SHPG_LOC_CD LIKE '5%' THEN SUBSTRING(ald.LAST_SHPG_LOC_CD,1,8) ELSE SUBSTRING(ald.LAST_SHPG_LOC_CD,1,4) END FirstHalf,
CASE WHEN ald.LAST_SHPG_LOC_CD LIKE '5%' THEN SUBSTRING(ald.LAST_SHPG_LOC_CD,9,8) ELSE SUBSTRING(ald.LAST_SHPG_LOC_CD,6,4) END SecondHalf,
ald.LAST_SHPG_LOC_NAME,
ald.LAST_CTY_NAME,
ald.LAST_STA_CD,
SUBSTRING(ald.LAST_PSTL_CD,1,3) AS LAST_PSTL_CD3,
SUBSTRING(ald.LAST_PSTL_CD,1,5) AS LAST_PSTL_CD5,
ald.LAST_PSTL_CD,
imLaneAwardAgg.IntermodalAwardPercent,
imLaneAwardAgg.WeightedCUR_RPM,
imLaneAwardAgg.WeightedRPM,
CASE WHEN ald.Shipmode = 'INTERMODAL' THEN COUNT(*) END AS IntermodalShipments,
CAST(CASE WHEN ald.Shipmode = 'INTERMODAL' THEN SUM(ald.fixd_itnr_dist) END AS NUMERIC (18,2)) AS IntermodalMiles,
CAST(CASE WHEN ald.Shipmode = 'INTERMODAL' THEN AVG(ald.fixd_itnr_dist) END AS NUMERIC (18,2)) AS IntermodalAvgDist,
CAST(ROUND(CASE WHEN ald.Shipmode = 'INTERMODAL' THEN SUM(CASE WHEN ActualRateCharge <> 'Yes' THEN ald.PreRate_Linehaul ELSE ald.Act_Linehaul END) / SUM(ald.fixd_itnr_dist) END,2) AS NUMERIC(18,2)) AS IntermodalRPM,
CAST(ROUND(CASE WHEN ald.Shipmode = 'INTERMODAL' THEN SUM(CASE WHEN ActualRateCharge <> 'Yes' THEN ald.PreRate_Linehaul ELSE ald.Act_Linehaul END) / SUM(ald.fixd_itnr_dist) END,2) -.15 AS NUMERIC(18,2)) AS IntermodalRPMAdj,
ald.ActualRateCharge,

/*
Intermodal costs
*/
CAST(CASE WHEN ald.Shipmode = 'INTERMODAL' THEN SUM(CASE WHEN ActualRateCharge <> 'Yes' THEN ald.TotalCost ELSE ald.TotalCost END) END AS NUMERIC(18,2)) AS IntermodalTotalCost,
CAST(CASE WHEN ald.Shipmode = 'INTERMODAL' THEN SUM(CASE WHEN ActualRateCharge <> 'Yes' THEN ald.PreRate_Linehaul ELSE ald.Act_Linehaul END) END AS NUMERIC(18,2)) AS IntermodalLinehaul,
CAST(CASE WHEN ald.Shipmode = 'INTERMODAL' THEN SUM(CASE WHEN ActualRateCharge <> 'Yes' THEN ald.PreRate_Fuel ELSE ald.Act_Fuel END) END AS NUMERIC(18,2)) AS IntermodalFuel,
CAST(CASE WHEN ald.Shipmode = 'INTERMODAL' THEN SUM(CASE WHEN ActualRateCharge <> 'Yes' THEN ald.PreRate_Accessorials ELSE ald.Act_Accessorials END) END AS NUMERIC(18,2)) AS IntermodalAccessorials,
CAST(CASE WHEN ald.Shipmode = 'INTERMODAL' THEN SUM(CASE WHEN ActualRateCharge <> 'Yes' THEN ald.PreRate_ZUSB ELSE ald.Act_ZUSB END) END AS NUMERIC(18,2)) AS IntermodalZUSB,

/*
Non-Intermodal costs
*/
CASE WHEN ald.Shipmode <> 'INTERMODAL' THEN COUNT(*) END AS NonIntermodalShipments,
CAST(CASE WHEN ald.Shipmode <> 'INTERMODAL' THEN SUM(ald.fixd_itnr_dist) END AS NUMERIC (18,2)) AS NonIntermodalMiles,
CAST(CASE WHEN ald.Shipmode <> 'INTERMODAL' THEN AVG(ald.fixd_itnr_dist) END AS NUMERIC (18,2)) AS NonIntermodalAvgDist,
CAST(ROUND(CASE WHEN ald.Shipmode <> 'INTERMODAL' THEN SUM(CASE WHEN ActualRateCharge <> 'Yes' THEN ald.PreRate_Linehaul ELSE ald.Act_Linehaul END) / SUM(ald.fixd_itnr_dist) END,2) AS NUMERIC(18,2)) AS NonIntermodalRPM,
CAST(CASE WHEN ald.Shipmode <> 'INTERMODAL' THEN SUM(CASE WHEN ActualRateCharge <> 'Yes' THEN ald.TotalCost ELSE ald.TotalCost END) END AS NUMERIC(18,2)) AS NonIntermodalTotalCost,
CAST(CASE WHEN ald.Shipmode <> 'INTERMODAL' THEN SUM(CASE WHEN ActualRateCharge <> 'Yes' THEN ald.PreRate_Linehaul ELSE ald.Act_Linehaul END) END AS NUMERIC(18,2)) AS NonIntermodalLinehaul,
CAST(CASE WHEN ald.Shipmode <> 'INTERMODAL' THEN SUM(CASE WHEN ActualRateCharge <> 'Yes' THEN ald.PreRate_Fuel ELSE ald.Act_Fuel END) END AS NUMERIC(18,2)) AS NonIntermodalFuel,
CAST(CASE WHEN ald.Shipmode <> 'INTERMODAL' THEN SUM(CASE WHEN ActualRateCharge <> 'Yes' THEN ald.PreRate_Accessorials ELSE ald.Act_Accessorials END) END AS NUMERIC(18,2)) AS NonIntermodalAccessorials,
CAST(CASE WHEN ald.Shipmode <> 'INTERMODAL' THEN SUM(CASE WHEN ActualRateCharge <> 'Yes' THEN ald.PreRate_ZUSB ELSE ald.Act_ZUSB END) END AS NUMERIC(18,2)) AS NonIntermodalZUSB,

/*
Lane effective/expiration Dates
*/
imLaneAwards.LaneEff,
imLaneAwards.LaneExp,

/*
Aggregate Award effective/expiration Dates
*/
imLaneAwardAgg.EffectiveDate AS CarrEff,
imLaneAwardAgg.ExpirationDate AS CarrExp

FROM (
SELECT DISTINCT Lane,
	ORIG_CITY_STATE,
	Origin,
	DEST_CITY_STATE,
	Dest,
	MIN(EffectiveDate) AS LaneEff,
	MAX(ExpirationDate) AS LaneExp
FROM USCTTDEV.dbo.tblAwardRatesHistorical
WHERE MODE = 'IM'
GROUP BY Lane,
	ORIG_CITY_STATE,
	Origin,
	DEST_CITY_STATE,
	Dest
) imLaneAwards

/*
Join Intermodal Award Lanes to Actual Load Detail, but only where the dates are between the lane effective award dates
*/

INNER JOIN (SELECT * FROM USCTTDEV.dbo.tblActualLoadDetail) ald
ON ald.Lane = imLaneAwards.Lane

/*
Join historical time series award data
*/
LEFT JOIN (SELECT DISTINCT arh.Lane,
arh.LaneID,
arh.Mode,
arh.Equipment,
CAST(ROUND(
        SUM(arh.CUR_RPM * arh.AWARD_PCT) / SUM(arh.AWARD_PCT), 
        2
      ) AS NUMERIC(18,2)) AS WeightedCUR_RPM,
CAST(ROUND(
        SUM(arh.[Rate Per Mile] * arh.AWARD_PCT) / SUM(arh.AWARD_PCT), 
        2
      )AS NUMERIC(18,2)) AS WeightedRPM,
SUM(AWARD_PCT) AS IntermodalAwardPercent,
MIN(dates.EffectiveDate) AS EffectiveDate,
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
AND arh.EffectiveDate >= dates.EffectiveDate
AND arh.ExpirationDate <= dates.ExpirationDate
WHERE arh.mode = 'IM'
--AND arh.LANE = 'GAAUGUST-5FL33811'
GROUP BY arh.Lane,
arh.LaneID,
arh.Mode,
arh.Equipment,
dates.ExpirationDate) imLaneAwardAgg ON imLaneAwardAgg.Lane = ald.Lane

/*
Where the date on the Actual Load Table is between the eff/exp dates from imLaneAwards
*/
WHERE CAST(CASE WHEN ald.DLVY_DTT IS NOT NULL THEN ald.DLVY_DTT
WHEN ald.SHPD_DTT IS NOT NULL THEN ald.DLVY_DTT
ELSE ald.STRD_DTT END AS DATE) BETWEEN imLaneAwards.LaneEff AND imLaneAwards.LaneExp
AND ald.EQMT_TYP <> 'LTL'

/*
Where the date on the Actual Load Table is betwen the eff/exp dates from imLaneAwardsAgg (time series query)
Also, only for the current year
*/
AND CAST(CASE WHEN ald.DLVY_DTT IS NOT NULL THEN ald.DLVY_DTT
WHEN ald.SHPD_DTT IS NOT NULL THEN ald.DLVY_DTT
ELSE ald.STRD_DTT END AS DATE) BETWEEN imLaneAwardAgg.EffectiveDate AND imLaneAwardAgg.ExpirationDate

GROUP BY ald.Lane,
ald.LD_LEG_ID,
CAST(CASE WHEN ald.DLVY_DTT IS NOT NULL THEN ald.DLVY_DTT
WHEN ald.SHPD_DTT IS NOT NULL THEN ald.DLVY_DTT
ELSE ald.STRD_DTT END AS DATE),
DATEPART(year,CAST(CASE WHEN ald.DLVY_DTT IS NOT NULL THEN ald.DLVY_DTT
WHEN ald.SHPD_DTT IS NOT NULL THEN ald.DLVY_DTT
ELSE ald.STRD_DTT END AS DATE)),
DATEPART(month,CAST(CASE WHEN ald.DLVY_DTT IS NOT NULL THEN ald.DLVY_DTT
WHEN ald.SHPD_DTT IS NOT NULL THEN ald.DLVY_DTT
ELSE ald.STRD_DTT END AS DATE)),
ald.CARR_CD,
ald.NAME,
ald.SRVC_CD,
ald.BU,
ald.ShipMode,
ald.EQMT_TYP,
ald.OrderType,
ald.SHIP_CONDITION,
ald.FRST_SHPG_LOC_CD,
ald.FRST_SHPG_LOC_NAME,
ald.FRST_CTY_NAME,
ald.FRST_STA_CD,
CASE WHEN ald.FRST_CTRY_CD = 'USA' THEN LEFT(ald.frst_pstl_cd,5) ELSE ald.frst_pstl_cd END,
ald.LAST_SHPG_LOC_CD,
CASE WHEN ald.LAST_SHPG_LOC_CD LIKE '5%' THEN SUBSTRING(ald.LAST_SHPG_LOC_CD,1,8) ELSE SUBSTRING(ald.LAST_SHPG_LOC_CD,1,4) END,
CASE WHEN ald.LAST_SHPG_LOC_CD LIKE '5%' THEN SUBSTRING(ald.LAST_SHPG_LOC_CD,9,8) ELSE SUBSTRING(ald.LAST_SHPG_LOC_CD,6,4) END,
ald.LAST_SHPG_LOC_NAME,
ald.LAST_CTY_NAME,
ald.LAST_STA_CD,
SUBSTRING(ald.LAST_PSTL_CD,1,3),
SUBSTRING(ald.LAST_PSTL_CD,1,5),
ald.LAST_PSTL_CD,
imLaneAwardAgg.IntermodalAwardPercent,
imLaneAwardAgg.WeightedCUR_RPM,
imLaneAwardAgg.WeightedRPM,
ald.ActualRateCharge,
imLaneAwards.LaneEff,
imLaneAwards.LaneExp,
imLaneAwardAgg.EffectiveDate,
imLaneAwardAgg.ExpirationDate

ORDER BY LANE ASC