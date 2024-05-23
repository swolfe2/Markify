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
    WHEN RIGHT(wd.WorkspaceName, 3) = '- Q' THEN 'Quality'
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
Get all unique Activities from log for the past 3 calendar months
SELECT DISTINCT al.Activity
FROM 
[db-pbi-platform-p-scus-1].PBI_Platform_Automation.CapacityDetail cd --Start with shared capacities
INNER JOIN [db-pbi-platform-p-scus-1].PBI_Platform_Automation.WorkspaceDetail wd 
    ON wd.CapacityID = cd.CapacityID --Only Workspaces on shared capacities
INNER JOIN [db-pbi-platform-p-scus-1].PBI_Platform_Automation.DatasetDetail dd 
    ON dd.WorkspaceID = wd.WorkspaceID --Only datasets on Workspaces on shared capacities
INNER JOIN [db-pbi-platform-p-scus-1].PBI_Platform_Automation.DataSourceDetail dsd 
    ON dsd.DatasetID = dd.DatasetID --Only datasource details for datasets on Workspaces on shared capacities
INNER JOIN [db-pbi-platform-p-scus-1].PBI_Platform_Automation.PBIActivityLog al 
    ON al.WorkspaceID = wd.WorkspaceID --Only activity logs where the WorkspaceID of the event is on shared capacities
WHERE al.CreationTime >= DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 3, 0)
ORDER BY al.Activity ASC*/

SELECT MAX(al.CreationDate) AS [Most Recent Activity Date],
al.UserID AS [User Email] 
FROM 
[db-pbi-platform-p-scus-1].PBI_Platform_Automation.CapacityDetail cd --Start with shared capacities
INNER JOIN [db-pbi-platform-p-scus-1].PBI_Platform_Automation.WorkspaceDetail wd ON wd.CapacityID = cd.CapacityID --Only Workspaces on shared capacities
INNER JOIN [db-pbi-platform-p-scus-1].PBI_Platform_Automation.DatasetDetail dd ON dd.WorkspaceID = wd.WorkspaceID --Only datasets on Workspaces on shared capacities
INNER JOIN [db-pbi-platform-p-scus-1].PBI_Platform_Automation.PBIActivityLog al ON al.WorkspaceID = wd.WorkspaceID --Only activity logs where the WorkspaceID of the event is on shared capacities
WHERE al.CreationTime >= DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 24, 0)
AND (
    al.Activity LIKE 'CANCEL%'
    OR al.Activity LIKE 'CREATE%'
    OR al.Activity LIKE 'DELETE%'
    OR al.Activity LIKE 'EDIT%'
    OR al.Activity LIKE 'REFRESH%'
    OR al.Activity LIKE 'RENAME%'
    OR al.Activity LIKE 'UPDATE%'
    OR al.Activity IN ('RequestDataflowRefresh','TakeOverDataset','TookOverDataflow')
    )
    AND al.WorkspaceID IS NOT NULL
    AND dd.DatasetName NOT IN ('Report Usage Metrics Model')
    AND al.UserID IN ('Cristian.Berri@kcc.com',
    'Daniela.A.Oliveira@kcc.com',
    'Jenni.C.Stamps@kcc.com',
    'Kaela.P.Fennell-Chin@kcc.com',
    'Maria.F.DeLasCasas@kcc.com',
    'minyoung.wui@y-k.co.kr',
    'TAN.NGUYENTRUONGKHAC@kcc.com',
    'viney.kumar@kcc.com')
    GROUP BY al.UserID