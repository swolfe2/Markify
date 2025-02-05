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