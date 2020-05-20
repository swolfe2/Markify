SELECT TOP 10 * FROM ##tblShipmentItemsRaw

/*
INSERT NEW ITEMS INTO tblShipmentItems
SELECT TOP 10 * FROM USCTTDEV.dbo.tblShipmentItems WHERE ShipmentItem = 'COTT,CLNC MR,BT,DISPLY,12PK,380'
SELECT * FROM USCTTDEV.dbo.tblShipmentItems WHERE BUSegment IS NULL ORDER BY ID DESC

SELECT ShipmentItem, COUNT(*) AS Count FROM USCTTDEV.dbo.tblShipmentItems GROUP BY ShipmentItem HAVING COUNT(*) > 1
*/
INSERT INTO  USCTTDEV.dbo.tblShipmentItems (AddedOn, ShipmentItem, ItemSummaryCode)
SELECT GETDATE() AS AddedOn, 
itm_desc,
CASE
    WHEN CHARINDEX(',', itm_desc) > 0 THEN
        rtrim(left(itm_desc, CHARINDEX(',', itm_desc) - 1))
    ELSE
        null
END AS Type
FROM OPENQUERY(NAJDAPRD,'SELECT DISTINCT sir.itm_desc FROM NAJDAADM.shipment_item_r sir') data
LEFT JOIN USCTTDEV.dbo.tblShipmentItems si ON si.ShipmentItem = data.itm_desc
WHERE si.ShipmentItem IS NULL
ORDER BY itm_desc ASC

/*
UPDATE Wadding
*/
UPDATE USCTTDEV.dbo.tblShipmentItems
SET BUSegment = 'Wadding'
WHERE ShipmentItem LIKE 'WDD'
AND BUSegment IS NULL

/*
Create Temp table with Shipment Item details
SELECT TOP 10 * FROM ##tblShipmentItemsRaw ORDER BY LD_LEG_ID DESC
*/

DROP TABLE IF EXISTS ##tblShipmentItemsRaw
SELECT DISTINCT data.LD_LEG_ID, 
SUM(data.qty) AS Qty, 
SUM(data.weight) AS Weight,
data.itm_desc,
si.ItemSummaryCode,
si.BUSegment
INTO ##tblShipmentItemsRaw
FROM USCTTDEV.dbo.tblShipmentItems si
INNER JOIN (SELECT * FROM OPENQUERY(NAJDAPRD,'SELECT DISTINCT
    l.ld_leg_id,
    /*s.shpm_num,*/
    sir.itm_desc,
    SUM(sir.qnty) AS qty,
    SUM(sir.nmnl_wgt) AS weight
FROM
    najdaadm.load_leg_r          l
    INNER JOIN najdaadm.load_leg_detail_r   ld ON l.ld_leg_id = ld.ld_leg_id
    INNER JOIN najdaadm.shipment_r          s ON ld.shpm_num = s.shpm_num
    INNER JOIN najdaadm.shipment_item_r     sir ON sir.shpm_id = s.shpm_id
WHERE
    EXTRACT(YEAR FROM
        CASE
            WHEN l.shpd_dtt IS NULL THEN
                l.strd_dtt
            ELSE
                l.shpd_dtt
        END
    ) >= EXTRACT(YEAR FROM SYSDATE) - 3
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
        ''53HC'',
        ''LTL''
    )
    AND l.last_ctry_cd IN (
        ''USA'',
        ''CAN'',
        ''MEX''
    )
    AND l.last_shpg_loc_cd NOT LIKE ''LCL%''
GROUP BY
    l.ld_leg_id,
    /*s.shpm_num,*/
    sir.itm_desc')) data ON data.itm_desc = si.ShipmentItem
	GROUP BY data.LD_LEG_ID,
	data.itm_desc,
	si.ItemSummaryCode,
	si.BUSegment

/*
Add ranking column
SELECT TOP 10 * FROM ##tblShipmentItemsRaw ORDER BY LD_LEG_ID DESC, RANK ASC
SELECT TOP 100 * FROM ##tblShipmentItemsRaw WHERE BUSegment = 'NFG' AND RANK > 10
SELECT * FROM ##tblShipmentItemsRaw WHERE LD_LEG_ID = '513494585' ORDER BY Rank ASC
SELECT DISTINCT ItemSummaryCode FROM ##tblShipmentItemsRaw
SELECT DISTINCT BUSegment FROM ##tblShipmentItemsRaw
*/
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'Rank'	AND TABLE_NAME LIKE '##tblShipmentItemsRaw') ALTER TABLE ##tblShipmentItemsRaw ADD [Rank]	INT NULL			--Line item ranking
UPDATE ##tblShipmentItemsRaw
SET [Rank] = ranking.Rank
FROM ##tblShipmentItemsRaw sir
INNER JOIN (SELECT LD_LEG_ID, Qty, Weight, itm_desc, ItemSummaryCode, BUSegment,
ROW_NUMBER() OVER (PARTITION BY LD_LEG_ID ORDER BY Weight DESC, QTY DESC)  AS Rank
FROM ##tblShipmentItemsRaw ) ranking ON ranking.LD_LEG_ID = sir.LD_LEG_ID
AND ranking.itm_desc = sir.itm_desc
 AND ranking.qty = sir.qty
 AND ranking.weight = sir.weight
 AND COALESCE(ranking.ItemSummaryCode,'MISSING') = COALESCE(sir.ItemSummaryCode,'MISSING')

 /*
 Create aggregate table for shipment items
 SELECT TOP 20 * FROM ##tblShipmentItemsAgg ORDER BY LD_LEG_ID ASC, Weight DESC 
 SELECT TOP 20 * FROM ##tblShipmentItemsAgg WHERE BUSegment = 'NFG' ORDER BY LD_LEG_ID ASC, Weight DESC  

 SELECT TOP 20 * FROM USCTTDEV.dbo.tblActualLoadDetail ORDER BY LD_LEG_ID DESC
 */
 DROP TABLE IF EXISTS ##tblShipmentItemsAgg
 SELECT LD_LEG_ID, SUM(QTY) AS QTY, SUM(Weight) AS Weight, BUSegment
 INTO ##tblShipmentItemsAgg
 FROM ##tblShipmentItemsRaw sir 
 GROUP BY LD_LEG_ID, BUSegment

/*
Add ranking, and rank aggregates
*/
 IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'Rank'	AND TABLE_NAME LIKE '##tblShipmentItemsAgg') ALTER TABLE ##tblShipmentItemsAgg ADD [Rank]	INT NULL			--Line item ranking
 UPDATE ##tblShipmentItemsAgg
