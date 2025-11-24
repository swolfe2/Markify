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
Get all AD group classifications from Group Manager
*/
Classifications
AS (
	SELECT gc."Group Name",
		gc.Classification
	FROM PBI_Groups.GroupClassification gc
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
		ad.PrincipalType,
		c.Classification
	FROM Workspaces w
	INNER JOIN ADGroups ad ON ad.WorkspaceID = w.WorkspaceID
	LEFT JOIN Classifications c ON c."Group Name" = ad.DisplayName
	),
/*
Aggregate for count of distinct classifications
*/
Aggregated
AS (
	SELECT DISTINCT WorkspaceID,
		COUNT(*) AS RecCount
	FROM (
		SELECT DISTINCT c.WorkspaceID,
			c.Classification
		FROM Combined c
		) grouped
	GROUP BY WorkspaceID
	HAVING COUNT(*) > 1
	),
/*
Get AD Group Owners
*/
Owners
AS (
	SELECT m.Group_Name,
		m.User_ID AS OwnerUserID,
		m.Display_Name AS OwnerName,
		LOWER(m.Email_Address) AS OwnerEmail
	FROM PBI_Groups.Managers m
	INNER JOIN Combined c ON c.DisplayName = m.Group_Name
	WHERE m.ROLE = 'Owner'
	)
/*
Return all Workspaces with >1 classification value assigned 24
*/
SELECT DISTINCT c.*,
	o.OwnerName,
	o.OwnerUserID,
	o.OwnerEmail
FROM Combined c
INNER JOIN Aggregated a ON a.WorkspaceID = c.WorkspaceID
LEFT JOIN Owners o ON o.Group_Name = c.DisplayName
ORDER BY c.WorkspaceName ASC,
	c.DisplayName ASC