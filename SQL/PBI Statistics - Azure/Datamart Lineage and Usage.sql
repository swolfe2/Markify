/*
Drop temp tables for clean run
*/
BEGIN TRY
    DROP TABLE IF EXISTS #AllEmails;
    DROP TABLE IF EXISTS #tblWorkspaceAdmin;
    DROP TABLE IF EXISTS #tblDatamartTemp;
    DROP TABLE IF EXISTS #tblDependentSemanticModels;
    DROP TABLE IF EXISTS #DependentReports;
    DROP TABLE IF EXISTS #ReportViews;
    DROP TABLE IF EXISTS #TotalActivities;
END TRY
BEGIN CATCH
    PRINT 'Error dropping temp tables: ' + ERROR_MESSAGE();
END CATCH;

/*
Integer variable for how far in the past to go back on the activity log
*/
DECLARE @DaysAgo INT = 180;

/*
Create a temporary table to store all admin emails
*/
SELECT 
    wd.WorkspaceID,
    wd.WorkspaceName,
    mam.User_ID,
    LOWER(mam.Email_Address) AS Email_Address,
    mam.Role

INTO #AllEmails
FROM 
    PBI_Groups.MembersAndManagers mam 
INNER JOIN 
    PBI_Platform_Automation.WorkspaceUserDetail wud
    ON wud.DisplayName = mam.Group_Name
INNER JOIN 
    PBI_Platform_Automation.WorkspaceDetail wd
    ON wd.WorkspaceID = wud.WorkspaceID
WHERE mam.Group_Name NOT IN ('PBI_ALLUSERS','PBI_LC_PROUSER','PBI_Support','PBI_PL_SERVICEADMIN','PBI_FFID_USERS','PBI_COLIBRA_ADMIN_AAD','PBI_PL_GATEWAY_LOGFILES')
AND mam.Role IN ('Owner', 'Delegate', 'Authorizer');

/*
Create a temporary table to concatenate multiple admin into same field for all Workspace IDs
*/
SELECT 
    wd.WorkspaceID,
    wd.WorkspaceName,
