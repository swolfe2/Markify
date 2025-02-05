DECLARE @Today DATE = GETDATE();
DECLARE @TwoWeeksAgo DATE = DATEADD(dd, DATEPART(DW,@Today)*-1-13, @Today);

WITH RankedRefreshDetail AS 
(
   SELECT
      c.WorkspaceID,
      d.WorkspaceName,
      c.DatasetID,
      RefreshName AS DatasetName,
      CAST(ROUND(AverageDuration / 60, 2) AS NUMERIC(10, 2)) AS AverageDurationMinutes,
      RefreshesPerDay,
      LastRefreshStartTime AS LastRefreshTime,
      c.ConfiguredBy,
      ROW_NUMBER() OVER (PARTITION BY RefreshName 
   ORDER BY
      LastRefreshStartTime DESC) AS row_num 
   FROM
      PBI_Platform_Automation.RefreshDetail AS c 
      INNER JOIN
         [PBI_Platform_Automation].[DatasetDetail] AS b 
         ON (c.DatasetID = b.DatasetID) 
      INNER JOIN
         [PBI_Platform_Automation].[workspaceDetail] AS d 
         ON (c.WorkspaceID = d.WorkspaceID) 
   WHERE
      Kind = 'Dataset' 
      AND c.CapacityID IN 
      (
         'CC10DC9F-8F94-4DD9-80CB-C29A580EDA70',
         --New Dev/Qual Capacity ID as of 11/1/2023
         '8E32EF36-AA16-4FEC-86BA-D2DBDAA70963'
      )
      -- Adhoc Capacity
      AND AverageDuration > 0
      AND CAST(c.LastRefreshStartTime AS DATE) >= @TwoWeeksAgo
)

SELECT
   LEFT(data.WorkspaceName, CHARINDEX(' ', data.WorkspaceName + ' ') - 1) AS WorkspaceRegion,
   RIGHT(data.WorkspaceName, LEN(data.WorkspaceName) - CHARINDEX(' - ', data.WorkspaceName) - 2) AS WorkspaceType,
   data.WorkspaceID,
   data.WorkspaceName,
   data.DatasetID,
   data.DatasetName,
   data.DatasetURL,
   data.ConfiguredBy,
   data.LastRefreshTime,
   data.RefreshesPerDay,
   data.AverageDurationMinutes,
   data.RefreshFrequency,
   data.MaximumRefreshMinutes,
   CASE
      WHEN
         data.AverageDurationMinutes > data.MaximumRefreshMinutes 
      THEN
         'Non-Compliant' 
      ELSE
         'Compliant' 
   END
   AS ComplianceFlag, 
   CASE
      WHEN
         data.AverageDurationMinutes > data.MaximumRefreshMinutes 
      THEN
         data.AverageDurationMinutes - data.MaximumRefreshMinutes 
   END
   AS AverageMinutesOverLimit, CAST(
   CASE
      WHEN
         data.AverageDurationMinutes > data.MaximumRefreshMinutes 
      THEN
         ROUND((data.AverageDurationMinutes - data.MaximumRefreshMinutes) * data.RefreshesperDay, 2) 
   END
   AS NUMERIC(10, 2)) AS TotalMinutesOverLimit 
FROM
   (
      SELECT
         a.WorkspaceID,
         a.WorkspaceName,
         a.DatasetID,
         a.DatasetName,
         'https://app.powerbi.com/groups/' + a.WorkspaceID + '/settings/datasets/' + a.DatasetID AS DatasetURL,
         AverageDurationMinutes,
         RefreshesPerDay,
         LastRefreshTime,
         SUBSTRING(a.ConfiguredBy, 3, LEN(a.ConfiguredBy) - 4) AS ConfiguredBy,
         CASE
            WHEN
               a.RefreshesPerDay > 24 
            THEN
               'More than Hourly' 
            WHEN
               a.RefreshesPerDay = 24 
            THEN
               'Hourly' 
            WHEN
               a.RefreshesPerDay BETWEEN 7 AND 24 
            THEN
               'Every 2 Hours' 
            WHEN
               a.RefreshesPerDay BETWEEN 4 AND 6 
            THEN
               'Every 4 Hours' 
            WHEN
               a.RefreshesPerDay BETWEEN 2 AND 3 
            THEN
               'Every 8 Hours' 
            WHEN
               a.RefreshesPerDay = 1 
            THEN
               'Daily' 
            WHEN
               a.RefreshesPerDay BETWEEN 0 AND 1 
            THEN
               'Weekly' 
            ELSE
               'Less than Weekly' 
         END
         AS RefreshFrequency, 
         CASE
            WHEN
               a.RefreshesPerDay > 24 
            THEN
               1 
            WHEN
               a.RefreshesPerDay = 24 
            THEN
               4 
            WHEN
               a.RefreshesPerDay BETWEEN 7 AND 24 
            THEN
               8 
            WHEN
               a.RefreshesPerDay BETWEEN 4 AND 6 
            THEN
               15 
            WHEN
               a.RefreshesPerDay BETWEEN 2 AND 3 
            THEN
               25 
            WHEN
               a.RefreshesPerDay = 1 
            THEN
               120 
            WHEN
               a.RefreshesPerDay BETWEEN 0 AND 1 
            THEN
               180 
            ELSE
               'Less than Weekly' 
         END
         AS MaximumRefreshMinutes 
      FROM
         RankedRefreshDetail AS a 
      WHERE
         row_num = 1 
         AND RefreshesPerDay IS NOT NULL 
         AND CAST(LastRefreshTime AS DATE) >= @TwoWeeksAgo
   )
   data 
ORDER BY
   data.RefreshesPerDay DESC, data.AverageDurationMinutes DESC;