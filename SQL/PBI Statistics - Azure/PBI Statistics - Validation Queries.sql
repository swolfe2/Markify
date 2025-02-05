/*
Capacity Count
- Count the total number of capacities
*/
SELECT COUNT(DISTINCT CapacityID) AS DistinctCount
FROM PBI_Platform_Automation.CapacityDetail

/*
Workspace Count
- Count the total number of Workspaces
*/
SELECT COUNT(DISTINCT WorkspaceID) AS DistinctCount
FROM PBI_Platform_Automation.WorkspaceDetail

/*
Dataset Count
- Count the total number of Datasets
*/
SELECT COUNT(DISTINCT DatasetID) AS DistinctCount
FROM PBI_Platform_Automation.DatasetDetail

/*
Dataflow Count
- Count the total number of Dataflows
*/
SELECT COUNT(DISTINCT DataflowID) AS DistinctCount
FROM PBI_Platform_Automation.DataflowDetail

/*
Datamart Count
- Count the total number of Dataflows
*/
SELECT COUNT(DISTINCT DatamartID) AS DistinctCount
FROM PBI_Platform_Automation.DatamartDetail

/*
Datasource Count
- Count the total number of Datasources
*/
SELECT COUNT(DISTINCT DatasourceID) AS DistinctCount
FROM PBI_Platform_Automation.DatasourceDetail

/*
Datasource Count
- Count the total number of Datasources
*/
SELECT COUNT(DISTINCT DatasourceID) AS DistinctCount
FROM PBI_Platform_Automation.DatasourceDetail

/*
Gateway Cluster Count
- Count the total number of Gateway Clusters
*/
SELECT COUNT(DISTINCT GatewayID) AS DistinctCount
FROM PBI_Platform_Automation.GatewayDetail

/*
Gateway Count
- Count the total number of Gateways
*/
SELECT COUNT(DISTINCT DatasourceID) AS DistinctCount
FROM PBI_Platform_Automation.GatewayDatasourceDetail

/*
Dashboard Count
- Count the total number of Dashboards
*/
SELECT COUNT(DISTINCT DashboardID) AS DistinctCount
FROM PBI_Platform_Automation.DashboardDetail

/*
Report Count
- Count the total number of Reports
*/
SELECT COUNT(DISTINCT ReportID) AS DistinctCount
FROM PBI_Platform_Automation.ReportDetail

/*
Datasource Type Count
- Count the total number of Reports
*/
SELECT COUNT(DISTINCT DatasourceType) AS DistinctCount
FROM PBI_Platform_Automation.DatasourceDetail


/*
Refresh Schedule Logic
This will take all of the JSON arrays, and expand them so there's 1 unique row for each combination
Also, this compares the scheduled time against the time zone table to convert to UTC
IF there is no refresh time provided, it will default to midnight at the current time zone
*/
SELECT
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
CROSS APPLY STRING_SPLIT(REPLACE(REPLACE(t.[ScheduleTimes], '[', ''), ']', ''), ',') s2) s

/*
Changes to Workspace Detail to capture Region and Workspace Type
*/
SELECT wd.WorkspaceID,
wd.WorkspaceType AS WorkspaceGroup,
wd.WorkspaceState,
CASE WHEN IsOnDedicatedCapacity = 1 THEN
    CASE WHEN LEFT(wd.WorkspaceName, 3) = 'GL ' THEN 'Global'
    WHEN LEFT(wd.WorkspaceName, 3) = 'AP ' THEN 'Asia Pac'
    WHEN LEFT(wd.WorkspaceName, 3) = 'NA ' THEN 'North America'
    WHEN LEFT(wd.WorkspaceName, 4) = 'LAO ' THEN 'Latin America'
    WHEN LEFT(wd.WorkspaceName, 5) = 'EMEA ' THEN 'EMEA'
    ELSE 'Naming Error' END
