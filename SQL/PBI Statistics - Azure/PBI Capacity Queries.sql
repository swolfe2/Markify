-- SELECT TOP (1000) [WorkspaceID]
--       ,[WorkspaceType]
--       ,[WorkspaceState]
--       ,[WorkspaceName]
--       ,[Description]
--       ,[IsOnDedicatedCapacity]
--       ,[CapacityID]
--       ,[DataflowStorageID]
--       ,[HasWorkspaceLevelSettings]
--       ,[IsReadOnly]
--       ,[DeploymentPipelineID]
--       ,[Workbooks]
--       ,[CapacityMigrationStatus]
--   FROM [PBI_Platform_Automation].[WorkspaceDetail]
--   WHERE IsOnDedicatedCapacity = 1

--   SELECT TOP 1000 * FROM [PBI_Platform_Automation].[WorkspaceUserDetail]

-- SELECT TOP 1000 * FROM [PBI_Platform_Automation].[WorkspaceScanResult]

-- SELECT * FROM PBI_Groups.MembersAndManagers

/*
Get unique Workspace details with Members and Managers
*/
SELECT 
cd.CapacityID,
cd.CapacityName,
cd.SKU AS CapacitySKU,
cd.State AS CapacityState,
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
wd.WorkspaceName,
wd.WorkspaceState,
-- wd.Description AS WorkspaceDescription,
TRIM ( CASE 
        WHEN CHARINDEX(CHAR(13) + CHAR(10), wd.Description) > 0 
          THEN REPLACE(wd.Description, CHAR(13) + CHAR(10), ' ')
        WHEN CHARINDEX(CHAR(13), wd.Description) > 0 
          THEN REPLACE(wd.Description, CHAR(13), ' ')
        WHEN CHARINDEX(CHAR(10), wd.Description) > 0 
          THEN REPLACE(wd.Description, CHAR(10), ' ')
        ELSE wd.Description
    END ) AS WorkspaceDescription,
'https://app.powerbi.com/groups/' + wd.WorkspaceID AS WorkspaceURL,
adGroups.GroupUserAccessRight,
adGroups.ADGroup,
adGroups.ADGroupIdentifier,
mam.User_ID AS UserID,
mam.Display_Name AS DisplayName,
LOWER ( mam.Email_Address ) AS Email,
mam.Member,
mam.Role

FROM PBI_Platform_Automation.CapacityDetail cd 
INNER JOIN PBI_Platform_Automation.WorkspaceDetail wd ON wd.CapacityID = cd.CapacityID 
LEFT JOIN (
  SELECT DISTINCT
  wud.WorkspaceID,
  wud.GroupUserAccessRight,
  wud.DisplayName AS ADGroup,
  wud.Identifier AS ADGroupIdentifier,
  wud.PrincipalType 
  FROM PBI_Platform_Automation.WorkspaceUserDetail wud
) adGroups ON adGroups.WorkspaceID = wd.WorkspaceID
LEFT JOIN PBI_Groups.MembersAndManagers mam ON mam.Group_Name = adGroups.ADGroup


SELECT TOP 100 * FROM PBI_Platform_Automation.ArtifactLineageDetail
WHERE WorkspaceName = 'GL COMMON CERTIFIED DATASETS - Public'

SELECT * FROM PBI_Platform_Automation.DatasourceDetail
WHERE ConnectionDetails LIKE '%c0ddd27f-49fb-4086-b542-1d69accc331c%'

SELECT * FROM PBI_Platform_Automation.DatasetTableDetail
WHERE TableExpression LIKE '%c0ddd27f-49fb-4086-b542-1d69accc331c%'

SELECT DISTINCT cd.CapacityID,
cd.CapacityName,
wd.WorkspaceID,
wd.WorkspaceName,
rd.ReportID,
rd.ReportName,
dd.DatasetID,
dd.DatasetName,
dd.ConfiguredBy,
dd.CreatedDate,
dd.DatasetID,
dd.DatasetName,
'https://app.powerbi.com/groups/' + wd.WorkspaceID +'/settings/datasets/' + dd.DatasetID AS DatasetURL,
dtd.TableName,
dtd.TableExpression
FROM PBI_Platform_Automation.CapacityDetail cd 
INNER JOIN PBI_Platform_Automation.WorkspaceDetail wd ON wd.CapacityID = cd.CapacityID 
INNER JOIN PBI_Platform_Automation.DatasetDetail dd ON dd.WorkspaceID = wd.WorkspaceID
INNER JOIN PBI_Platform_Automation.ReportDetail rd ON rd.DatasetID = dd.DatasetID
INNER JOIN PBI_Platform_Automation.DatasetTableDetail dtd ON dtd.DatasetID = dd.DatasetID
  AND dtd.TableExpression LIKE '%c0ddd27f-49fb-4086-b542-1d69accc331c%'

SELECT * FROM PBI_Platform_Automation.DatasetDetail

SELECT DISTINCT 
GROUP_NAME,
User_ID,
LOWER(Email_Address) AS Email_Address,
Member,
Role
FROM PBI_Groups.Managers
WHERE Group_Name LIKE '%HR_OVERHEAD%'

SELECT * FROM PBI_Platform_Automation.DatasetTableDetail dtd  
WHERE dtd.TableExpression LIKE '%https://www.moc.kcc.com/%'

SELECT * FROM PBI_Platform_Automation.DatasetDetail 
WHERE DatasetID = '483ad7a8-3831-4e08-b8d5-89110f3c0696'