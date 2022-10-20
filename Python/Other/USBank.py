'''
Code below to create Excel requires xlsxwriter
python -m pip install xrd xlsxwriter

# Example of writting via SQL to DB
# If executing this on KC Linux that is AD integrated refer to the
# following Yammer post on SQL driver setup.
# https://www.yammer.com/kcc.com/#/Threads/show?threadId=912791555

Added the following paths to my environment variables:
C:\\ProgramData\Anaconda3\\
C:\\ProgramData\Anaconda3\\Library\\bin

Also, be sure you've installed ALL packages below on the end computer!
turbodbc - https://turbodbc.readthedocs.io/en/latest/pages/getting_started.html#installation

What does this file do?
1) Loop through .txt files that exist within a single folder
    1) Read through lines, and parse into 3 different sections;
        1) Document header
        2) Freight bill
        3) Line item detail
    2) Append full recordset to Excel document for troubleshooting
    3) Append full recordset to MSSQL temp table, and execute stored procedure
    4) Move file to completed directory
2) Move to next .txt file in directory

Only take PAID string,
Where Date Modified = today
////sappa4fs.kcc.com//interfaces//PA4//Mulesoft//EDI//USBANK//IN//Processed
'''
import io
import os
import difflib
import pandas as pd
import numpy as np
import sqlalchemy as sa
from urllib.parse import quote_plus
from turbodbc import connect, make_options
from io import StringIO
from datetime import datetime
import time
from shutil import copyfile, move

#Set starting directory
startDir = '\\\\USTCA097\\Stage\\Database Files\\USBank\\1 - Files To Process'
"""
#If there's a text file already in the directory, delete that ish
for filename in os.listdir(startDir):
    if filename.endswith('.txt'):
        filepath = startDir +'\\'+ filename
        os.remove(filepath)
"""
#Set directory which has files
fileDir = '\\\\sappa4fs.kcc.com\\interfaces\\PA4\\Mulesoft\\EDI\\USBANK\\IN\\Processed'

#Loop through all files, and if it's a PAID .txt file that was modified in the last 24 hours, copy to the Files to Process folder
for filename in os.listdir(fileDir):
    now = datetime.today()
    if filename.endswith('.txt') and "PAID" in filename.upper():
        filepath = fileDir +'\\'+ filename
        modDate = datetime.fromtimestamp(os.path.getmtime(filepath))
        hoursOld = (now - modDate).total_seconds() / 3600
        if hoursOld < 24 and os.path.getsize(filepath) > 0:
                destfilepath = startDir +'\\'+ filename
                copyfile(filepath, destfilepath)
                #copyfile(filepath, destfilepath)

#Set completed directory
compDir = '\\\\USTCA097\\Stage\\Database Files\\USBank\\2 - Completed Files'

# Variables to hold record types when parsed
master = ''
freightBill = ''
freightBillDetail = ''

# Open connection to MSSQL Server
tempdb_params = quote_plus("Driver={ODBC Driver 17 for SQL Server};"
"Server=USTCAS98.KCC.COM;Database=TEMPDB;"
"Trusted_Connection=YES;Encrypt=YES;"
"TrustServerCertificate=YES")
tempdb_conn_string = f"mssql+pyodbc:///?odbc_connect={tempdb_params}"
tempdb_engine = sa.create_engine(tempdb_conn_string, fast_executemany=True)

#Set turboodbc options
options = make_options(parameter_sets_to_buffer=1000)

tembdb_connection = connect(
                            driver="ODBC Driver 17 for SQL Server",
                            server="USTCAS98.KCC.COM",
                            database="TEMPDB",
                            trusted_connection="YES",
                            encrypt="YES",
                            trustservercertificate="YES"
                            )

#tempdb_conn_string = f"mssql+pyodbc:///?odbc_connect={tempdb_params}"
#engine = create_engine(tempdb_conn_string, fast_executemany=True)
#@event.listens_for(engine, "before_cursor_execute")
#def receive_before_cursor_execute(
#       conn, cursor, statement, params, context, executemany
#        ):
#            if executemany:
#                cursor.fast_executemany = True

# Connect to main MSSQL Database
USCTTDEV_params = quote_plus("Driver={ODBC Driver 17 for SQL Server};"
"Server=USTCAS98.KCC.COM;Database=USCTTDEV;"
"Trusted_Connection=YES;Encrypt=YES;"
"TrustServerCertificate=YES")
USCTTDEV_conn_string = f"mssql+pyodbc:///?odbc_connect={USCTTDEV_params}"
USCTTDEV = sa.create_engine(USCTTDEV_conn_string)
USCTTDEVConn = USCTTDEV.connect()  

