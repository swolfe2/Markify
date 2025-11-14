/*
Get high level JSON results for rows with 'SensitivityLabel' somewhere in the JSON
*/
WITH ReportScan AS (
    SELECT *
    FROM PBI_Platform_Automation.WorkspaceScanResult wsr
    WHERE wsr.Reports LIKE '%SensitivityLabel%'
      AND ISJSON(wsr.Reports) = 1
),
DatasetScan AS (
    SELECT *
    FROM PBI_Platform_Automation.WorkspaceScanResult wsr
    WHERE wsr.Datasets LIKE '%sensitivityLabel%'
      AND ISJSON(wsr.Datasets) = 1
),
DataflowScan AS (
    SELECT *
    FROM PBI_Platform_Automation.WorkspaceScanResult wsr
    WHERE wsr.Dataflows LIKE '%sensitivityLabel%'
      AND ISJSON(wsr.Dataflows) = 1
),
/*
Unpack JSON results to tabular layouts
*/
ReportsUnpacked AS (
SELECT
    s.WorkspaceId,
    s.WorkspaceName,
    r.reportType AS ObjectType,
    r.id AS ReportID,
    r.name,
    r.datasetId,
    r.createdDateTime,
    r.modifiedDateTime,
    r.modifiedBy,
    r.createdBy,
    r.modifiedById,
    r.createdById,
    r.sensitivityLabelLabelId AS sensitivityLabelId
FROM ReportScan AS s
CROSS APPLY OPENJSON(s.Reports)
WITH (
    reportType               nvarchar(50)       '$.reportType',
    id                       uniqueidentifier   '$.id',
    name                     nvarchar(512)      '$.name',
    datasetId                uniqueidentifier   '$.datasetId',
    createdDateTime          datetime2(3)       '$.createdDateTime',
    modifiedDateTime         datetime2(3)       '$.modifiedDateTime',
    modifiedBy               nvarchar(256)      '$.modifiedBy',
    createdBy                nvarchar(256)      '$.createdBy',
    modifiedById             uniqueidentifier   '$.modifiedById',
    createdById              uniqueidentifier   '$.createdById',
    sensitivityLabelLabelId  uniqueidentifier   '$.sensitivityLabel.labelId'
) AS r
WHERE r.sensitivityLabelLabelId IS NOT NULL
),
DatasetsUnpacked AS (
SELECT
    s.WorkspaceId,
    s.WorkspaceName,
    'Dataset' AS ObjectType,
    d.id AS DatasetId,
    d.name AS DatasetName,
    d.configuredBy,
    d.configuredById,
    d.createdDate,
    d.targetStorageMode,
    d.contentProviderType,
    d.sensitivityLabelLabelId AS SensitivityLabelId
FROM DatasetScan AS s
CROSS APPLY OPENJSON(s.Datasets)
WITH (
    id                       uniqueidentifier   '$.id',
    name                     nvarchar(512)      '$.name',
    configuredBy             nvarchar(256)      '$.configuredBy',
    configuredById           uniqueidentifier   '$.configuredById',
    createdDate              datetime2(3)       '$.createdDate',
    targetStorageMode        nvarchar(50)       '$.targetStorageMode',
    contentProviderType      nvarchar(50)       '$.contentProviderType',
    sensitivityLabelLabelId  uniqueidentifier   '$.sensitivityLabel.labelId'
) AS d
WHERE d.sensitivityLabelLabelId IS NOT NULL
),
DataflowsUnpacked AS (
SELECT
    s.WorkspaceId,
    s.WorkspaceName,
    'Dataflow' AS ObjectType,
    f.objectId AS DataflowId,
    f.name AS DataflowName,
    f.description,
    f.configuredBy,
    f.modifiedBy,
    f.modifiedDateTime,
    f.sensitivityLabelLabelId AS SensitivityLabelId
FROM DataflowScan AS s
CROSS APPLY OPENJSON(s.Dataflows)
WITH (
    objectId                uniqueidentifier   '$.objectId',
    name                    nvarchar(512)      '$.name',
    description             nvarchar(1024)     '$.description',
    configuredBy            nvarchar(256)      '$.configuredBy',
    modifiedBy              nvarchar(256)      '$.modifiedBy',
    modifiedDateTime        datetime2(3)       '$.modifiedDateTime',
    sensitivityLabelLabelId uniqueidentifier   '$.sensitivityLabel.labelId'
) AS f
WHERE f.sensitivityLabelLabelId IS NOT NULL
)

/*
Combine and union
*/
SELECT  
du.WorkspaceID,
du.WorkspaceName,
du.ObjectType,
du.DataflowID AS ObjectID,
du.DataflowName AS ObjectName,
du.SensitivityLabelId
FROM DataflowsUnpacked du

UNION ALL

SELECT  
ru.WorkspaceID,
ru.WorkspaceName,
ru.ObjectType,
ru.ReportID AS ObjectID,
ru.name AS ObjectName,
ru.SensitivityLabelId
FROM ReportsUnpacked ru

UNION ALL

SELECT 
dat.WorkspaceID,
dat.WorkspaceName,
dat.ObjectType,
dat.DatasetID AS ObjectID,
dat.DatasetName AS ObjectName,
dat.SensitivityLabelId
FROM DatasetsUnpacked dat