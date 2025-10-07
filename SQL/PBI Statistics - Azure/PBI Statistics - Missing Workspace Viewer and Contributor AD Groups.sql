/*
Start with getting all enterprise Workspaces, and extract details
*/
WITH Workspaces AS (
SELECT wd.WorkspaceID,
wd.WorkspaceName,
CASE 
	WHEN RIGHT(wd.WorkspaceName, 3) = '- D'
		THEN 'Development'
	WHEN RIGHT(wd.WorkspaceName, 3) = '- Q'
		THEN 'Quality'
	WHEN RIGHT(wd.WorkspaceName, 7) = '- ADHOC'
		THEN 'Adhoc'
	WHEN RIGHT(wd.WorkspaceName, 8) = '- PUBLIC'
		THEN 'Public'
	WHEN LEFT(wd.WorkspaceName, 3) IN (
			'GL ',
			'AP ',
			'NA ',
			'LAO',
			'EME'
			)
		THEN 'Production Certified'
	ELSE 'Naming Error'
END AS WorkspaceType,
CASE 
	WHEN LEFT(wd.WorkspaceName, 3) = 'GL '
		THEN 'Global'
	WHEN LEFT(wd.WorkspaceName, 3) = 'AP '
		THEN 'Asia Pac'
	WHEN LEFT(wd.WorkspaceName, 3) = 'NA '
		THEN 'North America'
	WHEN LEFT(wd.WorkspaceName, 4) = 'LAO '
		THEN 'Latin America'
	WHEN LEFT(wd.WorkspaceName, 5) = 'EMEA '
		THEN 'EMEA'
	ELSE 'Naming Error'
END AS WorkspaceRegion
FROM PBI_Platform_Automation.WorkspaceDetail wd
INNER JOIN PBI_Platform_Automation.CapacityDetail cd
	ON cd.CapacityID = wd.CapacityID
	WHERE wd.IsOnDedicatedCapacity = 1
	AND wd.WorkspaceState = 'Active' 
	AND wd.WorkspaceType = 'Workspace'
),

/*
Get all Workspace ID's which have a Viewer role assigned to a DisplayName
*/
ViewerADGroups AS (
SELECT DISTINCT wud.WorkspaceID
FROM PBI_Platform_Automation.WorkspaceUserDetail wud
WHERE wud.DisplayName NOT IN (
	'PBI_PL_SERVICEADMIN',
	'sp-pbi-platform-p-1',
	'PBI_FFID_USERS',
	'PBI_Support',
	'collibraconnect-sp-prod-1'
	)
AND wud.GroupUserAccessRight = 'Viewer'
),

/*
Get all Workspace ID's which have a Contributor role assigned to a DisplayName
*/
ContributorADGroups AS (
SELECT DISTINCT wud.WorkspaceID
FROM PBI_Platform_Automation.WorkspaceUserDetail wud
WHERE wud.DisplayName NOT IN (
	'PBI_PL_SERVICEADMIN',
	'sp-pbi-platform-p-1',
	'PBI_FFID_USERS',
	'PBI_Support',
	'collibraconnect-sp-prod-1'
	)
AND wud.GroupUserAccessRight = 'Contributor'
),

/*
Combine everything together
*/
Combined AS (
SELECT w.WorkspaceID,
w.WorkspaceName,
w.WorkspaceRegion,
w.WorkspaceType,
CASE
	WHEN v.WorkspaceID IS NULL
		THEN 'Missing Viewer AD Group'
	ELSE 
		NULL 
END AS ViewerFlag,
CASE
	WHEN c.WorkspaceID IS NULL AND w.WorkspaceType <> 'Production Certified'
		THEN 'Missing Contributor AD Group'
	ELSE 
		NULL 
END AS ContributorFlag
FROM Workspaces w
LEFT JOIN ViewerADGroups v
	ON v.WorkspaceID = w.WorkspaceID
LEFT JOIN ContributorADGroups c
	ON c.WorkspaceID = w.WorkspaceID
)

/*
Keep only errors, and simplify flag
*/
SELECT DISTINCT 
c.WorkspaceID,
c.WorkspaceName,
c.WorkspaceRegion,
c.WorkspaceType,
CASE
	WHEN c.ViewerFlag IS NOT NULL and c.ContributorFlag IS NULL 
		THEN 'Missing Viewer AD Group'
	WHEN c.ViewerFlag IS NULL and c.ContributorFlag IS NOT NULL
		THEN 'Missing Contributor AD Group'
	ELSE 
		'Missing Viewer and Contributor AD Groups'
END AS Flag
FROM Combined c
WHERE c.ViewerFlag IS NOT NULL 
OR c.ContributorFlag IS NOT NULL
ORDER BY c.WorkspaceName ASC
