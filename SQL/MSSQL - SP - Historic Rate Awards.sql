USE [USCTTDEV]
GO
/****** Object:  StoredProcedure [dbo].[sp_HistoricRateAwards]    Script Date: 4/7/2021 3:44:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
-- =============================================
-- Author:		Steve Wolfe, steve.wolfe@kcc.com, Central Transportation Team
-- Create date: 10/21/2019
-- Last modified: 4/7/2021
-- 4/7/2021 - SW - Discovered missing rates, and unsure where they would have went. Created historic backup table, and subqueries to append/update daily. Will never delete, ever ever.
-- 11/18/2020 - SW - Added query to append to USCTTDEV.dbo.tblBidAppRatesWeeklyAwards for Andrew Krafthefer
-- 2/24/2020 - Added Equipment to insert query, and also updating equipment based on Actual Load Detail if still null.
-- 2/4/2020 - SW - Added query to update tblAwardRatesHistorical when if it's still showing as awarded on the historical table, but not on the Bid App Rates table
-- Description:	Append historic rate award changes to dbo.tblAwardRatesHistorical
-- =============================================
*/
ALTER PROCEDURE [dbo].[sp_HistoricRateAwards]
	-- Add the parameters for the stored procedure here
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
/*
What is this thing doing?
1) Make temp tables from both the tblBidAppLanes (Unique lanes) and tblBidAppRates (Unique awards on those lanes)
2) Add new SCACs to table
3) If the award RPM (cur_rpm) is different, depreciate previous record
4) If a lane on the award historical table doesn't match Lane / Effective Date / Weighted RPM on the new temp tables, update the expiration date to yesterday
5) If a lane is not on the award historical table, but is on the new temp tables, append to the award historical table
6) Delete any lines where teh ExipirationDate < EffectiveDate
*/

/*
Drop all temp tables, and ensure a clean process
*/
DROP 
  TABLE IF EXISTS ##tblLanesAndRatesTemp
  
/*
Create temp table with basic info from USCTTDEV.dbo.tblBidAppLanes
*/

