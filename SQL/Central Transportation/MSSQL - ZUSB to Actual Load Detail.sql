SELECT TOP 50 * FROM USCTTDEV.dbo.tblUSBankCharges

SELECT * FROM USCTTDEV.dbo.tblUSBankCharges
WHERE PONum = '517632336'

SELECT ald.Act_Accessorials,
ald.Act_Fuel,
ald.Act_Linehaul,
ald.Act_ZUSB
FROM USCTTDEV.dbo.tblActualLoadDetail ald
WHERE ald.LD_LEG_ID = '517602851'

SELECT usb.PONum,
usb.SyncadaRefNum,
usb.ItemHeader,
usb.LineID,
usb.LineNum,
usb.ShipFromCountry,
usb.ShipFromCity,
usb.ShipFromState,
usb.ShipToCountry,
usb.ShipToCity,
usb.ShipToState,
CASE WHEN usb.LineItemType = 'Freight' THEN usb.AmountInvoice ELSE usb.AmountPO END AS Charge,
usb.ChargeDescription,
CASE WHEN usbcc.Type IS NULL THEN 'UNKNOWN' ELSE usbcc.Type END AS Type,
COALESCE(ald.Act_Accessorials,0) + COALESCE(ald.Act_Fuel,0) + COALESCE(ald.Act_Linehaul,0) + COALESCE(ald.Act_ZUSB,0) AS TotalALDCharges
FROM USCTTDEV.dbo.tblUSBankCharges usb
INNER JOIN USCTTDEV.dbo.tblActualLoadDetail ald ON ald.LD_LEG_ID = usb.PONum
	AND ald.ActualRateCharge = 'Yes'
	AND ald.Act_ZUSB IS NOT NULL
LEFT JOIN USCTTDEV.dbo.tblUSBServiceChargeCodes usbcc ON usbcc.Code = CASE WHEN usb.ChargeDescription = 'Freight' THEN '400' ELSE usb.ServiceChargeCd END
WHERE ISNUMERIC(usb.PONum) = 1
AND LEFT(usb.PONum,1) = '5'
AND LEN(usb.PONum) = 9
AND CASE WHEN usb.LineItemType = 'Freight' THEN usb.AmountInvoice ELSE usb.AmountPO END IS NOT NULL
--AND PONum = '517602851'
ORDER BY usb.PONum ASC, usb.SyncadaRefNum ASC, usb.ItemHeader ASC, usb.LineID ASC, usb.LineNum ASC

SELECT DISTINCT usb.PONUM,
SUM(usb.Charge) AS TotalUSBCharges,
CAST(AVG(usb.TotalAldCharges) AS NUMERIC(10,2)) AS TotalALDCharges,
CASE WHEN SUM(usb.Charge) = AVG(usb.TotalAldCharges) THEN 'Matches' ELSE 'Does Not Match' END AS Match
FROM (
SELECT usb.PONum,
usb.SyncadaRefNum,
usb.ItemHeader,
usb.LineID,
usb.LineNum,
usb.ShipFromCountry,
usb.ShipFromCity,
usb.ShipFromState,
usb.ShipToCountry,
usb.ShipToCity,
usb.ShipToState,
CASE WHEN usb.LineItemType = 'Freight' THEN usb.AmountInvoice ELSE usb.AmountPO END AS Charge,
usb.ChargeDescription,
CASE WHEN usbcc.Type IS NULL THEN 'UNKNOWN' ELSE usbcc.Type END AS Type,
COALESCE(ald.Act_Accessorials,0) + COALESCE(ald.Act_Fuel,0) + COALESCE(ald.Act_Linehaul,0) + COALESCE(ald.Act_ZUSB,0) AS TotalALDCharges
FROM USCTTDEV.dbo.tblUSBankCharges usb
INNER JOIN USCTTDEV.dbo.tblActualLoadDetail ald ON ald.LD_LEG_ID = usb.PONum
	AND ald.ActualRateCharge = 'Yes'
	AND ald.Act_ZUSB IS NOT NULL
LEFT JOIN USCTTDEV.dbo.tblUSBServiceChargeCodes usbcc ON usbcc.Code = CASE WHEN usb.ChargeDescription = 'Freight' THEN '400' ELSE usb.ServiceChargeCd END
WHERE ISNUMERIC(usb.PONum) = 1
AND LEFT(usb.PONum,1) = '5'
AND LEN(usb.PONum) = 9
AND CASE WHEN usb.LineItemType = 'Freight' THEN usb.AmountInvoice ELSE usb.AmountPO END IS NOT NULL
--AND PONum = '517422894'
) usb
GROUP BY usb.PONum

