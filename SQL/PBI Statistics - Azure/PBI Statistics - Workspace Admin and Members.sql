-- Drop all temporary tables if they exist
DROP TABLE IF EXISTS #ParentDomains;
DROP TABLE IF EXISTS #DomainSegmentABU;
DROP TABLE IF EXISTS #tblWorkspaceAdminTemp;
DROP TABLE IF EXISTS #AllEmails;
DROP TABLE IF EXISTS #AdminEmails;
DROP TABLE IF EXISTS #DistinctOwners;
DROP TABLE IF EXISTS #DistinctDelegates;
DROP TABLE IF EXISTS #DistinctAuthorizers;

-- Step 1: Get domain detail by Workspace
/*
Get information on the parent domain of the Workspace
*/
SELECT dd.DomainID AS ParentDomainID,
SUBSTRING(dd.DisplayName, 1, CHARINDEX(' - ', dd.DisplayName) - 1) AS Segment,
SUBSTRING(dd.DisplayName, CHARINDEX(' - ', dd.DisplayName) + LEN(' - '), LEN(DisplayName)) AS ABU
INTO #ParentDomains
FROM PBI_Platform_Automation.DomainDetail dd
WHERE ParentDomainID IS NULL
AND Description = 'Segment - ABU'
GROUP BY dd.DomainID,
DisplayName;

/*
Expand all domains out to the DomainID level
*/
SELECT pd.ParentDomainID,
dd.DomainID,
pd.Segment,
pd.ABU,
dd.DisplayName AS GlobalFunction
INTO #DomainSegmentABU
FROM #ParentDomains pd
INNER JOIN PBI_Platform_Automation.DomainDetail dd 
	ON dd.ParentDomainID = pd.ParentDomainID;

-- Step 2: Create a temporary table to store all emails
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
WHERE mam.Group_Name NOT IN ('PBI_ALLUSERS',
    'PBI_LC_PROUSER',
    'PBI_Support',
    'PBI_PL_SERVICEADMIN',
    'PBI_FFID_USERS',
    'PBI_COLIBRA_ADMIN_AAD',
    'PBI_PL_GATEWAY_LOGFILES',
    'PBI_PL_QA_ADH',
    'sp-pbi-platform-p-1')
AND wud.GroupUserAccessRight IN ('Viewer','Contributor');

-- Step 3: Create a temporary table to store admin emails
SELECT DISTINCT
    WorkspaceID,
    WorkspaceName,
    User_ID,
    Email_Address,
    Role
INTO #AdminEmails
FROM #AllEmails
WHERE Role IN ('Owner', 'Delegate', 'Authorizer');

-- Step 4: Create separate temporary tables for each role
SELECT DISTINCT
    WorkspaceID,
    User_ID,
    Email_Address
INTO #DistinctOwners
FROM #AdminEmails
WHERE Role = 'Owner';

SELECT DISTINCT
    WorkspaceID,
    User_ID,
    Email_Address
INTO #DistinctDelegates
FROM #AdminEmails
WHERE Role = 'Delegate';

SELECT DISTINCT
    WorkspaceID,
    User_ID,
    Email_Address
INTO #DistinctAuthorizers
FROM #AdminEmails
WHERE Role = 'Authorizer';

