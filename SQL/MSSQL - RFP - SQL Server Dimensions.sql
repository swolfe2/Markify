/*
Get the plant/origin zone based off of the most recent date available from actuals
*/

    SELECT
        DISTINCT
        ald.FRST_SHPG_LOC_CD,
        ald.Origin_Zone,
        ald.OriginPlant,
        CASE WHEN ald.FRST_SHPG_LOC_CD NOT LIKE 'V%' THEN LEFT(ald.FRST_SHPG_LOC_CD,4) 
ELSE REPLACE(CASE
    WHEN CHARINDEX('-', ald.FRST_SHPG_LOC_CD) > 0 THEN
        rtrim(LEFT(ald.FRST_SHPG_LOC_CD, CHARINDEX('-', ald.FRST_SHPG_LOC_CD) - 1))
    ELSE
        ald.FRST_SHPG_LOC_CD
END,'V','')
END AS OriginPlantID
    FROM
        USCTTDEV.dbo.tblActualLoadDetail ald
        INNER JOIN(
SELECT
            DISTINCT
            CASE WHEN ald.FRST_SHPG_LOC_CD NOT LIKE 'V%' THEN LEFT(ald.FRST_SHPG_LOC_CD,4) 
ELSE REPLACE(CASE
    WHEN CHARINDEX('-', ald.FRST_SHPG_LOC_CD) > 0 THEN
        rtrim(LEFT(ald.FRST_SHPG_LOC_CD, CHARINDEX('-', ald.FRST_SHPG_LOC_CD) - 1))
    ELSE
        ald.FRST_SHPG_LOC_CD
END,'V','')
END AS OriginPlantID,
            MAX(CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END) AS MaxShipDate
        FROM
            USCTTDEV.dbo.tblActualLoadDetail ald

        /*AND ald.OriginPlant LIKE '2504%'*/
        GROUP BY CASE WHEN ald.FRST_SHPG_LOC_CD NOT LIKE 'V%' THEN LEFT(ald.FRST_SHPG_LOC_CD,4) 
ELSE REPLACE(CASE
    WHEN CHARINDEX('-', ald.FRST_SHPG_LOC_CD) > 0 THEN
        rtrim(LEFT(ald.FRST_SHPG_LOC_CD, CHARINDEX('-', ald.FRST_SHPG_LOC_CD) - 1))
    ELSE
        ald.FRST_SHPG_LOC_CD
END,'V','')
END) maxShipDate ON maxShipDate.OriginPlantID = CASE WHEN ald.FRST_SHPG_LOC_CD NOT LIKE 'V%' THEN LEFT(ald.FRST_SHPG_LOC_CD,4) 
ELSE REPLACE(CASE
    WHEN CHARINDEX('-', ald.FRST_SHPG_LOC_CD) > 0 THEN
        rtrim(LEFT(ald.FRST_SHPG_LOC_CD, CHARINDEX('-', ald.FRST_SHPG_LOC_CD) - 1))
    ELSE
        ald.FRST_SHPG_LOC_CD
END,'V','')
END AND maxShipDate.MaxShipDate = CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END

UNION ALL

    /*
Union Mexico Lanes not in Actuals
*/

    SELECT
        '' AS FRST_SHPG_LOC_CD,
        'AGAGUASC' AS Origin_Zone,
        '2325 - AGUASCALIENTES',
        '2325' AS OriginPlantID
UNION ALL
    SELECT
        '' AS FRST_SHPG_LOC_CD,
        'ZTPINOS' AS Origin_Zone,
        '2525 - PINOS',
        '2525' AS OriginPlantID
UNION ALL
    SELECT
        '' AS FRST_SHPG_LOC_CD,
        'QACOLON' AS Origin_Zone,
        '2537 - COLON',
        '2537' AS OriginPlantID
UNION ALL
    SELECT
        '2484-JD01' AS FRST_SHPG_LOC_CD,
        'TXDALLAS' AS Origin_Zone,
        '2484 - DALLAS',
        '2484' AS OriginPlantID

ORDER BY ald.OriginPlant ASC

/*
Get the unique Zone codes by ZIP for non-USA, ranked by shipment count for the current year
*/

SELECT
    *
