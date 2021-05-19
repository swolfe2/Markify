USE [USCTTDEV]
GO
/****** Object:  StoredProcedure [dbo].[sp_HistoricLaneAwards]    Script Date: 5/18/2021 1:47:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Steve Wolfe, steve.wolfe@kcc.com, Central Transportation Team
-- Create date: 10/4/2019
-- Last modified: 5/18/2021
-- 5/18/2021 - SW - Added update logic to update the ExpirationDate in case there was some kind of append error
-- 3/22/2021 - SW - Added a OR clause to the insert of new lanes for when the lane already exists, but the expiration date is before today's date
-- 1/16/2020 - SW - Made an oopsie on the lane; was updating the DEST_CITY_STATE to the ORIG_CITY_STATE; fixed!
-- Description:	Append historic rate award changes to dbo.tblHistoricAwards
-- =============================================

ALTER PROCEDURE [dbo].[sp_HistoricLaneAwards]


AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

/*
What is this thing doing?
1) Make temp tables from both the tblBidAppLanes (Unique lanes) and tblBidAppRates (Unique awards on those lanes)
2) Calculate the WieghtedRPM, Award Percent Sum, and Count of Award Carriers for Award lanes and update the temp tables
3) If a lane on the award historical table is no longer awarded, update the expiration date to yesterday
4) If a lane on the award historical table doesn't match Lane / Effective Date / Weighted RPM on the new temp tables, update the expiration date to yesterday
5) If a lane is not on the award historical table, but is on the new temp tables, append to the award historical table
6) Append new temp lines from the temp table, where the lane existed by the WeightedRPM was different, to the award historical table
7) Delete any lines where teh ExipirationDate < EffectiveDate
*/

/*
Update null strings to whatever matches in Actual Load Detail, if something matches
Only use which ZIP has the most loads
*/

UPDATE USCTTDEV.dbo.tblBidAppLanes
SET OriginZip = zips.Zip
FROM USCTTDEV.dbo.tblBidAppLanes bal
INNER JOIN (
SELECT Origin, 
ZIP,
LoadCount,
Rank
FROM(
SELECT DISTINCT ald.FRST_CTY_NAME + ', ' +   ald.FRST_STA_CD AS Origin, 
CASE WHEN ald.FRST_CTRY_CD = 'USA' THEN LEFT(ald.FRST_PSTL_CD,5) ELSE ald.FRST_PSTL_CD END AS Zip,
COUNT(*) AS LoadCount,
ROW_NUMBER() OVER (PARTITION BY ald.FRST_CTY_NAME + ', ' +   ald.FRST_STA_CD ORDER BY COUNT(*) DESC) Rank
FROM USCTTDEV.dbo.tblActualLoadDetail ald
GROUP BY ald.FRST_CTY_NAME + ', ' +   ald.FRST_STA_CD,
CASE WHEN ald.FRST_CTRY_CD = 'USA' THEN LEFT(ald.FRST_PSTL_CD,5) ELSE ald.FRST_PSTL_CD END
) data
WHERE data.Rank = 1) zips ON zips.Origin = bal.Origin
WHERE bal.OriginZip IS NULL

/*
Drop all temp tables, and ensure a clean process
*/
DROP 
  TABLE IF EXISTS ##tblBidAppLanesTemp,
  ##tblBidAppLanesRatesTemp
  
/*
Create temp table with basic info from USCTTDEV.dbo.tblBidAppLanes
SELECT * FROM ##tblBidAppLanesTemp
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
  ) query 
ORDER BY 
  LaneID ASC 

/*
Update ##tblBidAppLanesTemp with WeightedRPM, 
*/
ALTER TABLE 
  ##tblBidAppLanesTemp DROP COLUMN IF EXISTS WeightedRPM
ALTER TABLE 
  ##tblBidAppLanesTemp DROP COLUMN IF EXISTS AwardCarrierCount
ALTER TABLE 
  ##tblBidAppLanesTemp DROP COLUMN IF EXISTS AwardPercent
