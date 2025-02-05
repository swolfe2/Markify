SELECT 
CASE WHEN dsd.DatasourceType = 'Extension'
        THEN JSON_VALUE(dsd.ConnectionDetails, '$.extensionDataSourceKind')
    ELSE dsd.DatasourceType
END AS DatasourceTypeFinal,
CASE WHEN dsd.DatasourceType = 'Extension'
        THEN JSON_VALUE(dsd.ConnectionDetails, '$.extensionDataSourcePath')
    WHEN dsd.DatasourceType = 'File'
        THEN JSON_VALUE(dsd.ConnectionDetails, '$.path')
    ELSE NULL
END AS ExtensionDataSourcePath,
dsd.*
FROM [db-pbi-platform-p-scus-1].PBI_Platform_Automation.CapacityDetail cd --Start with shared capacities
INNER JOIN [db-pbi-platform-p-scus-1].PBI_Platform_Automation.WorkspaceDetail wd ON wd.CapacityID = cd.CapacityID --Only Workspaces on shared capacities
INNER JOIN [db-pbi-platform-p-scus-1].PBI_Platform_Automation.DatasetDetail dd ON dd.WorkspaceID = wd.WorkspaceID --Only datasets on Workspaces on shared capacities
INNER JOIN [db-pbi-platform-p-scus-1].PBI_Platform_Automation.DataSourceDetail dsd ON dsd.DatasetID = dd.DatasetID --Only datasource details for datasets on Workspaces on shared capacities

/*
Get the unique entries on the shared capacities
*/
SELECT * FROM [db-pbi-platform-p-scus-1].PBI_Platform_Automation.CapacityDetail cd; 

/*
Count of total Workspace ID's
*/
SELECT COUNT(DISTINCT wd.WorkspaceID) AS WorkspaceCount
FROM [db-pbi-platform-p-scus-1].PBI_Platform_Automation.WorkspaceDetail wd;

/*
Count of Workspace ID's on CapacityDetail table
*/
SELECT COUNT(DISTINCT wd.WorkspaceID) AS WorkspaceCountOnCapacity
FROM [db-pbi-platform-p-scus-1].PBI_Platform_Automation.WorkspaceDetail wd
INNER JOIN [db-pbi-platform-p-scus-1].PBI_Platform_Automation.CapacityDetail cd 
    ON cd.CapacityID = wd.CapacityID;

SELECT * FROM [db-pbi-platform-p-scus-1].PBI_Platform_Automation.RefreshScheduleDetail rsd

/*
Get the dataset details for the Walmart Selfservice Topline dataset in question
*/
SELECT * FROM [db-pbi-platform-p-scus-1].PBI_Platform_Automation.DatasetDetail
WHERE DatasetID = 'b917abf5-6be7-4dc6-b82d-3be63a5b76db'

/*
Attempt to get the data source details for the same Walmart Selfservice Topline dataset
This will return null
*/
SELECT * FROM [db-pbi-platform-p-scus-1].PBI_Platform_Automation.DataSourceDetail
WHERE DatasetID = 'b917abf5-6be7-4dc6-b82d-3be63a5b76db'

/*
Get the DatasetID for the Walmart Selfservice Detail table in Production Certified
*/
SELECT * FROM [db-pbi-platform-p-scus-1].PBI_Platform_Automation.DatasetDetail
WHERE DatasetName = 'Walmart Selfservice Detail'
AND WorkspaceID = '81573eb3-bb82-417c-91c5-9921b9c82a17'

/*
Get the Datasource Detail information for the Walmart Selfservice Detail table
*/
SELECT * FROM [db-pbi-platform-p-scus-1].PBI_Platform_Automation.DataSourceDetail
WHERE DatasetID = '30177938-1743-4d83-a380-0469a6fb9a98'

/*
Get the unique DatasourceTypes
*/
SELECT DISTINCT DatasourceType
FROM [db-pbi-platform-p-scus-1].PBI_Platform_Automation.DataSourceDetail
ORDER BY DatasourceType ASC

