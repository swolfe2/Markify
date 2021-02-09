SELECT * FROM USCTTDEV.dbo.tblActualLoadDetail
WHERE LD_LEG_ID = '520984380'

SELECT * FROM USCTTDEV.dbo.tblAwardLanesHistorical


SELECT * FROM USCTTDEV.dbo.tblAwardRatesHistorical
WHERE Lane = 'CAONTARI-5UT84116'

/*
Drop the temp table if it exists
*/
DROP TABLE IF EXISTS ##tblAwardLanesHistoricalTemp

/*
Create the temp table
*/
CREATE TABLE ##tblAwardLanesHistoricalTemp(
LaneID INT,
Lane NVARCHAR(30),
ORIG_CITY_STATE NVARCHAR(15),
Origin NVARCHAR(50),
DEST_CITY_STATE NVARCHAR(15),
Dest NVARCHAR(50),
Miles NUMERIC(18,2),
BID_LOADS INT,
UPDATED_LOADS INT,
HISTORICAL_LOADS INT,
FMIC NUMERIC(10,2),
Comment NVARCHAR(2000),
PrimaryCustomer NVARCHAR(500),
OrderType NVARCHAR(25),
EffectiveDate Date,
ExpirationDate Date,
WeightedRPM NUMERIC(10,2),
AwardPercent NUMERIC(10,2),
AddedOn DATETIME,
LastUpdated DATETIME
)

/*
Add unique lanes to Award Lanes Historical Temp, along with effective/expiration timeframes with lead logic
SELECT * FROM ##tblAwardLanesHistoricalTemp
*/
INSERT INTO ##tblAwardLanesHistoricalTemp(Lane, LaneID, EffectiveDate, ExpirationDate)
SELECT DISTINCT arh.Lane,
arh.LaneID,
arh.EffectiveDate,
arh.ExpirationDate
FROM(
				SELECT DISTINCT arh.Lane,
				arh.LaneID,
				CAST(arh.EffectiveDate AS DATE) AS EffectiveDate,
				CASE WHEN CAST(LEAD(arh.EffectiveDate - 1,1,0) OVER (PARTITION BY arh.Lane ORDER BY CAST(arh.EffectiveDate AS DATE) ASC) AS DATE) = '01/01/1900' THEN
					CAST('12/31/2999' AS DATE)
					ELSE
					CAST(LEAD(arh.EffectiveDate - 1,1,0) OVER (PARTITION BY arh.Lane ORDER BY CAST(arh.EffectiveDate AS DATE) ASC) AS DATE) END
					AS ExpirationDate,
				RANK() OVER (PARTITION BY arh.Lane ORDER BY CAST(arh.EffectiveDate AS DATE) ASC) AS RankNum
				FROM USCTTDEV.dbo.tblAwardRatesHistorical arh
				WHERE Lane = 'CAONTARI-5UT84116'
) arh
ORDER BY arh.EffectiveDate ASC

/*
Update lane information
SELECT * FROM ##tblAwardLanesHistoricalTemp
*/
UPDATE ##tblAwardLanesHistoricalTemp
SET ORIG_CITY_STATE = arh.ORIG_CITY_STATE,
Origin = arh.Origin,
DEST_CITY_STATE = arh.DEST_CITY_STATE,
Dest = arh.Dest,
Miles = arh.Miles
FROM ##tblAwardLanesHistoricalTemp alht
INNER JOIN USCTTDEV.dbo.tblAwardRatesHistorical arh ON arh.Lane = alht.Lane
AND CAST(arh.EffectiveDate AS DATE) BETWEEN alht.EffectiveDate AND alht.ExpirationDate

SELECT DISTINCT arh.LastUpdated,
COUNT(*) AS Count
FROM USCTTDEV.dbo.tblAwardRatesHistorical arh
GROUP BY arh.LastUpdated
ORDER BY arh.LastUpdated DESC



