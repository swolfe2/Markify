USE [USCTTDEV]
GO
/****** Object:  StoredProcedure [dbo].[sp_USBank]    Script Date: 6/10/2021 9:08:18 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Steve Wolfe, steve.wolfe@kcc.com, Central Transportation Team
-- Create date: 3/10/2020
-- Last modified: 2/13/2021
-- 2/13/2021 - SW - Complete overhaul to try to handle dupes
-- 2/10/2021 - Noticed duplciation of ProNum, where it is sometimes null. Updated logic to only append/update if/when
-- Description:	Updates USBank charges, coming from the Python file in \\USTCA097\Stage\Database Files\USBank
-- =============================================

ALTER PROCEDURE [dbo].[sp_USBank]

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

/*
What is this file doing?

1) Adds new bank charges, by PO / Line Item, to USCTTDEV.dbo.tblUSBankCharges
2) Updates USCTTDEV.dbo.tblUSBankCharges, by PO / Line Item
*/

/*
Just in case there are duplicate lineID's coming from USBank
Example: SELECT * FROM ##tblUSBChargesTemp
WHERE PONum IN ('E1M0380212','IADA856464') AND LineID = 1
File: KC_Historical693098_2352661.txt

UPDATE ##tblUSBChargesTemp SET LineNum = 1 WHERE PoNum = 'E1M0380212' AND LineNum = 2
*/
UPDATE ##tblUSBChargesTemp
SET LineNum = dupes.NewLineNum
FROM ##tblUSBChargesTemp usbct
INNER JOIN (
SELECT usbct.PONUM, 
usbct.ProNum, 
usbct.SyncadaRefNum, 
usbct.ItemHeader, 
usbct.LineID,
usbct.LineItemType,
usbct.ExpectedAmt,
usbct.LineItemDlr,
usbct.BookedBilledAmt,
usbct.UnitPriceInvoice,
usbct.AmountInvoice,
ROW_NUMBER() OVER (PARTITION BY usbct.PONUM, usbct.ProNum, usbct.SyncadaRefNum, usbct.ItemHeader, usbct.LineID ORDER BY CAST(usbct.AmountInvoice AS NUMERIC(10,2)) DESC) AS NewLineNum
FROM ##tblUSBChargesTemp usbct
INNER JOIN (
SELECT DISTINCT 
PONum,
PRONum,
SyncadaRefNum,
ItemHeader,
LineID,
LineNum,
LineItemType,
ServiceChargeCd,
COUNT(*) AS DistinctCount
FROM ##tblUSBChargesTemp
WHERE PONum IS NOT NULL
/*AND PONum = '16533227'*/
GROUP BY 
PONum,
PRONum,
SyncadaRefNum,
ItemHeader,
LineID,
LineNum,
LineItemType,
ServiceChargeCd
HAVING COUNT(*) <> 1
) dupes ON dupes.PONum = usbct.PONum
AND dupes.ProNum = usbct.ProNum
AND dupes.SyncadaRefNum = usbct.SyncadaRefNum
AND dupes.ItemHeader = usbct.ItemHeader
AND dupes.LineID = usbct.LineID
AND dupes.LineNum = usbct.LineNum
) dupes ON dupes.PONum = usbct.PONum
AND dupes.ProNum = usbct.ProNum
AND dupes.SyncadaRefNum = usbct.SyncadaRefNum
AND dupes.ItemHeader = usbct.ItemHeader
AND dupes.LineID = usbct.LineID
AND dupes.LineItemType = usbct.LineItemType
AND dupes.ExpectedAmt = usbct.ExpectedAmt
AND dupes.LineItemDlr = usbct.LineItemDlr
AND dupes.BookedBilledAmt = usbct.BookedBilledAmt
AND dupes.UnitPriceInvoice = usbct.UnitPriceInvoice
AND dupes.AmountInvoice = usbct.AmountInvoice

/*
Just in case there are duplicate lineID's coming from USBank
Example: SELECT * FROM ##tblUSBChargesTemp
WHERE PONum IN ('9002637860')
AND LineID = 2
File: 2021-02-13_10-19-05.116-USA_.KCNAUSD_Paid_USD_2502693_20210213.txt

UPDATE ##tblUSBChargesTemp SET LineNum = 1 WHERE PoNum = 'E1M0380212' AND LineNum = 2
*/
UPDATE ##tblUSBChargesTemp
SET LineNum = dupes.NewLineNum
FROM ##tblUSBChargesTemp usbct
INNER JOIN (
SELECT usbct.PONUM, 
usbct.ProNum, 
usbct.SyncadaRefNum, 
usbct.ItemHeader, 
usbct.LineID,
usbct.LineItemType,
usbct.ExpectedAmt,
usbct.LineItemDlr,
usbct.BookedBilledAmt,
usbct.UnitPriceInvoice,
usbct.AmountInvoice,
ROW_NUMBER() OVER (PARTITION BY usbct.PONUM, usbct.ProNum, usbct.SyncadaRefNum, usbct.ItemHeader, usbct.LineID ORDER BY CAST(usbct.AmountInvoice AS NUMERIC(10,2)) DESC) AS NewLineNum
FROM ##tblUSBChargesTemp usbct
INNER JOIN (
SELECT DISTINCT 
PONum,
PRONum,
SyncadaRefNum,
ItemHeader,
LineID,
LineNum,
COUNT(*) AS DistinctCount
FROM ##tblUSBChargesTemp
WHERE PONum IS NOT NULL
/*AND PONum = '16533227'*/
GROUP BY 
PONum,
PRONum,
SyncadaRefNum,
ItemHeader,
LineID,
LineNum
HAVING COUNT(*) <> 1
) dupes ON dupes.PONum = usbct.PONum
AND dupes.ProNum = usbct.ProNum
AND dupes.SyncadaRefNum = usbct.SyncadaRefNum
AND dupes.ItemHeader = usbct.ItemHeader
AND dupes.LineID = usbct.LineID
AND dupes.LineNum = usbct.LineNum
) dupes ON dupes.PONum = usbct.PONum
AND dupes.ProNum = usbct.ProNum
AND dupes.SyncadaRefNum = usbct.SyncadaRefNum
AND dupes.ItemHeader = usbct.ItemHeader
AND dupes.LineID = usbct.LineID
AND dupes.LineItemType = usbct.LineItemType
--AND dupes.ExpectedAmt = usbct.ExpectedAmt
AND dupes.LineItemDlr = usbct.LineItemDlr
--AND dupes.BookedBilledAmt = usbct.BookedBilledAmt
--AND dupes.UnitPriceInvoice = usbct.UnitPriceInvoice
AND dupes.AmountInvoice = usbct.AmountInvoice

