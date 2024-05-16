/*
SQL Logic By: Steve Wolfe - steve.wolfe@kcc.com - Data Viz CoE
Created: 3/15/2024
Modified:
Changelog: 3.15.24 - Logic created
*/

/*
Union all semantic models, Dataflows, and Datamarts
*/
WITH models AS (
/*
Get all Semantic Models
*/
SELECT DISTINCT
dsd.WorkspaceID,
dsd.DatasetID,
dsd.DatasetName,
dsd.ConfiguredBy,
'Semantic Model' AS Type
FROM [db-pbi-platform-p-scus-1].PBI_Platform_Automation.DatasetDetail dsd
WHERE dsd.ContentProviderType NOT IN ('UsageMetricsUserReport')

UNION ALL 

/*
Get all Dataflows
*/
SELECT DISTINCT 
dfd.WorkspaceID,
dfd.DataflowID,
dfd.Name,
dfd.ConfiguredBy,
'Dataflow' AS Type
FROM [db-pbi-platform-p-scus-1].PBI_Platform_Automation.DataflowDetail dfd

UNION ALL

/*
Get all Datamarts
*/
SELECT DISTINCT 
dmd.WorkspaceID,
dmd.DatamartID,
dmd.DatamartName,
dmd.ConfiguredBy,
'Datamart' AS Type
FROM [db-pbi-platform-p-scus-1].PBI_Platform_Automation.DatamartDetail dmd
),

/*
Get Power BI Activity for non-view activities
Will be used when there is no ConfiguredBy value
*/
activity AS (
SELECT DISTINCT al.DatasetID,
al.UserID
FROM [db-pbi-platform-p-scus-1].PBI_Platform_Automation.PBIActivityLog al
INNER JOIN (
SELECT DISTINCT 
al.DatasetID,
MAX(CreationTime) AS MaxTime
FROM [db-pbi-platform-p-scus-1].PBI_Platform_Automation.PBIActivityLog al
WHERE (
al.Activity LIKE 'CANCEL%'
OR al.Activity LIKE 'CREATE%'
OR al.Activity LIKE 'DELETE%'
OR al.Activity LIKE 'EDIT%'
OR al.Activity LIKE 'REFRESH%'
OR al.Activity LIKE 'RENAME%'
OR al.Activity LIKE 'UPDATE%'
OR al.Activity IN ('RequestDataflowRefresh', 'TakeOverDataset', 'TookOverDataflow')
)
AND al.WorkspaceID IS NOT NULL
AND al.CreationTime >= DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 6, 0)
GROUP by al.DatasetID
) maxActivity ON maxActivity.DatasetID = al.DatasetId
AND maxActivity.MaxTime = al.CreationTime
WHERE al.CreationTime >= DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 6, 0)
),

/*
Get unique Workspace detail information
*/
workspace AS (
SELECT DISTINCT
CASE WHEN wd.IsOnDedicatedCapacity = 1 THEN
    CASE WHEN LEFT(wd.WorkspaceName, 3) = 'GL ' THEN 'Global'
    WHEN LEFT(wd.WorkspaceName, 3) = 'AP ' THEN 'Asia Pac'
    WHEN LEFT(wd.WorkspaceName, 3) = 'NA ' THEN 'North America'
    WHEN LEFT(wd.WorkspaceName, 4) = 'LAO ' THEN 'Latin America'
    WHEN LEFT(wd.WorkspaceName, 5) = 'EMEA ' THEN 'EMEA'
    ELSE 'Naming Error' END
ELSE 'Not On Dedicated Capacity'
END AS WorkspaceRegion,
CASE WHEN wd.IsOnDedicatedCapacity = 1 THEN
    CASE WHEN RIGHT(wd.WorkspaceName, 3) = '- D' THEN 'Development'
    WHEN RIGHT(wd.WorkspaceName, 3) = '- Q' THEN 'Quality'
    WHEN RIGHT(wd.WorkspaceName, 7) = '- ADHOC' THEN 'Adhoc'
    WHEN RIGHT(wd.WorkspaceName, 8) = '- PUBLIC' THEN 'Public'
    WHEN LEFT(wd.WorkspaceName, 3) IN ('GL ', 'AP ', 'NA ', 'LAO', 'EME') THEN 'Production Certified'
    ELSE 'Naming Error' END
ELSE 'Not On Dedicated Capacity'
END AS WorkspaceType,
wd.WorkspaceID,
wd.WorkspaceName
FROM [db-pbi-platform-p-scus-1].PBI_Platform_Automation.WorkspaceDetail wd
INNER JOIN [db-pbi-platform-p-scus-1].PBI_Platform_Automation.CapacityDetail cd
    ON cd.CapacityID = wd.CapacityID
)


/*
Get the unique Semantic Models/Dataflows/Datamarts that are configured for Scheduled Refreshes in the Power BI Service
These Semantic Models should NOT be refreshed since data in dev/qual databases does not refresh regularly
*/
SELECT DISTINCT 
cd.CapacityID,
cd.CapacityName,
wd.WorkspaceID,
wd.WorkspaceName,
wd.WorkspaceRegion,
wd.WorkspaceType,
models.DatasetID,
models.DatasetName,
'https://app.powerbi.com/groups/' + models.WorkspaceID +'/settings/datasets/' + models.DatasetID AS DatasetURL,
CASE WHEN models.ConfiguredBy IS NULL THEN a.UserID ELSE models.ConfiguredBy END AS Owner,
rd.ScheduleDays,
(SELECT COUNT(*) FROM STRING_SPLIT(rd.ScheduleDays, ',') WHERE LTRIM(RTRIM(value)) LIKE '%day%') AS ScheduleDaysCount,
rd.ScheduleTimes,
(SELECT COUNT(*) FROM STRING_SPLIT(rd.ScheduleTimes, ',') WHERE LTRIM(RTRIM(value)) LIKE '%:%') AS ScheduleTimesCount

FROM models
INNER JOIN [db-pbi-platform-p-scus-1].PBI_Platform_Automation.RefreshScheduleDetail rd
    ON rd.DatasetID = models.DatasetID
INNER JOIN [db-pbi-platform-p-scus-1].PBI_Platform_Automation.CapacityDetail cd
    ON cd.CapacityID = rd.CapacityID
INNER JOIN workspace wd
    ON wd.WorkspaceID = models.WorkspaceID
LEFT JOIN activity a 
    ON a.DatasetID = models.DatasetID
WHERE rd.RefreshEnabled = 'True'
AND RIGHT(wd.WorkspaceName, 3) IN ('- D', '- Q')
AND models.DatasetName NOT IN ('Usage Metrics Report')