/*
Drop tables, just in case they exist
*/
DROP TABLE IF EXISTS ##tblUSBankChargeDetail,
##tblUSBankChargePivot,
##tblUSBankChargeAgg

/*
Create temp table of charge etails, for each line number
SELECT TOP 10 * FROM ##tblUSBankChargeDetail WHERE PONum = '517587437'
SELECT * FROM USCTTDEV.dbo.tblUsbankCharges WHERE PONum = '517587437' 
*/
SELECT * INTO ##tblUSBankChargeDetail
FROM (SELECT usb.PONum,
usb.SyncadaRefNum,
usb.ItemHeader,
usb.LineID,
usb.LineNum,
usb.ShipFromCountry,
usb.ShipFromCity,
usb.ShipFromState,
usb.ShipToCountry,
usb.ShipToCity,
usb.ShipToState,
CASE WHEN usb.LineItemType = 'Freight' THEN usb.AmountInvoice ELSE usb.AmountPO END AS Charge,
usb.ChargeDescription,
CASE WHEN usbcc.Type IS NULL THEN 'UNKNOWN' ELSE usbcc.Type END AS Type,
COALESCE(ald.Act_Accessorials,0) + COALESCE(ald.Act_Fuel,0) + COALESCE(ald.Act_Linehaul,0) + COALESCE(ald.Act_ZUSB,0) AS TotalALDCharges,
ald.Act_Accessorials,
ald.Act_Fuel,
ald.Act_Linehaul,
ald.Act_ZUSB
FROM USCTTDEV.dbo.tblUSBankCharges usb
INNER JOIN USCTTDEV.dbo.tblActualLoadDetail ald ON ald.LD_LEG_ID = usb.PONum
	AND ald.ActualRateCharge = 'Yes'
	AND ald.Act_ZUSB IS NOT NULL
LEFT JOIN USCTTDEV.dbo.tblUSBServiceChargeCodes usbcc ON usbcc.Code = CASE WHEN usb.ChargeDescription = 'Freight' THEN '400' ELSE usb.ServiceChargeCd END
WHERE ISNUMERIC(usb.PONum) = 1
AND LEFT(usb.PONum,1) = '5'
AND LEN(usb.PONum) = 9
AND CASE WHEN usb.LineItemType = 'Freight' THEN usb.AmountInvoice ELSE usb.AmountPO END IS NOT NULL
--AND PONum = '517602851'
)usb
ORDER BY usb.PONum ASC, usb.SyncadaRefNum ASC, usb.ItemHeader ASC, usb.LineID ASC, usb.LineNum ASC

/*
Declare Variables

SELECT TOP 10 * FROM ##tblUSBankChargePivot
SELECT DISTINCT LD_LEG_ID, COUNT(*) AS COUNT FROM ##tblUSBankChargePivot GROUP BY LD_LEG_ID HAVING COUNT(*) > 1
DROP TABLE IF EXISTS ##tblUSBankChargePivot

SELECT * FROM ##tblUSBankChargePivot WHERE [International Fee] IS NOT NULL
*/
DECLARE @cols AS NVARCHAR(MAX),
@query AS NVARCHAR(MAX)

SET @cols = STUFF((
			SELECT DISTINCT ',' + QUOTENAME(c.Type)
			FROM ##tblUSBankChargeDetail c
			FOR XML PATH(''),
				TYPE
			).value('.', 'NVARCHAR(MAX)'), 1, 1, '')