SELECT * INTO ##tblLanesAndRatesTemp FROM 
(SELECT
  bal.laneid,
  bal.orig_city_state,
  bal.dest_city_state,
  bal.lane,
  bal.commodity,
  bar.equipment,
  bal.miles,
  bal.bid_loads,
  bal.updated_loads,
  bal.historical_loads,
  bal.fmic,
  bal.comment AS lanecomment,
  bal.origin,
  SUBSTRING(bal.Origin, 1, CHARINDEX(', ', bal.Origin) - 1) OriginCity,
  SUBSTRING(bal.Origin, CHARINDEX(', ', bal.Origin) + 2, LEN(bal.Origin)) OriginState,
  bal.dest,
  SUBSTRING(bal.Dest, 1, CHARINDEX(', ', bal.Dest) - 1) DestCity,
  SUBSTRING(bal.Dest, CHARINDEX(', ', bal.Dest) + 2, LEN(bal.Dest)) DestState,
  bal.primarycustomer,
  bal.[order type],
  bal.effectivedate LaneEff,
  bal.expirationdate LaneExp,
  ca.carr_cd,
  ca.name,
  bar.scac,
  ca.srvc_desc,
  ca.broker,
  ca.shipmentcount,
  ca.maxShipDate,
  bar.mode,
  bar.preaward,
  bar.ly_vol,
  bar.ly_rpm,
  bar.bid_rpm,
  bar.award_pct,
  (SUM(bar.award_pct) OVER (PARTITION BY bal.laneid)) AS AwardSum,
  cnt.WeightedRPM,
  cnt.Count AS AwardCarrCount,
  bar.award_lds,
  bar.active_flag,
  bar.comment ratecomment,
  bar.confirmed,
  bar.service,
  bar.effectivedate CarrEff,
  bar.expirationdate CarrExp,
  bar.reason,
  bar.[rate per mile],
  bar.[min charge],
  CONVERT(decimal(10, 2), ROUND(iif(bar.ChargeType = 'Flat Rate', bar.[Min Charge], bar.[rate per mile] * iif(bal.Miles = 0 OR bal.MIles IS NULL, 1, bal.Miles)), 2)) AS AllInCost,
  bar.ChargeType,
  bar.cur_rpm,
  bar.rank_num,
  RANK() OVER (PARTITION BY bar.laneid ORDER BY bar.[rate per mile] ASC, bar.service DESC, bar.confirmed DESC, bar.[min charge] ASC, bar.SCAC ASC) AS Rank,
  ra.region,
  ra.carriermanager,
  CASE
    WHEN bal.[order type] = 'INBOUND' THEN SUBSTRING(bal.Dest, CHARINDEX(', ', bal.Dest) + 2, LEN(bal.Dest))
    ELSE SUBSTRING(bal.Origin, CHARINDEX(', ', bal.Origin) + 2, LEN(bal.Origin))
  END AS JoinState,
  iif(bar.confirmed = 'Y', 'Confirmed', 'Not Confirmed') AS ConfirmedString,
  iif(bar.active_flag = 'Y', 'Active', 'Not Active') AS ActiveString,
  iif(bar.active_flag = 'Y', 'Active', 'Not Active') + ' - ' + iif(bar.confirmed = 'Y', 'Confirmed', 'Not Confirmed') AS Status
FROM USCTTDEV.dbo.tblbidapplanes AS bal
INNER JOIN USCTTDEV.dbo.tblbidapprates AS bar
  ON (bal.laneid =
  bar.laneid)
INNER JOIN USCTTDEV.dbo.tblRegionalAssignments AS ra
  ON (ra.StateAbbv =
                    CASE
                      WHEN bal.[order type] = 'INBOUND' THEN SUBSTRING(bal.Dest, CHARINDEX(', ', bal.Dest) + 2, LEN(bal.Dest))
                      ELSE SUBSTRING(bal.Origin, CHARINDEX(', ', bal.Origin) + 2, LEN(bal.Origin))
                    END)
LEFT JOIN USCTTDEV.dbo.tblCarriers AS ca
  ON (bar.SCAC = ca.SRVC_CD)
INNER JOIN (SELECT DISTINCT
  lane, laneid,
  COUNT(DISTINCT SCAC) AS Count, 
  ROUND(
        SUM(CUR_RPM * AWARD_PCT) / SUM(AWARD_PCT), 
        2
      ) AS WeightedRPM
FROM USCTTDEV.dbo.tblBidAppRates
WHERE expirationdate >= GETDATE()
AND award_pct IS NOT NULL
GROUP BY lane, laneid) AS cnt
  ON cnt.laneid = bar.Laneid
) AS DATA
WHERE CarrExp >= getdate()
AND AWARD_PCT Is Not Null
AND CUR_RPM Is Not Null
ORDER BY laneid ASC, RANK ASC

/*
SELECT * FROM USCTTDEV.dbo.tblBidAppRates WHERE ExpirationDate >= getdate()
AND AWARD_PCT Is Not Null
AND CUR_RPM Is Not Null 
Update ##tblBidAppLanesTemp status column
SELECT * FROM ##tblLanesAndRatesTemp 
*/
ALTER TABLE 
  ##tblLanesAndRatesTemp DROP COLUMN IF EXISTS Status
ALTER TABLE 
  ##tblLanesAndRatesTemp ADD Status NVARCHAR(25)

/*
Update ##tblLanesAndRatesTemp where all the fields match
SELECT * FROM ##tblLanesAndRatesTemp
SELECT * FROM USCTTDEV.dbo.tblAwardRatesHistorical
*/
UPDATE ##tblLanesAndRatesTemp
SET STATUS = 'Matches'
FROM USCTTDEV.dbo.tblAwardRatesHistorical arh
INNER JOIN ##tblLanesAndRatesTemp lart ON lart.scac = arh.scac
AND lart.laneid = arh.laneID
AND lart.award_pct = arh.award_pct
AND lart.mode = arh.mode
AND lart.cur_rpm = arh.cur_rpm
AND arh.ExpirationDate > GETDATE()

