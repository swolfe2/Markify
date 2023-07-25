/*
Rate Loading - Email
*/

/*
Top section for email
*/
SELECT TOP 1000* FROM tfr0nedb.dbo.Addendums
WHERE CAST(SignedDate AS DATE) = CAST(GETDATE() AS DATE)
ORDER BY AddendumID ASC

/*
1k rows that were done today
*/
SELECT TOP 1000* FROM tfr0nedb.dbo.LaneRates lr
INNER JOIN (SELECT TOP 1000* FROM tfr0nedb.dbo.Addendums
WHERE CAST(SignedDate AS DATE) = CAST(GETDATE() AS DATE)) addendums ON addendums.AddendumID = lr.AddendumID

/*
Last 90 days changelog from rate loading process
*/
SELECT * FROM tfr0nedb.dbo.LaneRates lr
INNER JOIN (SELECT TOP 10000* FROM tfr0nedb.dbo.Addendums
WHERE CAST(SignedDate AS DATE) >= CAST(GETDATE()  - 90 AS DATE)) addendums ON addendums.AddendumID = lr.AddendumID
ORDER lr.SignedDate DESC, lr.AddendumID ASC

/*
Top section for email
*/
SELECT TOP 1000* FROM tfr0nedb.dbo.Addendums
WHERE CAST(SignedDate AS DATE) = CAST(GETDATE() AS DATE)
ORDER BY AddendumID ASC


/*
Formatted top section of Email
*/
DROP TABLE IF EXISTS ##tblAddendumHighLevel
SELECT * INTO ##tblAddendumHighLevel
FROM (
SELECT DISTINCT
  a.AddendumID,
  a.TariffNumber,
  a.CarrierID,
  a.TariffID,
  a.ServiceID,
  a.RateCount,
  updates.NewCount,
  updates.ChangeCount
FROM tfr0nedb.dbo.Addendums a
LEFT JOIN (SELECT DISTINCT
  updates.TariffID,
  updates.CarrierID,
  updates.ServiceID,
  SUM(CASE
    WHEN updates.Action = 'New' THEN 1
    ELSE 0
  END) AS NewCount,
  SUM(CASE
    WHEN updates.Action = 'Change' THEN 1
    ELSE 0
  END) AS ChangeCount
FROM (SELECT
  lr.*
FROM tfr0nedb.dbo.LaneRates lr
INNER JOIN (SELECT
  *
FROM tfr0nedb.dbo.Addendums
WHERE CAST(SignedDate AS date) = CAST(GETDATE() AS date)) addendums
  ON addendums.AddendumID = lr.AddendumID) updates
GROUP BY updates.TariffID,
         updates.CarrierID,
         updates.ServiceID) updates
  ON updates.TariffID = a.TariffID
  AND updates.CarrierID = a.CarrierID
  AND updates.ServiceID = a.ServiceID
WHERE CAST(SignedDate AS date) = CAST(GETDATE() AS date)
) a
ORDER BY a.CarrierID ASC, a.ServiceID ASC, a.AddendumID ASC
SELECT * FROM ##tblAddendumHighLevel

/*
Addendums changed today
*/
DROP TABLE IF EXISTS ##tblAddendumDetailTemp

SELECT lr.*  INTO ##tblAddendumDetailTemp 
FROM tfr0nedb.dbo.LaneRates lr
INNER JOIN (SELECT * FROM tfr0nedb.dbo.Addendums
WHERE CAST(SignedDate AS DATE) = CAST(GETDATE() AS DATE)) addendums ON addendums.AddendumID = lr.AddendumID
ORDER BY lr.CarrierID ASC, lr.ServiceID ASC, lr.AddendumID ASC

SELECT * FROM ##tblAddendumDetailTemp

WITH addendumDetailCTE (CreatedDate, AddendumID, TariffNumber, Action, CarrierName, CarrierID, TariffID, ServiceID, OriginZone, OriginZoneDesc, OriginZoneState, OriginZoneCountry, DestinationZone, DestinationZoneDesc, DestinationZoneState, DestinationZoneCountry, EquipmentTypeID, ChargeID, RateCode, Rate, MinCgh, EffectiveDate, ExpirationDate, CatchallIndicator)
AS (
SELECT CAST(addendums.CreatedDate AS DATE) AS CreatedDate, lr.AddendumID, lr.TariffNumber, lr.Action, lr.CarrierName, lr.CarrierID, lr.TariffID, lr.ServiceID, lr.OriginZone, lr.OriginZoneDesc, lr.OriginZoneState, lr.OriginZoneCountry, lr.DestinationZone, lr.DestinationZoneDesc, lr.DestinationZoneState, lr.DestinationZoneCountry, lr.EquipmentTypeID, lr.ChargeID, lr.RateCode, lr.Rate, lr.MinChg, lr.EffectiveDate, lr.ExpirationDate, lr.CatchallIndicator
FROM tfr0nedb.dbo.LaneRates lr
INNER JOIN (SELECT * FROM tfr0nedb.dbo.Addendums
WHERE CAST(SignedDate AS DATE) = CAST(GETDATE() AS DATE)) addendums ON addendums.AddendumID = lr.AddendumID
)
SELECT * FROM addendumDetailCTE ad
ORDER BY ad.CarrierID ASC, ad.ServiceID ASC, ad.AddendumID ASC, ad.OriginZone ASC, ad.DestinationZone ASC


WITH addendumHighLevelCTE (AddendumID, AddendumNumber, AddendumStatusID, CarrierID, ServiceID, TariffID, TariffNumber, RateCount, NewCount, ChangeCount)
AS (
SELECT DISTINCT
  a.AddendumID,
  a.AddendumNumber,
  a.AddendumStatusID,
  a.CarrierID,
  a.ServiceID,
  a.TariffID,
  a.TariffNumber,
  a.RateCount,
  updates.NewCount,
  updates.ChangeCount
FROM tfr0nedb.dbo.Addendums a
LEFT JOIN (SELECT DISTINCT
  updates.TariffID,
  updates.CarrierID,
  updates.ServiceID,
  SUM(CASE
    WHEN updates.Action = 'New' THEN 1
    ELSE 0
  END) AS NewCount,
  SUM(CASE
    WHEN updates.Action = 'Change' THEN 1
    ELSE 0
  END) AS ChangeCount
FROM (SELECT
  lr.*
FROM tfr0nedb.dbo.LaneRates lr
INNER JOIN (SELECT
  *
FROM tfr0nedb.dbo.Addendums
WHERE CAST(SignedDate AS date) = CAST(GETDATE() AS date)) addendums
  ON addendums.AddendumID = lr.AddendumID) updates
GROUP BY updates.TariffID,
         updates.CarrierID,
         updates.ServiceID) updates
  ON updates.TariffID = a.TariffID
  AND updates.CarrierID = a.CarrierID
  AND updates.ServiceID = a.ServiceID
WHERE CAST(SignedDate AS date) = CAST(GETDATE() AS date)
)

SELECT * FROM addendumHighLevelCTE a
ORDER BY a.CarrierID ASC, a.ServiceID ASC, a.AddendumID ASC



