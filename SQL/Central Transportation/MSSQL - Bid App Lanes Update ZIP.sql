/*
Get unique origin ZIPS by ORIG_CITY_STATE
*/
DROP TABLE IF EXISTS ##tblOriginZipTemp
SELECT * INTO ##tblOriginZipTemp 
FROM(
SELECT DISTINCT bal.ORIG_CITY_STATE, bal.ORIGINZip
FROM USCTTDEV.dbo.tblBidAppLanes bal
WHERE bal.OriginZIP IS NOT NULL)data

/*
Update where the origin ZIP is null
*/
UPDATE USCTTDEV.dbo.tblBidAppLanes
SET OriginZip = ozt.OriginZip
FROM USCTTDEV.dbo.tblBidAppLanes bal
INNER JOIN ##tblOriginZipTemp ozt ON ozt.ORIG_CITY_STATE = bal.ORIG_CITY_STATE
WHERE bal.OriginZip IS NULL

/*
Get unique Dest City/States for each DEST_CITY_STATE
*/
DROP TABLE IF EXISTS ##tblDestinationCityState
SELECT * INTO ##tblDestionationCityState
FROM(
SELECT DISTINCT bal.DEST_CITY_STATE, bal.DEST
FROM USCTTDEV.dbo.tblBidAppLanes bal
WHERE bal.Dest IS NOT NULL) data

/*
Update where the Dest is null
*/
UPDATE USCTTDEV.dbo.tblBidAppLanes
SET Dest = dt.Dest
FROM USCTTDEV.dbo.tblBidAppLanes bal
INNER JOIN ##tblDestionationCityState dt ON dt.DEST_CITY_STATE = bal.DEST_CITY_STATE
WHERE bal.Dest IS NULL