/*
Delete from ##tblLanesAndRatesTemp where everything matched
SELECT * FROM ##tblLanesAndRatesTemp
*/
DELETE FROM ##tblLanesAndRatesTemp
WHERE STATUS = 'Matches'

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
Update USCTTDEV.dbo.tblAwardRatesHistorical where something's different, by Lane / SCAC / Mode / CUR_RPM
Will depreciate records as of yesterday's date. Next query will add new records for today's date
*/
UPDATE USCTTDEV.dbo.tblAwardRatesHistorical
SET ExpirationDate = @Yest,
LastUpdated = @Now
FROM USCTTDEV.dbo.tblAwardRatesHistorical arh
INNER JOIN ##tblLanesAndRatesTemp lart ON lart.scac = arh.scac
AND lart.laneid = arh.laneID
AND lart.mode = arh.mode
WHERE ExpirationDate >= @Today

/*
Append new records to USCTTDEV.dbo.tblAwardRatesHistorical
*/
INSERT INTO USCTTDEV.dbo.tblAwardRatesHistorical (LaneID, Lane, ORIG_CITY_STATE, Origin, DEST_CITY_STATE, Dest, Miles, FMIC, EQUIPMENT, Comment, RateComment, [Order Type], WeightedRPM, AwardCarrierCount, AwardPercent, Carrier, CarrierName, SCAC, SCACName, Broker, Mode, PreAward, Award_PCT, Award_LDS, AwardSum, [Rate Per Mile], [Min Charge], CUR_RPM, AllInCost, Rank_Num, Rank, EffectiveDate, ExpirationDate, AddedOn, LastUpdated)  
SELECT LaneID, Lane, ORIG_CITY_STATE, Origin, DEST_CITY_STATE, Dest, Miles, FMIC, EQUIPMENT, lanecomment, RateComment, [Order Type], WeightedRPM, AwardCarrCount, AwardSum, CARR_CD, name, SCAC, SRVC_DESC, Broker, Mode, PreAward, Award_PCT, Award_LDS, AwardSum, [Rate Per Mile], [Min Charge], CUR_RPM, AllInCost, Rank_Num, Rank, @Today, CONVERT(Date,'12/31/2999'), @Today, @Now 
FROM ##tblLanesAndRatesTemp
ORDER BY LANEID, SCAC ASC

/*
If something exists on USCTTDEV.dbo.tblAwardRatesHistorical, but is no longer awarded, set effective date to yesterday
SELECT * FROM USCTTDEV.dbo.tblAwardRatesHistorical
UPDATE USCTTDEV.dbo.tblAwardRatesHistorical SET EFFECTIVEDATE = '2/1/2020'
*/
UPDATE USCTTDEV.dbo.tblAwardRatesHistorical
SET ExpirationDate = @Yest,
LastUpdated = @Now
FROM USCTTDEV.dbo.tblAwardRatesHistorical arh
INNER JOIN USCTTDEV.dbo.tblBidAppRates bar ON bar.LaneID = arh.LaneID
AND bar.SCAC = arh.SCAC
WHERE bar.AWARD_PCT IS NULL
AND arh.AWARD_PCT IS NOT NULL
AND arh.ExpirationDate > @Today