/*
Count the total number of unique DatasetIDs that exist on the shared capacities
*/
SELECT COUNT(DISTINCT dd.DatasetID) AS TotalDatasetCount
FROM [db-pbi-platform-p-scus-1].PBI_Platform_Automation.CapacityDetail cd --Start with shared capacities
INNER JOIN [db-pbi-platform-p-scus-1].PBI_Platform_Automation.WorkspaceDetail wd ON wd.CapacityID = cd.CapacityID --Only Workspaces on shared capacities
INNER JOIN [db-pbi-platform-p-scus-1].PBI_Platform_Automation.DatasetDetail dd ON dd.WorkspaceID = wd.WorkspaceID --Only datasets on Workspaces on shared capacities

/*
Count the number of unique DatasetID's that exist on DatasetDetails table by flag
*/
SELECT DISTINCT 
CASE WHEN dsd.DatasetID IS NOT NULL THEN 'On Dataset Detail' ELSE 'Not On Dataset Detail' END AS DatasetFlag,
COUNT(DISTINCT dd.DatasetID) AS DatasetCount
FROM [db-pbi-platform-p-scus-1].PBI_Platform_Automation.CapacityDetail cd --Start with shared capacities
INNER JOIN [db-pbi-platform-p-scus-1].PBI_Platform_Automation.WorkspaceDetail wd ON wd.CapacityID = cd.CapacityID --Only Workspaces on shared capacities
INNER JOIN [db-pbi-platform-p-scus-1].PBI_Platform_Automation.DatasetDetail dd ON dd.WorkspaceID = wd.WorkspaceID --Only datasets on Workspaces on shared capacities
LEFT JOIN (SELECT DISTINCT DatasetID FROM [db-pbi-platform-p-scus-1].PBI_Platform_Automation.DataSourceDetail) dsd ON dsd.DatasetID = dd.DatasetID
GROUP BY CASE WHEN dsd.DatasetID IS NOT NULL THEN 'On Dataset Detail' ELSE 'Not On Dataset Detail' END

/*
Set variable for total dataset count
*/
DECLARE @totalCount NUMERIC(18,2)
SET @totalCount = (SELECT
COUNT(DISTINCT dd.DatasetID)
FROM [db-pbi-platform-p-scus-1].PBI_Platform_Automation.CapacityDetail cd --Start with shared capacities
INNER JOIN [db-pbi-platform-p-scus-1].PBI_Platform_Automation.WorkspaceDetail wd ON wd.CapacityID = cd.CapacityID --Only Workspaces on shared capacities
INNER JOIN [db-pbi-platform-p-scus-1].PBI_Platform_Automation.DatasetDetail dd ON dd.WorkspaceID = wd.WorkspaceID --Only datasets on Workspaces on shared capacities
)

/*
Count the number of unique DatasetID's that exist on DatasetDetails table by flag
*/
SELECT DISTINCT 
CASE WHEN dsd.DatasetID IS NOT NULL THEN 'On Dataset Detail' ELSE 'Not On Dataset Detail' END AS DatasetFlag, --If the DatasetID exists on DataSourceDetail or not
CAST(COUNT(DISTINCT dd.DatasetID) AS INT) AS DatasetCount,
FORMAT(ROUND(COUNT(DISTINCT dd.DatasetID) / @totalCount,4),'P') AS DatasetFlagPercent
FROM [db-pbi-platform-p-scus-1].PBI_Platform_Automation.CapacityDetail cd --Start with shared capacities
INNER JOIN [db-pbi-platform-p-scus-1].PBI_Platform_Automation.WorkspaceDetail wd ON wd.CapacityID = cd.CapacityID --Only Workspaces on shared capacities
INNER JOIN [db-pbi-platform-p-scus-1].PBI_Platform_Automation.DatasetDetail dd ON dd.WorkspaceID = wd.WorkspaceID --Only datasets on Workspaces on shared capacities
LEFT JOIN (SELECT DISTINCT DatasetID FROM [db-pbi-platform-p-scus-1].PBI_Platform_Automation.DataSourceDetail) dsd ON dsd.DatasetID = dd.DatasetID
GROUP BY CASE WHEN dsd.DatasetID IS NOT NULL THEN 'On Dataset Detail' ELSE 'Not On Dataset Detail' END

