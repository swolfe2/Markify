SELECT TOP 10 * FROM USCTTDEV.dbo.tblShipmentItems

/*
Excel formula
="SELECT '" & B2 & "' AS ShipmentItem, '" & C2 & "' AS BUSegment UNION ALL"
*/

UPDATE USCTTDEV.dbo.tblShipmentItems
SET BUSegment = updates.BUSegment,
LastUpdated = GETDATE(),
LastUpdatedBy = REPLACE(CURRENT_USER,'KCUS\','')
FROM USCTTDEV.dbo.tblShipmentItems si
INNER JOIN (
SELECT 'BAG,104955501,500000054252,LSS2 ECON+ BA' AS ShipmentItem, 'NFG' AS BUSegment UNION ALL
SELECT 'BAG,105186700,500000051232,DPND GFM 84' AS ShipmentItem, 'NFG' AS BUSegment
) updates ON updates.ShipmentItem = si.ShipmentItem


SELECT TOP 10 * FROM USCTTDEV.dbo.tblUSBServiceChargeCodes

UPDATE USCTTDEV.dbo.tblUSBServiceChargeCodes
SET Type = upd.Type
FROM USCTTDEV.dbo.tblUSBServiceChargeCodes usb
INNER JOIN (
SELECT 'Currency Adjustment Factor' AS Description, 'LINEHAUL' AS Type UNION ALL
SELECT 'Large Package Surcharge' AS Description, 'ACCESSORIAL' AS Type UNION ALL
SELECT 'Pick/Up Allowance' AS Description, 'LINEHAUL' AS Type
) upd ON upd.Description = usb.Description