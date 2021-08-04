/*
Declare variables
*/
DECLARE @DefaultIMRate NUMERIC(10,2),
@DefaultTLRate NUMERIC(10,2),
@DefaultCapacity NUMERIC(10,2)

/*
Set variables
*/
SET @DefaultIMRate = 1.50
SET @DefaultTLRate = 2.00
SET @DefaultCapacity = 5.1

/*
If no awards are found for TF/TL, return 0 for all values but use default rates to create costs
*/
SELECT
    DISTINCT
    bal.LaneID,
    bal.Lane,
    ra.Region,
    bal.Origin,
    bal.ORIG_CITY_STATE AS OriginZone,
    bal.OriginZip,
    bal.Dest,
    bal.DEST_CITY_STATE AS DestZone,
    bal.DestZip,
    CAST(bal.Miles AS NUMERIC(10,2)) AS Miles,
    CASE WHEN IMAwards.IMAwardCount IS NOT NULL THEN 'Y' ELSE 'N' END AS IMAwarded,
    COALESCE(IMAwards.IMAwardCount,0) AS IMAwardCount,
    COALESCE(IMAwards.IMAwardPct,0) AS IMAwardPct,
    COALESCE(IMAwards.IMAwardAnnualLds,0) AS IMAwardAnnualLds,
    COALESCE(IMAwards.IMAwardWeeklyLds,0) AS IMAwardWeeklyLds,
    COALESCE(IMAwards.IMAwardWeeklyLdsSurge,0) AS IMAwardWeeklyLdsSurge,
    CASE WHEN IMAwards.IMWeightedRPM IS NULL THEN @DefaultIMRate ELSE IMAwards.IMWeightedRPM END AS IMWeightedRPM,
    CASE WHEN IMAwards.IMWeightedAdjustedRPM IS NULL THEN @DefaultIMRate ELSE IMAwards.IMWeightedAdjustedRPM END AS IMWeightedAdjustedRPM,
    CAST(ROUND(CASE WHEN IMAwards.IMWeightedAdjustedRPM IS NULL THEN @DefaultIMRate ELSE IMAwards.IMWeightedAdjustedRPM END * bal.Miles,2) AS NUMERIC(10,2)) AS BaseIMAwardLoadCost,
    CAST(ROUND(CASE WHEN IMAwards.IMWeightedAdjustedRPM IS NULL THEN @DefaultIMRate ELSE IMAwards.IMWeightedAdjustedRPM END * bal.Miles,2) AS NUMERIC(10,2)) AS BaseIMAwardAdjLoadCost,
    CASE WHEN TLAwards.TLAwardCount IS NOT NULL THEN 'Y' ELSE 'N' END AS TLAwarded,
    COALESCE(TLAwards.TLAwardCount,0) AS TLAwardCount,
    COALESCE(TLAwards.TLAwardPct,0) AS TLAwardPct,
    COALESCE(TLAwards.TLAwardAnnualLds,0) AS TLAwardAnnualLds,
    COALESCE(TLAwards.TLAwardWeeklyLds,0) AS TLAwardWeeklyLds,
    COALESCE(TLAwards.TLAwardWeeklyLdsSurge,0) AS TLAwardWeeklyLdsSurge,
    COALESCE(TLAwards.TLWeightedRPM,0) AS TLWeightedRPM,
    COALESCE(TLAwards.TLWeightedAdjustedRPM,0) AS TLWeightedAdjustedRPM,
    CAST(ROUND(CASE WHEN TLAwards.TLWeightedRPM IS NULL THEN @DefaultTLRate ELSE TLAwards.TLWeightedRPM END * bal.Miles,2) AS NUMERIC(10,2)) AS BaseTLAwardLoadCost,
    CAST(ROUND(CASE WHEN TLAwards.TLWeightedAdjustedRPM IS NULL THEN @DefaultTLRate ELSE TLAwards.TLWeightedAdjustedRPM END * bal.Miles,2) AS NUMERIC(10,2)) AS BaseTLAwardAdjLoadCost


