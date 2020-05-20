SELECT DISTINCT

CASE 
	WHEN ald.SHPD_DTT IS NULL 
		THEN DATEPART(year,ald.STRD_DTT) 
	ELSE DATEPART(year, ald.SHPD_DTT) 
END AS Year,
CASE 
	WHEN ald.SHPD_DTT IS NULL 
		THEN DATEPART(week,DATEADD(day, DATEDIFF(day, 0, ald.STRD_DTT) /7*7, 0)) 
	ELSE DATEPART(week, DATEADD(day, DATEDIFF(day, 0, ald.SHPD_DTT) /7*7, 0)) 
END AS Week,
CAST(CASE 
	WHEN ald.SHPD_DTT IS NULL 
		THEN DATEADD(day, DATEDIFF(day, 0, ald.STRD_DTT) /7*7, 0)
	ELSE DATEADD(day, DATEDIFF(day, 0, ald.SHPD_DTT) /7*7, 0)
END AS DATE) AS WeekStartDate,
COUNT(DISTINCT LD_LEG_ID) AS ShipmentCount,
SUM(FIXD_ITNR_DIST) as TotalMiles,
SUM(TOT_TOT_PCE) AS TotalPieces,
SUM(TOT_SCLD_WGT) AS TotalWeight,
SUM(TOT_VOL) AS TotalVolume,
SUM(TotalCost) AS TotalCost,

SUM(ConsumerTotalCost) AS ConsumerCost,
SUM(KCPTotalCost) AS KCPTotalCost,
SUM(NonWovenTotalCost) AS NonWovenCost,
SUM(UnknownTotalCost) AS UnknownCost,
SUM(Act_Fuel) AS TotalFuelCost,
SUM(ConsumerFuelCost) AS ConsumerFuelCost,
SUM(KCPFuelCost) AS KCPTotalFuelCost,
SUM(NonWovenFuelCost) AS NonWovenFuelCost,
SUM(UnknownFuelCost) AS UnknownFuelCost

FROM USCTTDEV.dbo.tblActualLoadDetail ald
WHERE CASE 
	WHEN ald.SHPD_DTT IS NULL 
		THEN DATEADD(day, DATEDIFF(day, 0, ald.STRD_DTT) /7*7, 0)
	ELSE DATEADD(day, DATEDIFF(day, 0, ald.SHPD_DTT) /7*7, 0)
END < GETDATE()
GROUP BY 
CASE 
	WHEN ald.SHPD_DTT IS NULL 
		THEN DATEPART(year,ald.STRD_DTT) 
	ELSE DATEPART(year, ald.SHPD_DTT) 
END,
CASE 
	WHEN ald.SHPD_DTT IS NULL 
		THEN DATEPART(week,DATEADD(day, DATEDIFF(day, 0, ald.STRD_DTT) /7*7, 0)) 
	ELSE DATEPART(week, DATEADD(day, DATEDIFF(day, 0, ald.SHPD_DTT) /7*7, 0)) 
END,
CAST(CASE 
	WHEN ald.SHPD_DTT IS NULL 
		THEN DATEADD(day, DATEDIFF(day, 0, ald.STRD_DTT) /7*7, 0)
	ELSE DATEADD(day, DATEDIFF(day, 0, ald.SHPD_DTT) /7*7, 0)
END AS DATE)


ORDER BY "YEAR", "WEEK" ASC

/*
SELECT * FROM USCTTDEV.dbo.tblActualLoadDetail WHERE ID < 10

SELECT DATEADD(day, DATEDIFF(day, 0, GETDATE()-6) /7*7, 0)
*/