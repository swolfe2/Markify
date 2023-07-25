/*
Insert from temp table to BidAppLanesRFP

DELETE FROM USCTTDEV.dbo.tblBidAppLanesRFP2020
*/
INSERT INTO USCTTDEV.dbo.tblBidAppLanesRFP2020 (LaneID, Lane, OriginGroup, OriginCountry, ORIG_CITY_STATE, Origin, OriginZip,
DestCountry, DEST_CITY_STATE, Dest, DestZip, MILES, BID_LOADS, UPDATED_LOADS, 
PrimaryCustomer, PrimaryUnloadType, [Order Type], EffectiveDate, ExpirationDate, BusinessUnit)
SELECT DISTINCT rfpt.LaneID, rfpt.Lane, rfpt.OriginGroup, rfpt.OriginCountry, rfpt.ORIG_CITY_STATE, rfpt.Origin, rfpt.OriginZip, 
rfpt.DestCountry, rfpt.DEST_CITY_STATE, rfpt.Dest, rfpt.DestZip, rfpt.PCMilerMiles, rfpt.BID_LOADS, rfpt.UPDATED_LOADS,
rfpt.PrimaryCustomer, rfpt.PrimaryUnloadType, rfpt.[Order Type], rfpt.EffectiveDate, rfpt.ExpirationDate, rfpt.BusinessUnit
FROM USCTTDEV.dbo.tblBidAppLanesRFP2020Temp rfpt
ORDER BY rfpt.LaneID ASC
/*
Insert into Bid App Rates from temp table
*/
INSERT INTO USCTTDEV.dbo.tblBidAppRatesRFP2020(LaneID, ORIG_CITY_STATE, DEST_CITY_STATE, Lane, Equipment, SCAC, Mode, ACTIVE_FLAG, Confirmed, Service, Origin, Dest, EffectiveDate, ExpirationDate,
[Rate Per Mile], [Min Charge], CUR_RPM, ChargeType, Rank_Num, AllInCost, FMIC, AWARD_LDS, AWARD_PCT)
SELECT DISTINCT rt.LaneID, rt.ORIG_CITY_STATE, rt.DEST_CITY_STATE, rt.Lane, rt.Equipment, rt.SCAC, CASE WHEN rt.Equipment = '53IM' THEN 'IM' ELSE 'T' END AS Mode, 'N' AS ACTIVE_FLAG, 'N' AS Confirmed, rt.Service,
rt.Origin, rt.Dest, rt.EffectiveDate, rt.ExpirationDate, 
CAST(CASE WHEN rt.[Min Charge] IS NOT NULL THEN ROUND(rt.[Min Charge] / rt.PCMilerMiles,2)
WHEN rt.Equipment = '53IM' THEN rt.CUR_RPM - .15 ELSE rt.CUR_RPM END AS NUMERIC(18,2)) AS [Rate Per Mile], 
CAST(rt. [Min Charge] AS NUMERIC(18,2)) AS [Min Charge], 
CAST(rt.CUR_RPM AS NUMERIC(18,2)) AS CUR_RPM, CASE WHEN rt.[Min Charge] IS NOT NULL THEN 'Flat Rate' ELSE 'Rate Per Mile' END AS ChargeType,
CAST(rt.Rank AS INT) AS Rank, CAST(CASE WHEN rt.[Min Charge] IS NOT NULL THEN rt.[Min Charge] ELSE ROUND(rt.CUR_RPM * rt.PCMilerMiles,2) END AS NUMERIC(18,2)) AS AllInCost,
CAST(ROUND(CASE WHEN rt.Equipment = '53IM' THEN rt.FMICIM ELSE rt.FMICOTR END / PCMilerMiles,2) AS NUMERIC (18,2)) AS FMIC,
rt.[Allocation (Shipments)] AS AWARD_LDS, CAST(ROUND(rt.[Allocation (Shipments)] / UPDATED_LOADS,2) AS NUMERIC(18,4)) AS AWARD_PCT
FROM USCTTDEV.dbo.tblBidAppRatesRFP2020Temp rt
WHERE rt.SCAC <> '-'
ORDER BY rt.LaneID ASC, CAST(rt.Rank AS INT) ASC