SET @query = 'SELECT PONum as LD_LEG_ID,  Act_Accessorials, Act_Fuel, Act_Linehaul, Act_ZUSB, TotalALDCharges, ' + @cols + ' from 
            (
                select udbcd.PONum
                    , udbcd.Charge
                    , udbcd.Type
					, udbcd.TotalALDCharges
					,udbcd.Act_Accessorials
					,udbcd.Act_Fuel
					,udbcd.Act_Linehaul
					,udbcd.Act_ZUSB
                from ##tblUSBankChargeDetail	udbcd	
           ) x
            pivot 
            (
                 SUM(Charge)
                for Type in (' + @cols + ')
            ) p '
SET @query = 'select * into ##tblUSBankChargePivot from (' + @query + ') y'

EXECUTE (@query)

/*
Ensure that all columns exist on the table
*/
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'ACCESSORIAL'						AND TABLE_NAME LIKE '##tblUSBankChargePivot') ALTER TABLE ##tblUSBankChargePivot ADD [ACCESSORIAL]					NUMERIC(10,2) NULL	
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'CUSTOMS/BROKERAGE'	AND TABLE_NAME LIKE '##tblUSBankChargePivot') ALTER TABLE ##tblUSBankChargePivot ADD [CUSTOMS/BROKERAGE]	NUMERIC(10,2) NULL	
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'FUEL'									AND TABLE_NAME LIKE '##tblUSBankChargePivot') ALTER TABLE ##tblUSBankChargePivot ADD [FUEL]									NUMERIC(10,2) NULL		
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'INTERNATIONAL FEE'		AND TABLE_NAME LIKE '##tblUSBankChargePivot') ALTER TABLE ##tblUSBankChargePivot ADD [INTERNATIONAL FEE]		NUMERIC(10,2) NULL	
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'LINEHAUL'							AND TABLE_NAME LIKE '##tblUSBankChargePivot') ALTER TABLE ##tblUSBankChargePivot ADD [LINEHAUL]							NUMERIC(10,2) NULL			
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'TAX'										AND TABLE_NAME LIKE '##tblUSBankChargePivot') ALTER TABLE ##tblUSBankChargePivot ADD [TAX]										NUMERIC(10,2) NULL	
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'UNKNOWN'							AND TABLE_NAME LIKE '##tblUSBankChargePivot') ALTER TABLE ##tblUSBankChargePivot ADD [UNKNOWN]						NUMERIC(10,2) NULL	
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'TotalUSBCharges'				AND TABLE_NAME LIKE '##tblUSBankChargePivot') ALTER TABLE ##tblUSBankChargePivot ADD [TotalUSBCharges]				NUMERIC(10,2) NULL		
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'USBMatchesALD'				AND TABLE_NAME LIKE '##tblUSBankChargePivot') ALTER TABLE ##tblUSBankChargePivot ADD [USBMatchesALD]				NVARCHAR(3) NULL

/*
Check to see if USB matches ALD

SELECT TOP 10 * FROM ##tblUSBankChargePivot WHERE LD_LEG_ID = '517633055'
SELECT DISTINCT LD_LEG_ID, COUNT(*) AS COUNT FROM ##tblUSBankChargePivot GROUP BY LD_LEG_ID HAVING COUNT(*) > 1
*/
UPDATE ##tblUSBankChargePivot
SET USBMatchesAld = CASE WHEN TotalALDCharges = 
COALESCE(Accessorial, 0) 
+ COALESCE([CUSTOMS/BROKERAGE],0) 
+ COALESCE(Fuel, 0) 
+ COALESCE([International Fee],0) 
+ COALESCE([Linehaul],0) 
+ COALESCE(Tax,0) 
+ COALESCE(UNKNOWN,0) THEN 'Yes'
ELSE 'No' END,
[TotalUSBCharges] = COALESCE(Accessorial, 0) 
+ COALESCE([CUSTOMS/BROKERAGE],0) 
+ COALESCE(Fuel, 0) 
+ COALESCE([International Fee],0) 
+ COALESCE([Linehaul],0) 
+ COALESCE(Tax,0) 
+ COALESCE(UNKNOWN,0) 
FROM ##tblUSBankChargePivot

