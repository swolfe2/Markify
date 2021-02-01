DROP TABLE IF EXISTS 
##tblAld,
##tblActualsToBidAppTemp;

CREATE TABLE ##tblActualsToBidAppTemp(
Name NVARCHAR(20),
[Delete] NVARCHAR(20),
[Visibility (State)] NVARCHAR(20),
[Lane Description] NVARCHAR(50),
[Region] NVARCHAR(20),
[Origin Group] NVARCHAR(20),
[Origin] NVARCHAR(20),
[Origin City] NVARCHAR(20),
[Origin State] NVARCHAR(20),
[Origin Postal Code] NVARCHAR(20),
[Origin Country] NVARCHAR(20),
[Destination] NVARCHAR(20),
[Destination City] NVARCHAR(20),
[Destination State] NVARCHAR(20),
[Destination Postal Code] NVARCHAR(20),
[Destination Country] NVARCHAR(20),
[Business Unit] NVARCHAR(20),
[Primary Lane Type] NVARCHAR(20),
[Primary Unload Type] NVARCHAR(20),
[Primary Customer(s)] NVARCHAR(50),
[Lane Comments] NVARCHAR(20),
[Miles- PC Miler 29] NVARCHAR(20),
[Intermodal Flag- Y or N] NVARCHAR(20),
[Max # of Intermodal] NVARCHAR(20),
[Annual Volume] NVARCHAR(20),
[Multi Stop Flag] NVARCHAR(20),
[Baseline w/o Fuel] NVARCHAR(20)
)


SELECT * INTO ##tblAld FROM (
SELECT DISTINCT ald.LD_LEG_ID,
ald.Lane,
ald.Region,
OriginGroup.OriginGroup,
ald.Origin_Zone,
ald.FRST_CTY_NAME,
ald.FRST_STA_CD,
CASE WHEN ald.FRST_CTRY_CD = 'USA' THEN LEFT(ald.FRST_PSTL_CD,5) ELSE ald.FRST_PSTL_CD END AS FRST_PSTL_CD,
ald.FRST_CTRY_CD,
ald.Dest_Zone,
ald.LAST_CTY_NAME,
ald.LAST_STA_CD,
CASE WHEN ald.LAST_CTRY_CD = 'USA' THEN LEFT(ald.LAST_PSTL_CD,5) ELSE ald.LAST_PSTL_CD END AS LAST_PSTL_CD,
ald.LAST_CTRY_CD,
ald.BU,
ald.OrderType,
CASE WHEN ald.LiveLoad IS NOT NULL THEN 'Live Load' ELSE 'Drop and Hook' END AS PrimaryUnloadType,
ald.CustomerHierarchy,
ald.STOPS,
ald.EQMT_TYP,
ald.Act_Linehaul
FROM USCTTDEV.dbo.tblActualLoadDetail ald
LEFT JOIN USCTTDEV.dbo.tblBidAppLanes bal ON bal.Lane = ald.Lane
LEFT JOIN (
SELECT DISTINCT bal.OriginGroup, bal.ORIG_CITY_STATE
FROM USCTTDEV.dbo.tblBidAppLanes bal
) OriginGroup ON originGroup.ORIG_CITY_STATE = ald.Origin_Zone
WHERE CAST(CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END AS DATE) >= GETDATE() - 90
AND bal.Lane IS NULL
AND ald.EQMT_TYP <> 'LTL'
) ald;

/*
Insert unique lane IDs into temp table
*/
INSERT INTO ##tblActualsToBidAppTemp([Lane Description] , Name)
SELECT Lane, ROW_NUMBER() OVER (ORDER BY lane.Lane ASC) FROM (
									SELECT DISTINCT
									ald.Lane,
									ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowNumber
									FROM ##tblAld ald
									GROUP BY
									ald.Lane) lane 
									WHERE lane.RowNumber = 1

