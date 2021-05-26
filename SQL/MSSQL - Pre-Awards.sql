DECLARE
@CompBeg AS Date,
@CompEnd AS DateTime,
@ServBeg AS Date,
@ServEnd AS DateTime
SET @CompBeg = '2/1/2021'
SET @CompEnd = GETDATE()
SET @ServBeg = '2/1/2021'
SET @ServEnd = GETDATE()
SELECT cs.Lane,
bal.Origin,
bal.Dest,
bal.PrimaryCustomer,
ca.CARR_CD AS CarrierCode,
ca.Name AS CarrierName,
cs.SCAC AS ServiceCode,
ca.SRVC_DESC AS SCACName,
ca.Broker,
ca.LiveLoad,
ca.Dedicated,
ca.NewOrIncumbent,
ca.CoupaDescription,
bar.AWARD_PCT AS BidAppAwardPercent,
bar.EQUIPMENT AS Equipment,
CASE WHEN bar.[Min Charge] IS NOT NULL THEN 'Min Charge' ELSE 'RPM' END AS RateType,
CASE WHEN bar.[Min Charge] IS NOT NULL THEN bar.[Min Charge] ELSE bar.CUR_RPM END AS Rate,
bar.[Rate Per Mile] AS AdjustedRPM,
carrierService.MinShipDate,
carrierService.MaxShipDate,
SUM(AcceptsComplianceCalculated) AS AcceptsComplianceCalculated,
SUM(SurgeComplianceCalculated) AS SurgeComplianceCalculated,
TRY_CONVERT(decimal (3, 2), SUM(cs.AcceptsComplianceCalculated)/1.0/SUM(cs.SurgeComplianceCalculated)/1.0,3) as CarrierLaneCompliance,
laneCompliance.OverallLaneCompliance,
CASE WHEN fmic.Lane IS NULL THEN 'No FMIC' ELSE 'FMIC' END AS FMICType,
fmic.LowLinehaulRatePerMile AS FMICLowLinehaulRPM,
fmic.FairLinehaulRatePerMile AS FMICFairLinehaulRPM,
fmic.HighLinehaulRatePerMile AS HighLinehaulRPM,
fmic.ModelAppliedtoDetermineEstimate AS FMICModelUsed,
CASE WHEN carrierService.Lane IS NULL THEN 'No Carrier Service' ELSE 'Carrier Service' END AS CarrierServiceType,
carrierService.AvgMiles AS CarrierAvgMiles,
carrierService.ActualRPM AS CarrierActRPM,
carrierService.Early AS CarrierEarly,
carrierService.OnTime AS CarrierOnTime,
carrierService.Lates AS CarrierLates,
carrierService.Deliveries AS Deliveries,
carrierService.CarrierOnTimePct,
CASE WHEN laneService.Lane IS NULL THEN 'No Lane Service' ELSE 'Lane Service' END AS LaneServiceType,
laneService.LaneOnTimePct
/*
Base query is going to include compliance summary, joined to the Bid App tables
*/
FROM USCTTDEV.dbo.tblComplianceSummary cs
INNER JOIN USCTTDEV.dbo.tblBidAppLanes bal ON bal.Lane = cs.Lane
LEFT JOIN USCTTDEV.dbo.tblBidAppRates bar ON bar.LaneID = bal.LaneiD
AND bar.SCAC = cs.SCAC
/*
Get the overall lane compliance, regardless of the carrier
*/
INNER JOIN (
SELECT cs.Lane,
TRY_CONVERT(decimal (3, 2), SUM(cs.AcceptsComplianceCalculated)/1.0/SUM(cs.SurgeComplianceCalculated)/1.0,3) as OverallLaneCompliance
FROM USCTTDEV.dbo.tblComplianceSummary cs
WHERE
CAST(cs.WeekBeginning AS DATE) between CAST(@CompBeg AS DATE) and CAST(@CompEnd AS DATE)
AND cs.CarrierAwarded = 'Y'
AND cs.SurgeComplianceCalculated > 0
GROUP BY cs.Lane) laneCompliance ON laneCompliance.Lane = bal.Lane
/*
Get the most recent FMIC data
*/
LEFT JOIN 
    (SELECT
        f2.*
    FROM
        (SELECT
            f.*,
            RANK() OVER (PARTITION BY f.LANE ORDER BY f.DateAdded DESC) AS RANK
        FROM
            USCTTDEV.dbo.tblFMICHistorical f
        WHERE
            f.ResultStatus not like 'Model not supported%') f2
    WHERE
        f2.Rank = 1) fmic
