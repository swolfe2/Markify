from __future__ import print_function
import httplib2
import oauth2client
import os
import googleapiclient
import openpyxl
import pandas
import pyodbc
import pygsheets

from pprint import pprint
from apiclient import discovery
from oauth2client import client
from oauth2client import tools
from oauth2client.file import Storage
from googleapiclient.discovery import build
from openpyxl import Workbook
from pandas import DataFrame, ExcelWriter
from df2gspread import gspread2df as g2d

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


credentials = get_credentials()

service = discovery.build('sheets', 'v4', credentials=credentials)

# The ID of the spreadsheet to update.
spreadsheet_id = '1ae3gZUqZSOeSj_ZumOIKHD1AaB2iVSgapi4YaXNHUew'

# The A1 notation of the values to clear.
range = 'tblActiveEmployees'

# TODO: Add desired entries to the request body if needed
clear_values_request_body = {}

request = service.spreadsheets().values().clear(spreadsheetId=spreadsheet_id,
                                                range=range, body=clear_values_request_body)
response = request.execute()

# Prints response that Google Sheet has been cleared
responseText = '\n'.join([str(response), 'The Google Sheet has been cleared!'])
print(responseText)

"""
This is the code used to get data from MSSQL. It's tied directly to the server
and can perform any type of SQL query for any of the tables
"""

# SQL Server Connection
server = '158.52.179.7'
database = 'Telephony'
username = 'tcsodbc'
password = 'tcsodbc'
cnxn = pyodbc.connect('Driver={ODBC Driver 13 for SQL Server};SERVER=' +
                      server+';DATABASE='+database+';UID='+username+';PWD='+password)

# Sample SQL Query
sql = 'select * from tblActiveEmployees'

"""
# Pandas reading values from SQL query, and building table
sqlData = pandas.read_sql_query(sql, cnxn)

# Pandas building dataframe, and exporting .xlsx copy of table to parent director
df = DataFrame(data=sqlData)
df.to_excel('tblActiveEmployees.xlsx',
            header=True, index=False)
"""