UNION ALL

/*
Count the total number of unique DatasetIDs that exist on the shared capacities
*/
SELECT DISTINCT 'Total Dataset Count', 
CAST(@totalCount AS INT) AS TotalDatasetCount,
null AS DatasetFlagPercent
FROM [db-pbi-platform-p-scus-1].PBI_Platform_Automation.CapacityDetail cd --Start with shared capacities
INNER JOIN [db-pbi-platform-p-scus-1].PBI_Platform_Automation.WorkspaceDetail wd ON wd.CapacityID = cd.CapacityID --Only Workspaces on shared capacities
INNER JOIN [db-pbi-platform-p-scus-1].PBI_Platform_Automation.DatasetDetail dd ON dd.WorkspaceID = wd.WorkspaceID --Only datasets on Workspaces on shared capacities


SELECT DISTINCT CreationTime
FROM [db-pbi-platform-p-scus-1].PBI_Platform_Automation.PBIActivityLog
WHERE CreationTime >= CAST(GETDATE()-90 AS DATE)
ORDER BY CreatioNTime DESC

/*
Get all unique Activities from log for the past 3 calendar months
*/
SELECT
  MAX(al.CreationDate) AS [Most Recent Activity Date],
  al.UserID AS [User Email]
FROM [db-pbi-platform-p-scus-1].PBI_Platform_Automation.CapacityDetail cd --Start with shared capacities
INNER JOIN [db-pbi-platform-p-scus-1].PBI_Platform_Automation.WorkspaceDetail wd
  ON wd.CapacityID = cd.CapacityID --Only Workspaces on shared capacities
INNER JOIN [db-pbi-platform-p-scus-1].PBI_Platform_Automation.DatasetDetail dd
  ON dd.WorkspaceID = wd.WorkspaceID --Only datasets on Workspaces on shared capacities
INNER JOIN [db-pbi-platform-p-scus-1].PBI_Platform_Automation.DataSourceDetail dsd
  ON dsd.DatasetID = dd.DatasetID --Only datasource details for datasets on Workspaces on shared capacities
INNER JOIN [db-pbi-platform-p-scus-1].PBI_Platform_Automation.PBIActivityLog al
  ON al.WorkspaceID = wd.WorkspaceID --Only activity logs where the WorkspaceID of the event is on shared capacities
WHERE al.CreationTime >= DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 3, 0)
AND (
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
GROUP BY al.UserID

/*
Get Acitivities performed in the Service
*/
SELECT CreationTime,
Activity,
ActivityID,
ReportID,
WorkspaceID,
WorkspaceName
FROM [db-pbi-platform-p-scus-1].PBI_Platform_Automation.PBIActivityLog al
WHERE al.CreationTime >= DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 3, 0)
AND Activity <> 'ViewReport'
AND UserID IN ('brayden.hughes1@kcc.com')
ORDER BY CreationTime DESC

/*
Get all unique Activities from log for the past 3 calendar months
*/
SELECT DISTINCT al.Activity
FROM [db-pbi-platform-p-scus-1].PBI_Platform_Automation.CapacityDetail cd --Start with shared capacities
INNER JOIN [db-pbi-platform-p-scus-1].PBI_Platform_Automation.WorkspaceDetail wd
  ON wd.CapacityID = cd.CapacityID --Only Workspaces on shared capacities
INNER JOIN [db-pbi-platform-p-scus-1].PBI_Platform_Automation.DatasetDetail dd
  ON dd.WorkspaceID = wd.WorkspaceID --Only datasets on Workspaces on shared capacities
