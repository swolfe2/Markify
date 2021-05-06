/*SELECT DISTINCT Lane
FROM USCTTDEV.dbo.tblAwardRatesHistorical
WHERE CAST(EffectiveDate AS DATE) BETWEEN '2/1/2020' AND '1/30/2021'

SELECT * FROM USCTTDEV.dbo.tblAwardRatesHistorical arh 
WHERE arh.Lane = 'ALMIDCIT-5AL36610'
*/
INSERT INTO USCTTDEV.dbo.tblAwardRatesHistorical (LaneID, Lane, ORIG_CITY_STATE, Origin, DEST_CITY_STATE, Miles, FMIC, Comment, RateComment, [Order Type], WeightedRPM, AwardCarrierCount, AwardPercent, Carrier, CarrierName, SCAC, SCACName, Broker, Mode, EQUIPMENT, PreAward, AWARD_PCT, AWARD_LDS, AwardSum, [Rate Per Mile], [Min Charge], CUR_RPM, AllInCost, Rank_Num, Rank, EffectiveDate, ExpirationDate, AddedOn, LastUpdated)
SELECT miss.LaneID,
miss.Lane,
miss.ORIG_CITY_STATE,
miss.Origin,
miss.DEST_CITY_STATE,
miss.Miles,
miss.FMIC,
miss.Comment,
miss.RateComment,
miss.[Order Type],
CASE WHEN miss.WeightedRPM IS NULL THEN miss.CUR_RPM ELSE miss.WeightedRPM END AS WeightedRPM,
miss.AwardCarrierCount,
miss.AWARD_PCT,
miss.Carrier,
miss.CarrierName,
miss.SCAC,
miss.SCACName,
miss.Broker,
miss.Mode,
miss.EQUIPMENT,
miss.PreAward,
miss.AWARD_PCT,
miss.AWARD_LDS,
miss.AwardSum,
miss.[Rate Per Mile],
miss.[Min Charge],
miss.CUR_RPM,
miss.AllInCost,
miss.Rank_Num,
miss.Rank,
miss.EffectiveDate,
miss.ExpirationDate,
miss.AddedOn,
miss.LastUpdated
FROM (

SELECT DISTINCT 
bal.LaneID,
bal.Lane,
bal.ORIG_CITY_STATE,
bal.Origin,
bal.DEST_CITY_STATE,
bal.Dest,
bal.Miles,
bal.FMIC,
bal.COMMENT,
'Added from missing rates 4/7/2021' AS RateComment,
bal.[Order Type],
bal.AwardWeightedRPM AS WeightedRPM,
COUNT(DISTINCT bar.SCAC) AS AwardCarrierCount,
SUM(bar.AWARD_PCT) AS AwardPercent,
arhdos.Carrier,
arhdos.CarrierName,
arhdos.SCAC,
arhdos.SCACName,
arhdos.Broker,
arhdos.MODE,
arhdos.EQUIPMENT,
arhdos.PreAward,
arhdos.AWARD_PCT,
arhdos.AWARD_LDS,
arhdos.AWARD_PCT AS AwardSum,
arhdos.[Rate Per Mile],
arhdos.[Min Charge],
arhdos.CUR_RPM,
arhdos.AllInCost,
arhdos.Rank_Num,
arhdos.Rank_Num AS Rank,
'2/01/2020' AS EffectiveDate,
'1/30/2021' AS ExpirationDate,
GETDATE() AS AddedOn,
GETDATE() AS LastUpdated


FROM USCTTDEV.dbo.tblBidAppLanes2020Archive bal
INNER JOIN USCTTDEV.dbo.tblBidAppRates2020Archive bar ON bal.LaneID = bar.LaneID

LEFT JOIN (
SELECT DISTINCT Lane
FROM USCTTDEV.dbo.tblAwardRatesHistorical
WHERE CAST(EffectiveDate AS DATE) BETWEEN '2/1/2020' AND '1/30/2021'
) arh ON arh.Lane = bal.Lane


INNER JOIN (
SELECT bal.LaneID,
bal.Lane,
bal.OriginGroup,
bal.OriginCountry,
bal.ORIG_CITY_STATE,
bal.Origin,
bal.OriginZIP,
bal.DestCountry,
bal.DEST_CITY_STATE,
bal.Dest,
bal.Miles,
bal.BID_LOADS,
bal.UPDATED_LOADS,
bal.FMIC AS LaneFMIC,
bal.COMMENT AS LaneComment,
bal.PrimaryCustomer,
bal.PrimaryUnloadType,
bal.[Order Type],
bal.PreAwardLane,
bal.AAO AS LaneAAO,
bal.CostcoGroup,
bal.AwardWeightedRPM,
bal.AwardWeightedService,
bal.CoupaTab,
bal.BusinessUnit,
bal.CurrentVolume AS LaneCurrentVolume,
bal.DestZip,
bar.Equipment,
ca.CARR_CD AS Carrier,
ca.Name AS CarrierName,
bar.SCAC,
ca.SRVC_DESC AS SCACName,
ca.Broker,
bar.Mode,
bar.LY_VOL,
bar.LY_RPM,
bar.BID_RPM,
bar.BID_AWARD_PCT,
bar.BID_AWARD_LDS,
bar.AWARD_PCT,
bar.AWARD_LDS,
bar.ACTIVE_FLAG,
bar.COMMENT,
bar.Service,
bar.Confirmed,
bar.EffectiveDate,
bar.Expirationdate,
bar.Reason,
bar.[Rate Per Mile],
bar.[Min Charge],
bar.CUR_RPM,
bar.Rank_Num,
bar.ChargeType,
bar.AllInCost,
bar.PreAward,
bar.AAO,
bar.FMIC,
bar.CurrentVolume
FROM USCTTDEV.dbo.tblBidAppLanes2020Archive bal
INNER JOIN USCTTDEV.dbo.tblBidAppRates2020Archive bar ON bal.LaneID = bar.LaneID
INNER JOIN USCTTDEV.dbo.tblCarriers ca ON ca.SRVC_CD = bar.SCAC
LEFT JOIN (
SELECT DISTINCT Lane
FROM USCTTDEV.dbo.tblAwardRatesHistorical
WHERE CAST(EffectiveDate AS DATE) BETWEEN '2/1/2020' AND '1/30/2021'
) arh ON arh.Lane = bal.Lane
WHERE bar.AWARD_PCT IS NOT NULL
AND arh.Lane IS NULL
)arhdos ON arhdos.Lane = bal.Lane

WHERE bar.AWARD_PCT IS NOT NULL
AND arh.Lane IS NULL
/*AND bal.Lane = 'ALHUNTSV-5AL36610'*/

GROUP BY bal.LaneID,
bal.Lane,
bal.ORIG_CITY_STATE,
bal.Origin,
bal.DEST_CITY_STATE,
bal.Dest,
bal.Miles,
bal.FMIC,
bal.COMMENT,
bal.[Order Type],
bal.AwardWeightedRPM,
arhdos.Carrier,
arhdos.CarrierName,
arhdos.SCAC,
arhdos.SCACName,
arhdos.Broker,
arhdos.MODE,
arhdos.EQUIPMENT,
arhdos.PreAward,
arhdos.AWARD_PCT,
arhdos.AWARD_LDS,
arhdos.AWARD_PCT,
arhdos.[Rate Per Mile],
arhdos.[Min Charge],
arhdos.CUR_RPM,
arhdos.AllInCost,
arhdos.Rank_Num,
arhdos.Rank_Num
) miss --2932
LEFT JOIN USCTTDEV.dbo.tblAwardRatesHistorical arh ON arh.Lane = miss.Lane
AND arh.SCAC = arh.SCAC
AND CAST(miss.EffectiveDate AS DATE) BETWEEN CAST(arh.EffectiveDate AS DATE) AND CAST(arh.ExpirationDate AS DATE)