FROM
    (
    SELECT
        DISTINCT
        zones.Zip,
        zones.Zone,
        zones.LoadCount,
        ROW_NUMBER() OVER (PARTITION BY zones.ZIP ORDER BY zones.LoadCount DESC) AS RowNumber
    FROM
        (
                                                                                                                                                                                                                                                                                                                                SELECT
                DISTINCT
                ald.LAST_PSTL_CD AS Zip,
                ald.Dest_Zone AS Zone,
                COUNT(DISTINCT ald.LD_LEG_ID) AS LoadCount
            FROM
                USCTTDEV.dbo.tblActualLoadDetail ald
            WHERE ald.LAST_CTRY_CD <> 'USA'
                AND YEAR(ald.SHPD_DTT) = YEAR(GETDATE())
                AND ald.EQMT_TYP <> 'LTL'
            GROUP BY ald.LAST_PSTL_CD, ald.Dest_Zone

        UNION ALL

            SELECT
                DISTINCT
                ald.FRST_PSTL_CD AS Zip,
                ald.Origin_Zone AS Zone,
                COUNT(DISTINCT ald.LD_LEG_ID) AS LoadCount
            FROM
                USCTTDEV.dbo.tblActualLoadDetail ald
            WHERE ald.FRST_CTRY_CD <> 'USA'
                AND YEAR(ald.SHPD_DTT) = YEAR(GETDATE())
                AND ald.EQMT_TYP <> 'LTL'
            GROUP BY ald.FRST_PSTL_CD, ald.Origin_Zone
    ) zones
    GROUP BY zones.Zip, zones.Zone, zones.LoadCount
) zoneAgg
WHERE ZoneAgg.RowNumber = 1

/*
Get Dest Zones by PlantID
*/
SELECT
    DestPlants.PlantID,
    DestPlants.Dest_Zone,
    DestPlants.LAST_CTRY_CD,
    DestPlants.LAST_PSTL_CD,
    LEFT(DestPlants.LAST_PSTL_CD,3) AS LAST_PSTL_CD_3,
    DestPlants.LoadCount