/*
Update region by lane
*/
UPDATE ##tblActualsToBidAppTemp
SET Region = region.Region
FROM ##tblActualsToBidAppTemp t INNER JOIN 
(SELECT * FROM (
									SELECT DISTINCT ald.Region,
									ald.Lane,
									ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowNumber
									FROM ##tblAld ald
									GROUP BY ald.Region,
									ald.Lane) region 
									WHERE region.RowNumber = 1
)region ON region.Lane = t.[Lane Description];


/*
Update Origin Group by lane
*/
UPDATE ##tblActualsToBidAppTemp
SET [Origin Group] = originGroup.OriginGroup
FROM ##tblActualsToBidAppTemp t INNER JOIN (	SELECT * FROM (
									SELECT DISTINCT ald.OriginGroup,
									ald.Lane,
									ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowNumber
									FROM ##tblAld ald
									GROUP BY ald.OriginGroup,
									ald.Lane) OriginGroup 
									WHERE OriginGroup.RowNumber = 1
)originGroup ON originGroup.Lane = t.[Lane Description];

/*
Update with Origin Zone by lane
*/
UPDATE ##tblActualsToBidAppTemp
SET Origin= OriginZone.Origin_Zone
FROM ##tblActualsToBidAppTemp t INNER JOIN (
									SELECT * FROM (
									SELECT DISTINCT ald.Origin_Zone,
									ald.Lane,
									ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowNumber
									FROM ##tblAld ald
									GROUP BY ald.Origin_Zone,
									ald.Lane) Origin_Zone 
									WHERE Origin_Zone.RowNumber = 1
)OriginZone ON OriginZone.Lane = t.[Lane Description];

/*
Update First City Name by lane
*/
UPDATE ##tblActualsToBidAppTemp
SET [Origin City]= FRST_CTY_NAME.FRST_CTY_NAME
FROM ##tblActualsToBidAppTemp t INNER JOIN (
									SELECT * FROM (
									SELECT DISTINCT ald.FRST_CTY_NAME,
									ald.Lane,
									ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowNumber
									FROM ##tblAld ald
									GROUP BY ald.FRST_CTY_NAME,
									ald.Lane) FRST_CTY_NAME 
									WHERE FRST_CTY_NAME.RowNumber = 1
)FRST_CTY_NAME ON FRST_CTY_NAME.Lane = t.[Lane Description];

/*
Update First State Name by lane
*/
UPDATE ##tblActualsToBidAppTemp
SET [Origin State]= FRST_STA_CD.FRST_STA_CD
FROM ##tblActualsToBidAppTemp t INNER JOIN (
									SELECT * FROM (
									SELECT DISTINCT ald.FRST_STA_CD,
									ald.Lane,
									ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowNumber
									FROM ##tblAld ald
									GROUP BY ald.FRST_STA_CD,
									ald.Lane) FRST_STA_CD 
									WHERE FRST_STA_CD.RowNumber = 1
)FRST_STA_CD ON FRST_STA_CD.Lane = t.[Lane Description];

/*
Update First State Name by lane
*/
UPDATE ##tblActualsToBidAppTemp
SET [Origin Postal Code]= FRST_PSTL_CD.FRST_PSTL_CD
FROM ##tblActualsToBidAppTemp t INNER JOIN (
									SELECT * FROM (
									SELECT DISTINCT ald.FRST_PSTL_CD,
									ald.Lane,
									ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowNumber
									FROM ##tblAld ald
									GROUP BY ald.FRST_PSTL_CD,
									ald.Lane) FRST_PSTL_CD 
									WHERE FRST_PSTL_CD.RowNumber = 1
)FRST_PSTL_CD ON FRST_PSTL_CD.Lane = t.[Lane Description];