/*
Update equipment types if something's wrong
*/
UPDATE ##tblUSBChargesTemp
SET EquipmentType = 
CASE 
WHEN LEN(EquipmentType) > 4 THEN LEFT(EquipmentType, 4)
ELSE EquipmentType END

/*
Update equipment types if something's wrong
*/
UPDATE ##tblUSBChargesTemp
SET MoveType = 
CASE WHEN MoveType LIKE '%Straight Truck%' THEN REPLACE(EquipmentType,'Straight Truck','53FT') 
WHEN LEN(MoveType) > 5 THEN LEFT(MoveType, 5)
ELSE MoveType END

/*
Update equipment types if something's wrong
*/
UPDATE ##tblUSBChargesTemp
SET Container1Type = 
CASE 
WHEN LEN(Container1Type) > 4 THEN LEFT(Container1Type, 4)
ELSE Container1Type END

/*
Set now variable to current date/time
SELECT * FROM ##tblUSBChargesTemp WHERE QuantityInvoice LIKE '%.5' ORDER BY PONum, LIneID, LineNum ASC 
SELECT * FROM USCTTDEV.dbo.tblUSBankCharges
*/
DECLARE @now datetime
SET @now = GETDATE()

/*
Add new records to table where they don't already exist
*/
INSERT INTO USCTTDEV.dbo.tblUSBankCharges (
AddedOn
,AddedFromFile
,UpdatedOn
,UpdatedFromFile
,ExchangeDesc
,CycleStartDate
,CycleEndDate
,ExchangePurpose
,CurrencyCode
,[File]
,SyncadaRefNum
,DocumentType
,FinancialStatusDate
,ProcessingModel
,Terms
,InboundOutbound
,ShipmentMode
,PONum
,PODate
,PRONum
,SellerOrderNum
,CarrInvoiceDate
,eBillID
,TransactionCreateDate
,SellerOrgName
,SellerIDCode
,BuyerOrgName
,BuyerID
,EquipmentType
,MoveType
,SpotBid
,ShipFromAddress1
,ShipFromAddress2
,ShipFromCity
,ShipFromState
,ShipFromPostalCd
,ShipFromCountry
,ShipToName
,ShipToAddress1
,ShipToAddress2
,ShipToCity
,ShipToState
,ShipToPostalCd
,ShipToCountry
,VoucherID
,Container1Type
,BillToAccountNum
,USBillToAmount
,ItemHeader
,LineID
,LineNum
,LineItemType
,GLCd
,ExpectedAmt
,LineItemDlr
,CreditDebitFlag
,BookedExpectAmt
,BookedExpectFlag
,BookedBilledAmt
,BookedBilledFlag
,BuyerPOTCN
,ServiceChargeCd
,CommodityCd
,ProductClass
,BilledRatedAsQty
,BilledRatedAsUOM
,ActualWeight
,ActualWeightUOM
,Volume
,VolumeUOM
,LandingQty
,PackingFormCd
,LineItemUnitPrice
,LineItemExtendedPrice
,BilledUnitOfMeasure
,UnitPriceInvoice
,QuantityInvoice
,AmountInvoice
,UnitPricePO
,AmountPO
,TotalShipmentMileage
)
/*
Append where the ProNum IS NOT NULL
*/
SELECT DISTINCT
@now
,usbct.[File]
,@now
,usbct.[File]
,usbct.ExchangeDesc
,usbct.CycleStartDate
,usbct.CycleEndDate
,usbct.ExchangePurpose
,usbct.CurrencyCode
,usbct.[File]
,usbct.SyncadaRefNum
,usbct.DocumentType
,usbct.FinancialStatusDate
,usbct.ProcessingModel
,usbct.Terms
,usbct.InboundOutbound
,usbct.ShipmentMode
,usbct.PONum
,usbct.PODate
,usbct.PRONum
,usbct.SellerOrderNum
,usbct.CarrInvoiceDate
,usbct.eBillID
,usbct.TransactionCreateDate
,usbct.SellerOrgName
,usbct.SellerIDCode
,usbct.BuyerOrgName
,usbct.BuyerID
,usbct.EquipmentType
,usbct.MoveType
,usbct.SpotBid
,usbct.ShipFromAddress1
,usbct.ShipFromAddress2
,usbct.ShipFromCity
,usbct.ShipFromState
,usbct.ShipFromPostalCd
,usbct.ShipFromCountry
,usbct.ShipToName
,usbct.ShipToAddress1
,usbct.ShipToAddress2
,usbct.ShipToCity
,usbct.ShipToState
,usbct.ShipToPostalCd
,usbct.ShipToCountry
,usbct.VoucherID
,usbct.Container1Type
,usbct.BillToAccountNum
,usbct.USBillToAmount
,usbct.ItemHeader
,usbct.LineID
,usbct.LineNum
,usbct.LineItemType
,usbct.GLCd
,usbct.ExpectedAmt
,usbct.LineItemDlr
,usbct.CreditDebitFlag
,usbct.BookedExpectAmt
,usbct.BookedExpectFlag
,usbct.BookedBilledAmt
,usbct.BookedBilledFlag
,usbct.BuyerPOTCN
,usbct.ServiceChargeCd
,usbct.CommodityCd
,usbct.ProductClass
,usbct.BilledRatedAsQty
,usbct.BilledRatedAsUOM
,usbct.ActualWeight
,usbct.ActualWeightUOM
,usbct.Volume
,usbct.VolumeUOM
,CAST(usbct.LandingQty AS NUMERIC(18,2))
,usbct.PackingFormCd
,usbct.LineItemUnitPrice
,usbct.LineItemExtendedPrice
,usbct.BilledUnitOfMeasure
,usbct.UnitPriceInvoice
,CAST(usbct.QuantityInvoice AS NUMERIC(18,2))
,usbct.AmountInvoice
,usbct.UnitPricePO
,usbct.AmountPO
,usbct.TotalShipmentMileage

FROM ##tblUSBChargesTemp usbct
LEFT JOIN USCTTDEV.dbo.tblUSBankCharges usbc ON usbc.PONum = usbct.PONum
AND usbc.LineID = usbct.LineID
AND usbc.LineNum = usbct.LineNum
AND usbc.PRONum = usbct.ProNum
AND usbc.SyncadaRefNum = usbct.SyncadaRefNum
WHERE usbc.PONum IS NULL
AND usbc.LineID IS NULL
AND usbc.LineNum IS NULL
AND usbc.ProNum IS NULL
AND usbct.ProNum IS NOT NULL
AND usbc.SyncadaRefNum IS NULL
AND usbct.PONum IS NOT NULL
ORDER BY usbct.[File] ASC, usbct.PONum ASC, usbct.ProNum ASC, usbct.SyncadaRefNum ASC, usbct.LineID ASC, usbct.LineNum ASC

