SELECT
  lanes.Lane,
  lanes.ORIG_CITY_STATE,
  lanes.DEST_CITY_STATE,
  lanes.OriginCountry,
  lanes.Origin,
  lanes.OriginZip,
  lanes.DestCountry,
  lanes.Dest,
  lanes.DestZIP,
  lanes.Source,
  CASE WHEN baseline.Lane IS NULL THEN 'No Historic Base' ELSE 'Historic Base' END AS Historic,
  baseline.HistoricLoadCount,
  baseline.SeptemberLoads,
  baseline.OctoberLoads,
  baseline.NovemberLoads,
  baseline.DecemberLoads,
  baseline.JanuaryLoads,
  baseline.FebruaryLoads,
  CASE WHEN last8Weeks.Lane IS NULL THEN 'Not Last 8 Weeks' ELSE ' Last 8 Weeks' END AS Last8Weeks,
  last8Weeks.[8WeeksAgo]+
  last8Weeks.[7WeeksAgo]+
  last8Weeks.[6WeeksAgo]+
  last8Weeks.[5WeeksAgo]+
  last8Weeks.[4WeeksAgo]+
  last8Weeks.[3WeeksAgo]+
  last8Weeks.[2WeeksAgo]+
  last8Weeks.[1WeekAgo]
  [8WeeksLoadCount],
  last8Weeks.[8WeeksAgo],
  last8Weeks.[7WeeksAgo],
  last8Weeks.[6WeeksAgo],
  last8Weeks.[5WeeksAgo],
  last8Weeks.[4WeeksAgo],
  last8Weeks.[3WeeksAgo],
  last8Weeks.[2WeeksAgo],
  last8Weeks.[1WeekAgo],
  piv.CustomersWithVolume,
  piv.CustomersNoVolume,
  piv.CustomersWithVolume,
  piv.CustomersNoVolume,
  piv.OrderTypeWithVolume,
  piv.OrderTypeNoVolume,
  piv.BUWithVolume,
  piv.BUNoVolume,
  piv.BUSegmentWithVolume,
  piv.BUSegmentNoVolume,
  piv.NameWithVolume,
  piv.NameNoVolume

FROM (SELECT DISTINCT
  bal.Lane,
  bal.OriginCountry,
  bal.ORIG_CITY_STATE,
  bal.Origin,
  bal.OriginZIP,
  bal.DestCountry,
  bal.DEST_CITY_STATE,
  bal.DEST,
  bal.DestZIP,
  'Bid App Lanes' AS Source
FROM USCTTDEV.dbo.tblBidAppLanes bal

UNION ALL

SELECT
  data.Lane,
  data.FRST_CTRY_CD,
  data.ORIGIN_ZONE,
  data.ORIGIN,
  data.OriginZIP,
  data.LAST_CTRY_CD,
  data.DEST_ZONE,
  data.DEST,
  data.DestZip,
  'Actual Load Detail' AS Source
FROM (SELECT DISTINCT
  ald.Lane,
  ald.FRST_CTRY_CD,
  ald.Origin_Zone,
  ald.FRST_CTY_NAME + ', ' + ald.FRST_STA_CD AS Origin,
  CASE
    WHEN ald.FRST_CTRY_CD = 'USA' THEN LEFT(ald.FRST_PSTL_CD, 5)
    ELSE ald.FRST_PSTL_CD
  END AS OriginZip,
  ald.LAST_CTRY_CD,
  ald.Dest_Zone,
  ald.LAST_CTY_NAME + ', ' + ald.LAST_STA_CD AS Dest,
  CASE
    WHEN ald.LAST_CTRY_CD = 'USA' THEN LEFT(ald.LAST_PSTL_CD, 5)
    ELSE ald.LAST_PSTL_CD
  END AS DestZip,
  COUNT(*) AS LoadCount,
  RANK() OVER (PARTITION BY Lane ORDER BY COUNT(*) DESC) AS Rank
FROM USCTTDEV.dbo.tblActualLoadDetail ald
WHERE CAST(ald.SHPD_DTT AS date) >= CAST('10/1/2019' AS date)
GROUP BY ald.Lane,
         ald.FRST_CTRY_CD,
         ald.Origin_Zone,
         ald.FRST_CTY_NAME + ', ' + ald.FRST_STA_CD,
         CASE
           WHEN ald.FRST_CTRY_CD = 'USA' THEN LEFT(ald.FRST_PSTL_CD, 5)
           ELSE ald.FRST_PSTL_CD
         END,
         ald.LAST_CTRY_CD,
         ald.Dest_Zone,
         ald.LAST_CTY_NAME + ', ' + ald.LAST_STA_CD,
         CASE
           WHEN ald.LAST_CTRY_CD = 'USA' THEN LEFT(ald.LAST_PSTL_CD, 5)
           ELSE ald.LAST_PSTL_CD
         END) data
LEFT JOIN USCTTDEV.dbo.tblBidAppLanes bal
  ON bal.Lane = data.Lane
WHERE bal.Lane IS NULL
AND data.Rank = 1) lanes
/*
Get Historical Baseline set
From September 2019 - Febrauary 2020
*/
LEFT JOIN(
SELECT DISTINCT ald.Lane, 
COUNT(DISTINCT ald.LD_LEG_ID) AS HistoricLoadCount,
SUM(CASE WHEN ald.SHPD_DTT >= '9/1/2019' AND ald.SHPD_DTT < '10/1/2019' THEN 1 ELSE 0 END) AS SeptemberLoads,
SUM(CASE WHEN ald.SHPD_DTT >= '10/1/2019' AND ald.SHPD_DTT < '11/1/2019' THEN 1 ELSE 0 END) AS OctoberLoads,
SUM(CASE WHEN ald.SHPD_DTT >= '11/1/2019' AND ald.SHPD_DTT < '12/1/2019' THEN 1 ELSE 0 END) AS NovemberLoads,
SUM(CASE WHEN ald.SHPD_DTT >= '12/1/2019' AND ald.SHPD_DTT < '1/1/2020' THEN 1 ELSE 0 END) AS DecemberLoads,
SUM(CASE WHEN ald.SHPD_DTT >= '1/1/2020' AND ald.SHPD_DTT < '2/1/2020' THEN 1 ELSE 0 END) AS JanuaryLoads,
SUM(CASE WHEN ald.SHPD_DTT >= '2/1/2020' AND ald.SHPD_DTT < '3/1/2020' THEN 1 ELSE 0 END) AS FebruaryLoads
FROM USCTTDEV.dbo.tblActualLoadDetail ald
WHERE ald.SHPD_DTT BETWEEN '9/1/2019' AND '2/29/2020'
GROUP BY ald.Lane
) baseline ON baseline.Lane = lanes.Lane