/*
Update First Country by lane
*/
UPDATE ##tblActualsToBidAppTemp
SET [Origin Country]= FRST_CTRY_CD.FRST_CTRY_CD
FROM ##tblActualsToBidAppTemp t INNER JOIN (
									SELECT * FROM (
									SELECT DISTINCT ald.FRST_CTRY_CD,
									ald.Lane,
									ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowNumber
									FROM ##tblAld ald
									GROUP BY ald.FRST_CTRY_CD,
									ald.Lane) FRST_CTRY_CD 
									WHERE FRST_CTRY_CD.RowNumber = 1
)FRST_CTRY_CD ON FRST_CTRY_CD.Lane = t.[Lane Description];

/*
Update Dest Zone by lane
*/
UPDATE ##tblActualsToBidAppTemp
SET Destination = Dest_Zone.Dest_Zone
FROM ##tblActualsToBidAppTemp t INNER JOIN (
									SELECT * FROM (
									SELECT DISTINCT ald.Dest_Zone,
									ald.Lane,
									ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowNumber
									FROM ##tblAld ald
									GROUP BY ald.Dest_Zone,
									ald.Lane) Dest_Zone 
									WHERE Dest_Zone.RowNumber = 1
)Dest_Zone ON Dest_Zone.Lane = t.[Lane Description];

/*
Update Dest City by lane
*/
UPDATE ##tblActualsToBidAppTemp
SET [Destination City] = LAST_CTY_NAME.LAST_CTY_NAME
FROM ##tblActualsToBidAppTemp t INNER JOIN (
									SELECT * FROM (
									SELECT DISTINCT ald.LAST_CTY_NAME,
									ald.Lane,
									ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowNumber
									FROM ##tblAld ald
									GROUP BY ald.LAST_CTY_NAME,
									ald.Lane) LAST_CTY_NAME 
									WHERE LAST_CTY_NAME.RowNumber = 1
)LAST_CTY_NAME ON LAST_CTY_NAME.Lane = t.[Lane Description];

/*
Update Dest State by lane
*/
UPDATE ##tblActualsToBidAppTemp
SET [Destination State] = LAST_STA_CD.LAST_STA_CD
FROM ##tblActualsToBidAppTemp t INNER JOIN (
									SELECT * FROM (
									SELECT DISTINCT ald.LAST_STA_CD,
									ald.Lane,
									ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowNumber
									FROM ##tblAld ald
									GROUP BY ald.LAST_STA_CD,
									ald.Lane) LAST_STA_CD 
									WHERE LAST_STA_CD.RowNumber = 1
)LAST_STA_CD ON LAST_STA_CD.Lane = t.[Lane Description];

/*
Update Dest ZIP by lane
*/
UPDATE ##tblActualsToBidAppTemp
SET [Destination Postal Code] = LAST_PSTL_CD.LAST_PSTL_CD
FROM ##tblActualsToBidAppTemp t INNER JOIN  (
									SELECT * FROM (
									SELECT DISTINCT ald.LAST_PSTL_CD,
									ald.Lane,
									ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowNumber
									FROM ##tblAld ald
									GROUP BY ald.LAST_PSTL_CD,
									ald.Lane) LAST_PSTL_CD 
									WHERE LAST_PSTL_CD.RowNumber = 1
)LAST_PSTL_CD ON LAST_PSTL_CD.Lane = t.[Lane Description];

/*
Update Dest Country by lane
*/
UPDATE ##tblActualsToBidAppTemp
SET [Destination Country] = LAST_CTRY_CD.LAST_CTRY_CD
FROM ##tblActualsToBidAppTemp t INNER JOIN (
									SELECT * FROM (
									SELECT DISTINCT ald.LAST_CTRY_CD,
									ald.Lane,
									ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowNumber
									FROM ##tblAld ald
									GROUP BY ald.LAST_CTRY_CD,
									ald.Lane) LAST_CTRY_CD 
									WHERE LAST_CTRY_CD.RowNumber = 1
)LAST_CTRY_CD ON LAST_CTRY_CD.Lane = t.[Lane Description];

