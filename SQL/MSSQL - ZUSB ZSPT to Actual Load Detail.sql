SELECT usb.* FROM USCTTDEV.dbo.tblUSBServiceChargeCodes usb
INNER JOIN (
SELECT DISTINCT Description, COUNT(*) AS COUNT
FROM USCTTDEV.dbo.tblUSBServiceChargeCodes
GROUP BY Description
HAVING COUNT(*) > 1
) dupes ON dupes.Description = usb.Description
ORDER BY usb.Description ASC

SELECT TOP 100 *
FROM USCTTDEV.dbo.tblUSBankCharges usb
LEFT JOIN (
SELECT DISTINCT usbcc.Code,
usbcc.Description,
usbcc.Type
FROM USCTTDEV.dbo.tblUSBServiceChargeCodes usbcc
WHERE usbcc.Type IS NOT NULL
) usbcc ON usbcc.Description = usb.ChargeDescription
AND usbcc.Code = CASE WHEN usb.LineItemType = 'Freight' THEN '400' ELSE usb.ServiceChargeCd END
WHERE usb.SyncadaRefNum = '1519490004'

SELECT * FROM USCTTDEV.dbo.tblActualLoadDetail
WHERE LD_LEG_ID = '520522705'


SELECT DISTINCT usb.PONum, 
usb.SellerIDCode,
usb.ShipFromCity,
usb.ShipFromState,
usb.ShipToCity,
usb.ShipToState
FROM USCTTDEV.dbo.tblUSBankCharges usb
LEFT JOIN (
SELECT DISTINCT usbcc.Code,
usbcc.Description,
usbcc.Type
FROM USCTTDEV.dbo.tblUSBServiceChargeCodes usbcc
WHERE usbcc.Type IS NOT NULL
) usbcc ON usbcc.Description = usb.ChargeDescription
AND usbcc.Code = CASE WHEN usb.LineItemType = 'Freight' THEN '400' ELSE usb.ServiceChargeCd END
WHERE usb.SyncadaRefNum = '1519490186'