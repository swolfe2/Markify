"""
This process was created by Steve Wolfe - Data Visualization CoE

Ensure that you have successfully pip installed requirements.txt!

Required packages needed to work:
https://pypi.org/project/pandas/ - version 1.4.3
https://pypi.org/project/playwright/ - version 1.24.1
-Ensure browsers are installed https://playwright.dev/python/docs/cli#install-browsers
https://pypi.org/project/pywin32/ - version 304
https://pypi.org/project/turbodbc/ - version 4.5.5

Process was developed using Python Version 3.10.5

Last update: 9/9/2022

Process steps overview:
1. Open new Chrome browser window with Playwright library
2. Log into Tableau Customer Portal
3. Select "All Licenses Report"
4. Scrape table in Pandas dataframe
5. Push dataframe to MSSQL server
6. Execute MSSQL stored procedure

"""

import sys
from datetime import datetime

import pandas as pd
from playwright.sync_api import sync_playwright

import mssql_database  # module in folder
from config import CRED_PW, CRED_UN, DB_NAME, MSSQL_SERVER  # module in folder
from send_email import send_email  # module in folder


def main():
    """
    This is the main function which will simulate via
    browser automation what would be done manually
    """
    url = "https://customer-portal.tableau.com/s/my-keys"

    # Disable mode runs due to the Playwright browser needing to always be visible
    # Defaults to produciton runs
    # mode = "Production"
    # Comment out below for production
    # mode = "Testing"

    def select_all_licenses_report(page, div, selector):
        """
        Check to make sure that the All Licenses Report is selected
        If it is not selected still after changing, go through
        process again until it is selected.

        If it is still not selected after a certain number of loops,
        send error email to people and break process.
        """
        # Set variables
        required_value = "All Licenses Report"

        # Initialize variables
        current_value = ""
        counter_value = 0
        max_loops = 5

        # Keep attempting to make sure it is the correct option
        while current_value != required_value:
            current_value = page.locator(selector).evaluate(
                "sel => sel.options[sel.options.selectedIndex].textContent"
            )
            if counter_value <= max_loops:
                if current_value != required_value:
                    counter_value += 1
                    page.locator(selector).select_option(label=required_value)
                    page.wait_for_selector(div)
            else:
                # If still not selected and > max_loops, send email and quit
                send_email(
                    "Could not select the All Licenses Report",
                    "Steve.Wolfe@kcc.com",
                    "",
                    "select_all_licenses_report",
                )
                page.close()
                sys.exit()

    def scrape_table(page):
        """
        Press the Export Data button and copy values to memory
        Use pandas read_clipboard by tab deliminated
        Check dataframe length values
        """
        global DF_LICENSES
        df_rows, df_columns = 0, 0
        counter_value = 0
        max_loops = 3
        while df_rows < 100 or df_columns < 10:
            # page.reload()
            page.wait_for_selector("div.dt-buttons")
            page.locator('"Export Data"').click()
            page.wait_for_selector("div.dt-button-collection")
            page.locator('"Copy"').click()

            print("Data table copy attempt " + str(counter_value + 1))
            DF_LICENSES = pd.read_clipboard(sep="\\t+")
            DF_LICENSES.fillna("", inplace=True)
            df_rows, df_columns = DF_LICENSES.shape
            counter_value += 1
            if counter_value == max_loops:
                # If still not selected and > max_loops, send email and quit
                send_email(
                    "Could not copy to dataframe",
                    "Steve.Wolfe@kcc.com",
                    "",
                    "scrape_table",
                )
                page.close()
                sys.exit()

        print("Dataframe rows/columns: " + str(df_rows) + "/" + str(df_columns))
        print(DF_LICENSES)

        print("Closing Chrome browser window")
        page.close()

    def scrape_table_paginate(page):

        """
        Press the Export Data button and copy values to memory
        Use pandas read_clipboard by tab deliminated
        Check dataframe length values
        """
        licenses = []
        global DF_LICENSES_DOS
        df_rows, df_columns = 0, 0
        counter_value = 0
        max_loops = 3

        selector = "name=tbl_Customer_Asset__c_length"
        page.wait_for_selector(selector)

        current_value = page.locator(selector).evaluate(
            "sel => sel.options[sel.options.selectedIndex].textContent"
        )
        required_value = "500"
        while current_value != required_value:
            page.locator(selector).select_option(label=required_value)
            page.wait_for_selector("div.tbl_Customer_Asset__c_paginate")

        while df_rows < 100 or df_columns < 10:
            page.reload()
            page.wait_for_selector("div.dt-buttons")
            page.locator('"Export Data"').click()
            page.wait_for_selector("div.dt-button-collection")
            page.locator('"Copy"').click()

            print("Data table copy attempt " + str(counter_value + 1))
            DF_LICENSES_DOS = pd.read_clipboard(sep="\\t+")
            DF_LICENSES_DOS.fillna("", inplace=True)
            df_rows, df_columns = DF_LICENSES_DOS.shape
            counter_value += 1
            if counter_value == max_loops:
                # If still not selected and > max_loops, send email and quit
                send_email(
                    "Could not copy to dataframe",
                    "Steve.Wolfe@kcc.com",
                    "",
                    "scrape_table",
                )
                page.close()
                sys.exit()

        print("Dataframe rows/columns: " + str(df_rows) + "/" + str(df_columns))

        print("Closing Chrome browser window")
        page.close()

        return licenses

    def push_to_mssql(df, conn):

        temp_table = "##tblTableauLicensesTemp"

        # Get dataframe size
        count_row, count_col = (
            df.shape[0],
            df.shape[1],
        )  # gives number of row/column count

        # Get Start Time
        start_time = datetime.now()

        # Fill all NA values with something
        for col in df:
            # get dtype for column
            d_type = df[col].dtype
            # check if it is a number
            if d_type == int or d_type == float:
                df[col].fillna(0, inplace=True)
            else:
                df[col].fillna("", inplace=True)

        print("Creating temp table")

        # Create dictionary of columns and data types
        outputdict = mssql_database.sqlcol(df)

        # Clean dataframe values up
        mssql_database.clean_dataframe(df)

        # Create a temp table, and push values to it from dataframe
        mssql_database.create_temp_table(df, conn, temp_table, outputdict)

        # Clean the temp table by values
        mssql_database.clean_temp_table(df, conn, temp_table)

        # Execute Stored Procedure
        mssql_database.run_stored_procedure(conn, "dbo.sp_TableauPortalAutomation")

        # Get End Time
        end_time = datetime.now()
        total_seconds = (end_time - start_time).total_seconds()
        # stop = (time.time() - start).total_seconds()
        return print(
            " Rows:"
            + str(count_row)
            + " Columns: "
            + str(count_col)
            + " Total Seconds: "
            + str(total_seconds)
        )

    with sync_playwright() as p:

        # initiate new browser session
        # if mode == "Production":
        #    browser = p.chromium.launch()
        # else:
        #    browser = p.chromium.launch(headless=False, slow_mo=200)

        # Launch visible browser
        browser = p.chromium.launch(headless=False, slow_mo=200)

        print("Opening Chome browser window")
        page = browser.new_page()
        page.goto(url)

        # Wait until Submit button is visible on page,
        # enter details, and press Submit button
        print("Logging into Tableau Customer Portal")
        page.wait_for_selector("id=signInButton")
        page.fill("input#email", CRED_UN)
        page.fill("input#password", CRED_PW)
        page.click("button[id=signInButton]")

        # Browser automation variables, things which must be found
        selector = "select.slds-select"
        div = "div.dt-buttons"

        page.wait_for_selector(div)
        page.wait_for_selector(selector)

        # Get current selector value, and ensure it's changed correctly
        try:
            print("Selecting 'All Licenses Report'")
            select_all_licenses_report(page, div, selector)
        except Exception as e_m:
            send_email(
                str(e_m), "steve.wolfe@kcc.com", "", "select_all_licenses_report"
            )
            page.close()
            sys.exit()

        # Scrape the all license table
        try:
            print("Attempting to copy data table to memory")
            scrape_table(page)
        except Exception as e_m:
            send_email(str(e_m), "steve.wolfe@kcc.com", "", "scrape_table")
            page.close()
            sys.exit()

        # # Scrape the all license table
        # try:
        #     print("Attempting to copy data table to memory")
        #     scrape_table_paginate(page)
        # except Exception as e_m:
        #     send_email(str(e_m), "steve.wolfe@kcc.com", "", "scrape_table")
        #     page.close()
        #     sys.exit()

        # Connect to MSSQL
        conn = mssql_database.connect_to_database()

        # push to MSSQL
        push_to_mssql(DF_LICENSES, conn)

        print("Process Complete!")


if __name__ == "__main__":
    main()