/*
Update BU by lane
*/
UPDATE ##tblActualsToBidAppTemp
SET [Business Unit] = BU.BU
FROM ##tblActualsToBidAppTemp t INNER JOIN (
									SELECT * FROM (
									SELECT DISTINCT ald.BU,
									ald.Lane,
									ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowNumber
									FROM ##tblAld ald
									GROUP BY ald.BU,
									ald.Lane) BU 
									WHERE BU.RowNumber = 1
)BU ON BU.Lane = t.[Lane Description];

/*
Update BU by lane
*/
UPDATE ##tblActualsToBidAppTemp
SET [Primary Lane Type] = OrderType.OrderType
FROM ##tblActualsToBidAppTemp t INNER JOIN(
									SELECT * FROM (
									SELECT DISTINCT ald.OrderType,
									ald.Lane,
									ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowNumber
									FROM ##tblAld ald
									GROUP BY ald.OrderType,
									ald.Lane) OrderType 
									WHERE OrderType.RowNumber = 1
)OrderType ON OrderType.Lane = t.[Lane Description];

/*
Update Primary Unload Type by lane
*/
UPDATE ##tblActualsToBidAppTemp
SET [Primary Unload Type] = PrimaryUnloadType.PrimaryUnloadType
FROM ##tblActualsToBidAppTemp t INNER JOIN(
									SELECT * FROM (
									SELECT DISTINCT ald.PrimaryUnloadType,
									ald.Lane,
									ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowNumber
									FROM ##tblAld ald
									GROUP BY ald.PrimaryUnloadType,
									ald.Lane) PrimaryUnloadType 
									WHERE PrimaryUnloadType.RowNumber = 1
)PrimaryUnloadType ON PrimaryUnloadType.Lane = t.[Lane Description];

/*
Update Customer by lane
*/
UPDATE ##tblActualsToBidAppTemp
SET [Primary Customer(s)] = CustomerHierarchy.CustomerHierarchy
FROM ##tblActualsToBidAppTemp t INNER JOIN(
									SELECT * FROM (
									SELECT DISTINCT ald.CustomerHierarchy,
									ald.Lane,
									ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowNumber
									FROM ##tblAld ald
									GROUP BY ald.CustomerHierarchy,
									ald.Lane) CustomerHierarchy 
									WHERE CustomerHierarchy.RowNumber = 1
)CustomerHierarchy ON CustomerHierarchy.Lane = t.[Lane Description];

/*
Update Multistop Flag by lane
*/
UPDATE ##tblActualsToBidAppTemp
SET [Multi Stop Flag] = MultiStopFlag.MultiStopFlag
FROM ##tblActualsToBidAppTemp t INNER JOIN(
									SELECT DISTINCT MultiStop.Lane,
									MultiStop.MultiStopLoads,
									MultiStop.LoadCount,
									CAST(ROUND(CAST(MultiStop.MultiStopLoads AS NUMERIC(10,2)) / CAST(MultiStop.LoadCount AS NUMERIC(10,2)),2) AS NUMERIC(10,2)) AS MultiStopPercent,
									CASE WHEN CAST(ROUND(CAST(MultiStop.MultiStopLoads AS NUMERIC(10,2)) / CAST(MultiStop.LoadCount AS NUMERIC(10,2)),2) AS NUMERIC(10,2)) >= .4 THEN 'Y' ELSE 'N' END AS MultiStopFlag
									FROM (
													SELECT DISTINCT ald.Lane,
													SUM(CASE WHEN ald.Stops > 1 THEN 1 ELSE 0 END) AS MultiStopLoads,
													COUNT(DISTINCT ald.LD_LEG_ID) AS LoadCount
													FROM ##tblAld ald
													GROUP BY ald.Lane
													) MultiStop
)MultiStopFlag ON MultiStopFlag.Lane = t.[Lane Description];