/*
Update USBank table to match details from temp, where ProNum IS NOT NULL
*/
UPDATE USCTTDEV.dbo.tblUSBankCharges
SET UpdatedOn = @now
,UpdatedFromFile = usbct.[file]
,ExchangeDesc = usbct.ExchangeDesc
,CycleStartDate = usbct.CycleStartDate
,CycleEndDate = usbct.CycleEndDate
,ExchangePurpose = usbct.ExchangePurpose
,CurrencyCode = usbct.CurrencyCode
,[File] = usbct.[File]
/*,SyncadaRefNum = usbct.SyncadaRefNum*/
,DocumentType = usbct.DocumentType
,FinancialStatusDate = usbct.FinancialStatusDate
,ProcessingModel = usbct.ProcessingModel
,Terms = usbct.Terms
,InboundOutbound = usbct.InboundOutbound
,ShipmentMode = usbct.ShipmentMode
,PONum = usbct.PONum
,PODate = usbct.PODate
,PRONum = usbct.PRONum
,SellerOrderNum = usbct.SellerOrderNum
,CarrInvoiceDate = usbct.CarrInvoiceDate
,eBillID = usbct.eBillID
,TransactionCreateDate = usbct.TransactionCreateDate
,SellerOrgName = usbct.SellerOrgName
,SellerIDCode = usbct.SellerIDCode
,BuyerOrgName = usbct.BuyerOrgName
,BuyerID = usbct.BuyerID
,EquipmentType = usbct.EquipmentType
,MoveType = usbct.MoveType
,SpotBid = usbct.SpotBid
,ShipFromAddress1 = usbct.ShipFromAddress1
,ShipFromAddress2 = usbct.ShipFromAddress2
,ShipFromCity = usbct.ShipFromCity
,ShipFromState = usbct.ShipFromState
,ShipFromPostalCd = usbct.ShipFromPostalCd
,ShipFromCountry = usbct.ShipFromCountry
,ShipToName = usbct.ShipToName
,ShipToAddress1 = usbct.ShipToAddress1
,ShipToAddress2 = usbct.ShipToAddress2
,ShipToCity = usbct.ShipToCity
,ShipToState = usbct.ShipToState
,ShipToPostalCd = usbct.ShipToPostalCd
,ShipToCountry = usbct.ShipToCountry
,VoucherID = usbct.VoucherID
,Container1Type = usbct.Container1Type
,BillToAccountNum = usbct.BillToAccountNum
,USBillToAmount = usbct.USBillToAmount
/*,ItemHeader = usbct.ItemHeader
,LineID = usbct.LineID
,LineNum = usbct.LineNum
,LineItemType = usbct.LineItemType*/
,GLCd = usbct.GLCd
,ExpectedAmt = usbct.ExpectedAmt
,LineItemDlr = usbct.LineItemDlr
,CreditDebitFlag = usbct.CreditDebitFlag
,BookedExpectAmt = usbct.BookedExpectAmt
,BookedExpectFlag = usbct.BookedExpectFlag
,BookedBilledAmt = usbct.BookedBilledAmt
,BookedBilledFlag  = usbct.BookedBilledFlag
,BuyerPOTCN = usbct.BuyerPOTCN
,ServiceChargeCd = usbct.ServiceChargeCd
,CommodityCd = usbct.CommodityCd
,ProductClass = usbct.ProductClass
,BilledRatedAsQty = usbct.BilledRatedAsQty
,BilledRatedAsUOM = usbct.BilledRatedAsUOM
,ActualWeight = usbct.ActualWeight
,ActualWeightUOM = usbct.ActualWeightUOM
,Volume = usbct.Volume
,VolumeUOM = usbct.VolumeUOM
,LandingQty = CAST(usbct.LandingQty AS NUMERIC(18,2))
,PackingFormCd = usbct.PackingFormCd
,LineItemUnitPrice = usbct.LineItemUnitPrice
,LineItemExtendedPrice = usbct.LineItemExtendedPrice
,BilledUnitOfMeasure = usbct.BilledUnitOfMeasure
,UnitPriceInvoice = usbct.UnitPriceInvoice
,QuantityInvoice = CAST(usbct.QuantityInvoice AS NUMERIC(18,2))
,AmountInvoice = usbct.AmountInvoice
,UnitPricePO = usbct.UnitPricePO
,AmountPO = usbct.AmountPO
,TotalShipmentMileage = usbct.TotalShipmentMileage

FROM ##tblUSBChargesTemp usbct
INNER JOIN USCTTDEV.dbo.tblUSBankCharges usbc ON usbc.PONum = usbct.PONum
AND usbc.LineID = usbct.LineID
AND usbc.LineNum = usbct.LineNum
AND usbc.ProNum = usbct.ProNum
AND usbc.SyncadaRefNum = usbct.SyncadaRefNum
WHERE usbct.ProNum IS NOT NULL
AND usbct.PONum IS NOT NULL

/*
Delete where ProNum IS NOT NULL
*/
DELETE FROM ##tblUSBChargesTemp
WHERE ProNum IS NOT NULL

/*
Append where the ProNum is null
*/
INSERT INTO USCTTDEV.dbo.tblUSBankCharges (
AddedOn
,AddedFromFile
,UpdatedOn
,UpdatedFromFile
,ExchangeDesc
,CycleStartDate
,CycleEndDate
,ExchangePurpose
,CurrencyCode
,[File]
,SyncadaRefNum
,DocumentType
,FinancialStatusDate
,ProcessingModel
,Terms
,InboundOutbound
,ShipmentMode
,PONum
,PODate
,PRONum
,SellerOrderNum
,CarrInvoiceDate
,eBillID
,TransactionCreateDate
,SellerOrgName
,SellerIDCode
,BuyerOrgName
,BuyerID
,EquipmentType
,MoveType
,SpotBid
,ShipFromAddress1
,ShipFromAddress2
,ShipFromCity
,ShipFromState
,ShipFromPostalCd
,ShipFromCountry
,ShipToName
,ShipToAddress1
,ShipToAddress2
,ShipToCity
,ShipToState
,ShipToPostalCd
,ShipToCountry
,VoucherID
,Container1Type
,BillToAccountNum
,USBillToAmount
,ItemHeader
,LineID
,LineNum
,LineItemType
,GLCd
,ExpectedAmt
,LineItemDlr
,CreditDebitFlag
,BookedExpectAmt
,BookedExpectFlag
,BookedBilledAmt
,BookedBilledFlag
,BuyerPOTCN
,ServiceChargeCd
,CommodityCd
,ProductClass
,BilledRatedAsQty
,BilledRatedAsUOM
,ActualWeight
,ActualWeightUOM
,Volume
,VolumeUOM
,LandingQty
,PackingFormCd
,LineItemUnitPrice
,LineItemExtendedPrice
,BilledUnitOfMeasure
,UnitPriceInvoice
,QuantityInvoice
,AmountInvoice
,UnitPricePO
,AmountPO
,TotalShipmentMileage
)

