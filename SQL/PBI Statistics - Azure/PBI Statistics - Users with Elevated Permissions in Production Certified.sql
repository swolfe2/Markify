/*
Start with getting all enterprise Workspaces, and extract details
*/
WITH Workspaces
AS (
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
	INNER JOIN PBI_Platform_Automation.CapacityDetail cd ON cd.CapacityID = wd.CapacityID
	WHERE wd.IsOnDedicatedCapacity = 1
		AND wd.WorkspaceState = 'Active'
		AND wd.WorkspaceType = 'Workspace'
	)
/*
Get all Users who have >Viewer access in a Production Certified Workspace
*/
SELECT w.WorkspaceID,
	w.WorkspaceName,
	w.WorkspaceRegion,
	wud.EmailID,
	CASE 
		WHEN CHARINDEX(' ', wud.DisplayName) = 0
			THEN wud.DisplayName
		ELSE CASE 
				WHEN LEFT(wud.DisplayName, CHARINDEX(' ', wud.DisplayName) - 1) = SUBSTRING(wud.DisplayName, CHARINDEX(' ', wud.DisplayName) + 1, LEN(wud.DisplayName))
					THEN REPLACE(wud.EmailID, '@kcc.com', '')
				ELSE wud.DisplayName
				END
		END AS UserID,
	wud.DisplayName,
	wud.GroupUserAccessRight
FROM Workspaces w
INNER JOIN PBI_Platform_Automation.WorkspaceUserDetail wud ON wud.WorkspaceID = w.WorkspaceID
WHERE w.WorkspaceType = 'Production Certified'
	AND wud.GroupUserAccessRight NOT IN ('Viewer')
	AND wud.PrincipalType = 'User'
ORDER BY w.WorkspaceRegion ASC,
	w.WorkspaceName ASC,
	wud.EmailID ASC