#Create a single table out of all available temp tables
def loopMSSQL():
    #SQL Temp Table Loop Counter
    sqlLoopCounter = 1

    #SQL Union String
    sqlUnionString = ("SELECT * INTO ##tblUSBChargesTemp FROM (SELECT * FROM ##tblUSBChargesTemp0 ")

    #SQL Union Loop
    sqlUnionLoop = ""

    while(sqlLoopCounter < loopCounter):
        sqlUnionLoop = sqlUnionLoop + "UNION ALL SELECT * FROM ##tblUSBChargesTemp" + str(sqlLoopCounter) + " "
        sqlLoopCounter = sqlLoopCounter + 1

    sqlUnionString = sqlUnionString + sqlUnionLoop + ")data"

    # cleans the previous head insert
    with tembdb_connection.cursor() as cursor:
        cursor.execute(str(sqlUnionString))
        tembdb_connection.commit()

#Update the single temp table value to null where they are certain values
def cleanMSSQL():
    for col in merge_df.columns:

        sqlCleanString = ("UPDATE ##tblUSBChargesTemp SET [" + col + "] = NULL WHERE [" + col + "] IN ('0', '0.0', 'nan')")
        # cleans the previous head insert
        with tembdb_connection.cursor() as cursor:
            cursor.execute(str(sqlCleanString))
            tembdb_connection.commit()

        if 'Date' in col:
        #sqlCleanString = ("UPDATE ##tblUSBChargesTemp SET [" + col + "] = REPLACE([" + col + "],'.0','')")
            sqlCleanString = ("UPDATE ##tblUSBChargesTemp SET [" + col + "] = CONVERT(NVARCHAR(10), CONVERT(DATE, REPLACE([" + col + "],'.0',''), 103), 101)")
            # cleans the previous head insert
            with tembdb_connection.cursor() as cursor:
                cursor.execute(str(sqlCleanString))
                tembdb_connection.commit()

#Runs stored procedure on MSSQL server to append new data to main table, and update existing rows
def sp_MSSQL():
    sqlSPString = ("EXEC USCTTDEV.dbo.sp_USBank")
    # cleans the previous head insert
    with tembdb_connection.cursor() as cursor:
        cursor.execute(str(sqlSPString))
        tembdb_connection.commit()

# Move file to completed directory, and change to Filename+'-Completed.txt
def renameFiles():
    for i in completedFiles:

        oldFile = i[0]
        newFile = i[-1]
        move(oldFile, newFile + '.txt')
        #os.rename(oldFile, newFile + '.txt') 

#Loop over each filename
#Loop Counter
loopCounter = 0

#Array holds all completed files that have been pushed to MSSQL Server
completedFiles = []