SET [Rank] = ranking.Rank
FROM ##tblShipmentItemsAgg sir
INNER JOIN (SELECT LD_LEG_ID, Qty, Weight, BUSegment,
ROW_NUMBER() OVER (PARTITION BY LD_LEG_ID ORDER BY Weight DESC, QTY DESC)  AS Rank
FROM ##tblShipmentItemsAgg ) ranking ON ranking.LD_LEG_ID = sir.LD_LEG_ID
 AND ranking.qty = sir.qty
 AND ranking.weight = sir.weight
 AND COALESCE(ranking.BUSegment,'MISSING') = COALESCE(sir.BUSegment,'MISSING')

/*
Update Actual Load Detail for Wadding loads
*/
UPDATE USCTTDEV.dbo.tblActualLoadDetail
SET BUSegment =  wad.BUSegment
FROM USCTTDEV.dbo.tblActualLoadDetail ald
INNER JOIN (SELECT DISTINCT LD_LEG_ID, BUSegment FROM ##tblShipmentItemsRaw WHERE BUSegment = 'Wadding') wad ON wad.LD_LEG_ID = ald.LD_LEG_ID
WHERE ald.BUSegment IS NULL OR ald.BUSegment <> 'Wadding'

/*
Update NFG from aggregate table, where Rank = 1
*/
 UPDATE USCTTDEV.dbo.tblActualLoadDetail
SET BUSegment =  nfg.BUSegment
FROM USCTTDEV.dbo.tblActualLoadDetail ald
INNER JOIN (SELECT DISTINCT LD_LEG_ID, BUSegment FROM ##tblShipmentItemsRaw WHERE BUSegment = 'NFG' AND Rank = 1) nfg ON nfg.LD_LEG_ID = ald.LD_LEG_ID
WHERE ald.BUSegment IS NULL AND ald.BUSegment <> 'NFG'

/*
Update to KCP where BU Is already KCP
*/
UPDATE USCTTDEV.dbo.tblActualLoadDetail
SET BUSegment = BU
WHERE (BUSegment IS NULL AND BUSegment <> 'Wadding' AND BUSegment <> 'NFG') 
AND BUSegment <> BU
AND BU = 'KCP'

/*
Update to NonWovens WHERE BU Is already NonWovens
*/
UPDATE USCTTDEV.dbo.tblActualLoadDetail
SET BUSegment = BU
WHERE (BUSegment IS NULL AND BUSegment <> 'Wadding' AND BUSegment <> 'NFG' ) 
AND BUSegment <> BU
AND BU = 'NON WOVENS'

/*
Update leftovers to whatever is Rank 1 on the aggregate table
SELECT * FROM USCTTDEV.dbo.tblActualLoadDetail WHERE BUSegment IS NULL
 
*/
 UPDATE USCTTDEV.dbo.tblActualLoadDetail
SET BUSegment =  rankings.BUSegment
FROM USCTTDEV.dbo.tblActualLoadDetail ald
INNER JOIN (SELECT DISTINCT LD_LEG_ID, BUSegment FROM ##tblShipmentItemsRaw WHERE Rank = 1) rankings ON rankings.LD_LEG_ID = ald.LD_LEG_ID
WHERE ald.BUSegment IS NULL