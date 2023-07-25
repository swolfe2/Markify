USE [USCTTDEV]
GO
/****** Object:  StoredProcedure [dbo].[sp_LaneForecast]    Script Date: 5/18/2021 11:37:21 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Steve Wolfe, steve.wolfe@kcc.com, Central Transportation Team
-- Create date: 4/29/2021
-- Last modified: 5/4/2021
-- 5/4/2021 - SW - Added code to create weekly view by lane, along with award data, to USCTTDEV.dbo.tblLaneForecastWeeklyAggregate
-- Description:	Modify temp table produced by Python script, and append/update MSSQL server
-- =============================================

ALTER PROCEDURE [dbo].[sp_LaneForecast]

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
/*
Ensure that all columns exist on the table
SELECT * FROM ##tblForecastTemp
*/
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'Comments'						AND TABLE_NAME LIKE '##tblForecastTemp') ALTER TABLE ##tblForecastTemp ADD [Comments]						NVARCHAR(250) NULL	
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'ProcessedOn'					AND TABLE_NAME LIKE '##tblForecastTemp') ALTER TABLE ##tblForecastTemp ADD [ProcessedOn]					DATETIME NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'UpdatedOn'					AND TABLE_NAME LIKE '##tblForecastTemp') ALTER TABLE ##tblForecastTemp ADD [UpdatedOn]					DATETIME NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'AddedOn'						AND TABLE_NAME LIKE '##tblForecastTemp') ALTER TABLE ##tblForecastTemp ADD [AddedOn]						DATETIME NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'FRST_SHPG_LOC_CD'	AND TABLE_NAME LIKE '##tblForecastTemp') ALTER TABLE ##tblForecastTemp ADD [FRST_SHPG_LOC_CD]	NVARCHAR(30) NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'FRST_PSTL_CD'				AND TABLE_NAME LIKE '##tblForecastTemp') ALTER TABLE ##tblForecastTemp ADD [FRST_PSTL_CD]				NVARCHAR(30) NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'LAST_SHPG_LOC_CD'	AND TABLE_NAME LIKE '##tblForecastTemp') ALTER TABLE ##tblForecastTemp ADD [LAST_SHPG_LOC_CD]	NVARCHAR(30) NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'Lane'									AND TABLE_NAME LIKE '##tblForecastTemp') ALTER TABLE ##tblForecastTemp ADD [Lane]								NVARCHAR(30) NULL

/*
Delete forecast rows if SnapshotWeek or SendingWeek is null
*/
DELETE FROM ##tblForecastTemp
WHERE SnapshotWeek IS NULL
OR SendingWeek IS NULL;

/*
Delete any PU ShipCondition because pickup doesn't matter
*/
DELETE FROM ##tblForecastTemp
WHERE ShipCondition = 'PU'

/*
Try to get Destination Zone by customer location if it's null in the base data
*/
UPDATE ##tblForecastTemp
SET DestinationZone = ald.Dest_Zone,
Comments = '1 - DestinationZone previously null in upload data. Updated from tblActualLoadDetail by LAST_SHPG_LOC_CD'
FROM ##tblForecastTemp ft
INNER JOIN USCTTDEV.dbo.tblActualLoadDetail ald ON LEFT(ald.LAST_SHPG_LOC_CD,8) = ft.FCSTIntCust4 AND RIGHT(ald.LAST_SHPG_LOC_CD,8) = ft.FCSTShiptoCust
WHERE ft.DestinationZone IS NULL