ELSE 'Not On Dedicated Capacity'
END AS WorkspaceRegion,
CASE WHEN IsOnDedicatedCapacity = 1 THEN
    CASE WHEN RIGHT(wd.WorkspaceName, 3) = '- D' THEN 'Development'
    WHEN RIGHT(wd.WorkspaceName, 3) = '- Q ' THEN 'Quality'
    WHEN RIGHT(wd.WorkspaceName, 7) = '- ADHOC' THEN 'Adhoc'
    WHEN RIGHT(wd.WorkspaceName, 8) = '- PUBLIC' THEN 'Public'
    WHEN LEFT(wd.WorkspaceName, 3) IN ('GL ', 'AP ', 'NA ', 'LAO', 'EME') THEN 'Production Certified'
    ELSE 'Naming Error' END
ELSE 'Not On Dedicated Capacity'
END AS WorkspaceType,
wd.WorkspaceName,
wd.Description,
wd.IsOnDedicatedCapacity,
wd.CapacityID,
wd.DataflowStorageID,
wd.HasWorkspaceLevelSettings,
wd.IsReadOnly,
wd.DeploymentPipelineID,
wd.Workbooks,
wd.CapacityMigrationStatus
FROM PBI_Platform_Automation.WorkspaceDetail wd

/*
DatasourceDetail
Parse out all JSON ConnectionDetails values into DatasourceServer and DatasourceConnection
*/
SELECT
  dsd.DatasourceType AS DatasourceBase,
  CASE
    WHEN dsd.DatasourceType = 'Extension' THEN JSON_VALUE(ConnectionDetails, '$.extensionDataSourceKind')
    ELSE dsd.DatasourceType
  END AS DatasourceType,
  CASE
    WHEN dsd.ConnectionDetails LIKE '{"server":%' THEN REPLACE(REPLACE(JSON_VALUE(dsd.ConnectionDetails, '$.server'), '"', ''), '\', '')
    WHEN dsd.ConnectionDetails LIKE '{"sharePointSiteUrl":%' THEN REPLACE(REPLACE(JSON_VALUE(dsd.ConnectionDetails, '$.sharePointSiteUrl'), '"', ''), '\', '')
    WHEN dsd.ConnectionDetails LIKE '%:"Anaplan"%' THEN REPLACE(JSON_VALUE(JSON_VALUE(dsd.ConnectionDetails, '$.extensionDataSourcePath'), '$.apiUrl'), '\\', '')
    WHEN dsd.ConnectionDetails LIKE '%:"Snowflake"%' THEN LEFT(JSON_VALUE(dsd.ConnectionDetails, '$.extensionDataSourcePath'), CHARINDEX(';', JSON_VALUE(dsd.ConnectionDetails, '$.extensionDataSourcePath')) - 1)
    WHEN dsd.ConnectionDetails LIKE '{"path":%' THEN REPLACE(JSON_VALUE(dsd.ConnectionDetails, '$.path'), '\\\\', '\\')
    WHEN dsd.ConnectionDetails LIKE '{"url":%' THEN JSON_VALUE(dsd.ConnectionDetails, '$.url')
    WHEN dsd.ConnectionDetails LIKE '{"loginServer":%' THEN JSON_VALUE(dsd.ConnectionDetails, '$.loginServer')
    WHEN dsd.ConnectionDetails LIKE '{"extensionDataSourceKind":"Databricks"%' THEN JSON_VALUE(JSON_VALUE(dsd.ConnectionDetails, '$.extensionDataSourcePath'), '$.host')
    WHEN dsd.ConnectionDetails LIKE '%"UsageMetricsDataConnector"%' THEN 'UsageMetricsDataConnector'
    WHEN dsd.ConnectionDetails LIKE '%"VSTS"%' THEN 'VSTS'
    WHEN dsd.ConnectionDetails LIKE '%"GoogleBigQuery"%' THEN 'GoogleBigQuery'
    WHEN dsd.ConnectionDetails LIKE '%"Smartsheet"%' THEN 'Smartsheet'
    WHEN dsd.ConnectionDetails LIKE '{"connectionString":%' THEN JSON_VALUE(dsd.ConnectionDetails, '$.connectionString')
    WHEN dsd.DatasourceType = 'AzureBlobs' THEN JSON_VALUE(dsd.ConnectionDetails, '$.account')
    WHEN dsd.DatasourceType = 'AzureTables' THEN JSON_VALUE(dsd.ConnectionDetails, '$.account')
    WHEN dsd.DatasourceType = 'AzureDataLakeStorage' THEN JSON_VALUE(dsd.ConnectionDetails, '$.server')
    WHEN dsd.DatasourceType = 'Exchange' THEN JSON_VALUE(dsd.ConnectionDetails, '$.emailAddress')
    WHEN dsd.DatasourceType = 'ActiveDirectory' THEN JSON_VALUE(dsd.ConnectionDetails, '$.domain')
    WHEN dsd.ConnectionDetails LIKE '{"extensionDataSourceKind":%' THEN JSON_VALUE(dsd.ConnectionDetails, '$.extensionDataSourceKind')
    ELSE dsd.ConnectionDetails
  END AS DatasourceServer,

  CASE
    WHEN dsd.ConnectionDetails LIKE '%"database":"%' THEN REPLACE(REPLACE(JSON_VALUE(dsd.ConnectionDetails, '$.database'), '"', ''), '\', '')
    WHEN dsd.ConnectionDetails LIKE '{"sharePointSiteUrl":%' THEN REPLACE(REPLACE(JSON_VALUE(dsd.ConnectionDetails, '$.sharePointSiteUrl'), '"', ''), '\', '')
    WHEN dsd.ConnectionDetails LIKE '%hana.kcc.com:32015%' THEN 'SAP/HANA Production'
    WHEN dsd.ConnectionDetails LIKE '%dev-hana.kcc.com:30115%' THEN 'SAP/HANA Development'
    WHEN dsd.ConnectionDetails LIKE '%qa-hana.kcc.com:31015%' THEN 'SAP/HANA Quality'
    WHEN dsd.ConnectionDetails LIKE '%:"Anaplan"%' THEN REPLACE(JSON_VALUE(JSON_VALUE(dsd.ConnectionDetails, '$.extensionDataSourcePath'), '$.authUrl'), '\\', '')
    WHEN dsd.ConnectionDetails LIKE '{"extensionDataSourceKind":"Snowflake",%' THEN RIGHT(
      JSON_VALUE(dsd.ConnectionDetails, '$.extensionDataSourcePath'),
      CHARINDEX(';', REVERSE(JSON_VALUE(dsd.ConnectionDetails, '$.extensionDataSourcePath'))) - 1
      )
    WHEN dsd.ConnectionDetails LIKE '{"extensionDataSourceKind":"Databricks"%' THEN JSON_VALUE(JSON_VALUE(dsd.ConnectionDetails, '$.extensionDataSourcePath'), '$.httpPath')
    WHEN dsd.ConnectionDetails LIKE '{"loginServer":%' THEN JSON_VALUE(dsd.ConnectionDetails, '$.classInfo')
    WHEN dsd.ConnectionDetails LIKE '%"VSTS"%' THEN JSON_VALUE(dsd.ConnectionDetails, '$.extensionDataSourcePath')
    WHEN dsd.ConnectionDetails LIKE '%"UsageMetricsDataConnector"%' THEN 'UsageMetricsDataConnector'
    WHEN dsd.DatasourceType = 'AzureBlobs' THEN CASE
        WHEN dsd.ConnectionDetails LIKE '%{"url":%' THEN JSON_VALUE(dsd.ConnectionDetails, '$.url')
        ELSE JSON_VALUE(dsd.ConnectionDetails, '$.domain')
      END
    WHEN dsd.DatasourceType = 'AzureTables' THEN JSON_VALUE(dsd.ConnectionDetails, '$.domain')
    WHEN dsd.DatasourceType = 'AzureDataLakeStorage' THEN JSON_VALUE(dsd.ConnectionDetails, '$.path')
    WHEN dsd.ConnectionDetails LIKE '%"GoogleBigQuery"%' THEN 'GoogleBigQuery'
    WHEN dsd.ConnectionDetails LIKE '%"Smartsheet"%' THEN 'Smartsheet'
    WHEN dsd.DatasourceType = 'Exchange' THEN JSON_VALUE(dsd.ConnectionDetails, '$.emailAddress')
    WHEN dsd.DatasourceType = 'ActiveDirectory' THEN JSON_VALUE(dsd.ConnectionDetails, '$.domain')
    WHEN dsd.ConnectionDetails LIKE '%"extensionDataSourcePath":%' THEN JSON_VALUE(dsd.ConnectionDetails, '$.extensionDataSourcePath')
    WHEN dsd.ConnectionDetails LIKE '{"path":%' THEN REPLACE(JSON_VALUE(dsd.ConnectionDetails, '$.path'), '\\\\', '\\')
    WHEN dsd.ConnectionDetails LIKE '{"url":%' THEN JSON_VALUE(dsd.ConnectionDetails, '$.url')
    WHEN dsd.ConnectionDetails LIKE '{"connectionString":%' THEN JSON_VALUE(dsd.ConnectionDetails, '$.connectionString')
    ELSE dsd.ConnectionDetails
  END AS DatasourceConnection,
  dsd.ConnectionDetails,
  dsd.DatasourceID,
  dsd.GatewayID,
  dsd.ArtifactID,
  CASE WHEN dsd.ArtifactType = 'Dataset' THEN 'Semantic Model' ELSE dsd.ArtifactType END AS ArtifactType,
  dsd.WorkspaceID
FROM PBI_Platform_Automation.DatasourceDetail dsd

/*
DataObjects table in Datamodel
Get all unique Dataset, Dataflow, and Datamart IDs with the Type and Configured By
*/
SELECT 
dsd.WorkspaceID,
dsd.DatasetID,
dsd.DatasetName,
dsd.ContentProviderType AS ContentProviderType,
CASE 
    WHEN dsd.ContentProviderType IN ('CSV', 'Excel', 'InImportMode', 'PbixInImportMode') THEN 'Import'
    WHEN dsd.ContentProviderType IN ('InCompositeMode', 'PbixInCompositeMode') THEN 'Composite'
    WHEN dsd.ContentProviderType IN ('InDirectQueryMode', 'PbixInDirectQueryMode') THEN 'Direct Query'
    WHEN dsd.ContentProviderType IN ('PbixInLiveConnectionMode') THEN 'Live'
    WHEN dsd.ContentProviderType LIKE 'RealTime%' THEN 'Real Time'
    WHEN dsd.ContentProviderType LIKE 'UsageMetrics%' THEN 'Usage Metrics'
ELSE 'Unknown' END AS StorageMode,
dsd.CreatedDate,
dsd.ConfiguredBy,
'https://app.powerbi.com/groups/' + dsd.WorkspaceID + '/datasets/' + dsd.DatasetID + '/details' AS DatasetURL,
'Semantic Model' AS ObjectType
FROM PBI_Platform_Automation.DatasetDetail dsd

UNION ALL

SELECT 
dfd.WorkspaceID,
dfd.DataflowID,
dfd.Name,
'Dataflow' AS ContentProviderType,
'Import' AS StorageMode,
'' AS CreatedDate,
dfd.ConfiguredBy,
'https://app.powerbi.com/groups/' + dfd.WorkspaceID + '/dataflows/' + dfd.DataflowID  AS DatasetURL,
'Dataflow' AS ObjectType
FROM PBI_Platform_Automation.DataflowDetail dfd

UNION ALL 

SELECT 
dmd.WorkspaceID,
dmd.DatamartID,
dmd.DatamartName,
dmd.DatamartType,
'Import' AS StorageMode,
dmd.ModifiedDateTime,
CASE WHEN dmd.ModifiedBy IS NULL THEN dmd.ConfiguredBy ELSE dmd.ModifiedBy END AS DatamartOwner,
'https://app.powerbi.com/groups/' + dmd.WorkspaceID + '/datamarts/' + dmd.DatamartID  AS DatasetURL,
'Datamart' AS ObjectType
FROM PBI_Platform_Automation.DatamartDetail dmd