INNER JOIN [db-pbi-platform-p-scus-1].PBI_Platform_Automation.DataSourceDetail dsd
  ON dsd.DatasetID = dd.DatasetID --Only datasource details for datasets on Workspaces on shared capacities
INNER JOIN [db-pbi-platform-p-scus-1].PBI_Platform_Automation.PBIActivityLog al
  ON al.WorkspaceID = wd.WorkspaceID --Only activity logs where the WorkspaceID of the event is on shared capacities
WHERE al.CreationTime >= DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 3, 0)
ORDER BY al.Activity ASC

/*
Get Acitivities performed in the Service on Enterprise Workspaces
*/
SELECT al.UserID,
al.CreationTime,
al.Activity,
al.ActivityID,
al.ReportID,
al.WorkspaceID,
al.WorkspaceName
FROM [db-pbi-platform-p-scus-1].PBI_Platform_Automation.CapacityDetail cd --Start with shared capacities
INNER JOIN [db-pbi-platform-p-scus-1].PBI_Platform_Automation.WorkspaceDetail wd
  ON wd.CapacityID = cd.CapacityID --Only Workspaces on shared capacities
INNER JOIN [db-pbi-platform-p-scus-1].PBI_Platform_Automation.DatasetDetail dd
  ON dd.WorkspaceID = wd.WorkspaceID --Only datasets on Workspaces on shared capacities
--INNER JOIN [db-pbi-platform-p-scus-1].PBI_Platform_Automation.DataSourceDetail dsd
--  ON dsd.DatasetID = dd.DatasetID --Only datasource details for datasets on Workspaces on shared capacities
INNER JOIN [db-pbi-platform-p-scus-1].PBI_Platform_Automation.PBIActivityLog al
  ON al.WorkspaceID = wd.WorkspaceID --Only activity logs where the WorkspaceID of the event is on shared capacities
WHERE al.CreationTime >= DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 3, 0)
AND Activity <> 'ViewReport'
AND UserID IN ('abhishek.singhal@kcc.com')
ORDER BY CreationTime DESC

/*
Get Acitivities performed in the Service
*/
SELECT al.CreationTime,
al.Activity,
al.ActivityID,
al.ReportID,
al.WorkspaceID,
al.WorkspaceName,
dd.DatasetID,
dd.DatasetName
FROM [db-pbi-platform-p-scus-1].PBI_Platform_Automation.CapacityDetail cd --Start with shared capacities
INNER JOIN [db-pbi-platform-p-scus-1].PBI_Platform_Automation.WorkspaceDetail wd
  ON wd.CapacityID = cd.CapacityID --Only Workspaces on shared capacities
INNER JOIN [db-pbi-platform-p-scus-1].PBI_Platform_Automation.DatasetDetail dd
  ON dd.WorkspaceID = wd.WorkspaceID --Only datasets on Workspaces on shared capacities
-- INNER JOIN [db-pbi-platform-p-scus-1].PBI_Platform_Automation.DataSourceDetail dsd
--   ON dsd.DatasetID = dd.DatasetID --Only datasource details for datasets on Workspaces on shared capacities
INNER JOIN [db-pbi-platform-p-scus-1].PBI_Platform_Automation.PBIActivityLog al
  ON al.WorkspaceID = wd.WorkspaceID --Only activity logs where the WorkspaceID of the event is on shared capacities