/*
Update Intermodal Flag by lane
*/
UPDATE ##tblActualsToBidAppTemp
SET [Intermodal Flag- Y or N] = IMFlag.IMFlag
FROM ##tblActualsToBidAppTemp t INNER JOIN (
									SELECT DISTINCT Intermodal.Lane,
									Intermodal.IMLoads,
									Intermodal.LoadCount,
									CAST(ROUND(CAST(Intermodal.IMLoads AS NUMERIC(10,2)) / CAST(Intermodal.LoadCount AS NUMERIC(10,2)),2) AS NUMERIC(10,2)) AS IMPercent,
									CASE WHEN CAST(ROUND(CAST(Intermodal.IMLoads AS NUMERIC(10,2)) / CAST(Intermodal.LoadCount AS NUMERIC(10,2)),2) AS NUMERIC(10,2)) >= .5 THEN 'Y' ELSE 'N' END AS IMFlag
									FROM (
													SELECT DISTINCT ald.Lane,
													SUM(CASE WHEN ald.EQMT_TYP = '53IM' THEN 1 ELSE 0 END) AS IMLoads,
													COUNT(DISTINCT ald.LD_LEG_ID) AS LoadCount
													FROM ##tblAld ald
													GROUP BY ald.Lane
													) Intermodal
)IMFlag ON IMFlag.Lane = t.[Lane Description];

/*
Update Volume and baseline by lane
*/
UPDATE ##tblActualsToBidAppTemp
SET [Annual Volume] = volume.LoadCount * 4,
[Baseline w/o Fuel] = volume.BaselineLinehaul,
[Visibility (State)] = 'Active'
FROM ##tblActualsToBidAppTemp t INNER JOIN(
									SELECT DISTINCT ald.Lane,
									COUNT(DISTINCT ald.LD_LEG_ID) AS LoadCount,
									CAST(ROUND(AVG(ald.Act_Linehaul),2) AS NUMERIC(10,2)) AS BaselineLinehaul
									FROM ##tblAld ald
									GROUP BY ald.Lane
)volume ON volume.Lane = t.[Lane Description];


SELECT * FROM ##tblActualsToBidAppTemp ORDER BY CAST(Name AS INT) ASC


WITH ald AS (
SELECT DISTINCT ald.LD_LEG_ID,
ald.Lane,
ald.Region,
OriginGroup.OriginGroup,
ald.Origin_Zone,
ald.FRST_CTY_NAME,
ald.FRST_STA_CD,
CASE WHEN ald.FRST_CTRY_CD = 'USA' THEN LEFT(ald.FRST_PSTL_CD,5) ELSE ald.FRST_PSTL_CD END AS FRST_PSTL_CD,
ald.FRST_CTRY_CD,
ald.Dest_Zone,
ald.LAST_CTY_NAME,
ald.LAST_STA_CD,
CASE WHEN ald.LAST_CTRY_CD = 'USA' THEN LEFT(ald.LAST_PSTL_CD,5) ELSE ald.LAST_PSTL_CD END AS LAST_PSTL_CD,
ald.LAST_CTRY_CD,
ald.BU,
ald.OrderType,
CASE WHEN ald.LiveLoad IS NOT NULL THEN 'Live Load' ELSE 'Drop and Hook' END AS PrimaryUnloadType,
ald.CustomerHierarchy,
ald.STOPS,
ald.EQMT_TYP,
ald.Act_Linehaul
FROM USCTTDEV.dbo.tblActualLoadDetail ald
LEFT JOIN USCTTDEV.dbo.tblBidAppLanes bal ON bal.Lane = ald.Lane
LEFT JOIN (
SELECT DISTINCT bal.OriginGroup, bal.ORIG_CITY_STATE
FROM USCTTDEV.dbo.tblBidAppLanes bal
) OriginGroup ON originGroup.ORIG_CITY_STATE = ald.Origin_Zone
WHERE CAST(CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END AS DATE) >= GETDATE() - 30
AND bal.Lane IS NULL
AND ald.EQMT_TYP <> 'LTL'
),

