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
GROUP BY LEFT(ald.LAST_PSTL_CD,3),
CASE WHEN ald.LAST_CTRY_CD = 'USA' THEN LEFT(ald.LAST_PSTL_CD,5) ELSE ald.LAST_PSTL_CD END
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
    SUM(COUNT(DISTINCT ald.LD_LEG_ID)) OVER (PARTITION BY ald.CustomerHierarchy, LEFT(ald.LAST_PSTL_CD,3)) AS Total3ZipCustomerLoadCount,
    CAST(ROUND(CAST(COUNT(DISTINCT ald.LD_LEG_ID) AS NUMERIC(10,2)) / SUM(COUNT(DISTINCT ald.LD_LEG_ID)) OVER (PARTITION BY ald.CustomerHierarchy, LEFT(ald.LAST_PSTL_CD,3)),2) AS NUMERIC(10,2)) AS LaneSharePercentCustomer,
    ROW_NUMBER() OVER (PARTITION BY ald.CustomerHierarchy, LEFT(ald.LAST_PSTL_CD,3) ORDER BY COUNT(DISTINCT ald.LD_LEG_ID) DESC) AS RowNumber
FROM
    USCTTDEV.dbo.tblActualLoadDetail ald
WHERE YEAR(CASE WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
WHEN ald.STRD_DTT IS NOT NULL THEN ald.STRD_DTT
ELSE ald.SHPD_DTT END) = YEAR(GETDATE())
    AND ald.EQMT_TYP <> 'LTL'
GROUP BY ald.CustomerHierarchy,
LEFT(ald.LAST_PSTL_CD,3),
CASE WHEN ald.LAST_CTRY_CD = 'USA' THEN LEFT(ald.LAST_PSTL_CD,5) ELSE ald.LAST_PSTL_CD END
ORDER BY ald.CustomerHierarchy ASC, LAST_PSTL_CDShort ASC, RowNumber ASC


