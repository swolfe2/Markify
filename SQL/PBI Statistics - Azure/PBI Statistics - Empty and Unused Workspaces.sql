/*
This SQL was composed by steve.wolfe@kcc.com
Last Updated: 2/25/2025
Intent: To analyze all Power BI Workspaces, and identify:
1) Workspaces with no reports (Empty Workspaces)
2) Workspaces with reports that have not been accessed in the last X number of days

Main Activity Types
CreateFolder = 'Created Workspace'
DeleteFolder = 'Deleted Workspace'
*/


/*
Variable for how far back to go on the PBI Activity Log
*/
DECLARE @DaysAgo INT = 90;

/*
Start by getting the Workspaces which have already been deleted
*/
WITH WorkspacesDeleted AS (
    SELECT 
        CASE WHEN al.WorkspaceName IS NULL 
        THEN al.ObjectID 
        ELSE al.WorkspaceName 
    END AS WorkspaceName
    FROM PBI_Platform_Automation.PBIActivityLog al
    WHERE al.Activity = 'DeleteFolder'
    AND al.WorkspaceName IS NOT NULL
    GROUP BY CASE WHEN al.WorkspaceName IS NULL 
        THEN al.ObjectID 
        ELSE al.WorkspaceName 
    END
),

/*
Get all Workspaces that have been created, along with when they were created
Minus the Workspaces that have already been deleted
This appears to only go back to the beginning of 2024
*/
CreatedWorkspaces AS (
    SELECT cw.WorkspaceName,
    cw.WorkspaceID,
    CASE 
        WHEN cw.CreationDate IS NULL 
        THEN '12/31/2023' 
        ELSE cw.CreationDate 
    END AS CreationDate
    FROM (
        SELECT 
            wd.WorkspaceName,
            wd.WorkspaceID,
            MAX(al.CreationDate) AS CreationDate
        FROM PBI_Platform_Automation.WorkspaceDetail wd
            INNER JOIN PBI_Platform_Automation.PBIActivityLog al
                ON al.ItemName = wd.WorkspaceName
        WHERE al.Activity = 'CreateFolder'
        AND wd.WorkspaceName IS NOT NULL
        GROUP BY wd.WorkspaceName,
        wd.WorkspaceID
    ) cw 
    LEFT JOIN WorkspacesDeleted wd 
        ON wd.WorkspaceName = cw.WorkspaceName 
    WHERE wd.WorkspaceName IS NULL
    GROUP BY cw.WorkspaceName,
    cw.WorkspaceID,
    cw.CreationDate
),

/*
Get all Reports that exist in all Workspaces
Get all Report usage for the last X number of days
Count the number of reports per Workspace, and how many have had usage
*/
ReportUsage AS (
SELECT 
    r.CapacityID,
	r.CapacityName,
	r.WorkspaceID,
	r.WorkspaceName,
	r.TotalReportCount,
	r.TotalUsageCount,
	CASE 
		WHEN r.TotalReportCount = 0
			AND r.TotalUsageCount = 0
			THEN 'No Reports'
		WHEN r.TotalUsageCount = 0
			THEN 'No Report Usage'
		ELSE 'Other Issue'
    END AS ReportUsageFlag,
	MAX(r.LastViewedDate) AS LastViewedDate, 
    DATEDIFF ( DAY, MAX(r.LastViewedDate), CAST(GETDATE() AS DATE)) AS DaysSinceLastView
FROM (
    SELECT DISTINCT cd.CapacityID,
        cd.CapacityName,
        wd.WorkspaceID,
        wd.WorkspaceName,
        CAST(COALESCE(COUNT(DISTINCT r.ReportID), 0) AS INT) AS TotalReportCount,
        CAST(COALESCE(SUM(r.ReportUsageCount), 0) AS INT) AS TotalUsageCount,
        MAX(r.LastViewedDate) AS LastViewedDate,
        CAST(COALESCE(SUM(r.UnusedReportMarker), 0) AS INT) AS UnusedReportCount,
        CAST(COALESCE(SUM(r.UsedReportMarker), 0) AS INT) AS UsedReportCount
    FROM PBI_Platform_Automation.WorkspaceDetail wd
    INNER JOIN PBI_Platform_Automation.CapacityDetail cd ON cd.CapacityID = wd.CapacityID
    LEFT JOIN (
        SELECT DISTINCT rd.WorkspaceID,
            rd.ReportID,
            CAST(COALESCE(SUM(lvd.ReportUsageCount), 0) AS INT) AS ReportUsageCount,
            CASE WHEN lvd.ReportUsageCount = 0 OR lvd.ReportID IS NULL THEN 1 ELSE 0 END AS UnusedReportMarker,
            CASE WHEN lvd.ReportUsageCount > 0 THEN 1 ELSE 0 END AS UsedReportMarker,
            lvd.LastViewedDate
        FROM PBI_Platform_Automation.ReportDetail rd
        /*
        Get the last viewed date from any time range and last X days
        */
        LEFT JOIN (
            SELECT DISTINCT al.WorkspaceID,
                al.ReportID,
                MAX(al.CreationDate) AS LastViewedDate,
                COALESCE(SUM(CASE 
                            WHEN al.CreationDate BETWEEN CAST(GETDATE() - @DaysAgo AS DATE)
                                    AND CAST(GETDATE() AS DATE)
                                THEN 1
                            ELSE 0
                            END), 0) AS ReportUsageCount
            FROM PBI_Platform_Automation.PBIActivityLog al
            INNER JOIN PBI_Platform_Automation.CapacityDetail cd ON cd.CapacityID = al.CapacityID
            WHERE al.Activity IN (
                    'ViewReport',
                    'ViewDashboard'
                    )
            AND al.ReportID IS NOT NULL
            AND al.ReportName NOT IN ('Usage Metrics Report', 'Report Usage Metrics Report')
            --AND al.WorkspaceID = '142cae3e-2d3b-40cb-9b9a-9c50c7b879cd'
            GROUP BY al.WorkspaceID,
                al.ReportID,
                al.CapacityID
            ) lvd ON lvd.WorkspaceID = rd.WorkspaceID
            AND lvd.ReportID = rd.ReportID
        WHERE rd.ReportID IS NOT NULL
        AND rd.ReportName NOT IN ('Usage Metrics Report', 'Report Usage Metrics Report')
            --AND rd.WorkspaceID = '142cae3e-2d3b-40cb-9b9a-9c50c7b879cd'
        GROUP BY rd.WorkspaceID,
            rd.ReportID,
            lvd.ReportID,
            lvd.LastViewedDate,
            lvd.ReportUsageCount
        ) r ON r.WorkspaceID = wd.WorkspaceID
    GROUP BY cd.CapacityID,
        cd.CapacityName,
        wd.WorkspaceID,
        wd.WorkspaceName
        ) r

WHERE r.TotalUsageCount = 0
GROUP BY r.CapacityID,
	r.CapacityName,
	r.WorkspaceID,
	r.WorkspaceName,
	r.TotalReportCount,
	r.TotalUsageCount,
	CASE 
		WHEN r.TotalReportCount = 0
			AND r.TotalUsageCount = 0
			THEN 'No Reports'
		WHEN r.TotalUsageCount = 0
			THEN 'No Report Usage'
		ELSE 'Other Issue'
    END
),