/*
Use Bid App Lanes as base table
*/
FROM
    USCTTDEV.dbo.tblBidAppLanes bal

    /*
Join rates table by LaneID
*/
    INNER JOIN USCTTDEV.dbo.tblBidAppRates bar ON bar.LaneID = bal.laneID

    /*
Join regional assignments by standard logic to get Region
*/
    LEFT JOIN USCTTDEV.dbo.tblRegionalAssignments ra
    ON ( ra.StateAbbv = 
    CASE WHEN bal.[order type] LIKE '%INBOUND%' AND bal.BusinessUnit <> 'NON WOVENS' THEN
		REPLACE(REVERSE(LEFT(REVERSE(bal.Dest), CHARINDEX(',', REVERSE(bal.Dest)) -1)), ' ','')
        ELSE
        REPLACE(REVERSE(LEFT(REVERSE(bal.Origin), CHARINDEX(',', REVERSE(bal.Origin)) -1)), ' ','')
    END)

    /*
Join aggregate award information for Intermodal
*/
    LEFT JOIN (
SELECT
        DISTINCT
        bar.LaneID,
        bar.Lane,
        COUNT(DISTINCT bar.SCAC) AS IMAwardCount,
        SUM(bar.AWARD_PCT) AS IMAwardPct,
        SUM(bar.AWARD_LDS) AS IMAwardAnnualLds,
        CASE WHEN SUM(bar.AWARD_LDS) < 52 THEN 1 ELSE CAST(ROUND(SUM(CAST(bar.AWARD_LDS AS NUMERIC(10,2))) / 52,0) AS INT) END AS IMAwardWeeklyLds,
        CASE WHEN (SUM(bar.AWARD_LDS) * 1.15) < 52 THEN 1 ELSE CAST(ROUND((SUM(CAST(bar.AWARD_LDS AS NUMERIC(10,2))) * 1.15) / 52,0) AS INT) END AS IMAwardWeeklyLdsSurge,
        CAST(ROUND(SUM(bar.AWARD_PCT * bar.CUR_RPM) /SUM(bar.AWARD_PCT),2) AS NUMERIC(10,2)) AS IMWeightedRPM,
        CAST(ROUND(SUM(bar.AWARD_PCT * bar.[Rate Per Mile]) /SUM(bar.AWARD_PCT),2) AS NUMERIC(10,2)) AS IMWeightedAdjustedRPM
    FROM
        USCTTDEV.dbo.tblBidAppRates bar
    WHERE bar.AWARD_PCT IS NOT NULL
        AND bar.EQUIPMENT = '53IM'
    GROUP BY bar.LaneID,
bar.Lane
) IMAwards ON IMAwards.LaneID = bal.LaneID

    /*
Join aggregate award information for non-Intermodal
THIS IS FOR ANY AWARD EQUIPMENT NOT 53IM
*/
    LEFT JOIN (
SELECT
        DISTINCT
        bar.LaneID,
        bar.Lane,
        COUNT(DISTINCT bar.SCAC) AS TLAwardCount,
        SUM(bar.AWARD_PCT) AS TLAwardPct,
        SUM(bar.AWARD_LDS) AS TLAwardAnnualLds,
        CASE WHEN SUM(bar.AWARD_LDS) < 52 THEN 1 ELSE CAST(ROUND(SUM(CAST(bar.AWARD_LDS AS NUMERIC(10,2))) / 52,0) AS INT) END AS TLAwardWeeklyLds,
        CASE WHEN (SUM(bar.AWARD_LDS) * 1.15) < 52 THEN 1 ELSE CAST(ROUND((SUM(CAST(bar.AWARD_LDS AS NUMERIC(10,2))) * 1.15) / 52,0) AS INT) END AS TLAwardWeeklyLdsSurge,
        CAST(ROUND(SUM(bar.AWARD_PCT * bar.CUR_RPM) /SUM(bar.AWARD_PCT),2) AS NUMERIC(10,2)) AS TLWeightedRPM,
        CAST(ROUND(SUM(bar.AWARD_PCT * bar.[Rate Per Mile]) /SUM(bar.AWARD_PCT),2) AS NUMERIC(10,2)) AS TLWeightedAdjustedRPM
    FROM
        USCTTDEV.dbo.tblBidAppRates bar
    WHERE bar.AWARD_PCT IS NOT NULL
        AND bar.EQUIPMENT <> '53IM'
    GROUP BY bar.LaneID,
bar.Lane
) TLAwards ON TLAwards.LaneID = bal.LaneID

WHERE bal.Dest IS NOT NULL
    AND bal.Origin IS NOT NULL
--AND bal.Lane = 'ALMOBILE-5CA91761'

GROUP BY bal.LaneID,
bal.Lane,
ra.Region,
bal.Origin,
bal.ORIG_CITY_STATE,
bal.OriginZip,
bal.Dest,
bal.DEST_CITY_STATE,
bal.DestZip,
bal.Miles,
IMAwards.IMAwardCount,
IMAwards.IMAwardPct,
IMAwards.IMAwardAnnualLds,
IMAwards.IMAwardWeeklyLds,
IMAwards.IMAwardWeeklyLdsSurge,
IMAwards.IMWeightedRPM,
IMAwards.IMWeightedAdjustedRPM,
TLAwards.TLAwardCount,
TLAwards.TLAwardPct,
TLAwards.TLAwardAnnualLds,
TLAwards.TLAwardWeeklyLds,
TLAwards.TLAwardWeeklyLdsSurge,
TLAwards.TLWeightedRPM,
TLAwards.TLWeightedAdjustedRPM
ORDER BY bal.LaneID ASC