ALTER TABLE 
  ##tblBidAppLanesTemp ADD WeightedRPM NUMERIC(6,2)
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
SELECT DISTINCT bar.Lane FROM USCTTDEV.dbo.tblBidAppRates bar WHERE bar.AWARD_PCT > 0
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
  AwardCarrierCount = balrt.AwardCarrierCount, 
  AwardPercent = balrt.AwardPercent 
FROM 
  ##tblBidAppLanesTemp balt
  INNER JOIN ##tblBidAppLanesRatesTemp balrt on balrt.laneid = balt.laneid

/*
Update any potential nulls
*/
  UPDATE 
	USCTTDEV.dbo.tblAwardLanesHistorical
	SET WeightedRPM = balt.WeightedRPM,
	AwardCarrierCount = balt.AwardCarrierCount,
	AwardPercent = balt.AwardPercent 
FROM USCTTDEV.dbo.tblAwardLanesHistorical alh
INNER JOIN ##tblBidAPpLanesTemp balt ON balt.Lane = alh.Lane
AND balt.EffectiveDate = alh.EffectiveDate
AND balt.ExpirationDate = alh.ExpirationDate
WHERE alh.WeightedRPM IS NULL
AND balt.WeightedRPM IS NOT NULL
  
/*
Set variabless
*/
  Declare @Now datetime, 
  @Today datetime, 
  @Yest datetime 
Set 
  @Now = GETDATE() 
Set 
  @Today = CONVERT(Date, @Now) 
Set 
  @Yest = CONVERT(
    Date, 
    dateadd(day,-1, @Today)
  ) 

/*
If the Lane / Effective Date / Weighted RPM combination doesn't match what's on the temp table, then mark the expiration date as 1 day before today's date
Select * from ##tblBidAppLanesTemp where LaneID = 97
Select * from ##tblBIdAppLanesRatesTemp
SELECT * FROM USCTTDEV.dbo.tblAwardLanesHistorical WHERE LaneID = 97
DELETE FROM USCTTDEV.dbo.tblAwardLanesHistorical WHERE ID = 23545
UPDATE USCTTDEV.dbo.tblAwardLanesHistorical SET ExpirationDate = '2999-12-31 00:00:00.000', UPDATED_LOADS = 2 WHERE ID = 97
*/
UPDATE 
  USCTTDEV.dbo.tblAwardLanesHistorical 
SET 
  ExpirationDate = @Yest, 
  LastUpdated = @Now 
FROM 
  USCTTDEV.dbo.tblAwardLanesHistorical alh 
  INNER JOIN ##tblBidAppLanesTemp balt
  ON balt.lane = alh.lane 
  INNER JOIN ##tblBidAppLanesRatesTemp bart on bart.laneid = balt.laneid
  INNER JOIN (
    SELECT 
      LANE, 
	  LaneID,
      MAX(ID) as MaxID 
    FROM 
      USCTTDEV.dbo.tblAwardLanesHistorical 
    GROUP BY 
      Lane,
	  LaneID
  ) max on max.Laneid = balt.laneid
  and max.MaxID = alh.ID 
WHERE 
  bart.WeightedRPM <> alh.WeightedRPM
  OR balt.UPDATED_LOADS <> alh.UPDATED_LOADS
  AND alh.ExpirationDate > GETDATE() 

/*
Add to USCTTDEV.dbo.tblAwardLanesHistorical where the Lane does not exist.
select * from USCTTDEV.dbo.tblAwardLanesHistorical order by LaneID Asc
*/
  INSERT INTO USCTTDEV.dbo.tblAwardLanesHistorical (
    LaneID, Lane, ORIG_CITY_STATE, Origin, 
    DEST_CITY_STATE, Dest, PrimaryCustomer, 
    Miles, BID_LOADS, UPDATED_LOADS, 
    HISTORICAL_LOADS, FMIC, Comment, 
    [Order Type], EffectiveDate, ExpirationDate, 
    WeightedRPM, AwardCarrierCount, 
    AwardPercent, AddedOn, LastUpdated
  ) 