SELECT DISTINCT
@now
,usbct.[File]
,@now
,usbct.[File]
,usbct.ExchangeDesc
,usbct.CycleStartDate
,usbct.CycleEndDate
,usbct.ExchangePurpose
,usbct.CurrencyCode
,usbct.[File]
,usbct.SyncadaRefNum
,usbct.DocumentType
,usbct.FinancialStatusDate
,usbct.ProcessingModel
,usbct.Terms
,usbct.InboundOutbound
,usbct.ShipmentMode
,usbct.PONum
,usbct.PODate
,usbct.PRONum
,usbct.SellerOrderNum
,usbct.CarrInvoiceDate
,usbct.eBillID
,usbct.TransactionCreateDate
,usbct.SellerOrgName
,usbct.SellerIDCode
,usbct.BuyerOrgName
,usbct.BuyerID
,usbct.EquipmentType
,usbct.MoveType
,usbct.SpotBid
,usbct.ShipFromAddress1
,usbct.ShipFromAddress2
,usbct.ShipFromCity
,usbct.ShipFromState
,usbct.ShipFromPostalCd
,usbct.ShipFromCountry
,usbct.ShipToName
,usbct.ShipToAddress1
,usbct.ShipToAddress2
,usbct.ShipToCity
,usbct.ShipToState
,usbct.ShipToPostalCd
,usbct.ShipToCountry
,usbct.VoucherID
,usbct.Container1Type
,usbct.BillToAccountNum
,usbct.USBillToAmount
,usbct.ItemHeader
,usbct.LineID
,usbct.LineNum
,usbct.LineItemType
,usbct.GLCd
,usbct.ExpectedAmt
,usbct.LineItemDlr
,usbct.CreditDebitFlag
,usbct.BookedExpectAmt
,usbct.BookedExpectFlag
,usbct.BookedBilledAmt
,usbct.BookedBilledFlag
,usbct.BuyerPOTCN
,usbct.ServiceChargeCd
,usbct.CommodityCd
,usbct.ProductClass
,usbct.BilledRatedAsQty
,usbct.BilledRatedAsUOM
,usbct.ActualWeight
,usbct.ActualWeightUOM
,usbct.Volume
,usbct.VolumeUOM
,CAST(usbct.LandingQty AS NUMERIC(18,2))
,usbct.PackingFormCd
,usbct.LineItemUnitPrice
,usbct.LineItemExtendedPrice
,usbct.BilledUnitOfMeasure
,usbct.UnitPriceInvoice
,CAST(usbct.QuantityInvoice AS NUMERIC(18,2))
,usbct.AmountInvoice
,usbct.UnitPricePO
,usbct.AmountPO
,usbct.TotalShipmentMileage

FROM ##tblUSBChargesTemp usbct
LEFT JOIN USCTTDEV.dbo.tblUSBankCharges usbc ON usbc.PONum = usbct.PONum
AND usbc.LineID = usbct.LineID
AND usbc.LineNum = usbct.LineNum
AND usbc.SyncadaRefNum = usbct.SyncadaRefNum
/*AND usbc.PRONum = usbct.ProNum*/
WHERE usbc.PONum IS NULL
AND usbc.LineID IS NULL
AND usbc.LineNum IS NULL
AND usbc.SyncadaRefNum IS NULL
/*AND usbc.ProNum IS NULL*/
AND usbct.ProNum IS NULL
AND usbct.PONum IS NOT NULL
ORDER BY usbct.[File] ASC, usbct.PONum ASC, usbct.ProNum ASC, usbct.SyncadaRefNum ASC, usbct.LineID ASC, usbct.LineNum ASC

/*
Update USBank table to match details from temp, where ProNum IS NULL
*/
UPDATE USCTTDEV.dbo.tblUSBankCharges
SET UpdatedOn = @now
,UpdatedFromFile = usbct.[file]
,ExchangeDesc = usbct.ExchangeDesc
,CycleStartDate = usbct.CycleStartDate
,CycleEndDate = usbct.CycleEndDate
,ExchangePurpose = usbct.ExchangePurpose
,CurrencyCode = usbct.CurrencyCode
,[File] = usbct.[File]
/*,SyncadaRefNum = usbct.SyncadaRefNum*/
,DocumentType = usbct.DocumentType
,FinancialStatusDate = usbct.FinancialStatusDate
,ProcessingModel = usbct.ProcessingModel
,Terms = usbct.Terms
,InboundOutbound = usbct.InboundOutbound
,ShipmentMode = usbct.ShipmentMode
,PONum = usbct.PONum
,PODate = usbct.PODate
,PRONum = usbct.PRONum
,SellerOrderNum = usbct.SellerOrderNum
,CarrInvoiceDate = usbct.CarrInvoiceDate
,eBillID = usbct.eBillID
,TransactionCreateDate = usbct.TransactionCreateDate
,SellerOrgName = usbct.SellerOrgName
,SellerIDCode = usbct.SellerIDCode
,BuyerOrgName = usbct.BuyerOrgName
,BuyerID = usbct.BuyerID
,EquipmentType = usbct.EquipmentType
,MoveType = usbct.MoveType
,SpotBid = usbct.SpotBid
,ShipFromAddress1 = usbct.ShipFromAddress1
,ShipFromAddress2 = usbct.ShipFromAddress2
,ShipFromCity = usbct.ShipFromCity
,ShipFromState = usbct.ShipFromState
,ShipFromPostalCd = usbct.ShipFromPostalCd
,ShipFromCountry = usbct.ShipFromCountry
,ShipToName = usbct.ShipToName
,ShipToAddress1 = usbct.ShipToAddress1
,ShipToAddress2 = usbct.ShipToAddress2
,ShipToCity = usbct.ShipToCity
,ShipToState = usbct.ShipToState
,ShipToPostalCd = usbct.ShipToPostalCd
,ShipToCountry = usbct.ShipToCountry
,VoucherID = usbct.VoucherID
,Container1Type = usbct.Container1Type
,BillToAccountNum = usbct.BillToAccountNum
,USBillToAmount = usbct.USBillToAmount
/*,ItemHeader = usbct.ItemHeader
,LineID = usbct.LineID
,LineNum = usbct.LineNum
,LineItemType = usbct.LineItemType*/
,GLCd = usbct.GLCd
,ExpectedAmt = usbct.ExpectedAmt
,LineItemDlr = usbct.LineItemDlr
,CreditDebitFlag = usbct.CreditDebitFlag
,BookedExpectAmt = usbct.BookedExpectAmt
,BookedExpectFlag = usbct.BookedExpectFlag
,BookedBilledAmt = usbct.BookedBilledAmt
,BookedBilledFlag  = usbct.BookedBilledFlag
,BuyerPOTCN = usbct.BuyerPOTCN
,ServiceChargeCd = usbct.ServiceChargeCd
,CommodityCd = usbct.CommodityCd
,ProductClass = usbct.ProductClass
,BilledRatedAsQty = usbct.BilledRatedAsQty
,BilledRatedAsUOM = usbct.BilledRatedAsUOM
,ActualWeight = usbct.ActualWeight
,ActualWeightUOM = usbct.ActualWeightUOM
,Volume = usbct.Volume
,VolumeUOM = usbct.VolumeUOM
,LandingQty = CAST(usbct.LandingQty AS NUMERIC(18,2))
,PackingFormCd = usbct.PackingFormCd
,LineItemUnitPrice = usbct.LineItemUnitPrice
,LineItemExtendedPrice = usbct.LineItemExtendedPrice
,BilledUnitOfMeasure = usbct.BilledUnitOfMeasure
,UnitPriceInvoice = usbct.UnitPriceInvoice
,QuantityInvoice = CAST(usbct.QuantityInvoice AS NUMERIC(18,2))
,AmountInvoice = usbct.AmountInvoice
,UnitPricePO = usbct.UnitPricePO
,AmountPO = usbct.AmountPO
,TotalShipmentMileage = usbct.TotalShipmentMileage

