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
1) Get specific file from Andrew Krafthefer's File Directory
2) Copy file to area on SAS server, if it detects there's been a change in the previous 24 hours
3) Do some data frame manipulations to prep data for load to MSSQL server
4) Load to MSSQL server temp table
5) Execute MSSQL stored procedure
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

# Open connection to MSSQL Server
tempdb_params = quote_plus( "Driver={ODBC Driver 17 for SQL Server};"
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

# Connect to main MSSQL Database
USCTTDEV_params = quote_plus("Driver={ODBC Driver 17 for SQL Server};"
"Server=USTCAS98.KCC.COM;Database=USCTTDEV;"
"Trusted_Connection=YES;Encrypt=YES;"
"TrustServerCertificate=YES")
USCTTDEV_conn_string = f"mssql+pyodbc:///?odbc_connect={USCTTDEV_params}"
USCTTDEV = sa.create_engine(USCTTDEV_conn_string)
USCTTDEVConn = USCTTDEV.connect()

#Runs stored procedure on MSSQL server to append new data to main table, and update existing rows
def sp_MSSQL_LaneForecastAccuracy():
    sqlSPString = ("EXEC USCTTDEV.dbo.sp_LaneForecastAccuracy")
    # cleans the previous head insert
    with tembdb_connection.cursor() as cursor:
        cursor.execute(str(sqlSPString))
        tembdb_connection.commit()

#Set starting directory
startDir = r'\\USTCA097\Stage\Database Files\Lane Forecast Analysis'

#Set directory which has files
fileDir = r'\\kcfiles\share\Corporate\DISTRIBUTION\Dist Analysis\Projects\2019 Projects\Outbound Lane tool\v2021'

#Loop through all files, and if the forecast file that was modified in the last 24 hours, copy to the Files to Process folder;
for filename in os.listdir(fileDir):
    now = datetime.today()
    if filename.endswith('.xlsx') and "LANE FCST ACTUAL" in filename.upper():
        filepath = fileDir +'\\'+ filename
        modDate = datetime.fromtimestamp(os.path.getmtime(filepath))
        hoursOld = (now - modDate).total_seconds() / 3600
        if hoursOld < 24 and os.path.getsize(filepath) > 0:
                destfilepath = startDir +'\\'+ filename
                copyfile(filepath, destfilepath)
        else: 
            sp_MSSQL_LaneForecastAccuracy()
            exit()            

#Reset file name now that we're going on
filename = "Lane Fcst Actual.xlsx"

#Update the single temp table value to null where they are certain values
def cleanMSSQL():
    for col in forecast.columns:

        sqlCleanString = ("UPDATE ##tblForecastTemp SET [" + col + "] = NULL WHERE [" + col + "] IN ('0', '0.0', 'nan')")
        # cleans the previous head insert
        with tembdb_connection.cursor() as cursor:
            cursor.execute(str(sqlCleanString))
            tembdb_connection.commit()

#Add missing columns so that stored procedure doesn't mess up
def addMSSQLColumns():    
    newcols = """
                IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'Comments'		    AND TABLE_NAME LIKE '##tblForecastTemp') ALTER TABLE ##tblForecastTemp ADD [Comments]		    VARCHAR(250) NULL	
                IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'ProcessedOn'		AND TABLE_NAME LIKE '##tblForecastTemp') ALTER TABLE ##tblForecastTemp ADD [ProcessedOn]	    DATETIME NULL
                IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'UpdatedOn'			AND TABLE_NAME LIKE '##tblForecastTemp') ALTER TABLE ##tblForecastTemp ADD [UpdatedOn]		    DATETIME NULL
                IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'AddedOn'			AND TABLE_NAME LIKE '##tblForecastTemp') ALTER TABLE ##tblForecastTemp ADD [AddedOn]			DATETIME NULL
                IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'FRST_SHPG_LOC_CD'	AND TABLE_NAME LIKE '##tblForecastTemp') ALTER TABLE ##tblForecastTemp ADD [FRST_SHPG_LOC_CD]	NVARCHAR(30) NULL
                IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'FRST_PSTL_CD'		AND TABLE_NAME LIKE '##tblForecastTemp') ALTER TABLE ##tblForecastTemp ADD [FRST_PSTL_CD]		NVARCHAR(30) NULL
                IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'LAST_SHPG_LOC_CD'	AND TABLE_NAME LIKE '##tblForecastTemp') ALTER TABLE ##tblForecastTemp ADD [LAST_SHPG_LOC_CD]	NVARCHAR(30) NULL
                IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'Lane'				AND TABLE_NAME LIKE '##tblForecastTemp') ALTER TABLE ##tblForecastTemp ADD [Lane]				NVARCHAR(30) NULL
                """
    with tembdb_connection.cursor() as cursor:
            cursor.execute(str(newcols))
            tembdb_connection.commit() 

#Runs stored procedure on MSSQL server to append new data to main table, and update existing rows
def sp_MSSQL():
    sqlSPString = ("EXEC USCTTDEV.dbo.sp_LaneForecast")
    # cleans the previous head insert
    with tembdb_connection.cursor() as cursor:
        cursor.execute(str(sqlSPString))
        tembdb_connection.commit()

#set forecast data variable
forecast = ""
forecast = pd.read_excel(startDir + r"\Lane FCST Actual.xlsx", sheet_name="FCST Output")

#remove rows where ALL are blank
forecast = forecast.dropna(how='all')

#make the first row of values the new column headers, with spaces removed
forecast.columns = forecast.iloc[0].str.replace(' ','')

#make the new dataframe
forecast = forecast[1:]

#Set final data types for each header in dataframe
forecast = forecast.astype({
                            "SnapshotWeek":'object',
                            "SendingWeek":'object',
                            "OriginPlant":'object',
                            "OriginCampus":'object',
                            "OriginZone":'object',
                            "DestinationPlant":'object',
                            "DestinationCampus":'object',
                            "DestinationZone":'object',
                            "DestinationPostalCode":'object',
                            "FCSTIntCust4":'object',
                            "FCSTIntCust4TXT":'object',
                            "FCSTShiptoCust":'object',
                            "FCSTShiptoCustTXT":'object',
                            "Type":'object',
                            "ShipCondition":'object',
                            "FCSTTL":'object',
                            "WeeklyAward":'object'
                            })

#Convert datetime to date
for col in forecast:
    colname = forecast[col].name.lower()
    if 'snapshotweek' in colname or 'sendingweek' in colname:
        forecast[col] = pd.to_datetime(forecast[col]).dt.date

#Change entire dataframe to object, because holy shit... why are the data types so damn difficult!
lst = list(forecast)
forecast[lst] = forecast[lst].astype(str)
forecast = forecast.replace(np.nan, '', regex=True)

#Fill all NA values with something
for col in forecast:
    #get dtype for column
    dt = forecast[col].dtype 
    #check if it is a number
    if dt == int or dt == float:
        forecast[col].fillna(0, inplace=True)
    else:
        forecast[col].fillna("", inplace=True)

#Get dataframe size
count_row = forecast.shape[0]  # gives number of row count
count_col = forecast.shape[1]  # gives number of col count

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

outputdict = sqlcol(forecast)

#This temp table contains the individual dataframe data
forecast.head().to_sql('##tblForecastTemp', 
                    con=tempdb_engine, 
                    if_exists = 'append', 
                    index = False, 
                    dtype = outputdict)

#Execute function to push to individual dataframe temp table
turbo_write("TEMPDB", forecast, '##tblForecastTemp')

#Clean all values on temp table, which are 0, 0.0, nan
cleanMSSQL()

#Add missing columns because stored procedure is acting the fool
addMSSQLColumns()

#Run Stored Procedure to append new lanes, and update existing ones
sp_MSSQL()

#Run stored procedure for Lane Forecast Accuracy
sp_MSSQL_LaneForecastAccuracy()

# Disconnect from production MSSQL Server, and drop connection
USCTTDEVConn.invalidate()
USCTTDEV.dispose()
