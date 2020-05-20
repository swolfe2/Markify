"""
Code written by Steve Wolfe
steve_wolfe@whirlpool.com
Taken from Google's Python Quickstart Sheets Documentation
"""
from __future__ import print_function
import httplib2
import oauth2client
import os
import googleapiclient
import openpyxl
import pandas
import pyodbc
import datetime

from googleapiclient import discovery
from oauth2client import client
from oauth2client import tools
from oauth2client.file import Storage
from openpyxl import Workbook
from pandas import DataFrame, ExcelWriter


""" This is the code to get raw data from a specific Google Sheet"""
try:
    import argparse
    flags = argparse.ArgumentParser(parents=[tools.argparser]).parse_args()
except ImportError:
    flags = None

# If modifying these scopes, delete your previously saved credentials
# at ~/.credentials/sheets.googleapis.com-python-quickstart.json
SCOPES = 'https://www.googleapis.com/auth/spreadsheets'
CLIENT_SECRET_FILE = 'client_secret_noemail.json'
APPLICATION_NAME = 'Google Sheets API Python'

# Prints getting credentials
print("Getting Google Sheets Credentials")


def get_credentials():
    """Gets valid user credentials from storage.

    If nothing has been stored, or if the stored credentials are invalid,
    the OAuth2 flow is completed to obtain the new credentials.

    Returns:
        Credentials, the obtained credential.
    """
    home_dir = os.path.expanduser('~')
    credential_dir = os.path.join(home_dir, '.credentials')
    if not os.path.exists(credential_dir):
        os.makedirs(credential_dir)
    credential_path = os.path.join(credential_dir,
                                   'sheets.googleapis.com-python-quickstart.json')

    store = Storage(credential_path)
    credentials = store.get()
    if not credentials or credentials.invalid:
        flow = client.flow_from_clientsecrets(CLIENT_SECRET_FILE, SCOPES)
        flow.user_agent = APPLICATION_NAME
        if flags:
            credentials = tools.run_flow(flow, store, flags)
        else:  # Needed only for compatibility with Python 2.6
            credentials = tools.run_flow(flow, store)
        print('Storing credentials to ' + credential_path)
    return credentials


"""Shows basic usage of the Sheets API.

Creates a Sheets API service object and prints the names and majors of
students in a sample spreadsheet:
https://docs.google.com/spreadsheets/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms/edit
"""

# Getting Credentials to log into Google Sheets
credentials = get_credentials()
http = credentials.authorize(httplib2.Http())
discoveryUrl = ('https://sheets.googleapis.com/$discovery/rest?version=v4')
service = discovery.build(
    'sheets', 'v4', http=http, discoveryServiceUrl=discoveryUrl)

# Spreadsheet ID
spreadsheetId = '1N5aBWa9pSvEgO9rNrHHmPSWIptR8leg3xozE0aLiGzI'

# Data range to create dataframe, and create raw file document
getDataRangeName = 'ExportInitial!A:D'
result = service.spreadsheets().values().get(
    spreadsheetId=spreadsheetId, range=getDataRangeName).execute()
values = result.get('values', [])

# Export to main folder, and overwrite
df = DataFrame(data=values)
df.to_excel('\\\\10.29.7.46\\c$\\Users\\wolfes\\Desktop\\Innowera Files - DO NOT DELETE\\Order Redate\\OrderRedateRaw.xlsx',
            header=False, index=False)

# Export to Archive Folder
currentDateTime = str(datetime.datetime.now().strftime('%Y.%m.%d.%H.%M.%S'))
df = DataFrame(data=values)
dfPathName = ""
#df.to_excel('\\\\10.29.7.46\\c$\\Users\\wolfes\\Desktop\\Innowera Files - DO NOT DELETE\\Order Redate\\Google Sheet Archive\\Google Sheet - '+currentDateTime+'.xlsx',
#            header=False, index=False)

# Prints Excel Success
print("Excel files created successfully")

# Google Sheet tab range to clear/reappend
SQLRangeName = 'ExportInitial!A2:D'

# TODO: Add desired entries to the request body if needed
clear_values_request_body = {}

# Building Service to Clear Google Sheet
request = service.spreadsheets().values().clear(spreadsheetId=spreadsheetId,
                                                range=SQLRangeName, body=clear_values_request_body)
response = request.execute()

# Prints response that Google Sheet has been cleared
responseText = '\n'.join(
    [str(response), 'The Google Sheet has been cleared!'])
print(responseText)

"""
#Execute SQL Statement, create table, and append back to Google Sheet
# SQL Server Connection
server = '158.52.179.7'
database = 'Telephony'
username = 'tcsodbc'
password = 'tcsodbc'
cnxn = pyodbc.connect('Driver={ODBC Driver 13 for SQL Server};SERVER=' +
                      server+';DATABASE='+database+';UID='+username+';PWD='+password)

# Sample SQL Query to get Data
sql = 'select * from tblInnoweraModelHomeDesignCenter ORDER BY [ID]'
cursor = cnxn.cursor()
cursor.execute(sql)
list(cursor.fetchall())

# Pandas reading values from SQL query, and building table
sqlData = pandas.read_sql_query(sql, cnxn)

# Pandas building dataframe, and exporting .xlsx copy of table
df = DataFrame(data=sqlData)

# Google Sheets API can't handle date/time. Below converts certain headers to formatted text strings.
df['Date'] = df['Date'].dt.strftime('%m/%d/%Y')
df['DateTime'] = df['DateTime'].dt.strftime('%m/%d/%Y %H:%M:%S')
df['RDD'] = df['RDD'].dt.strftime('%m/%d/%Y')
df['DateTimeErrorTable'] = df['DateTimeErrorTable'].dt.strftime(
    '%m/%d/%Y %H:%M:%S')
df['DateTimeSuccessTable'] = df['DateTimeSuccessTable'].dt.strftime(
    '%m/%d/%Y %H:%M:%S')
df['WorkedOn'] = df['WorkedOn'].dt.strftime('%m/%d/%Y %H:%M:%S')
df['EmailSentOn'] = df['EmailSentOn'].dt.strftime('%m/%d/%Y %H:%M:%S')

df.to_excel('\\\\10.29.7.46\\c$\\Users\\wolfes\\Desktop\\Innowera Files - DO NOT DELETE\\OMAR - Model Home\\tblInnoweraModelHomeDesignCenter.xlsx',
            header=True, index=False)
dfHeaders = df.columns.values.tolist()
dfHeadersArray = [dfHeaders]
dfDataClean = df.replace('NaT', '', regex=True)
dfData = dfDataClean.values.tolist()


#Writing to Google Sheet Range
# Prints response that data has been acquired
print("SQL Data acquired. Starting append to Google Sheets.")
# print(dfHeaders)
# print(dfData)

# How the input data should be interpreted.
value_input_option = 'USER_ENTERED'  # TODO: Update placeholder value.

# How the input data should be inserted.
insert_data_option = 'OVERWRITE'  # TODO: Update placeholder value.

value_range_body = {
    "majorDimension": "ROWS",
    "values":
    dfHeadersArray + dfData
}

request = service.spreadsheets().values().append(spreadsheetId=spreadsheetId, range=SQLRangeName,
                                                 valueInputOption=value_input_option, insertDataOption=insert_data_option, body=value_range_body)
response = request.execute()
"""
# Prints completion
print("Doc Cancel Script Completed!")
