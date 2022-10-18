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

Last update: 10/12/2022

Process steps overview:
1. Open new Chrome browser window with Playwright library
2. Log into Tableau Customer Portal
3. Select "All Licenses Report"
4. Scrape table in Pandas dataframe
5. Push dataframe to MSSQL server
6. Execute MSSQL stored procedure

"""

import re
import sys
from datetime import datetime

import pandas as pd
from playwright.sync_api import sync_playwright

import utils.mssql_database as mssql_database  # module in utils folder
from utils.config import CRED_PW, CRED_UN
from utils.send_email import send_error_email  # module in utils folder


# Get the email address, check to ensure it's formatted correctly, and return to variable
def get_email_address():
    """
    This module will get the user's input for an email address, then do a regex comparison to only accept email addresses in the following domains:
    kcc.com
    kmb1.com
    kcsoftex.com
    y-k.co.kr

    Module will continue until valid input is received.
    """

    while True:
        user_email = (
            input("What is the user's Kimberly-Clark email address?")
            .replace(" ", "")
            .lower()
        )

        if not re.match(
            r"\b[A-Za-z0-9._%+-]+@((kcc|kmb1|kcsoftex)\.com|y-k\.co\.kr)\b", user_email
        ):
            print(
                f"{user_email} is not a valid email. Please check your entry and try again."
            )
        else:
            break

    return user_email


def get_license_number():
    """
    This module will get the user's input for an license, then do a regex comparison to only accept correct formatted strings.

    Module will continue until valid input is received.
    """

    while True:
        license_number = (
            input("What license number are you wanting to assign?")
            .replace(" ", "")
            .upper()
        )
        if not re.match(
            r"[A-Za-z0-9]{4}-[A-Za-z0-9]{4}-[A-Za-z0-9]{4}-[A-Za-z0-9]{4}-[A-Za-z0-9]{4}",
            license_number,
        ):
            print(
                f"{license_number} is not in the correct format. Please check your entry."
            )
        else:
            break

    return license_number


def tableau_portal(email_address):
    def deactivate_current_license(page, email_address):
        print(f"Searching for currently assigned licenses for {email_address}")

        page.locator('text=Search: >> input[type="search"]').fill(email_address)
        page.locator('text=Search: >> input[type="search"]').press("Enter")

        # Locate elements, this locator points to a list.
        rows = page.locator('table[id="tbl_Customer_Asset__c"]')

        # Pattern 3: resolve locator to elements on page and map them to their text content.
        # Note: the code inside evaluateAll runs in page, you can call any DOM apis there.
        texts = rows.evaluate_all("list => list.map(element => element.textContent)")
        row_count = texts.__len__()

    url = "https://customer-portal.tableau.com/s/my-keys"

    with sync_playwright() as p:
        # Launch visible browser
        browser = p.chromium.launch(headless=False, slow_mo=200)

        print("Opening Chrome browser window")
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

        # Attempt to deactivate license for current user
        deactivate_current_license(page, email_address)


def main(USER_EMAIL, LICENSE_NUMBER):

    print(f"Validated User Email Input: {USER_EMAIL}")
    print(f"Validated License Number Input: {LICENSE_NUMBER}")

    tableau_portal(USER_EMAIL)


if __name__ == "__main__":

    global USER_EMAIL
    global LICENSE_NUMBER

    USER_EMAIL = ""
    LICENSE_NUMBER = ""

    # Any text in this variable will cause a debug run
    run_type = "Test"

    if run_type != "":
        USER_EMAIL = "steve.wolfe@kcc.com"
        LICENSE_NUMBER = "TC8O-D27D-6DA0-37DD-76E9"
    else:
        USER_EMAIL = get_email_address()
        LICENSE_NUMBER = get_license_number()

    main(USER_EMAIL, LICENSE_NUMBER)
