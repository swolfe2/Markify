from __future__ import print_function
import httplib2
import oauth2client
import os
import googleapiclient
import openpyxl
import pandas
import pyodbc

from apiclient import discovery
from oauth2client import client
from oauth2client import tools
from oauth2client.file import Storage
from googleapiclient.discovery import build
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


def main():
    """Shows basic usage of the Sheets API.

    Creates a Sheets API service object and prints the names and majors of
    students in a sample spreadsheet:
    https://docs.google.com/spreadsheets/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms/edit
    """
    credentials = get_credentials()
    http = credentials.authorize(httplib2.Http())
    discoveryUrl = ('https://sheets.googleapis.com/$discovery/rest?version=v4')
    service = discovery.build(
        'sheets', 'v4', credentials=credentials)

    spreadsheetId = '1ae3gZUqZSOeSj_ZumOIKHD1AaB2iVSgapi4YaXNHUew'
    rangeName = 'tblActiveEmployees!A:A'
    result = service.spreadsheets().values().get(
        spreadsheetId=spreadsheetId, range=rangeName).execute()
    values = result.get('values', [])
    if not values:
        print('No data found.')
    else:

        batch_clear_values_request_body = {
            # The ranges to clear, in A1 notation.
            'rangeName': [],  # TODO: Update placeholder value.

            # TODO: Add desired entries to the request body.
        }

        request = service.spreadsheets().values().batchClear(
            spreadsheetId=spreadsheetId, body=batch_clear_values_request_body)
        response = request.execute()

        # TODO: Change code below to process the `response` dict:
        pprint(response)

        # SQL Server Connection
        server = '158.52.179.7'
        database = 'Telephony'
        username = 'tcsodbc'
        password = 'tcsodbc'
        cnxn = pyodbc.connect('Driver={ODBC Driver 13 for SQL Server};SERVER=' +
                              server+';DATABASE='+database+';UID='+username+';PWD='+password)

        # Sample SQL Query
        sql = 'select * from tblActiveEmployees'

        # Pandas reading values from SQL query, and building table
        sqlData = pandas.read_sql_query(sql, cnxn)

        # Pandas building dataframe, and exporting .xlsx copy of table
        df = DataFrame(data=sqlData)
        df.to_excel('tblActiveEmployees.xlsx',
                    header=True, index=False)


if __name__ == '__main__':
    main()
