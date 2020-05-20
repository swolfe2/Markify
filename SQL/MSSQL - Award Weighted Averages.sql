USE [USCTTDEV]
GO
/****** Object:  StoredProcedure [dbo].[sp_AwardWeightedAverages]    Script Date: 1/17/2020 11:48:28 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Steve Wolfe, steve.wolfe@kcc.com, Central Transportation Team
-- Create date: 10/4/2019
-- Last modified: 10/30/2019
-- Description:	Update USCTTDEV.dbo.tblBidAppLanes with Weighted Averages for Award Lanes
-- 10/30/2019 - SW - Added SQL to update All In Cost, and also adjust the Award_PCT / LDS if null
-- =============================================

ALTER PROCEDURE [dbo].[sp_AwardWeightedAverages]

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

/*
What is this thing doing?
1) Make temp tables from both the tblBidAppLanes (Unique lanes) and tblBidAppRates (Unique awards on those lanes)
2) Calculate the WieghtedRPM, Award Percent Sum, and Count of Award Carriers for Award lanes and update the temp tables
3) Update USCTTDEV.dbo.tblBidAppLanes with Weighted Averages
*/

/*
Update Award_PCT to Null if 0
*/
UPDATE USCTTDEV.dbo.tblBidAppRates
SET AWARD_PCT = Null
WHERE AWARD_PCT = 0

/*
Update Award_PCT and Award_LDS to null if Award_LDS is 0
*/
UPDATE USCTTDEV.dbo.tblBidAppRates
SET AWARD_PCT = Null, Award_LDS = Null
WHERE Award_LDS = 0

/*
Update Charge Type for if there's a Flat Rate or Rate Per Mile
SELECT * FROM USCTTDEV.dbo.tblBidAppRates order by ID ASC
*/
UPDATE USCTTDEV.dbo.tblBidAppRates
SET ChargeType = CASE WHEN [Min Charge] IS NULL THEN 'Rate Per Mile' ELSE 'Flat Rate' END

/*
Update Rate Per Mile and CUR_RPM for when there's a min charge
*/
UPDATE USCTTDEV.dbo.tblBidAppRates
SET CUR_RPM = ROUND(bar.[Min Charge] / bal.miles, 2),
[Rate Per Mile] =  CASE WHEN bar.MODE = 'IM' THEN ROUND(bar.[Min Charge] / bal.miles, 2) - .15 ELSE ROUND(bar.[Min Charge] / bal.miles, 2) END
FROM USCTTDEV.dbo.tblBidAppRates bar
INNER JOIN USCTTDEV.dbo.tblBidAppLanes bal on bar.laneid = bal.laneid
WHERE [Min Charge] IS NOT NULL and ChargeType = 'Flat Rate'

/*
Update AllInCost
*/
UPDATE USCTTDEV.dbo.tblBidAppRates
SET AllInCost = CASE WHEN [ChargeType] = 'Flat Rate' THEN [Min Charge] ELSE Round([Rate Per Mile] * bal.miles,2) END
FROM USCTTDEV.dbo.tblBidAppRates bar
INNER JOIN USCTTDEV.dbo.tblBidAppLanes bal on bar.laneid = bal.laneid

/*
Drop all temp tables, and ensure a clean process
*/
DROP 
  TABLE IF EXISTS ##tblBidAppLanesTemp,
  ##tblBidAppLanesRatesTemp
  
/*
Create temp table with basic info from USCTTDEV.dbo.tblBidAppLanes
*/
SELECT 
  * INTO ##tblBidAppLanesTemp  FROM 
  (
    SELECT 
      DISTINCT max.MaxID, 
      bal.LaneID, 
      bal.ORIG_CITY_STATE, 
      bal.Origin, 
      bal.DEST_CITY_STATE, 
      bal.Dest, 
      bal.Lane, 
      bal.PrimaryCustomer, 
      bal.MILES, 
      bal.BID_LOADS, 
      bal.UPDATED_LOADS, 
      bal.HISTORICAL_LOADS, 
      bal.FMIC, 
      bal.COMMENT, 
      UPPER(bal.[Order Type]) as [Order Type], 
      bal.EffectiveDate, 
      bal.ExpirationDate 
    FROM 
      USCTTDEV.dbo.tblBidAppLanes bal 
      LEFT JOIN USCTTDEV.dbo.tblAwardLanesHistorical bah ON bal.laneid = bah.laneid
      LEFT JOIN (
        SELECT 
          LANE,
    	  LaneID,
          MAX(ID) as MaxID 
        FROM 
          USCTTDEV.dbo.tblAwardLanesHistorical 
        GROUP BY 
          Lane,
		  LaneID
      ) max on max.Laneid = bah.laneid
	  WHERE AwardPercent > 0
  ) query 
