"""
This process was created by Steve Wolfe - Data Visualization CoE

Required packages needed to work:
https://pypi.org/project/bs4/
https://pypi.org/project/playwright/
https://pypi.org/project/pywin32/

Last update: 8/12/2022

"""

import os
import sys
from datetime import datetime

import win32com.client as win32
from bs4 import BeautifulSoup
from playwright.sync_api import sync_playwright

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
                    "All Licenses Report",
                )
                sys.exit()

    with sync_playwright() as p:

        # initiate new browser session
        if mode == "Production":
            browser = p.chromium.launch()
        else:
            browser = p.chromium.launch(headless=False, slow_mo=50)
        page = browser.new_page()
        page.goto(url)

        # Wait until Submit button is visible on page,
        # enter details, and press Submit button
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
        select_all_licenses_report(page, div, selector)

        print("We in here!")


if __name__ == "__main__":
    main()