/*
Add more missing columns
*/
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'Act_AccessorialFinal'		AND TABLE_NAME LIKE '##tblUSBankChargePivot') ALTER TABLE ##tblUSBankChargePivot ADD [Act_AccessorialFinal]		NUMERIC(10,2) NULL	
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'Act_FuelFinal'						AND TABLE_NAME LIKE '##tblUSBankChargePivot') ALTER TABLE ##tblUSBankChargePivot ADD [Act_FuelFinal]				  	NUMERIC(10,2) NULL	
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'Act_LinehaulFinal'				AND TABLE_NAME LIKE '##tblUSBankChargePivot') ALTER TABLE ##tblUSBankChargePivot ADD [Act_LinehaulFinal]			NUMERIC(10,2) NULL		
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'Act_ZUSBFinal'					AND TABLE_NAME LIKE '##tblUSBankChargePivot') ALTER TABLE ##tblUSBankChargePivot ADD [Act_ZUSBFinal]					NUMERIC(10,2) NULL	

/*
If totals match, update the Final
SELECT TOP 10 * FROM ##tblUSBankChargePivot WHERE LD_LEG_ID = '517633055'
SELECT * FROM ##tblUSBankChargePivot
SELECT * FROM USCTTDEV.dbo.tblUSBankCharges WHERE PONum = '517675479'
*/
UPDATE ##tblUSBankChargePivot

SET Act_AccessorialFinal = CASE WHEN 
COALESCE(ACCESSORIAL, 0)
+ COALESCE([CUSTOMS/BROKERAGE],0)
+ COALESCE([INTERNATIONAL FEE],0)
+ COALESCE([TAX],0) = 0 THEN Act_Accessorials
ELSE COALESCE(ACCESSORIAL, 0)
+ COALESCE([CUSTOMS/BROKERAGE],0)
+ COALESCE([INTERNATIONAL FEE],0)
+ COALESCE([TAX],0) END ,

Act_FuelFinal = CASE WHEN FUEL IS NULL THEN Act_Fuel ELSE COALESCE(Fuel,0) END,

Act_LinehaulFinal = CASE WHEN Accessorial IS NULL
AND [CUSTOMS/BROKERAGE] IS NULL 
AND [Fuel] IS NULL
AND [INTERNATIONAL FEE] IS NULL
AND [LINEHAUL] IS NOT NULL
AND [TAX] IS NULL THEN 
COALESCE(Act_Linehaul,0) + COALESCE(Act_ZUSB,0)
ELSE CASE WHEN LINEHAUL IS NULL THEN Act_Linehaul ELSE Linehaul END END

WHERE USBMatchesALD = 'Yes'
AND Linehaul IS NOT NULL

UPDATE ##tblUSBankChargePivot
SET Act_ZUSBFinal = TotalALDCharges - (
COALESCE(Act_AccessorialFinal,0)
+ COALESCE(Act_FuelFinal,0)
+ COALESCE(Act_LinehaulFinal,0)
)
WHERE Act_LinehaulFinal IS NOT NULL

/*
If totals don't match, update the Final
SELECT TOP 10 * FROM ##tblUSBankChargePivot WHERE LD_LEG_ID = '517587437'
SELECT * FROM ##tblUSBankChargePivot
SELECT * FROM USCTTDEV.dbo.tblUSBankCharges WHERE PONum = '517587437'


SELECT TOP 10 * FROM ##tblUSBankChargePivot WHERE LD_LEG_ID = '517675479'
*/
UPDATE ##tblUSBankChargePivot
SET Act_AccessorialFinal = Act_Accessorials,
Act_FuelFinal = Act_Fuel,
Act_LinehaulFinal = Act_Linehaul,
Act_ZUSBFinal = Act_ZUSB
WHERE USBMatchesALD = 'No'
OR Linehaul IS NULL

