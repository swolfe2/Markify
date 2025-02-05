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