/*
For Group Management, start by getting all of the AD Groups for PBI Workspaces
*/
ADGroups
AS (
	SELECT wud.GroupUserAccessRight,
		wud.DisplayName,
		wud.WorkspaceID
	FROM PBI_Platform_Automation.WorkspaceUserDetail wud
	WHERE wud.DisplayName NOT IN (
			'PBI_PL_SERVICEADMIN',
			'PBI_FFID_USERS',
			'PBI_Support',
			'sp-pbi-platform-p-1',
			'collibraconnect-sp-prod-1',
			'USNOFF11',
			'USNOFF12',
			'USNOFF13'
			)
		AND wud.DisplayName LIKE 'PBI_WS%'
		AND wud.GroupUserAccessRight IN (
			'Contributor',
			'Viewer'
			)
	GROUP BY wud.GroupUserAccessRight,
		wud.DisplayName,
		wud.WorkspaceID
	),

/*
With the AD Groups for PBI Workspaces, get the emails of the Owners/Delegates
Typically, there should always be 2 values, and they both should be unique
*/
ADGroupAdminEmails
AS (
	SELECT mam.Group_Name,
		LOWER(mam.Email_Address) AS Email_Address
	FROM PBI_Groups.MembersAndManagers mam
	WHERE mam.ROLE IN (
			'Owner',
			'Delegate'
			)
		AND mam.Group_Name LIKE 'PBI_WS%'
	GROUP BY mam.Group_Name,
		LOWER(mam.Email_Address)
	),

/*
Output a final list of Owners/Delegates for each PBI Workspace with unique emails
*/
ADGroupAdmin
AS (
	SELECT ad.WorkspaceID,
		STRING_AGG(ad.Email_Address, ', ') AS WorkspaceAdmin
	FROM (
		SELECT ad.WorkspaceID,
			adae.Email_Address
		FROM ADGroups ad
		INNER JOIN ADGroupAdminEmails adae ON adae.Group_Name = ad.DisplayName
		GROUP BY ad.WorkspaceID,
			adae.Email_Address
		) ad
	GROUP BY ad.WorkspaceID
	)

/*
Main query which combines all CTE's above together
*/
SELECT
ru.CapacityID,
ru.CapacityName,
ru.WorkspaceID,
ru.WorkspaceName,
cw.CreationDate,
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
    END 
AS WorkspaceType,
TRIM(
    CASE 
        WHEN CHARINDEX(CHAR(13) + CHAR(10), wd.Description) > 0
            THEN REPLACE(wd.Description, CHAR(13) + CHAR(10), ' ')
        WHEN CHARINDEX(CHAR(13), wd.Description) > 0
            THEN REPLACE(wd.Description, CHAR(13), ' ')
        WHEN CHARINDEX(CHAR(10), wd.Description) > 0
            THEN REPLACE(wd.Description, CHAR(10), ' ')
        ELSE wd.Description
    END) 
AS WorkspaceDescription,
'https://app.powerbi.com/groups/' + wd.WorkspaceID AS WorkspaceURL,
ru.TotalReportCount,
ru.TotalUsageCount,
ru.ReportUsageFlag,
CAST ( ru.LastViewedDate AS DATE ) AS LastViewedDate,
ru.DaysSinceLastView,
CASE 
    WHEN adga.WorkspaceAdmin IS NULL 
        THEN 'Unknown' 
    ELSE adga.WorkspaceAdmin 
END AS WorkspaceAdmin
FROM ReportUsage ru
INNER JOIN PBI_Platform_Automation.WorkspaceDetail wd 
    ON wd.WorkspaceID = ru.WorkspaceID
LEFT JOIN ADGroupAdmin adga
    ON adga.WorkspaceID = wd.WorkspaceID
LEFT JOIN CreatedWorkspaces cw 
    ON cw.WorkspaceID = wd.WorkspaceID;
