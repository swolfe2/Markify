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
	SELECT dd.DisplayName AS "GlobalFunction",
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
Get the unique Workspaces that were created in the past 7 days
*/
WorkspaceCreations
AS (
	SELECT
	al.WorkspaceID,
	al.CreationDate
	FROM PBI_Platform_Automation.PBIActivityLog al
	WHERE Activity = 'CreateFolder'
	AND CreationDate >= GETDATE() - 7
	GROUP BY al.WorkspaceID,
	al.CreationDate
)

/*
Combine Domains, Subdomains by Activity Dates
*/
SELECT 
	dw.WorkspaceID,
	dw.DisplayName,
	pd.DomainID,
	sd.SubDomainID,
	pd.Segment,
	pd.ABU,
	sd.GlobalFunction,
	wc.CreationDate
FROM ParentDomain pd
LEFT JOIN SubDomain sd ON pd.DomainID = sd.ParentDomainID
INNER JOIN PBI_Platform_Automation.DomainWorkspace dw 
	ON dw.DomainID = sd.SubdomainID
INNER JOIN WorkspaceCreations wc
	ON wc.WorkspaceId = dw.WorkspaceID
GROUP BY dw.WorkspaceID,
	dw.DisplayName,
	pd.DomainID,
	pd.Segment,
	pd.ABU,
	pd.[Description],
	sd.SubDomainID,
	sd.GlobalFunction,
	sd.SubDomainDescription,
	sd.SubDomainContributorsScope,
	wc.CreationDate;