/*
Update Act_Final fields to null if 0
*/
UPDATE ##tblUSBankChargePivot
SET Act_AccessorialFinal = CASE WHEN Act_AccessorialFinal = 0 THEN NULL ELSE Act_AccessorialFinal END,
Act_FuelFinal = CASE WHEN Act_FuelFinal = 0 THEN NULL ELSE Act_FuelFinal END,
Act_LinehaulFinal = CASE WHEN Act_LinehaulFinal = 0 THEN NULL ELSE Act_LinehaulFinal END,
Act_ZUSBFinal = CASE WHEN Act_ZUSBFinal = 0 THEN NULL ELSE Act_ZUSBFinal END

/*
If Final matches Accessorial, updated both to null
*/
UPDATE ##tblUSBankChargePivot
SET Act_AccessorialFinal = NULL,
Act_ZUSBFinal = NULL
WHERE Act_AccessorialFinal + Act_ZUSBFinal = 0
AND Act_ZUSBFinal IS NOT NULL
AND Act_AccessorialFInal IS NOT NULL

/*
Add Final Missing Columns
*/
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'FinalCharges'						AND TABLE_NAME LIKE '##tblUSBankChargePivot') ALTER TABLE ##tblUSBankChargePivot ADD [FinalCharges]						NUMERIC(10,2) NULL	
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'Matches'								AND TABLE_NAME LIKE '##tblUSBankChargePivot') ALTER TABLE ##tblUSBankChargePivot ADD [Matches]				  				NVARCHAR(3) NULL	

/*
Set FinalCharges to sum of Final fields
*/
UPDATE ##tblUSBankChargePivot
SET [FinalCharges] = 
COALESCE(Act_AccessorialFinal,0)
+ COALESCE(Act_FuelFInal,0)
+ COALESCE(Act_LinehaulFinal,0)
+COALESCE(Act_ZUSBFInal,0)

/*
Set Final Match Flag
*/
UPDATE ##tblUSBankChargePivot
SET Matches = CASE WHEN FinalCharges = TotalALDCharges THEN 'Yes' ELSE 'No' END

/*
Oracle queries


SELECT l.LD_LEG_ID,
l.EQMT_TYP,
f.CUR_STAT_ID,
f.FRHT_INVC_ID,
v.VCHR_NUM,
c.CHRG_CD,
c.CHRG_AMT_DLR,
c.PYMNT_AMT_DLR
FROM NAJDAADM.LOAD_LEG_R l
INNER JOIN NAJDAADM.VOUCHER_AP_R v ON v.LD_LEG_ID = l.LD_LEG_ID
INNER JOIN NAJDAADM.FREIGHT_BILL_R f ON f.FRHT_INVC_ID = v.FRHT_INVC_ID
AND f.FRHT_INVC_ID = v.FRHT_INVC_ID
INNER JOIN NAJDAADM.CHARGE_DETAIL_R c ON c.VCHR_NUM_AP = v.VCHR_NUM
WHERE l.LD_LEG_ID = '517632336'
AND c.CHRG_CD IS NOT NULL

SELECT *
FROM NAJDAADM.LOAD_LEG_R l
INNER JOIN NAJDAADM.VOUCHER_AP_R v ON v.LD_LEG_ID = l.LD_LEG_ID
INNER JOIN NAJDAADM.FREIGHT_BILL_R f ON f.FRHT_INVC_ID = v.FRHT_INVC_ID
AND f.FRHT_INVC_ID = v.FRHT_INVC_ID
INNER JOIN NAJDAADM.CHARGE_DETAIL_R c ON c.VCHR_NUM_AP = v.VCHR_NUM
WHERE l.LD_LEG_ID = '517580499'

SELECT * FROM NAJDAADM.STATUS_R
SELECT * FROM NAJDAADM.CHARGE_DETAIL_R c
WHERE c.VCHR_NUM = '000006103215'
SELECT * FROM NAJDAADM.FREIGHT_BILL_R
WHERE FRHT_INVC_ID = 
*/