lanes AS (
									SELECT * FROM (
									SELECT DISTINCT
									ald.Lane,
									ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowNumber
									FROM ald
									GROUP BY
									ald.Lane) lane 
									WHERE lane.RowNumber = 1
),

regions AS (
									SELECT * FROM (
									SELECT DISTINCT ald.Region,
									ald.Lane,
									ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowNumber
									FROM ald
									GROUP BY ald.Region,
									ald.Lane) region 
									WHERE region.RowNumber = 1
),

originGroup AS (
									SELECT * FROM (
									SELECT DISTINCT ald.OriginGroup,
									ald.Lane,
									ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowNumber
									FROM ald
									GROUP BY ald.OriginGroup,
									ald.Lane) OriginGroup 
									WHERE OriginGroup.RowNumber = 1
),

Origin_Zone AS (
									SELECT * FROM (
									SELECT DISTINCT ald.Origin_Zone,
									ald.Lane,
									ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowNumber
									FROM ald
									GROUP BY ald.Origin_Zone,
									ald.Lane) Origin_Zone 
									WHERE Origin_Zone.RowNumber = 1
),

FRST_CTY_NAME AS (
									SELECT * FROM (
									SELECT DISTINCT ald.FRST_CTY_NAME,
									ald.Lane,
									ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowNumber
									FROM ald
									GROUP BY ald.FRST_CTY_NAME,
									ald.Lane) FRST_CTY_NAME 
									WHERE FRST_CTY_NAME.RowNumber = 1
),

FRST_STA_CD AS (
									SELECT * FROM (
									SELECT DISTINCT ald.FRST_STA_CD,
									ald.Lane,
									ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowNumber
									FROM ald
									GROUP BY ald.FRST_STA_CD,
									ald.Lane) FRST_STA_CD 
									WHERE FRST_STA_CD.RowNumber = 1
),

FRST_PSTL_CD AS (
									SELECT * FROM (
									SELECT DISTINCT ald.FRST_PSTL_CD,
									ald.Lane,
									ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowNumber
									FROM ald
									GROUP BY ald.FRST_PSTL_CD,
									ald.Lane) FRST_PSTL_CD 
									WHERE FRST_PSTL_CD.RowNumber = 1
),

FRST_CTRY_CD AS (
									SELECT * FROM (
									SELECT DISTINCT ald.FRST_CTRY_CD,
									ald.Lane,
									ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowNumber
									FROM ald
									GROUP BY ald.FRST_CTRY_CD,
									ald.Lane) FRST_CTRY_CD 
									WHERE FRST_CTRY_CD.RowNumber = 1
),

Dest_Zone AS (
									SELECT * FROM (
									SELECT DISTINCT ald.Dest_Zone,
									ald.Lane,
									ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowNumber
									FROM ald
									GROUP BY ald.Dest_Zone,
									ald.Lane) Dest_Zone 
									WHERE Dest_Zone.RowNumber = 1
),

LAST_CTY_NAME AS (
									SELECT * FROM (
									SELECT DISTINCT ald.LAST_CTY_NAME,
									ald.Lane,
									ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowNumber
									FROM ald
									GROUP BY ald.LAST_CTY_NAME,
									ald.Lane) LAST_CTY_NAME 
									WHERE LAST_CTY_NAME.RowNumber = 1
),

LAST_STA_CD AS (
									SELECT * FROM (
									SELECT DISTINCT ald.LAST_STA_CD,
									ald.Lane,
									ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowNumber
									FROM ald
									GROUP BY ald.LAST_STA_CD,
									ald.Lane) LAST_STA_CD 
									WHERE LAST_STA_CD.RowNumber = 1
),

LAST_PSTL_CD AS (
									SELECT * FROM (
									SELECT DISTINCT ald.LAST_PSTL_CD,
									ald.Lane,
									ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowNumber
									FROM ald
									GROUP BY ald.LAST_PSTL_CD,
									ald.Lane) LAST_PSTL_CD 
									WHERE LAST_PSTL_CD.RowNumber = 1
),