/*
Add missing GAATL lanes
*/
INSERT INTO USCTTDEV.dbo.tblBidAppRatesRFP2020 (ORIG_CITY_STATE, DEST_CITY_STATE, Lane, Equipment, SCAC, Mode, AWARD_PCT, AWARD_LDS, ACTIVE_FLAG, Confirmed, Service, Origin, Dest, EffectiveDate, ExpirationDate, [Rate Per Mile], CUR_RPM, Rank_Num, ChargeType, AllInCost, FMIC)
SELECT bar.ORIG_CITY_STATE, bar.DEST_CITY_STATE, bar.Lane, bar.Equipment, bar.SCAC, bar.Mode, bar.AWARD_PCT, bar.AWARD_LDS, 'N', 'N', bar.Service, bar.Origin, bar.Dest, bar.EffectiveDate, bar.ExpirationDate, bar.[Rate Per Mile], bar.CUR_RPM, bar.Rank_Num, bar.ChargeType, bar.AllInCost, bar.FMIC
FROM USCTTDEV.dbo.tblBidAppRates bar
LEFT JOIN USCTTDEV.dbo.tblBidAppRatesRFP2020 rfp ON rfp.Lane = bar.Lane
WHERE bar.ORIG_CITY_STATE LIKE 'GAATL%'
AND rfp.Lane IS NULL
and bar.LaneID > 2000
ORDER BY bar.LaneID ASC

/*
Update missing LaneID's
*/
UPDATE USCTTDEV.dbo.tblBidAppRatesRFP2020
SET LaneID = bal.LaneID
FROM USCTTDEV.dbo.tblBidAppRatesRFP2020 bart
INNER JOIN USCTTDEV.dbo.tblBidAppLanesRFP2020 bal ON bal.Lane = bart.Lane
WHERE bart.LaneID IS NULL

/*
Duplicate Lane Check
*/
SELECT DISTINCT Lane, COUNT(*) AS Count
FROM USCTTDEV.dbo.tblBidAppLanesRFP2020
GROUP BY Lane
HAVING COUNT(*) > 1

/*
Duplicate Rate Check
*/
SELECT DISTINCT Lane, SCAC, COUNT(*) AS COUNT
FROM USCTTDEV.dbo.tblBidAppRatesRFP2020
GROUP BY Lane, SCAC
HAVING COUNT(*) <> 1

/*
Ensure LaneIDs have correct values
*/
SELECT * 
FROM USCTTDEV.dbo.tblBidAppLanesRFP2020 bal
INNER JOIN USCTTDEV.dbo.tblBidAppRatesRFP2020 bar ON bar.Lane = bal.Lane
WHERE bal.LaneID <> bar.LaneID

/*
Update ChargeType String
*/
UPDATE USCTTDEV.dbo.tblBidAppRatesRFP2021
SET LY_VOL = bardos.AWARD_LDS,
LY_RPM = CASE WHEN bar.[Min Charge] IS NOT NULL THEN bar.[Min Charge] ELSE bar.CUR_RPM END
FROM USCTTDEV.dbo.tblBidAppRatesRFP2021 bar
INNER JOIN USCTTDEV.dbo.tblBidAppRates bardos ON bardos.Lane = bar.Lane
AND bardos.SCAC = bar.SCAC

/*
Update where Bid App Rates award sum is higher than updated loads
*/
UPDATE USCTTDEV.dbo.tblBidAppLanesRFP2021
SET UPDATED_LOADS = bar.AwardLoadSum
FROM USCTTDEV.dbo.tblBidAppLanesRFP2021 bal
INNER JOIN (
SELECT DISTINCT bal.laneID, bal.Lane, bal.UPDATED_LOADS, CAST(SUM(bar.AWARD_LDS) AS INT) AS AwardLoadSum
FROM USCTTDEV.dbo.tblBidAppLanesRFP2021 bal
INNER JOIN USCTTDEV.dbo.tblBidAppRatesRFP2021 bar ON bar.LaneID = bal.LaneID
GROUP BY bal.laneID, bal.Lane, bal.UPDATED_LOADS
) bar ON bar.LaneID = bal.LaneID
WHERE bar.AwardLoadSum > bal.UPDATED_LOADS