FROM ##tblUSBChargesTemp usbct
INNER JOIN USCTTDEV.dbo.tblUSBankCharges usbc ON usbc.PONum = usbct.PONum
AND usbc.LineID = usbct.LineID
AND usbc.LineNum = usbct.LineNum
AND usbc.SyncadaRefNum = usbct.SyncadaRefNum
/*AND usbc.ProNum = usbct.ProNum*/
WHERE usbct.ProNum IS NULL
AND usbct.PONum IS NOT NULL


/*
Delete where ProNum IS NOT NULL
*/
DELETE FROM ##tblUSBChargesTemp
WHERE PONum IS NOT NULL

/*
Append where the ProNum is null
*/
INSERT INTO USCTTDEV.dbo.tblUSBankCharges (
AddedOn
,AddedFromFile
,UpdatedOn
,UpdatedFromFile
,ExchangeDesc
,CycleStartDate
,CycleEndDate
,ExchangePurpose
,CurrencyCode
,[File]
,SyncadaRefNum
,DocumentType
,FinancialStatusDate
,ProcessingModel
,Terms
,InboundOutbound
,ShipmentMode
,PONum
,PODate
,PRONum
,SellerOrderNum
,CarrInvoiceDate
,eBillID
,TransactionCreateDate
,SellerOrgName
,SellerIDCode
,BuyerOrgName
,BuyerID
,EquipmentType
,MoveType
,SpotBid
,ShipFromAddress1
,ShipFromAddress2
,ShipFromCity
,ShipFromState
,ShipFromPostalCd
,ShipFromCountry
,ShipToName
,ShipToAddress1
,ShipToAddress2
,ShipToCity
,ShipToState
,ShipToPostalCd
,ShipToCountry
,VoucherID
,Container1Type
,BillToAccountNum
,USBillToAmount
,ItemHeader
,LineID
,LineNum
,LineItemType
,GLCd
,ExpectedAmt
,LineItemDlr
,CreditDebitFlag
,BookedExpectAmt
,BookedExpectFlag
,BookedBilledAmt
,BookedBilledFlag
,BuyerPOTCN
,ServiceChargeCd
,CommodityCd
,ProductClass
,BilledRatedAsQty
,BilledRatedAsUOM
,ActualWeight
,ActualWeightUOM
,Volume
,VolumeUOM
,LandingQty
,PackingFormCd
,LineItemUnitPrice
,LineItemExtendedPrice
,BilledUnitOfMeasure
,UnitPriceInvoice
,QuantityInvoice
,AmountInvoice
,UnitPricePO
,AmountPO
,TotalShipmentMileage
)

SELECT DISTINCT
@now
,usbct.[File]
,@now
,usbct.[File]
,usbct.ExchangeDesc
,usbct.CycleStartDate
,usbct.CycleEndDate
,usbct.ExchangePurpose
,usbct.CurrencyCode
,usbct.[File]
,usbct.SyncadaRefNum
,usbct.DocumentType
,usbct.FinancialStatusDate
,usbct.ProcessingModel
,usbct.Terms
,usbct.InboundOutbound
,usbct.ShipmentMode
,usbct.PONum
,usbct.PODate
,usbct.PRONum
,usbct.SellerOrderNum
,usbct.CarrInvoiceDate
,usbct.eBillID
,usbct.TransactionCreateDate
,usbct.SellerOrgName
,usbct.SellerIDCode
,usbct.BuyerOrgName
,usbct.BuyerID
,usbct.EquipmentType
,usbct.MoveType
,usbct.SpotBid
,usbct.ShipFromAddress1
,usbct.ShipFromAddress2
,usbct.ShipFromCity
,usbct.ShipFromState
,usbct.ShipFromPostalCd
,usbct.ShipFromCountry
,usbct.ShipToName
,usbct.ShipToAddress1
,usbct.ShipToAddress2
,usbct.ShipToCity
,usbct.ShipToState
,usbct.ShipToPostalCd
,usbct.ShipToCountry
,usbct.VoucherID
,usbct.Container1Type
,usbct.BillToAccountNum
,usbct.USBillToAmount
,usbct.ItemHeader
,usbct.LineID
,usbct.LineNum
,usbct.LineItemType
,usbct.GLCd
,usbct.ExpectedAmt
,usbct.LineItemDlr
,usbct.CreditDebitFlag
,usbct.BookedExpectAmt
,usbct.BookedExpectFlag
,usbct.BookedBilledAmt
,usbct.BookedBilledFlag
,usbct.BuyerPOTCN
,usbct.ServiceChargeCd
,usbct.CommodityCd
,usbct.ProductClass
,usbct.BilledRatedAsQty
,usbct.BilledRatedAsUOM
,usbct.ActualWeight
,usbct.ActualWeightUOM
,usbct.Volume
,usbct.VolumeUOM
,CAST(usbct.LandingQty AS NUMERIC(18,2))
,usbct.PackingFormCd
,usbct.LineItemUnitPrice
,usbct.LineItemExtendedPrice
,usbct.BilledUnitOfMeasure
,usbct.UnitPriceInvoice
,CAST(usbct.QuantityInvoice AS NUMERIC(18,2))
,usbct.AmountInvoice
,usbct.UnitPricePO
,usbct.AmountPO
,usbct.TotalShipmentMileage

