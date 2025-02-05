/*
This query was developed by Steve Wolfe from the Data Visualization CoE Team
The intent is to analyze the Scheduled Refeshes from the PBI Service
The data will ONLY use Scheduled Refeshes that are enabled from the PBI Service
This will take all of the JSON arrays, and expand them so there's 1 unique row for each combination
Also, this compares the scheduled time against the time zone table to convert to UTC
If there is no refresh time provided, it will default to midnight at the current time zone
*/
WITH DaysOfTheWeek AS (
SELECT 'Monday' AS DayName, 1 AS DayNumber UNION ALL
SELECT 'Tuesday' AS DayName, 2 AS DayNumber UNION ALL
SELECT 'Wednesday' AS DayName, 3 AS DayNumber UNION ALL
SELECT 'Thursday' AS DayName, 4 AS DayNumber UNION ALL
SELECT 'Friday' AS DayName, 5 AS DayNumber UNION ALL
SELECT 'Saturday' AS DayName, 6 AS DayNumber UNION ALL
SELECT 'Sunday' AS DayName, 7 AS DayNumber
),

/*
This contains refresh schedule information for all refreshes that are enabled AND have a day of the week visible
--57317
*/
ScheduleWithDays AS (
SELECT
  cd.CapacityID,
  cd.CapacityName,
  wd.WorkspaceID,
  wd.WorkspaceName,
  dd.DatasetID,
  dd.DatasetName,
  REPLACE(s1.value, '"', '') AS [ScheduleDay],
  CAST(CASE
    WHEN s2.Value = '' THEN '00:00:00'
    WHEN LEN(REPLACE(s2.value, '"', '')) > 1 THEN REPLACE(s2.value, '"', '')
    ELSE NULL
  END AS time) AS [ScheduleTime],
  tz.current_utc_offset AS UTCOffset,
  CAST(REPLACE(REPLACE(tz.current_utc_offset, '+', ''), '-', '') AS time) AS OffsetTime,
  CASE
    WHEN LEFT(tz.current_utc_offset, 1) = '+' THEN 'Subtract'
    WHEN LEFT(tz.current_utc_offset, 1) = '-' THEN 'Add'
    ELSE NULL
  END AS AddSubtract,
  rsd.RefreshEnabled,
  rsd.LocalTimeZone,
  rsd.NotifyOption,
  REPLACE(REPLACE(REPLACE(rsd.ConfiguredBy, '[', ''), ']', ''), '"', '') AS [ConfiguredBy]
FROM PBI_Platform_Automation.CapacityDetail cd
INNER JOIN PBI_Platform_Automation.WorkspaceDetail wd 
    ON wd.CapacityID = cd.CapacityID
    AND wd.IsOnDedicatedCapacity = 'True'
INNER JOIN PBI_Platform_Automation.DatasetDetail dd 
    ON dd.WorkspaceID = wd.WorkspaceID 
INNER JOIN PBI_Platform_Automation.RefreshScheduleDetail rsd 
    ON rsd.DatasetID = dd.DatasetID 
    AND rsd.RefreshEnabled = 'True'
INNER JOIN sys.time_zone_info tz
  ON tz.Name = rsd.LocalTimeZone
CROSS APPLY STRING_SPLIT(REPLACE(REPLACE(rsd.[ScheduleDays], '[', ''), ']', ''), ',') s1
CROSS APPLY STRING_SPLIT(REPLACE(REPLACE(rsd.[ScheduleTimes], '[', ''), ']', ''), ',') s2
WHERE LEN ( s1.Value ) > 1),

