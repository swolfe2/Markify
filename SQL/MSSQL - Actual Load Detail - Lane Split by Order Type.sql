/*
Get the lane split by order type from Actual Load Detail for the past 90 days
*/
SELECT
    DISTINCT
    ald.Lane,
    CASE
    WHEN ald.CUSTOMER > 0 THEN 1
    ELSE 0
  END + CASE
    WHEN ald.INTERMILL > 0 THEN 1
    ELSE 0
  END + CASE
    WHEN ald.[RF-INBOUND] > 0 THEN 1
    ELSE 0
  END + CASE
    WHEN ald.[RM-INBOUND] > 0 THEN 1
    ELSE 0
  END AS TotalOrderTypes,
    ald.CUSTOMER + ald.INTERMILL + ald.[RF-INBOUND] + ald.[RM-INBOUND] AS TotalLoadCount,
    ald.CUSTOMER,
    CAST(ROUND(CAST(ald.CUSTOMER AS NUMERIC(10, 2)) / (ald.CUSTOMER + ald.INTERMILL + ald.[RF-INBOUND] + ald.[RM-INBOUND]), 2) AS NUMERIC(10, 2)) AS CustomerSplit,
    ald.INTERMILL,
    CAST(ROUND(CAST(ald.INTERMILL AS NUMERIC(10, 2)) / (ald.CUSTOMER + ald.INTERMILL + ald.[RF-INBOUND] + ald.[RM-INBOUND]), 2) AS NUMERIC(10, 2)) AS IntermillSplit,
    ald.[RF-INBOUND],
    CAST(ROUND(CAST(ald.[RF-INBOUND] AS NUMERIC(10, 2)) / (ald.CUSTOMER + ald.INTERMILL + ald.[RF-INBOUND] + ald.[RM-INBOUND]), 2) AS NUMERIC(10, 2)) AS 'RF-InboundSplit',
    ald.[RM-INBOUND],
    CAST(ROUND(CAST(ald.[RM-INBOUND] AS NUMERIC(10, 2)) / (ald.CUSTOMER + ald.INTERMILL + ald.[RF-INBOUND] + ald.[RM-INBOUND]), 2) AS NUMERIC(10, 2)) AS 'RM-InboundSplit'
FROM
    (SELECT
        DISTINCT
        Lane,
        COALESCE([CUSTOMER], 0) AS 'CUSTOMER',
        COALESCE([INTERMILL], 0) AS 'INTERMILL',
        COALESCE([RF-INBOUND], 0) AS 'RF-INBOUND',
        COALESCE([RM-INBOUND], 0) AS 'RM-INBOUND'
    FROM
        (SELECT
            DISTINCT
            ald.Lane,
            ald.OrderType,
            COUNT(DISTINCT ald.LD_LEG_ID) AS TotalLoadCount
        FROM
            USCTTDEV.dbo.tblActualLoadDetail ald
        WHERE CAST(ald.SHPD_DTT AS DATE) >= CAST(GETDATE() - 90 AS DATE)
        GROUP BY ald.Lane,
         ald.OrderType) p
PIVOT
(
SUM(TotalLoadCount)
FOR OrderType IN
([CUSTOMER],
[INTERMILL],
[RF-INBOUND],
[RM-INBOUND])
) AS pvt) ald