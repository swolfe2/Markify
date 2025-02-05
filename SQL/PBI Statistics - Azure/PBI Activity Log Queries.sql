SELECT TOP 10 * FROM PBI_Platform_Automation.DatasetDetail
WHERE WorkspaceID = '301c6b83-05ea-4a8c-9f98-222560c1a38d'
AND DatasetName = 'RO Operative'

SELECT TOP 10 * FROM PBI_Platform_Automation.DatasetTableDetail
WHERE DatasetID = '12239b1c-d278-47f7-87b9-f6e373123a3d'

SELECT TOP 10 * FROM PBI_Platform_Automation.DatasourceDetail
WHERE ArtifactID = '12239b1c-d278-47f7-87b9-f6e373123a3d'

SELECT
   CreationDate,
   Activity,
   COUNT ( * ) AS RecordCount 
FROM
   PBI_Platform_Automation.PBIActivityLog 
WHERE
   WorkspaceID = 'e1df06f7-9c37-4ecc-ada0-f3416c700cf4' 
   AND DatasetName = 'All Outlet Central and CT20 Model' 
   AND Activity IN 
   (
      'CreateDataset',
      'EditDataset'
   )
   AND CAST (CreationDate AS DATE) >= CAST (GETDATE() - 180 AS DATE) 
GROUP BY
   CreationDate,
   Activity 
ORDER BY
   CreationDate DESC

SELECT CAST ( rd.CreatedDateTime AS DATE) AS CreatedDate,
CAST ( rd.ModifiedDateTime AS DATE) AS ModifiedDate,
wd.WorkspaceID,
wd.WorkspaceName,
rd.ReportName
FROM PBI_Platform_Automation.ReportDetail rd
INNER JOIN PBI_Platform_Automation.WorkspaceDetail wd ON wd.WorkspaceID = rd.WorkspaceID
INNER JOIN PBI_Platform_Automation.CapacityDetail cd ON cd.CapacityID = wd.CapacityID
WHERE rd.ReportName = 'CPK Historical Volumes (last 12 months)'
AND rd.WorkspaceID = '62e99ddf-5c9a-4965-85be-b225229cec7e'

SELECT * FROM PBI_Platform_Automation.WorkspaceDetail WHERE WorkspaceID = 'a04966ab-98e7-419b-9374-7ebf0e10fcc4d'
SELECT TOP 100 * FROM PBI_Platform_Automation.PBIActivityLog WHERE WorkspaceID = 'a04966ab-98e7-419b-9374-7ebf0e10fcc4d'

SELECT * FROM PBI_Platform_Automation.PBIActivityLog WHERE WorkspaceID = 'a04966ab-98e7-419b-9374-7ebf0e10fcc4'
AND CreationDate >= GETDATE() - 10
AND Activity NOT IN ('ViewReport')
AND ObjectID = 'PBI Metadata'

SELECT wd.* 
FROM PBI_Platform_Automation.CapacityDetail cd 
INNER JOIN PBI_Platform_Automation.WorkspaceDetail wd 
   ON wd.CapacityID = cd.CapacityID

SELECT TOP 10 * FROM PBI_Platform_Automation.PBIActivityLog pal

SELECT DISTINCT [Activity] 
FROM PBI_Platform_Automation.PBIActivityLog pal
WHERE [Activity] LIKE 'Create%'
ORDER BY [Activity] ASC

SELECT DISTINCT
cd.CapacityID,
cd.CapacityName,
wd.WorkspaceID,
wd.WorkspaceName,
pal.CreationTime,
pal.CreationDate,
pal.Activity,
pal.FolderDisplayName,
pal.FolderObjectID,
pal.UserID
FROM PBI_Platform_Automation.PBIActivityLog pal
INNER JOIN PBI_Platform_Automation.WorkspaceDetail wd
   ON wd.WorkspaceID = pal.WorkspaceID 
INNER JOIN PBI_Platform_Automation.CapacityDetail cd 
   ON cd.CapacityID = wd.CapacityID
WHERE pal.Activity = 'CreateFolder'
AND pal.CreationDate >= GETDATE() - 30

SELECT 
pal.*
FROM PBI_Platform_Automation.PBIActivityLog pal
WHERE pal.Activity = 'CreateFolder'
AND pal.CreationDate >= GETDATE() - 30