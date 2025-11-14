/*
This SQL replicates the Segment - ABU Dataflow logic from 
https://app.powerbi.com/groups/a04966ab-98e7-419b-9374-7ebf0e10fcc4/dataflows/5d9e1dec-5981-4d61-b5f3-389e3dcd8c3e?experience=power-bi
*/
/*
Get the parent domain values
*/
WITH ParentDomain
AS (
	SELECT dd.DomainID,
		dd.DisplayName,
		dd.Description,
		dd.ContributorsScope,
		RTRIM(SUBSTRING(dd.DisplayName, 1, CHARINDEX(' - ', dd.DisplayName) - 1)) AS Segment,
		LTRIM(SUBSTRING(dd.DisplayName, CHARINDEX(' - ', dd.DisplayName) + 3, LEN(dd.DisplayName))) AS ABU
	FROM PBI_Platform_Automation.DomainDetail dd
	WHERE ParentDomainID IS NULL
	GROUP BY dd.DomainID,
		dd.DisplayName,
		dd.Description,
		dd.ContributorsScope
	),
/*
Get the subdomain values
*/
SubDomain
AS (
	SELECT dd.DisplayName AS "GlobalFunction",a
		dd.DomainID AS "SubdomainID",
		dd.ContributorsScope AS "SubDomainContributorsScope",
		dd.[Description] AS "SubDomainDescription",
		dd.ParentDomainID
	FROM PBI_Platform_Automation.DomainDetail dd
	WHERE ParentDomainID IS NOT NULL
	GROUP BY dd.DomainID,
		dd.DisplayName,
		dd.Description,
		dd.ContributorsScope,
		dd.ParentDomainID
	),
/*
Sort the roles
*/
RoleSort AS (
    SELECT 'Authorizer' AS Role, 1 AS Sort
    UNION ALL
    SELECT 'Delegate', 2
    UNION ALL
    SELECT 'Member', 3
    UNION ALL
    SELECT 'Owner', 4
)


/*
Combine Domains, Subdomains and Workspace Details
*/
SELECT 
	wd.WorkspaceName,
	wd.WorkspaceID,
	CASE WHEN LEFT(wd.WorkspaceName, 3) = 'GL ' THEN 'Global'
		WHEN LEFT(wd.WorkspaceName, 3) = 'AP ' THEN 'Asia Pac'
		WHEN LEFT(wd.WorkspaceName, 3) = 'NA ' THEN 'North America'
		WHEN LEFT(wd.WorkspaceName, 4) = 'LAO ' THEN 'Latin America'
		WHEN LEFT(wd.WorkspaceName, 5) = 'EMEA ' THEN 'EMEA'
	ELSE 'Naming Error'
	END AS WorkspaceRegion,
	CASE WHEN RIGHT(wd.WorkspaceName, 3) = '- D' THEN 'Development'
		WHEN RIGHT(wd.WorkspaceName, 3) = '- Q' THEN 'Quality'
		WHEN RIGHT(wd.WorkspaceName, 7) = '- ADHOC' THEN 'Adhoc'
		WHEN RIGHT(wd.WorkspaceName, 8) = '- PUBLIC' THEN 'Public'
		WHEN LEFT(wd.WorkspaceName, 3) IN ('GL ', 'AP ', 'NA ', 'LAO', 'EME') THEN 'Production Certified'
	ELSE 'Naming Error'
	END AS WorkspaceType,
	pd.DomainID,
	sd.SubDomainID,
	pd.Segment,
	pd.ABU,
	sd.GlobalFunction,
	wud.DisplayName,
	mam.Display_Name AS 'UserName',
	LOWER(mam.Email_Address) AS 'EmailAddress',
	UPPER(mam.User_ID) AS 'UserID',
	mam.Member,
	mam.Role
FROM ParentDomain pd
LEFT JOIN SubDomain sd ON pd.DomainID = sd.ParentDomainID
INNER JOIN PBI_Platform_Automation.DomainWorkspace dw 
	ON dw.DomainID = sd.SubdomainID
INNER JOIN PBI_Platform_Automation.WorkspaceDetail wd
	ON wd.WorkspaceID = dw.WorkspaceID
	AND wd.IsOnDedicatedCapacity = 1
INNER JOIN PBI_Platform_Automation.WorkspaceUserDetail wud
	ON wud.WorkspaceID = wd.WorkspaceID
	AND wud.DisplayName NOT IN ('PBI_ALLUSERS',
    'PBI_LC_PROUSER',
    'PBI_Support',
    'PBI_PL_SERVICEADMIN',
    'PBI_FFID_USERS',
    'PBI_COLIBRA_ADMIN_AAD',
    'PBI_PL_GATEWAY_LOGFILES',
    'PBI_PL_QA_ADH',
    'sp-pbi-platform-p-1')
INNER JOIN PBI_Groups.MembersAndManagers mam
	ON mam.Group_Name = wud.DisplayName
INNER JOIN RoleSort rs
	ON rs.Role = mam.Role
GROUP BY dw.WorkspaceID,
	wd.WorkspaceName,
	wd.WorkspaceID,
	pd.Segment,
	pd.ABU,
	pd.DomainID,
	sd.SubDomainID,
	sd.GlobalFunction,
	sd.SubDomainDescription,
	sd.SubDomainContributorsScope,
	wud.DisplayName,
	mam.Display_Name,
	mam.Email_Address,
	mam.User_ID,
	mam.Member,
	mam.Role,
	rs.Sort
	
ORDER BY wd.WorkspaceName ASC,
wud.DisplayName ASC,
rs.Sort ASC,
mam.Email_Address ASC