FROM ##tblUSBChargesTemp usbct
LEFT JOIN USCTTDEV.dbo.tblUSBankCharges usbc ON /*usbc.PONum = usbct.PONum
AND*/ usbc.LineID = usbct.LineID
AND usbc.LineNum = usbct.LineNum
AND usbc.SyncadaRefNum = usbct.SyncadaRefNum
/*AND usbc.PRONum = usbct.ProNum*/
WHERE /*usbc.PONum IS NULL
AND */usbc.LineID IS NULL
AND usbc.LineNum IS NULL
AND usbc.SyncadaRefNum IS NULL
/*AND usbc.ProNum IS NULL
AND usbct.ProNum IS NULL
AND usbct.PONum IS NOT NULL*/
ORDER BY usbct.[File] ASC, usbct.PONum ASC, usbct.ProNum ASC, usbct.SyncadaRefNum ASC, usbct.LineID ASC, usbct.LineNum ASC

/*
Update USBank table to match details from temp, where ProNum IS NULL
*/
UPDATE USCTTDEV.dbo.tblUSBankCharges
SET UpdatedOn = @now
,UpdatedFromFile = usbct.[file]
,ExchangeDesc = usbct.ExchangeDesc
,CycleStartDate = usbct.CycleStartDate
,CycleEndDate = usbct.CycleEndDate
,ExchangePurpose = usbct.ExchangePurpose
,CurrencyCode = usbct.CurrencyCode
,[File] = usbct.[File]
/*,SyncadaRefNum = usbct.SyncadaRefNum*/
,DocumentType = usbct.DocumentType
,FinancialStatusDate = usbct.FinancialStatusDate
,ProcessingModel = usbct.ProcessingModel
,Terms = usbct.Terms
,InboundOutbound = usbct.InboundOutbound
,ShipmentMode = usbct.ShipmentMode
,PONum = usbct.PONum
,PODate = usbct.PODate
,PRONum = usbct.PRONum
,SellerOrderNum = usbct.SellerOrderNum
,CarrInvoiceDate = usbct.CarrInvoiceDate
,eBillID = usbct.eBillID
,TransactionCreateDate = usbct.TransactionCreateDate
,SellerOrgName = usbct.SellerOrgName
,SellerIDCode = usbct.SellerIDCode
,BuyerOrgName = usbct.BuyerOrgName
,BuyerID = usbct.BuyerID
,EquipmentType = usbct.EquipmentType
,MoveType = usbct.MoveType
,SpotBid = usbct.SpotBid
,ShipFromAddress1 = usbct.ShipFromAddress1
,ShipFromAddress2 = usbct.ShipFromAddress2
,ShipFromCity = usbct.ShipFromCity
,ShipFromState = usbct.ShipFromState
,ShipFromPostalCd = usbct.ShipFromPostalCd
,ShipFromCountry = usbct.ShipFromCountry
,ShipToName = usbct.ShipToName
,ShipToAddress1 = usbct.ShipToAddress1
,ShipToAddress2 = usbct.ShipToAddress2
,ShipToCity = usbct.ShipToCity
,ShipToState = usbct.ShipToState
,ShipToPostalCd = usbct.ShipToPostalCd
,ShipToCountry = usbct.ShipToCountry
,VoucherID = usbct.VoucherID
,Container1Type = usbct.Container1Type
,BillToAccountNum = usbct.BillToAccountNum
,USBillToAmount = usbct.USBillToAmount
/*,ItemHeader = usbct.ItemHeader
,LineID = usbct.LineID
,LineNum = usbct.LineNum
,LineItemType = usbct.LineItemType*/
,GLCd = usbct.GLCd
,ExpectedAmt = usbct.ExpectedAmt
,LineItemDlr = usbct.LineItemDlr
,CreditDebitFlag = usbct.CreditDebitFlag
,BookedExpectAmt = usbct.BookedExpectAmt
,BookedExpectFlag = usbct.BookedExpectFlag
,BookedBilledAmt = usbct.BookedBilledAmt
,BookedBilledFlag  = usbct.BookedBilledFlag
,BuyerPOTCN = usbct.BuyerPOTCN
,ServiceChargeCd = usbct.ServiceChargeCd
,CommodityCd = usbct.CommodityCd
,ProductClass = usbct.ProductClass
,BilledRatedAsQty = usbct.BilledRatedAsQty
,BilledRatedAsUOM = usbct.BilledRatedAsUOM
,ActualWeight = usbct.ActualWeight
,ActualWeightUOM = usbct.ActualWeightUOM
,Volume = usbct.Volume
,VolumeUOM = usbct.VolumeUOM
,LandingQty = CAST(usbct.LandingQty AS NUMERIC(18,2))
,PackingFormCd = usbct.PackingFormCd
,LineItemUnitPrice = usbct.LineItemUnitPrice
,LineItemExtendedPrice = usbct.LineItemExtendedPrice
,BilledUnitOfMeasure = usbct.BilledUnitOfMeasure
,UnitPriceInvoice = usbct.UnitPriceInvoice
,QuantityInvoice = CAST(usbct.QuantityInvoice AS NUMERIC(18,2))
,AmountInvoice = usbct.AmountInvoice
,UnitPricePO = usbct.UnitPricePO
,AmountPO = usbct.AmountPO
,TotalShipmentMileage = usbct.TotalShipmentMileage

FROM ##tblUSBChargesTemp usbct
INNER JOIN USCTTDEV.dbo.tblUSBankCharges usbc ON /*usbc.PONum = usbct.PONum
AND*/ usbc.LineID = usbct.LineID
AND usbc.LineNum = usbct.LineNum
AND usbc.SyncadaRefNum = usbct.SyncadaRefNum
/*AND usbc.ProNum = usbct.ProNum*/
WHERE usbc.PONum IS NULL
AND usbc.ProNum IS NULL

/*
Delete where ProNum IS NOT NULL
*/
DELETE FROM ##tblUSBChargesTemp
WHERE SyncadaRefNum IS NOT NULL

/*
Get rid of any stupid .0's that exist
*/
UPDATE USCTTDEV.dbo.tblUSBankCharges
SET ServiceChargeCd = REPLACE(ServiceChargeCd,'.0','')
WHERE ServiceChargeCd LIKE '%.0'

/*
Update ChargeDescription from USB Service Charge Codes
*/
UPDATE USCTTDEV.dbo.tblUSBankCharges
SET ChargeDescription = 
CASE WHEN usb.LineItemType = 'Freight' THEN 'Freight'
ELSE usbc.Description END
FROM USCTTDEV.dbo.tblUSBankCharges usb
LEFT JOIN USCTTDEV.dbo.tblUSBServiceChargeCodes usbc ON usbc.Code = usb.ServiceChargeCd
WHERE usb.ChargeDescription IS NULL