ORDER BY 
  LaneID ASC 

/*
Update ##tblBidAppLanesTemp with WeightedRPM, 
*/
ALTER TABLE 
  ##tblBidAppLanesTemp DROP COLUMN IF EXISTS WeightedRPM
ALTER TABLE 
  ##tblBidAppLanesTemp DROP COLUMN IF EXISTS WeightedService
ALTER TABLE 
  ##tblBidAppLanesTemp DROP COLUMN IF EXISTS AwardCarrierCount
ALTER TABLE 
  ##tblBidAppLanesTemp DROP COLUMN IF EXISTS AwardPercent
ALTER TABLE 
  ##tblBidAppLanesTemp ADD WeightedRPM NUMERIC(6,2)
ALTER TABLE 
  ##tblBidAppLanesTemp ADD WeightedService NUMERIC(6,2)
ALTER TABLE 
  ##tblBidAppLanesTemp ADD AwardCarrierCount INT
ALTER TABLE 
  ##tblBidAppLanesTemp ADD AwardPercent NUMERIC(6,2)
  
/*
Drop temp table for rate information, if exists
*/
DROP 
  TABLE IF EXISTS ##tblBidAppLanesRatesTemp 
  
/*
Create temp table for weighted RPM
*/
SELECT 
  * INTO ##tblBidAppLanesRatesTemp  FROM 
  (
    SELECT 
      DISTINCT LANE, 
	  LaneID,
      ROUND(
        SUM(bar.CUR_RPM * bar.AWARD_PCT) / SUM(bar.AWARD_PCT), 
        2
      ) AS WeightedRPM, 
	  ROUND(
        SUM(bar.service * bar.AWARD_LDS) / SUM(bar.AWARD_LDS), 
        2
      ) AS WeightedService,
      SUM(
        CASE WHEN [SCAC] IS NULL THEN 0 ELSE 1 END
      ) AS AwardCarrierCount, 
      SUM(bar.AWARD_PCT) as AwardPercent, 
      MAX(bar.EffectiveDate) as EffectiveDate, 
      MAX(bar.ExpirationDate) as ExpirationDate 
    FROM 
      USCTTDEV.dbo.tblBidAppRates bar 
    WHERE 
      AWARD_PCT IS NOT NULL 
      --AND bar.EffectiveDate <= GETDATE() 
      AND bar.ExpirationDate > GETDATE() 
      AND bar.AWARD_PCT > 0 
      AND CUR_RPM > 0 
    GROUP BY 
      bar.lane,
	  bar.LaneID
  ) data 

/*
Update ##tblBidAppLanesTemp to ##tblBidAppLanesRatesTemp
Select * from ##tblBidAppLanesTemp
*/
UPDATE 
  ##tblBidAppLanesTemp
SET 
  WeightedRPM = balrt.WeightedRPM,
  WeightedService = balrt.WeightedService,
  AwardCarrierCount = balrt.AwardCarrierCount, 
  AwardPercent = balrt.AwardPercent 
FROM 
  ##tblBidAppLanesTemp balt
  INNER JOIN ##tblBidAppLanesRatesTemp balrt on balrt.laneid = balt.laneid

/*
Update USCTTDEV.dbo.tblBidAppLanes to values from ##tblBidAppLanesTemp
If lane id doesn't exist, update to null
*/
UPDATE USCTTDEV.dbo.tblBidAppLanes
SET AwardWeightedRPM = CASE WHEN balt.laneID is null THEN null ELSE balt.WeightedRPM END, 
AwardWeightedService = CASE WHEN balt.laneID is null THEN null ELSE balt.WeightedService END
FROM USCTTDEV.dbo.tblBidAppLanes bal
LEFT JOIN ##tblBidAppLanesTemp balt on bal.laneid = balt.laneid

/*
Don't really need this, but do it anyway
*/
DROP 
  TABLE IF EXISTS ##tblBidAppLanesTemp,
  ##tblBidAppLanesRatesTemp

END