USE [USCTTDEV]
GO
/****** Object:  StoredProcedure [dbo].[sp_FMIC]    Script Date: 1/17/2020 11:51:14 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Steve Wolfe, steve.wolfe@kcc.com, Central Transportation Team
-- Create date: 1/13/2020
-- Last modified: 
-- Description:	Update USCTTDEV.dbo.tblBidAppLanes and USCTTDEV.dbo.tblBidAppRates with FMIC data
-- =============================================

ALTER PROCEDURE [dbo].[sp_FMIC]

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
/*
What's this file doing?

1) Update USCTTDEV.dbo.tblBidAppRates with the FMIC rate for each lane/equipment
2) Clear out any FMIC rates where it's not in the newest FMIC data
3) Clear any FMIC rates on the USCTTDEV.dbo.tblBidAppLanes table
4) Update the USCTTDEV.dbo.tblBidAppLanes table with the Avg(FMIC) rate for Non-Award Lanes
5) Update the USCTTDEV.dbo.tblBidAppLanes table with the WeightedAvg(FMIC) rate for Award Lanes
*/

/*
Update USCTTDEV.dbo.tblBidAppRates to new FMIC Values
*/
UPDATE USCTTDEV.dbo.tblBidAppRates
SET FMIC = FMIC.FairLinehaulRatePerMile
FROM USCTTDEV.dbo.tblBidAppRates bar
INNER JOIN (SELECT DISTINCT
  EstimateID AS LaneID,
  CASE
    WHEN MODE = 'DV' AND
      TempControlType = 'C' THEN '53TC'
    WHEN MODE = 'DV' AND
      TempControlType <> 'C' THEN '53FT'
    WHEN MODE = 'IC' THEN '53IM'
  END AS EQUIPMENT,
  FairLinehaulRatePerMile,
  FuelProgramUsed
FROM USCTTDEV.dbo.tblFMICHistorical
WHERE ENDDATE > GETDATE()) FMIC
  ON fmic.LaneID = bar.LaneID
  AND FMIC.EQUIPMENT = bar.EQUIPMENT

/*
If LaneID / Equipment is not on tblFMICHistorical, then update to null
*/
UPDATE USCTTDEV.dbo.tblBidAppRates
SET FMIC = NULL
FROM USCTTDEV.dbo.tblBidAppRates bar
LEFT JOIN (SELECT DISTINCT
  EstimateID AS LaneID,
  CASE
    WHEN MODE = 'DV' AND
      TempControlType = 'C' THEN '53TC'
    WHEN MODE = 'DV' AND
      TempControlType <> 'C' THEN '53FT'
    WHEN MODE = 'IC' THEN '53IM'
  END AS EQUIPMENT,
  FairLinehaulRatePerMile,
  FuelProgramUsed
FROM USCTTDEV.dbo.tblFMICHistorical
WHERE ENDDATE > GETDATE()) FMIC
  ON fmic.LaneID = bar.LaneID
  AND FMIC.EQUIPMENT = bar.EQUIPMENT
WHERE fmic.LaneID IS NULL
AND fmic.EQUIPMENT IS NULL

/*
Update USCTTDEV.dbo.tblBidAppLanes for AWARDED FMIC data
SELECT bar.LaneID, avg(bar.FMIC) AS FMIC, SUM(bar.award_pct) as AWARD_PCT, bar.EQUIPMENT
FROM USCTTDEV.dbo.tblBidAppRates bar
WHERE bar.award_pct IS NOT NULL
AND bar.FMIC IS NOT NULL
AND bar.laneID = 220
GROUP BY bar.LaneID, bar.EQUIPMENT
ORDER BY LaneID ASC
*/

/*
Clear FMIC from USCTTDEV.dbo.tblBidAppLanes
*/
UPDATE USCTTDEV.dbo.tblBidAppLanes
SET FMIC = NULL

/*
Update USCTTDEV.dbo.tblBidAppLanes to Non-Award AVG FMIC
*/
UPDATE USCTTDEV.dbo.tblBidAppLanes
SET FMIC = avgFMIC.AvgFMIC
FROM USCTTDEV.dbo.tblBidAppLanes bal
INNER JOIN (SELECT DISTINCT
  bal.LaneID,
  CAST(ROUND(AVG(bar.FMIC), 2) AS numeric(18, 2)) AS AvgFMIC
FROM USCTTDEV.dbo.tblBidAppLanes bal
INNER JOIN USCTTDEV.dbo.tblBidAppRates bar
  ON bar.LaneID = bal.LaneID
LEFT JOIN (SELECT DISTINCT
  LaneID
FROM USCTTDEV.dbo.tblBidAppRates
WHERE AWARD_PCT IS NOT NULL) awards
  ON awards.LaneID = bal.LaneID
WHERE bar.AWARD_PCT IS NULL
AND awards.LaneID IS NULL
GROUP BY bal.LaneID) avgFMIC
  ON avgFMIC.LaneID = bal.LaneID

/*
Update USCTTEV.dbo.tblBidAppLanes to Award Weighted AVG FMIC
*/
UPDATE USCTTDEV.dbo.tblBidAppLanes
SET FMIC = awardFMIC.AwardFMIC
FROM USCTTDEV.dbo.tblBidAppLanes bal
INNER JOIN (SELECT
  data.LaneID,
  CAST(ROUND(SUM(data.FMIC * data.AWARD_PCT) / SUM(data.AWARD_PCT), 2) AS numeric(18, 2)) AS AwardFMIC
FROM (SELECT
  bar.LaneID,
  AVG(bar.FMIC) AS FMIC,
  SUM(bar.award_pct) AS AWARD_PCT,
  bar.EQUIPMENT
FROM USCTTDEV.dbo.tblBidAppRates bar
WHERE bar.award_pct IS NOT NULL
AND bar.FMIC IS NOT NULL
GROUP BY bar.LaneID,
         bar.EQUIPMENT) data
GROUP BY data.LaneID) awardFMIC
  ON awardFMIC.laneID = bal.LaneID
END