-- Concatenate all unique Admin Emails (Owner, Delegate, Authorizer)
(SELECT STRING_AGG(CONVERT(VARCHAR(MAX), Email_Address), '; ')
    FROM (SELECT DISTINCT Email_Address FROM #AllEmails ae WHERE ae.WorkspaceID = wd.WorkspaceID) AS DistinctAdminEmails) AS WorkspaceAdminEmails

INTO #tblWorkspaceAdmin
FROM 
    PBI_Platform_Automation.WorkspaceDetail wd
INNER JOIN #AllEmails ae 
    ON ae.WorkspaceID = wd.WorkspaceID 
GROUP BY  wd.WorkspaceID,
wd.WorkspaceName;
    
/*
Create temp table for all datamart IDs
--114 rows
SELECT * FROM #tblDatamartTemp WHERE DatamartWorkspaceID = '9ea18019-ff38-48f2-9128-ef6de7427493'
*/
SELECT
cd.CapacityID AS DatamartCapacityID,
cd.CapacityName AS DatamartCapacityName,
wd.WorkspaceID AS DatamartWorkspaceID,
wd.WorkspaceName AS DatamartWorkspaceName,
wa.WorkspaceAdminEmails AS DatamartWorkspaceAdminEmails,
LOWER(
	CASE WHEN 
		dmd.ModifiedBy IS NULL THEN dmd.ConfiguredBy
		ELSE 
		dmd.ConfiguredBy
	END 
) AS DatamartOwner,
dmd.DatamartType,
dmd.DatamartID,
dmd.DatamartName

INTO #tblDatamartTemp
FROM PBI_Platform_Automation.DatamartDetail dmd
INNER JOIN PBI_Platform_Automation.WorkspaceDetail wd
  ON wd.WorkspaceID = dmd.WorkspaceID 
  AND wd.IsOnDedicatedCapacity = 1
INNER JOIN PBI_Platform_Automation.CapacityDetail cd 
  ON cd.CapacityID = wd.CapacityID
INNER JOIN #tblWorkspaceAdmin wa 
    ON wa.WorkspaceID = wd.WorkspaceID
GROUP BY cd.CapacityID,
cd.CapacityName,
wd.WorkspaceID,
wd.WorkspaceName,
wa.WorkspaceAdminEmails,
CASE WHEN 
		dmd.ModifiedBy IS NULL THEN dmd.ConfiguredBy
		ELSE 
		dmd.ConfiguredBy
	END,
dmd.DatamartType,
dmd.DatamartID,
dmd.DatamartName;

/*
Create temp table of all dependent artifacts
SELECT * FROM PBI_Platform_Automation.ArtifactLineageDetail
--313 rows
SELECT * FROM #tblDependentSemanticModels WHERE DependentWorkspaceiD = '9ea18019-ff38-48f2-9128-ef6de7427493'
*/
SELECT DISTINCT
dmt.*, 
ald.WorkspaceID AS DependentWorkspaceID,
ald.WorkspaceName AS DependentWorkspaceName,
wa.WorkspaceAdminEmails AS DependentWorkspaceAdminEmails,
ald.ArtifactType AS DependentArtifactType,
ald.ArtifactID AS DependentArtifactID,
ald.ArtifactName AS DependentArtifactName

INTO #tblDependentSemanticModels
FROM #tblDatamartTemp dmt
LEFT JOIN PBI_Platform_Automation.ArtifactLineageDetail ald 
	ON ald.DependentArtifactID = dmt.DatamartID
INNER JOIN #tblWorkspaceAdmin wa 
    ON wa.WorkspaceID = ald.DependentWorkspaceID;


/*
Create temp table of all Reports that are attached to dependent semantic models
SELECT * FROM #DependentReports WHERE DatamartWorkspaceID = '9ea18019-ff38-48f2-9128-ef6de7427493'
DROP TABLE IF EXISTS #DependentReports;
--332 rows
*/
SELECT DISTINCT 
dsm.*,
wd.WorkspaceID AS ReportWorkspaceID,
wd.WorkspaceName AS ReportWorkspaceName,
wd.IsOnDedicatedCapacity,
rd.ReportID,
rd.ReportName,
rd.ModifiedBy AS ReportModifiedBy


INTO #DependentReports
FROM #tblDependentSemanticModels dsm
LEFT JOIN PBI_Platform_Automation.ReportDetail rd 
    ON rd.DatasetID = dsm.DependentArtifactID
    AND LEFT(rd.ReportName,5) <> '[App]'
LEFT JOIN PBI_Platform_Automation.WorkspaceDetail wd
    ON wd.WorkspaceID = rd.WorkspaceID
    AND wd.IsOnDedicatedCapacity = 1;

/*
Calculate REPORT usage across all dependent ReportIDs in the @DaysAgo timeframe
SELECT * FROM #ReportViews
*/
SELECT DISTINCT 
dr.DependentWorkspaceID,
dr.ReportID,
COUNT ( * ) AS ReportViewCount,
MIN ( pal.CreationDate ) AS EarliestViewDate,
MAX ( pal.CreationDate ) AS LatestViewDate

INTO #ReportViews
FROM #DependentReports dr
INNER JOIN PBI_Platform_Automation.PBIActivityLog pal 
    ON pal.ReportID = dr.ReportID 
    AND pal.WorkspaceID = dr.ReportWorkspaceID 
    AND pal.CreationDate >= CAST ( GETDATE() - 90 AS DATE ) 
    AND pal.Activity = 'ViewReport'
GROUP BY dr.DependentWorkspaceID,
dr.ReportID;

/*
Calculate ALL usage across all dependent DatasetIDs in the @DaysAgo timeframe
SELECT * FROM #TotalActivities
*/
SELECT DISTINCT 
dr.DependentWorkspaceID,
dr.DependentArtifactID,
COUNT ( * ) AS ActivityCount,
MIN ( pal.CreationDate ) AS EarliestActivityDate,
MAX ( pal.CreationDate ) AS LatestActivityDate

INTO #TotalActivities
FROM #DependentReports dr
INNER JOIN PBI_Platform_Automation.PBIActivityLog pal 
    ON pal.DatasetID = dr.DependentArtifactID 
    AND pal.WorkspaceID = dr.ReportWorkspaceID 
    AND pal.CreationDate >= CAST ( GETDATE() - 90 AS DATE ) 
GROUP BY dr.DependentWorkspaceID,
dr.DependentArtifactID;

/*
Final combination
*/

SELECT 
dr.DatamartCapacityID,
dr.DatamartCapacityName,
dr.DatamartWorkspaceID,
dr.DatamartWorkspaceName,
CASE WHEN LEFT(dr.DatamartWorkspaceName, 3) = 'GL ' THEN 'Global'
        WHEN LEFT(dr.DatamartWorkspaceName, 3) = 'AP ' THEN 'Asia Pac'
        WHEN LEFT(dr.DatamartWorkspaceName, 3) = 'NA ' THEN 'North America'
        WHEN LEFT(dr.DatamartWorkspaceName, 4) = 'LAO ' THEN 'Latin America'
        WHEN LEFT(dr.DatamartWorkspaceName, 5) = 'EMEA ' THEN 'EMEA'
        ELSE 'Naming Error' 
    END AS WorkspaceRegion,
    CASE WHEN RIGHT(dr.DatamartWorkspaceName, 3) = '- D' THEN 'Development'
        WHEN RIGHT(dr.DatamartWorkspaceName, 3) = '- Q' THEN 'Quality'
        WHEN RIGHT(dr.DatamartWorkspaceName, 7) = '- ADHOC' THEN 'Adhoc'
        WHEN RIGHT(dr.DatamartWorkspaceName, 8) = '- PUBLIC' THEN 'Public'
        WHEN LEFT(dr.DatamartWorkspaceName, 3) IN ('GL ', 'AP ', 'NA ', 'LAO', 'EME') THEN 'Production Certified'
        ELSE 'Naming Error' 
    END AS WorkspaceType,
dr.DatamartWorkspaceAdminEmails,
dr.DatamartOwner,
dr.DatamartType,
dr.DatamartID,
dr.DatamartName,
dr.DependentWorkspaceID,
dr.DependentWorkspaceName,
dr.DependentWorkspaceAdminEmails,
dr.DependentArtifactType,
dr.DependentArtifactID,
dr.DependentArtifactName,
dr.ReportWorkspaceID,
dr.ReportWorkspaceName,
dr.ReportID,
dr.ReportName,
dr.ReportModifiedBy,
rv.ReportViewCount,
ta.ActivityCount,
CASE 
    WHEN dr.ReportID IS NULL
        THEN 'Report Not On Enterprise Capacity'
    WHEN ta.ActivityCount IS NULL AND rv.ReportViewCount IS NULL
        THEN 'No Activity'
    WHEN rv.ReportViewCount IS NULL 
        THEN 'No Report Views'
    WHEN ta.ActivityCount IS NULL 
        THEN 'No Activities'
    ELSE
        'Utilized'
    END 
AS ActivityFlag

FROM #DependentReports dr
LEFT JOIN #ReportViews rv 
    ON rv.DependentWorkspaceID = dr.DependentWorkspaceID
    AND rv.ReportID = dr.ReportID
LEFT JOIN #TotalActivities ta 
    ON ta.DependentWorkspaceID = dr.DependentWorkspaceID
    AND ta.DependentArtifactID = dr.DependentArtifactID

GROUP BY dr.DatamartCapacityID,
dr.DatamartCapacityName,
dr.DatamartWorkspaceID,
dr.DatamartWorkspaceName,
dr.DatamartWorkspaceAdminEmails,
dr.DatamartOwner,
dr.DatamartType,
dr.DatamartID,
dr.DatamartName,
dr.DependentWorkspaceID,
dr.DependentWorkspaceName,
dr.DependentWorkspaceAdminEmails,
dr.DependentArtifactType,
dr.DependentArtifactID,
dr.DependentArtifactName,
dr.ReportWorkspaceID,
dr.ReportWorkspaceName,
dr.ReportID,
dr.ReportName,
dr.ReportModifiedBy,
rv.ReportViewCount,
ta.ActivityCount

ORDER BY dr.DatamartCapacityName ASC,
dr.DatamartWorkspaceName ASC,
dr.DatamartName ASC, 
ta.ActivityCount DESC;

/*
Testing queries

SELECT TOP 100 * FROM PBI_Platform_Automation.PBIActivityLog
WHERE DatasetID = '0e3fe0a8-b1a6-4a06-97e8-a2e2c84d6757'

SELECT * FROM PBI_Platform_Automation.DatamartDetail 
WHERE DatamartID = '0e3fe0a8-b1a6-4a06-97e8-a2e2c84d6757'

SELECT * FROM PBI_Platform_Automation.DatasetTableDetail 
WHERE DatasetID = '598d914c-920f-4678-a773-b6cc3443f967'

SELECT * FROM PBI_Platform_Automation.DatasetDetail 
WHERE DatasetID = '598d914c-920f-4678-a773-b6cc3443f967'

SELECT * FROM PBI_Platform_Automation.ArtifactLineageDetail
WHERE ArtifactID = '0e3fe0a8-b1a6-4a06-97e8-a2e2c84d6757'

SELECT * FROM PBI_Platform_Automation.ArtifactLineageDetail
WHERE DependentArtifactID = '0e3fe0a8-b1a6-4a06-97e8-a2e2c84d6757'

SELECT pal.DatasetID,
pal.WorkspaceId,
COUNT ( * ) AS RecordCount
FROM PBI_Platform_Automation.PBIActivityLog pal
WHERE pal.CreationDate > @DaysAgo
GROUP BY pal.DatasetId,
pal.WorkspaceID

SELECT * FROM PBI_Platform_Automation.DatamartDetail
WHERE WorkspaceID = '9ea18019-ff38-48f2-9128-ef6de7427493'
*/