-- Step 5: Create the final result table
    SELECT 
        wd.WorkspaceID,
        wd.WorkspaceName,
        CASE WHEN LEFT(wd.WorkspaceName, 3) = 'GL ' THEN 'Global'
        WHEN LEFT(wd.WorkspaceName, 3) = 'AP ' THEN 'Asia Pac'
        WHEN LEFT(wd.WorkspaceName, 3) = 'NA ' THEN 'North America'
        WHEN LEFT(wd.WorkspaceName, 4) = 'LAO ' THEN 'Latin America'
        WHEN LEFT(wd.WorkspaceName, 5) = 'EMEA ' THEN 'EMEA'
        ELSE 'Naming Error' 
    END AS WorkspaceRegion,
    CASE WHEN RIGHT(wd.WorkspaceName, 3) = '- D' THEN 'Development'
        WHEN RIGHT(wd.WorkspaceName, 3) = '- Q' THEN 'Quality'
        WHEN RIGHT(wd.WorkspaceName, 7) = '- ADHOC' THEN 'Adhoc'
        WHEN RIGHT(wd.WorkspaceName, 8) = '- PUBLIC' THEN 'Public'
        WHEN LEFT(wd.WorkspaceName, 3) IN ('GL ', 'AP ', 'NA ', 'LAO', 'EME') THEN 'Production Certified'
        ELSE 'Naming Error' 
    END AS WorkspaceType,
    d.DomainID,
    d.Segment,
    d.ABU,
    d.GlobalFunction,
    -- Concatenate unique Owner Emails and IDs
    (SELECT STRING_AGG(CONVERT(VARCHAR(MAX), Email_Address), '; ')
     FROM #DistinctOwners o WHERE o.WorkspaceID = wd.WorkspaceID) AS OwnerEmails,
    (SELECT STRING_AGG(CONVERT(VARCHAR(MAX), User_ID), '; ')
     FROM #DistinctOwners o WHERE o.WorkspaceID = wd.WorkspaceID) AS OwnerIDs,
    -- Concatenate unique Delegate Emails and IDs
    (SELECT STRING_AGG(CONVERT(VARCHAR(MAX), Email_Address), '; ')
     FROM #DistinctDelegates d WHERE d.WorkspaceID = wd.WorkspaceID) AS DelegateEmails,
    (SELECT STRING_AGG(CONVERT(VARCHAR(MAX), User_ID), '; ')
     FROM #DistinctDelegates d WHERE d.WorkspaceID = wd.WorkspaceID) AS DelegateIDs,
    -- Concatenate unique Authorizer Emails and IDs
    (SELECT STRING_AGG(CONVERT(VARCHAR(MAX), Email_Address), '; ')
     FROM #DistinctAuthorizers a WHERE a.WorkspaceID = wd.WorkspaceID) AS AuthorizerEmails,
    (SELECT STRING_AGG(CONVERT(VARCHAR(MAX), User_ID), '; ')
     FROM #DistinctAuthorizers a WHERE a.WorkspaceID = wd.WorkspaceID) AS AuthorizerIDs,
    -- Concatenate all unique Admin Emails (Owner, Delegate, Authorizer)
    (SELECT STRING_AGG(CONVERT(VARCHAR(MAX), Email_Address), '; ')
     FROM (SELECT DISTINCT Email_Address FROM #AdminEmails ae WHERE ae.WorkspaceID = wd.WorkspaceID) AS DistinctAdminEmails) AS AllAdminEmails,
    -- Concatenate all unique Admin User IDs (Owner, Delegate, Authorizer)
    (SELECT STRING_AGG(CONVERT(VARCHAR(MAX), User_ID), '; ')
     FROM (SELECT DISTINCT User_ID FROM #AdminEmails ae WHERE ae.WorkspaceID = wd.WorkspaceID) AS DistinctAdminUserIDs) AS AllAdminUserIDs,
    -- Concatenate all unique Emails
    (SELECT STRING_AGG(CONVERT(VARCHAR(MAX), Email_Address), '; ')
     FROM (SELECT DISTINCT Email_Address FROM #AllEmails ae WHERE ae.WorkspaceID = wd.WorkspaceID) AS DistinctAllEmails) AS AllEmails,
    -- Concatenate all unique User IDs
    (SELECT STRING_AGG(CONVERT(VARCHAR(MAX), User_ID), '; ')
     FROM (SELECT DISTINCT User_ID FROM #AllEmails ae WHERE ae.WorkspaceID = wd.WorkspaceID) AS DistinctAllUserIDs) AS AllUserIDs
INTO #tblWorkspaceAdminTemp   
FROM 
    PBI_Platform_Automation.WorkspaceDetail wd
    LEFT JOIN PBI_Platform_Automation.DomainWorkspace dw ON dw.WorkspaceID = wd.WorkspaceID
    LEFT JOIN #DomainSegmentABU d ON d.DomainID = dw.DomainID
WHERE 
    wd.IsOnDedicatedCapacity = 1
    AND wd.WorkspaceState = 'Active'    
GROUP BY 
    wd.WorkspaceID,
    wd.WorkspaceName,
    d.DomainID,
    d.Segment,
    d.ABU,
    d.GlobalFunction;

SELECT * FROM #tblWorkspaceAdminTemp;