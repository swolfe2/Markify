SELECT DISTINCT
  CAST(CASE
    WHEN ald.DLVY_DTT IS NOT NULL THEN ald.DLVY_DTT
    WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
    ELSE ald.STRD_DTT
  END AS date) AS DATE,
  Dates.Year,
  Dates.Month,
  Dates.WeekStartDate,
  Dates.WeekNumber,
  CAST(AddedOn AS date) AddedOn,
  CAST(LastUpdated AS date) LastUpdated,
  STATUS,
  CASE
    WHEN ald.DLVY_DTT IS NOT NULL THEN 'Delivered'
    WHEN ald.SHPD_DTT IS NOT NULL THEN 'Shipped'
    ELSE 'Started'
  END AS LoadStatus,
  CAST(STRD_DTT AS date) AS StartDate,
  CAST(SHPD_DTT AS date) AS ShippedDate,
  CAST(DLVY_DTT AS date) AS DeliveredDate,
  CARR_CD AS CarrierCode,
  Name AS CarrierName,
  SRVC_CD AS ServiceCode,
  SRVC_DESC AS ServiceName,
  LD_LEG_ID AS LoadNumber,
  OriginPlant,
  FRST_SHPG_LOC_CD AS OrigShippingLocationCode,
  FRST_SHPG_LOC_CD AS OrigShippingLocationName,
  FRST_CTY_NAME AS OrigCityName,
  FRST_STA_CD AS OrigState,
  FRST_PSTL_CD AS OrigPostalCode,
  FRST_CTRY_CD AS OrigCountry,
  DestinationPlant,
  CustomerHierarchy,
  CustomerGroup,
  LAST_SHPG_LOC_CD AS DestShippingLocationCode,
  LAST_SHPG_LOC_NAME AS DestShippingLocationName,
  DestCity AS DestCityName,
  LAST_STA_CD AS DestState,
  LAST_PSTL_CD AS DestPostalCode,
  LAST_CTRY_CD AS DestCountry,
  CASE
    WHEN OrderType LIKE '%INBOUND%' THEN LAST_STA_CD
    ELSE FRST_STA_CD
  END AS RegionJoinState,
  Region.RegionCountry,
  Region.RegionStateName,
  Region.Region,
  Region.CarrierManager,
  EQMT_TYP AS Equipment,
  ShipMode,
  FIXD_ITNR_DIST AS Distance,
  PreRate_Accessorials,
  PreRate_Fuel,
  PreRate_Linehaul,
  PreRate_Repo,
  PreRate_ZUSB,
  PreRateCharge,
  Act_Accessorials,
  Act_Fuel,
  Act_Linehaul,
  Act_Repo,
  Act_ZUSB,
  ActualRateCharge,
  OrderType,
  BU,
  Origin_Zone AS OriginZone,
  Dest_Zone AS Dest_Zone,
  Lane,
  TOT_TOT_PCE AS TotalPieces,
  OrderCount,
  BUCount,
  TotalWeight,
  TotalVolume,
  TotalCost,
  ConsumerWeight,
  ConsumerVolume,
  ConsumerTotalCost,
  ConsumerLinehaulCost,
  ConsumerFuelCost,
  ConsumerAccessorialsCost,
  KCPWeight,
  KCPVolume,
  KCPTotalCost,
  KCPLinehaulCost,
  KCPFuelCost,
  KCPAccessorialsCost,
  NonWovenTotalCost,
  NonWovenLinehaulCost,
  NonWovenFuelCost,
  NonWovenAccessorialsCost,
  NonWovenWeight,
  NonWovenVolume,
  UnknownWeight,
  UnknownVolume
  UnknownTotalCost,
  UnknownLinehaulCost,
  UnknownFuelCost,
  UnknownAccessorialsCost,
  FRAN,
  RFT,
  AwardLane,
  AwardCarrier,
  Broker
FROM USCTTDEV.dbo.tblActualLoadDetail ald
INNER JOIN (
/*
Dates Query
*/
SELECT DISTINCT
  CAST(CASE
    WHEN ald.DLVY_DTT IS NOT NULL THEN ald.DLVY_DTT
    WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
    ELSE ald.STRD_DTT
  END AS date) AS Date,
  DATEPART(YEAR, CAST(CASE
    WHEN ald.DLVY_DTT IS NOT NULL THEN ald.DLVY_DTT
    WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
    ELSE ald.STRD_DTT
  END AS date)) AS Year,
  DATEPART(MONTH, CAST(CASE
    WHEN ald.DLVY_DTT IS NOT NULL THEN ald.DLVY_DTT
    WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
    ELSE ald.STRD_DTT
  END AS date)) AS Month,
  CAST(DATEADD(wk, DATEDIFF(wk, 0, CAST(CASE
    WHEN ald.DLVY_DTT IS NOT NULL THEN ald.DLVY_DTT
    WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
    ELSE ald.STRD_DTT
  END AS date)), 0) AS date) AS WeekStartDate,
  DATEPART(WEEK, CAST(DATEADD(wk, DATEDIFF(wk, 0, CAST(CASE
    WHEN ald.DLVY_DTT IS NOT NULL THEN ald.DLVY_DTT
    WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
    ELSE ald.STRD_DTT
  END AS date)), 0) AS date)) AS WeekNumber
FROM USCTTDEV.dbo.tblActualLoadDetail ald
GROUP BY CAST(CASE
  WHEN ald.DLVY_DTT IS NOT NULL THEN ald.DLVY_DTT
  WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
  ELSE ald.STRD_DTT
END AS date)
)dates ON dates.date = CAST(CASE
    WHEN ald.DLVY_DTT IS NOT NULL THEN ald.DLVY_DTT
    WHEN ald.SHPD_DTT IS NOT NULL THEN ald.SHPD_DTT
    ELSE ald.STRD_DTT
  END AS date)

LEFT JOIN (
SELECT Country AS RegionCountry,
StateName AS RegionStateName,
StateAbbv AS RegionState,
Region,
CarrierManager
FROM USCTTDEV.dbo.tblRegionalAssignments
) region ON region.RegionState = CASE
    WHEN OrderType LIKE '%INBOUND%' THEN LAST_STA_CD
    ELSE FRST_STA_CD
  END

WHERE ald.STATUS <> 'Cancelled'
AND ald.ID < 10