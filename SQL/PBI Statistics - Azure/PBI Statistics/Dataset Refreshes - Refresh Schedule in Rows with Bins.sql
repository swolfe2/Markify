
SELECT
  f.CapacityID,
  f.WorkspaceID,
  f.DatasetID,
  f.ScheduleDay,
  f.LocalTimeZone,
  f.ScheduleTime,
  CONVERT(varchar(5), CONVERT(time, DATEADD(HOUR, DATEDIFF(HOUR, 0, f.ScheduleTime), 0)), 108) AS [RoundedScheduleTime],
  CONVERT(varchar(5), CONVERT(time, DATEADD(HOUR, DATEDIFF(HOUR, 0, f.ScheduleTime), 0)), 108) + ' - ' + CONVERT(varchar(5), CONVERT(time, DATEADD(HOUR, DATEDIFF(HOUR, 0, f.ScheduleTime) + 1, 0)), 108) AS [RoundedScheduleTimeBin],
  f.UTCOffset,
  f.UTCTime,
  CONVERT(varchar(5), CONVERT(time, DATEADD(HOUR, DATEDIFF(HOUR, 0, f.UTCTime), 0)), 108) AS [RoundedScheduleUTCTime],
  CONVERT(varchar(5), CONVERT(time, DATEADD(HOUR, DATEDIFF(HOUR, 0, f.UTCTime), 0)), 108) + ' - ' + CONVERT(varchar(5), CONVERT(time, DATEADD(HOUR, DATEDIFF(HOUR, 0, f.UTCTime) + 1, 0)), 108) AS [RoundedScheduleUTCTimeBin],
  f.RefreshEnabled,
  f.NotifyOption,
  f.ConfiguredBy

FROM (SELECT
  s.DatasetID,
  s.ScheduleDay,
  s.LocalTimeZone,
  s.ScheduleTime,
  s.UTCOffset,
  CASE
    WHEN s.AddSubtract = 'Subtract' THEN CONVERT(time(0), DATEADD(SECOND, -DATEDIFF(SECOND, '00:00:00', s.OffsetTIme), s.ScheduleTime))
    WHEN s.AddSubtract = 'Add' THEN DATEADD(SECOND, DATEDIFF(SECOND, 0, s.ScheduleTime), s.OffsetTIme)
    ELSE NULL
  END AS UTCTime,
  s.RefreshEnabled,
  s.NotifyOption,
  s.CapacityID,
  s.WorkspaceID,
  s.ConfiguredBy
FROM (SELECT
  t.[DatasetID],
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
  t.RefreshEnabled,
  t.LocalTimeZone,
  t.NotifyOption,
  t.CapacityID,
  t.WorkspaceID,
  REPLACE(REPLACE(REPLACE([ConfiguredBy], '[', ''), ']', ''), '"', '') AS [ConfiguredBy]
FROM PBI_Platform_Automation.RefreshScheduleDetail t
INNER JOIN sys.time_zone_info tz
  ON tz.Name = t.LocalTimeZone
CROSS APPLY STRING_SPLIT(REPLACE(REPLACE(t.[ScheduleDays], '[', ''), ']', ''), ',') s1
CROSS APPLY STRING_SPLIT(REPLACE(REPLACE(t.[ScheduleTimes], '[', ''), ']', ''), ',') s2) s) f