/*
Get the last 8 weeks counts by lane, excluding the current week
*/
LEFT JOIN(
SELECT DISTINCT Lane,
CASE WHEN [8] IS NULL THEN 0 ELSE [8] END AS [8WeeksAgo],
CASE WHEN [7] IS NULL THEN 0 ELSE [7] END AS [7WeeksAgo],
CASE WHEN [6] IS NULL THEN 0 ELSE [6] END AS [6WeeksAgo],
CASE WHEN [5] IS NULL THEN 0 ELSE [5] END AS [5WeeksAgo],
CASE WHEN [4] IS NULL THEN 0 ELSE [4] END AS [4WeeksAgo],
CASE WHEN [3] IS NULL THEN 0 ELSE [3] END AS [3WeeksAgo],
CASE WHEN [2] IS NULL THEN 0 ELSE [2] END AS [2WeeksAgo],
CASE WHEN [1] IS NULL THEN 0 ELSE [1] END AS [1WeekAgo]
FROM(
SELECT * FROM
(
SELECT DISTINCT
ald.Lane,
/*CAST(ald.SHPD_DTT AS DATE) AS SHPD_DTT,
DATEPART(week,CAST(GETDATE() AS Date)) AS CurrentWeek,*/
DATEPART(week,CAST(GETDATE() AS Date)) - DATEPART(week, CAST(ald.SHPD_DTT AS DATE)) AS WeeksAgo,
ISNULL(COUNT(DISTINCT LD_LEG_ID),0) AS LoadCount
FROM USCTTDEV.dbo.tblActualLoadDetail ald
WHERE DATEPART(week,CAST(ald.SHPD_DTT AS DATE)) BETWEEN DATEPART(week,CAST(GETDATE() AS Date)) - 8 AND DATEPART(week,CAST(GETDATE() AS Date))
AND YEAR(ald.SHPD_DTT) = YEAR(GETDATE())
AND DATEPART(week,CAST(GETDATE() AS Date)) <> DATEPART(week, CAST(ald.SHPD_DTT AS Date))
GROUP BY ald.Lane, DATEPART(week,CAST(GETDATE() AS Date)) - DATEPART(week, CAST(ald.SHPD_DTT AS DATE))
)  data
PIVOT(
    SUM(LoadCount)
    FOR WeeksAgo IN (
        [8], 
        [7], 
        [6], 
        [5], 
        [4], 
        [3], 
        [2],
		[1])
) AS last8Weeks
) last8WeeksF
) last8Weeks ON last8Weeks.Lane = lanes.Lane