WHERE arh.Lane IS NULL
AND arh.SCAC IS NULL

ORDER BY miss.LaneID ASC,
miss.AWARD_PCT DESC

/*


This is how to do all of this shit manually, should you ever have to


*/

/*
UPDATE USCTTDEV.dbo.tblAwardRatesHistorical
SET ExpirationDate = '1/30/2021',
RateComment = 'Updated 4/8/2021 for Data Integrity Issues'
WHERE ID = 15807
*/

DECLARE @Lane NVARCHAR(30)
SET @Lane = 'WINEENAH-5CA91761'

SELECT DISTINCT 
arh.ID,
arh.Lane,
arh.SCAC,
arh.AWARD_PCT, 
arh.AWARD_LDS,
arh.WeightedRPM,
arh.CUR_RPM,
arh.EffectiveDate,
arh.ExpirationDate,
arh.LastUpdated,
arh.RateComment
FROM USCTTDEV.dbo.tblAwardRatesHistorical arh
WHERE arh.Lane = @Lane
AND arh.EffectiveDate <= '1/31/2021'
ORDER BY Lane ASC, EffectiveDate ASC, ID ASC

SELECT * FROM USCTTDEV.dbo.tblBidAppChangelog cl
WHERE cl.Lane = @Lane
AND cl.Field = 'AWARD_PCT'
AND cl.ChangeTable = 'tblBidAppRates'
AND UpdatedOn >= '2/1/2020'
ORDER BY ID DESC

