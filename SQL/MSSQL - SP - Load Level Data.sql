USE [USCTTDEV]
GO
/****** Object:  StoredProcedure [dbo].[sp_LoadLevelData]    Script Date: 8/4/2021 10:28:11 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
-- =============================================
-- Author:		Steve Wolfe, steve.wolfe@kcc.com, Central Transportation Team
-- Create date: 8/4/2021
-- Last modified: 
-- 
-- Description:	Creates dataset for Load Level Data / Project Earl
There are default variables, which are used to help run things later in the process.
The most likely one to be changed will be @DefaultCapacity and @DefaultLoadCost
-- =============================================
*/
ALTER PROCEDURE [dbo].[sp_LoadLevelData]

AS
BEGIN
    /*
Declare variables
*/
    DECLARE @DefaultIMRate NUMERIC(10,2),
@DefaultTLRate NUMERIC(10,2),
@PercentageAbove NUMERIC(10,2),
@DefaultCapacity INT,
@DefaultLoadCost NUMERIC(10,2);

    /*
Set variables
*/
    SET @DefaultIMRate = 1.50
    SET @DefaultTLRate = 2.00
    SET @PercentageAbove = .2
    SET @DefaultCapacity = 5
    SET @DefaultLoadCost = 1555.00;

    WITH
        awards
        (
            LaneID,
            Lane,
            Region,
            Origin,
            OriginZone,
            OriginZip,
            Dest,
            DestZone,
            DestZip,
            Miles,
            IMAwarded,
            IMAwardCount,
            IMAwardPct,
            IMAwardAnnualLds,
            IMAwardWeeklyLds,
            IMAwardWeeklyLdsSurge,
            IMWeightedRPM,
            IMWeightedAdjustedRPM,
            BaseIMAwardLoadCost,
            BaseIMAwardAdjLoadCost,
            TLAwarded,
            TLAwardCount,
            TLAwardPct,
            TLAwardAnnualLds,
            TLAwardWeeklyLds,
            TLAwardWeeklyLdsSurge,
            TLWeightedRPM,
            TLWeightedAdjustedRPM,
            BaseTLAwardLoadCost,
            BaseTLAwardAdjLoadCost
        )

        AS
        
        (
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
                CASE WHEN TLAwards.TLAwardWeeklyLds IS NULL THEN @DefaultCapacity ELSE COALESCE(TLAwards.TLAwardWeeklyLds,0) END AS TLAwardWeeklyLds,
                CASE WHEN TLAwards.TLAwardWeeklyLds IS NULL THEN @DefaultCapacity ELSE COALESCE(TLAwards.TLAwardWeeklyLdsSurge,0) END AS TLAwardWeeklyLdsSurge,
                CASE WHEN TLAwards.TLWeightedRPM IS NULL THEN @DefaultTLRate ELSE TLAwards.TLWeightedRPM END AS TLWeightedRPM,
                CASE WHEN TLAwards.TLWeightedAdjustedRPM IS NULL THEN @DefaultTLRate ELSE TLAwards.TLWeightedAdjustedRPM END AS TLWeightedAdjustedRPM,
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
        ),

        actuals
        (
            LD_LEG_ID,
            SHPD_DTT,
            FIXD_ITNR_DIST,
            EQMT_TYP,
            BU,
            OrderType,
            RateType,
            AwardLane,
            AwardCarrier,
            Dedicated,
            Lane,
            Region,
            FRST_SHPG_LOC_CD,
            FRST_SHPG_LOC_NAME,
            FRST_PSTL_CD,
            OriginPlant,
            LAST_SHPG_LOC_CD,
            LAST_SHPG_LOC_NAME,
            LAST_PSTL_CD,
            DestinationPlant,
            ChargeType,
            Act_Linehaul,
            Act_RPM,
            BaseAwardCost,
            BaseAwardRPM,
            PercentageFromAward,
            PreferenceMarker
        )
        AS
        
        (
            SELECT
                ald.LD_LEG_ID,
                CAST(ald.SHPD_DTT AS DATE) AS SHPD_DTT,
                ald.FIXD_ITNR_DIST,
                ald.EQMT_TYP,
                ald.BU,
                ald.OrderType,
                ald.RateType,
                ald.AwardLane,
                ald.AwardCarrier,
                ald.Dedicated,
                ald.Lane,
                ald.Region,
                ald.FRST_SHPG_LOC_CD,
                ald.FRST_SHPG_LOC_NAME,
                ald.FRST_PSTL_CD,
                ald.OriginPlant,
                ald.LAST_SHPG_LOC_CD,
                ald.LAST_SHPG_LOC_NAME,
                ald.LAST_PSTL_CD,
                ald.DestinationPlant,
                CASE WHEN ald.ActualRateCharge = 'Yes' THEN 'Actual Charges' ELSE 'Pre-Rate' END AS ChargeType,
                ald.Act_Linehaul,
                CAST(ROUND(ald.Act_Linehaul / ald.FIXD_ITNR_DIST,2) AS NUMERIC(10,2)) AS Act_RPM,
                ROUND(CASE WHEN ald.EQMT_TYP = '53IM' THEN awards.IMWeightedRPM ELSE awards.TLWeightedRPM END * ald.FIXD_ITNR_DIST,2) AS BaseAwardCost,
                CASE WHEN ald.EQMT_TYP = '53IM' THEN awards.IMWeightedRPM ELSE awards.TLWeightedRPM END AS BaseAwardRPM,

                CAST(ROUND(CASE WHEN ald.Act_Linehaul - ROUND(CASE WHEN ald.EQMT_TYP = '53IM' THEN awards.IMWeightedRPM ELSE awards.TLWeightedRPM END * ald.FIXD_ITNR_DIST,2) = 0 THEN 0 
ELSE 
ROUND((ald.Act_Linehaul - ROUND(CASE WHEN ald.EQMT_TYP = '53IM' THEN awards.IMWeightedRPM ELSE awards.TLWeightedRPM END * ald.FIXD_ITNR_DIST,2)),2) / ROUND(CASE WHEN ald.EQMT_TYP = '53IM' THEN awards.IMWeightedRPM ELSE awards.TLWeightedRPM END * ald.FIXD_ITNR_DIST,2) 
END,4) AS NUMERIC(10,4)) AS PercentageFromAward,

                CASE WHEN CAST(ROUND(CASE WHEN ald.Act_Linehaul - ROUND(CASE WHEN ald.EQMT_TYP = '53IM' THEN awards.IMWeightedRPM ELSE awards.TLWeightedRPM END * ald.FIXD_ITNR_DIST,2) = 0 THEN 0 
ELSE 
ROUND((ald.Act_Linehaul - ROUND(CASE WHEN ald.EQMT_TYP = '53IM' THEN awards.IMWeightedRPM ELSE awards.TLWeightedRPM END * ald.FIXD_ITNR_DIST,2)),2) / ROUND(CASE WHEN ald.EQMT_TYP = '53IM' THEN awards.IMWeightedRPM ELSE awards.TLWeightedRPM END * ald.FIXD_ITNR_DIST,2) 
END,4) AS NUMERIC(10,4)) <= @PercentageAbove THEN 'Preferred' 
WHEN ald.Dedicated IS NOT NULL THEN 'Preferred'
ELSE 'NonPrefer' END AS PreferenceMarker

            FROM
                USCTTDEV.dbo.tblActualLoadDetail ald
                INNER JOIN awards ON awards.Lane = ald.Lane
            WHERE ald.EQMT_TYP <> 'LTL'
                AND ald.OrderType = 'INTERMILL'
                AND CAST(ald.SHPD_DTT AS DATE) BETWEEN CAST(GETDATE()-30 AS DATE) AND CAST(GETDATE() AS DATE)
            --AND ald.Lane = 'ARCONWAY-ONMILTON'
        ),

        /*
Get the aggregate load from actuals CTE by lane
*/
        actualsLaneCount
        (
            Lane,
            [Ship Plant],
            [Dest Plant],
            ActLoadCount
        )
        AS
        (
            SELECT
                DISTINCT
                als.Lane,
                LEFT(als.FRST_SHPG_LOC_CD,4) AS [Ship Plant],
                LEFT(als.LAST_SHPG_LOC_CD,4) AS [Dest Plant],
                COUNT(DISTINCT als.LD_LEG_ID) AS ActLoadCount
            FROM
                actuals als
            GROUP BY als.Lane,
LEFT(als.FRST_SHPG_LOC_CD,4),
LEFT(als.LAST_SHPG_LOC_CD,4)
        ),

        actAgg
        (
            [Ship Plant],
            [Dest Plant],
            [Lane],
            [Shipping Condition],
            [PreferenceMarker],
            [Total],
            [TotalShipDays],
            [AveragePerDay],
            [WeeklyBaseCapacity],
            [WeeklySurgeCapacity],
            [DailyBaseCapacity],
            [DailySurgeCapacity],
            [AvgActLinehaul]
        )
        AS
        (
            SELECT
                DISTINCT
                LEFT(actuals.FRST_SHPG_LOC_CD,4) AS 'Ship Plant' ,
                LEFT(actuals.LAST_SHPG_LOC_CD,4) AS 'Dest Plant',
                awards.Lane,
                CASE WHEN actuals.EQMT_TYP = '53IM' THEN 'TF' ELSE 'TL' END AS 'Shipping Condition',
                actuals.PreferenceMarker,
                COUNT(DISTINCT actuals.LD_LEG_ID) AS Total,
                COUNT(DISTINCT actuals.SHPD_DTT) AS TotalShipDays,
                COUNT(DISTINCT actuals.LD_LEG_ID) / COUNT(DISTINCT actuals.SHPD_DTT) AS AveragePerDay,

                /*
Per discussion with Ron Sweet on 7/23, these values need to be daily. I have made it known that this will GREATLY skew the actual award capacity, since CTT awards at a weekly level
*/
                CAST(CASE WHEN CASE WHEN actuals.EQMT_TYP = '53IM' THEN 'TF' ELSE 'TL' END = 'TF' THEN AVG(awards.IMAwardWeeklyLds) ELSE AVG(awards.TLAwardWeeklyLds) END AS NUMERIC(10,1)) AS WeeklyBaseCapacity,
                CAST(CASE WHEN CASE WHEN actuals.EQMT_TYP = '53IM' THEN 'TF' ELSE 'TL' END = 'TF' THEN AVG(awards.IMAwardWeeklyLdsSurge) ELSE AVG(awards.TLAwardWeeklyLdsSurge) END AS NUMERIC(10,1)) AS WeeklySurgeCapacity,
                CAST(ROUND(CASE WHEN CAST(CASE WHEN CASE WHEN actuals.EQMT_TYP = '53IM' THEN 'TF' ELSE 'TL' END = 'TF' THEN AVG(awards.IMAwardWeeklyLds) ELSE AVG(awards.TLAwardWeeklyLds) END AS NUMERIC(10,1)) / 7 < 1 THEN 1 
ELSE CAST(CASE WHEN CASE WHEN actuals.EQMT_TYP = '53IM' THEN 'TF' ELSE 'TL' END = 'TF' THEN AVG(awards.IMAwardWeeklyLdsSurge) ELSE AVG(awards.TLAwardWeeklyLdsSurge) END AS NUMERIC(10,1)) / 7 END,1) AS NUMERIC(10,1)) AS DailyBaseCapacity,
                CAST(ROUND(CASE WHEN CAST(CASE WHEN CASE WHEN actuals.EQMT_TYP = '53IM' THEN 'TF' ELSE 'TL' END = 'TF' THEN AVG(awards.IMAwardWeeklyLds) ELSE AVG(awards.TLAwardWeeklyLds) END AS NUMERIC(10,1)) / 7 < 1 THEN 1 
ELSE CAST(CASE WHEN CASE WHEN actuals.EQMT_TYP = '53IM' THEN 'TF' ELSE 'TL' END = 'TF' THEN AVG(awards.IMAwardWeeklyLdsSurge) ELSE AVG(awards.TLAwardWeeklyLdsSurge) END AS NUMERIC(10,1)) / 7 END,1) AS NUMERIC(10,1)) AS DailySurgeCapacity,
                CAST(ROUND(AVG(actuals.Act_Linehaul),2) AS NUMERIC(10,2)) AS AvgActLinehaul

            FROM
                actuals --866
                INNER JOIN awards ON /*awards.OriginZip = CASE WHEN actuals.Region IN ('CANADA', 'MEXICO') THEN actuals.FRST_PSTL_CD ELSE LEFT(actuals.FRST_PSTL_CD,5) END
AND awards.DestZip = CASE WHEN actuals.Region IN ('CANADA', 'MEXICO') THEN actuals.FRST_PSTL_CD ELSE LEFT(actuals.FRST_PSTL_CD,5) END
AND*/ awards.OriginZone + '-' + awards.DestZone = actuals.Lane
            /*AND LEFT(actuals.FRST_SHPG_LOC_CD,4) = '2023'
AND LEFT(actuals.LAST_SHPG_LOC_CD,4) = '2299'*/
            GROUP BY LEFT(actuals.FRST_SHPG_LOC_CD,4) ,
LEFT(actuals.LAST_SHPG_LOC_CD,4),
awards.Lane,
CASE WHEN actuals.EQMT_TYP = '53IM' THEN 'TF' ELSE 'TL' END,
actuals.PreferenceMarker
        ),

        /*
Union missing NonPrefer by lane/shipment type to actuals
Divide total by aggregate lane volume to get percentage
*/
        final
        (
            [Ship Plant],
            [Dest Plant],
            [Lane],
            [Shipping Condition],
            [PreferenceMarker],
            Total,
            TotalShipDays,
            WeeklyBaseCapacity,
            AvgActLinehaul,
            Type,
            ActLoadCount,
            TotalLaneVolPercent
        )
        AS
        (
            SELECT
                final.[Ship Plant],
                final.[Dest Plant],
                final.Lane,
                final.[Shipping Condition],
                final.PreferenceMarker,
                final.Total,
                final.TotalShipDays,
                final.WeeklyBaseCapacity,
                final.AvgActLinehaul,
                /*final.WeeklySurgeCapacity,
final.DailyBaseCapacity,
final.DailySurgeCapacity,*/
                final.Type,
                alc.ActLoadCount,
                CAST(ROUND(CAST(final.Total AS NUMERIC(10,2)) / alc.ActLoadCount,1) AS NUMERIC(10,1)) AS TotalLaneVolPercent
            FROM
                (

                    SELECT
                        DISTINCT
                        --692
                        missing.[Ship Plant],
                        missing.[Dest Plant],
                        missing.Lane,
                        missing.[Shipping Condition],
                        'NonPrefer' AS PreferenceMarker,
                        1 AS Total,
                        0 AS TotalShipDays,
                        @DefaultCapacity AS WeeklyBaseCapacity,
                        @DefaultCapacity AS WeeklySurgeCapacity,
                        1 AS DailyBaseCapacity,
                        1 AS DailySurgeCapacity,
                        @DefaultLoadCost AS AvgActLinehaul,
                        'Missing in Actuals' AS Type
                    FROM
                        actAgg AS missing
                        LEFT JOIN actAgg ON actAgg.[Ship Plant] = missing.[Ship Plant]
                            AND actAgg.[Dest Plant] = missing.[Dest Plant]
                            AND actAgg.Lane = missing.Lane
                            AND actAgg.[Shipping Condition] = missing.[Shipping Condition]
                            AND actAgg.PreferenceMarker = 'NonPrefer'
                    WHERE actAgg.Lane IS NULL

                UNION ALL

                    SELECT
                        DISTINCT
                        actAgg.[Ship Plant],
                        actAgg.[Dest Plant],
                        actAgg.Lane,
                        actAgg.[Shipping Condition],
                        actAgg.PreferenceMarker,
                        actAgg.Total,
                        actAgg.TotalShipDays,
                        actAgg.WeeklyBaseCapacity,
                        actAgg.WeeklySurgeCapacity,
                        actAgg.DailyBaseCapacity,
                        actAgg.DailySurgeCapacity,
                        actAgg.AvgActLinehaul,
                        'Included in Actuals' AS Type
                    FROM
                        actAgg
) final
                LEFT JOIN actualsLaneCount alc ON alc.[Ship Plant] = final.[Ship Plant]
                    AND alc.[Dest Plant] = final.[Dest Plant]
                    AND alc.Lane = final.Lane
            /*WHERE final.[Ship Plant]= '2007'
AND final.[Dest Plant] = '2031'
AND final.Lane = 'SCGRANIT-5CT06776'*/
        )

    /*
Final query output from stored procedure
*/
    SELECT
        DISTINCT
        final.[Ship Plant] AS FromLocationID,
        final.[Dest Plant] AS ToLocationID,
        final.[Shipping Condition] AS ModelID,
        final.PreferenceMarker AS CarrierID,
        0 AS MinimumsLoadsPerDay,
        CAST(CASE WHEN final.Type = 'Missing in Actuals' THEN @DefaultCapacity ELSE CEILING((ROUND(final.WeeklyBaseCapacity / 7,1))) END AS INT) AS MaximumLoadsPerDay,
        CASE WHEN final.Type = 'Missing in Actuals' THEN @DefaultLoadCost ELSE final.AvgActLinehaul END AS RatePerLoad,
        GETUTCDATE() AS CurrentUTCDateTime
    FROM
        final
    ORDER BY FromLocationID ASC, ToLocationID ASC, ModelID ASC, CarrierID ASC

END