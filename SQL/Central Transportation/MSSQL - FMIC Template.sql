SELECT * FROM USCTTDEV.dbo.tblBIdAppLanes
/*
SELECT * FROM USCTTDEV.dbo.tblAwardLanes

SELECT DISTINCT bal.LaneID,
ald.FRST_CTY_NAME, 
ald.FRST_STA_CD, 
left(ald.FRST_PSTL_CD,5) as FRST_ZIP_CD, 
ald.FRST_CTRY_CD
FROM USCTTDEV.dbo.tblActualLoadDetail ald
INNER JOIN USCTTDEV.dbo.tblBidAppLanes bal on bal.Lane = ald.Lane
ORDER BY bal.LaneID ASC
*/
SELECT DISTINCT bal.LaneID,
SUBSTRING(bal.Origin,0,CHARINDEX(',',bal.Origin,0)) AS OriginCity,
SUBSTRING(bal.Origin,CHARINDEX(', ',bal.Origin)+2,LEN(bal.Origin)) AS OriginState,
bal.OriginZIP,
bal.OriginCountry,
SUBSTRING(bal.Dest,0,CHARINDEX(',',bal.Dest,0)) AS DestCity,
SUBSTRING(bal.Dest,CHARINDEX(', ',bal.Dest)+2,LEN(bal.Dest)) AS DestState,
CASE WHEN bal.DestCountry = 'USA' THEN RIGHT(bal.DEST_CITY_STATE,5)
ELSE zips.OriginZip END AS DestZip,
bal.DestCountry,
bal.Miles,
bal.UPDATED_LOADS,
CASE WHEN bal.CostcoGroup IS NULL THEN 'DS' ELSE 'MS' END AS RouteType, --DS = 'Direct Stop' else 'Multi-Stop',
CASE WHEN RIGHT(bal.Lane,4) LIKE '%(TC)%' THEN 'TC' ELSE 'DV' END AS Mode -- TC = 'Temp Control' else 'Dry Van'

FROM USCTTDEV.dbo.tblBidAppLanes bal
INNER JOIN USCTTDEV.dbo.tblBidAppRates bar on bar.LaneID = bal.LaneID
LEFT JOIN (SELECT DISTINCT ORIG_CITY_STATE, MAX(OriginZIP) as OriginZip FROM USCTTDEV.dbo.tblBidAppLanes GROUP BY ORIG_CITY_STATE) zips ON zips.ORIG_CITY_STATE = bal.DEST_CITY_STATE
WHERE bar.EQUIPMENT = '53FT'
ORDER BY bal.LaneID ASC