/*
Update equipment type if it's still blank, for some reason, from Actual Load Detail
*/
UPDATE USCTTDEV.dbo.tblAwardRatesHistorical
SET EQUIPMENT = equip.EQMT_TYP
FROM USCTTDEV.dbo.tblAwardRatesHistorical arh
INNER JOIN (SELECT DISTINCT CARR_CD, SRVC_CD, EQMT_TYP, RANK() OVER (Partition by CARR_CD, SRVC_CD ORDER BY COUNT(*) DESC) AS Rank
FROM USCTTDEV.dbo.tblActualLoadDetail
GROUP BY CARR_CD, SRVC_CD, EQMT_TYP) equip ON arh.Carrier = equip.CARR_CD
AND arh.SCAC = equip.SRVC_CD
WHERE equip.rank = 1
and arh.EQUIPMENT IS NULL

/*
Update Mode, in case it's some other value that's not supposed to be there
*/
UPDATE USCTTDEV.dbo.tblAwardRatesHistorical
SET MODE = CASE WHEN EQUIPMENT = '53IM' THEN 'IM'
ELSE 'T' END
WHERE MODE NOT IN ('IM','T')

/*
Add all new ID's to backup table before any deletes
*/
INSERT INTO USCTTDEV.dbo.tblAwardRatesHistoricalBackup (ID, LaneID, Lane, ORIG_CITY_STATE, Origin, DEST_CITY_STATE, Miles, FMIC, Comment, RateComment, [Order Type], WeightedRPM, AwardCarrierCount, AwardPercent, Carrier, CarrierName, SCAC, SCACName, Broker, Mode, EQUIPMENT, PreAward, AWARD_PCT, AWARD_LDS, AwardSum, [Rate Per Mile], [Min Charge], CUR_RPM, AllInCost, Rank_Num, Rank, EffectiveDate, ExpirationDate, AddedOn, LastUpdated)
SELECT arh.ID, arh.LaneID, arh.Lane, arh.ORIG_CITY_STATE, arh.Origin, arh.DEST_CITY_STATE, arh.Miles, arh.FMIC, arh.Comment, arh.RateComment, arh.[Order Type], arh.WeightedRPM, arh.AwardCarrierCount, arh.AwardPercent, arh.Carrier, arh.CarrierName, arh.SCAC, arh.SCACName, arh.Broker, arh.Mode, arh.EQUIPMENT, arh.PreAward, arh.AWARD_PCT, arh.AWARD_LDS, arh.AwardSum, arh.[Rate Per Mile], arh.[Min Charge], arh.CUR_RPM, arh.AllInCost, arh.Rank_Num, arh.Rank, arh.EffectiveDate, arh.ExpirationDate, arh.AddedOn, arh.LastUpdated
FROM USCTTDEV.dbo.tblAwardRatesHistorical arh
LEFT JOIN USCTTDEV.dbo.tblAwardRatesHistoricalBackup arhb ON arhb.ID = arh.ID
WHERE arhb.ID IS NULL

/*
Update all existing ID's to match what's on the Award Rates Historical table
*/
UPDATE USCTTDEV.dbo.tblAwardRatesHistoricalBackup
SET 
LaneID = arh.LaneID, 
Lane = arh.Lane, 
ORIG_CITY_STATE = arh.ORIG_CITY_STATE, 
Origin = arh.Origin, 
DEST_CITY_STATE = arh.DEST_CITY_STATE, 
Miles = arh.Miles, 
FMIC = arh.FMIC, 
Comment = arh.COMMENT, 
RateComment = arh.RateComment, 
[Order Type] = arh.[Order Type], 
WeightedRPM = arh.WeightedRPM, 
AwardCarrierCount = arh.AwardCarrierCount, 
AwardPercent = arh.AwardPercent, 
Carrier = arh.Carrier, 
CarrierName = arh.CarrierName, 
SCAC = arh.SCAC, 
SCACName = arh.SCACName, 
Broker = arh.Broker, 
Mode = arh.Mode, 
EQUIPMENT = arh.EQUIPMENT, 
PreAward = arh.PreAward, 
AWARD_PCT = arh.AWARD_PCT, 
AWARD_LDS = arh.AWARD_LDS, 
AwardSum = arh.AwardSum, 
[Rate Per Mile] = arh.[Rate Per Mile], 
[Min Charge] = arh.[Min Charge], 
CUR_RPM = arh.CUR_RPM, 
AllInCost = arh.AllInCost, 
Rank_Num = arh.Rank_Num, 
Rank = arh.Rank, 
EffectiveDate = arh.EffectiveDate, 
ExpirationDate = arh.ExpirationDate, 
AddedOn = arh.AddedOn, 
LastUpdated = arh.LastUpdated
FROM USCTTDEV.dbo.tblAwardRatesHistoricalBackup arhb
INNER JOIN USCTTDEV.dbo.tblAwardRatesHistorical arh ON arh.ID = arh.ID

