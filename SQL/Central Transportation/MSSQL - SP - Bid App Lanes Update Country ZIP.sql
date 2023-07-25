USE [USCTTDEV]
GO
/****** Object:  StoredProcedure [dbo].[sp_BidAppLanesUpdateCountryZip]    Script Date: 9/10/2021 4:14:31 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Steve Wolfe, steve.wolfe@kcc.com, Central Transportation Team
-- Create date: 1/8/2020
-- Last modified: 9/10/2021
-- 9/10/2021 - SW - per Will Wooten; WI zones updated from Conway/Maumelle to Fox Valley Market
-- 11/3/2020 - SW - Added update queries to update the Origin Zip based on Actual Load Detail load counts
-- 9/2/2020 - SW - Added CTE and update query to make sure origin group gets updated every day
-- 6/3/2020 - SW - Added query to make sure the Origin Zip is set from USCTTDEV.dbo.tblActualLoadDetail
-- 2/19/2020 - SW - Added queries to make sure the origin/dest countries are correct to the Regional Assignments table
-- 2/3/2020 - SW - Added update stuff to Bid App Rates table
-- 1/14/2020 - SW - Added query to update Bid App Lanes to match UpdatedCityName from dbo_tblZoneCities
-- 2/5/2020 - SQL - Added subqueries to assign Origin/Dest states based off of the Zone Codes if they're still missing for some reason

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
##tblDestinations,
##tblOriginZones,
##tblDestZones

    /*
Create temp table of origin details
*/
    SELECT
        *
    INTO ##tblOrigins
    FROM(
SELECT
            DISTINCT
            Origin,
            OriginCountry,
            OriginZIP
        FROM
            USCTTDEV.dbo.tblBidAppLanes
        WHERE OriginCountry IS NOT NULL) Origins

    /*
Create temp table of dest details
SELECT * FROM ##tblDestinations
*/
    SELECT
        *
    INTO ##tblDestinations
    FROM(
SELECT
            DISTINCT
            Dest,
            DestCountry,
            RIGHT(Dest,2) AS State
        FROM
            USCTTDEV.dbo.tblBidAppLanes
        WHERE DestCountry IS NOT NULL) Destinations

    /*
Update the origins table where null to temp table details
*/
    UPDATE USCTTDEV.dbo.tblBidAppLanes
SET OriginCountry = o.OriginCountry, OriginZip = o.OriginZip
FROM
        USCTTDEV.dbo.tblBidAppLanes bal
        INNER JOIN ##tblOrigins o ON o.Origin = bal.Origin
WHERE bal.OriginCountry IS NULL

    /*
Update the origins table where null to temp table details
*/
    UPDATE USCTTDEV.dbo.tblBidAppLanes
SET DestCountry = d.DestCountry
FROM
        USCTTDEV.dbo.tblBidAppLanes bal
        INNER JOIN ##tblDestinations d ON d.Dest = bal.Dest
WHERE bal.DestCountry IS NULL

    /*
In case there's still no match to the destination, look up country from last 2 of dest against RA table
*/
    UPDATE USCTTDEV.dbo.tblBidAppLanes
SET DestCountry = ra.Country
FROM
        USCTTDEV.dbo.tblBidAppLanes bal
        INNER JOIN USCTTDEV.dbo.tblRegionalAssignments ra ON ra.StateAbbv = RIGHT(bal.Dest,2)
WHERE bal.DestCountry IS NULL

    /*
Update Bid App Lanes to Updated City name, so it will match Actual Load Details
*/
    UPDATE USCTTDEV.dbo.tblBidAppLanes
SET DEST = updt.UpdatedCityState
FROM
        USCTTDEV.dbo.tblBidAppLanes bal
        INNER JOIN (SELECT
            DISTINCT
            bal.DEST_CITY_STATE,
            bal.Dest,
            RTRIM(LEFT(bal.Dest, CHARINDEX(',', bal.Dest) - 1)) AS CityName,
            zc.UpdatedCityName,
            zc.UpdatedCityName + ', ' + RIGHT(bal.Dest, 2) AS UpdatedCityState
        FROM
            USCTTDEV.dbo.tblBidAppLanes bal
            INNER JOIN USCTTDEV.dbo.tblZoneCities zc
            ON zc.Zone = bal.DEST_CITY_STATE
        WHERE RTRIM(LEFT(bal.Dest, CHARINDEX(',', bal.Dest) - 1)) <> zc.UpdatedCityName) updt
        ON updt.DEST_CITY_STATE = bal.DEST_CITY_STATE
