USE [USCTTDEV]
GO
/****** Object:  StoredProcedure [dbo].[sp_CarrierInfo]    Script Date: 1/17/2020 11:50:30 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Steve Wolfe, steve.wolfe@kcc.com, Central Transportation Team>
-- Create date: <9/30/2019>
-- Last modified: <1/15/2020>
-- Description:	<Executes query against Oracle, loads to temp table, then appends/updates dbo.tblCarriers>
-- 1/15/2020 - SW - Added update query for new OPEN SRVC_CDs that get appened to table
-- 10/31/2019 - SW - Added queries to update Name / SRVC_DESC based on Coupa Description, and if CARR_CD already exists
-- =============================================
ALTER PROCEDURE [dbo].[sp_CarrierInfo]
	-- Add the parameters for the stored procedure here
AS
/*
This file will append new carrier information into tblCarriers, and update existing records
MSSQL AUTHOR: Steve Wolfe
*/

/*
Delete Temp table, if exists
*/
DROP TABLE IF EXISTS
##tblCarrierTemp

/*
Declare query variable, since query is more than 8,000 characters
*/
DECLARE @myQuery VARCHAR(MAX)

/*
Set query
*/
SET @myQuery = '
SELECT DISTINCT
    l.carr_cd,
    c.name,
    l.srvc_cd,
    mst.srvc_desc,
    CASE
        WHEN eqmt_typ = ''53IM'' THEN
            ''INTERMODAL''
        ELSE
            ''TRUCK''
    END shipmode,
    COUNT(DISTINCT l.ld_leg_id) shipmentcount,
    MAX(l.shpd_dtt) maxshipdate
FROM
    najdaadm.load_leg_r    l
    INNER JOIN najdaadm.load_at_r     la ON l.frst_shpg_loc_cd = la.shpg_loc_cd
    INNER JOIN najdaadm.status_r      s ON l.cur_optlstat_id = s.stat_id
    INNER JOIN najdaadm.carrier_r     c ON l.carr_cd = c.carr_cd
    LEFT JOIN najdaadm.mstr_srvc_t   mst ON l.srvc_cd = mst.srvc_cd
WHERE
    EXTRACT(YEAR FROM
        CASE
            WHEN l.shpd_dtt IS NULL THEN
                l.strd_dtt
            ELSE
                l.shpd_dtt
        END
    ) >= EXTRACT(YEAR FROM SYSDATE)
    AND l.cur_optlstat_id IN (
        300,
        305,
        310,
        320,
        325,
        335,
        345
    )
    AND l.eqmt_typ IN (
        ''48FT'',
        ''48TC'',
        ''53FT'',
        ''53TC'',
        ''53IM'',
        ''53RT'',
        ''53HC''
    )
    AND l.last_ctry_cd IN (
        ''USA'',
        ''CAN'',
        ''MEX''
    )
GROUP BY
    l.carr_cd,
    c.name,
    l.srvc_cd,
    mst.srvc_desc,
    CASE
            WHEN eqmt_typ = ''53IM'' THEN
                ''INTERMODAL''
            ELSE
                ''TRUCK''
        END
ORDER BY
    carr_cd ASC,
    srvc_cd ASC
'

/*
Create Temp table
*/
CREATE TABLE ##tblCarrierTemp 
  ( 
  CARR_CD		nvarchar(5),
  Name			nvarchar(50),
  SRVC_CD		nvarchar(5),
  SRVC_DESC		nvarchar(50),
  Shipmode		nvarchar(10),
  ShipmentCount	int,
  MaxShipdate	datetime
  ) 

  /*
  Append records from giant Oracle query into MSSQL temp table
  */
  INSERT INTO ##tblCarrierTemp
  EXEC (@myQuery) AT NAJDAPRD

  select * from ##tblCarrierTemp

  /*
  Append new values from ##tblOperationalMetricsTemp to USCTTDEV.DBO.TBLOPERATIONALMETRICS, where the LD_LEG_ID value does not exist
  */
  INSERT INTO USCTTDEV.DBO.tblCarriers 
            (CARR_CD,
			Name,
			SRVC_CD,
			SRVC_DESC,
			Shipmode,
			ShipmentCount,
			MaxShipDate) 
SELECT CT.CARR_CD,
		CT.NAME,
		CT.SRVC_CD,
		CT.SRVC_DESC,
		CT.Shipmode,
		CT.ShipmentCount,
		CT.MaxShipDate
FROM   ##tblCarrierTemp AS CT 
       LEFT JOIN USCTTDEV.DBO.tblCarriers C 
              ON C.SRVC_CD = CT.SRVC_CD
			  AND C.CARR_CD = CT.CARR_CD
WHERE  C.SRVC_CD IS NULL and C.CARR_CD IS NULL
ORDER BY C.CARR_CD ASC, C.SRVC_CD ASC

/*
Declare and set variable for current date/time to use on AddedOn/LastUpdated
*/
DECLARE @currentDateTime as datetime
SET @currentDateTime = GETDATE()

/*
Update ALL fields on MSSQL Server table to match what's currently in Temp table
*/
UPDATE C
SET 
C.AddedOn = CASE WHEN C.AddedOn is null then @currentDateTime else C.AddedOn END,
C.LastUpdated = @currentDateTime,
C.Name = CT.Name,
C.SRVC_DESC = CT.SRVC_DESC,
C.Shipmode = CT.Shipmode,
C.ShipmentCount = CASE WHEN CT.SRVC_CD Is Null THEN 0 ELSE CT.ShipmentCount END,
C.MaxShipDate = CT.MaxShipDate
FROM USCTTDEV.DBO.tblCarriers AS C
LEFT JOIN   ##tblCarrierTemp AS CT 
              ON C.CARR_CD = CT.CARR_CD
			  AND C.SRVC_CD = CT.SRVC_CD

/*
Update USCTTDEV.dbo.tblCarriers where the Name / SRVC_DESC is null
*/
UPDATE USCTTDEV.dbo.tblCarriers
SET NAME = carr.Name
FROM USCTTDEV.dbo.tblCarriers ca
INNER JOIN (SELECT DISTINCT CARR_CD, NAME FROM USCTTDEV.dbo.tblCarriers WHERE NAME IS NOT NULL) carr ON carr.CARR_CD = ca.carr_cd
WHERE ca.NAME IS NULL

/*
Update Name / SRVC DESC / Shipmode where Coupa Description is not null
*/
UPDATE USCTTDEV.dbo.tblCarriers
Set Name = CASE WHEN NAME IS NULL THEN SUBSTRING(CoupaDescription, COALESCE(NULLIF(CHARINDEX('-',CoupaDescription)+2,1),1),8000) ELSE NAME END,
SRVC_DESC = CoupaDescription, SHIPMODE = 'TRUCK'
FROM USCTTDEV.dbo.tblCarriers
WHERE SRVC_DESC IS NULL

/*
Update SRVC_DESC where the SRVC_CD is OPEN
*/
UPDATE USCTTDEV.dbo.tblCarriers
SET SRVC_DESC = 'Open (Spot Quote) Carrier'
WHERE SRVC_CD = 'OPEN'
AND SRVC_DESC IS NULL

/*
Update tblUsage if ClosedOn is null, to OpenedOn time
Probably due to them shutting down / restarting their laptop 
Or some other kind of issue keeping them from closing the DB
*/
UPDATE USCTTDEV.dbo.tblUsage
SET ClosedOn = OpenedOn
WHERE ClosedOn IS NULL

Select * from USCTTDEV.DBO.tblCarriers