WHERE al.CreationTime >= DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 3, 0)
AND (
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
AND dd.DatasetName NOT IN ('Report Usage Metrics Model')
AND UserID IN ('Casey.Kobasiar@kcc.com')

ORDER BY CreationTime DESC

/*
Missing Dataset ID's
*/
-- SELECT * 
-- FROM [db-pbi-platform-p-scus-1].PBI_Platform_Automation.DataSourceDetail dsd
-- WHERE dsd.DatasetID IN (
-- '5edce12a-6fa0-4190-acbc-96af0d73f675',
-- '33674322-097c-4751-b838-8c21ed80f7b5',
-- '551848a8-a770-4293-9029-18798dcbb695')

SELECT r.id as refreshid,
    r.Name as datasetname,
    r.kind,
    r.averageduration,
    r.refreshesperday,
    r.configuredby,
    d.contentprovidertype,
    d.workspaceid,
    w.workspacename,
    w.isondedicatedcapacity
from [db-pbi-platform-p-scus-1].PBI_Platform_Automation.Refreshes r
    inner join [db-pbi-platform-p-scus-1].PBI_Platform_Automation.DatasetDetails d on d.id = r.ID
    inner join [db-pbi-platform-p-scus-1].PBI_Platform_Automation.WorkspaceDetails w on w.id = d.WorkspaceID
where r.LastRefreshType = 'Scheduled'
    and LEN(r.ConfiguredBy)>2
    and w.IsOnDedicatedCapacity = 'true'

ORDER BY
r.RefreshesPerDay desc,
r.ConfiguredBy asc,
w.WorkspaceName asc,
r.Name asc


/*
Get table info
*/
SELECT * FROM [db-pbi-platform-p-scus-1].PBI_Platform_Automation.TableColumDetail

/*
Get refresh schedule details for Adhoc capacity
*/
SELECT rsd.ScheduleDays,
rsd.ScheduleTimes,
rsd.RefreshEnabled,
rsd.LocalTimeZone,
rsd.NotifyOption,
cd.CapacityID,
cd.CapacityName,
wd.WorkspaceID,
wd.WorkspaceName,
dd.DatasetID,
dd.DatasetName,
'https://app.powerbi.com/groups/' + wd.WorkspaceID +'/settings/datasets/' + dd.DatasetID AS DatasetURL,
rsd.ConfiguredBy
FROM [db-pbi-platform-p-scus-1].PBI_Platform_Automation.RefreshScheduleDetail rsd
INNER JOIN PBI_Platform_Automation.WorkspaceDetail wd ON wd.WorkspaceID = rsd.WorkspaceID
INNER JOIN PBI_Platform_Automation.CapacityDetail cd ON cd.CapacityID = rsd.CapacityID
INNER JOIN PBI_Platform_Automation.DatasetDetail dd ON dd.DatasetID = rsd.DatasetID
WHERE rsd.RefreshEnabled = 'True'
AND cd.capacityID = 'CC10DC9F-8F94-4DD9-80CB-C29A580EDA70'
AND rsd.ConfiguredBy IN ('["leland.carawan@kcc.com"]','["ryan.m.hall@kcc.com"]')

/*
Get all datasets on capacities that are owned by FireFight USNOFF IDs
*/
SELECT DISTINCT cd.CapacityID,
cd.CapacityName,
wd.WorkspaceID,
wd.WorkspaceName,
dd.DatasetID,
dd.DatasetName,
dd.ConfiguredBy,
dd.CreatedDate,
dd.DatasetID,
dd.DatasetName,
'https://app.powerbi.com/groups/' + wd.WorkspaceID +'/settings/datasets/' + dd.DatasetID AS DatasetURL
-- 'https://app.powerbi.com/groups/' + wd.WorkspaceID +'/settings/datasets/' + dd.DatasetID AS DatasetURL,
-- rd.ReportName,
-- rd.ModifiedBy,
-- rd.ModifiedDateTime 
FROM [PBI_Platform_Automation].CapacityDetail cd
INNER JOIN [PBI_Platform_Automation].WorkspaceDetail wd
    ON wd.CapacityID = cd.CapacityID 
INNER JOIN [PBI_Platform_Automation].DatasetDetail dd 
    ON dd.WorkspaceID = wd.WorkspaceID 
INNER JOIN [PBI_Platform_Automation].ReportDetail rd 
    ON rd.DatasetID = dd.DatasetID
WHERE dd.ConfiguredBy LIKE 'USNOFF%'
  AND dd.DatasetName <> 'Usage Metrics Report'