WHERE bal.Dest <> updt.UpdatedCityState

    /*
Select distinct Origin Zones/Zips into temp table
SELECT * FROM ##tblOriginZones

DROP TABLE IF EXISTS ##tblOriginZones
*/
    SELECT
        *
    INTO ##tblOriginZones
    FROM
        (SELECT
            DISTINCT
            ORIG_CITY_STATE,
            ORIGINZip,
            OriginCountry,
            COUNT(*) AS Count,
            RANK() OVER (PARTITION BY ORIG_CITY_STATE ORDER BY COUNT(*)DESC) AS vol_rank
        FROM
            USCTTDEV.dbo.tblBidAppLanes bal
        WHERE bal.OriginZip IS NOT NULL
        GROUP BY ORIG_CITY_STATE, ORIGINZip, OriginCountry)
OriginZones
    WHERE originZones.vol_rank = 1

    /*
Update Origin Zone Zip Where null
*/
    UPDATE USCTTDEV.dbo.tblBidAppLanes 
SET OriginZip = oz.OriginZip,
OriginCountry = oz.OriginCountry
FROM
        USCTTDEV.dbo.tblBidAppLanes bal
        INNER JOIN ##tblOriginZones oz ON oz.ORIG_CITY_STATE = bal.ORIG_CITY_STATE
WHERE bal.OriginZip IS NULL

    /*
Select distinct Origin Zones/Zips into temp table
SELECT * FROM ##tblDestZones

DROP TABLE IF EXISTS ##tblDestZones
*/
    SELECT
        *
    INTO ##tblDestZones
    FROM
        (SELECT
            DISTINCT
            DEST_CITY_STATE,
            Dest,
            DestCountry,
            COUNT(*) AS Count,
            RANK() OVER (PARTITION BY DEST_CITY_STATE ORDER BY COUNT(*)DESC) AS vol_rank
        FROM
            USCTTDEV.dbo.tblBidAppLanes bal
        WHERE bal.DEST IS NOT NULL
        GROUP BY DEST_CITY_STATE, Dest, DestCountry)
DestZones
    WHERE DestZones.vol_rank = 1

    /*
Update Dest Where null
*/
    UPDATE USCTTDEV.dbo.tblBidAppLanes 
SET Dest = dz.Dest,
DestCountry = dz.DestCountry
FROM
        USCTTDEV.dbo.tblBidAppLanes bal
        INNER JOIN ##tblDestZones dz ON dz.DEST_CITY_STATE = bal.DEST_CITY_STATE
WHERE bal.Dest IS NULL

    /*
Give the Origin a state when it's null
*/
    UPDATE USCTTDEV.dbo.tblBidAppLanes
SET Origin = Origin+', '+CASE WHEN ORIG_CITY_STATE LIKE 'KCIL' THEN 'IL' ELSE LEFT(ORIG_CITY_STATE,2) END
FROM
        USCTTDEV.dbo.tblBidAppLanes bal
WHERE Origin NOT LIKE '%,%'

    /*
Update null origins, again
*/
    UPDATE USCTTDEV.dbo.tblBidAppLanes
SET Origin = orig.Origin
FROM
        USCTTDEV.dbo.tblBidAppLanes bal
        INNER JOIN (SELECT
            DISTINCT
            ORIG_CITY_STATE,
            ORIGIN
        FROM
            USCTTDEV.dbo.tblBidAppLanes bal
        WHERE ORIGIN IS NOT NULL) orig ON orig.ORIG_CITY_STATE = bal.ORIG_CITY_STATE
