USE [USCTTDEV]
GO
/****** Object:  StoredProcedure [dbo].[sp_HistoricRateAwards]    Script Date: 1/17/2020 11:52:26 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Steve Wolfe, steve.wolfe@kcc.com, Central Transportation Team
-- Create date: 10/21/2019
-- Last modified: 
-- Description:	Append historic rate award changes to dbo.tblAwardRatesHistorical
-- =============================================
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
Update ##tblBidAppLanesTemp status column
*/
ALTER TABLE 
  ##tblLanesAndRatesTemp DROP COLUMN IF EXISTS Status
ALTER TABLE 
  ##tblLanesAndRatesTemp ADD Status NVARCHAR(25)

/*
Update USCTTDEV.dbo.tblAwardRatesHistorical where all the fields match
*/
UPDATE ##tblLanesAndRatesTemp
SET STATUS = 'Matches'
FROM USCTTDEV.dbo.tblAwardRatesHistorical arh
INNER JOIN ##tblLanesAndRatesTemp lart ON lart.scac = arh.scac
AND lart.laneid = arh.laneID
AND lart.award_pct = arh.award_pct
AND lart.mode = arh.mode
AND lart.cur_rpm = arh.cur_rpm

/*
Delete from ##tblLanesAndRatesTemp where everything matched
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
INSERT INTO USCTTDEV.dbo.tblAwardRatesHistorical (LaneID, Lane, ORIG_CITY_STATE, Origin, DEST_CITY_STATE, Dest, Miles, FMIC, Comment, RateComment, [Order Type], WeightedRPM, AwardCarrierCount, AwardPercent, Carrier, CarrierName, SCAC, SCACName, Broker, Mode, PreAward, Award_PCT, Award_LDS, AwardSum, [Rate Per Mile], [Min Charge], CUR_RPM, AllInCost, Rank_Num, Rank, EffectiveDate, ExpirationDate, AddedOn, LastUpdated)  
SELECT LaneID, Lane, ORIG_CITY_STATE, Origin, DEST_CITY_STATE, Dest, Miles, FMIC, lanecomment, RateComment, [Order Type], WeightedRPM, AwardCarrCount, AwardSum, CARR_CD, name, SCAC, SRVC_DESC, Broker, Mode, PreAward, Award_PCT, Award_LDS, AwardSum, [Rate Per Mile], [Min Charge], CUR_RPM, AllInCost, Rank_Num, Rank, @Today, CONVERT(Date,'12/31/2999'), @Today, @Now 
FROM ##tblLanesAndRatesTemp
ORDER BY LANEID, SCAC ASC

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

END