/*
Delete from table if the ExpirationDate is < Effective date
This should only happen when multiple changes are recorded on the same day for the same lane!
*/
DELETE FROM 
  USCTTDEV.dbo.tblAwardRatesHistorical
WHERE 
  ExpirationDate < EffectiveDate 

/*
Drop all temp tables, and ensure a clean process
*/
DROP 
  TABLE IF EXISTS ##tblLanesAndRatesTemp

  /*
  Add weekly awards
  */
INSERT INTO USCTTDEV.dbo.tblBidAppRatesWeeklyAwards(AddedOn, WeekStartDate, LaneID, ORIG_CITY_STATE, DEST_CITY_STATE, DestZip, PrimaryCustomer, [Order Type], UPDATED_LOADS, EQUIPMENT, SCAC, AWARD_PCT)
SELECT CAST(WeeklyAwards.AddedOn AS DATETIME) AS AddedOn,
CAST(WeeklyAwards.WeekStartDate AS DATE) AS WeekStartDate,
CAST(WeeklyAwards.LaneID AS INT) AS LaneID,
CAST(WeeklyAwards.ORIG_CITY_STATE AS NVARCHAR(20)) AS ORIG_CITY_STATE,
CAST(WeeklyAwards.DEST_CITY_STATE AS NVARCHAR(20)) AS DEST_CITY_STATE,
CAST(WeeklyAwards.DestZip AS NVARCHAR(10)) AS DestZip,
CAST(WeeklyAwards.PrimaryCustomer AS NVARCHAR(250)) AS PrimaryCustomer,
CAST(WeeklyAwards.[Order Type] AS NVARCHAR(25)) AS [Order Type],
CAST(WeeklyAwards.UPDATED_LOADS AS INT) AS UPDATED_LOADS,
CAST(WeeklyAwards.EQUIPMENT AS NVARCHAR(5)) AS EQUIPMENT,
CAST(WeeklyAwards.SCAC AS NVARCHAR(5)) AS SCAC,
CAST(WeeklyAwards.AWARD_PCT AS NUMERIC(10,2)) AS AWARD_PCT
FROM (SELECT DISTINCT 
GETDATE() AS AddedOn,
CAST(DATEADD(wk, DATEDIFF(wk,0,GETDATE()), 0) AS DATE) AS WeekStartDate,
bal.LaneID,
bal.ORIG_CITY_STATE,
bal.DEST_CITY_STATE,
bal.DestZip,
bal.PrimaryCustomer,
bal.[Order Type],
bal.UPDATED_LOADS,
bar.EQUIPMENT,
bar.SCAC,
bar.AWARD_PCT
FROM USCTTDEV.dbo.tblBidAppLanes bal
INNER JOIN USCTTDEV.dbo.tblBidAppRates bar ON bar.LaneID = bal.LaneID
WHERE bar.AWARD_PCT IS NOT NULL) WeeklyAwards
WHERE WeeklyAwards.WeekStartDate NOT IN (SELECT DISTINCT barwa.WeekStartDate FROM USCTTDEV.dbo.tblBidAppRatesWeeklyAwards barwa)
ORDER BY WeeklyAwards.ORIG_CITY_STATE ASC, WeeklyAwards.DEST_CITY_STATE ASC, WeeklyAwards.SCAC ASC

END