LAST_CTRY_CD AS (
									SELECT * FROM (
									SELECT DISTINCT ald.LAST_CTRY_CD,
									ald.Lane,
									ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowNumber
									FROM ald
									GROUP BY ald.LAST_CTRY_CD,
									ald.Lane) LAST_CTRY_CD 
									WHERE LAST_CTRY_CD.RowNumber = 1
),

BU AS (
									SELECT * FROM (
									SELECT DISTINCT ald.BU,
									ald.Lane,
									ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowNumber
									FROM ald
									GROUP BY ald.BU,
									ald.Lane) BU 
									WHERE BU.RowNumber = 1
),

OrderType AS (
									SELECT * FROM (
									SELECT DISTINCT ald.OrderType,
									ald.Lane,
									ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowNumber
									FROM ald
									GROUP BY ald.OrderType,
									ald.Lane) OrderType 
									WHERE OrderType.RowNumber = 1
),

PrimaryUnloadType AS (
									SELECT * FROM (
									SELECT DISTINCT ald.PrimaryUnloadType,
									ald.Lane,
									ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowNumber
									FROM ald
									GROUP BY ald.PrimaryUnloadType,
									ald.Lane) PrimaryUnloadType 
									WHERE PrimaryUnloadType.RowNumber = 1
),

CustomerHierarchy AS (
									SELECT * FROM (
									SELECT DISTINCT ald.CustomerHierarchy,
									ald.Lane,
									ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowNumber
									FROM ald
									GROUP BY ald.CustomerHierarchy,
									ald.Lane) CustomerHierarchy 
									WHERE CustomerHierarchy.RowNumber = 1
),

MultiStop AS (
									SELECT DISTINCT MultiStop.Lane,
									MultiStop.MultiStopLoads,
									MultiStop.LoadCount,
									CAST(ROUND(CAST(MultiStop.MultiStopLoads AS NUMERIC(10,2)) / CAST(MultiStop.LoadCount AS NUMERIC(10,2)),2) AS NUMERIC(10,2)) AS MultiStopPercent,
									CASE WHEN CAST(ROUND(CAST(MultiStop.MultiStopLoads AS NUMERIC(10,2)) / CAST(MultiStop.LoadCount AS NUMERIC(10,2)),2) AS NUMERIC(10,2)) >= .4 THEN 'Y' ELSE 'N' END AS MultiStopFlag
									FROM (
													SELECT DISTINCT ald.Lane,
													SUM(CASE WHEN ald.Stops > 1 THEN 1 ELSE 0 END) AS MultiStopLoads,
													COUNT(DISTINCT ald.LD_LEG_ID) AS LoadCount
													FROM ald
													GROUP BY ald.Lane
													) MultiStop
),

Intermodal AS (
									SELECT DISTINCT Intermodal.Lane,
									Intermodal.IMLoads,
									Intermodal.LoadCount,
									CAST(ROUND(CAST(Intermodal.IMLoads AS NUMERIC(10,2)) / CAST(Intermodal.LoadCount AS NUMERIC(10,2)),2) AS NUMERIC(10,2)) AS IMPercent,
									CASE WHEN CAST(ROUND(CAST(Intermodal.IMLoads AS NUMERIC(10,2)) / CAST(Intermodal.LoadCount AS NUMERIC(10,2)),2) AS NUMERIC(10,2)) >= .5 THEN 'Y' ELSE 'N' END AS IMFlag
									FROM (
													SELECT DISTINCT ald.Lane,
													SUM(CASE WHEN ald.EQMT_TYP = '53IM' THEN 1 ELSE 0 END) AS IMLoads,
													COUNT(DISTINCT ald.LD_LEG_ID) AS LoadCount
													FROM ald
													GROUP BY ald.Lane
													) Intermodal
),

