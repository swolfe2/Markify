USE [USCTTDEV]
GO
/****** Object:  StoredProcedure [dbo].[sp_CancelledLoads]    Script Date: 1/17/2020 11:50:03 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Steve Wolfe, steve.wolfe@kcc.com, Central Transportation Team
-- Create date: 1/2/2020
-- Last modified: 1/16/2020
-- 1/16/2020 - SW - Now deleting from USCTTDEV.dbo.tblActualLoadDetail where the status is not between 300 AND 345
-- Description:	Update MSSQL tables for cancelled loads in TM
-- =============================================

ALTER PROCEDURE [dbo].[sp_CancelledLoads]

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

/*
What is this file doing?

1) Create temp table for cancelled loads within the past 2 calendar years
2) Update RFT table with cancelled load details
3) Update Actual Load Details with cancelled load details
4) Update Operational Metrics with cancelled load details

*/

/*
Create temp table for Canceled Loads
*/
DROP TABLE IF EXISTS ##tblCanceledLoadsTemp
SELECT * INTO ##tblCanceledLoadsTemp FROM OPENQUERY(NAJDAPRD, '
SELECT DISTINCT
    l.ld_leg_id,
    l.cur_optlstat_id,
    s.stat_shrt_desc,
    EXTRACT(YEAR FROM
        CASE
            WHEN l.shpd_dtt IS NULL THEN
                l.strd_dtt
            ELSE
                l.shpd_dtt
        END
    ) AS year,
    l.shpd_dtt,
    l.strd_dtt
FROM
    najdaadm.load_leg_r   l
    INNER JOIN najdaadm.status_r     s ON l.cur_optlstat_id = s.stat_id
WHERE
    (EXTRACT(YEAR FROM
        CASE
            WHEN l.shpd_dtt IS NULL THEN
                l.strd_dtt
            ELSE
                l.shpd_dtt
        END
    ) >= EXTRACT(YEAR FROM SYSDATE) - 2 OR l.strd_dtt IS NULL)
    AND l.cur_optlstat_id IN (
        350,
        355,
        360
    )
ORDER BY
    l.strd_dtt ASC
')

/*
SELECT * FROM ##tblCanceledLoadsTemp
SELECT * FROM USCTTDEV.dbo.tblRFTDetailDataHistorical WHERE ID <10
Update RFT Table with Cancelled status
*/
UPDATE USCTTDEV.dbo.tblRFTDetailDataHistorical
SET CurrentStatus = clt.CUR_OPTLSTAT_ID, CurrentStatusDesc = clt.STAT_SHRT_DESC
FROM USCTTDEV.dbo.tblRFTDetailDataHistorical rft
INNER JOIN ##tblCanceledLoadsTemp clt ON clt.LD_LEG_ID = rft.LOAD_NUMBER
WHERE rft.CurrentStatus <> clt.CUR_OPTLSTAT_ID

/*
SELECT * FROM ##tblCanceledLoadsTemp
SELECT * FROM tblActualLOadDetail WHERE ID <10
SELECT * INTO ##tblActualLOadDetail FROM USCTTDEV.dbo.tblActualLoadDetail
Update Actual Load Detail with Cancelled status
*/
UPDATE USCTTDEV.dbo.tblActualLoadDetail
SET CUR_OPTLSTAT_ID = clt.CUR_OPTLSTAT_ID, Status = clt.STAT_SHRT_DESC
FROM USCTTDEV.dbo.tblActualLoadDetail  ald
INNER JOIN ##tblCanceledLoadsTemp clt ON clt.LD_LEG_ID = ald.LD_LEG_ID
WHERE ald.CUR_OPTLSTAT_ID <> clt.CUR_OPTLSTAT_ID

/*
SELECT * FROM ##tblCanceledLoadsTemp
SELECT * FROM ##tblOperationalMetrics WHERE ID <10
SELECT * INTO ##tblOperationalMetrics FROM USCTTDEV.dbo.tblOperationalMetrics
Update Operational Metrics table with Cancelled status
*/
UPDATE USCTTDEV.dbo.tblOperationalMetrics
SET LOAD_STATUS = clt.STAT_SHRT_DESC
FROM USCTTDEV.dbo.tblOperationalMetrics om
INNER JOIN ##tblCanceledLoadsTemp clt ON clt.LD_LEG_ID = om.LD_LEG_ID
WHERE om.LOAD_STATUS <> clt.STAT_SHRT_DESC

/*
Delete from USCTTDEV.dbo.tblActualLoadDetail if the
CUR_OPTLSTAT_ID NOT BETWEEN 300 AND 345
This will handle Cancelled and Deleted loads
*/
DELETE FROM USCTTDEV.dbo.tblActualLoadDetail
WHERE CUR_OPTLSTAT_ID NOT BETWEEN 300 AND 345

/*
Redundant, but I do it anyway! : D 
Delete Temp table, if exists
*/
DROP TABLE IF EXISTS
##tblCanceledLoadsTemp

END