/*
Update Bid App Lanes Comment
*/
UPDATE USCTTDEV.dbo.tblBidAppLanesRFP2021
SET COMMENT = 'Coupa Lane Award: ' + FORMAT( bar.AwardLoadSum / CAST(bal.UPDATED_LOADS AS NUMERIC(18,2)), 'P0') + ' - Loads: ' + FORMAT(bar.AwardLoadSum, 'N0')
FROM USCTTDEV.dbo.tblBidAppLanesRFP2021 bal
INNER JOIN (
SELECT DISTINCT bal.laneID, bal.Lane, bal.UPDATED_LOADS, CAST(SUM(bar.AWARD_LDS) AS INT) AS AwardLoadSum
FROM USCTTDEV.dbo.tblBidAppLanesRFP2021 bal
INNER JOIN USCTTDEV.dbo.tblBidAppRatesRFP2021 bar ON bar.LaneID = bal.LaneID
GROUP BY bal.laneID, bal.Lane, bal.UPDATED_LOADS
) bar ON bar.LaneID = bal.LaneID
WHERE bar.AwardLoadSum IS NOT NULL

/*
Update Historical Loads
*/
UPDATE USCTTDEV.dbo.tblBidAppLanesRFP2021
SET HISTORICAL_LOADS = baldos.AwardLds
FROM USCTTDEV.dbo.tblBidAppLanesRFP2021 bal
INNER JOIN (SELECT DISTINCT Lane, SUM(AWARD_LDS) AS AwardLds FROM USCTTDEV.dbo.tblBidAppRates bar GROUP BY bar.Lane) baldos ON baldos.Lane = bal.Lane

/*
Update Bid App Rates Comment
*/
UPDATE USCTTDEV.dbo.tblBidAppRatesRFP2021
SET COMMENT = 'Coupa Award - PCT: ' + FORMAT(AWARD_PCT,'P0') + ' / Loads: ' + FORMAT(AWARD_LDS, 'N0')
WHERE AWARD_PCT IS NOT NULL

/*
Set Bid RPM
*/
UPDATE USCTTDEV.dbo.tblBidAppRatesRFP2021
SET BID_RPM = CASE WHEN ChargeType = 'Rate Per Mile' THEN CUR_RPM ELSE [Min Charge] END

/*
Check Lane Award vs. Sum
*/
SELECT bal.UPDATED_LOADS, bar.SCAC, bar.AWARD_PCT, bar.AWARD_LDS
FROM USCTTDEV.dbo.tblBidAppLanesRFP2021 bal
INNER JOIN USCTTDEV.dbo.tblBidAppRatesRFP2021 bar On bar.LaneID = bal.LaneID
WHERE bar.AWARD_PCT IS NOT NULL
AND bal.Lane = 'ARCONWAY-5CT06776'

/*
[Forms].[frmDashboard].[cboAnalysisType]
txtAnalysisType
ChangeTable
" & RateTable & " " & _
" & LaneTable & " " & _
*/

'Get Lane/Rate tables
Dim AnalysisType As String, LaneTable As String, RateTable As String
AnalysisType = Forms!frmLaneAnalysis!txtAnalysisType
    If AnalysisType = "2021 RFP Analysis" Then
        LaneTable = "tblBidAppLanesRFP2021"
        RateTable = "tblBidAppRatesRFP2021"
            Else
        LaneTable = "tblBidAppLanes"
        RateTable = "tblBidAppRates"
    End If

'Set the table names that will be used in Passthrough Queries
Dim AnalysisType As String, GoodLaneTable As String, GoodRateTable, BadLaneTable As String, BadRateTable As String, GoodEffectiveDate As String, BadEffectiveDate As String
AnalysisType = Forms!frmLaneAnalysis!txtAnalysisType
If AnalysisType = "2021 RFP Analysis" Then
    GoodLaneTable = "USCTTDEV.dbo.tblBidAppLanesRFP2021 bal"
    GoodRateTable = "USCTTDEV.dbo.tblBidAppRatesRFP2021 bar"
    GoodEffectiveDate = "CAST ('2/10/2021' AS Date) AS EffectiveDate"
    BadLaneTable = "USCTTDEV.dbo.tblBidAppLanes bal"
    BadRateTable = "USCTTDEV.dbo.tblBidAppRates bar"
    BadEffectiveDate = "CAST ('2/10/2020' AS Date) AS EffectiveDate"
