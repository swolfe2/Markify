SELECT DISTINCT cd.CapacityID,
cd.CapacityName,
wd.WorkspaceID,
wd.WorkspaceName,
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
rd.ReportID,
rd.ReportName,
CASE WHEN rd.CreatedBy IS NULL AND dd.ConfiguredBy IS NULL
    THEN mam.Email_Address
    WHEN rd.CreatedBy IS NULL THEN dd.ConfiguredBy
ELSE rd.CreatedBy END AS ReportOwner,
CASE WHEN rd.CreatedBy IS NULL AND dd.ConfiguredBy IS NULL
    THEN 'Workspace Owner'
    WHEN rd.CreatedBy IS NULL THEN 'Dataset Owner'
ELSE 'Report Owner' END AS ReportOwnerType,
'https://app.powerbi.com/groups/' + wd.WorkspaceID + '/reports/' + rd.ReportID AS ReportURL,
dd.DatasetID,
dd.DatasetName,
dd.ConfiguredBy,
dd.CreatedDate,
dd.DatasetID,
dd.DatasetName,
'https://app.powerbi.com/groups/' + wd.WorkspaceID +'/settings/datasets/' + dd.DatasetID AS DatasetURL
FROM PBI_Platform_Automation.CapacityDetail cd 
INNER JOIN PBI_Platform_Automation.WorkspaceDetail wd ON wd.CapacityID = cd.CapacityID 
INNER JOIN PBI_Platform_Automation.DatasetDetail dd ON dd.WorkspaceID = wd.WorkspaceID
INNER JOIN PBI_Platform_Automation.ReportDetail rd ON rd.DatasetID = dd.DatasetID
    AND rd.ReportName NOT IN ('Report Usage Metrics Report')
    AND LOWER(rd.ReportName) NOT LIKE '%[app]%'
LEFT JOIN (
  SELECT DISTINCT
  wud.WorkspaceID,
  wud.GroupUserAccessRight,
  wud.DisplayName AS ADGroup,
  wud.Identifier AS ADGroupIdentifier,
  wud.PrincipalType 
  FROM PBI_Platform_Automation.WorkspaceUserDetail wud
) adGroups ON adGroups.WorkspaceID = wd.WorkspaceID
    AND adGroups.GroupUserAccessRight = 'Viewer'
LEFT JOIN PBI_Groups.MembersAndManagers mam ON mam.Group_Name = adGroups.ADGroup
    AND mam.Role = 'Owner'
    AND mam.Email_Address IS NOT NULL

SELECT * FROM PBI_Platform_Automation.ReportDetail 
WHERE ReportName = 'Report Usage Metrics Report'




SELECT DISTINCT ad.AddedOn, ad.UpdatedOn, ad.Enabled, ad.DisplayName, ad.OfficeLocation, ad.CountryName, LOWER(ad.UserPrincipalName) AS UserPrincipalName, LOWER(ad.Email) AS Email, ad.EmployeeNumber, ad.Title, ad.JobCategory, ad.Region FROM sql-pbi-platform-p-scus-1.database.windows.net." & SQL_Database & ".tblActiveDirectory ad INNER JOIN (   SELECT DISTINCT MAX(UpdatedOn) AS MAXUpdatedOn,   UserPrincipalName   FROM sql-pbi-platform-p-scus-1.database.windows.net." & SQL_Database & ".tblActiveDirectory   GROUP BY UserPrincipalName ) MAXID ON MAXID.UserPrincipalName = ad.UserPrincipalName  AND MAXID.MAXUpdatedOn = ad.UpdatedOn WHERE ad.UserPrincipalName IS NOT NULL

SELECT DISTINCT wd.WorkspaceName,
rd.ReportName,
dd.DatasetName
FROM PBI_Platform_Automation.DatasetDetail dd 
INNER JOIN PBI_Platform_Automation.DatasetTableDetail dtd
    ON dtd.DatasetID = dd.DatasetID 
    AND dtd.TableExpression LIKE '%tableau.kcp.revenuedatacloud.com%'
INNER JOIN 
    PBI_Platform_Automation.ReportDetail rd 
        ON rd.DatasetID = dd.DatasetID 
INNER JOIN 
    PBI_Platform_Automation.WorkspaceDetail wd
        ON wd.WorkspaceID = rd.WorkspaceID
ORDER BY wd.WorkspaceName ASC, rd.ReportName ASC, dd.DatasetName ASC