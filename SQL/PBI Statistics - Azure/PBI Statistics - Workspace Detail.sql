
-- T-SQL

/*
Replicates Segment / ABU logic from the referenced Dataflow
and protects against invalid DisplayName values that lack ' - '.
*/

WITH ParentDomain AS
(
    SELECT
        dd.DomainID,
        dd.DisplayName,
        dd.Description,
        dd.ContributorsScope,
        -- compute the separator position once
        CHARINDEX(' - ', dd.DisplayName) AS sep_pos
    FROM PBI_Platform_Automation.DomainDetail AS dd
    WHERE dd.ParentDomainID IS NULL
      AND dd.DisplayName IS NOT NULL
      AND CHARINDEX(' - ', dd.DisplayName) > 0
),
ParsedParent AS
(
    SELECT
        pd.DomainID,
        pd.DisplayName,
        pd.Description,
        pd.ContributorsScope,
        -- safe Segment and ABU parsing
        RTRIM(SUBSTRING(pd.DisplayName, 1, pd.sep_pos - 1)) AS Segment,
        LTRIM(SUBSTRING(pd.DisplayName, pd.sep_pos + 3, LEN(pd.DisplayName) - pd.sep_pos - 2)) AS ABU
    FROM ParentDomain AS pd
),
SubDomain AS
(
    SELECT
        dd.DisplayName           AS GlobalFunction,
        dd.DomainID              AS SubdomainID,
        dd.ContributorsScope     AS SubDomainContributorsScope,
        dd.[Description]         AS SubDomainDescription,
        dd.ParentDomainID
    FROM PBI_Platform_Automation.DomainDetail AS dd
    WHERE dd.ParentDomainID IS NOT NULL
)
SELECT 
    wd.WorkspaceName,
    wd.WorkspaceID,
    CASE 
        WHEN LEFT(wd.WorkspaceName, 3) = 'GL '  THEN 'Global'
        WHEN LEFT(wd.WorkspaceName, 3) = 'AP '  THEN 'Asia Pac'
        WHEN LEFT(wd.WorkspaceName, 3) = 'NA '  THEN 'North America'
        WHEN LEFT(wd.WorkspaceName, 4) = 'LAO ' THEN 'Latin America'
        WHEN LEFT(wd.WorkspaceName, 5) = 'EMEA ' THEN 'EMEA'
        ELSE 'Naming Error'
    END AS WorkspaceRegion,
    CASE 
        WHEN RIGHT(wd.WorkspaceName, 3) = '- D'      THEN 'Development'
        WHEN RIGHT(wd.WorkspaceName, 3) = '- Q'      THEN 'Quality'
        WHEN RIGHT(wd.WorkspaceName, 7) = '- ADHOC'  THEN 'Adhoc'
        WHEN RIGHT(wd.WorkspaceName, 8) = '- PUBLIC' THEN 'Public'
        -- treat Region prefixes as Production Certified
        WHEN LEFT(wd.WorkspaceName, 3) IN ('GL ', 'AP ', 'NA ') 
          OR LEFT(wd.WorkspaceName, 4) = 'LAO '
          OR LEFT(wd.WorkspaceName, 5) = 'EMEA '
          THEN 'Production Certified'
        ELSE 'Naming Error'
    END AS WorkspaceType,
    pp.DomainID,
    sd.SubdomainID,
    pp.Segment,
    pp.ABU,
    sd.GlobalFunction
FROM ParsedParent AS pp
LEFT JOIN SubDomain   AS sd ON pp.DomainID = sd.ParentDomainID
INNER JOIN PBI_Platform_Automation.DomainWorkspace AS dw 
    ON dw.DomainID = sd.SubdomainID
INNER JOIN PBI_Platform_Automation.WorkspaceDetail AS wd
    ON wd.WorkspaceID = dw.WorkspaceID
   AND wd.IsOnDedicatedCapacity = 1
GROUP BY 
    dw.WorkspaceID,
    wd.WorkspaceName,
    wd.WorkspaceID,
    pp.Segment,
    pp.ABU,
    pp.DomainID,
    sd.SubdomainID,
    sd.GlobalFunction,
    sd.SubDomainDescription,
    sd.SubDomainContributorsScope
