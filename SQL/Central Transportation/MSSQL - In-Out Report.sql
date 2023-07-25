SELECT CityState, CA.Name as Carrier, SCAC, CA.SRVC_DESC as "SCAC Description", LY_VOL, InboundLoads, OutboundLoads FROM (SELECT DISTINCT
  locations.CityState,
  locations.SCAC,
  outbound.OutboundLoads,
  inbound.InboundLoads,
  COALESCE(outbound.LY_VOL,0) + COALESCE(inbound.LY_VOL,0) AS LY_VOL
FROM (SELECT DISTINCT
  bal.Origin CityState,
  bar.SCAC
FROM USCTTDEV.dbo.tblBidAppLanes bal
INNER JOIN USCTTDEV.dbo.tblBidAppRates bar
  ON bal.LaneID = bar.laneID
UNION ALL
SELECT DISTINCT
  bal.Dest CityState,
  bar.SCAC
FROM USCTTDEV.dbo.tblBidAppLanes bal
INNER JOIN USCTTDEV.dbo.tblBidAppRates bar
  ON bal.LaneID = bar.laneID) locations

LEFT JOIN (SELECT DISTINCT
  bal.ORIGIN,
  bar.SCAC,
  CAST(SUM(bar.AWARD_LDS) AS int) OutboundLoads,
  CAST(SUM(bar.LY_VOL) AS int) LY_VOL
FROM USCTTDEV.dbo.tblBidAppLanes bal
INNER JOIN USCTTDEV.dbo.tblBidAppRates bar
  ON bal.LaneID = bar.laneID
GROUP BY bal.Origin,
         bar.SCAC) outbound
  ON locations.CityState = outbound.Origin
  AND locations.SCAC = outbound.SCAC

LEFT JOIN (SELECT DISTINCT
  bal.Dest,
  bar.SCAC,
  CAST(SUM(bar.AWARD_LDS) AS int) InboundLoads,
  CAST(SUM(bar.LY_VOL) AS int) LY_VOL
FROM USCTTDEV.dbo.tblBidAppLanes bal
INNER JOIN USCTTDEV.dbo.tblBidAppRates bar
  ON bal.LaneID = bar.laneID
GROUP BY bal.Dest,
         bar.SCAC) inbound
  ON inbound.Dest = locations.CityState
  AND inbound.SCAC = locations.SCAC

WHERE OutboundLoads IS NOT NULL
OR InboundLoads IS NOT NULL) Data

LEFT JOIN USCTTDEV.dbo.tblCarriers ca on ca.SRVC_CD = data.SCAC
ORDER BY CityState, SCAC ASC