Volume AS (
									SELECT DISTINCT ald.Lane,
									COUNT(DISTINCT ald.LD_LEG_ID) AS LoadCount,
									CAST(ROUND(AVG(ald.Act_Linehaul),2) AS NUMERIC(10,2)) AS BaselineLinehaul
									FROM ald
									GROUP BY ald.Lane
)


SELECT 
ROW_NUMBER() OVER (ORDER BY lanes.Lane ASC) AS Name,
'' AS [Delete],
'Active' AS [Visibility (State)],
lanes.Lane AS [Lane Description],
regions.Region AS [Region],
originGroup.OriginGroup AS [Origin Group],
Origin_Zone.Origin_Zone AS [Origin],
FRST_CTY_NAME.FRST_CTY_NAME AS [Origin City],
FRST_STA_CD.FRST_STA_CD AS [Origin State],
FRST_PSTL_CD.FRST_PSTL_CD AS [Origin Postal Code],
FRST_CTRY_CD.FRST_CTRY_CD AS [Origin Country],
Dest_Zone.Dest_Zone AS [Destination],
LAST_CTY_NAME.LAST_CTY_NAME AS [Destination City],
LAST_STA_CD.LAST_STA_CD AS [Destination State],
LAST_PSTL_CD.LAST_PSTL_CD AS [Destination Postal Code],
LAST_CTRY_CD.LAST_CTRY_CD AS [Destination Country],
BU.BU AS [Business Unit],
OrderType.OrderType AS [Primary Lane Type],
PrimaryUnloadType.PrimaryUnloadType AS [Primary Unload Type],
CustomerHierarchy.CustomerHierarchy AS [Primary Customer(s)],
'' AS [Lane Comments],
'' AS [Miles- PC Miler 29],
Intermodal.IMFlag as [Intermodal Flag- Y or N],
'' as [Max # of Intermodal],
Volume.LoadCount * 12 AS [Annual Volume],
MultiStop.MultiStopFlag AS [Multi Stop Flag],
Volume.BaselineLinehaul AS [Baseline w/o Fuel]

FROM lanes
INNER JOIN regions ON regions.Lane = lanes.Lane
INNER JOIN originGroup ON originGroup.Lane = lanes.Lane
INNER JOIN Origin_Zone ON Origin_Zone.Lane = lanes.Lane
INNER JOIN FRST_CTY_NAME ON FRST_CTY_NAME.Lane = lanes.Lane
INNER JOIN FRST_STA_CD ON FRST_STA_CD.Lane = lanes.Lane
INNER JOIN FRST_PSTL_CD ON FRST_PSTL_CD.Lane = lanes.Lane
INNER JOIN FRST_CTRY_CD ON FRST_CTRY_CD.Lane = lanes.Lane
INNER JOIN Dest_Zone ON Dest_Zone.Lane = lanes.Lane
INNER JOIN LAST_CTY_NAME ON LAST_CTY_NAME.Lane = lanes.Lane
INNER JOIN LAST_STA_CD ON LAST_STA_CD.Lane = lanes.Lane
INNER JOIN LAST_PSTL_CD ON LAST_PSTL_CD.Lane = lanes.Lane
INNER JOIN LAST_CTRY_CD ON LAST_CTRY_CD.Lane = lanes.Lane
INNER JOIN BU ON BU.Lane = lanes.Lane
INNER JOIN OrderType ON OrderType.Lane = lanes.Lane
INNER JOIN PrimaryUnloadType ON PrimaryUnloadType.Lane = lanes.Lane
INNER JOIN CustomerHierarchy ON CustomerHierarchy.Lane = lanes.Lane
INNER JOIN MultiStop ON MultiStop.Lane = lanes.Lane
INNER JOIN Intermodal ON Intermodal.Lane = lanes.Lane
INNER JOIN Volume ON Volume.Lane = lanes.Lane

ORDER BY Name ASC
