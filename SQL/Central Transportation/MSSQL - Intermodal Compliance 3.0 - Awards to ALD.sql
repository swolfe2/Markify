SELECT DISTINCT
origins.FRST_SHPG_LOC_CD AS [Ship DC],
lanes.FRST_PSTL_CD AS [Ship DC Zip],
lanes.FRST_CTY_NAME AS [Ship DC City],
ald.LAST_SHPG_LOC AS [External Customer LVL 2],
ald.CustomerHierarchy AS [Customer Headquarter Name],
ald.LAST_SHPG_LOC_CD AS [Ship To Location],
ald.LAST_SHPG_LOC_NAME AS [Customer Name],
lanes.LAST_CTY_NAME AS [Customer City],
lanes.LAST_STA_CD AS [Cust State],
lanes.LAST_PSTL_CD AS [Customer Zip Code],
CASE WHEN awards.Lane IS NOT NULL AND ald.OTRCount IS NOT NULL THEN awards.WeightedCost - ald.OTRAvgCost 
WHEN awards.Lane IS NOT NULL and ald.OTRCount IS NULL THEN 0
WHEN ald.OTRCount IS NOT NULL AND ald.TOFCCount IS NOT NULL THEN ald.TOFCAvgCost - ald.OTRAvgCost 
WHEN ald.OTRCount IS NULL AND ald.TOFCCount IS NOT NULL THEN 0 END AS [Rail Cost vs. OTR Cost],
ald.TOFCCount AS [TOFC Shipment - 6 months],
ald.OTRCount AS [OTR Shipments - 6 months],
ald.TotalLoadCount AS [Total Shipments - 6 months]

FROM (
SELECT DISTINCT 
lanes.Origin_Zone,
lanes.Dest_Zone,
lanes.Lane,
lanes.FRST_CTRY_CD,
lanes.FRST_CTY_NAME,
lanes.FRST_STA_CD,
lanes.FRST_PSTL_CD,
lanes.LAST_CTRY_CD,
lanes.LAST_CTY_NAME,
lanes.LAST_STA_CD,
lanes.LAST_PSTL_CD,
lanes.TableName,
ROW_NUMBER() OVER (PARTITION BY lanes.Lane ORDER BY lanes.TableName DESC) AS RowNumber
FROM (

SELECT DISTINCT ald.Origin_Zone,
ald.Dest_Zone,
ald.Lane, 
ald.FRST_CTRY_CD,
ald.FRST_CTY_NAME,
ald.FRST_STA_CD,
CASE WHEN ald.FRST_CTRY_CD = 'USA' THEN LEFT(ald.FRST_PSTL_CD,5) ELSE ald.FRST_PSTL_CD END AS FRST_PSTL_CD,
ald.LAST_CTRY_CD,
ald.LAST_CTY_NAME,
ald.LAST_STA_CD,
CASE WHEN ald.LAST_CTRY_CD = 'USA' THEN LEFT(ald.LAST_PSTL_CD,5) ELSE ald.LAST_PSTL_CD END AS LAST_PSTL_CD,
'Actual Load Detail' AS TableName
FROM USCTTDEV.dbo.tblActualLoadDetail ald
WHERE CAST(SHPD_DTT AS DATE) >= CAST(GETDATE() - 365 AS DATE) 
AND LEFT(ald.FRST_SHPG_LOC_CD,1) <> 'V'
AND ald.EQMT_TYP = '53IM'

UNION ALL

SELECT DISTINCT bal.ORIG_CITY_STATE,
bal.DEST_CITY_STATE,
bal.Lane,
bal.OriginCountry,
CASE
    WHEN CHARINDEX(',', bal.Origin) > 0 then
        RTRIM(LTRIM(LEFT(bal.Origin, CHARINDEX(',', bal.Origin) - 1)))
    ELSE
        bal.Origin
END AS FRST_CTY_NAME,
CASE
    WHEN CHARINDEX(',', bal.Origin) > 0 then
        RTRIM(LTRIM(REPLACE(RIGHT(bal.Origin, CHARINDEX(',', reverse(bal.Origin)) - 1 ),' ','')))
    ELSE
        bal.Origin
END AS FRST_STA_CD,
bal.OriginZip,
bal.DestCountry,
CASE
    WHEN CHARINDEX(',', bal.Dest) > 0 then
        RTRIM(LTRIM(LEFT(bal.Dest, CHARINDEX(',', bal.Dest) - 1)))
    ELSE
        bal.Dest
END AS LAST_CTY_NAME,
CASE
    WHEN CHARINDEX(',', bal.Dest) > 0 then
        RTRIM(LTRIM(REPLACE(RIGHT(bal.Dest, CHARINDEX(',', reverse(bal.Dest)) - 1 ),' ','')))
    ELSE
        bal.Dest
END AS LAST_STA_CD,
bal.DestZip,
'Bid App Lanes' AS TableName

FROM USCTTDEV.dbo.tblBidAppLanes bal
INNER JOIN USCTTDEV.dbo.tblBidAppRates bar ON bar.LaneID = bal.laneID

WHERE bar.EQUIPMENT = '53IM'
AND bal.OriginZip IS NOT NULL
) lanes
) lanes