Select 
  balt.LaneID, 
  balt.Lane, 
  balt.ORIG_CITY_STATE, 
  balt.Origin, 
  balt.DEST_CITY_STATE, 
  balt.Dest, 
  balt.PrimaryCustomer, 
  balt.Miles, 
  balt.BID_LOADS, 
  balt.UPDATED_LOADS, 
  balt.HISTORICAL_LOADS, 
  balt.FMIC, 
  balt.Comment, 
  balt.[Order Type], 
  @Today, 
  '12/31/2999', 
  balt.WeightedRPM, 
  balt.AwardCarrierCount, 
  balt.AwardPercent, 
  @Now, 
  @Now 
FROM 
  ##tblBidAppLanesTemp balt
  LEFT JOIN USCTTDEV.dbo.tblAwardLanesHistorical alh ON alh.laneid = balt.laneid
WHERE 
  alh.lane Is Null 
ORDER BY 
  balt.LaneID ASC 

/*
Add to USCTTDEV.dbo.tblAwardLanesHistorical where the Lane / Rate / Weighted RPM does not exist
*/

  INSERT INTO USCTTDEV.dbo.tblAwardLanesHistorical (
    LaneID, Lane, ORIG_CITY_STATE, Origin, 
    DEST_CITY_STATE, Dest, PrimaryCustomer, 
    Miles, BID_LOADS, UPDATED_LOADS, 
    HISTORICAL_LOADS, FMIC, Comment, 
    [Order Type], EffectiveDate, ExpirationDate, 
    WeightedRPM, AwardCarrierCount, 
    AwardPercent, AddedOn, LastUpdated
  ) 

Select 
  balt.LaneID, 
  balt.Lane, 
  balt.ORIG_CITY_STATE, 
  balt.Origin, 
  balt.DEST_CITY_STATE, 
  balt.Dest, 
  balt.PrimaryCustomer, 
  balt.Miles, 
  balt.BID_LOADS, 
  balt.UPDATED_LOADS, 
  balt.HISTORICAL_LOADS, 
  balt.FMIC, 
  balt.Comment, 
  balt.[Order Type], 
  @Today, 
  '12/31/2999', 
  balt.WeightedRPM, 
  balt.AwardCarrierCount, 
  balt.AwardPercent, 
  @Now, 
  @Now 
FROM 
  ##tblBidAppLanesTemp balt
  INNER JOIN ##tblBidAppLanesRatesTemp bart on balt.laneid = bart.laneid
  LEFT JOIN USCTTDEV.dbo.tblAwardLanesHistorical alh ON alh.laneid = balt.laneid
  INNER JOIN (
    SELECT 
      LANE, 
      MAX(ID) as MaxID 
    FROM 
      USCTTDEV.dbo.tblAwardLanesHistorical 
    GROUP BY 
      Lane
  ) max on max.Lane = balt.lane 
  and max.MaxID = alh.ID 
WHERE 
  alh.WeightedRPM <> bart.WeightedRPM 
  OR alh.WeightedRPM IS NULL
  OR alh.UPDATED_LOADS <> balt.UPDATED_LOADS
  OR CAST(alh.ExpirationDate AS DATE) < CAST(GETDATE() AS DATE)
ORDER BY 
  balt.LaneID ASC 

/*
If no longer awarded but is still Active update EndDate to @Yest
SElect * from USCTTDEV.dbo.tblAwardLanesHistorical order by ID ASC
Select * from ##tblBidAppLanesRatesTemp

Select * FROM 
  USCTTDEV.dbo.tblAwardLanesHistorical alh 
  LEFT JOIN ##tblBidAppLanesRatesTemp bart on bart.lane = alh.lane
WHERE 
  bart.lane is null 
  AND alh.ExpirationDate > 10/24/2019

  SELECT * FROM 
  USCTTDEV.dbo.tblAwardLanesHistorical alh 
  LEFT JOIN ##tblBidAppLanesRatesTemp bart on bart.laneid = alh.laneid
 WHERE   bart.lane is null
  AND alh.AwardPercent is not null
*/

UPDATE 
  USCTTDEV.dbo.tblAwardLanesHistorical 