ON bal.Lane = fmic.Lane
AND (CASE WHEN bar.EQUIPMENT = '53IM' THEN 'IC' ELSE 'DV' END) = fmic.Mode
/*
Get information about the specific carrier
*/
LEFT JOIN USCTTDEV.dbo.tblCarriers ca ON ca.SRVC_CD = cs.SCAC
AND ca.CARR_CD = cs.Carrier
/*
Get the individual carrier's service on the lane
*/
LEFT JOIN (
SELECT
om.CARR_CD,
om.SRVC_CD,
ald.EQMT_TYP,
ald.Lane,
CAST(MIN(ald.SHPD_DTT) AS DATE) AS MinShipDate,
CAST(MAX(ald.SHPD_DTT) AS DATE) AS MaxShipDate,
ROUND(AVG(ald.FIXD_ITNR_DIST),2) AS AvgMiles,
ROUND(SUM(ald.act_linehaul)/SUM(ald.FIXD_ITNR_DIST),2) AS ActualRPM,
SUM(CAPS_EARLY_STOP_CNT) AS Early,
SUM(CAPS_ONTIME_STOP_CNT) AS OnTime,
SUM(CAPS_LATE_STOP_CNT) AS Lates,
SUM(CAPS_DELIVERED_STOP_CNT) AS Deliveries,
TRY_CONVERT(DECIMAL (3,2), SUM(CAPS_EARLY_STOP_CNT + CAPS_ONTIME_STOP_CNT)/1.0/SUM(CAPS_DELIVERED_STOP_CNT)/1.0) AS CarrierOnTimePct
FROM    USCTTDEV.dbo.tblOperationalMetrics om
INNER JOIN USCTTDEV.dbo.tblActualLoadDetail ald ON  om.LD_LEG_ID = ald.LD_LEG_ID
WHERE
CAST(ald.shpd_dtt AS DATE) BETWEEN CAST(@ServBeg AS DATE) AND CAST(@ServEnd AS DATE)
AND om.eqmt_typ <> 'ltl'
AND om.CAPS_DELIVERED_STOP_CNT > 0
GROUP BY
om.CARR_CD,
om.SRVC_CD,
ald.EQMT_TYP,
ald.Lane
) carrierService ON carrierService.Lane = cs.Lane
AND carrierService.SRVC_CD = cs.SCAC
AND carrierService.CARR_CD = cs.Carrier
AND carrierService.EQMT_TYP = bar.EQUIPMENT
/*
Get the overall lane service
*/
LEFT JOIN (
SELECT
ald.Lane,
ROUND(AVG(ald.FIXD_ITNR_DIST),2) AS AvgMiles,
ROUND(SUM(ald.act_linehaul)/SUM(ald.FIXD_ITNR_DIST),2) AS ActualRPM,
SUM(CAPS_EARLY_STOP_CNT) AS Early,
SUM(CAPS_ONTIME_STOP_CNT) AS OnTime,
SUM(CAPS_LATE_STOP_CNT) AS Lates,
SUM(CAPS_DELIVERED_STOP_CNT) AS Deliveries,
TRY_CONVERT(DECIMAL (3,2), SUM(CAPS_EARLY_STOP_CNT + CAPS_ONTIME_STOP_CNT)/1.0/SUM(CAPS_DELIVERED_STOP_CNT)/1.0) AS LaneOnTimePct
FROM    USCTTDEV.dbo.tblOperationalMetrics om
INNER JOIN USCTTDEV.dbo.tblActualLoadDetail ald ON  om.LD_LEG_ID = ald.LD_LEG_ID
WHERE
CAST(ald.shpd_dtt AS DATE) BETWEEN CAST(@ServBeg AS DATE) AND CAST(@ServEnd AS DATE)
AND om.eqmt_typ <> 'ltl'
AND om.CAPS_DELIVERED_STOP_CNT > 0
GROUP BY
ald.Lane
) laneService ON laneService.Lane = cs.Lane
/*
Filter to only where the carrier was awarded some on the lane, between the dates
*/
WHERE
CAST(cs.WeekBeginning AS DATE) between CAST(@CompBeg AS DATE) and CAST(@CompEnd AS DATE)
AND cs.CarrierAwarded = 'Y'
AND cs.SurgeComplianceCalculated > 0
GROUP BY cs.Lane,
bal.Origin,
bal.Dest,
bal.PrimaryCustomer,
ca.CARR_CD,
ca.Name,
cs.SCAC,
ca.SRVC_DESC,
ca.Broker,
ca.LiveLoad,
ca.Dedicated,
ca.NewOrIncumbent,
ca.CoupaDescription,
bar.AWARD_PCT,
laneCompliance.OverallLaneCompliance,
bar.EQUIPMENT,
CASE WHEN bar.[Min Charge] IS NOT NULL THEN 'Min Charge' ELSE 'RPM' END,
CASE WHEN bar.[Min Charge] IS NOT NULL THEN bar.[Min Charge] ELSE bar.CUR_RPM END,
bar.[Rate Per Mile],
CASE WHEN fmic.Lane IS NULL THEN 'No FMIC' ELSE 'FMIC' END,
fmic.LowLinehaulRatePerMile,
fmic.FairLinehaulRatePerMile,
fmic.HighLinehaulRatePerMile,
fmic.ModelAppliedtoDetermineEstimate,
CASE WHEN carrierService.Lane IS NULL THEN 'No Carrier Service' ELSE 'Carrier Service' END,
carrierService.MinShipDate,
carrierService.MaxShipDate,
carrierService.AvgMiles,
carrierService.ActualRPM,
carrierService.Early,
carrierService.OnTime,
carrierService.Lates,
carrierService.Deliveries,
carrierService.CarrierOnTimePct,
CASE WHEN laneService.Lane IS NULL THEN 'No Lane Service' ELSE 'Lane Service' END,
laneService.LaneOnTimePct
ORDER BY cs.Lane ASC, cs.SCAC ASC, TRY_CONVERT(DECIMAL (3, 2), SUM(cs.AcceptsComplianceCalculated)/1.0/SUM(cs.SurgeComplianceCalculated)/1.0,3)  DESC