WHERE bal.Origin IS NULL

    /*
Give the Dest a state when it's null
*/
    UPDATE USCTTDEV.dbo.tblBidAppLanes
SET Dest = Dest+', '+CASE WHEN DestCountry <> 'USA' THEN LEFT(DEST_CITY_STATE,2) ELSE SUBSTRING(DEST_CITY_STATE,2,2) END
FROM
        USCTTDEV.dbo.tblBidAppLanes bal
WHERE Dest NOT LIKE '%,%'

    /*
Update null dests, again
*/
    UPDATE USCTTDEV.dbo.tblBidAppLanes
SET Dest = Dest.Dest
FROM
        USCTTDEV.dbo.tblBidAppLanes bal
        INNER JOIN (SELECT
            DISTINCT
            DEST_CITY_STATE,
            Dest
        FROM
            USCTTDEV.dbo.tblBidAppLanes bal
        WHERE Dest IS NOT NULL) dest ON dest.DEST_CITY_STATE = bal.DEST_CITY_STATE
WHERE bal.Dest IS NULL

    /*
Make sure everything is uppercase
*/
    UPDATE USCTTDEV.dbo.tblBidAppLanes
SET Origin = UPPER(Origin),
Dest = UPPER(Dest)

    /*
Make sure that the origin country is right

SELECT DISTINCT RIGHT(origin, 2) as MissingOrig
FROM USCTTDEV.dbo.tblBidAppLanes bal
LEFT JOIN USCTTDEV.dbo.tblRegionalAssignments ra ON ra.StateAbbv = right(bal.Origin, 2)
WHERE ra.StateAbbv IS NULL
*/
    UPDATE USCTTDEV.dbo.tblBidAppLanes
SET OriginCountry = ra.Country
FROM
        USCTTDEV.dbo.tblBidAppLanes bal
        INNER JOIN USCTTDEV.dbo.tblRegionalAssignments ra ON ra.StateAbbv = RIGHT(bal.Origin, 2)
WHERE OriginCountry <> ra.Country

    /*
Make sure the dest country is right

SELECT DISTINCT RIGHT(dest, 2) as MissingDest
FROM USCTTDEV.dbo.tblBidAppLanes bal
LEFT JOIN USCTTDEV.dbo.tblRegionalAssignments ra ON ra.StateAbbv = right(bal.dest, 2)
WHERE ra.StateAbbv IS NULL
*/
    UPDATE USCTTDEV.dbo.tblBidAppLanes
SET DestCountry = ra.Country
FROM
        USCTTDEV.dbo.tblBidAppLanes bal
        INNER JOIN USCTTDEV.dbo.tblRegionalAssignments ra ON ra.StateAbbv = RIGHT(bal.Dest, 2)
WHERE DestCountry <> ra.Country

    /*
Make sure lane strings stay the same, in case something gets messed up
*/
    UPDATE USCTTDEV.dbo.tblBidAppRates
SET Lane = bal.Lane,
ORIG_CITY_STATE = bal.ORIG_CITY_STATE,
Dest = bal.DEST_CITY_STATE
FROM
        USCTTDEV.dbo.tblBidAppLanes bal
        INNER JOIN USCTTDEV.dbo.tblBidAppRates bar ON bar.LaneID = bal.LaneID
WHERE bal.Lane <> bar.Lane
        OR bal.ORIG_CITY_STATE <> bar.ORIG_CITY_STATE
        OR bal.DEST_CITY_STATE <> bar.DEST_CITY_STATE

    /*
Fill in Bid App Rates Gaps
*/
    UPDATE USCTTDEV.dbo.tblBidAppRates 
SET ORIG_CITY_STATE = bal.ORIG_CITY_STATE,
DEST_CITY_STATE = bal.DEST_CITY_STATE,
MODE = CASE WHEN bar.EQUIPMENT = '53IM' THEN 'IM'
WHEN bar.EQUIPMENT = '53TC' THEN 'TC'
ELSE 'T' END,
ACTIVE_FLAG = 'Y',
CONFIRMED = 'Y',
ORIGIN = bal.Origin,
DEST = bal.Dest,
EffectiveDate = CONVERT(DATE, getdate()),
ExpirationDate = '12/31/2999'
FROM
        USCTTDEV.dbo.tblBidAppRates bar
        INNER JOIN USCTTDEV.dbo.tblBidAppLanes bal ON bal.LaneID = bar.LaneID
