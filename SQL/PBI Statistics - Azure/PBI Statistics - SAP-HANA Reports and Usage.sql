
/*
Get all Datasets which have an SAP/HANA table
*/
WITH Datasets AS (
SELECT 
DatasetID 
FROM PBI_Platform_Automation.DatasetTableDetail dtd
GROUP BY DatasetID
),

/*
Get information on the parent domain of the Workspace
*/
ParentDomains AS (
SELECT dd.DomainID AS ParentDomainID,
SUBSTRING(dd.DisplayName, 1, CHARINDEX(' - ', dd.DisplayName) - 1) AS Segment,
SUBSTRING(dd.DisplayName, CHARINDEX(' - ', dd.DisplayName) + LEN(' - '), LEN(DisplayName)) AS ABU
FROM PBI_Platform_Automation.DomainDetail dd
WHERE ParentDomainID IS NULL
AND Description = 'Segment - ABU'
GROUP BY dd.DomainID,
DisplayName),

/*
Expand all domains out to the DomainID level
*/
DomainSegmentABU AS (
SELECT pd.ParentDomainID,
dd.DomainID,
pd.Segment,
pd.ABU,
dd.DisplayName AS GlobalFunction
FROM ParentDomains pd
INNER JOIN PBI_Platform_Automation.DomainDetail dd 
	ON dd.ParentDomainID = pd.ParentDomainID
),

/*
Get all unique report data for each unique dataset in the Datasets CTE
*/
ReportData AS (
SELECT 
cd.CapacityID,
cd.CapacityName,
wd.WorkspaceID,
wd.WorkspaceName,
rd.ReportID,
rd.ReportName,
LOWER(rd.ModifiedBy) AS ModifiedBy,
rd.ModifiedDateTime,
dom.GlobalFunction,
dom.Segment,
dom.ABU
FROM Datasets d
INNER JOIN PBI_Platform_Automation.DatasetDetail dd
	ON dd.DatasetID = d.DatasetID
INNER JOIN PBI_Platform_Automation.ReportDetail rd
	ON rd.DatasetID = dd.DatasetID 
INNER JOIN PBI_Platform_Automation.WorkspaceDetail wd
	ON wd.WorkspaceID = rd.WorkspaceID 
LEFT JOIN PBI_Platform_Automation.DomainWorkspace dw
	ON dw.WorkspaceID = wd.WorkspaceID
LEFT JOIN DomainSegmentABU dom
	ON dom.DomainID = dw.DomainID
INNER JOIN PBI_Platform_Automation.CapacityDetail cd 
	ON cd.CapacityID = wd.CapacityID 
	AND wd.IsOnDedicatedCapacity = 1
), 

/*
Calculate the view count and most recent view date from the Activity Log
This table has millions of rows, and where the majority of query compute comes from
*/
ReportViews AS (
SELECT al.ReportID,
al.WorkspaceID,
COUNT(al.ActivityID) AS ViewCount,
MAX(al.CreationDate) AS MostRecentViewDate
FROM PBI_Platform_Automation.PBIActivityLog al
INNER JOIN ReportData rd
    ON rd.ReportID = al.ReportID
    AND rd.WorkspaceID = al.WorkspaceId
WHERE Activity IN ('ViewReport')
AND al.CreationDate >= DATEADD(DAY, 1, DATEADD(MONTH, -6, EOMONTH(GETDATE(), -1))) --6 Calendar Months
GROUP BY al.ReportID,
al.WorkspaceID
)

/*
Final query
*/
SELECT rd.CapacityID,
rd.CapacityName,
rd.WorkspaceID,
rd.WorkspaceName,
rd.ReportID,
rd.ReportName,
rd.ModifiedBy,
rd.ModifiedDateTime,
rd.GlobalFunction,
rd.Segment,
rd.ABU,
COALESCE(rv.ViewCount,0) AS ViewCount,
rv.MostRecentViewDate
FROM ReportData rd
LEFT JOIN ReportViews rv 
	ON rv.ReportID = rd.ReportID 
	AND rv.WorkspaceID = rd.WorkspaceID