LEFT JOIN (
SELECT DISTINCT
/*
All customers with volume, sorted descending
*/
  volume.Lane,
  STUFF((SELECT
    ', ' + CONCAT(CustomerHierarchy, ' - (', COUNT, ')')
  FROM (SELECT DISTINCT
    ald.Lane,
    ald.CustomerHierarchy,
    COUNT(*) AS COUNT,
    ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(*) DESC) AS Rank
  FROM USCTTDEV.dbo.tblActualLoadDetail ald
  WHERE CAST(ald.SHPD_DTT AS date) >= '9/1/2019'
  GROUP BY ald.Lane,
           ald.CustomerHierarchy
		   ) wvol
  WHERE wvol.Lane = volume.Lane
  /*AND wvol.Rank <= 5*/
  ORDER BY COUNT DESC
  FOR xml PATH (''), TYPE)
  .value('.', 'varchar(max)'), 1, 1, '')
  AS CustomersWithVolume,

  /*
All customers by volume, sorted descending
*/
  STUFF((SELECT
    ', ' + CustomerHierarchy
  FROM (SELECT DISTINCT
    ald.Lane,
    ald.CustomerHierarchy,
    COUNT(*) AS COUNT,
    ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(*) DESC) AS Rank
  FROM USCTTDEV.dbo.tblActualLoadDetail ald
  WHERE CAST(ald.SHPD_DTT AS date) >= '9/1/2019'
  /*AND Rank <= 5*/
  GROUP BY ald.Lane,
           ald.CustomerHierarchy) nvol
  WHERE nvol.Lane = volume.Lane
  /*AND nvol.Rank <= 5*/
  ORDER BY COUNT DESC
  FOR xml PATH (''), TYPE)
  .value('.', 'varchar(max)'), 1, 1, '')
  AS CustomersNoVolume,

  /*
All order types with volume, sorted descending
*/
    STUFF((SELECT
    ', ' + CONCAT(OrderType, ' - (', COUNT, ')')
  FROM (SELECT DISTINCT
    ald.Lane,
    ald.OrderType,
    COUNT(*) AS COUNT,
    ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(*) DESC) AS Rank
  FROM USCTTDEV.dbo.tblActualLoadDetail ald
  WHERE CAST(ald.SHPD_DTT AS date) >= '9/1/2019'
  GROUP BY ald.Lane,
           ald.OrderType
		   ) wvol
  WHERE wvol.Lane = volume.Lane
  /*AND wvol.Rank <= 5*/
  ORDER BY COUNT DESC
  FOR xml PATH (''), TYPE)
  .value('.', 'varchar(max)'), 1, 1, '')
  AS OrderTypeWithVolume,

  /*
All customers by volume, sorted descending
*/
    STUFF((SELECT
    ', ' + OrderType
  FROM (SELECT DISTINCT
    ald.Lane,
    ald.OrderType,
    COUNT(*) AS COUNT,
    ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(*) DESC) AS Rank
  FROM USCTTDEV.dbo.tblActualLoadDetail ald
  WHERE CAST(ald.SHPD_DTT AS date) >= '9/1/2019'
  /*AND Rank <= 5*/
  GROUP BY ald.Lane,
           ald.OrderType) nvol
  WHERE nvol.Lane = volume.Lane
  /*AND nvol.Rank <= 5*/
  ORDER BY COUNT DESC
  FOR xml PATH (''), TYPE)
  .value('.', 'varchar(max)'), 1, 1, '')
  AS OrderTypeNoVolume,

  /*
All BU with volume, sorted descending
*/
      STUFF((SELECT
    ', ' + CONCAT(BU, ' - (', COUNT, ')')
  FROM (SELECT DISTINCT
    ald.Lane,
    ald.BU,
    COUNT(*) AS COUNT,
    ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(*) DESC) AS Rank
  FROM USCTTDEV.dbo.tblActualLoadDetail ald
  WHERE CAST(ald.SHPD_DTT AS date) >= '9/1/2019'
  GROUP BY ald.Lane,
           ald.BU
		   ) wvol
  WHERE wvol.Lane = volume.Lane
  /*AND wvol.Rank <= 5*/
  ORDER BY COUNT DESC
  FOR xml PATH (''), TYPE)
  .value('.', 'varchar(max)'), 1, 1, '')
  AS BUWithVolume,

  /*
All BU by volume, sorted descending
*/
    STUFF((SELECT
    ', ' + BU
  FROM (SELECT DISTINCT
    ald.Lane,
    ald.BU,
    COUNT(*) AS COUNT,
    ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(*) DESC) AS Rank
  FROM USCTTDEV.dbo.tblActualLoadDetail ald
  WHERE CAST(ald.SHPD_DTT AS date) >= '9/1/2019'
  /*AND Rank <= 5*/
  GROUP BY ald.Lane,
           ald.BU) nvol
  WHERE nvol.Lane = volume.Lane
  /*AND nvol.Rank <= 5*/
  ORDER BY COUNT DESC
  FOR xml PATH (''), TYPE)
  .value('.', 'varchar(max)'), 1, 1, '')
  AS BUNoVolume,

  /*
All BUSegments with volume, sorted descending
*/
  STUFF((SELECT
    ', ' + CONCAT(BUSegment, ' - (', COUNT, ')')
  FROM (SELECT DISTINCT
    ald.Lane,
    ald.BUSegment,
    COUNT(*) AS COUNT,
    ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(*) DESC) AS Rank
  FROM USCTTDEV.dbo.tblActualLoadDetail ald
  WHERE CAST(ald.SHPD_DTT AS date) >= '9/1/2019'
  GROUP BY ald.Lane,
           ald.BUSegment
		   ) wvol
  WHERE wvol.Lane = volume.Lane
  /*AND wvol.Rank <= 5*/
  ORDER BY COUNT DESC
  FOR xml PATH (''), TYPE)
  .value('.', 'varchar(max)'), 1, 1, '')
  AS BUSegmentWithVolume,

  /*
All BUSegments by volume, sorted descending
*/
    STUFF((SELECT
    ', ' + BUSegment
  FROM (SELECT DISTINCT
    ald.Lane,
    ald.BUSegment,
    COUNT(*) AS COUNT,
    ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(*) DESC) AS Rank
  FROM USCTTDEV.dbo.tblActualLoadDetail ald
  WHERE CAST(ald.SHPD_DTT AS date) >= '9/1/2019'
  /*AND Rank <= 5*/
  GROUP BY ald.Lane,
           ald.BUSegment) nvol
  WHERE nvol.Lane = volume.Lane
  /*AND nvol.Rank <= 5*/
  ORDER BY COUNT DESC
  FOR xml PATH (''), TYPE)
  .value('.', 'varchar(max)'), 1, 1, '')
  AS BUSegmentNoVolume,

  /*
All carrier names with volume, sorted descending
*/
  	STUFF((SELECT
    ', ' + CONCAT(Name, ' - (', COUNT, ')')
  FROM (SELECT DISTINCT
    ald.Lane,
    ald.Name,
    COUNT(*) AS COUNT,
    ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(*) DESC) AS Rank
  FROM USCTTDEV.dbo.tblActualLoadDetail ald
  WHERE CAST(ald.SHPD_DTT AS date) >= '9/1/2019'
  GROUP BY ald.Lane,
           ald.Name
		   ) wvol
  WHERE wvol.Lane = volume.Lane
  /*AND wvol.Rank <= 5*/
  ORDER BY COUNT DESC
  FOR xml PATH (''), TYPE)
  .value('.', 'varchar(max)'), 1, 1, '')
  AS NameWithVolume,

  /*
All carrier names by volume, sorted descending
*/
    STUFF((SELECT
    ', ' + Name
  FROM (SELECT DISTINCT
    ald.Lane,
    ald.Name,
    COUNT(*) AS COUNT,
    ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(*) DESC) AS Rank
  FROM USCTTDEV.dbo.tblActualLoadDetail ald
  WHERE CAST(ald.SHPD_DTT AS date) >= '9/1/2019'
  /*AND Rank <= 5*/
  GROUP BY ald.Lane,
           ald.Name) nvol
  WHERE nvol.Lane = volume.Lane
  /*AND nvol.Rank <= 5*/
  ORDER BY COUNT DESC
  FOR xml PATH (''), TYPE)
  .value('.', 'varchar(max)'), 1, 1, '')
  AS NameNoVolume

  /*
  Get the unique lanes which have had volume since 9/1/2019
  */
FROM (SELECT DISTINCT
  ald.Lane,
  ald.CustomerHierarchy,
  COUNT(*) AS COUNT,
  ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(*) DESC) AS Rank
FROM USCTTDEV.dbo.tblActualLoadDetail ald
WHERE CAST(ald.SHPD_DTT AS date) >= '9/1/2019'
GROUP BY ald.Lane,
         ald.CustomerHierarchy) volume
/*WHERE volume.Rank <= 5*/
/*ORDER BY volume.Lane ASC*/
)piv ON piv.Lane = lanes.Lane

ORDER BY lanes.Lane ASC