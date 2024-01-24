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