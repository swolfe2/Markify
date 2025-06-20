/*
Get Workspaces missing their Viewer or Contributor Roles
*/
SELECT *
FROM (
	SELECT piv.WorkspaceName,
		piv.WorkspaceID,
		piv.WorkspaceRegion,
		piv.WorkspaceType,
		piv.Viewer AS ViewerADGroup,
		piv.Contributor AS ContributorADGroup,
		CASE 
			WHEN piv.WorkspaceType = 'Production Certified'
				AND piv.Viewer IS NULL
				THEN 'Missing Viewer Role'
			WHEN piv.WorkspaceType = 'Public'
				AND piv.Contributor IS NULL
				THEN 'Missing Contributor Role'
			WHEN piv.Viewer IS NULL
				AND piv.Contributor IS NULL
				THEN 'Missing Active Directory Groups'
			WHEN piv.Viewer IS NULL
				AND piv.WorkspaceType <> 'Public'
				THEN 'Missing Viewer Active Directory Group'
			WHEN piv.Contributor IS NULL
				AND piv.WorkspaceType <> 'Production Certified'
				THEN 'Missing Contributor Active Directory Group'
			ELSE 'Compliant'
			END AS WorkspaceFlag
	FROM (
		SELECT wd.WorkspaceName,
			wud.WorkspaceID,
			CASE 
				WHEN wd.IsOnDedicatedCapacity = 1
					THEN CASE 
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
							END
				ELSE 'Not On Dedicated Capacity'
				END AS WorkspaceRegion,
			CASE 
				WHEN wd.IsOnDedicatedCapacity = 1
					THEN CASE 
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
							END
				ELSE 'Not On Dedicated Capacity'
				END AS WorkspaceType,
			wud.GroupUserAccessRight,
			wud.DisplayName
		FROM PBI_Platform_Automation.WorkspaceUserDetail wud
		INNER JOIN PBI_Platform_Automation.WorkspaceDetail wd ON wd.WorkspaceID = wud.WorkspaceID
		WHERE wud.DisplayName NOT IN (
				'PBI_PL_SERVICEADMIN',
				'PBI_FFID_USERS',
				'PBI_Support'
				)
			AND LEFT(wud.DisplayName, 4) = 'PBI_'
			AND wud.GroupUserAccessRight IN (
				'Viewer',
				'Contributor'
				)
			AND wd.IsOnDedicatedCapacity = 1
		) AS SourceTable
	PIVOT(MAX(DisplayName) FOR GroupUserAccessRight IN (
				[Viewer],
				[Contributor]
				)) AS piv
	) data
WHERE data.WorkspaceFlag <> 'Compliant'

SELECT wud.* 
FROM PBI_Platform_Automation.WorkspaceUserDetail wud 
WHERE wud.WorkspaceID = 'a11dae7a-fcea-436f-b79f-71d3de53f840'