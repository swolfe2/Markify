SELECT bal.LaneID, 
bal.Lane, 
bal.ORIG_CITY_STATE,
bal.Miles,
bal.UPDATED_LOADS AS LaneLoads,
count(SCAC) AS BrokerSCACCount, 
CAST(ROUND(min(CUR_RPM),2) AS numeric(18,2)) AS BrokerMinRPM,
CAST(ROUND(avg(CUR_RPM),2) AS numeric(18,2)) AS BrokerAvgRPM,
brokerawards.BrokerAwardSCACCount,
brokerawards.BrokerAwardRPM,
brokerawards.BrokerAwardLoads,
nonbroker.NonBrokerSCACCount,
nonbroker.NonBrokerAvgRPM,
nonbrokerawards.NonBrokerAwardSCACCount,
nonbrokerawards.NonBrokerAwardRPM,
nonbrokerawards.NonBrokerWeightedAvgRPM,
nonbrokerawards.NonBrokerAwardLoads,
intermodal.IntermodalAwardLoads,
CAST(intermodal.[IntermodalAward%] AS Numeric(18,2)) AS 'IntermodalAward%',
CAST(CAST(nonbrokerawards.NonBrokerAwardLoads AS Numeric(18,2)) / bal.UPDATED_LOADS AS Numeric(18,2)) AS 'NonBrokerAward%',
CAST(CAST(brokerawards.BrokerAwardLoads AS Numeric(18,2))/ bal.UPDATED_LOADS AS Numeric(18,2)) AS 'BrokerAward%',
CAST((COALESCE(nonbrokerawards.NonBrokerAwardLoads / bal.UPDATED_LOADS,0))+(COALESCE(brokerawards.BrokerAwardLoads / bal.UPDATED_LOADS,0)) + COALESCE(intermodal.[IntermodalAward%],0) AS Numeric (18,2)) AS 'TotalAward%'
FROM USCTTDEV.dbo.tblBidAppRates bar
INNER JOIN USCTTDEV.dbo.tblCarriers ca ON ca.SRVC_CD = bar.SCAC
INNER JOIN USCTTDEV.dbo.tblBidAppLanes bal ON bal.LaneID = bar.LaneID
INNER JOIN USCTTDEV.dbo.tblBidAppBrokerLimits babl ON babl.OriginZONe = bal.ORIG_CITY_STATE

LEFT JOIN (
SELECT DISTINCT bal.LaneID, count(bar.SCAC) AS BrokerAwardSCACCount, CAST(ROUND(avg(bar.CUR_RPM),2) AS numeric(18,2)) AS BrokerAwardRPM, CAST(SUM(AWARD_LDS) AS INT) AS BrokerAwardLoads
FROM USCTTDEV.dbo.tblBidAppLanes bal
INNER JOIN USCTTDEV.dbo.tblBidAppRates bar ON bar.LaneID = bal.LaneID
INNER JOIN USCTTDEV.dbo.tblBidAppBrokerLimits babl ON babl.OriginZONe = bal.ORIG_CITY_STATE
INNER JOIN USCTTDEV.dbo.tblCarriers ca ON ca.SRVC_CD = bar.SCAC
WHERE bar.AWARD_PCT IS NOT NULL 
AND ca.Broker = 'Y'
AND bar.ACTIVE_FLAG = 'Y'
AND bar.Equipment = '53FT'
GROUP BY bal.LaneID
) brokerawards ON brokerawards.LaneID = bal.LaneID

LEFT JOIN (
SELECT bar.LaneID, bar.Lane, bar.Equipment, count(SCAC) AS NonBrokerSCACCount, CAST(ROUND(avg(CUR_RPM),2) AS numeric(18,2)) AS NonBrokerAvgRPM 
FROM USCTTDEV.dbo.tblBidAppRates bar
INNER JOIN USCTTDEV.dbo.tblCarriers ca ON ca.SRVC_CD = bar.SCAC
INNER JOIN USCTTDEV.dbo.tblBidAppLanes bal ON bal.LaneID = bar.LaneID
INNER JOIN USCTTDEV.dbo.tblBidAppBrokerLimits babl ON babl.OriginZONe = bal.ORIG_CITY_STATE
WHERE ca.Broker IS NULL 
AND bar.ACTIVE_FLAG = 'Y'
AND bar.EQUIPMENT = '53FT'
GROUP BY bar.LaneID, bar.Lane, bar.Equipment
) nonbroker ON nonbroker.LaneID = bal.LaneID

LEFT JOIN (
SELECT DISTINCT bal.LaneID, count(bar.SCAC) AS NonBrokerAwardSCACCount, CAST(ROUND(avg(bar.CUR_RPM),2) AS numeric(18,2)) AS NonBrokerAwardRPM, CAST(SUM(AWARD_LDS) AS INT) AS NonBrokerAwardLoads,
CAST(Sum(bar.cur_rpm*bar.award_pct) / Sum(bar.award_pct) AS DECIMAL(18, 2)) AS NonBrokerWeightedAvgRPM 
FROM USCTTDEV.dbo.tblBidAppLanes bal
INNER JOIN USCTTDEV.dbo.tblBidAppRates bar ON bar.LaneID = bal.LaneID
INNER JOIN USCTTDEV.dbo.tblBidAppBrokerLimits babl ON babl.OriginZONe = bal.ORIG_CITY_STATE
INNER JOIN USCTTDEV.dbo.tblCarriers ca ON ca.SRVC_CD = bar.SCAC
WHERE bar.AWARD_PCT IS NOT NULL 
AND ca.Broker IS NULL
AND bar.ACTIVE_FLAG = 'Y'
AND bar.Equipment = '53FT'
GROUP BY bal.LaneID
) nonbrokerawards ON nonbrokerawards.LaneID = bal.LaneID

LEFT JOIN (
SELECT DISTINCT bal.LaneID, SUM(bar.AWARD_PCT) AS 'IntermodalAward%', CAST(ROUND(sum(bar.Award_PCT) * bal.UPDATED_LOADS,0) AS INT) AS 'IntermodalAwardLoads'
FROM USCTTDEV.dbo.tblBidAppLanes bal
INNER JOIN USCTTDEV.dbo.tblBidAppRates bar ON bar.LaneID = bal.LaneID
WHERE AWARD_PCT IS NOT NULL
AND bar.EQUIPMENT = '53IM'
GROUP BY bal.LaneID, bal.UPDATED_LOADS
) intermodal ON intermodal.LaneID = bal.LaneID

WHERE ca.Broker = 'Y' 
AND bar.ACTIVE_FLAG = 'Y'
AND bal.UPDATED_LOADS > 0

GROUP BY bal.LaneID, 
bal.Lane, 
bal.Miles,
bal.ORIG_CITY_STATE,
bal.UPDATED_LOADS,
bar.Equipment,
brokerawards.BrokerAwardSCACCount,
brokerawards.BrokerAwardRPM,
brokerawards.BrokerAwardLoads,
nonbroker.NonBrokerAvgRPM,
nonbroker.NonBrokerSCACCount,
nonbrokerawards.NonBrokerAwardSCACCount,
nonbrokerawards.NonBrokerAwardRPM,
nonbrokerawards.NonBrokerWeightedAvgRPM,
nonbrokerawards.NonBrokerAwardLoads,
intermodal.IntermodalAwardLoads,
intermodal.[IntermodalAward%]

ORDER BY bal.LaneID ASC