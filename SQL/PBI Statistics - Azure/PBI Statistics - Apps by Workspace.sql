--WARNING! ERRORS ENCOUNTERED DURING SQL PARSING!
/*
Get the parent domain values
*/
WITH ParentDomain
AS (   SELECT
               dd.DomainID,
               dd.DisplayName,
               dd.Description,
               dd.ContributorsScope,
               RTRIM(SUBSTRING(dd.DisplayName, 1, CHARINDEX(' - ', dd.DisplayName) - 1)) AS Segment,
               LTRIM(SUBSTRING(dd.DisplayName, CHARINDEX(' - ', dd.DisplayName) + 3, LEN(dd.DisplayName))) AS ABU
       FROM
               PBI_Platform_Automation.DomainDetail dd
       WHERE
               ParentDomainID IS NULL
       GROUP BY
               dd.DomainID,
               dd.DisplayName,
               dd.Description,
               dd.ContributorsScope),
/*
Get the subdomain values
*/
SubDomain
AS (   SELECT
               dd.DisplayName AS "Global Function",
               dd.DomainID AS "SubdomainID",
               dd.ContributorsScope AS "SubDomainContributorsScope",
               dd.[Description] AS "SubDomainDescription",
               dd.ParentDomainID
       FROM
               PBI_Platform_Automation.DomainDetail dd
       WHERE
               ParentDomainID IS NOT NULL
       GROUP BY
               dd.DomainID,
               dd.DisplayName,
               dd.Description,
               dd.ContributorsScope,
               dd.ParentDomainID),
/*
Combine Domains and Subdomains
*/
CombinedDomain
AS (   SELECT
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
       FROM
               ParentDomain pd
           LEFT JOIN
             SubDomain sd
                 ON pd.DomainID = sd.ParentDomainID
           INNER JOIN
             PBI_Platform_Automation.DomainWorkspace dw
                 ON dw.DomainID = sd.SubdomainID
       GROUP BY
               dw.WorkspaceID,
               dw.DisplayName,
               pd.DomainID,
               pd.Segment,
               pd.ABU,
               pd.[Description],
               sd.SubDomainID,
               sd.[Global Function],
               sd.SubDomainDescription,
               sd.SubDomainContributorsScope)
/*
Main logic to get Workspace list with Report added in Power BI App and Domain attributtes
*/
SELECT
        rd.[WorkspaceID],
        wd.WorkspaceName,
        CASE
                WHEN RIGHT(wd.WorkspaceName, 3) = '- D'
                  THEN
                  'Development'
                WHEN RIGHT(wd.WorkspaceName, 3) = '- Q'
                  THEN
                  'Quality'
                WHEN RIGHT(wd.WorkspaceName, 7) = '- ADHOC'
                  THEN
                  'Adhoc'
                WHEN RIGHT(wd.WorkspaceName, 8) = '- PUBLIC'
                  THEN
                  'Public'
                WHEN LEFT(wd.WorkspaceName, 3) IN (
                  'GL ',
                  'AP ',
                  'NA ',
                  'LAO',
                  'EME'
                  )
                  THEN
                  'Production Certified'
                ELSE
                'Naming Error'
        END AS Environment,
        CASE
                WHEN LEFT(wd.WorkspaceName, 3) = 'GL '
                  THEN
                  'Global'
                WHEN LEFT(wd.WorkspaceName, 3) = 'AP '
                  THEN
                  'Asia Pacific'
                WHEN LEFT(wd.WorkspaceName, 3) = 'NA '
                  THEN
                  'North America'
                WHEN LEFT(wd.WorkspaceName, 4) = 'LAO '
                  THEN
                  'Latin America'
                WHEN LEFT(wd.WorkspaceName, 5) = 'EMEA '
                  THEN
                  'EMEA'
                ELSE
                'Naming Error'
        END AS Region,
        cd.Segment,
        cd.ABU,
        cd.[Global Function],
        rd.AppID,
        rd.ReportID,
        rd.ReportName,
        rd.ModifiedDateTime,
        rd.WebUrl
FROM
        [PBI_Platform_Automation].[ReportDetail] AS rd
    INNER JOIN
      [PBI_Platform_Automation].[WorkspaceDetail] AS wd
        ON wd.WorkspaceID = rd.WorkspaceID
    LEFT JOIN
      CombinedDomain AS cd
        ON cd.WorkspaceID = rd.WorkspaceID
WHERE
        LEFT(rd.ReportName, 6) = '[App] '
        AND rd.AppID IS NOT NULL
        AND wd.IsOnDedicatedCapacity = 1
        AND wd.WorkspaceType = 'Workspace'
        AND wd.WorkspaceState = 'Active'
GROUP BY
        rd.[WorkspaceID],
        wd.WorkspaceName,
        cd.Segment,
        cd.ABU,
        cd.[Global Function],
        rd.AppID,
        rd.ReportID,
        rd.ReportName,
        rd.ModifiedDateTime,
        rd.WebUrl
ORDER BY
        wd.WorkspaceName ASC,
        rd.ReportName ASC