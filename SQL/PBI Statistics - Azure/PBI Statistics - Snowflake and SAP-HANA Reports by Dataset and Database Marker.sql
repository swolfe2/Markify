/*
Get all Datasets which have an SAP/HANA table
*/
WITH Datasets
AS (
	SELECT DISTINCT DatasetID,
		CASE 
			WHEN TableExpression LIKE '%SapHana.Database%'
				THEN 1
			ELSE 0
			END AS SAPHANAMarker,
		CASE 
			WHEN TableExpression LIKE '%Snowflake.Databases%'
				THEN 1
			ELSE 0
			END AS SnowflakeMarker
	FROM PBI_Platform_Automation.DatasetTableDetail
	WHERE (TableExpression LIKE '%SapHana.Database%'
		OR TableExpression LIKE '%Snowflake.Databases%')
		-- Optional filter for a specific dataset
		-- AND DatasetID = 'ed27149b-b9c2-49f4-b74e-734d8300b358'
	),
/*
Group Datasets into whether they use only 1 database backend or both
*/
DatasetGroups
AS (
	SELECT DatasetID,
		MAX(SAPHANAMarker) AS SAPHANAMarker,
		MAX(SnowflakeMarker) AS SnowflakeMarker,
		CASE 
			WHEN MAX(SAPHANAMarker) = 1
				AND MAX(SnowflakeMarker) = 1
				THEN 'Both SAP/HANA and Snowflake'
			WHEN MAX(SAPHANAMarker) = 1
				THEN 'SAP/HANA Only'
			WHEN MAX(SnowflakeMarker) = 1
				THEN 'Snowflake Only'
			ELSE 'Neither SAP/HANA or Snowflake'
			END AS DatabaseMarker
	FROM Datasets
	GROUP BY DatasetID
	),
/*
Get information on the parent domain of the Workspace
*/
ParentDomains
AS (
	SELECT dd.DomainID AS ParentDomainID,
		SUBSTRING(dd.DisplayName, 1, CHARINDEX(' - ', dd.DisplayName) - 1) AS Segment,
		SUBSTRING(dd.DisplayName, CHARINDEX(' - ', dd.DisplayName) + LEN(' - '), LEN(DisplayName)) AS ABU
	FROM PBI_Platform_Automation.DomainDetail dd
	WHERE ParentDomainID IS NULL
		AND Description = 'Segment - ABU'
	GROUP BY dd.DomainID,
		DisplayName
	),
/*
Expand all domains out to the DomainID level
*/
DomainSegmentABU
AS (
	SELECT pd.ParentDomainID,
		dd.DomainID,
		pd.Segment,
		pd.ABU,
		dd.DisplayName AS GlobalFunction
	FROM ParentDomains pd
	INNER JOIN PBI_Platform_Automation.DomainDetail dd ON dd.ParentDomainID = pd.ParentDomainID
	)
/*
Final query output
*/
SELECT DISTINCT wd.WorkspaceID,
	wd.WorkspaceName,
	dom.GlobalFunction,
	dom.Segment,
	dom.ABU,
	dd.DatasetID,
	dd.DatasetName,
	dg.SAPHANAMarker,
	dg.SnowflakeMarker,
	dg.DatabaseMarker,
	rd.ReportID,
	rd.ReportName
FROM PBI_Platform_Automation.CapacityDetail cd
INNER JOIN PBI_Platform_Automation.WorkspaceDetail wd ON wd.CapacityID = wd.CapacityID
	AND wd.IsOnDedicatedCapacity = 1
LEFT JOIN PBI_Platform_Automation.DomainWorkspace dw ON dw.WorkspaceID = wd.WorkspaceID
LEFT JOIN DomainSegmentABU dom ON dom.DomainID = dw.DomainID
INNER JOIN PBI_Platform_Automation.DatasetDetail dd ON dd.WorkspaceID = wd.WorkspaceID
INNER JOIN Datasets d ON d.DatasetID = dd.DatasetID
INNER JOIN PBI_Platform_Automation.ReportDetail rd ON rd.DatasetID = dd.DatasetID
LEFT JOIN DatasetGroups dg ON dg.DatasetID = d.DatasetID