/*
SELECT * FROM ##tblUSBChargesTemp
WHERE PONum = '16655260' AND LineID = 2

SELECT * FROM ##tblUSBChargesTemp
WHERE PONum IN ('4300619098','IADA856464') AND LineID = 1

SELECT * FROM USCTTDEV.dbo.tblUSBankCharges
WHERE PONum IN ('16798771') 
AND SyncadaRefNum = '1514216790'
AND LineID = 1

SELECT * FROM ##tblUSBChargesTemp
WHERE PONum IN (
'16798771',
'518577198',
'520628424',
'520928388',
'520543526',
'520548613',
'9002637860'
)
AND SyncadaRefNum = '1444226825'
AND LineID = 1

SELECT * FROM USCTTDEV.dbo.tblUSBankCharges
WHERE PONum IN ('9002637860') 
AND SyncadaRefNum = '1513428126'
AND LineID = 1

SELECT DISTINCT 
PONum,
PRONum,
SyncadaRefNum,
ItemHeader,
LineID,
LineNum,
LineItemType,
--LineItemDlr,
ServiceChargeCd,
Max(ID) AS MInID, 
COUNT(*) AS DistinctCount
FROM USCTTDEV.dbo.tblUSBankCharges
WHERE PONum IS NOT NULL
/*AND PONum = '16533227'*/
GROUP BY 
PONum,
PRONum,
SyncadaRefNum,
ItemHeader,
LineID,
LineNum,
LineItemType,
--LineItemDlr,
ServiceChargeCd
HAVING COUNT(*) <> 1

SELECT DISTINCT 
PONum,
PRONum,
SyncadaRefNum,
ItemHeader,
LineID,
LineNum,
LineItemType,
--LineItemDlr,
ServiceChargeCd,
Max(ID) AS MInID, 
COUNT(*) AS DistinctCount
FROM USCTTDEV.dbo.tblUSBankCharges2
WHERE PONum IS NOT NULL
/*AND PONum = '16533227'*/
GROUP BY 
PONum,
PRONum,
SyncadaRefNum,
ItemHeader,
LineID,
LineNum,
LineItemType,
--LineItemDlr,
ServiceChargeCd
HAVING COUNT(*) <> 1

SELECT DISTINCT 
usbct.PONUM, 
usbct.ProNum, 
usbct.SyncadaRefNum, 
usbct.ItemHeader, 
usbct.LineID,
usbct.LineItemType,
usbct.ExpectedAmt,
usbct.LineItemDlr,
usbct.BookedBilledAmt,
usbct.UnitPriceInvoice,
usbct.AmountInvoice,
ROW_NUMBER() OVER (PARTITION BY usbct.PONUM, usbct.ProNum, usbct.SyncadaRefNum, usbct.ItemHeader, usbct.LineID ORDER BY CAST(usbct.AmountInvoice AS NUMERIC(10,2)) DESC) AS NewLineNum
FROM USCTTDEV.dbo.tblUSBankCharges2 usbct
INNER JOIN (
SELECT DISTINCT 
PONum,
PRONum,
SyncadaRefNum,
ItemHeader,
LineID,
LineNum,
LineItemType,
ServiceChargeCd,
COUNT(*) AS DistinctCount
FROM USCTTDEV.dbo.tblUSBankCharges2
WHERE PONum IS NOT NULL
/*AND PONum = '16533227'*/
GROUP BY 
PONum,
PRONum,
SyncadaRefNum,
ItemHeader,
LineID,
LineNum,
LineItemType,
ServiceChargeCd
HAVING COUNT(*) <> 1
) dupes ON dupes.PONum = usbct.PONum
AND dupes.ProNum = usbct.ProNum
AND dupes.SyncadaRefNum = usbct.SyncadaRefNum
AND dupes.ItemHeader = usbct.ItemHeader
AND dupes.LineID = usbct.LineID
AND dupes.LineNum = usbct.LineNum

UPDATE USCTTDEV.dbo.tblUSBankCharges2
SET LineNum = '2'
WHERE ID = '7454116'

DELETE FROM USCTTDEV.dbo.tblUSBankCharges
WHERE AddedFromFile IN ('2021-02-13_10-19-05.116-USA_.KCNAUSD_Paid_USD_2502693_20210213.txt',
'2021-01-22_10-19-04.591-USA_.KCNAUSD_Paid_USD_2491340_20210122.txt',
'2020-12-12_10-19-08.690-USA_.KCNAUSD_Paid_USD_2466888_20201212.txt'
)

*/


/*
These are loops to update data types, not used in the stored procedure but in the Python file.

--Set database
--USE tempdb;

--Set table
DECLARE @TableName sysname = '##tblUSBChargesTemp';

--Declare table used to hold data types from table
DECLARE @DataTypes TABLE (
  Class varchar(50),
  Name varchar(50),
  PRIMARY KEY (Name)
);

--Insert datatypes from table
INSERT INTO @DataTypes (Class
, Name)
  VALUES ('Text', 'text')
  , ('Text', 'ntext')
  , ('Text', 'varchar')
  , ('Text', 'char')
  , ('Text', 'nvarchar')
  , ('Text', 'nchar')
  , ('Numeric', 'bit')
  , ('Numeric', 'tinyint')
  , ('Numeric', 'smallint')
  , ('Numeric', 'int')
  , ('Numeric', 'bigint')
  , ('Numeric', 'smallmoney')
  , ('Numeric', 'money')
  , ('Numeric', 'real')
  , ('Numeric', 'float')
  , ('Numeric', 'decimal')
  , ('Numeric', 'numeric')

  
SELECT * FROM @DataTypes

--Declare table used to hold update statements
DECLARE @UpdateStatements TABLE (
  RowNumber INT,
  UpdateStatement varchar(max),
  PRIMARY KEY (RowNumber)
);

--Insert update statements into table
INSERT INTO @UpdateStatements (RowNumber
, UpdateStatement)
SELECT
	ROW_NUMBER() OVER(ORDER BY QUOTENAME(OBJECT_NAME(c.object_id)) ASC) AS RowNumber,
  [UpdateStatement] = Concat
  ('UPDATE '
  , QUOTENAME(OBJECT_NAME(c.object_id))
  , ' SET '
  , QUOTENAME(c.name)
  , ' = NULL WHERE '
  , QUOTENAME(c.name)
  , ' = ''0'' OR '
    , QUOTENAME(c.name)
  , ' = ''0.0'' OR '
  ,QUOTENAME(c.name)
  , ' = ''nan''  '
 /* , CASE
    WHEN dt.Class = 'text' THEN '0'
    ELSE ''''''
  END*/
  , ' ;'
  )
FROM sys.columns c
INNER JOIN sys.types typ
  ON c.system_type_id = typ.system_type_id
INNER JOIN @DataTypes dt
  ON typ.name = dt.Name
WHERE OBJECT_NAME(c.object_id) = @TableName
/*AND c.is_nullable = 1*/
;

SELECT * FROM @UpdateStatements