WHERE bar.ORIG_CITY_STATE IS NULL

    /*
Update RPM and ChargeType depending on Min Charge value
*/
    UPDATE USCTTDEV.dbo.tblBidAppRates 
SET  [Rate Per Mile] = Round( IIF(bar.[Min Charge] / iif(bal.MILES = 0, 1, bal.MILES) > bar.CUR_RPM, ( bar.[Min Charge] / iif(bal.MILES = 0, 1, bal.MILES) ), bar.cur_rpm ), 2 ), 
  ChargeType = IIF( bar.[Min Charge] / iif(bal.MILES = 0, 1, bal.MILES) > bar.CUR_RPM, 'Flat Rate', 'Rate Per Mile' ) 
FROM
        USCTTDEV.dbo.tblBidAppRates bar
        INNER JOIN USCTTDEV.dbo.tblBidAppLanes bal ON bal.LaneID = bar.LaneID

    /*
'Update Intermodal with Fuel differential, based on Min Charge/Flat Rate value
*/
    DECLARE @fuelDifferential AS DECIMAL(5, 5)
    SET @fueldifferential =.15
    UPDATE USCTTDEV.dbo.tblBidAppRates 
SET 
  [Rate Per Mile] = Round( 
    IIF( 
      bar.[Min Charge] / iif(bal.MILES = 0, 1, bal.MILES) > bar.CUR_RPM, 
      ( 
        bar.[Min Charge] / iif(bal.MILES = 0, 1, bal.MILES) 
      ) - @fuelDifferential, 
      bar.cur_rpm - @fuelDifferential),2) 
FROM
        USCTTDEV.dbo.tblBidAppRates bar
        INNER JOIN USCTTDEV.dbo.tblBidAppLanes bal ON bal.orig_city_state = bar.orig_city_state
            AND bal.dest_city_state = bar.dest_city_state 
WHERE 
  bar.MODE = 'IM'

    /*
Update Bid App Rates Rank
*/
    UPDATE USCTTDEV.dbo.tblBidAppRates
SET RANK_NUM = ranks.Rank
FROM
        USCTTDEV.dbo.tblBidAppRates bar
        INNER JOIN (
SELECT
            bal.LaneID,
            bar.SCAC,
            RANK() OVER(PARTITION BY bal.orig_city_state, bal.dest_city_state ORDER BY bar.[rate per mile] ASC, bar.service DESC, bar.confirmed DESC, bar.[min charge] ASC, bar.SCAC ASC) AS Rank
        FROM
            USCTTDEV.dbo.tblbidapplanes AS bal
            INNER JOIN USCTTDEV.dbo.tblbidapprates AS bar
            ON ( bal.laneid =  
                      bar.laneid )) ranks ON ranks.LaneID = bar.LaneID
            AND ranks.SCAC = bar.SCAC

    /*
Update flat rate stuff, and make sure it's using the flat rate totals!
*/
    UPDATE USCTTDEV.dbo.tblBidAppRates
SET ChargeType = 'Flat Rate',
CUR_RPM = CAST(ROUND(bar.[Min Charge] / bal.MILES,2) AS NUMERIC(18,2)),
[Rate Per Mile] = CASE WHEN bar.EQUIPMENT = '53IM' THEN 
CAST(ROUND(bar.[Min Charge] / bal.MILES,2)-.15 AS NUMERIC(18,2))
ELSE CAST(ROUND(bar.[Min Charge] / bal.MILES,2) AS NUMERIC(18,2)) END,
AllInCost = [Min Charge]
FROM
        USCTTDEV.dbo.tblBidAppRates bar
        INNER JOIN USCTTDEV.dbo.tblBidAppLanes bal ON bal.LaneID = bar.LaneID