SET 
  ExpirationDate = @Yest 
FROM 
  USCTTDEV.dbo.tblAwardLanesHistorical alh 
  LEFT JOIN ##tblBidAppLanesRatesTemp bart on bart.laneid = alh.laneid
WHERE 
  bart.lane is null
  AND alh.AwardPercent is not null
  AND alh.ExpirationDate > @Today 

  /*
  Delete from table if the ExpirationDate is < Effective date
  This should only happen when multiple changes are recorded on the same day for the same lane!
  */
DELETE FROM 
  USCTTDEV.dbo.tblAwardLanesHistorical 
WHERE 
  ExpirationDate < EffectiveDate 

/*
Update LastUpdated, and other fields, to @Now where the MaxID on USCTTDEV.dbo.tblAwardLanesHistorical = MaxID from tblBidAppLanesTemp
*/
UPDATE USCTTDEV.dbo.tblAwardLanesHistorical
SET 
	Lane = bal.Lane,
	ORIG_CITY_STATE = bal.ORIG_CITY_STATE,
	Origin =  bal.Origin,
	DEST_CITY_STATE = bal.DEST_CITY_STATE,
	Dest = bal.Dest,
	Miles = bal.Miles,
	BID_LOADS = bal.BID_LOADS,
	UPDATED_LOADS = bal.UPDATED_LOADS,
	HISTORICAL_LOADS = bal.HISTORICAL_LOADS,
	FMIC = bal.FMIC,
	COMMENT = bal.COMMENT,
	[Order Type] = bal.[Order Type],
	LastUpdated = @Now
FROM USCTTDEV.dbo.tblAwardLanesHistorical alh
INNER JOIN ##tblBidAppLanesTemp bal ON bal.MaxID = alh.ID AND bal.LaneID = alh.LaneID

/*
Update Expiration Date to what it should be in case there was some kind of error when it appended
*/
UPDATE USCTTDEV.dbo.tblAwardLanesHistorical
SET ExpirationDate = updateDate.UpdatedEffectiveDate
FROM USCTTDEV.dbo.tblAwardLanesHistorical arh
INNER JOIN (
SELECT updateEff.Lane,
updateEff.EffectiveDate,
updateEff.UpdatedEffectiveDate
FROM (
SELECT DISTINCT alh.Lane,
alh.EffectiveDate,
LEAD(EffectiveDate,1,0) OVER (PARTITION BY alh.Lane ORDER BY alh.EffectiveDate ASC) - 1 AS UpdatedEffectiveDate
FROM USCTTDEV.dbo.tblAwardLanesHistorical alh
WHERE alh.ExpirationDate = '12/31/2999'
/*AND Lane = 'ALTHEODO-5WI53110'*/) updateEff
WHERE updateEff.UpdatedEffectiveDate >= '1/1/2020'
) updateDate ON updateDate.Lane = arh.Lane
AND updateDate.EffectiveDate = arh.EffectiveDate

/*
delete from USCTTDEV.dbo.tblAwardLanesHistorical

Select balt.*, max.MaxID
FROM ##tblBidAppLanesTemp balt
INNER JOIN (SELECT LANE, MAX(ID) as MaxID FROM USCTTDEV.dbo.tblAwardLanesHistorical GROUP BY Lane) max on max.Lane = balt.lane
where balt.lane = 'AGSANFRA-5IL60446'

select * from ##tblBidAppLanesTemp where lane = 'AGSANFRA-5IL60446'
select * from ##tblBidAppLanesRatesTemp where lane = 'AGSANFRA-5IL60446'
select * from USCTTDEV.dbo.tblAwardLanesHistorical where lane = 'AGSANFRA-5IL60446'
select * from ##tblBidAppLanesTemp where lane = 'AGSANFRA-5IL60446'
UPDATE USCTTDEV.dbo.tblAwardLanesHistorical set ExpirationDate = '12/31/2999'
select * from ##tblBidAppLanesTemp order by laneid asc
select * from ##tblBidAppLanesRatesTemp order by lane asc
*/

END