/*
This contains refresh schedule information for all refreshes that are enabled AND DO NOT have a day of the week visible
It will cross join each unique row 7 times because these refreshes are happening daily
--7637
*/
ScheduleWithoutDays AS (
SELECT
  cd.CapacityID,
  cd.CapacityName,
  wd.WorkspaceID,
  wd.WorkspaceName,
  dd.DatasetID,
  dd.DatasetName,
  dow.DayName AS ScheduleDay,
  CAST(CASE
    WHEN s2.Value = '' THEN '00:00:00'
    WHEN LEN(REPLACE(s2.value, '"', '')) > 1 THEN REPLACE(s2.value, '"', '')
    ELSE NULL
  END AS time) AS [ScheduleTime],
  tz.current_utc_offset AS UTCOffset,
  CAST(REPLACE(REPLACE(tz.current_utc_offset, '+', ''), '-', '') AS time) AS OffsetTime,
  CASE
    WHEN LEFT(tz.current_utc_offset, 1) = '+' THEN 'Subtract'
    WHEN LEFT(tz.current_utc_offset, 1) = '-' THEN 'Add'
    ELSE NULL
  END AS AddSubtract,
  rsd.RefreshEnabled,
  rsd.LocalTimeZone,
  rsd.NotifyOption,
  REPLACE(REPLACE(REPLACE(rsd.ConfiguredBy, '[', ''), ']', ''), '"', '') AS [ConfiguredBy]
FROM PBI_Platform_Automation.CapacityDetail cd
INNER JOIN PBI_Platform_Automation.WorkspaceDetail wd 
    ON wd.CapacityID = cd.CapacityID
    AND wd.IsOnDedicatedCapacity = 'True'
INNER JOIN PBI_Platform_Automation.DatasetDetail dd 
    ON dd.WorkspaceID = wd.WorkspaceID 
INNER JOIN PBI_Platform_Automation.RefreshScheduleDetail rsd 
    ON rsd.DatasetID = dd.DatasetID 
    AND rsd.RefreshEnabled = 'True'
INNER JOIN sys.time_zone_info tz
  ON tz.Name = rsd.LocalTimeZone
CROSS APPLY STRING_SPLIT(REPLACE(REPLACE(rsd.[ScheduleDays], '[', ''), ']', ''), ',') s1
CROSS APPLY STRING_SPLIT(REPLACE(REPLACE(rsd.[ScheduleTimes], '[', ''), ']', ''), ',') s2
CROSS JOIN DaysOfTheWeek dow
WHERE LEN ( s1.Value ) < 1),

/*
Union both Day and No Day datasets together
--64954
*/
AllRows AS (
    SELECT swd.CapacityID, 
    swd.CapacityName,
    swd.WorkspaceID,
    swd.WorkspaceName,
    swd.DatasetID,
    swd.DatasetName,
    swd.ScheduleDay,
    swd.ScheduleTime,
    swd.UTCOffset,
    CASE
        WHEN swd.AddSubtract = 'Subtract' THEN CONVERT(time(0), DATEADD(SECOND, - DATEDIFF(SECOND, '00:00:00', swd.OffsetTIme), swd.ScheduleTime))
        WHEN swd.AddSubtract = 'Add' THEN DATEADD(SECOND, DATEDIFF(SECOND, 0, swd.ScheduleTime), swd.OffsetTIme)
        ELSE NULL
    END AS UTCTime,
    swd.OffsetTime,
    swd.AddSubtract,
    swd.RefreshEnabled,
    swd.LocalTimeZone,
    swd.NotifyOption,
    swd.ConfiguredBy
    FROM ScheduleWithDays swd

    UNION ALL 

    SELECT
    swod.CapacityID, 
    swod.CapacityName,
    swod.WorkspaceID,
    swod.WorkspaceName,
    swod.DatasetID,
    swod.DatasetName,
    swod.ScheduleDay,
    swod.ScheduleTime,
    swod.UTCOffset,
    CASE
        WHEN swod.AddSubtract = 'Subtract' THEN CONVERT(time(0), DATEADD(SECOND, - DATEDIFF(SECOND, '00:00:00', swod.OffsetTIme), swod.ScheduleTime))
        WHEN swod.AddSubtract = 'Add' THEN DATEADD(SECOND, DATEDIFF(SECOND, 0, swod.ScheduleTime), swod.OffsetTIme)
        ELSE NULL
    END AS UTCTime,
    swod.OffsetTime,
    swod.AddSubtract,
    swod.RefreshEnabled,
    swod.LocalTimeZone,
    swod.NotifyOption,
    swod.ConfiguredBy
    FROM ScheduleWithoutDays swod
)

