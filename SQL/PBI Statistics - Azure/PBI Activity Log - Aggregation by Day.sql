SELECT
    cd.CapacityID,
    cd.CapacityName,
    wd.WorkspaceID,
    wd.WorkspaceName,
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
    TRIM(
        CASE 
            WHEN CHARINDEX(CHAR(13) + CHAR(10), wd.Description) > 0
                THEN REPLACE(wd.Description, CHAR(13) + CHAR(10), ' ')
            WHEN CHARINDEX(CHAR(13), wd.Description) > 0
                THEN REPLACE(wd.Description, CHAR(13), ' ')
            WHEN CHARINDEX(CHAR(10), wd.Description) > 0
                THEN REPLACE(wd.Description, CHAR(10), ' ')
            ELSE wd.Description
        END) AS WorkspaceDescription,
    CONCAT('https://app.powerbi.com/groups/', wd.WorkspaceID) AS WorkspaceURL,
    pal.DatasetID,
    pal.DatasetName,
    CONCAT('https://app.powerbi.com/groups/', pal.WorkspaceID, '/settings/datasets/', pal.DatasetID) AS DatasetURL,
    pal.ReportID,
    pal.ReportName,
    CONCAT('https://app.powerbi.com/groups/', pal.WorkspaceID, '/reports/', pal.ReportID) AS ReportURL,
    pal.CreationDate,
    pal.Activity,
    COUNT(*) AS RecordCount

FROM PBI_Platform_Automation.PBIActivityLog pal
INNER JOIN PBI_Platform_Automation.CapacityDetail cd
    ON cd.CapacityID = pal.CapacityID 
INNER JOIN PBI_Platform_Automation.WorkspaceDetail wd 
    ON wd.WorkspaceID = pal.WorkspaceID
    AND wd.IsOnDedicatedCapacity = 1

WHERE pal.ReportID IS NOT NULL
AND pal.ReportName NOT IN ('Usage Metrics Report', 'Report Usage Metrics Report')

GROUP BY cd.CapacityID,
cd.CapacityName,
wd.WorkspaceID,
wd.WorkspaceName,
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
    END,
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
    END,
TRIM(
    CASE 
        WHEN CHARINDEX(CHAR(13) + CHAR(10), wd.Description) > 0
            THEN REPLACE(wd.Description, CHAR(13) + CHAR(10), ' ')
        WHEN CHARINDEX(CHAR(13), wd.Description) > 0
            THEN REPLACE(wd.Description, CHAR(13), ' ')
        WHEN CHARINDEX(CHAR(10), wd.Description) > 0
            THEN REPLACE(wd.Description, CHAR(10), ' ')
        ELSE wd.Description
    END),
CONCAT('https://app.powerbi.com/groups/', wd.WorkspaceID),
pal.DatasetID,
pal.DatasetName,
CONCAT('https://app.powerbi.com/groups/', pal.WorkspaceID, '/settings/datasets/', pal.DatasetID),
pal.ReportID,
pal.ReportName,
CONCAT('https://app.powerbi.com/groups/', pal.WorkspaceID, '/reports/', pal.ReportID),
pal.CreationDate,
pal.Activity;