--Declare variables used for row iteration over update queries
DECLARE @i INT,
@numrows INT,
@sqlCommand NVARCHAR(1000)
--Loop over the table
SET @i = 1
SET @numrows = (SELECT COUNT(*) FROM @UpdateStatements)
IF @numrows > 0
    WHILE (@i <= (SELECT MAX(RowNumber) FROM @UpdateStatements))
    BEGIN
		--Set @sqlCommand to the current query, and execute via sp_executesql
		SET @sqlCommand = (SELECT UpdateStatement FROM @UpdateStatements WHERE RowNumber = @i) 
		EXECUTE sp_executesql @sqlCommand
        SET @i = @i + 1
    END
*/

/*
Get the MAX character lengths

SELECT MAX(LEN(usbct.[File]
))Files,MAX(LEN(usbct.ExchangeDesc
))ExchangeDesc,MAX(LEN(usbct.CycleStartDate
))CycleStartDate,MAX(LEN(usbct.CycleEndDate
))CycleEndDate,MAX(LEN(usbct.ExchangePurpose
))ExchangePurpose,MAX(LEN(usbct.CurrencyCode
))CurrencyCode,MAX(LEN(usbct.[File]
))Files2,MAX(LEN(usbct.SyncadaRefNum
))SyncadaRefNum,MAX(LEN(usbct.DocumentType
))DocumentType,MAX(LEN(usbct.FinancialStatusDate
))FinancialStatusDate,MAX(LEN(usbct.ProcessingModel
))ProcessingModel,MAX(LEN(usbct.Terms
))Terms,MAX(LEN(usbct.InboundOutbound
))InboundOutbound,MAX(LEN(usbct.ShipmentMode
))ShipmentMode,MAX(LEN(usbct.PONum
))PONum,MAX(LEN(usbct.PODate
))PODate,MAX(LEN(usbct.PRONum
))PRONum,MAX(LEN(usbct.SellerOrderNum
))SellerOrderNum,MAX(LEN(usbct.CarrInvoiceDate
))CarrInvoiceDate,MAX(LEN(usbct.eBillID
))eBillID,MAX(LEN(usbct.TransactionCreateDate
))TransactionCreateDate,MAX(LEN(usbct.SellerOrgName
))SellerOrgName,MAX(LEN(usbct.SellerIDCode
))SellerIDCode,MAX(LEN(usbct.BuyerOrgName
))BuyerOrgName,MAX(LEN(usbct.BuyerID
))BuyerID,MAX(LEN(usbct.EquipmentType
))EquipmentType,MAX(LEN(usbct.MoveType
))MoveType,MAX(LEN(usbct.SpotBid
))SpotBid,MAX(LEN(usbct.ShipFromAddress1
))ShipFromAddress1,MAX(LEN(usbct.ShipFromAddress2
))ShipFromAddress2,MAX(LEN(usbct.ShipFromCity
))ShipFromCity,MAX(LEN(usbct.ShipFromState
))ShipFromState,MAX(LEN(usbct.ShipFromPostalCd
))ShipFromPostalCd,MAX(LEN(usbct.ShipFromCountry
))ShipFromCountry,MAX(LEN(usbct.ShipToName
))ShipToName,MAX(LEN(usbct.ShipToAddress1
))ShipToAddress1,MAX(LEN(usbct.ShipToAddress2
))ShipToAddress2,MAX(LEN(usbct.ShipToCity
))ShipToState,MAX(LEN(usbct.ShipToState
))ShipToState,MAX(LEN(usbct.ShipToPostalCd
))ShipToPostalCd,MAX(LEN(usbct.ShipToCountry
))ShipToCountry,MAX(LEN(usbct.VoucherID
))VoucherID,MAX(LEN(usbct.Container1Type
))Container1Type,MAX(LEN(usbct.BillToAccountNum
))BillToAccountNum,MAX(LEN(usbct.USBillToAmount
))USBillToAmount,MAX(LEN(usbct.ItemHeader
))ItemHeader,MAX(LEN(usbct.LineID
))LineID,MAX(LEN(usbct.LineNum
))LineNum,MAX(LEN(usbct.LineItemType
))LineItemType,MAX(LEN(usbct.GLCd
))GLCd,MAX(LEN(usbct.ExpectedAmt
))ExpectedAmt,MAX(LEN(usbct.LineItemDlr
))LineItemDlr,MAX(LEN(usbct.CreditDebitFlag
))CreditDebitFlag,MAX(LEN(usbct.BookedExpectAmt
))BookedExpectAmt,MAX(LEN(usbct.BookedExpectFlag
))BookedExpectFlag,MAX(LEN(usbct.BookedBilledAmt
))BookedBilledAmt,MAX(LEN(usbct.BookedBilledFlag
))BookedBilledFlag,MAX(LEN(usbct.BuyerPOTCN
))BuyerPOTCN,MAX(LEN(usbct.ServiceChargeCd
))ServiceChargeCd,MAX(LEN(usbct.CommodityCd
))CommodityCd,MAX(LEN(usbct.ProductClass
))ProductClass,MAX(LEN(usbct.BilledRatedAsQty
))BilledRatedAsQty,MAX(LEN(usbct.BilledRatedAsUOM
))BilledRatedAsUOM,MAX(LEN(usbct.ActualWeight
))ActualWeight,MAX(LEN(usbct.ActualWeightUOM
))ActualWeightUOM,MAX(LEN(usbct.Volume
))Volume,MAX(LEN(usbct.VolumeUOM
))VolumeUOM,MAX(LEN(CAST(usbct.LandingQty AS NUMERIC(18,2))
))LandingQty,MAX(LEN(usbct.PackingFormCd
))PackingFormCd,MAX(LEN(usbct.LineItemUnitPrice
))LineItemUnitPrice,MAX(LEN(usbct.LineItemExtendedPrice
))LineItemExtendedPrice,MAX(LEN(usbct.BilledUnitOfMeasure
))BilledUnitOfMeasure,MAX(LEN(usbct.UnitPriceInvoice
))UnitPriceInvoice,MAX(LEN(CAST(usbct.QuantityInvoice AS NUMERIC(18,2))
))QuantityInvoice,MAX(LEN(usbct.AmountInvoice
))AmountInvoice,MAX(LEN(usbct.UnitPricePO
))UnitPricePO,MAX(LEN(usbct.AmountPO
))AmountPO,MAX(LEN(usbct.TotalShipmentMileage))TotalShipmentMileage

FROM ##tblUSBChargesTemp usbct
LEFT JOIN USCTTDEV.dbo.tblUSBankCharges usbc ON usbc.PONum = usbct.PONum
AND usbc.LineID = usbct.LineID
AND usbc.LineNum = usbct.LineNum
WHERE usbc.PONum IS NULL
AND usbc.LineID IS NULL
AND usbc.LineNum IS NULL

*/

END