WHERE [Min Charge] IS NOT NULL AND ChargeType = 'Rate Per Mile'


    /*
Update All In Cost
*/
    UPDATE USCTTDEV.dbo.tblBidAppRates
SET AllInCost = CASE WHEN bar.ChargeType = 'Rate Per Mile' THEN bar.[Rate Per Mile] * bal.MILES
ELSE bar.[Min Charge] END
FROM
        USCTTDEV.dbo.tblBidAppRates bar
        INNER JOIN USCTTDEV.dbo.tblBidAppLanes bal ON bal.LaneID = bar.LaneID

    /*
/*
Add new lanes/carriers to original Coupa data
*/
INSERT INTO USCTTDEV.dbo.tblBidAppRatesTemp$ (LaneID, ORIG_CITY_STATE, DEST_CITY_STATE, Lane, Equipment, SCAC, Mode, LY_VOL, AWARD_PCT, AWARD_LDS, ACTIVE_FLAG, COMMENT, Confirmed, Service, Origin, Dest, EffectiveDate, ExpirationDate, [Rate Per Mile], [Min Charge], CUR_RPM, Rank_Num, ChargeType)
  SELECT
    *
  FROM (SELECT
    bar.LaneID,
    bar.ORIG_CITY_STATE,
    bar.DEST_CITY_STATE,
    bar.Lane,
    bar.Equipment,
    bar.SCAC,
    bar.MODE,
    0 AS LY_Vol,
    0 AS AWARD_PCT,
    0 AS AWARD_LDS,
    'Y' AS ACTIVE_FLAG,
    'NOT IN ORIGINAL COUPA DATA' AS Comment,
    'Y' AS Confirmed,
    1 AS SERVICE,
    bar.Origin,
    bar.Dest,
    bar.EffectiveDate,
    bar.ExpirationDate,
    CAST(ROUND(bar.CUR_RPM, 2) AS numeric(18, 2)) AS [Rate Per Mile],
    bar.[Min Charge],
    CAST(ROUND(bar.CUR_RPM, 2) AS numeric(18, 2)) AS CUR_RPM,
    CAST(ROUND(bar.Rank_Num, 2) AS numeric(18, 2)) AS Rank_Num,
    bar.ChargeType
  FROM USCTTDEV.dbo.tblBidAppRates bar
  LEFT JOIN USCTTDEV.dbo.tblBidAppRatesTemp$ bart
    ON (bar.LaneID = bart.LaneID
    AND bar.SCAC = bart.SCAC)
  WHERE bart.LaneID IS NULL) data

  /*
  Update original Coupa data where the ID is null
  */
  UPDATE USCTTDEV.dbo.tblBidAppRatesTemp$
  SET ID = LaneID
  WHERE ID IS NULL
  */
    /*
Rank them bad boys
*/
    EXEC USCTTDEV.dbo.sp_BidAppRatesRank

    /*
Update Dest ZIP if null, and dest like 5*
*/
    UPDATE USCTTDEV.dbo.tblBidAppLanes 
SET DestZip = RIGHT(Dest_City_State,5)
FROM
        USCTTDEV.dbo.tblBidAppLanes 
WHERE DEST_CITY_STATE LIKE '5%'
        AND DestZip IS NULL

    /*
Update Dest ZIP If null, and Dest NOT like 5*
*/
    UPDATE USCTTDEV.dbo.tblBidAppLanes 
SET DestZip = OriginZones.OriginZip
FROM
        USCTTDEV.dbo.tblBidAppLanes
        INNER JOIN (
SELECT
            DISTINCT
            bal.ORIG_CITY_STATE,
            OriginZip
        FROM
            USCTTDEV.dbo.tblBidAppLanes bal
) OriginZones ON OriginZones.ORIG_CITY_STATE = Dest_City_State
WHERE DEST_CITY_STATE NOT LIKE '5%'
        AND DestZip IS NULL

    /*
Update Origin Zips to whichever has the MOST shipments from Actual Load Detail, if it's currently different
*/
    --SELECT DISTINCT bal.ORIG_CITY_STATE, bal.OriginZip, OrigZips.FRST_PSTL_CD
    UPDATE USCTTDEV.dbo.tblBidAppLanes