SELECT * FROM USCTTDEV.dbo.tblBidAppRatesWeeklyAwards barwa
WHERE barwa.ORIG_CITY_STATE + '-' + barwa.DEST_CITY_STATE = @Lane
AND barwa.WeekStartDate BETWEEN '1/1/2021' AND '1/31/2021'
ORDER BY WeekStartDate ASC

SELECT DISTINCT bar.Lane,
bar.SCAC,
bar.CUR_RPM
FROM USCTTDEV.dbo.tblBidAppRates2020Archive bar
WHERE bar.Lane = @Lane

/*
UPDATE USCTTDEV.dbo.tblAwardRatesHistorical
SET EffectiveDate = '3/16/2020',
RateComment = 'Updated 4/8/2021 for Data Integrity Issues'
WHERE ID = 17032
*/

/*
UPDATE USCTTDEV.dbo.tblAwardRatesHistorical
SET ExpirationDate = '1/30/2021',
EffectiveDate = '1/15/2021',
CUR_RPM = 0.63,
WeightedRPM = 0.63,
RateComment = 'Updated 4/8/2021 for Data Integrity Issues'
WHERE ID = 44677
*/

/*
UPDATE USCTTDEV.dbo.tblAwardRatesHistorical
SET ExpirationDate = '1/30/2021',
EffectiveDate = '11/12/2020',
Carrier = 'NFIL',
CarrierName = 'NFI Interactive Logistics',
SCAC = 'NFIL',
SCACName = 'NFIL - Truckload',
CUR_RPM = 1.05,
WeightedRPM = 1.05,
RateComment = 'Updated 4/8/2021 for Data Integrity Issues'
WHERE ID = 44705
*/

/*
UPDATE USCTTDEV.dbo.tblAwardRatesHistorical
SET ExpirationDate = '1/30/2021',
EffectiveDate = '6/20/2020',
Carrier = 'CFAA',
CarrierName = 'Cheema Freightlines',
SCAC = 'CFAA',
SCACName = 'CFAA - Truckload',
CUR_RPM = 1.95,
WeightedRPM = 1.95,
RateComment = 'Updated 4/8/2021 for Data Integrity Issues'
WHERE ID = 44708
*/

/*
UPDATE USCTTDEV.dbo.tblAwardRatesHistorical
SET ExpirationDate = '1/30/2021',
EffectiveDate = '7/16/2020',
Carrier = 'LEGS',
CarrierName = 'Legend Transportation',
SCAC = 'LEGS',
SCACName = 'LEGS - Truckload',
CUR_RPM = .99,
WeightedRPM = .99,
AWARD_PCT = 1,
AWARD_LDS = 65,
RateComment = 'Updated 4/8/2021 for Data Integrity Issues'
WHERE ID = 44704
*/

/*
SELECT * FROM USCTTDEV.dbo.tblCarriers WHERE SRVC_CD = 'CFAA'
SELECT * FROM USCTTDEV.dbo.tblAwardRatesHistorical WHERE ID = 44640
*/

/*
SELECT * FROM USCTTDEV.dbo.tblAwardRatesHistorical WHERE ID = 948

INSERT INTO USCTTDEV.dbo.tblAwardRatesHistorical (LaneID, Lane, ORIG_CITY_STATE, Origin, DEST_CITY_STATE, Dest, Miles, FMIC, Comment, RateComment, [Order Type], WeightedRPM, AwardCarrierCount, AwardPercent, Carrier, CarrierName, SCAC, SCACName, Broker, Mode, Equipment, PreAward, Award_PCT, AWARD_LDS, AwardSum, [Rate Per Mile], [Min Charge], CUR_RPM, AllInCost, Rank_Num, Rank, EffectiveDate, ExpirationDate, AddedOn, LastUpdated)
SELECT LaneID, Lane, ORIG_CITY_STATE, Origin, DEST_CITY_STATE, Dest, Miles, FMIC, Comment, RateComment, [Order Type], WeightedRPM, AwardCarrierCount, AwardPercent, Carrier, CarrierName, SCAC, SCACName, Broker, Mode, Equipment, PreAward, Award_PCT, AWARD_LDS, AwardSum, [Rate Per Mile], [Min Charge], CUR_RPM, AllInCost, Rank_Num, Rank, EffectiveDate, ExpirationDate, GETDATE(), GETDATE()
FROM USCTTDEV.dbo.tblAwardRatesHistorical
WHERE ID = 18071

DELETE FROM USCTTDEV.dbo.tblAwardRatesHistorical WHERE ID = 44708
SELECT * FROM USCTTDEV.dbo.tblAwardRatesHistorical WHERE ID = 44708
*/