for filename in os.listdir(startDir):
    fileCount = 0
    if filename.endswith('.txt'):
        fileCount = fileCount + 1
        file = startDir +'\\'+ filename
        fileText = os.path.splitext(os.path.basename(filename))[0]
        newFileText = fileText #+ '-Complete.txt'

        #Array holds the previous file name, and the new file name, used for moving files later in process
        filelist = [startDir +'\\'+ filename, compDir +'\\'+ newFileText]

        # Open file, then close as soon as data is gathered in memory
        with open(file, 'r') as fin:
            data = fin.readlines()
        fin.close

        #make sure variables are null
        master = ""
        freightBill = ""
        freightBillDetail = ""
        master_df = ""
        freightBill_df = ""
        freightBillDetail_df = ""
        merge_df = ""
        _words = ""
        _first2 = ""

        # Parse the file and group record types
        for line in data:
            
            _words = line.split('|')
            
            #Get the first 2 characters of the word
            first2 = _words[0:1]

            #Get the first 4 characters of the word
            first4 = _words[0:4]

            # Append master record to own array
            if '00' in first2 or '"00"' in first4:
                master += line

            elif '01' in first2 or '"01"' in first4:
                freightBill += line

            elif '02' in first2 or '"02"' in first4:
                freightBillDetail += line

        fileOutput = open('\\\\USTCA097\\Stage\\Database Files\\USBank\\master.txt', 'w')
        fileOutput.write(master)
        fileOutput.close

        fileOutput = open('\\\\USTCA097\\Stage\\Database Files\\USBank\\FreightBill.txt', 'w')
        fileOutput.write(freightBill)
        fileOutput.close

        fileOutput = open('\\\\USTCA097\\Stage\\Database Files\\USBank\\freightBillDetail.txt', 'w')
        fileOutput.write(freightBillDetail)
        fileOutput.close

        # Create master dataframe and invoice key for final invoice merge
        master_df = pd.read_csv(io.StringIO(master), sep='|', header=None)
        master_df['File'] = filename
        master_df.columns = ["FileHeader"
                            ,"HeaderOffering"
                            ,"ReferenceID"
                            ,"TransControlNum"
                            ,"SenderID"
                            ,"ReceiverID"
                            ,"ExchangeDesc"
                            ,"CycleStartDate"
                            ,"CycleEndDate"
                            ,"ExchangePurpose"
                            ,"ExtractType"
                            ,"BillToAccountNumMain"
                            ,"SyncadaInvNum"
                            ,"SyncadaInvDate"
                            ,"RemitToName"
                            ,"RemitToAddr"
                            ,"RemitToCity"
                            ,"RemitToState"
                            ,"RemitToPostalCode"
                            ,"CurrencyCode"
                            ,"File"]

        #Columns to drop in Master File
        #cols = [11,12,13,14,15,16,17,18,19]
        #master_df.drop(master_df.columns[cols],axis=1,inplace=True)

        # Create the freightBill and row level dataframes
        freightBill_df = pd.read_csv(io.StringIO(freightBill), sep='|', header=None)
        freightBill_df['File'] = filename
        #print(freightBill_df.info(verbose=True))
        freightBill_df.columns = ["RecordHeader"
                                ,"SyncadaRefNum"
                                ,"DocumentType"
                                ,"FinancialStatus"
                                ,"FinancialStatusDate"
                                ,"ProcessingModel"
                                ,"Terms"
                                ,"InboundOutbound"
                                ,"ShipmentMode"
                                ,"PONum"
                                ,"PODate"
                                ,"PRONum"
                                ,"SellerOrderNum"
                                ,"CarrInvoiceDate"
                                ,"eBillID"
                                ,"BuyerOrderNum"
                                ,"TransactionCreateDate"
                                ,"SellerOrgName"
                                ,"SellerIDCode"
                                ,"SellerAddress1"
                                ,"SellerAddress2"
                                ,"SellerCity"
                                ,"SellerState"
                                ,"SellerPostalCd"
                                ,"SellerCountry"
                                ,"BuyerOrgName"
                                ,"BuyerID"
                                ,"BuyerAddress1"
                                ,"BuyerAddress2"
                                ,"BuyerCity"
                                ,"BuyerState"
                                ,"BuyerPostalCd"
                                ,"BuyerCountry"
                                ,"ServiceLevelReq"
                                ,"ServiceLevelProv"
                                ,"ComplianceCompEvent"
                                ,"ScheduledPickupDate"
                                ,"ActualShipDate"
                                ,"RequestedDeliveryDate"
                                ,"ActualDeliveryDate"
                                ,"ActualDeliveryTime"
                                ,"ServiceCompDate"
                                ,"ServiceCompTime"
                                ,"EquipmentType"
                                ,"MoveType"
                                ,"SpotBid"
                                ,"BusinessSegment"
                                ,"ComplianceDate"
                                ,"ComplianceTime"
                                ,"ShipFromName"
                                ,"ShipFromLocCode"
                                ,"ShipFromFacID"
                                ,"ShipFromLocType"
                                ,"ShipFromAddress1"
                                ,"ShipFromAddress2"
                                ,"ShipFromCity"
                                ,"ShipFromState"
                                ,"ShipFromPostalCd"
                                ,"ShipFromCountry"
                                ,"ShipToName"
                                ,"ShipToLocationCd"
                                ,"ShipToFacilityID"
                                ,"ShipToLocationType"
                                ,"ShipToAddress1"
                                ,"ShipToAddress2"
                                ,"ShipToCity"
                                ,"ShipToState"
                                ,"ShipToPostalCd"
                                ,"ShipToCountry"
                                ,"FBUserDefQual1"
                                ,"VoucherID"
                                ,"FBUserDefQual2"
                                ,"FBUserDefVal2"
                                ,"FBUserDefQual3"
                                ,"FBUserDefVal3"
                                ,"VesselName"
                                ,"VesselNumber"
                                ,"VoyageNumber"
                                ,"VesselRegCountry"
                                ,"Container1Type"
                                ,"Container1Num"
                                ,"Container1Weight"
                                ,"Container1Volume"
                                ,"Container2Type"
                                ,"Container2Num"
                                ,"Container2Weight"
                                ,"Container2Volume"
                                ,"Container3Type"
                                ,"Container3Number"
                                ,"Container3Weight"
                                ,"Container3Volume"
                                ,"BillToAccountNum"
                                ,"USBillToAmount"
                                ,"File"]   

        # Create the freightBillDetail row level dataframe
        freightBillDetail_df = pd.read_csv(io.StringIO(freightBillDetail), sep='|', header=None)
        freightBillDetail_df.columns = ["ItemHeader"
                                        ,"SyncadaRefNum"
                                        ,"LineID"
                                        ,"LineNum"
                                        ,"LineItemType"
                                        ,"GLCd"
                                        ,"ExpectedAmt"
                                        ,"LineItemDlr"
                                        ,"CreditDebitFlag"
                                        ,"BookedExpectAmt"
                                        ,"BookedExpectFlag"
                                        ,"BookedBilledAmt"
                                        ,"BookedBilledFlag"
                                        ,"BuyerPOTCN"
                                        ,"ServiceChargeCd"
                                        ,"CommodityCd"
                                        ,"ProductClass"
                                        ,"BuyerProductID"
                                        ,"SellerProductID"
                                        ,"POType"
                                        ,"DepartmentNum"
                                        ,"Division"
                                        ,"TaxLevel"
                                        ,"BilledRatedAsQty"
                                        ,"BilledRatedAsUOM"
                                        ,"ActualWeight"
                                        ,"ActualWeightUOM"
                                        ,"Volume"
                                        ,"VolumeUOM"
                                        ,"LandingQty"
                                        ,"PackingFormCd"
                                        ,"LineItemUnitPrice"
                                        ,"LineItemExtendedPrice"
                                        ,"FBDUserDefQual1"
                                        ,"FBDUserDefVal1"
                                        ,"FBDUserDefQual2"
                                        ,"FBDUserDefVal2"
                                        ,"FBDUserDefQual3"
                                        ,"FBDUserDefVal3"
                                        ,"RatedUOM"
                                        ,"BilledUnitOfMeasure"
                                        ,"UnitPriceInvoice"
                                        ,"QuantityInvoice"
                                        ,"UOMInvoice"
                                        ,"UOM2Invoice"
                                        ,"Quantity2Invoice"
                                        ,"PercentAdjustmentInvoice"
                                        ,"AmountInvoice"
                                        ,"UnitPricePO"
                                        ,"QuantityPO"
                                        ,"UOMPO"
                                        ,"OPM2PO"
                                        ,"Quantity2PO"
                                        ,"PercentAdjustmentPO"
                                        ,"AmountPO"
                                        ,"TotalShipmentMileage"
                                        ,"MileageSource"
                                        ,"MileageType"
                                        ,"MileageVersion"]        

        # Merge all dataframes together
        merge_df = master_df.merge(freightBill_df, on='File', how='left')

        # merge_df['File'] = filename
        merge_df = merge_df.merge(freightBillDetail_df, on='SyncadaRefNum', how='left')

        # Dump it to Excel for QA
        #writer = pd.ExcelWriter(startDir + '\\' + filename.replace('.txt','') +'.xlsx' , engine='xlsxwriter')
        #merge_df.to_excel(writer, 'FullData', index=True)
        #master_df.to_excel(writer, 'Master', index=True)
        #freightBill_df.to_excel(writer, 'FreightBill', index=True)
        #freightBillDetail_df.to_excel(writer, 'FreightBillDetail', index=True)
        #writer.save()
        
        #Set final data types for each header in dataframe
        merge_df.ActualDeliveryDate = merge_df.ActualDeliveryDate.astype('object')
        merge_df.ActualDeliveryTime = merge_df.ActualDeliveryTime.astype('object')
        merge_df.ActualShipDate = merge_df.ActualShipDate.astype('object')
        merge_df.ActualWeight = merge_df.ActualWeight.astype('object')
        merge_df.ActualWeightUOM = merge_df.ActualWeightUOM.astype('object')
        merge_df.AmountInvoice = merge_df.AmountInvoice.astype('object')
        merge_df.AmountPO = merge_df.AmountPO.astype('object')
        merge_df.BilledRatedAsQty = merge_df.BilledRatedAsQty.astype('object')
        merge_df.BilledRatedAsUOM = merge_df.BilledRatedAsUOM.astype('object')
        merge_df.BilledUnitOfMeasure = merge_df.BilledUnitOfMeasure.astype('object')
        merge_df.BillToAccountNum = merge_df.BillToAccountNum.astype('object')
        merge_df.BillToAccountNumMain = merge_df.BillToAccountNumMain.astype('object')
        merge_df.BookedBilledAmt = merge_df.BookedBilledAmt.astype('object')
        merge_df.BookedBilledFlag = merge_df.BookedBilledFlag.astype('object')
        merge_df.BookedExpectAmt = merge_df.BookedExpectAmt.astype('object')
        merge_df.BookedExpectFlag = merge_df.BookedExpectFlag.astype('object')
        merge_df.BusinessSegment = merge_df.BusinessSegment.astype('object')
        merge_df.BuyerAddress1 = merge_df.BuyerAddress1.astype('object')
        merge_df.BuyerAddress2 = merge_df.BuyerAddress2.astype('object')
        merge_df.BuyerCity = merge_df.BuyerCity.astype('object')
        merge_df.BuyerCountry = merge_df.BuyerCountry.astype('object')
        merge_df.BuyerID = merge_df.BuyerID.astype('object')
        merge_df.BuyerOrderNum = merge_df.BuyerOrderNum.astype('object')
        merge_df.BuyerOrgName = merge_df.BuyerOrgName.astype('object')
        merge_df.BuyerPostalCd = merge_df.BuyerPostalCd.astype('object')
        merge_df.BuyerPOTCN = merge_df.BuyerPOTCN.astype('object')
        merge_df.BuyerProductID = merge_df.BuyerProductID.astype('object')
        merge_df.BuyerState = merge_df.BuyerState.astype('object')
        merge_df.CarrInvoiceDate = merge_df.CarrInvoiceDate.astype('object')
        merge_df.CommodityCd = merge_df.CommodityCd.astype('object')
        merge_df.ComplianceCompEvent = merge_df.ComplianceCompEvent.astype('object')
        merge_df.ComplianceDate = merge_df.ComplianceDate.astype('object')
        merge_df.ComplianceTime = merge_df.ComplianceTime.astype('object')
        merge_df.Container1Num = merge_df.Container1Num.astype('object')
        merge_df.Container1Type = merge_df.Container1Type.astype('object')
        merge_df.Container1Volume = merge_df.Container1Volume.astype('object')
        merge_df.Container1Weight = merge_df.Container1Weight.astype('object')
        merge_df.Container2Num = merge_df.Container2Num.astype('object')
        merge_df.Container2Type = merge_df.Container2Type.astype('object')
        merge_df.Container2Volume = merge_df.Container2Volume.astype('object')
        merge_df.Container2Weight = merge_df.Container2Weight.astype('object')
        merge_df.Container3Number = merge_df.Container3Number.astype('object')
        merge_df.Container3Type = merge_df.Container3Type.astype('object')
        merge_df.Container3Volume = merge_df.Container3Volume.astype('object')
        merge_df.Container3Weight = merge_df.Container3Weight.astype('object')
        merge_df.CreditDebitFlag = merge_df.CreditDebitFlag.astype('object')
        merge_df.CurrencyCode = merge_df.CurrencyCode.astype('object')
        merge_df.CycleEndDate = merge_df.CycleEndDate.astype('object')
        merge_df.CycleStartDate = merge_df.CycleStartDate.astype('object')
        merge_df.DepartmentNum = merge_df.DepartmentNum.astype('object')
        merge_df.Division = merge_df.Division.astype('object')
        merge_df.DocumentType = merge_df.DocumentType.astype('object')
        merge_df.eBillID = merge_df.eBillID.astype('object')
        merge_df.EquipmentType = merge_df.EquipmentType.astype('object')
        merge_df.ExchangeDesc = merge_df.ExchangeDesc.astype('object')
        merge_df.ExchangePurpose = merge_df.ExchangePurpose.astype('object')
        merge_df.ExpectedAmt = merge_df.ExpectedAmt.astype('object')
        merge_df.ExtractType = merge_df.ExtractType.astype('object')
        merge_df.FBDUserDefQual1 = merge_df.FBDUserDefQual1.astype('object')
        merge_df.FBDUserDefQual2 = merge_df.FBDUserDefQual2.astype('object')
        merge_df.FBDUserDefQual3 = merge_df.FBDUserDefQual3.astype('object')
        merge_df.FBDUserDefVal2 = merge_df.FBDUserDefVal2.astype('object')
        merge_df.FBUserDefQual1 = merge_df.FBUserDefQual1.astype('object')
        merge_df.FBUserDefQual2 = merge_df.FBUserDefQual2.astype('object')
        merge_df.FBUserDefQual3 = merge_df.FBUserDefQual3.astype('object')
        merge_df.FBDUserDefVal1 = merge_df.FBDUserDefVal1.astype('object')
        merge_df.FBUserDefVal2 = merge_df.FBUserDefVal2.astype('object')
        merge_df.FBUserDefVal3 = merge_df.FBUserDefVal3.astype('object')
        merge_df.FBUserDefVal3 = merge_df.FBUserDefVal3.astype('object')
        merge_df.File = merge_df.File.astype('object')
        merge_df.FileHeader = merge_df.FileHeader.astype('object')
        merge_df.FinancialStatus = merge_df.FinancialStatus.astype('object')
        merge_df.FinancialStatusDate = merge_df.FinancialStatusDate.astype('object')
        merge_df.GLCd = merge_df.GLCd.astype('object')
        merge_df.HeaderOffering = merge_df.HeaderOffering.astype('object')
        merge_df.InboundOutbound = merge_df.InboundOutbound.astype('object')
        merge_df.ItemHeader = merge_df.ItemHeader.astype('object')
        merge_df.LandingQty = merge_df.LandingQty.astype('object')
        merge_df.LineID = merge_df.LineID.astype('object')
        merge_df.LineItemDlr = merge_df.LineItemDlr.astype('object')
        merge_df.LineItemExtendedPrice = merge_df.LineItemExtendedPrice.astype('object')
        merge_df.LineItemType = merge_df.LineItemType.astype('object')
        merge_df.LineItemUnitPrice = merge_df.LineItemUnitPrice.astype('object')
        merge_df.LineNum = merge_df.LineNum.astype('object')
        merge_df.MileageSource = merge_df.MileageSource.astype('object')
        merge_df.MileageType = merge_df.MileageType.astype('object')
        merge_df.MileageVersion = merge_df.MileageVersion.astype('object')
        merge_df.MoveType = merge_df.MoveType.astype('object')
        merge_df.OPM2PO = merge_df.OPM2PO.astype('object')
        merge_df.PackingFormCd = merge_df.PackingFormCd.astype('object')
        merge_df.PercentAdjustmentInvoice = merge_df.PercentAdjustmentInvoice.astype('object')
        merge_df.PercentAdjustmentPO = merge_df.PercentAdjustmentPO.astype('object')
        merge_df.PODate = merge_df.PODate.astype('object')
        merge_df.PONum = merge_df.PONum.astype('object')
        merge_df.POType = merge_df.POType.astype('object')
        merge_df.ProcessingModel = merge_df.ProcessingModel.astype('object')
        merge_df.ProductClass = merge_df.ProductClass.astype('object')
        merge_df.PRONum = merge_df.PRONum.astype('object')
        merge_df.Quantity2Invoice = merge_df.Quantity2Invoice.astype('object')
        merge_df.Quantity2PO = merge_df.Quantity2PO.astype('object')
        merge_df.QuantityInvoice = merge_df.QuantityInvoice.astype('object')
        merge_df.QuantityPO = merge_df.QuantityPO.astype('object')
        merge_df.RatedUOM = merge_df.RatedUOM.astype('object')
        merge_df.ReceiverID = merge_df.ReceiverID.astype('object')
        merge_df.RecordHeader = merge_df.RecordHeader.astype('object')
        merge_df.ReferenceID = merge_df.ReferenceID.astype('object')
        merge_df.RemitToAddr = merge_df.RemitToAddr.astype('object')
        merge_df.RemitToCity = merge_df.RemitToCity.astype('object')
        merge_df.RemitToName = merge_df.RemitToName.astype('object')
        merge_df.RemitToPostalCode = merge_df.RemitToPostalCode.astype('object')
        merge_df.RemitToState = merge_df.RemitToState.astype('object')
        merge_df.RequestedDeliveryDate = merge_df.RequestedDeliveryDate.astype('object')
        merge_df.ScheduledPickupDate = merge_df.ScheduledPickupDate.astype('object')
        merge_df.SellerAddress1 = merge_df.SellerAddress1.astype('object')
        merge_df.SellerAddress2 = merge_df.SellerAddress2.astype('object')
        merge_df.SellerCity = merge_df.SellerCity.astype('object')
        merge_df.SellerCountry = merge_df.SellerCountry.astype('object')
        merge_df.SellerIDCode = merge_df.SellerIDCode.astype('object')
        merge_df.SellerOrderNum = merge_df.SellerOrderNum.astype('object')
        merge_df.SellerOrgName = merge_df.SellerOrgName.astype('object')
        merge_df.SellerPostalCd = merge_df.SellerPostalCd.astype('object')
        merge_df.SellerProductID = merge_df.SellerProductID.astype('object')
        merge_df.SellerState = merge_df.SellerState.astype('object')
        merge_df.SenderID = merge_df.SenderID.astype('object')
        merge_df.ServiceChargeCd = merge_df.ServiceChargeCd.astype('object')
        merge_df.ServiceCompDate = merge_df.ServiceCompDate.astype('object')
        merge_df.ServiceCompTime = merge_df.ServiceCompTime.astype('object')
        merge_df.ServiceLevelProv = merge_df.ServiceLevelProv.astype('object')
        merge_df.ServiceLevelReq = merge_df.ServiceLevelReq.astype('object')
        merge_df.ShipFromAddress1 = merge_df.ShipFromAddress1.astype('object')
        merge_df.ShipFromAddress2 = merge_df.ShipFromAddress2.astype('object')
        merge_df.ShipFromCity = merge_df.ShipFromCity.astype('object')
        merge_df.ShipFromCountry = merge_df.ShipFromCountry.astype('object')
        merge_df.ShipFromFacID = merge_df.ShipFromFacID.astype('object')
        merge_df.ShipFromLocCode = merge_df.ShipFromLocCode.astype('object')
        merge_df.ShipFromLocType = merge_df.ShipFromLocType.astype('object')
        merge_df.ShipFromName = merge_df.ShipFromName.astype('object')
        merge_df.ShipFromPostalCd = merge_df.ShipFromPostalCd.astype('object')
        merge_df.ShipFromState = merge_df.ShipFromState.astype('object')
        merge_df.ShipmentMode = merge_df.ShipmentMode.astype('object')
        merge_df.ShipToAddress1 = merge_df.ShipToAddress1.astype('object')
        merge_df.ShipToAddress2 = merge_df.ShipToAddress2.astype('object')
        merge_df.ShipToCity = merge_df.ShipToCity.astype('object')
        merge_df.ShipToCountry = merge_df.ShipToCountry.astype('object')
        merge_df.ShipToFacilityID = merge_df.ShipToFacilityID.astype('object')
        merge_df.ShipToLocationCd = merge_df.ShipToLocationCd.astype('object')
        merge_df.ShipToLocationType = merge_df.ShipToLocationType.astype('object')
        merge_df.ShipToName = merge_df.ShipToName.astype('object')
        merge_df.ShipToPostalCd = merge_df.ShipToPostalCd.astype('object')
        merge_df.ShipToState = merge_df.ShipToState.astype('object')
        merge_df.SpotBid = merge_df.SpotBid.astype('object')
        merge_df.SyncadaInvDate = merge_df.SyncadaInvDate.astype('object')
        merge_df.SyncadaInvNum = merge_df.SyncadaInvNum.astype('object')
        merge_df.SyncadaRefNum = merge_df.SyncadaRefNum.astype('object')
        merge_df.TaxLevel = merge_df.TaxLevel.astype('object')
        merge_df.Terms = merge_df.Terms.astype('object')
        merge_df.TotalShipmentMileage = merge_df.TotalShipmentMileage.astype('object')
        merge_df.TransactionCreateDate = merge_df.TransactionCreateDate.astype('object')
        merge_df.TransControlNum = merge_df.TransControlNum.astype('object')
        merge_df.UnitPriceInvoice = merge_df.UnitPriceInvoice.astype('object')
        merge_df.UnitPricePO = merge_df.UnitPricePO.astype('object')
        merge_df.UOM2Invoice = merge_df.UOM2Invoice.astype('object')
        merge_df.UOMInvoice = merge_df.UOMInvoice.astype('object')
        merge_df.UOMPO = merge_df.UOMPO.astype('object')
        merge_df.USBillToAmount = merge_df.USBillToAmount.astype('object')
        merge_df.VesselName = merge_df.VesselName.astype('object')
        merge_df.VesselNumber = merge_df.VesselNumber.astype('object')
        merge_df.VesselRegCountry = merge_df.VesselRegCountry.astype('object')
        merge_df.Volume = merge_df.Volume.astype('object')
        merge_df.VolumeUOM = merge_df.VolumeUOM.astype('object')
        merge_df.VoucherID = merge_df.VoucherID.astype('object')
        merge_df.VoyageNumber = merge_df.VoyageNumber.astype('object')

        #Get rid of quotes that have appeared, since the update on 6/21/2020
        merge_df = merge_df.applymap(str)
        merge_df.apply(lambda s:s.str.replace('"', ""))

        #Fix string special characters
        merge_df['EquipmentType'] = merge_df['EquipmentType'].str.replace('~1|_~1', "")
        merge_df['Container1Type'] = merge_df['Container1Type'].str.replace('~1|_~1', "")
        merge_df['Container2Type'] = merge_df['Container2Type'].str.replace('~1|_~1', "")
        merge_df['Container3Type'] = merge_df['Container3Type'].str.replace('~1|_~1', "")

        #Drop specific columns from merge_df
        merge_df = merge_df.drop(['FileHeader'
        ,'HeaderOffering'
        ,'ReferenceID'
        ,'TransControlNum'
        ,'SenderID'
        ,'ReceiverID'
        ,'ExtractType'
        ,'BillToAccountNumMain'
        ,'SyncadaInvNum'
        ,'SyncadaInvDate'
        ,'RemitToName'
        ,'RemitToAddr'
        ,'RemitToCity'
        ,'RemitToState'
        ,'RemitToPostalCode'
        ,'RecordHeader'
        ,'FinancialStatus'
        ,'BuyerOrderNum'
        ,'SellerAddress1'
        ,'SellerAddress2'
        ,'SellerCity'
        ,'SellerState'
        ,'SellerPostalCd'
        ,'SellerCountry'
        ,'BuyerAddress1'
        ,'BuyerAddress2'
        ,'BuyerCity'
        ,'BuyerState'
        ,'BuyerPostalCd'
        ,'BuyerCountry'
        ,'ServiceLevelReq'
        ,'ServiceLevelProv'
        ,'ComplianceCompEvent'
        ,'ScheduledPickupDate'
        ,'ActualShipDate'
        ,'RequestedDeliveryDate'
        ,'ActualDeliveryDate'
        ,'ActualDeliveryTime'
        ,'ServiceCompDate'
        ,'BusinessSegment'
        ,'ComplianceDate'
        ,'ComplianceTime'
        ,'ShipFromName'
        ,'ShipFromLocCode'
        ,'ShipFromFacID'
        ,'ShipFromLocType'
        ,'ShipToLocationCd'
        ,'ShipToFacilityID'
        ,'ShipToLocationType'
        ,'FBUserDefQual1'
        ,'FBUserDefQual2'
        ,'FBUserDefVal2'
        ,'FBUserDefQual3'
        ,'FBUserDefVal3'
        ,'VesselName'
        ,'VesselNumber'
        ,'VoyageNumber'
        ,'VesselRegCountry'
        ,'Container1Num'
        ,'Container1Weight'
        ,'Container1Volume'
        ,'Container2Type'
        ,'Container2Num'
        ,'Container2Weight'
        ,'Container2Volume'
        ,'Container3Type'
        ,'Container3Number'
        ,'Container3Weight'
        ,'Container3Volume'
        ,'BuyerProductID'
        ,'SellerProductID'
        ,'POType'
        ,'DepartmentNum'
        ,'Division'
        ,'TaxLevel'
        ,'FBDUserDefQual1'
        ,'FBDUserDefVal1'
        ,'FBDUserDefQual2'
        ,'FBDUserDefVal2'
        ,'FBDUserDefQual3'
        ,'FBDUserDefVal3'
        ,'RatedUOM'
        ,'UOMInvoice'
        ,'UOM2Invoice'
        ,'Quantity2Invoice'
        ,'PercentAdjustmentInvoice'
        ,'QuantityPO'
        ,'UOMPO'
        ,'OPM2PO'
        ,'Quantity2PO'
        ,'PercentAdjustmentPO'
        ,'MileageSource'
        ,'MileageType'
        ,'MileageVersion'
        ], axis=1)

        #Change entire dataframe to object, because holy shit... why are the data types so damn difficult!
        lst = list(merge_df)
        merge_df[lst] = merge_df[lst].astype(str)
        merge_df = merge_df.replace(np.nan, '', regex=True)

        #Fill all NA values with something
        for col in merge_df:
            #get dtype for column
            dt = merge_df[col].dtype 
            #check if it is a number
            if dt == int or dt == float:
                merge_df[col].fillna(0, inplace=True)
            else:
                merge_df[col].fillna("", inplace=True)

        # print data types
        #print(merge_df.info(verbose=True))



        # Dump it to Excel for QA
        #writer = pd.ExcelWriter(startDir + '\\' + filename.replace('.txt','') +'.xlsx' , engine='xlsxwriter')
        #merge_df.to_excel(writer, 'FullData', index=True)
        #master_df.to_excel(writer, 'Master', index=True)
        #freightBill_df.to_excel(writer, 'FreightBill', index=True)
        #freightBillDetail_df.to_excel(writer, 'FreightBillDetail', index=True)
        #writer.save()

        """
        The best way to do this is to connect to the temp db first, and then post results to a temp table there
        Then, once that's done, connect to the main database the stored procedure runs on and execute it
        That enseures that the stored procedure can run on the global temp table while the connection is open
        """

        #Get dataframe size
        count_row = merge_df.shape[0]  # gives number of row count
        count_col = merge_df.shape[1]  # gives number of col count

        #Get Start Time
        startTime = datetime.now()      

        #Function to append temp tables
        def turbo_write(mydb, df, table):
            """Use turbodbc to insert data into sql."""

            #get the array of values
            values = [df[col].values for col in df.columns]

            # preparing columns
            colunas = '(['
            colunas += '], ['.join(df.columns)
            colunas += '])'

            # preparing value place holders
            val_place_holder = ['?' for col in df.columns]
            sql_val = '('
            sql_val += ', '.join(val_place_holder)
            sql_val += ')'

            # writing sql query for turbodbc
            sql = f"""
            INSERT INTO {mydb}.{table} {colunas}
            VALUES {sql_val}
            """

            # cleans the previous head insert
            with tembdb_connection.cursor() as cursor:
                cursor.execute(f"delete from {mydb}.dbo.{table}")
                tembdb_connection.commit()

            # inserts data, for real
            with tembdb_connection.cursor() as cursor:
                try:
                    cursor.executemanycolumns(sql, values)
                    tembdb_connection.commit()
                except Exception as e:
                    tembdb_connection.rollback()
                    print('Failed to upload: '+ str(e))

            #Get End Time
            endTime = datetime.now()
            totalSeconds = (endTime-startTime).total_seconds()
            #stop = (time.time() - start).total_seconds()
            return print(f"File " + filename + " Rows:" + str(count_row) + " Columns: " + str(count_col) + " Total Seconds: " + str(totalSeconds))

        def sqlcol(dfparam):    
            dtypedict = {}
            for i,j in zip(dfparam.columns, dfparam.dtypes):
                if "object" in str(j):
                    dtypedict.update({i: sa.types.NVARCHAR(length=2000)})

                if "datetime" in str(j):
                    dtypedict.update({i: sa.types.NVARCHAR(length=2000)})

                if "float" in str(j):
                    dtypedict.update({i: sa.types.NVARCHAR(length=2000)})

                if "int" in str(j):
                    dtypedict.update({i: sa.types.NVARCHAR(length=2000)})

            return dtypedict

        outputdict = sqlcol(merge_df)
        #print(outputdict)    

        #This temp table contains the individual dataframe data
        merge_df.head().to_sql('##tblUSBChargesTemp' + str(loopCounter), 
                            con=tempdb_engine, 
                            if_exists = 'append', 
                            index = False, 
                            dtype = outputdict)

        #Execute function to push to individual dataframe temp tables
        turbo_write("TEMPDB", merge_df, '##tblUSBChargesTemp' + str(loopCounter))

        #Add 1 to loopCounter
        loopCounter = loopCounter + 1

        #Add to Completed Files array 
        completedFiles.append(filelist)

        """        
        # How to execute a stored procedure on MSSQL Server, against connection
        connection = USCTTDEV.raw_connection()
        cursor = connection.cursor()
        cursor.execute("exec USCTTDEV.dbo.sp_CarrierInfo")
        cursor.close()
        connection.commit()
        """

if fileCount > 0:
    #Puts all MSSQL Temp tables onto single table (##tblUSBChargesTemp)
    loopMSSQL()

    #Clean all values on temp table, which are 0, 0.0, nan
    cleanMSSQL()

    #Run Stored Procedure to append new lanes, and update existing ones
    sp_MSSQL()

    #Rename Files once process is complete
    renameFiles()

else:
    print("No files to process.")

# Disconnect from production MSSQL Server, and drop connection
USCTTDEVConn.invalidate()
USCTTDEV.dispose()