SET OriginZip = OrigZips.FRST_PSTL_CD
FROM
        USCTTDEV.dbo.tblBidAppLanes bal
        INNER JOIN (
SELECT
            DISTINCT
            Origin_Zone,
            CASE WHEN FRST_CTRY_CD = 'USA' THEN LEFT(FRST_PSTL_CD,5) ELSE FRST_PSTL_CD END AS FRST_PSTL_CD,
            COUNT(DISTINCT LD_LEG_ID) AS LoadCount,
            ROW_NUMBER() OVER (PARTITION BY Origin_Zone ORDER BY COUNT(DISTINCT LD_LEG_ID) DESC) AS Rank
        FROM
            USCTTDEV.dbo.tblActualLoadDetail
        /*WHERE Origin_Zone = 'QCGATINE'*/
        GROUP BY Origin_Zone, CASE WHEN FRST_CTRY_CD = 'USA' THEN LEFT(FRST_PSTL_CD,5) ELSE FRST_PSTL_CD END) OrigZips ON OrigZips.Origin_Zone = bal.ORIG_CITY_STATE
WHERE OrigZips.Rank = 1
        AND bal.OriginZIP <> OrigZips.FRST_PSTL_CD

    /*
Redundant, but I do it anyway!
*/
    DROP TABLE IF EXISTS 
