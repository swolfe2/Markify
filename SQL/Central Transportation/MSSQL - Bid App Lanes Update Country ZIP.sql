USE [USCTTDEV]
GO
/****** Object:  StoredProcedure [dbo].[sp_BidAppLanesUpdateCountryZip]    Script Date: 1/17/2020 11:49:20 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Steve Wolfe, steve.wolfe@kcc.com, Central Transportation Team
-- Create date: 1/8/2020
-- Last modified: 1/14/2020

-- 1/14/2020 - SW - Added query to update Bid App Lanes to match UpdatedCityName from dbo_tblZoneCities

-- Description:	Update USCTTDEV.dbo.tblBidAppLanes where country / zips are missing
-- =============================================

ALTER PROCEDURE [dbo].[sp_BidAppLanesUpdateCountryZip]

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

/*
What is this file doing?

1) Create some temp tables for origin/destination details where they're not null
2) Update USCTTDEV.dbo.tblBidAppLanes where null from temp table details

TODO: 

*/

/*
Delete Temp tables, if exists
*/
DROP TABLE IF EXISTS 
##tblOrigins,
##tblDestinations

/*
Create temp table of origin details
*/
SELECT * INTO ##tblOrigins FROM(
SELECT DISTINCT Origin, OriginCountry, OriginZIP
FROM USCTTDEV.dbo.tblBidAppLanes
WHERE OriginCountry IS NOT NULL) Origins

/*
Create temp table of dest details
*/
SELECT * INTO ##tblDestinations FROM(
SELECT DISTINCT Dest, DestCountry, RIGHT(Dest,2) AS State
FROM USCTTDEV.dbo.tblBidAppLanes
WHERE DestCountry IS NOT NULL) Destinations

/*
Update the origins table where null to temp table details
*/
UPDATE USCTTDEV.dbo.tblBidAppLanes
SET OriginCountry = o.OriginCountry, OriginZip = o.OriginZip
FROM USCTTDEV.dbo.tblBidAppLanes bal
INNER JOIN ##tblOrigins o ON o.Origin = bal.Origin
WHERE bal.OriginCountry IS NULL

/*
Update the origins table where null to temp table details
*/
UPDATE USCTTDEV.dbo.tblBidAppLanes
SET DestCountry = d.DestCountry
FROM USCTTDEV.dbo.tblBidAppLanes bal
INNER JOIN ##tblDestinations d ON d.Dest = bal.Dest
WHERE bal.DestCountry IS NULL

/*
In case there's still no match to the destination, look up country from last 2 of dest against RA table
*/
UPDATE USCTTDEV.dbo.tblBidAppLanes
SET DestCountry = ra.Country
FROM USCTTDEV.dbo.tblBidAppLanes bal
INNER JOIN USCTTDEV.dbo.tblRegionalAssignments ra on ra.StateAbbv = right(bal.Dest,2)
WHERE bal.DestCountry is null

/*
Update Bid App Lanes to Updated City name, so it will match Actual Load Details
*/
UPDATE USCTTDEV.dbo.tblBidAppLanes
SET DEST = updt.UpdatedCityState
FROM USCTTDEV.dbo.tblBidAppLanes bal
INNER JOIN (SELECT DISTINCT
  bal.DEST_CITY_STATE,
  bal.Dest,
  RTRIM(LEFT(bal.Dest, CHARINDEX(',', bal.Dest) - 1)) AS CityName,
  zc.UpdatedCityName,
  zc.UpdatedCityName + ', ' + RIGHT(bal.Dest, 2) AS UpdatedCityState
FROM USCTTDEV.dbo.tblBidAppLanes bal
INNER JOIN USCTTDEV.dbo.tblZoneCities zc
  ON zc.Zone = bal.DEST_CITY_STATE
WHERE RTRIM(LEFT(bal.Dest, CHARINDEX(',', bal.Dest) - 1)) <> zc.UpdatedCityName) updt
  ON updt.DEST_CITY_STATE = bal.DEST_CITY_STATE
WHERE bal.Dest <> updt.UpdatedCityState

/*
Redundant, but I do it anyway!
*/
DROP TABLE IF EXISTS 
##tblOrigins,
##tblDestinations

END