"""
Code below to create Excel requires xlsxwriter
python -m pip install xrd xlsxwriter
# Example of writting via SQL to DB
# If executing this on KC Linux that is AD integrated refer to the
# following Yammer post on SQL driver setup.
# https://www.yammer.com/kcc.com/#/Threads/show?threadId=912791555
Also, be sure you've installed ALL packages below on the end computer!
turbodbc
https://turbodbc.readthedocs.io/en/latest/pages/getting_started.html#installation
"""

import io
import os
import difflib
import sys
import pyperclip
import pandas as pd
import numpy as np
import sqlalchemy as sa
from tabulate import tabulate
from urllib.parse import quote_plus
from turbodbc import connect, make_options
from io import StringIO
from datetime import datetime
import time
from shutil import copyfile, move

# Open connection to MSSQL Server
tempdb_params = quote_plus(
    "Driver={ODBC Driver 17 for SQL Server};"
    "Server=USTCAS98.KCC.COM;Database=TEMPDB;"
    "Trusted_Connection=YES;Encrypt=YES;"
    "TrustServerCertificate=YES"
)
tempdb_conn_string = f"mssql+pyodbc:///?odbc_connect={tempdb_params}"
tempdb_engine = sa.create_engine(tempdb_conn_string, fast_executemany=True)

# Set turboodbc options
options = make_options(parameter_sets_to_buffer=1000)

tembdb_connection = connect(
    driver="ODBC Driver 17 for SQL Server",
    server="USTCAS98.KCC.COM",
    database="TEMPDB",
    trusted_connection="YES",
    encrypt="YES",
    trustservercertificate="YES",
)

# Connect to main MSSQL Database
USCTTDEV_params = quote_plus(
    "Driver={ODBC Driver 17 for SQL Server};"
    "Server=USTCAS98.KCC.COM;Database=USCTTDEV;"
    "Trusted_Connection=YES;Encrypt=YES;"
    "TrustServerCertificate=YES"
)
USCTTDEV_conn_string = f"mssql+pyodbc:///?odbc_connect={USCTTDEV_params}"
USCTTDEV = sa.create_engine(USCTTDEV_conn_string)
USCTTDEVConn = USCTTDEV.connect()

# Update the single temp table value to null where they are certain values
def cleanMSSQL():
    for col in DatabaseDSNs.columns:

        sqlCleanString = (
            "UPDATE ##tblDatabaseDSNs SET [" + col + "] = NULL "
            "WHERE [" + col + "] IN ('0', '0.0', 'nan')"
        )
        # cleans the previous head insert
        with tembdb_connection.cursor() as cursor:
            cursor.execute(str(sqlCleanString))
            tembdb_connection.commit()


# Add missing columns so that stored procedure doesn't mess up
def addMSSQLColumns():
    newcols = """
                IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'UpdatedOn'	AND TABLE_NAME LIKE '##tblDatabaseDSNs') ALTER TABLE ##tblDatabaseDSNs ADD [UpdatedOn] DATETIME NOT NULL DEFAULT (GETDATE())
                IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'AddedOn'	AND TABLE_NAME LIKE '##tblDatabaseDSNs') ALTER TABLE ##tblDatabaseDSNs ADD [AddedOn]   DATETIME NOT NULL DEFAULT (GETDATE())
                """
    with tembdb_connection.cursor() as cursor:
        cursor.execute(str(newcols))
        tembdb_connection.commit()


# Insert rows to MSSQL table
def insertToMSSQL():
    newcols = """
                INSERT INTO USCTTDEV.dbo.tblWarehouseID(WH_ID, WH_NAME, UpdatedOn, AddedOn)
                SELECT widt.WH_ID,
                widt.WH_NAME,
                widt.UpdatedOn,
                widt.AddedOn
                FROM ##tblDatabaseDSNs widt
                LEFT JOIN USCTTDEV.dbo.tblWarehouseID wid ON wid.WH_ID = widt.WH_ID
                WHERE wid.WH_ID IS NULL
                ORDER BY widt.WH_ID ASC
                """
    with tembdb_connection.cursor() as cursor:
        cursor.execute(str(newcols))
        tembdb_connection.commit()


# Update rows on the MSSQL table
def updateMSSQL():
    newcols = """
                UPDATE USCTTDEV.dbo.tblWarehouseID
                SET UpdatedOn = widt.UpdatedOn,
                wh_name = widt.wh_name
                FROM USCTTDEV.dbo.tblWarehouseID wid
                INNER JOIN ##tblDatabaseDSNs widt ON widt.wh_id = wid.wh_id
                """
    with tembdb_connection.cursor() as cursor:
        cursor.execute(str(newcols))
        tembdb_connection.commit()


# Update rows on the MSSQL table
def executeQuery(query):
    with tembdb_connection.cursor() as cursor:
        cursor.execute(str(query))
        tembdb_connection.commit()


# Excel file link
filename = r"\\USTCA097\Stage\Database Files\WMS\WMS DSN.xlsx"

# set DatabaseDSNs data variable
DatabaseDSNs = ""
DatabaseDSNs = pd.read_excel(filename, sheet_name="DSN")

# remove rows where ALL are blank
DatabaseDSNs = DatabaseDSNs.dropna(how="all")