##tblOrigins,
##tblDestinations,
##tblOriginZones,
##tblDestZones;

    /*
Added 9/2/2020; these Origin Groups are the same ones used in the 2021 RFP. Update Bid App Lanes with the right Origin Group
Updated 9/10/2021 per Will Wooten; WI zones updated from Conway/Maumelle to Fox Valley Market
*/
    WITH
        tblOriginGroups
        (
            Origin,
            OriginGroup
        )
        AS
        
        (
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            SELECT
                    'GAAUGUST' AS [Origin],
                    'BiGranAug' AS [OriginGroup]
            UNION ALL
                SELECT
                    'SCBEECIS' AS [Origin],
                    'BiGranAug' AS [OriginGroup]
            UNION ALL
                SELECT
                    'SCGRANIT' AS [Origin],
                    'BiGranAug' AS [OriginGroup]
            UNION ALL
                SELECT
                    'SCEDGEFI' AS [Origin],
                    'BiGranAug' AS [OriginGroup]
            UNION ALL
                SELECT
                    'ARCONWAY' AS [Origin],
                    'Conway/Maumelle' AS [OriginGroup]
            UNION ALL
                SELECT
                    'ARMAUMEL' AS [Origin],
                    'Conway/Maumelle' AS [OriginGroup]
            UNION ALL
                SELECT
                    'WIAPPLET' AS [Origin],
                    'Fox Valley Market' AS [OriginGroup]
            UNION ALL
                SELECT
                    'WIKAUKAU' AS [Origin],
                    'Fox Valley Market' AS [OriginGroup]
            UNION ALL
                SELECT
                    'WIMENASH' AS [Origin],
                    'Fox Valley Market' AS [OriginGroup]
            UNION ALL
                SELECT
                    'WINEENAH' AS [Origin],
                    'Fox Valley Market' AS [OriginGroup]
            UNION ALL
                SELECT
                    'WILITTLE' AS [Origin],
                    'Fox Valley Market' AS [OriginGroup]
            UNION ALL
                SELECT
                    'WIOSHKOS' AS [Origin],
                    'Fox Valley Market' AS [OriginGroup]
            UNION ALL
                SELECT
                    'WICLINTO' AS [Origin],
                    'Green Bay Market- GB' AS [OriginGroup]
            UNION ALL
                SELECT
                    'WIDEPERE' AS [Origin],
                    'Green Bay Market- GB' AS [OriginGroup]
            UNION ALL
                SELECT
                    'WIGREENB' AS [Origin],
                    'Green Bay Market- GB' AS [OriginGroup]
            UNION ALL
                SELECT
                    'WIHOBART' AS [Origin],
                    'Green Bay Market- GB' AS [OriginGroup]
            UNION ALL
                SELECT
                    'NCHENVIL' AS [Origin],
                    'Hendersonville/Greer' AS [OriginGroup]
            UNION ALL
                SELECT
                    'SCGREER' AS [Origin],
                    'Hendersonville/Greer' AS [OriginGroup]
            UNION ALL
                SELECT
                    'OKJENKS' AS [Origin],
                    'Jenks/Tulsa' AS [OriginGroup]
            UNION ALL
                SELECT
                    'OKTULSA' AS [Origin],
                    'Jenks/Tulsa' AS [OriginGroup]
            UNION ALL
                SELECT
                    'WICUDAHY' AS [Origin],
                    'Milwaukee Market- MI' AS [OriginGroup]
            UNION ALL
                SELECT
                    'WIGERMAN' AS [Origin],
                    'Milwaukee Market- MI' AS [OriginGroup]
            UNION ALL
                SELECT
                    'WIHARTFO' AS [Origin],
                    'Milwaukee Market- MI' AS [OriginGroup]
            UNION ALL
                SELECT
                    'WIMILWAU' AS [Origin],
                    'Milwaukee Market- MI' AS [OriginGroup]
            UNION ALL
                SELECT
                    'WIOAKCRE' AS [Origin],
                    'Milwaukee Market- MI' AS [OriginGroup]
            UNION ALL
                SELECT
                    'WIPEWAUK' AS [Origin],
                    'Milwaukee Market- MI' AS [OriginGroup]
            UNION ALL
                SELECT
                    'WISUSSEX' AS [Origin],
                    'Milwaukee Market- MI' AS [OriginGroup]
            UNION ALL
                SELECT
                    'WIWALLIS' AS [Origin],
                    'Milwaukee Market- MI' AS [OriginGroup]
            UNION ALL
                SELECT
                    'ALMOBILE' AS [Origin],
                    'Mobile/Theodore' AS [OriginGroup]
            UNION ALL
                SELECT
                    'ALTHEODO' AS [Origin],
                    'Mobile/Theodore' AS [OriginGroup]
            UNION ALL
                SELECT
                    'UTOGDEN' AS [Origin],
                    'Ogden/Salt Lake City' AS [OriginGroup]
            UNION ALL
                SELECT
                    'UTSALTLA' AS [Origin],
                    'Ogden/Salt Lake City' AS [OriginGroup]
            UNION ALL
                SELECT
                    'CAONTARI' AS [Origin],
                    'Ontario/Garden Grove' AS [OriginGroup]
            UNION ALL
                SELECT
                    'CAGARGRO' AS [Origin],
                    'Ontario/Garden Grove' AS [OriginGroup]
            UNION ALL
                SELECT
                    'KCILROME-KCP' AS [Origin],
                    'Romeoville KCP/Skin' AS [OriginGroup]
            UNION ALL
                SELECT
                    'KCILROME-SKIN' AS [Origin],
                    'Romeoville KCP/Skin' AS [OriginGroup]
            UNION ALL
                SELECT
                    'KCILROME-NOF' AS [Origin],
                    'Romeoville KCP/Skin' AS [OriginGroup]
            UNION ALL
                SELECT
                    'NJSWEDES' AS [Origin],
                    'Swedesboro/Chester' AS [OriginGroup]
            UNION ALL
                SELECT
                    'PACHESTE' AS [Origin],
                    'Swedesboro/Chester' AS [OriginGroup]
            UNION ALL
                SELECT
                    'WICHIPPE' AS [Origin],
                    'Western WI- WW' AS [OriginGroup]
            UNION ALL
                SELECT
                    'WIEAUCLA' AS [Origin],
                    'Western WI- WW' AS [OriginGroup]
            UNION ALL
                SELECT
                    'WIMENOMO' AS [Origin],
                    'Western WI- WW' AS [OriginGroup]
        )