INNER JOIN (
SELECT DISTINCT LEFT(ald.FRST_SHPG_LOC_CD,4) AS FRST_SHPG_LOC_CD,
CASE WHEN ald.FRST_CTRY_CD = 'USA' THEN LEFT(ald.FRST_PSTL_CD,5) ELSE ald.FRST_PSTL_CD END AS FRST_PSTL_CD,
ald.FRST_CTY_NAME,
ald.Origin_Zone
FROM USCTTDEV.dbo.tblActualLoadDetail ald
WHERE CAST(SHPD_DTT AS DATE) >= CAST(GETDATE() - 365 AS DATE) 
AND LEFT(ald.FRST_SHPG_LOC_CD,1) <> 'V'
AND ald.EQMT_TYP = '53IM'
) origins ON origins.Origin_Zone = lanes.Origin_Zone
AND lanes.RowNumber = 1

LEFT JOIN (
SELECT DISTINCT ald.Lane,
ald.DestinationPlant AS LAST_SHPG_LOC,
ald.CustomerHierarchy,
CASE WHEN LEFT(ald.DestinationPlant ,1) = '5' THEN RIGHT(ald.LAST_SHPG_LOC_CD,8) ELSE ald.DestinationPlant END AS LAST_SHPG_LOC_CD,
ald.LAST_SHPG_LOC_NAME,
ald.LAST_CTY_NAME,
ald.LAST_STA_CD,
CASE WHEN ald.LAST_CTRY_CD = 'USA' THEN LEFT(ald.LAST_PSTL_CD,5) ELSE ald.LAST_PSTL_CD END AS LAST_PSTL_CD,
SUM(CASE WHEN ald.EQMT_TYP = '53IM' THEN 1 END) AS TOFCCount,
CAST(ROUND(AVG(CASE WHEN ald.EQMT_TYP = '53IM' THEN ald.TotalCost END),2) AS NUMERIC(10,2)) AS TOFCAvgCost,
SUM(CASE WHEN ald.EQMT_TYP <> '53IM' THEN 1 END) AS OTRCount,
CAST(ROUND(AVG(CASE WHEN ald.EQMT_TYP <> '53IM' THEN ald.TotalCost END),2) AS NUMERIC(10,2)) AS OTRAvgCost,
COUNT(DISTINCT ald.LD_LEG_ID) AS TotalLoadCount
FROM USCTTDEV.dbo.tblActualLoadDetail ald
WHERE ald.SHPD_DTT >= DATEADD(MONTH, DATEDIFF(MONTH, 0, DATEADD(m, -6, GETDATE())), 0)
AND ald.EQMT_TYP <> 'LTL'
GROUP BY ald.Lane,
ald.DestinationPlant,
ald.CustomerHierarchy,
CASE WHEN LEFT(ald.DestinationPlant ,1) = '5' THEN RIGHT(ald.LAST_SHPG_LOC_CD,8) ELSE ald.DestinationPlant END,
ald.LAST_SHPG_LOC_NAME,
ald.LAST_CTY_NAME,
ald.LAST_STA_CD,
CASE WHEN ald.LAST_CTRY_CD = 'USA' THEN LEFT(ald.LAST_PSTL_CD,5) ELSE ald.LAST_PSTL_CD END
) ald ON ald.Lane = lanes.Lane

LEFT JOIN (
SELECT DISTINCT bal.Lane,
CAST(bal.Miles AS NUMERIC(10,2)) AS Miles,
CAST(ROUND(
        SUM(bar.CUR_RPM * bar.AWARD_PCT) / SUM(bar.AWARD_PCT), 
        2
      ) AS NUMERIC(10,2)) AS WeightedRPM,
CAST(ROUND(
        SUM(bar.CUR_RPM * bar.AWARD_PCT) / SUM(bar.AWARD_PCT), 
        2
      ) * bal.Miles AS NUMERIC(10,2)) AS WeightedCost
FROM USCTTDEV.dbo.tblBidAppLanes bal 
INNER JOIN USCTTDEV.dbo.tblBidAppRates bar ON bar.LaneID = bal.LaneID
WHERE bar.AWARD_PCT IS NOT NULL
AND bar.EQUIPMENT = '53IM'
GROUP BY bal.Lane,
bal.Miles
) awards ON awards.Lane = lanes.Lane

ORDER BY origins.FRST_SHPG_LOC_CD ASC, lanes.FRST_PSTL_CD ASC


