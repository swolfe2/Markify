"""
Code written by Steve Wolfe
steve_wolfe@whirlpool.com
Taken from Google's Python Quickstart Sheets Documentation
"""
from __future__ import print_function
print("Importing Libraries")
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

print("Getting Google API Client/JSON Information")
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

print("Getting Google Sheet Credentials")


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


def todaysDate():
    """Shows basic usage of the Sheets API.

    Creates a Sheets API service object and prints the names and majors of
    students in a sample spreadsheet:
    https://docs.google.com/spreadsheets/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms/edit
    """
    credentials = get_credentials()
    http = credentials.authorize(httplib2.Http())
    discoveryUrl = ('https://sheets.googleapis.com/$discovery/rest?version=v4')
    service = googleapiclient.discovery.build(
        'sheets', 'v4', http=http, discoveryServiceUrl=discoveryUrl)

    print("Connecting to Google Sheet")

    # Google Sheet Url Link and Range name. Can use tab names to get full page.
    spreadsheetId = '1mJcQT054t63sNWiI2hv2fnV3WTXJg00PRow81WJGNNo'
    rangeName = 'Raw Data!K3'

    # TODO: Add desired entries to the request body if needed
    clear_values_request_body = {}

    # Building Service to Clear Google Sheet
    request = service.spreadsheets().values().clear(spreadsheetId=spreadsheetId,
                                                    range=rangeName, body=clear_values_request_body)
    response = request.execute()

    # Prints response that Google Sheet has been cleared
    responseText = '\n'.join(
        [str(response), 'The Google Sheet has been cleared!'])
    print(responseText)

    print("Getting Current Timestamp")

    # Pandas reading values from SQL query
    now = (datetime.datetime.now().strftime('%m/%d/%Y %H:%M:%S'))
    print (now)
    values = [
        [
            now
        ],
    ]

    print("Updating Google Sheet Timestamp")

    # How the input data should be interpreted.
    value_input_option = 'USER_ENTERED'  # TODO: Update placeholder value.

    # How the input data should be inserted.
    insert_data_option = 'OVERWRITE'  # TODO: Update placeholder value.

    value_range_body = {
        "values": values,
        "majorDimension": 'COLUMNS',
    }

    request = service.spreadsheets().values().append(spreadsheetId=spreadsheetId, range=rangeName,
                                                     valueInputOption=value_input_option, insertDataOption=insert_data_option, body=value_range_body)
    response = request.execute()
    
if __name__ == '__main__':
    todaysDate()