Else
    GoodLaneTable = "USCTTDEV.dbo.tblBidAppLanes bal"
    GoodRateTable = "USCTTDEV.dbo.tblBidAppRates bar"
    GoodEffectiveDate = "CAST ('2/10/2020' AS Date) AS EffectiveDate"
    BadLaneTable = "USCTTDEV.dbo.tblBidAppLanesRFP2021 bal"
    BadRateTable = "USCTTDEV.dbo.tblBidAppRatesRFP2021 bar"
    BadEffectiveDate = "CAST ('2/10/2021' AS Date) AS EffectiveDate"
End If

'Replace QueryDef with Good Lane Table
sSql = Replace(sSql, BadLaneTable, GoodLaneTable)

'Replace QueryDef with Good Rate Table
sSql = Replace(sSql, BadRateTable, GoodRateTable)

'Replace QueryDef with Good Effective Date
sSql = Replace(sSql, BadEffectiveDate, GoodEffectiveDate)

/*

*/


/*
SELECT TOP 20 * FROM USCTTDEV.dbo.tblBidAppLanesRFP2021 WHERE Lane = 'ALFAIRHO-5AL36610'
SELECT TOP 20 * FROM USCTTDEV.dbo.tblBidAppRatesRFP2021 WHERE Lane = 'ALFAIRHO-5AL36610'
SELECT TOP 20 * FROM USCTTDEV.dbo.tblBidAppLanes WHERE Lane = 'ALFAIRHO-5AL36610'
SELECT TOP 20 * FROM USCTTDEV.dbo.tblBidAppRates WHERE Lane = 'ALFAIRHO-5AL36610'
*/
SELECT DISTINCT bal.LaneID,
bal.Lane,
bar.SCAC,
CAST(bal.MILES AS NUMERIC(18,2)) Miles,
CAST(bal.HISTORICAL_LOADS AS INT) AS LY_LANE_VOL,
CAST(LY_VOL AS INT) LY_VOL,
CAST(ROUND(CAST(bal.HISTORICAL_LOADS AS NUMERIC(18,2)) /  CAST(LY_VOL AS INT),2) AS NUMERIC(18,2)) AS LY_AWARD_PCT,
CAST(LY_RPM AS NUMERIC(18,2)) LY_RPM,
CAST((ROUND(CAST(LY_RPM AS NUMERIC(18,2)) * CAST(bal.Miles AS NUMERIC(18,2)) * LY_VOL,2)) AS NUMERIC(18,2)) AS LY_COST,
bal.BID_LOADS AS TY_LANE_BID_VOL,
bar.BID_AWARD_LDS AS TY_BID_VOL,
CAST(ROUND(CAST(bal.BID_LOADS AS NUMERIC(18,2)) /  CAST(bar.BID_AWARD_LDS AS INT),2) AS NUMERIC(18,2)) AS TY_BID_AWARD_PCT,
CAST(bar.BID_RPM AS NUMERIC(18,2)) AS TY_BID_RPM
FROM USCTTDEV.dbo.tblBidAppRatesRFP2021 bar
INNER JOIN USCTTDEV.dbo.tblBIdAppLanesRFP2021 bal ON bal.LaneID = bar.LaneID

GROUP BY  bal.LaneID,
bal.Lane,
bar.SCAC,
CAST(bal.MILES AS NUMERIC(18,2)),
CAST(bal.HISTORICAL_LOADS AS INT),
CAST(LY_VOL AS INT),
CAST(ROUND(CAST(bal.HISTORICAL_LOADS AS NUMERIC(18,2)) /  CAST(LY_VOL AS INT),2) AS NUMERIC(18,2)),
CAST(LY_RPM AS NUMERIC(18,2)),
CAST((ROUND(CAST(LY_RPM AS NUMERIC(18,2)) * CAST(bal.Miles AS NUMERIC(18,2)) * LY_VOL,2)) AS NUMERIC(18,2)),
bal.BID_LOADS,
bar.BID_AWARD_LDS,
CAST(ROUND(CAST(bal.BID_LOADS AS NUMERIC(18,2)) /  CAST(bar.BID_AWARD_LDS AS INT),2) AS NUMERIC(18,2)),
CAST(bar.BID_RPM AS NUMERIC(18,2))

ORDER BY bal.LaneID ASC, bar.SCAC ASC