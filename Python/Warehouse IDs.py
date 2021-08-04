"""
Code below to create Excel requires xlsxwriter
python -m pip install xrd xlsxwriter
# Example of writting via SQL to DB
# If executing this on KC Linux that is AD integrated refer to the
# following Yammer post on SQL driver setup.
# https://www.yammer.com/kcc.com/#/Threads/show?threadId=912791555
Added the following paths to my environment variables:
r'C:/ProgramData/Anaconda3/
r'C:/ProgramData/Anaconda3/Library/bin
Also, be sure you've installed ALL packages below on the end computer!
turbodbc
https://turbodbc.readthedocs.io/en/latest/pages/getting_started.html#installation
What does this file do?
1) Get specific file from File Directory, quit process if file was last
modified more than 36 hours ago
2) Append records to temp table in MSSQL
3) Append new records to main MSSQL table
4) Update records on main MSSQL to match
"""

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

# Runs stored procedure on MSSQL server to append new data to main table
# and update existing rows


def sp_MSSQL_LaneForecastAccuracy():
    sqlSPString = "EXEC USCTTDEV.dbo.sp_LaneForecastAccuracy"
    # cleans the previous head insert
    with tembdb_connection.cursor() as cursor:
        cursor.execute(str(sqlSPString))
        tembdb_connection.commit()


# Set directory which has files
fileDir = r"\\USTCA097\Stage\Database Files\Warehouse IDs"
# Count number of files
fileCount = 0

# If the file was last modified more than 36 hours ago, then don't do anything
for filename in os.listdir(fileDir):
    now = datetime.today()
    if filename.endswith(".xlsx") and "WAREHOUSE IDS" in filename.upper():
        fileCount = 1
        filepath = fileDir + "\\" + filename
        modDate = datetime.fromtimestamp(os.path.getmtime(filepath))
        hoursOld = (now - modDate).total_seconds() / 3600
        if hoursOld > 36 and os.path.getsize(filepath) > 0:
            exit()
# Quit if there are no files to process
if fileCount != 1:
    exit()
# Reset file name now that we're going on
filename = "Warehouse IDs.xlsx"


# Update the single temp table value to null where they are certain values
def cleanMSSQL():
    for col in WarehouseIDs.columns:

        sqlCleanString = (
            "UPDATE ##tblWarehouseIDs SET [" + col + "] = NULL "
            "WHERE [" + col + "] IN ('0', '0.0', 'nan')"
        )
        # cleans the previous head insert
        with tembdb_connection.cursor() as cursor:
            cursor.execute(str(sqlCleanString))
            tembdb_connection.commit()


# Add missing columns so that stored procedure doesn't mess up
def addMSSQLColumns():
    newcols = """
                IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'UpdatedOn'	AND TABLE_NAME LIKE '##tblWarehouseIDs') ALTER TABLE ##tblWarehouseIDs ADD [UpdatedOn] DATETIME NOT NULL DEFAULT (GETDATE())
                IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'AddedOn'	AND TABLE_NAME LIKE '##tblWarehouseIDs') ALTER TABLE ##tblWarehouseIDs ADD [AddedOn]   DATETIME NOT NULL DEFAULT (GETDATE())
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
                FROM ##tblWarehouseIDs widt
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
                INNER JOIN ##tblWarehouseIDs widt ON widt.wh_id = wid.wh_id
                """
    with tembdb_connection.cursor() as cursor:
        cursor.execute(str(newcols))
        tembdb_connection.commit()


# set WarehouseIDs data variable
WarehouseIDs = ""
WarehouseIDs = pd.read_excel(fileDir + r"\Warehouse IDs.xlsx", sheet_name="Data")

# remove rows where ALL are blank
WarehouseIDs = WarehouseIDs.dropna(how="all")

# Change entire dataframe to object, because holy shit... why are the data types so damn difficult!
lst = list(WarehouseIDs)
WarehouseIDs[lst] = WarehouseIDs[lst].astype(str)
WarehouseIDs = WarehouseIDs.replace(np.nan, "", regex=True)

# Fill all NA values with something
for col in WarehouseIDs:
    # get dtype for column
    dt = WarehouseIDs[col].dtype
    # check if it is a number
    if dt == int or dt == float:
        WarehouseIDs[col].fillna(0, inplace=True)
    else:
        WarehouseIDs[col].fillna("", inplace=True)
# Make sure the dataframe looks right
print(WarehouseIDs.to_markdown())

# Get dataframe size
count_row = WarehouseIDs.shape[0]  # gives number of row count
count_col = WarehouseIDs.shape[1]  # gives number of col count

# Get Start Time
startTime = datetime.now()


# Function to append temp tables
def turbo_write(mydb, df, table):
    """Use turbodbc to insert data into sql."""

    # get the array of values
    values = [df[col].values for col in df.columns]

    # preparing columns
    colunas = "(["
    colunas += "], [".join(df.columns)
    colunas += "])"

    # preparing value place holders
    val_place_holder = ["?" for col in df.columns]
    sql_val = "("
    sql_val += ", ".join(val_place_holder)
    sql_val += ")"

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
            print("Failed to upload: " + str(e))
    # Get End Time
    endTime = datetime.now()
    totalSeconds = (endTime - startTime).total_seconds()
    # stop = (time.time() - start).total_seconds()
    return print(
        f"File "
        + filename
        + " Rows:"
        + str(count_row)
        + " Columns: "
        + str(count_col)
        + " Total Seconds: "
        + str(totalSeconds)
    )


def sqlcol(dfparam):
    dtypedict = {}
    for i, j in zip(dfparam.columns, dfparam.dtypes):
        if "object" in str(j):
            dtypedict.update({i: sa.types.NVARCHAR(length=2000)})
        if "datetime" in str(j):
            dtypedict.update({i: sa.types.NVARCHAR(length=2000)})
        if "float" in str(j):
            dtypedict.update({i: sa.types.NVARCHAR(length=2000)})
        if "int" in str(j):
            dtypedict.update({i: sa.types.NVARCHAR(length=2000)})
    return dtypedict


outputdict = sqlcol(WarehouseIDs)

# This temp table contains the individual dataframe data
WarehouseIDs.head().to_sql(
    "##tblWarehouseIDs",
    con=tempdb_engine,
    if_exists="append",
    index=False,
    dtype=outputdict,
)

# Execute function to push to individual dataframe temp table
turbo_write("TEMPDB", WarehouseIDs, "##tblWarehouseIDs")

# Clean all values on temp table, which are 0, 0.0, nan
cleanMSSQL()

# Add missing columns because stored procedure is acting the fool
addMSSQLColumns()

# Run Query to append new lanes
insertToMSSQL()

# Run Query to update existing lanes
updateMSSQL()

# Disconnect from production MSSQL Server, and drop connection
USCTTDEVConn.invalidate()
USCTTDEV.dispose()
