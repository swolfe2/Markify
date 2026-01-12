/*
    Report Owners with Production Certified Replacements for USNOFF
    ================================================================
    
    Purpose:
        Identifies report owners across capacities and replaces FFID/NULL owners
        on Production Certified reports with the actual owner from Adhoc capacity.
    
    Logic:
        1. Find reports in Adhoc capacity to get the "real" owner (ModifiedBy)
        2. For Premium_Prod reports where owner is FFID (USNOFF) or NULL,
           substitute the Adhoc owner as the "UpdatedOwnerFromAdhoc"
        3. Enrich with User IDs by joining owner emails to MembersAndManagers
    
    CTEs:
        - AdhocOwners: Reports from Adhoc capacity with their owners
        - Reports:     All reports with owner replacement logic applied
        - UserInfo:    User ID to Email mapping for lookups
*/

WITH 
/*
    CTE: AdhocOwners
    ----------------
    Retrieves all reports from Adhoc capacities with their last modifier (owner).
    Used as the source of "true" ownership when Production reports have
    FFID accounts or NULL as the owner.
    BaseWorkspaceName strips ' - Adhoc' suffix for matching to Production workspaces.
*/
AdhocOwners AS (
    SELECT DISTINCT
        cd.CapacityID,
        cd.CapacityName,
        wd.WorkspaceName,
        REPLACE(wd.WorkspaceName, ' - Adhoc', '') AS BaseWorkspaceName,
        wd.WorkspaceID,
        rd.ReportID,
        rd.ReportName,
        LOWER(rd.ModifiedBy) AS AdhocOwner
    FROM PBI_Platform_Automation.CapacityDetail cd
    INNER JOIN PBI_Platform_Automation.WorkspaceDetail wd
        ON wd.CapacityID = cd.CapacityID
    INNER JOIN PBI_Platform_Automation.ReportDetail rd
        ON rd.WorkspaceID = wd.WorkspaceID
    WHERE cd.CapacityName LIKE '%Adhoc%'
),

/*
    CTE: Reports
    ------------
    Core report listing with owner replacement logic.
    For Premium_Prod reports where ModifiedBy contains 'USNOFF' or is NULL,
    the owner is replaced with the corresponding AdhocOwner.
    OwnerFlag indicates whether the owner was 'Replaced' or is 'Actual'.
*/
Reports AS (
    SELECT DISTINCT
        cd.CapacityID,
        cd.CapacityName,
        wd.WorkspaceName,
        wd.WorkspaceID,
        rd.ReportID,
        rd.ReportName,
        LOWER(rd.ModifiedBy) AS CurrentOwner,
        CASE
            WHEN cd.CapacityName = 'Premium_Prod'
                 AND (rd.ModifiedBy LIKE '%USNOFF%' OR rd.ModifiedBy IS NULL)
            THEN LOWER(ao.AdhocOwner)
            ELSE LOWER(rd.ModifiedBy)
        END AS UpdatedOwnerFromAdhoc,
        CASE
            WHEN cd.CapacityName = 'Premium_Prod'
                 AND (rd.ModifiedBy LIKE '%USNOFF%' OR rd.ModifiedBy IS NULL)
            THEN 'Replaced'
            ELSE 'Actual'
        END AS OwnerFlag
    FROM PBI_Platform_Automation.CapacityDetail cd
    INNER JOIN PBI_Platform_Automation.WorkspaceDetail wd
        ON wd.CapacityID = cd.CapacityID
    INNER JOIN PBI_Platform_Automation.ReportDetail rd
        ON rd.WorkspaceID = wd.WorkspaceID
    LEFT JOIN AdhocOwners ao
        ON ao.BaseWorkspaceName = wd.WorkspaceName
        AND ao.ReportName = rd.ReportName
),

/*
    CTE: UserInfo
    -------------
    Lookup table mapping user emails to their User IDs.
    Used to enrich owner emails with corresponding User IDs.
*/
UserInfo AS (
    SELECT DISTINCT
        UPPER(mam.User_ID) AS UserID,
        LOWER(mam.Email_Address) AS UserEmail
    FROM PBI_Groups.MembersAndManagers mam
)

/*
    Final SELECT
    ------------
    Combines report data with User ID lookups for both current and updated owners.
*/
SELECT
    r.CapacityID,
    r.CapacityName,
    r.WorkspaceName,
    r.WorkspaceID,
    r.ReportID,
    r.ReportName,
    r.CurrentOwner,
    u.UserID AS CurrentOwnerID,
    r.UpdatedOwnerFromAdhoc,
    u2.UserID AS UpdatedOwnerID,
    r.OwnerFlag
FROM Reports r
LEFT JOIN UserInfo u
    ON u.UserEmail = r.CurrentOwner
LEFT JOIN UserInfo u2
    ON u2.UserEmail = r.UpdatedOwnerFromAdhoc
ORDER BY
    r.CapacityID,
    r.CapacityName,
    r.WorkspaceName,
    r.WorkspaceID,
    r.ReportID,
    r.ReportName;