/*
Update Destination Zone to match ald if it's null in the base data
*/
UPDATE ##tblForecastTemp
SET DestinationZone = ald.Dest_Zone,
Comments = '2 - DestinationZone previously null in upload data. Updated from tblActualLoadDetail by Dest Zip where the most loads have been shipped.'
FROM ##tblForecastTemp ft
INNER JOIN (SELECT DISTINCT CASE WHEN ald.LAST_CTRY_CD = 'USA' THEN LEFT(ald.LAST_PSTL_CD,5) ELSE LEFT(ald.LAST_PSTL_CD,3) END AS DestZip,
ald.Dest_Zone,
COUNT(DISTINCT ald.LD_LEG_ID) AS LoadCount,
ROW_NUMBER() OVER (PARTITION BY CASE WHEN ald.LAST_CTRY_CD = 'USA' THEN LEFT(ald.LAST_PSTL_CD,5) ELSE LEFT(ald.LAST_PSTL_CD,3) END ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowRank
FROM USCTTDEV.dbo.tblActualLoadDetail ald
WHERE ald.EQMT_TYP <> 'LTL'
GROUP BY  CASE WHEN ald.LAST_CTRY_CD = 'USA' THEN LEFT(ald.LAST_PSTL_CD,5) ELSE LEFT(ald.LAST_PSTL_CD,3) END,
ald.Dest_Zone) ald ON ald.DestZip = ft.DestinationPostalCode
WHERE ft.DestinationZone IS NULL
AND ald.RowRank = 1

/*
Update Destination Zone to match Bid App Lanes if it's null in the base data
*/
UPDATE ##tblForecastTemp
SET DestinationZone = bal.DEST_CITY_STATE,
Comments = '3 - DestinationZone previously null in upload data. Updated from tblBIdAppLanes.'
FROM ##tblForecastTemp ft
INNER JOIN (SELECT DISTINCT bal.DEST_CITY_STATE,
CASE WHEN bal.DestCountry = 'USA' THEN bal.DestZip ELSE LEFT(bal.DestZip,3) END AS DestZip
FROM USCTTDEV.dbo.tblBidAppLanes bal) bal ON bal.DestZip = ft.DestinationPostalCode
WHERE ft.DestinationZone IS NULL

/*
Update Destination Zone to match JDA/TMS table if it's null in the base data
*/
DROP TABLE IF EXISTS ##tblDestZipsTemp

/*
Create temp table of JDA/TMS state/zips
*/
SELECT * INTO ##tblDestZipsTemp 
FROM OPENQUERY(NAJDAPRD,'
SELECT DISTINCT lat.DEST_ZN_CD,
SUBSTR(lat.DEST_ZN_CD,-5) AS DestZip
FROM NAJDAADM.LANE_ASSC_T lat
WHERE lat.DEST_CTRY_CD = ''USA''
') data

/*
Update Destination Zone to match JDA/TMS table if it's null in the base data
*/
UPDATE ##tblForecastTemp
SET DestinationZone = dzt.DEST_ZN_CD,
Comments = '4 - DestinationZone previously null in upload data. Updated from the NAJDAADM.LANE_ASSC_T table in JDA/TMS.'
FROM ##tblForecastTemp ft
INNER JOIN ##tblDestZipsTemp dzt ON dzt.DestZip = ft.DestinationPostalCode
WHERE ft.DestinationZone IS NULL

/*
Update Destination Zone to match the Zip Code table if it's null in the base data
SELECT TOP 10 * FROM USCTTDEV.dbo.tblZipCodes W
SELECT * FROM ##tblForecastTemp WHERE DestinationZone IS NULL
*/
UPDATE ##tblForecastTemp
SET DestinationZone = '5'+zc.StateAbbv+LEFT(ft.DestinationPostalCode,5),
Comments = '5 - DestinationZone previously null in upload data. Updated from tblZipCodes.'
FROM ##tblForecastTemp ft
INNER JOIN USCTTDEV.dbo.tblZipCodes zc ON zc.PostalCode = ft.DestinationPostalCode
WHERE ft.DestinationZone IS NULL
AND zc.CountryCode = 'US'

/*
Update Destination Zone to match Destination Campus if null in the base data
SELECT TOP 10 * FROM USCTTDEV.dbo.tblZipCodes W
SELECT * FROM ##tblForecastTemp WHERE DestinationZone IS NULL
*/
UPDATE ##tblForecastTemp
SET DestinationZone = im.Dest_Zone,
Comments = '6 - DestinationZone previously null in upload data. Updated from Actual Load Detail where the plant matches.'
FROM ##tblForecastTemp ft
INNER JOIN (
SELECT DISTINCT LEFT(ald.DestinationPlant,4) AS DestinationPlant,
ald.Dest_Zone,
COUNT(DISTINCT ald.LD_LEG_ID) AS LoadCount,
ROW_NUMBER() OVER (PARTITION BY LEFT(ald.DestinationPlant,4) ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RankNum
FROM USCTTDEV.dbo.tblActualLoadDetail ald
WHERE ald.DestinationPlant LIKE '2%'
AND CAST(ald.SHPD_DTT AS DATE) >= CAST(GETDATE() - 90 AS DATE)
GROUP BY LEFT(ald.DestinationPlant,4),
ald.Dest_Zone) im ON im.DestinationPlant = ft.DestinationPlant
WHERE ft.DestinationZone IS NULL
AND ft.FCSTIntCust4 LIKE '%Intermill%'
AND im.RankNum = 1

/*
Update the NA-Intermill string to actually mean something, based on the highest shipment count in the past 90 days
SELECT * FROM ##tblForecastTemp WHERE Type = 'Intermill'
*/
UPDATE ##tblForecastTemp
SET FCSTIntCust4 = aldInt.LAST_SHPG_LOC_CD,
FCSTIntCust4Txt = aldInt.LAST_SHPG_LOC_NAME,
FCSTShipToCust = aldInt.LAST_SHPG_LOC_CD,
FCSTShipToCustTxt = aldInt.LAST_SHPG_LOC_NAME
FROM ##tblForecastTemp ft
INNER JOIN (
SELECT DISTINCT 
LEFT(ald.LAST_SHPG_LOC_CD,8) AS ShipTo,
RIGHT(ald.LAST_SHPG_LOC_CD,8) AS ShipToIndiv,
ald.LAST_SHPG_LOC_CD,
ald.LAST_SHPG_LOC_NAME,
ald.DestinationPlant,
LEFT(ald.DestinationPlant,4) AS DestPlant,
COUNT(DISTINCT ald.LD_LEG_ID) AS LoadCount,
ROW_NUMBER() OVER (PARTITION BY LEFT(ald.DestinationPlant,4) ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowRank
FROM USCTTDEV.dbo.tblActualLoadDetail ald
WHERE LEFT(ald.LAST_SHPG_LOC_CD, 1) NOT IN ('5','V')
AND ald.EQMT_TYP <> 'LTL'
AND ald.LAST_SHPG_LOC_CD <> '99999999'
AND CAST(CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END AS DATE) >= CAST(GETDATE() - 90 AS DATE)
GROUP BY LEFT(ald.LAST_SHPG_LOC_CD,8),
RIGHT(ald.LAST_SHPG_LOC_CD,8),
ald.LAST_SHPG_LOC_CD,
ald.LAST_SHPG_LOC_NAME,
ald.DestinationPlant,
LEFT(ald.DestinationPlant,4)
)aldInt ON aldInt.DestPlant = ft.DestinationPlant
AND aldInt.RowRank = 1
WHERE ft.FCSTIntCust4 = 'NA - Intermill'
OR ft.Type = 'Intermill'

/*
Update FRST_SHPG_LOC_CD by Origin Campus first, then Origin Plant second
*/
UPDATE ##tblForecastTemp
SET FRST_SHPG_LOC_CD = orig.FRST_SHPG_LOC_CD,
FRST_PSTL_CD = orig.FRST_PSTL_CD
FROM ##tblForecastTemp ft
INNER JOIN (
SELECT DISTINCT ald.Origin_Zone,
ald.OriginPlant,
ald.FRST_SHPG_LOC_CD,
ald.FRST_PSTL_CD,
LEFT(ald.FRST_SHPG_LOC_CD,4) AS OriginPlantFour,
COUNT(DISTINCT ald.LD_LEG_ID) AS LoadCount,
ROW_NUMBER() OVER (PARTITION BY ald.OriginPlant ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowRank
FROM USCTTDEV.dbo.tblActualLoadDetail ald
WHERE LEFT(ald.FRST_SHPG_LOC_CD, 1) NOT IN ('5','V')
AND ald.EQMT_TYP <> 'LTL'
AND CAST(CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END AS DATE) >= CAST(GETDATE() - 90 AS DATE)
GROUP BY ald.Origin_Zone,
ald.OriginPlant,
ald.FRST_SHPG_LOC_CD,
ald.FRST_PSTL_CD
) orig ON orig.OriginPlantFour = ft.OriginCampus
AND orig.Origin_Zone = ft.OriginZone
AND orig.RowRank = 1
AND ft.FRST_SHPG_LOC_CD IS NULL

/*
Update FRST_SHPG_LOC_CD by then Origin Plant second
*/
UPDATE ##tblForecastTemp
SET FRST_SHPG_LOC_CD = orig.FRST_SHPG_LOC_CD,
FRST_PSTL_CD = orig.FRST_PSTL_CD
FROM ##tblForecastTemp ft
INNER JOIN (
SELECT DISTINCT ald.Origin_Zone,
ald.OriginPlant,
ald.FRST_SHPG_LOC_CD,
ald.FRST_PSTL_CD,
LEFT(ald.FRST_SHPG_LOC_CD,4) AS OriginPlantFour,
COUNT(DISTINCT ald.LD_LEG_ID) AS LoadCount,
ROW_NUMBER() OVER (PARTITION BY ald.OriginPlant ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowRank
FROM USCTTDEV.dbo.tblActualLoadDetail ald
WHERE LEFT(ald.FRST_SHPG_LOC_CD, 1) NOT IN ('5','V')
AND ald.EQMT_TYP <> 'LTL'
AND CAST(CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END AS DATE) >= CAST(GETDATE() - 90 AS DATE)
GROUP BY ald.Origin_Zone,
ald.OriginPlant,
ald.FRST_SHPG_LOC_CD,
ald.FRST_PSTL_CD
) orig ON orig.OriginPlantFour = ft.OriginPlant
AND orig.Origin_Zone = ft.OriginZone
AND orig.RowRank = 1
AND ft.FRST_SHPG_LOC_CD IS NULL

/*
Update LAST_SHPG_LOC_CD when it is a customer delivery
*/
UPDATE ##tblForecastTemp
SET LAST_SHPG_LOC_CD = FCSTIntCust4 + FCSTShiptoCust
WHERE LEFT(FCSTIntCust4,1) = '5'
AND LAST_SHPG_LOC_CD IS NULL

/*
Update LAST_SHPG_LOC_CD by Dest Campus first, then Dest Plant second
*/
UPDATE ##tblForecastTemp
SET LAST_SHPG_LOC_CD = orig.LAST_SHPG_LOC_CD
FROM ##tblForecastTemp ft
INNER JOIN (
SELECT DISTINCT ald.Dest_Zone,
ald.DestinationPlant,
ald.LAST_SHPG_LOC_CD,
LEFT(ald.LAST_SHPG_LOC_CD,4) AS DestPlantFour,
COUNT(DISTINCT ald.LD_LEG_ID) AS LoadCount,
ROW_NUMBER() OVER (PARTITION BY ald.DestinationPlant ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowRank
FROM USCTTDEV.dbo.tblActualLoadDetail ald
WHERE ald.EQMT_TYP <> 'LTL'
AND CAST(CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END AS DATE) >= CAST(GETDATE() - 90 AS DATE)
GROUP BY ald.Dest_Zone,
ald.DestinationPlant,
ald.LAST_SHPG_LOC_CD
) orig ON orig.DestPlantFour = ft.DestinationCampus
AND orig.Dest_Zone = ft.DestinationZone
AND orig.RowRank = 1
AND ft.LAST_SHPG_LOC_CD IS NULL

/*
Update LAST_SHPG_LOC_CD by then Dest Plant second
*/
UPDATE ##tblForecastTemp
SET LAST_SHPG_LOC_CD = orig.LAST_SHPG_LOC_CD
FROM ##tblForecastTemp ft
INNER JOIN (
SELECT DISTINCT ald.Dest_Zone,
ald.DestinationPlant,
ald.LAST_SHPG_LOC_CD,
LEFT(ald.LAST_SHPG_LOC_CD,4) AS DestPlantFour,
COUNT(DISTINCT ald.LD_LEG_ID) AS LoadCount,
ROW_NUMBER() OVER (PARTITION BY ald.DestinationPlant ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowRank
FROM USCTTDEV.dbo.tblActualLoadDetail ald
WHERE ald.EQMT_TYP <> 'LTL'
AND CAST(CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END AS DATE) >= CAST(GETDATE() - 90 AS DATE)
GROUP BY ald.Dest_Zone,
ald.DestinationPlant,
ald.LAST_SHPG_LOC_CD
) orig ON orig.DestPlantFour = ft.DestinationPlant
AND orig.Dest_Zone = ft.DestinationZone
AND orig.RowRank = 1
AND ft.LAST_SHPG_LOC_CD IS NULL

/*
Update Lane where Origin Zone and Destination Zone are both not null
*/
UPDATE ##tblForecastTemp
SET Lane = OriginZone + '-' + DestinationZone
WHERE Lane IS NULL
AND OriginZone IS NOT NULL
AND DestinationZone IS NOT NULL

/*
Set final date/times for Processed/Updated/Added
SELECT * FROM ##tblForecastTemp
*/
UPDATE ##tblForecastTemp
SET ProcessedOn = GETDATE(),
UpdatedOn = GETDATE(),
AddedOn = GETDATE()

/*
Set current date/time
*/
DECLARE @today DATETIME
SET @today = GETDATE()

/*
Add new rows that are in the raw data which aren't on the table now
*/
INSERT INTO USCTTDEV.dbo.tblLaneForecastWeekly (AddedOn, UpdatedOn, SnapshotWeek, SendingWeek, OriginPlant, OriginCampus, OriginZone, FRST_SHPG_LOC_CD, FRST_PSTL_CD, DestinationPlant, 
DestinationCampus, DestinationZone, LAST_SHPG_LOC_CD, DestinationPostalCode, Lane, FCSTIntCust4, FCSTIntCust4TXT, FCSTShiptoCust, FCSTShiptoCustTXT, Type, ShipCondition, FCSTTL, WeeklyAward, Comments)
SELECT @today, @today, ft.SnapshotWeek, ft.SendingWeek, ft.OriginPlant, ft.OriginCampus, ft.OriginZone, ft.FRST_SHPG_LOC_CD, ft.FRST_PSTL_CD, ft.DestinationPlant, ft.DestinationCampus, ft.DestinationZone, 
ft.LAST_SHPG_LOC_CD, ft.DestinationPostalCode, ft.Lane, ft.FCSTIntCust4, ft.FCSTIntCust4TXT, ft.FCSTShiptoCust, ft.FCSTShiptoCustTXT, ft.Type, ft.ShipCondition, ft.FCSTTL, ft.WeeklyAward, ft.Comments
FROM ##tblForecastTemp ft
LEFT JOIN USCTTDEV.dbo.tblLaneForecastWeekly lfw ON lfw.SnapshotWeek = ft.SnapshotWeek
AND lfw.SendingWeek = ft.SendingWeek
AND lfw.OriginPlant = ft.OriginPlant
/*AND lfw.OriginCampus = ft.OriginCampus
AND lfw.DestinationZone = ft.DestinationZone
AND lfw.FCSTIntCust4 = ft.FCSTIntCust4*/
AND lfw.FCSTIntCust4TXT = ft.FCSTIntCust4TXT
AND lfw.Type = ft.Type
AND lfw.ShipCondition = ft.ShipCondition
WHERE 
lfw.SnapshotWeek IS NULL
AND lfw.OriginPlant IS NULL
/*AND lfw.OriginCampus IS NULL*/
/*AND lfw.DestinationZone IS NULL*/
/*AND lfw.FCSTIntCust4TXT IS NULL*/
AND lfw.Type IS NULL
AND lfw.ShipCondition IS NULL
ORDER BY ft.OriginZone ASC, CAST(ft.SnapshotWeek AS DATE) ASC, CAST(ft.SendingWeek AS DATE) ASC, ft.DestinationZone ASC, ft.LAST_SHPG_LOC_CD ASC

/*
Update all existing rows which match raw data, in case values have been updated
*/
UPDATE USCTTDEV.dbo.tblLaneForecastWeekly
SET AddedOn = @today,
UpdatedOn = @today,
SnapshotWeek = ft.SnapshotWeek,
OriginPlant = ft.OriginPlant,
OriginCampus = ft.OriginCampus,
OriginZone = ft.OriginZone,
FRST_SHPG_LOC_CD = ft.FRST_SHPG_LOC_CD,
FRST_PSTL_CD = ft.FRST_PSTL_CD,
DestinationPlant = ft.DestinationPlant,
DestinationCampus = ft.DestinationCampus,
DestinationZone = ft.DestinationZone,
LAST_SHPG_LOC_CD = ft.LAST_SHPG_LOC_CD,
DestinationPostalCode = ft.DestinationPostalCode,
Lane = ft.Lane,
FCSTIntCust4 = ft.FCSTIntCust4,
FCSTIntCust4TXT = ft.FCSTIntCust4TXT,
FCSTShiptoCust = ft.FCSTShiptoCust,
FCSTShiptoCustTXT = ft.FCSTShiptoCustTXT,
Type = ft.Type,
ShipCondition = ft.ShipCondition,
FCSTTL = ft.FCSTTL,
WeeklyAward = ft.WeeklyAward,
Comments = ft.Comments
FROM USCTTDEV.dbo.tblLaneForecastWeekly lfw
INNER JOIN ##tblForecastTemp ft ON lfw.SnapshotWeek = ft.SnapshotWeek
AND lfw.SendingWeek = ft.SendingWeek
AND lfw.OriginPlant = ft.OriginPlant
/*AND lfw.OriginCampus = ft.OriginCampus
AND lfw.DestinationZone = ft.DestinationZone
AND lfw.FCSTIntCust4 = ft.FCSTIntCust4*/
AND lfw.FCSTIntCust4TXT = ft.FCSTIntCust4TXT
AND lfw.Type = ft.Type
AND lfw.ShipCondition = ft.ShipCondition

/*
Drop table if it already exists
*/
DROP TABLE IF EXISTS ##tblLaneForecastWeeklyAggregate

/*
Create temporary table with weekly aggregate lane forecasts and lane award information
*/
SELECT DISTINCT 
lfw.SnapshotWeek,
lfw.SendingWeek,
lfw.OriginZone,
lfw.DestinationZone,
lfw.OriginZone + '-' + lfw.DestinationZone AS Lane,
SUM(CASE WHEN lfw.Type = 'Intermill' THEN lfw.FCSTTL END) AS IntermillShipments,
SUM(CASE WHEN lfw.Type = 'Customer - KCP' THEN lfw.FCSTTL END) AS KCPShipments,
SUM(CASE WHEN lfw.Type = 'Customer - Consumer' THEN lfw.FCSTTL END) AS ConsumerShipments,
SUM(CASE WHEN lfw.Type NOT IN ('Intermill','Customer - KCP', 'Customer - Consumer') THEN FCSTTL END) AS OtherShipments,
SUM(CASE WHEN lfw.ShipCondition = 'TL' THEN lfw.FCSTTL END) AS TLShipments,
SUM(CASE WHEN lfw.ShipCondition = 'TF' THEN lfw.FCSTTL END) AS TFShipments,
SUM(FCSTTL) AS TotalForecastShipments,
CASE WHEN awards.AwardPercent IS NULL THEN futureAwards.AwardPercent ELSE awards.AwardPercent END AS AwardPercent,
CAST(CASE WHEN ROUND(CASE WHEN awards.AwardLoads IS NULL THEN futureAwards.AwardLoads ELSE awards.AwardLoads END / 52,0) <1 THEN 1 ELSE ROUND(CASE WHEN awards.AwardLoads IS NULL THEN futureAwards.AwardLoads ELSE awards.AwardLoads END / 52,0) END AS INT) AS BaseWeeklyAward,
CAST(CASE WHEN ROUND((CASE WHEN awards.AwardLoads IS NULL THEN futureAwards.AwardLoads ELSE awards.AwardLoads END * 1.15) / 52,0) <1 THEN 1 ELSE ROUND(CASE WHEN awards.AwardLoads IS NULL THEN futureAwards.AwardLoads ELSE awards.AwardLoads END * 1.15 / 52,0) END AS INT) AS SurgeWeeklyAward,
CASE WHEN awards.IMAwardPercent IS NULL THEN futureAwards.IMAwardPercent ELSE awards.IMAwardPercent END AS IMAwardPercent,
CAST(CASE WHEN awards.IMAwardLoads IS NULL THEN futureAwards.IMAwardLoads ELSE awards.IMAwardPercent END AS INT) AS IMAwardLoads,
CAST(CASE WHEN ROUND(CASE WHEN awards.IMAwardLoads IS NULL THEN futureAwards.IMAwardLoads ELSE awards.IMAwardPercent END / 52,0) <1 THEN 1 ELSE ROUND(CASE WHEN awards.IMAwardLoads IS NULL THEN futureAwards.IMAwardLoads ELSE awards.IMAwardPercent END / 52,0) END AS INT) AS BaseIMWeeklyAward,
CAST(CASE WHEN ROUND((CASE WHEN awards.IMAwardLoads IS NULL THEN futureAwards.IMAwardLoads ELSE awards.IMAwardPercent END * 1.15) / 52,0) <1 THEN 1 ELSE ROUND(CASE WHEN awards.IMAwardLoads IS NULL THEN futureAwards.IMAwardLoads ELSE awards.IMAwardPercent END * 1.15 / 52,0) END AS INT) AS SurgeIMWeeklyAward,
CASE WHEN awards.TLAwardPercent IS NULL THEN futureAwards.TLAwardPercent ELSE awards.TLAwardPercent END AS TLAwardPercent,
CAST(CASE WHEN awards.TLAwardLoads IS NULL THEN futureAwards.TLAwardLoads ELSE awards.TLAwardLoads END AS INT) AS TLAwardLoads,
CAST(CASE WHEN ROUND(CASE WHEN awards.TLAwardLoads IS NULL THEN futureAwards.TLAwardLoads ELSE awards.TLAwardLoads END / 52,0) <1 THEN 1 ELSE ROUND(CASE WHEN awards.TLAwardLoads IS NULL THEN futureAwards.TLAwardLoads ELSE awards.TLAwardLoads END / 52,0) END AS INT) AS BaseTLWeeklyAward,
CAST(CASE WHEN ROUND((CASE WHEN awards.TLAwardLoads IS NULL THEN futureAwards.TLAwardLoads ELSE awards.TLAwardLoads END * 1.15) / 52,0) <1 THEN 1 ELSE ROUND(CASE WHEN awards.TLAwardLoads IS NULL THEN futureAwards.TLAwardLoads ELSE awards.TLAwardLoads END * 1.15 / 52,0) END AS INT) AS SurgeTLWeeklyAward

INTO ##tblLaneForecastWeeklyAggregate

FROM USCTTDEV.dbo.tblLaneForecastWeekly lfw
LEFT JOIN (
SELECT DISTINCT 
barwa.WeekStartDate,
barwa.ORIG_CITY_STATE + '-' + barwa.DEST_CITY_STATE AS Lane,
AVG(UPDATED_LOADS) AS LaneLoads,
SUM(barwa.AWARD_PCT) AS AwardPercent,
CAST(ROUND(AVG(UPDATED_LOADS) * SUM(CAST(barwa.AWARD_PCT AS NUMERIC(10,2))), 0) AS INT) AS AwardLoads,
COUNT(DISTINCT barwa.SCAC) AS AwardCarrierCount,
SUM(CASE WHEN barwa.EQUIPMENT = '53IM' THEN barwa.AWARD_PCT END) AS IMAwardPercent,
CAST(ROUND(AVG(UPDATED_LOADS) * SUM(CASE WHEN barwa.EQUIPMENT = '53IM' THEN barwa.AWARD_PCT END), 0) AS INT) AS IMAwardLoads,
SUM(CASE WHEN barwa.EQUIPMENT <> '53IM' THEN barwa.AWARD_PCT END) AS TLAwardPercent,
CASE WHEN (
CAST(ROUND(AVG(UPDATED_LOADS) * SUM(CAST(barwa.AWARD_PCT AS NUMERIC(10,2))), 0) AS INT) -
COALESCE(CAST(ROUND(AVG(UPDATED_LOADS) * SUM(CASE WHEN barwa.EQUIPMENT = '53IM' THEN barwa.AWARD_PCT END), 0) AS INT),0)) > 0 THEN 
CAST(ROUND(AVG(UPDATED_LOADS) * SUM(CAST(barwa.AWARD_PCT AS NUMERIC(10,2))), 0) AS INT) -
COALESCE(CAST(ROUND(AVG(UPDATED_LOADS) * SUM(CASE WHEN barwa.EQUIPMENT = '53IM' THEN barwa.AWARD_PCT END), 0) AS INT),0) 
ELSE Null END AS TLAwardLoads
FROM USCTTDEV.dbo.tblBidAppRatesWeeklyAwards barwa
GROUP BY barwa.WeekStartDate,
barwa.ORIG_CITY_STATE + '-' + barwa.DEST_CITY_STATE
) awards ON awards.WeekStartDate = lfw.SendingWeek
AND awards.Lane = lfw.OriginZone + '-' + lfw.DestinationZone

LEFT JOIN (
SELECT DISTINCT 
barwa.WeekStartDate,
barwa.ORIG_CITY_STATE + '-' + barwa.DEST_CITY_STATE AS Lane,
AVG(UPDATED_LOADS) AS LaneLoads,
SUM(barwa.AWARD_PCT) AS AwardPercent,
CAST(ROUND(AVG(UPDATED_LOADS) * SUM(CAST(barwa.AWARD_PCT AS NUMERIC(10,2))), 0) AS INT) AS AwardLoads,
COUNT(DISTINCT barwa.SCAC) AS AwardCarrierCount,
SUM(CASE WHEN barwa.EQUIPMENT = '53IM' THEN barwa.AWARD_PCT END) AS IMAwardPercent,
CAST(ROUND(AVG(UPDATED_LOADS) * SUM(CASE WHEN barwa.EQUIPMENT = '53IM' THEN barwa.AWARD_PCT END), 0) AS INT) AS IMAwardLoads,
SUM(CASE WHEN barwa.EQUIPMENT <> '53IM' THEN barwa.AWARD_PCT END) AS TLAwardPercent,
CASE WHEN (
CAST(ROUND(AVG(UPDATED_LOADS) * SUM(CAST(barwa.AWARD_PCT AS NUMERIC(10,2))), 0) AS INT) -
COALESCE(CAST(ROUND(AVG(UPDATED_LOADS) * SUM(CASE WHEN barwa.EQUIPMENT = '53IM' THEN barwa.AWARD_PCT END), 0) AS INT),0)) > 0 THEN 
CAST(ROUND(AVG(UPDATED_LOADS) * SUM(CAST(barwa.AWARD_PCT AS NUMERIC(10,2))), 0) AS INT) -
COALESCE(CAST(ROUND(AVG(UPDATED_LOADS) * SUM(CASE WHEN barwa.EQUIPMENT = '53IM' THEN barwa.AWARD_PCT END), 0) AS INT),0) 
ELSE Null END AS TLAwardLoads

FROM USCTTDEV.dbo.tblBidAppRatesWeeklyAwards barwa
WHERE barwa.WeekStartDate = CAST(DATEADD(wk, DATEDIFF(wk,0,GETDATE()), 0) AS DATE)
GROUP BY barwa.WeekStartDate,
barwa.ORIG_CITY_STATE + '-' + barwa.DEST_CITY_STATE
) futureAwards ON futureawards.Lane = lfw.OriginZone + '-' + lfw.DestinationZone
GROUP BY lfw.SnapshotWeek,
lfw.SendingWeek,
lfw.OriginZone,
lfw.DestinationZone,
CASE WHEN awards.AwardPercent IS NULL THEN futureAwards.AwardPercent ELSE awards.AwardPercent END,
awards.AwardLoads,
futureAwards.AwardLoads,
futureAwards.IMAwardLoads,
CASE WHEN awards.IMAwardPercent IS NULL THEN futureAwards.IMAwardPercent ELSE awards.IMAwardPercent END,
CASE WHEN awards.IMAwardLoads IS NULL THEN futureAwards.IMAwardLoads ELSE awards.IMAwardPercent END,
CASE WHEN awards.TLAwardPercent IS NULL THEN futureAwards.TLAwardPercent ELSE awards.TLAwardPercent END,
CASE WHEN awards.TLAwardLoads IS NULL THEN futureAwards.TLAwardLoads ELSE awards.TLAwardLoads END

ORDER BY lfw.SnapshotWeek ASC, lfw.OriginZone ASC, lfw.DestinationZone ASC, lfw.SendingWeek ASC

/*
Add to weekly aggregate table if it doesn't already exist
*/
INSERT INTO USCTTDEV.dbo.tblLaneForecastWeeklyAggregate (
AddedOn
,LastUpdated
,SnapshotWeek
,SendingWeek
,OriginZone
,DestinationZone
,Lane
,IntermillShipments
,KCPShipments
,ConsumerShipments
,OtherShipments
,TLShipments
,TFShipments
,TotalForecastShipments
,AwardPercent
,BaseWeeklyAward
,SurgeWeeklyAward
,IMAwardPercent
,IMAwardLoads
,BaseIMWeeklyAward
,SurgeIMWeeklyAward
,TLAwardPercent
,TLAwardLoads
,BaseTLWeeklyAward
,SurgeTLWeeklyAward)

SELECT 
@today,
@today,
lfwat.SnapshotWeek
,lfwat.SendingWeek
,lfwat.OriginZone
,lfwat.DestinationZone
,lfwat.Lane
,lfwat.IntermillShipments
,lfwat.KCPShipments
,lfwat.ConsumerShipments
,lfwat.OtherShipments
,lfwat.TLShipments
,lfwat.TFShipments
,lfwat.TotalForecastShipments
,lfwat.AwardPercent
,lfwat.BaseWeeklyAward
,lfwat.SurgeWeeklyAward
,lfwat.IMAwardPercent
,lfwat.IMAwardLoads
,lfwat.BaseIMWeeklyAward
,lfwat.SurgeIMWeeklyAward
,lfwat.TLAwardPercent
,lfwat.TLAwardLoads
,lfwat.BaseTLWeeklyAward
,lfwat.SurgeTLWeeklyAward 
FROM ##tblLaneForecastWeeklyAggregate lfwat
LEFT JOIN USCTTDEV.dbo.tblLaneForecastWeeklyAggregate lfwa ON lfwa.SnapshotWeek = lfwat.SnapshotWeek
AND lfwa.SendingWeek = lfwat.SendingWeek
AND CASE WHEN lfwa.OriginZone IS NULL THEN 'UNKNOWN' ELSE lfwa.OriginZone END = CASE WHEN lfwat.OriginZone IS NULL THEN 'UNKNOWN' ELSE lfwat.OriginZone END
AND CASE WHEN lfwa.DestinationZone IS NULL THEN 'UNKNOWN' ELSE lfwa.DestinationZone END = CASE WHEN lfwat.DestinationZone IS NULL THEN 'UNKNOWN' ELSE lfwat.DestinationZone END
WHERE (lfwa.OriginZone IS NULL
AND lfwa.DestinationZone IS NULL)
ORDER BY lfwat.SnapshotWeek ASC, lfwat.OriginZone ASC, lfwat.DestinationZone ASC, lfwat.SendingWeek ASC

/*
Update weekly aggregate table if it does exist
*/
UPDATE USCTTDEV.dbo.tblLaneForecastWeeklyAggregate
SET 
AddedOn = @today
,LastUpdated = @today
,SnapshotWeek = lfwat.SnapshotWeek
,SendingWeek  = lfwat.SendingWeek
,OriginZone = lfwat.OriginZone
,DestinationZone = lfwat.DestinationZone
,Lane = lfwat.Lane
,IntermillShipments = lfwat.IntermillShipments
,KCPShipments = lfwat.KCPShipments
,ConsumerShipments = lfwat.ConsumerShipments
,OtherShipments = lfwat.OtherShipments
,TLShipments = lfwat.TLShipments
,TFShipments = lfwat.TFShipments
,TotalForecastShipments = lfwat.TotalForecastShipments
,AwardPercent = lfwat.AwardPercent
,BaseWeeklyAward = lfwat.BaseWeeklyAward
,SurgeWeeklyAward = lfwat.SurgeWeeklyAward
,IMAwardPercent = lfwat.IMAwardPercent
,IMAwardLoads = lfwat.IMAwardLoads
,BaseIMWeeklyAward = lfwat.BaseIMWeeklyAward
,SurgeIMWeeklyAward = lfwat.SurgeIMWeeklyAward
,TLAwardPercent = lfwat.TLAwardPercent
,TLAwardLoads = lfwat.TLAwardLoads
,BaseTLWeeklyAward = lfwat.BaseTLWeeklyAward
,SurgeTLWeeklyAward = lfwat.SurgeTLWeeklyAward
FROM USCTTDEV.dbo.tblLaneForecastWeeklyAggregate lfwa
INNER JOIN ##tblLaneForecastWeeklyAggregate lfwat ON lfwat.SnapshotWeek = lfwa.SnapshotWeek
AND lfwat.SendingWeek = lfwa.SendingWeek
AND CASE WHEN lfwat.OriginZone IS NULL THEN 'UNKNOWN' ELSE lfwat.OriginZone END = CASE WHEN lfwa.OriginZone IS NULL THEN 'UNKNOWN' ELSE lfwa.OriginZone END
AND CASE WHEN lfwat.DestinationZone IS NULL THEN 'UNKNOWN' ELSE lfwat.DestinationZone END = CASE WHEN lfwa.DestinationZone IS NULL THEN 'UNKNOWN' ELSE lfwa.DestinationZone END

/*
Make sure temp tables are gone
*/
DROP TABLE IF EXISTS ##tblForecastTemp,
##tblLaneForecastWeeklyAggregate

END