"""
This process was created by Steve Wolfe - Data Visualization CoE

Required packages needed to work:
https://pypi.org/project/pandas/ - version 1.4.3
https://pypi.org/project/playwright/ - version 1.24.1
https://pypi.org/project/pywin32/ - version 304
https://pypi.org/project/turbodbc/ - version 4.5.5

Process was developed using Python Version 3.10.5

Last update: 8/16/2022

TODO: Scrape table into pandas Dataframe
TODO: Write subprocess to append dataframe to MSSQL
TODO: Write subprocess to execute stored procedure

Process steps overview:
1. Open new Chrome browser window with Playwright library
2. Log into Tableau Customer Portal
3. Select "All Licenses Report"
4. Scrape table in Pandas dataframe
5. Push dataframe to MSSQL server
6. Execute MSSQL stored procedure

"""

import os
import sys
from datetime import datetime
from urllib.parse import quote_plus

import pandas as pd
import sqlalchemy
import win32com.client as win32
from playwright.sync_api import sync_playwright
from turbodbc import connect, make_options

from config import CRED_PW, CRED_UN


def main():
    """
    This is the main function which will simulate via
    browser automation what would be done manually
    """
    url = "https://customer-portal.tableau.com/s/my-keys"

    # Defaults to produciton runs
    mode = "Production"
    # Comment out below for production
    mode = "Testing"

    def send_email(error_message, to_address, cc_address, process_step):
        """
        This subprocess will allow an email message to be sent,
        which will typically only be used for when something goes
        wrong in the process. It will always originate from the same source.

        Server name: smtp.office365.com
        Port: 587
        Encryption method: STARTTLS
        """

        def kill_outlook():
            """
            This subprocess will kill the Outlook applicaiton if currently open
            """
            win_management = win32.GetObject("winmgmts:")
            for process in win_management.ExecQuery(
                'select * from Win32_Process where Name="Outlook.exe"'
            ):
                # os.system("taskkill /pid /F /IM " + str(p.ProcessId))
                os.kill(process.ProcessId, 9)

        # Kill Outlook if it is currently open
        kill_outlook()

        # HTML email details
        html_body = (
            """
        Hello,
        <p>During today's run of the Python automation for Tableau Licesnses, the automation
        failed at the <span style="background-color: #FFFF00"><b>"""
            + process_step
            + """</b></span> step at """
            + datetime.now().strftime("%m/%d/%Y %H:%M")
            + """.</p>
        <p>Please perform a manual review, and correct any issues that may have occurred.</p>
        <p>Thank you,</p>"""
        )

        outlook_mail_item = 0x0
        obj = win32.Dispatch("Outlook.Application")
        new_mail = obj.CreateItem(outlook_mail_item)
        new_mail.Subject = "Tableau License Automation Failure: " + error_message
        new_mail.HTMLBody = html_body
        new_mail.To = to_address
        new_mail.Cc = cc_address
        new_mail.Send()

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
            page.reload()
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

    def scrape_table_paginate(page) -> list:
        """Scrape the page for table data.

        Args:
            current_page: page object Playwright

        Returns:
            list of dictionaries containing license data
        """

        licenses = []

        contents = page.content()
        soup = BeautifulSoup(contents, "html.parser")

        # site uses DataTables, with scrolling, default behavior creates two tables for header and body, here we find
        # TDs since each has the same id as contained in the corresponding th
        s_table = soup.find(
            "table", {"id": re.compile("^tbl_Customer_Asset__c")}, "tbody"
        )
        s_rows = s_table.find_all("tr")

        # process each row extracting all tds
        for s_row in s_rows:
            row_items = s_row.find_all("td")
            if row_items:

                # add item if id is present for dictionary, 'error' should not appear in results
                row_data = {
                    item.get("id", "error"): item.text
                    for item in row_items
                    if item.has_attr("id")
                }
                licenses.append(row_data)

        return licenses

    def push_to_mssql(df):
        def clean_dataframe(df):
            # Change entire dataframe to object, because holy shit... why are the data types so damn difficult!
            lst = list(df)
            df[lst] = df[lst].astype(str)
            return df

        def sqlcol(df):
            dtypedict = {}
            for i, j in zip(df.columns, df.dtypes):
                if "object" in str(j):
                    dtypedict.update({i: "NVARCHAR(2000)"})

                elif "datetime" in str(j):
                    dtypedict.update({i: sqlalchemy.types.NVARCHAR(length=2000)})

                elif "float" in str(j):
                    dtypedict.update({i: sqlalchemy.types.NVARCHAR(length=2000)})

                elif "int" in str(j):
                    dtypedict.update({i: sqlalchemy.types.NVARCHAR(length=2000)})

            return dtypedict

        def create_temp_table(df, conn, db, temp_table, outputdict):
            print("Creating temp table")
            # This temp table contains the individual dataframe data
            print(df.head())
            # Ensure there is no temp table already on the temp database
            with conn.cursor() as cursor:
                cursor.execute(f"DROP TABLE IF EXISTS {temp_table}")
                conn.commit()

            # Create temp table, with default datatypes and standard headers
            temp_sql_create = "CREATE TABLE " + temp_table + "("
            for key, value in outputdict.items():
                temp_sql_create += "[" + key + "] " + value + ", "
            temp_sql_create += ")"
            with conn.cursor() as cursor:
                cursor.execute(temp_sql_create)
                conn.commit()

            # get the array of values
            values = [df[col].values for col in df.columns]

            # preparing columns
            columns = "(["
            columns += "], [".join(df.columns)
            columns += "])"

            # preparing value place holders
            val_place_holder = ["?" for col in df.columns]
            sql_val = "("
            sql_val += ", ".join(val_place_holder)
            sql_val += ")"

            # writing sql query for turbodbc
            sql = f"""
            INSERT INTO {db}.{temp_table} {columns}
            VALUES {sql_val}
            """

            # inserts data, for real
            with conn.cursor() as cursor:
                try:
                    cursor.executemanycolumns(sql, values)
                    conn.commit()
                except Exception as e:
                    conn.rollback()
                    print("Failed to upload: " + str(e))

        server = "USTCAS24"
        db = "TableauLicenses"
        temp_table = "##tblTableauLicensesTemp"
        temp_db_conn = connect(
            driver="ODBC Driver 17 for SQL Server",
            server=server,
            database=db,
            trusted_connection="YES",
            encrypt="YES",
            trustservercertificate="YES",
        )

        db_conn = connect(
            driver="ODBC Driver 17 for SQL Server",
            server=server,
            database=db,
            trusted_connection="YES",
            encrypt="YES",
            trustservercertificate="YES",
        )

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
        outputdict = sqlcol(df)

        # Clean dataframe values up
        clean_dataframe(df)

        # Create a temp table, and push values to it from dataframe
        create_temp_table(df, temp_db_conn, db, temp_table, outputdict)

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
        if mode == "Production":
            browser = p.chromium.launch()
        else:
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

            # Scrape the all license table
        try:
            print("Attempting to copy data table to memory")
            scrape_table_paginate(page)
        except Exception as e_m:
            send_email(str(e_m), "steve.wolfe@kcc.com", "", "scrape_table")
            page.close()
            sys.exit()

        # push to MSSQL
        push_to_mssql(DF_LICENSES)

        print("We in here!")


if __name__ == "__main__":
    main()
