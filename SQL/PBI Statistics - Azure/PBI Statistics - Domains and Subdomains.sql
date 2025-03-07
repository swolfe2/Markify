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
	SELECT dd.DisplayName AS "Global Function",
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
	)
/*
Combine Domains and Subdomains
*/
SELECT 
	dw.WorkspaceID,
	dw.DisplayName,
	pd.DomainID,
	pd.Segment,
	pd.ABU,
	pd.[Description],
	sd.SubDomainID,
	sd.[Global Function],
	sd.SubDomainDescription,
	sd.SubDomainContributorsScope
FROM ParentDomain pd
LEFT JOIN SubDomain sd ON pd.DomainID = sd.ParentDomainID
INNER JOIN PBI_Platform_Automation.DomainWorkspace dw 
	ON dw.DomainID = sd.SubdomainID
GROUP BY dw.WorkspaceID,
	dw.DisplayName,
	pd.DomainID,
	pd.Segment,
	pd.ABU,
	pd.[Description],
	sd.SubDomainID,
	sd.[Global Function],
	sd.SubDomainDescription,
	sd.SubDomainContributorsScope;