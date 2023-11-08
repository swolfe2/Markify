SELECT 
rd.*,
DATEDIFF(minute, [StartTime], [EndTime]) AS TimeDifference
FROM PBI_Platform_Automation.RefreshDetail as rd
    INNER JOIN [PBI_Platform_Automation].[CapacityDetail] cd
        ON cd.CapacityID = rd.CapacityID
	INNER JOIN [PBI_Platform_Automation].[DatasetDetail] as dd
        ON dd.DatasetID = rd.DatasetID
    INNER JOIN [PBI_Platform_Automation].[workspaceDetail] as wd
        ON wd.WorkspaceID = rd.WorkspaceID
WHERE rd.CapacityID IN ('CC10DC9F-8F94-4DD9-80CB-C29A580EDA70', --New Dev/Qual Capacity ID as of 11/1/2023
'8E32EF36-AA16-4FEC-86BA-D2DBDAA70963') -- Adhoc Capacity
AND rd.AverageDuration > 0
AND CAST(rd.StartTime AS DATE) >= CAST(GETDATE()-60 AS DATE)
AND rd.DatasetID = 'c3db2418-b55a-4c8f-a446-8e764ba1e766'
ORDER BY StartTime DESC

SELECT DISTINCT 
cd.CapacityID,
cd.CapacityName,
dd.DatasetID,
dd.DatasetName,
dd.ConfiguredBy,
rd.Kind

FROM PBI_Platform_Automation.RefreshDetail as rd
    INNER JOIN [PBI_Platform_Automation].[CapacityDetail] cd
        ON cd.CapacityID = rd.CapacityID
	INNER JOIN [PBI_Platform_Automation].[DatasetDetail] as dd
        ON dd.DatasetID = rd.DatasetID
    INNER JOIN [PBI_Platform_Automation].[workspaceDetail] as wd
        ON wd.WorkspaceID = rd.WorkspaceID
WHERE rd.CapacityID IN ('CC10DC9F-8F94-4DD9-80CB-C29A580EDA70', --New Dev/Qual Capacity ID as of 11/1/2023
'8E32EF36-AA16-4FEC-86BA-D2DBDAA70963') -- Adhoc Capacity
AND rd.AverageDuration > 0
AND CAST(rd.StartTime AS DATE) >= CAST(GETDATE()-60 AS DATE)
AND rd.DatasetID = 'c3db2418-b55a-4c8f-a446-8e764ba1e766'

SELECT * FROM [PBI_Platform_Automation].[DatasetDetail] WHERE DatasetID = 'c3db2418-b55a-4c8f-a446-8e764ba1e766'

WITH RefreshDetail AS (
    SELECT DISTINCT
    cd.CapacityID,
    cd.CapacityName,
    wd.WorkspaceID,
    wd.WorkspaceName,
    wd.WorkspaceState,
    rd.Kind,
    dd.DatasetID,
    dd.DatasetName,
    dd.ContentProviderType,
    'https://app.powerbi.com/groups/' + wd.WorkspaceID +'/settings/datasets/' + dd.DatasetID AS DatasetURL,
    dd.ConfiguredBy AS DatasetOwner,
    CAST(rd.StartTime AS DATE) AS StartDate,
    rd.StartTime,
    CAST(rd.EndTime AS DATE) AS EndDate,
    rd.EndTime,
    DATEDIFF(MINUTE, rd.StartTime, rd.EndTime) AS Minutes,
    rd.LastRefreshType,
    rd.LastRefreshStatus
    FROM PBI_Platform_Automation.RefreshDetail AS rd
    INNER JOIN [PBI_Platform_Automation].[CapacityDetail] cd
    ON cd.CapacityID = rd.CapacityID
    INNER JOIN [PBI_Platform_Automation].[DatasetDetail] AS dd
    ON dd.DatasetID = rd.DatasetID
    INNER JOIN [PBI_Platform_Automation].[workspaceDetail] AS wd
    ON wd.WorkspaceID = rd.WorkspaceID
    WHERE rd.StartTime IS NOT NULL
    AND DATEDIFF(MINUTE, rd.StartTime, rd.EndTime) > 0
    AND CAST(rd.StartTime AS date) >= CAST(GETDATE() - 60 AS date)
    -- AND rd.CapacityID IN ('CC10DC9F-8F94-4DD9-80CB-C29A580EDA70', --New Dev/Qual Capacity ID as of 11/1/2023
    -- '8E32EF36-AA16-4FEC-86BA-D2DBDAA70963') -- Adhoc Capacity
    -- AND rd.DatasetID = 'c3db2418-b55a-4c8f-a446-8e764ba1e766'
)

SELECT * 
FROM PBI_Platform_Automation.RefreshDetail 
WHERE DatasetID = 'e2443ea4-4c58-4c27-8fa8-69f491e8ed76'
ORDER BY StartTime DESC