# Change entire dataframe to object, because holy shit... why are the data types so damn difficult!
lst = list(DatabaseDSNs)
DatabaseDSNs[lst] = DatabaseDSNs[lst].astype(str)
DatabaseDSNs = DatabaseDSNs.replace(np.nan, "", regex=True)

# Start with a blank SQL value
sSql = ""

# Iterate over all available rows on the Excel file
for index, row in DatabaseDSNs.iterrows():
    dsn = row["SASDSN"]
    server = row["Server"]
    database = row["Default Database"]

    # Union all SQL statmeents together, except the first
    if sSql != "":
        sSql = sSql + " UNION ALL"

    # Fill in the variables with information from the Excel file
    sSql = (
        sSql
        + """
            SELECT * FROM OPENQUERY("""
        + server
        + """, 'select distinct car_move.car_move_id car_move_id,
            trlr.trlr_id,
            trlr.trlr_num,
            trlr.yard_loc,
            CONVERT(datetime, trlr.arrdte, 120) trlr_arrival_date,
            CONVERT(datetime, car_move.vc_sap_oub_cmpdte, 120) car_move_sap_complete_date,
            CONVERT(datetime, shipment.late_dlvdte, 120) target_ship_date,
            car_move.carcod,
            (select max(adrmst.adrnam)
            from """
        + database
        + """.dbo.ord ord2,
            """
        + database
        + """.dbo.shipment_line,
            """
        + database
        + """.dbo.shipment,
            """
        + database
        + """.dbo.stop,
            """
        + database
        + """.dbo.adrmst
            where stop.car_move_id = car_move.car_move_id
            and shipment_line.ordnum = ord2.ordnum
            and shipment_line.client_id = ord2.client_id
            and shipment_line.wh_id = ord2.wh_id
            and shipment_line.ship_id = shipment.ship_id
            and shipment.stop_id = stop.stop_id
            and stop.stop_seq = 1
            and adrmst.adr_id = stop.adr_id) stcust_addr_name
            from """
        + database
        + """.dbo.stop,
            """
        + database
        + """.dbo.car_move
            left outer
            join """
        + database
        + """.dbo.trlr
            on trlr.trlr_id = car_move.trlr_id
            left outer
            join """
        + database
        + """.dbo.locmst
            on locmst.wh_id = trlr.yard_loc_wh_id
            and locmst.stoloc = trlr.yard_loc
            left outer
            join """
        + database
        + """.dbo.wrkque
            on wrkque.refloc = trlr.trlr_num
            and wrkque.wrkref = trlr.carcod,
            """
        + database
        + """.dbo.shipment_line,
            """
        + database
        + """.dbo.shipment
            left outer
            join """
        + database
        + """.dbo.shp_dst_loc
            on shp_dst_loc.ship_id = shipment.ship_id
            and shp_dst_loc.wh_id = shipment.wh_id,
            """
        + database
        + """.dbo.ord
            left outer
            join """
        + database
        + """.dbo.adrmst
            on ord.bt_adr_id = adrmst.adr_id,
            """
        + database
        + """.dbo.ord_line,
            """
        + database
        + """.dbo.prtmst_view,
            """
        + database
        + """.dbo.prtftp
            left outer
            join """
        + database
        + """.dbo.prtftp_dtl pfd_cse
            on pfd_cse.prtnum = prtftp.prtnum
            and pfd_cse.wh_id = prtftp.wh_id
            and pfd_cse.ftpcod = prtftp.ftpcod
            and pfd_cse.uomcod = ''CS''
            left outer
            join """
        + database
        + """.dbo.prtftp_dtl pfd_lyr
            on pfd_lyr.prtnum = prtftp.prtnum
            and pfd_lyr.wh_id = prtftp.wh_id
            and pfd_lyr.ftpcod = prtftp.ftpcod
            and pfd_lyr.uomcod = ''LY''
            left outer
            join """
        + database
        + """.dbo.prtftp_dtl pfd_tld
            on pfd_tld.prtnum = prtftp.prtnum
            and pfd_tld.wh_id = prtftp.wh_id
            and pfd_tld.ftpcod = prtftp.ftpcod
            and pfd_tld.pal_flg = 1
            where shipment_line.ordnum = ord_line.ordnum
            and shipment_line.ordlin = ord_line.ordlin
            and shipment_line.ordsln = ord_line.ordsln
            and shipment_line.client_id = ord_line.client_id
            and shipment_line.wh_id = ord_line.wh_id
            and ord_line.ordnum = ord.ordnum
            and ord_line.wh_id = ord.wh_id
            and ord_line.client_id = ord.client_id
            and prtmst_view.prtnum = ord_line.prtnum
            and prtmst_view.wh_id = ord_line.wh_id
            and prtftp.prtnum = prtmst_view.prtnum
            and prtftp.wh_id = prtmst_view.wh_id_tmpl
            and prtftp.defftp_flg = 1
            and shipment.ship_id = shipment_line.ship_id
            and shipment.stop_id = stop.stop_id
            and stop.car_move_id = car_move.car_move_id
            and car_move.trans_mode=''T''
            and car_move.vc_equip=''LIVE''
            and shipment.late_dlvdte >= GETDATE()-90') data 
            """
    )

# Copy SQL to clipboard for testing
pyperclip.copy(sSql)

# Create Pandas Dataframe
# executeQuery(sSql)

df = pd.read_sql_query(sSql, tembdb_connection)
df2 = df.head(100)
print(tabulate(df2, headers="keys", tablefmt="psql"))