UPDATE USCTTDEV.dbo.tblBidAppLanes
SET OriginGroup =  CASE WHEN og.Origin IS NULL THEN NULL
WHEN bal.OriginGroup IS NULL AND og.Origin IS NOT NULL THEN og.OriginGroup
ELSE og.OriginGroup
END
FROM
        USCTTDEV.dbo.tblBidAppLanes bal
        LEFT JOIN tblOriginGroups og ON og.Origin = bal.ORIG_CITY_STATE

    /*
Make sure all Origin Groups are filled out
*/
    UPDATE USCTTDEV.dbo.tblBidAppLanes
SET OriginGroup = origGroup.OriginGroup
FROM
        USCTTDEV.dbo.tblBidAppLanes bal
        INNER JOIN (SELECT
            DISTINCT
            bal.ORIG_CITY_STATE,
            bal.OriginGroup,
            ROW_NUMBER() OVER (PARTITION BY bal.ORIG_CITY_STATE ORDER BY COUNT(DISTINCT bal.ID) DESC) AS RowNum
        FROM
            USCTTDEV.dbo.tblBidAppLanes bal
        WHERE bal.OriginGroup IS NOT NULL
        GROUP BY  bal.ORIG_CITY_STATE,
bal.OriginGroup) origGroup ON origGroup.ORIG_CITY_STATE = bal.ORIG_CITY_STATE
            AND origGroup.RowNum = 1
WHERE bal.OriginGroup IS NULL

    /*
Update the Origin Zip for the Origin Zone to match whichever one on Actual Load Detail has the most loads on it
*/
    UPDATE USCTTDEV.dbo.tblBidAppLanes
SET OriginZip = originZones.FRST_PSTL_CD
FROM
        USCTTDEV.dbo.tblBidAppLanes bal
        INNER JOIN (
SELECT
            Origin_Zone,
            FRST_PSTL_CD
        FROM(
SELECT
                DISTINCT
                ald.Origin_Zone,
                CASE WHEN ald.FRST_CTRY_CD = 'USA' THEN LEFT(ald.FRST_PSTL_CD,5) ELSE ald.FRST_PSTL_CD END AS FRST_PSTL_CD,
                COUNT(DISTINCT ald.LD_LEG_ID) AS LoadCount,
                ROW_NUMBER() OVER (PARTITION BY ald.Origin_Zone ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RankingNum
            FROM
                USCTTDEV.dbo.tblActualLoadDetail ald
            WHERE YEAR(SHPD_DTT) >= YEAR(GETDATE()) - 1
            GROUP BY ald.Origin_Zone,
CASE WHEN ald.FRST_CTRY_CD = 'USA' THEN LEFT(ald.FRST_PSTL_CD,5) ELSE ald.FRST_PSTL_CD END) originZones
        WHERE originZones.RankingNum = 1) originZones ON originZones.Origin_Zone = bal.ORIG_CITY_STATE

    /*
Update the Origin Zip for the Lane to match whichever one on Actual Load Detail has the most loads on it
*/
    UPDATE USCTTDEV.dbo.tblBidAppLanes
SET OriginZip = lanes.FRST_PSTL_CD
FROM
        USCTTDEV.dbo.tblBidAppLanes bal
        INNER JOIN(
SELECT
            DISTINCT
            Lane,
            FRST_PSTL_CD
        FROM
            (
SELECT
                DISTINCT
                ald.Lane,
                CASE WHEN ald.FRST_CTRY_CD = 'USA' THEN LEFT(ald.FRST_PSTL_CD,5) ELSE ald.FRST_PSTL_CD END AS FRST_PSTL_CD,
                COUNT(DISTINCT ald.LD_LEG_ID) AS LoadCount,
                ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RankingNum
            FROM
                USCTTDEV.dbo.tblActualLoadDetail ald
            WHERE YEAR(SHPD_DTT) >= YEAR(GETDATE()) - 1
            GROUP BY ald.Lane,
CASE WHEN ald.FRST_CTRY_CD = 'USA' THEN LEFT(ald.FRST_PSTL_CD,5) ELSE ald.FRST_PSTL_CD END) lanes
        WHERE lanes.RankingNum = 1) lanes ON lanes.Lane = bal.Lane

END