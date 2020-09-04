SELECT DISTINCT
  Plant,
  CARR_CD,
  NAME,
  SRVC_CD,
  SRVC_DESC,
  SUM(Inbound) AS Inbound,
  SUM(Outbound) AS Outbound
FROM (SELECT DISTINCT
  Plant,
  CARR_CD,
  Name,
  SRVC_CD,
  SRVC_DESC,
  pt.Inbound,
  pt.Outbound
FROM (SELECT DISTINCT
  ald.Region,
  REPLACE(ald.OriginPlant, ' (5 POINTS)','') AS Plant,
  ald.Origin_Zone AS Zone,
  ald.CARR_CD,
  ald.Name,
  ald.SRVC_CD,
  ald.SRVC_DESC,
  'Outbound' AS TYPE,
  COUNT(DISTINCT ald.LD_LEG_ID) AS LoadCount
FROM USCTTDEV.dbo.tblActualLoadDetail ald
WHERE SHPD_DTT BETWEEN '9/1/2019' AND '2/29/2020'
AND LEFT(ald.OriginPlant, 1) = '2'
GROUP BY ald.Region,
         REPLACE(ald.OriginPlant, ' (5 POINTS)',''),
         ald.Origin_Zone,
         ald.CARR_CD,
         ald.Name,
         ald.SRVC_CD,
         ald.SRVC_DESC

UNION ALL

SELECT DISTINCT
  ald.Region,
  REPLACE(ald.DestinationPlant, ' (5 POINTS)','') AS Plant,
  ald.Dest_Zone AS Zone,
  ald.CARR_CD,
  ald.Name,
  ald.SRVC_CD,
  ald.SRVC_DESC,
  'Inbound' AS TYPE,
  COUNT(DISTINCT ald.LD_LEG_ID) AS LoadCount
FROM USCTTDEV.dbo.tblActualLoadDetail ald
WHERE SHPD_DTT BETWEEN '9/1/2019' AND '2/29/2020'
AND LEFT(ald.DestinationPlant, 1) = '2'
GROUP BY ald.Region,
         REPLACE(ald.DestinationPlant, ' (5 POINTS)',''),
         ald.Dest_Zone,
         ald.CARR_CD,
         ald.Name,
         ald.SRVC_CD,
         ald.SRVC_DESC) AS loads

PIVOT
(
SUM(Loadcount)
FOR Type
IN ([Inbound], [Outbound])
) AS pt) hist
GROUP BY Plant,
         CARR_CD,
         NAME,
         SRVC_CD,
         SRVC_DESC

ORDER BY Plant ASC, CARR_CD ASC, SRVC_CD ASC