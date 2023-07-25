/*
Declare variables
*/
DECLARE @month int
/*
Set Monthly variable for Actual Load Detail retrieval
*/
SET
@month = 6
/*
Used to count possible duplicates
SELECT DISTINCT ORIG_CITY_STATE, DEST_CITY_STATE, Dest, ShipMode, COUNT(*) AS COUNT FROM (
*/

/*
Full dataset
*/
SELECT
DISTINCT
  data.*,
  rates.SixMonthLoadCount,
  rates.ThirtyDayLoadCount
FROM (

/*
Awarded weighted average
*/
SELECT
  *
FROM (SELECT
DISTINCT
  bal.ORIG_CITY_STATE,
  bal.Origin,
  LEFT(
  bal.Origin,
  CHARINDEX(', ', bal.Origin + ', ') - 1
  ) AS ORIG_CITY,
  RIGHT(
  bal.Origin,
  CHARINDEX(
  ',',
  REVERSE(bal.Origin)
  ) - 2
  ) AS ORIG_STATE,
  LEFT(bal.OriginZip, 3) AS OriginZip,
  bal.DEST_CITY_STATE,
  bal.Dest,
  LEFT(
  bal.Dest,
  CHARINDEX(', ', bal.Dest + ', ') - 1
  ) AS DEST_CITY,
  RIGHT(
  bal.Dest,
  CHARINDEX(
  ',',
  REVERSE(bal.Dest)
  ) - 2
  ) AS DEST_STATE,
  CASE
    WHEN DestCountry = 'USA' THEN RIGHT(bal.DEST_CITY_STATE, 5)
  END AS Dest_Zip,
  CASE
    WHEN bar.EQUIPMENT = '53FT' THEN 'TRUCK'
    WHEN bar.EQUIPMENT = '53TC' THEN 'TEMP CONTROL'
    ELSE 'INTERMODAL'
  END AS ShipMode,
  CAST(
  ROUND(bal.Miles, 0) AS int
  ) AS TotalMiles,
  CAST(
  ROUND(
  SUM(bar.CUR_RPM * bar.AWARD_PCT) / SUM(bar.AWARD_PCT),
  2
  ) AS decimal(9, 2)
  ) AS WeightedRPM,
  CAST(
  ROUND(bal.Miles, 0) AS int
  ) * (
  CAST(
  ROUND(
  SUM(bar.CUR_RPM * bar.AWARD_PCT) / SUM(bar.AWARD_PCT),
  2
  ) AS decimal(9, 2)
  )
  ) AS TotalCost,
  'Awarded Rates' AS Type
FROM USCTTDEV.dbo.tblBidAppLanes bal
INNER JOIN USCTTDEV.dbo.tblBidAppRates bar
  ON bar.LaneID = bal.LaneID
INNER JOIN (SELECT
DISTINCT
  bar.LaneID,
  bar.MODE
FROM USCTTDEV.dbo.tblBidAppRates bar
WHERE award_pct IS NOT NULL) award
  ON award.LaneID = bal.LaneID
  AND award.mode = bar.MODE
GROUP BY bal.ORIG_CITY_STATE,
         bal.Origin,
         LEFT(
         bal.Origin,
         CHARINDEX(', ', bal.Origin + ', ') - 1
         ),
         RIGHT(
         bal.Origin,
         CHARINDEX(
         ',',
         REVERSE(bal.Origin)
         ) - 2
         ),
         LEFT(bal.OriginZip, 3),
         bal.DEST_CITY_STATE,
         bal.Dest,
         LEFT(
         bal.Dest,
         CHARINDEX(', ', bal.Dest + ', ') - 1
         ),
         RIGHT(
         bal.Dest,
         CHARINDEX(
         ',',
         REVERSE(bal.Dest)
         ) - 2
         ),
         CASE
           WHEN DestCountry = 'USA' THEN RIGHT(bal.DEST_CITY_STATE, 5)
         END,
         CASE
           WHEN bar.EQUIPMENT = '53FT' THEN 'TRUCK'
           WHEN bar.EQUIPMENT = '53TC' THEN 'TEMP CONTROL'
           ELSE 'INTERMODAL'
         END,
         CAST(
         ROUND(bal.Miles, 0) AS int
         )) awards
UNION ALL

/*
Non-Awarded Lane/Modes
Use AVERAGE CUR_RPM value
Also, exclude rates that are 1.5*IQR +/- the CUR_RPM value
*/
SELECT
  *
FROM (SELECT
DISTINCT
  bal.ORIG_CITY_STATE,
  bal.Origin,
  LEFT(
  bal.Origin,
  CHARINDEX(', ', bal.Origin + ', ') - 1
  ) AS ORIG_CITY,
  RIGHT(
  bal.Origin,
  CHARINDEX(
  ',',
  REVERSE(bal.Origin)
  ) - 2
  ) AS ORIG_STATE,
  LEFT(bal.OriginZip, 3) AS OriginZip,
  bal.DEST_CITY_STATE,
  bal.Dest,
  LEFT(
  bal.Dest,
  CHARINDEX(', ', bal.Dest + ', ') - 1
  ) AS DEST_CITY,
  RIGHT(
  bal.Dest,
  CHARINDEX(
  ',',
  REVERSE(bal.Dest)
  ) - 2
  ) AS DEST_STATE,
  CASE
    WHEN DestCountry = 'USA' THEN RIGHT(bal.DEST_CITY_STATE, 5)
  END AS Dest_Zip,
  CASE
    WHEN bar.EQUIPMENT = '53FT' THEN 'TRUCK'
    WHEN bar.EQUIPMENT = '53TC' THEN 'TEMP CONTROL'
    ELSE 'INTERMODAL'
  END AS ShipMode,
  CAST(
  ROUND(bal.Miles, 0) AS int
  ) AS TotalMiles,
  CAST(
  ROUND(
  AVG(bar.CUR_RPM),
  2
  ) AS decimal(9, 2)
  ) AS WeightedRPM,
  CAST(
  ROUND(bal.Miles, 0) AS int
  ) * (
  CAST(
  ROUND(
  AVG(bar.CUR_RPM),
  2
  ) AS decimal(9, 2)
  )
  ) AS TotalCost,
  'Submitted Rates' AS Type
FROM USCTTDEV.dbo.tblBidAppLanes bal
INNER JOIN USCTTDEV.dbo.tblBidAppRates bar
  ON bar.LaneID = bal.LaneID

/*
Get quartile ranges, and set the UCL/LCL values
*/
INNER JOIN (SELECT DISTINCT
  qr.LaneID,
  qr.EQUIPMENT,
  qr.FirstQuartile,
  qr.ThirdQuartile,
  qr.ThirdQuartile - qr.FirstQuartile AS IQR,
  CAST(ROUND(qr.FirstQuartile - (1.5 * (qr.ThirdQuartile - FirstQuartile)), 2) AS numeric(18, 2)) AS LCL,
  CAST(ROUND(qr.ThirdQuartile + (1.5 * (qr.ThirdQuartile - FirstQuartile)), 2) AS numeric(18, 2)) AS UCL
FROM (SELECT DISTINCT
  laneID,
  EQUIPMENT,
  CAST(ROUND(PERCENTILE_DISC(0.25) WITHIN GROUP (ORDER BY CUR_RPM) OVER (PARTITION BY LaneID, EQUIPMENT), 2) AS numeric(18, 2)) AS FirstQuartile,
  CAST(ROUND(PERCENTILE_DISC(0.75) WITHIN GROUP (ORDER BY CUR_RPM) OVER (PARTITION BY LaneID, EQUIPMENT), 2) AS numeric(18, 2)) AS ThirdQuartile
FROM USCTTDEV.dbo.tblBidAppRates) qr) quartiles
  ON bar.LaneID = quartiles.LaneID
  AND bar.EQUIPMENT = quartiles.EQUIPMENT
/*
Get awarded lanes/modes, used to exclude from dataset since they already appear in Award query
*/
LEFT JOIN (SELECT
DISTINCT
  bar.LaneID,
  bar.MODE
FROM USCTTDEV.dbo.tblBidAppRates bar
WHERE bar.award_pct IS NOT NULL) award
  ON award.LaneID = bal.LaneID
  AND award.mode = bar.MODE

WHERE award.LaneID IS NULL
AND award.Mode IS NULL
AND bar.CUR_RPM BETWEEN quartiles.LCL AND quartiles.UCL
GROUP BY bal.ORIG_CITY_STATE,
         bal.Origin,
         LEFT(
         bal.Origin,
         CHARINDEX(', ', bal.Origin + ', ') - 1
         ),
         RIGHT(
         bal.Origin,
         CHARINDEX(
         ',',
         REVERSE(bal.Origin)
         ) - 2
         ),
         LEFT(bal.OriginZip, 3),
         bal.DEST_CITY_STATE,
         bal.Dest,
         LEFT(
         bal.Dest,
         CHARINDEX(', ', bal.Dest + ', ') - 1
         ),
         RIGHT(
         bal.Dest,
         CHARINDEX(
         ',',
         REVERSE(bal.Dest)
         ) - 2
         ),
         CASE
           WHEN DestCountry = 'USA' THEN RIGHT(bal.DEST_CITY_STATE, 5)
         END,
         CASE
           WHEN bar.EQUIPMENT = '53FT' THEN 'TRUCK'
           WHEN bar.EQUIPMENT = '53TC' THEN 'TEMP CONTROL'
           ELSE 'INTERMODAL'
         END,
         CAST(
         ROUND(bal.Miles, 0) AS int
         )) rates
UNION ALL
SELECT
  *
FROM (

/*
Actuals Rates
There are some funky things going on with the destinations, where cities in the same dest zone have different names. 
Need to use whatever the MAX count value is, since it's probably the most accurate
*/
SELECT DISTINCT ald.Origin_Zone,
ald.FRST_CTY_NAME + ', ' + ald.FRST_STA_CD AS Origin,
ald.FRST_CTY_NAME AS ORIG_CITY,
ald.FRST_STA_CD AS ORIG_STATE,
LEFT(ald.FRST_PSTL_CD, 3) AS OriginZip,
ald.Dest_Zone AS DEST_CITY_STATE,
ald.DestCity + ', ' + ald.LAST_STA_CD AS Dest,
ald.DestCity AS DEST_CITY,
ald.LAST_STA_CD AS DEST_STATE,
CASE
    WHEN ald.LAST_CTRY_CD = 'USA' THEN LEFT(ald.LAST_PSTL_CD, 5)
    ELSE ald.DEST_ZONE
  END AS Dest_Zip,
  CASE
    WHEN ald.EQMT_TYP = '53FT' THEN 'TRUCK'
    WHEN ald.EQMT_TYP = '53TC' THEN 'TEMP CONTROL'
    ELSE 'INTERMODAL'
  END AS ShipMode,
  CAST(
  ROUND(
  AVG(ald.FIXD_ITNR_DIST),
  0
  ) AS int
  ) AS TotalMiles,
  CAST(
  ROUND(
  ROUND(
  AVG(ald.ACT_LINEHAUL),
  2
  ) / CAST(
  ROUND(
  AVG(ald.FIXD_ITNR_DIST),
  0
  ) AS int
  ),
  2
  ) AS numeric(18, 2)
  ) AS Avg_RPM,
  CAST(
  CAST(
  ROUND(
  AVG(ald.FIXD_ITNR_DIST),
  0
  ) AS int
  ) * ROUND(
  ROUND(
  AVG(ald.ACT_LINEHAUL),
  2
  ) / CAST(
  ROUND(
  AVG(ald.FIXD_ITNR_DIST),
  0
  ) AS int
  ),
  2
  ) AS numeric(18, 2)) AS TotalCost,
  'Actuals' AS Type

FROM USCTTDEV.dbo.tblActualLoadDetail ald

LEFT JOIN (SELECT
DISTINCT
  bal.LaneID,
  bal.ORIG_CITY_STATE,
  bal.DEST_CITY_STATE,
  LEFT(
  bal.Dest,
  CHARINDEX(', ', bal.Dest + ', ') - 1
  ) AS Dest,
  bar.EQUIPMENT,
  CASE
       WHEN bar.EQUIPMENT = '53FT' THEN 'TRUCK'
       WHEN bar.EQUIPMENT = '53TC' THEN 'TEMP CONTROL'
       ELSE 'INTERMODAL'
     END AS ShipMode 
FROM USCTTDEV.dbo.tblBidAppLanes bal
INNER JOIN USCTTDEV.dbo.tblBidAppRates bar
  ON bar.LaneID = bal.LaneID) bidApp
  ON bidApp.ORIG_CITY_STATE = ald.Origin_Zone
  AND bidapp.DEST_CITY_STATE = ald.Dest_Zone
  AND bidApp.Dest = ald.DestCity
  AND bidApp.ShipMode =
          CASE
            WHEN ald.EQMT_TYP = '53FT' THEN 'TRUCK'
            WHEN ald.EQMT_TYP = '53TC' THEN 'TEMP CONTROL'
            ELSE 'INTERMODAL'
          END
WHERE CASE
  WHEN ald.SHPD_DTT IS NULL THEN ald.STRD_DTT
  ELSE ald.SHPD_DTT
END > DATEADD(m, -@month, current_timestamp)
/*AND ald.ActualRateCharge = 'Yes'*/
AND ald.Origin_Zone IS NOT NULL
AND (
ald.Dest_Zone IS NOT NULL
AND ald.Dest_Zone NOT LIKE 'US-%'
)
AND bidApp.ORIG_CITY_STATE IS NULL
AND bidApp.DEST_CITY_STATE IS NULL
AND bidApp.EQUIPMENT IS NULL
AND bidApp.Dest IS NULL
/*AND ald.Origin_Zone = 'TXDALLAS' and ald.Dest_Zone = '5TX78219'*/

GROUP BY ald.Origin_Zone,
ald.FRST_CTY_NAME + ', ' + ald.FRST_STA_CD,
ald.FRST_CTY_NAME,
ald.FRST_STA_CD,
LEFT(ald.FRST_PSTL_CD, 3),
ald.Dest_Zone,
ald.DestCity + ', ' + ald.LAST_STA_CD,
ald.DestCity,
ald.LAST_STA_CD,
CASE
WHEN ald.LAST_CTRY_CD = 'USA' THEN LEFT(ald.LAST_PSTL_CD, 5)
ELSE ald.DEST_ZONE
END,
CASE
WHEN ald.EQMT_TYP = '53FT' THEN 'TRUCK'
WHEN ald.EQMT_TYP = '53TC' THEN 'TEMP CONTROL'
ELSE 'INTERMODAL'
END) actuals
/*WHERE DEST_CITY_STATE = '5VA23231'*/) data
LEFT JOIN (

/*
Actuals Counts
There are some funky things going on with the destinations, where cities in the same dest zone have different names. Need to use whatever the MAX value is, since it's probably the most accurate
*/
SELECT DISTINCT ald.Origin_Zone AS ORIG_CITY_STATE,
REPLACE(ald.FRST_CTY_NAME + ', ' + ald.FRST_STA_CD, ' ,', ',') AS Origin,
ald.FRST_CTY_NAME AS ORIG_CITY,
ald.FRST_STA_CD AS ORIG_STATE,
LEFT(ald.FRST_PSTL_CD, 3) AS OriginZip,
ald.Dest_Zone AS DEST_CITY_STATE,
ald.DestCity + ', ' + ald.LAST_STA_CD AS Dest,
ald.DestCity AS DEST_CITY,
ald.LAST_STA_CD AS DEST_STATE,
CASE
    WHEN ald.LAST_CTRY_CD = 'USA' THEN LEFT(ald.LAST_PSTL_CD, 5)
    ELSE ald.DEST_ZONE
  END AS Dest_Zip,
  CASE
    WHEN ald.EQMT_TYP = '53FT' THEN 'TRUCK'
    WHEN ald.EQMT_TYP = '53TC' THEN 'TEMP CONTROL'
    ELSE 'INTERMODAL'
  END AS ShipMode,
  CAST(
  ROUND(
  AVG(ald.FIXD_ITNR_DIST),
  0
  ) AS int
  ) AS TotalMiles,
  CAST(
  ROUND(
  ROUND(
  AVG(ald.ACT_LINEHAUL),
  2
  ) / CAST(
  ROUND(
  AVG(ald.FIXD_ITNR_DIST),
  0
  ) AS int
  ),
  2
  ) AS numeric(18, 2)
  ) AS Avg_RPM,
  CAST(
  CAST(
  ROUND(
  AVG(ald.FIXD_ITNR_DIST),
  0
  ) AS int
  ) * ROUND(
  ROUND(
  AVG(ald.ACT_LINEHAUL),
  2
  ) / CAST(
  ROUND(
  AVG(ald.FIXD_ITNR_DIST),
  0
  ) AS int
  ),
  2
  ) AS numeric(18, 2)) AS TotalCost,
  COUNT(DISTINCT LD_LEG_ID) AS SixMonthLoadCount,
  SUM(
  CASE
    WHEN (
      CASE
        WHEN ald.SHPD_DTT IS NULL THEN ald.STRD_DTT
        ELSE ald.SHPD_DTT
      END
      ) > DATEADD(D, -30, current_timestamp) THEN 1
    ELSE 0
  END
  ) AS ThirtyDayLoadCount,
  'Shipment Count' AS Type

FROM USCTTDEV.dbo.tblActualLoadDetail ald

WHERE CASE
  WHEN ald.SHPD_DTT IS NULL THEN ald.STRD_DTT
  ELSE ald.SHPD_DTT
END > DATEADD(m, -@month, current_timestamp)
/*AND ald.ActualRateCharge = 'Yes'*/
AND ald.Origin_Zone IS NOT NULL
AND (
ald.Dest_Zone IS NOT NULL
AND ald.Dest_Zone NOT LIKE 'US-%'
)
/*AND ald.Origin_Zone = 'TXDALLAS' and ald.Dest_Zone = '5TX78219'*/

GROUP BY ald.Origin_Zone,
REPLACE(ald.FRST_CTY_NAME + ', ' + ald.FRST_STA_CD, ' ,', ','),
ald.FRST_CTY_NAME,
ald.FRST_STA_CD,
LEFT(ald.FRST_PSTL_CD, 3),
ald.Dest_Zone,
ald.DestCity + ', ' + ald.LAST_STA_CD,
ald.DestCity,
ald.LAST_STA_CD,
CASE
WHEN ald.LAST_CTRY_CD = 'USA' THEN LEFT(ald.LAST_PSTL_CD, 5)
ELSE ald.DEST_ZONE
END,
CASE
WHEN ald.EQMT_TYP = '53FT' THEN 'TRUCK'
WHEN ald.EQMT_TYP = '53TC' THEN 'TEMP CONTROL'
ELSE 'INTERMODAL'
END) rates
  ON rates.ORIG_CITY_STATE = data.ORIG_CITY_STATE
  AND rates.DEST_CITY_STATE = data.DEST_CITY_STATE
  AND rates.ShipMode = data.ShipMode
  AND rates.Dest = data.Dest

/*
WHERE data.ORIG_CITY_STATE = 'KYLOUISV' and data.DEST_CITY_STATE = '5TN37774'
)data

GROUP BY ORIG_CITY_STATE, DEST_CITY_STATE, ShipMode
HAVING COUNT(*) <> 1
*/
ORDER BY Origin ASC, 
Dest ASC, 
Dest_Zip ASC, 
ShipMode ASC