FROM(
SELECT
        DISTINCT
        LEFT(ald.LAST_SHPG_LOC_CD,4) AS PlantID,
        ald.LAST_CTRY_CD,
        ald.Dest_Zone,
        CASE WHEN ald.LAST_CTRY_CD = 'USA' THEN LEFT(ald.LAST_PSTL_CD,5) ELSE ald.LAST_PSTL_CD END AS LAST_PSTL_CD,
        --114
        COUNT(DISTINCT ald.LD_LEG_ID) AS LoadCount,
        ROW_NUMBER() OVER (PARTITION BY  LEFT(ald.LAST_SHPG_LOC_CD,4) ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowNum
    FROM
        USCTTDEV.dbo.tblActualLoadDetail ald
    WHERE LEFT(ald.LAST_SHPG_LOC_CD,1) NOT IN ('5','V','9')
        AND YEAR(ald.SHPD_DTT) = YEAR(GETDATE())
        AND ald.EQMT_TYP <> 'LTL'
    GROUP BY LEFT(ald.LAST_SHPG_LOC_CD,4),
ald.LAST_CTRY_CD,
ald.Dest_Zone,
CASE WHEN ald.LAST_CTRY_CD = 'USA' THEN LEFT(ald.LAST_PSTL_CD,5) ELSE ald.LAST_PSTL_CD END
) DestPlants
WHERE DestPlants.RowNum = 1
ORDER BY DestPlants.PlantID ASC


/*
Full 3-digit to 5-digit splits
No LTL
Current Year
*/

WITH
    Actuals
    (
        LAST_PSTL_CDShort,
        LAST_PSTL_CD,
        LoadCount,
        Total3ZipCustomerLoadCount,
        LaneSharePercentCustomer,
        RowNumber
    )
    AS
    (
        SELECT
            DISTINCT
            LEFT(ald.LAST_PSTL_CD,3) AS LAST_PSTL_CDShort,
            CASE WHEN ald.LAST_CTRY_CD = 'USA' THEN LEFT(ald.LAST_PSTL_CD,5) ELSE ald.LAST_PSTL_CD END AS LAST_PSTL_CD,
            COUNT(DISTINCT ald.LD_LEG_ID) AS LoadCount,
            SUM(COUNT(DISTINCT ald.LD_LEG_ID)) OVER (PARTITION BY LEFT(ald.LAST_PSTL_CD,3)) AS Total3ZipCustomerLoadCount,
            CAST(ROUND(CAST(COUNT(DISTINCT ald.LD_LEG_ID) AS NUMERIC(10,2)) / SUM(COUNT(DISTINCT ald.LD_LEG_ID)) OVER (PARTITION BY LEFT(ald.LAST_PSTL_CD,3)),2) AS NUMERIC(10,2)) AS LaneSharePercentCustomer,
            ROW_NUMBER() OVER (PARTITION BY LEFT(ald.LAST_PSTL_CD,3) ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowNumber
        FROM
            USCTTDEV.dbo.tblActualLoadDetail ald
        WHERE YEAR(CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.SHPD_DTT END) = YEAR(GETDATE())
            AND ald.EQMT_TYP <> 'LTL'
        /*AND LEFT(ald.LAST_PSTL_CD,3) = '217'*/
        GROUP BY LEFT(ald.LAST_PSTL_CD,3),
CASE WHEN ald.LAST_CTRY_CD = 'USA' THEN LEFT(ald.LAST_PSTL_CD,5) ELSE ald.LAST_PSTL_CD END
    )

    SELECT
        actuals.*,
        'Actuals' AS Type
    FROM
        Actuals

    /*
Unions provided by Thomas 9/20/2021
Only add the additions when they don't exist in Actuals
*/
UNION ALL
    SELECT
        additions.*,
        'Additions' AS Type
    FROM
        (
SELECT
            additions.*,
            1 AS Total3ZipCustomerLoadCount,
            1 AS LaneSharePercentCustomer,
            1 AS RowNumber
        FROM
            (
                                                                                                                                                                                                                                                                                                                    SELECT
                    "3dig" AS LAST_PSTL_CDShort,
                    "5dig" AS LAST_PSTL_CD,
                    1 AS LoadCount
                FROM
                    (
SELECT
                        LEFT(last_pstl_cd,3) AS "3dig",
                        CASE WHEN last_ctry_cd = 'USA' THEN LEFT(last_pstl_cd,5) ELSE last_pstl_cd END AS "5dig",
                        count(ld_leg_id) AS ldct,
                        sum(CASE WHEN eqmt_typ = 'ltl' THEN 1 ELSE 0 END) AS LTL,
                        sum(CASE WHEN eqmt_typ <> 'ltl' THEN 1 ELSE 0 END) AS fullTL,
                        max(shpd_dtt) AS LatestShip,
                        rank() OVER (partition BY LEFT(last_pstl_cd,3) ORDER BY sum(CASE WHEN eqmt_typ <> 'ltl' THEN 1 ELSE 0 END) DESC, count(ld_leg_id) DESC, max(shpd_dtt)) AS rank
                    FROM
                        USCTTDEV.dbo.tblActualLoadDetail
                    WHERE LEFT(last_pstl_cd,3) IN ('968','651','460','540','252','288','292','294','384','316','016','161','225','A0P','A1B','T2S','V3S','V9G')
                    GROUP BY
    LEFT(last_pstl_cd,3),
    CASE WHEN last_ctry_cd = 'USA' THEN LEFT(last_pstl_cd,5) ELSE last_pstl_cd END) AS sQry
                WHERE
    rank = 1
            UNION ALL
                SELECT
                    'T2S' AS LAST_PSTL_CDShort,
                    'T2S2S2' AS LAST_PSTL_CD,
                    1 AS LoadCount
            UNION ALL
                SELECT
                    '968' AS LAST_PSTL_CDShort,
                    '96819' AS LAST_PSTL_CD,
                    1 AS LoadCount
) additions
) additions
    WHERE additions.LAST_PSTL_CDShort NOT IN (SELECT
        DISTINCT
        LAST_PSTL_CDShort
    FROM
        Actuals)

ORDER BY LAST_PSTL_CDShort ASC, RowNumber ASC

/*
3-digit to 5-digit splits by Customer Hierarchy
No LTL
Current Year
*/
SELECT
    DISTINCT
    ald.CustomerHierarchy,
    LEFT(ald.LAST_PSTL_CD,3) AS LAST_PSTL_CDShort,
    CASE WHEN ald.LAST_CTRY_CD = 'USA' THEN LEFT(ald.LAST_PSTL_CD,5) ELSE ald.LAST_PSTL_CD END AS LAST_PSTL_CD,
    COUNT(DISTINCT ald.LD_LEG_ID) AS LoadCount,
    SUM(COUNT(DISTINCT ald.LD_LEG_ID)) OVER (PARTITION BY LEFT(ald.LAST_PSTL_CD,3)) AS Total3ZipLoadCount,
    CAST(ROUND(CAST(COUNT(DISTINCT ald.LD_LEG_ID) AS NUMERIC(10,2)) / SUM(COUNT(DISTINCT ald.LD_LEG_ID)) OVER (PARTITION BY LEFT(ald.LAST_PSTL_CD,3)),2) AS NUMERIC(10,2)) AS [3ZipLaneShare],
    ROW_NUMBER() OVER (PARTITION BY LEFT(ald.LAST_PSTL_CD,3) ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS [3ZIPRank],
    SUM(COUNT(DISTINCT ald.LD_LEG_ID)) OVER (PARTITION BY LEFT(ald.LAST_PSTL_CD,3), ald.CustomerHierarchy) AS Total3ZipHierarchyLoadCount,
    CAST(ROUND(CAST(COUNT(DISTINCT ald.LD_LEG_ID) AS NUMERIC(10,2)) / SUM(COUNT(DISTINCT ald.LD_LEG_ID)) OVER (PARTITION BY LEFT(ald.LAST_PSTL_CD,3), ald.CustomerHierarchy),2) AS NUMERIC(10,2)) AS [3ZipHierarchyLaneShare],
    ROW_NUMBER() OVER (PARTITION BY LEFT(ald.LAST_PSTL_CD,3), ald.CustomerHierarchy ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS [3ZIPHierarchyRank],
    SUM(COUNT(DISTINCT ald.LD_LEG_ID)) OVER (PARTITION BY CASE WHEN ald.LAST_CTRY_CD = 'USA' THEN LEFT(ald.LAST_PSTL_CD,5) ELSE ald.LAST_PSTL_CD END) AS TotalZipCustomerLoadCount,
    CAST(ROUND(CAST(COUNT(DISTINCT ald.LD_LEG_ID) AS NUMERIC(10,2)) / SUM(COUNT(DISTINCT ald.LD_LEG_ID)) OVER (PARTITION BY CASE WHEN ald.LAST_CTRY_CD = 'USA' THEN LEFT(ald.LAST_PSTL_CD,5) ELSE ald.LAST_PSTL_CD END),2) AS NUMERIC(10,2)) AS [3ZipFrom5TotalLaneShare],
    ROW_NUMBER() OVER (PARTITION BY CASE WHEN ald.LAST_CTRY_CD = 'USA' THEN LEFT(ald.LAST_PSTL_CD,5) ELSE ald.LAST_PSTL_CD END ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS [3ZipFrom5TotalRank]
FROM
    USCTTDEV.dbo.tblActualLoadDetail ald
WHERE YEAR(CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.SHPD_DTT END) = YEAR(GETDATE())
    AND ald.EQMT_TYP <> 'LTL'
/*AND ald.CustomerHierarchy = 'Amazon'*/
GROUP BY ald.CustomerHierarchy,
LEFT(ald.LAST_PSTL_CD,3),
CASE WHEN ald.LAST_CTRY_CD = 'USA' THEN LEFT(ald.LAST_PSTL_CD,5) ELSE ald.LAST_PSTL_CD END
ORDER BY LAST_PSTL_CDShort ASC, [3ZIPRank] ASC

/*
Get the primary state for the 5-digit zip
*/
SELECT
    *
FROM
    (
SELECT
        DISTINCT
        CASE WHEN ald.LAST_CTRY_CD = 'USA' THEN LEFT(ald.LAST_PSTL_CD,5) ELSE ald.LAST_PSTL_CD END AS PostalCode5,
        --9524
        ald.LAST_STA_CD,
        COUNT(DISTINCT ald.LD_LEG_ID) AS LoadCount,
        ROW_NUMBER() OVER (PARTITION BY CASE WHEN ald.LAST_CTRY_CD = 'USA' THEN LEFT(ald.LAST_PSTL_CD,5) ELSE ald.LAST_PSTL_CD END ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowNumber
    FROM
        USCTTDEV.dbo.tblActualLoadDetail ald
    GROUP BY CASE WHEN ald.LAST_CTRY_CD = 'USA' THEN LEFT(ald.LAST_PSTL_CD,5) ELSE ald.LAST_PSTL_CD END,
ald.LAST_STA_CD) FullZip
WHERE FullZip.RowNumber = 1
ORDER BY FullZip.PostalCode5 ASC, FullZip.RowNumber ASC


/*
Get the primary state for the 3-digit zip
*/
SELECT
    *
FROM
    (
SELECT
        DISTINCT
        LEFT(ald.LAST_PSTL_CD,3) AS PostalCode3,
        ald.LAST_STA_CD,
        COUNT(DISTINCT ald.LD_LEG_ID) AS LoadCount,
        ROW_NUMBER() OVER (PARTITION BY LEFT(ald.LAST_PSTL_CD,3) ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowNumber
    FROM
        USCTTDEV.dbo.tblActualLoadDetail ald
    GROUP BY LEFT(ald.LAST_PSTL_CD,3),
ald.LAST_STA_CD) ParitalZip
WHERE ParitalZip.RowNumber = 1
ORDER BY ParitalZip.PostalCode3 ASC, ParitalZip.RowNumber ASC

/*
Combine 3-digit to 5-digit
*/
WITH
    PostalCode5
    (
        PostalCode5,
        LAST_STA_CD,
        LoadCount,
        RowNumber
    )
    AS
    (
        SELECT
            *
        FROM
            (
SELECT
                DISTINCT
                CASE WHEN ald.LAST_CTRY_CD = 'USA' THEN LEFT(ald.LAST_PSTL_CD,5) ELSE ald.LAST_PSTL_CD END AS PostalCode5,
                --9524
                ald.LAST_STA_CD,
                COUNT(DISTINCT ald.LD_LEG_ID) AS LoadCount,
                ROW_NUMBER() OVER (PARTITION BY CASE WHEN ald.LAST_CTRY_CD = 'USA' THEN LEFT(ald.LAST_PSTL_CD,5) ELSE ald.LAST_PSTL_CD END ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowNumber
            FROM
                USCTTDEV.dbo.tblActualLoadDetail ald
            GROUP BY CASE WHEN ald.LAST_CTRY_CD = 'USA' THEN LEFT(ald.LAST_PSTL_CD,5) ELSE ald.LAST_PSTL_CD END,
ald.LAST_STA_CD) FullZip
        WHERE FullZip.RowNumber = 1
    ),

    PostalCode3
    (
        PostalCode3,
        LAST_STA_CD,
        LoadCount,
        RowNumber
    )
    AS
    (
        SELECT
            *
        FROM
            (
SELECT
                DISTINCT
                LEFT(ald.LAST_PSTL_CD,3) AS PostalCode3,
                ald.LAST_STA_CD,
                COUNT(DISTINCT ald.LD_LEG_ID) AS LoadCount,
                ROW_NUMBER() OVER (PARTITION BY LEFT(ald.LAST_PSTL_CD,3) ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowNumber
            FROM
                USCTTDEV.dbo.tblActualLoadDetail ald
            GROUP BY LEFT(ald.LAST_PSTL_CD,3),
ald.LAST_STA_CD) ParitalZip
        WHERE ParitalZip.RowNumber = 1
    )

SELECT
    DISTINCT
    PostalCode3.*,
    PostalCode5.*,
    CAST(ROUND(CAST(PostalCode5.LoadCount AS NUMERIC(10,2)) / PostalCode3.LoadCount,2) AS NUMERIC(10,2)) AS LaneSharePercent
FROM
    PostalCode3
    LEFT JOIN PostalCode5 ON LEFT(PostalCode5.PostalCode5,3) = PostalCode3.PostalCode3

ORDER BY PostalCode3.PostalCode3 ASC, PostalCode5.PostalCode5 ASC

/*
Get Canada 3-digit zip zone for most load count
*/
SELECT
    *
FROM
    (
SELECT
        DISTINCT
        CanadaAgg.Zone,
        CanadaAgg.Zip3,
        CanadaAgg.LoadCount,
        ROW_NUMBER() OVER (PARTITION BY CanadaAgg.Zip3 ORDER BY CanadaAgg.LoadCount DESC) AS RowNumber
    FROM(
                                                                                                                        SELECT
                DISTINCT
                Origin_Zone AS Zone,
                LEFT(FRST_PSTL_CD,3) AS Zip3,
                COUNT(DISTINCT ald.LD_LEG_ID) AS LoadCount
            FROM
                USCTTDEV.dbo.tblActualLoadDetail ald
            WHERE ald.FRST_CTRY_CD = 'CAN'
            GROUP BY Origin_Zone,
LEFT(FRST_PSTL_CD,3)

        UNION ALL

            SELECT
                DISTINCT
                Dest_Zone AS Zone,
                LEFT(LAST_PSTL_CD,3) AS Zip3,
                COUNT(DISTINCT ald.LD_LEG_ID) AS LoadCount
            FROM
                USCTTDEV.dbo.tblActualLoadDetail ald
            WHERE ald.LAST_CTRY_CD = 'CAN'
            GROUP BY Dest_Zone,
LEFT(LAST_PSTL_CD,3)
) CanadaAgg
    WHERE CanadaAgg.Zone IS NOT NULL
/*ORDER BY CanadaAgg.Zip3 ASC,  CanadaAgg.RowNumber ASC*/
) CanadaAgg
WHERE CanadaAgg.RowNumber = 1
ORDER BY CanadaAgg.Zip3 ASC,  CanadaAgg.RowNumber ASC

/*
Get Unique Lanes by Month
/*52929*/
*/
WITH
    CurrentYearLanes
    (
        Origin_Zone,
        Dest_Zone,
        Lane,
        TheMonth,
        TheQuarter,
        TheYear
    )
    AS

    (
        SELECT
            DISTINCT
            ald.Origin_Zone,
            ald.Dest_Zone,
            ald.Lane,
            da.TheMonth,
            da.TheQuarter,
            da.TheYear
        FROM
            USCTTDEV.dbo.tblActualLoadDetail ald
CROSS JOIN (
SELECT
                DISTINCT
                da.TheMonth,
                da.TheQuarter,
                da.TheYear
            FROM
                USCTTDEV.dbo.tblDates da
            WHERE da.TheYear = 2021
                AND da.TheMonth <= MONTH(GETDATE())) da
        WHERE CAST(CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END AS DATE) <= CAST(GETDATE() AS DATE)
            AND YEAR(CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END) = YEAR(GETDATE())
            AND ald.EQMT_TYP <> 'LTL'
        /*AND ald.Lane = 'ALALEXAN-5AL36610'*/
    ),
    CurrentYearActuals
    (
        Origin_Zone,
        Dest_Zone,
        Lane,
        Month,
        LoadCount,
        IntermillCount,
        CustomerCount,
        RFCount,
        RMCount,
        IntermodalCount,
        TCCount,
        TLCount,
        ConsumerCount,
        KCPCount,
        NonWovensCount,
        UnknownBUCount,
        ContractRateCount,
        SpotRateCount,
        LiveLoadCount,
        BrokerLoadCount,
        DedicatedLoadCount
    )
    AS

    (
        /*
Get lane count volumes by specific types
SELECT TOP 10 * FROM USCTTDEV.dbo.tblActualLoadDetail
*/

        SELECT
            DISTINCT
            ald.Origin_Zone,
            ald.Dest_Zone,
            ald.Lane,
            MONTH(CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END) AS Month,
            COUNT(DISTINCT ald.LD_LEG_ID) AS LoadCount,
            SUM(CASE WHEN ald.OrderType = 'INTERMILL' THEN 1 ELSE 0 END) AS IntermillCount,
            SUM(CASE WHEN ald.OrderType = 'CUSTOMER' THEN 1 ELSE 0 END) AS CustomerCount,
            SUM(CASE WHEN ald.OrderType = 'RF-INBOUND' THEN 1 ELSE 0 END) AS RFCount,
            SUM(CASE WHEN ald.OrderType = 'RM-INBOUND' THEN 1 ELSE 0  END) AS RMCount,
            SUM(CASE WHEN ald.EQMT_TYP = '53IM' THEN 1 ELSE 0 END) AS IntermodalCount,
            SUM(CASE WHEN ald.EQMT_TYP = '53TC' THEN 1 ELSE 0 END) AS TCCount,
            SUM(CASE WHEN ald.EQMT_TYP NOT IN ('53IM','53TC') THEN 1 ELSE 0 END) AS TLCount,
            SUM(CASE WHEN ald.BU = 'CONSUMER' THEN 1 ELSE 0 END) AS ConsumerCount,
            SUM(CASE WHEN ald.BU = 'KCP' THEN 1 ELSE 0 END) AS KCPCount,
            SUM(CASE WHEN ald.BU = 'NON WOVENS' THEN 1 ELSE 0 END) AS NonWovensCount,
            SUM(CASE WHEN ald.BU = 'UNKNOWN' THEN 1 ELSE 0 END) AS UnknownBUCount,
            SUM(CASE WHEN ald.RateType = 'Contract' THEN 1 ELSE 0 END) AS ContractRateCount,
            SUM(CASE WHEN ald.RateType <> 'Contract' THEN 1 ELSE 0 END) AS SpotRateCount,
            SUM(CASE WHEN ald.LiveLoad IS NOT NULL THEN 1 ELSE 0 END) AS LiveLoadCount,
            SUM(CASE WHEN ald.Broker IS NOT NULL THEN 1 ELSE 0 END) AS BrokerLoadCount,
            SUM(CASE WHEN ald.Dedicated IS NOT NULL THEN 1 ELSE 0 END) AS DedicatedLoadCount

        FROM
            USCTTDEV.dbo.tblActualLoadDetail ald

        WHERE CAST(CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END AS DATE) <= CAST(GETDATE() AS DATE)

            AND YEAR(CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END) = YEAR(GETDATE())

            AND ald.EQMT_TYP <> 'LTL'

        /*AND ald.Lane = 'ALALEXAN-5AL36610'*/

        GROUP BY 
ald.Origin_Zone,
ald.Dest_Zone,
ald.Lane,
MONTH(CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END)
    )

SELECT
    cyl.Origin_Zone,
    cyl.Dest_Zone,
    cyl.Lane,
    cyl.TheMonth,
    cyl.TheQuarter,
    cyl.TheYear,
    COALESCE(cya.LoadCount,0) AS LoadCount,
    COALESCE(cya.IntermillCount,0) AS IntermillCount,
    COALESCE(cya.CustomerCount,0) AS CustomerCount,
    COALESCE(cya.RFCount,0) AS RFCount,
    COALESCE(cya.RMCount,0) AS RMCount,
    COALESCE(cya.IntermodalCount,0) AS IntermodalCount,
    COALESCE(cya.TCCount,0) AS TCCount,
    COALESCE(cya.TLCount,0) AS TLCount,
    COALESCE(cya.ConsumerCount,0) AS ConsumerCount,
    COALESCE(cya.KCPCount,0) AS KCPCount,
    COALESCE(cya.NonWovensCount,0) AS NonWovensCount,
    COALESCE(cya.UnknownBUCount,0) AS UnknownBUCount,
    COALESCE(cya.ContractRateCount,0) AS ContractRateCount,
    COALESCE(cya.SpotRateCount,0) AS SpotRateCount,
    COALESCE(cya.LiveLoadCount,0) AS LiveLoadCount,
    COALESCE(cya.BrokerLoadCount,0) AS BrokerLoadCount,
    COALESCE(cya.DedicatedLoadCount,0) AS DedicatedLoadCount
FROM
    CurrentYearLanes cyl
    LEFT JOIN CurrentYearActuals cya ON cya.Lane = cyl.Lane
        AND cya.Month = cyl.TheMonth

ORDER BY cyl.Lane ASC, cyl.TheMonth ASC

/*
Get unique Dest Zones by ranking of load counts
2004
*/
WITH
    DestZoneInfo
    (
        Dest_Zone,
        LAST_CTRY_CD,
        LAST_CTY_NAME,
        LAST_STA_CD,
        LAST_PSTL_CD,
        LoadCount,
        Ranking
    )
    AS

    (
        SELECT
            DISTINCT
            ald.Dest_Zone,
            ald.LAST_CTRY_CD,
            ald.LAST_CTY_NAME,
            ald.LAST_STA_CD,
            CASE WHEN ald.LAST_CTRY_CD = 'USA' THEN SUBSTRING(ald.LAST_PSTL_CD,1,5) ELSE ald.LAST_PSTL_CD END AS LAST_PSTL_CD,
            COUNT(DISTINCT ald.LD_LEG_ID) AS LoadCount,
            ROW_NUMBER() OVER (PARTITION BY ald.Dest_Zone ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS Ranking

        FROM
            USCTTDEV.dbo.tblActualLoadDetail ald
        WHERE CAST(CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END AS DATE) <= CAST(GETDATE() AS DATE)

            AND YEAR(CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END) = YEAR(GETDATE())

            AND ald.EQMT_TYP <> 'LTL'
        GROUP BY 
ald.Dest_Zone,
ald.LAST_CTRY_CD,
ald.LAST_CTY_NAME,
ald.LAST_STA_CD,
CASE WHEN ald.LAST_CTRY_CD = 'USA' THEN SUBSTRING(ald.LAST_PSTL_CD,1,5) ELSE ald.LAST_PSTL_CD END
    )
SELECT
    *
FROM
    DestZoneInfo
ORDER BY DestZoneInfo.Dest_Zone ASC, DestZoneInfo.Ranking ASC

/*
Get unique Origin Zones by ranking of load counts
2004
*/
WITH
    OriginZoneInfo
    (
        Origin_Zone,
        FRST_CTRY_CD,
        FRST_CTY_NAME,
        FRST_STA_CD,
        FRST_PSTL_CD,
        LoadCount,
        Ranking
    )
    AS

    (
        SELECT
            DISTINCT
            ald.Origin_Zone,
            ald.FRST_CTRY_CD,
            ald.FRST_CTY_NAME,
            ald.FRST_STA_CD,
            CASE WHEN ald.FRST_CTRY_CD = 'USA' THEN SUBSTRING(ald.FRST_PSTL_CD,1,5) ELSE ald.FRST_PSTL_CD END AS FRST_PSTL_CD,
            COUNT(DISTINCT ald.LD_LEG_ID) AS LoadCount,
            ROW_NUMBER() OVER (PARTITION BY ald.Origin_Zone ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS Ranking

        FROM
            USCTTDEV.dbo.tblActualLoadDetail ald
        WHERE CAST(CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END AS DATE) <= CAST(GETDATE() AS DATE)

            AND YEAR(CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END) = YEAR(GETDATE())

            AND ald.EQMT_TYP <> 'LTL'
        GROUP BY 
ald.Origin_Zone,
ald.FRST_CTRY_CD,
ald.FRST_CTY_NAME,
ald.FRST_STA_CD,
CASE WHEN ald.FRST_CTRY_CD = 'USA' THEN SUBSTRING(ald.FRST_PSTL_CD,1,5) ELSE ald.FRST_PSTL_CD END
    )
SELECT
    *
FROM
    OriginZoneInfo
ORDER BY OriginZoneInfo.Origin_Zone ASC, OriginZoneInfo.Ranking ASC

/*
Get first place zone information by load count for current year
*/

WITH
    OriginZoneInfo
    (
        Origin_Zone,
        FRST_CTRY_CD,
        FRST_CTY_NAME,
        FRST_STA_CD,
        FRST_PSTL_CD,
        LoadCount,
        Ranking
    )
    AS

    (
        SELECT
            DISTINCT
            ald.Origin_Zone,
            ald.FRST_CTRY_CD,
            ald.FRST_CTY_NAME,
            ald.FRST_STA_CD,
            CASE WHEN ald.FRST_CTRY_CD = 'USA' THEN SUBSTRING(ald.FRST_PSTL_CD,1,5) ELSE ald.FRST_PSTL_CD END AS FRST_PSTL_CD,
            COUNT(DISTINCT ald.LD_LEG_ID) AS LoadCount,
            ROW_NUMBER() OVER (PARTITION BY ald.Origin_Zone ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS Ranking

        FROM
            USCTTDEV.dbo.tblActualLoadDetail ald
        WHERE CAST(CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END AS DATE) <= CAST(GETDATE() AS DATE)

            AND YEAR(CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END) = YEAR(GETDATE())

            AND ald.EQMT_TYP <> 'LTL'
        GROUP BY 
ald.Origin_Zone,
ald.FRST_CTRY_CD,
ald.FRST_CTY_NAME,
ald.FRST_STA_CD,
CASE WHEN ald.FRST_CTRY_CD = 'USA' THEN SUBSTRING(ald.FRST_PSTL_CD,1,5) ELSE ald.FRST_PSTL_CD END
    )
,

    DestZoneInfo
    (
        Dest_Zone,
        LAST_CTRY_CD,
        LAST_CTY_NAME,
        LAST_STA_CD,
        LAST_PSTL_CD,
        LoadCount,
        Ranking
    )
    AS

    (
        SELECT
            DISTINCT
            ald.Dest_Zone,
            ald.LAST_CTRY_CD,
            ald.LAST_CTY_NAME,
            ald.LAST_STA_CD,
            CASE WHEN ald.LAST_CTRY_CD = 'USA' THEN SUBSTRING(ald.LAST_PSTL_CD,1,5) ELSE ald.LAST_PSTL_CD END AS LAST_PSTL_CD,
            COUNT(DISTINCT ald.LD_LEG_ID) AS LoadCount,
            ROW_NUMBER() OVER (PARTITION BY ald.Dest_Zone ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS Ranking

        FROM
            USCTTDEV.dbo.tblActualLoadDetail ald
        WHERE CAST(CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END AS DATE) <= CAST(GETDATE() AS DATE)

            AND YEAR(CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.CRTD_DTT END) = YEAR(GETDATE())

            AND ald.EQMT_TYP <> 'LTL'
        GROUP BY 
ald.Dest_Zone,
ald.LAST_CTRY_CD,
ald.LAST_CTY_NAME,
ald.LAST_STA_CD,
CASE WHEN ald.LAST_CTRY_CD = 'USA' THEN SUBSTRING(ald.LAST_PSTL_CD,1,5) ELSE ald.LAST_PSTL_CD END
    )

SELECT
    ZoneAgg.Zone,
    ZoneAgg.Country,
    ZoneAgg.City,
    ZoneAgg.State,
    ZoneAgg.ZipCode
FROM
    (
SELECT
        DISTINCT
        ZoneAgg.Zone,
        ZoneAgg.Country,
        ZoneAgg.City,
        ZoneAgg.State,
        ZoneAgg.ZipCode,
        ZoneAgg.LoadCount,
        ROW_NUMBER() OVER (PARTITION BY ZoneAgg.Zone ORDER BY ZoneAgg.LoadCount DESC) AS RowNumber
    FROM
        (
                                                SELECT
                DISTINCT
                o.Origin_Zone AS Zone,
                o.FRST_CTRY_CD AS Country,
                o.FRST_CTY_NAME AS City,
                o.FRST_STA_CD AS State,
                o.FRST_PSTL_CD AS ZipCode,
                o.LoadCount AS LoadCount
            FROM
                OriginZoneInfo o
            WHERE o.Ranking = 1

        UNION ALL

            SELECT
                DISTINCT
                d.Dest_Zone AS Zone,
                d.LAST_CTRY_CD AS Country,
                d.LAST_CTY_NAME AS City,
                d.LAST_STA_CD AS State,
                d.LAST_PSTL_CD AS ZipCode,
                d.LoadCount AS LoadCount
            FROM
                DestZoneInfo d
            WHERE d.Ranking = 1) ZoneAgg
) ZoneAgg
WHERE ZoneAgg.RowNumber = 1
ORDER BY ZoneAgg.Zone ASC, RowNumber ASC