/*
Final query logic
*/
SELECT DISTINCT
    ar.CapacityID, 
    ar.CapacityName,
    ar.WorkspaceID,
    ar.WorkspaceName,
    CASE WHEN LEFT(ar.WorkspaceName, 3) = 'GL ' THEN 'Global'
        WHEN LEFT(ar.WorkspaceName, 3) = 'AP ' THEN 'Asia Pac'
        WHEN LEFT(ar.WorkspaceName, 3) = 'NA ' THEN 'North America'
        WHEN LEFT(ar.WorkspaceName, 4) = 'LAO ' THEN 'Latin America'
        WHEN LEFT(ar.WorkspaceName, 5) = 'EMEA ' THEN 'EMEA'
        ELSE 'Naming Error' 
    END AS WorkspaceRegion,
    CASE WHEN RIGHT(ar.WorkspaceName, 3) = '- D' THEN 'Development'
        WHEN RIGHT(ar.WorkspaceName, 3) = '- Q ' THEN 'Quality'
        WHEN RIGHT(ar.WorkspaceName, 7) = '- ADHOC' THEN 'Adhoc'
        WHEN RIGHT(ar.WorkspaceName, 8) = '- PUBLIC' THEN 'Public'
        WHEN LEFT(ar.WorkspaceName, 3) IN ('GL ', 'AP ', 'NA ', 'LAO', 'EME') THEN 'Production Certified'
        ELSE 'Naming Error' 
    END AS WorkspaceType, 
    ar.DatasetID,
    ar.DatasetName,
    'https://app.powerbi.com/groups/' + ar.WorkspaceID + '/settings/datasets/' + ar.DatasetID AS DatasetURL,
    ar.ScheduleDay,
    dotw.DayNumber AS ScheduleDayNumber,
    ar.LocalTimeZone,
    ar.ScheduleTime,
    CONVERT(varchar(5), CONVERT(time, DATEADD(HOUR, DATEDIFF(HOUR, 0, ar.ScheduleTime), 0)), 108) AS [RoundedScheduleTime],
    CONVERT(varchar(5), CONVERT(time, DATEADD(HOUR, DATEDIFF(HOUR, 0, ar.ScheduleTime), 0)), 108) + ' - ' + CONVERT(varchar(5), CONVERT(time, DATEADD(HOUR, DATEDIFF(HOUR, 0, ar.ScheduleTime) + 1, 0)), 108) AS [RoundedScheduleTimeBin],
    ar.UTCOffset,
    ar.OffsetTime,
    ar.UTCTime,
    CONVERT(varchar(5), CONVERT(time, DATEADD(HOUR, DATEDIFF(HOUR, 0, ar.UTCTime), 0)), 108) AS [RoundedScheduleUTCTime],
    CONVERT(varchar(5), CONVERT(time, DATEADD(HOUR, DATEDIFF(HOUR, 0, ar.UTCTime), 0)), 108) + ' - ' + CONVERT(varchar(5), CONVERT(time, DATEADD(HOUR, DATEDIFF(HOUR, 0, ar.UTCTime) + 1, 0)), 108) AS [RoundedScheduleUTCTimeBin],
    ar.AddSubtract,
    ar.RefreshEnabled,
    ar.NotifyOption,
    CASE WHEN ar.ConfiguredBy = 'null' THEN NULL ELSE LOWER ( ar.ConfiguredBy ) END AS DatasetOwner
FROM AllRows ar
INNER JOIN DaysOfTheWeek dotw 
    ON dotw.DayName = ar.ScheduleDay
