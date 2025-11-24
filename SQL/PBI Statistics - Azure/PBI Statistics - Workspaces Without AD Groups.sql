/*
Get all enterprise Workspaces
*/
WITH Workspaces
AS (
	SELECT wd.WorkspaceID,
		wd.WorkspaceName,
		wd.Description
	FROM PBI_Platform_Automation.WorkspaceDetail wd
	WHERE wd.IsOnDedicatedCapacity = 1
		AND wd.WorkspaceState = 'Active'
	),
/*
Get all AD groups for enterprise Workspaces
*/
ADGroups
AS (
	SELECT DISTINCT wud.WorkspaceID,
		wud.DisplayName,
		wud.PrincipalType
	FROM PBI_Platform_Automation.WorkspaceUserDetail wud
	INNER JOIN Workspaces wd ON wd.WorkspaceID = wud.WorkspaceID
	WHERE wud.DisplayName LIKE 'PBI_WS_%'
	),
/*
Combine
*/
Combined
AS (
	SELECT w.WorkspaceID,
		w.WorkspaceName,
		w.Description,
		ad.DisplayName,
		ad.PrincipalType
	FROM Workspaces w
	LEFT JOIN ADGroups ad ON ad.WorkspaceID = w.WorkspaceID
	),
/*
Get all Workspaces with NO Active Directory Groups
*/
MissingGroups
AS (
	SELECT *
	FROM Combined
	WHERE DisplayName IS NULL
	)
/*
Return all PBI Workspaces with NO Active Directory Groups
*/
SELECT *
FROM MissingGroups c