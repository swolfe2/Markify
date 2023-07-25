/*
TODO: Start with Max record

SELECT * FROM USCTTDEV.dbo.tblAuditLoadLeg
WHERE LD_LEG_ID = 516816107 order by ID ASC
*/

/*
Unique Year / Week Start Date FROM MONDAY / Week Number

SELECT DISTINCT YEAR(CAST(DATEADD(wk, DATEDIFF(wk,0,AUDT_SYS_DTT), 0) AS date)) AS Year, 
CAST(DATEADD(wk, DATEDIFF(wk,0,AUDT_SYS_DTT), 0) AS date) AS WeekStartDate, 
DATEPART(wk,CAST(DATEADD(wk, DATEDIFF(wk,0,AUDT_SYS_DTT), 0) AS date)) as WeekNumber
FROM USCTTDEV.dbo.tblAuditLoadLeg
ORDER BY YEAR(CAST(DATEADD(wk, DATEDIFF(wk,0,AUDT_SYS_DTT), 0) AS date)), 
CAST(DATEADD(wk, DATEDIFF(wk,0,AUDT_SYS_DTT), 0) AS date) ASC
*/

/*
Look for specific LD_LEG_ID details

SELECT * FROM USCTTDEV.dbo.tblAuditLoadLeg
WHERE LD_SRVC_CD = 'FHTP' AND CAST(DATEADD(wk, DATEDIFF(wk,0,AUDT_SYS_DTT), 0) AS date) = '2018-12-31'

SELECT DISTINCT AUDT_CNFG_CD, COUNT(*) as COUNT FROM USCTTDEV.dbo.tblAuditLoadLeg
WHERE LD_SRVC_CD = 'FHTP' AND CAST(DATEADD(wk, DATEDIFF(wk,0,AUDT_SYS_DTT), 0) AS date) = '2018-12-31'
GROUP BY AUDT_CNFG_CD
*/

/*
SELECT DISTINCT al.LD_CARR_CD, ca.CARR_CD, LD_SRVC_CD 
FROM USCTTDEV.dbo.tblAuditLoadLeg al
LEFT JOIN USCTTDEV.dbo.tblCarriers ca ON ca.SRVC_CD = al.ld_srvc_cd
WHERE ca.srvc_cd IS NULL
ORDER BY LD_SRVC_CD ASC, LD_CARR_CD ASC
*/

DECLARE @cols AS NVARCHAR(MAX),
@query AS NVARCHAR(MAX),
@query2 AS NVARCHAR(MAX),
@tempQuery AS NVARCHAR(MAX)

/*
Create a temp, pivoted table of time series by carrier / service, with counts of deliveries by category type
*/

SET @cols = STUFF((
			SELECT DISTINCT ',' + QUOTENAME(c.AUDT_SEC_DESC)
			FROM USCTTDEV.dbo.tblAuditLoadLeg c
			FOR XML PATH(''),
				TYPE
			).value('.', 'NVARCHAR(MAX)'), 1, 1, '')

SET @query = 'SELECT Year, WeekStartDate, WeekNumber, CASE WHEN LD_CARR_CD IS NULL THEN LD_SRVC_CD ELSE LD_CARR_CD END AS LD_CARR_CD, LD_SRVC_CD , ' + @cols + ' from 
            (
                select YEAR(CAST(DATEADD(wk, DATEDIFF(wk,0,AUDT_SYS_DTT), 0) AS date)) AS Year,
				CAST(DATEADD(wk, DATEDIFF(wk,0,AUDT_SYS_DTT), 0) AS date) AS WeekStartDate,
				DATEPART(wk,CAST(DATEADD(wk, DATEDIFF(wk,0,AUDT_SYS_DTT), 0) AS date)) as WeekNumber,
                CASE WHEN LD_CARR_CD IS NULL THEN LD_SRVC_CD ELSE LD_CARR_CD END AS LD_CARR_CD,
				LD_SRVC_CD,
				AUDT_SEC_DESC,
				LD_LEG_ID
                FROM USCTTDEV.dbo.tblAuditLoadLeg prdr	
				--WHERE LD_SRVC_CD = ''FHTP''
           ) x
            pivot 
            (
                 COUNT(LD_LEG_ID)
                for AUDT_SEC_DESC in (' + @cols + ')
            ) p '
SET @query = 'select * from (' + @query + ') y '
--EXECUTE (@query)

DROP TABLE IF EXISTS ##TempPivot
SET @tempQuery = 'SELECT * INTO ##TempPivot FROM (' + @query + ')data 
ORDER BY Year ASC,
WeekStartDate ASC, 
LD_CARR_CD ASC, 
LD_SRVC_CD ASC'
EXECUTE (@tempQuery)

SELECT * FROM ##TempPivot
ORDER BY Year ASC,
WeekStartDate ASC, 
LD_CARR_CD ASC, 
LD_SRVC_CD ASC


/*
Looking at all carr_cd / srvc_cd, even when a LD_CARR_CD might be null

SET @query2 = 'SELECT Year, WeekStartDate, WeekNumber, LD_CARR_CD, LD_SRVC_CD , ' + @cols + ' from 
            (
                select YEAR(CAST(DATEADD(wk, DATEDIFF(wk,0,AUDT_SYS_DTT), 0) AS date)) AS Year,
				CAST(DATEADD(wk, DATEDIFF(wk,0,AUDT_SYS_DTT), 0) AS date) AS WeekStartDate,
				DATEPART(wk,CAST(DATEADD(wk, DATEDIFF(wk,0,AUDT_SYS_DTT), 0) AS date)) as WeekNumber,
                LD_CARR_CD,
				LD_SRVC_CD,
				AUDT_SEC_DESC,
				LD_LEG_ID
                FROM USCTTDEV.dbo.tblAuditLoadLeg prdr	
				--WHERE LD_SRVC_CD = ''FHTP''
           ) x
            pivot 
            (
                 COUNT(LD_LEG_ID)
                for AUDT_SEC_DESC in (' + @cols + ')
            ) p '
SET @query2 = 'select * from (' + @query2 + ') y ORDER BY Year ASC, WeekStartDate ASC, LD_CARR_CD ASC, LD_SRVC_CD ASC'
EXECUTE (@query2)
*/

