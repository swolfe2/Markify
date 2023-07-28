import csv
import datetime
import os
from pathlib import Path

import utils.mssql_database as mssql_database  # module in utils folder
from utils.send_email import send_email  # module in utils folder

import pandas as pd


def main():
    # Connect to MSSQL server
    conn = mssql_database.connect_to_database()

    # Create a list of columns and data for iterating
    data_dict = mssql_database.execute_query_to_dictonary(
        conn,
        "SELECT * FROM TableauLicenses.dbo.v_AssignedRegisteredEmailMismatch WHERE EmailSentOn IS NULL",
    )

    # Path to file
    filepath = r"C:\Users\U15405\OneDrive - Kimberly-Clark\Desktop\July 2023 License Renewal Datasets"

    """ 
    SELECT
    q1.*,
    q2.KeyName AS NewKeyName,
    q2.ProductName AS NewProductName,
    q2.PeriodEnd AS NewPeriodEnd,
    NULL AS Completed
    FROM (
    SELECT *, 
        ROW_NUMBER() OVER (ORDER BY PeriodEnd ASC, KeyName ASC) row_num
    FROM (
        SELECT DISTINCT tp.KeyName, tp.PeriodEnd, tp.ProductName, tp.UserName, ad.FirstName, tp.AssignedEmail, ad.ManagerName, ad.ManagerEmail
        FROM TableauLicenses.dbo.tblTableauPortal tp
        LEFT JOIN TableauLicenses.dbo.tblActiveDirectory ad 
        ON ad.Email = tp.AssignedEmail
        WHERE tp.KeyStatus = 'Assigned'
        AND YEAR(tp.PeriodEnd) = YEAR(GETDATE())
        AND MONTH(tp.PeriodEnd) <= 10
    ) q1
    ) q1
    LEFT JOIN (
    SELECT *,
        ROW_NUMBER() OVER (ORDER BY LastInstalled DESC, KeyName ASC) row_num
    FROM (
        SELECT DISTINCT tp.KeyName, tp.ProductName, tp.PeriodEnd, tp.LastInstalled
        FROM TableauLicenses.dbo.tblTableauPortal tp
        WHERE tp.PeriodEnd = '7/31/2024'  
        AND tp.ProductName = 'Desktop Professional'
        AND tp.KeyStatus = 'Unassigned'
        AND (tp.RegisteredEmail LIKE '%kcc.com' OR tp.RegisteredEmail IS NULL)
    ) q2
    ) q2
    ON q1.row_num = q2.row_num
    """
    filename = "License Reassignments - July 2023 Expirations.csv"

    data_dict = {}
    with open(os.path.join(filepath, filename)) as f:
        reader = csv.reader(f)
        headers = next(reader)

        for i, row in enumerate(reader):
            data_dict[i] = {header: value for header, value in zip(headers, row)}

    # Get current python file name, for MSSQL appends
    current_filename = Path(__file__).name

    # Loop though list, and send email from variable values
    if len(data_dict) > 0:
        print("Starting to loop through " + str(len(data_dict)) + " licenses.")

        today = datetime.date.today()

        # Get specific fields from the data dictionary of the index
        for index in range(len(data_dict)):
            key_name = data_dict[index]["KeyName"]
            period_end = str(data_dict[index]["PeriodEnd"])
            product_name = str(data_dict[index]["ProductName"])
            assigned_user = str(data_dict[index]["UserName"])
            first_name = str(data_dict[index]["FirstName"])
            assigned_email = str(data_dict[index]["AssignedEmail"].lower())
            new_key_name = str(data_dict[index]["NewKeyName"])
            new_product_name = str(data_dict[index]["NewProductName"])
            new_period_end = str(data_dict[index]["NewPeriodEnd"])

            if data_dict[index]["ManagerEmail"] == None:
                assigned_email_manager = ""
            else:
                assigned_email_manager = data_dict[index]["ManagerEmail"].lower()

            to = assigned_email

            if assigned_email_manager != "":
                cc = assigned_email_manager
            else:
                cc = ""

            html_header = """
                <!DOCTYPE html> 
                <html>
                <head>
                <style>
                #tableau_licenses {font-family: Arial, Helvetica, sans-serif;border-collapse: collapse; width: 55%;}
                #tableau_licenses td, #tableau_licenses th {border: 1px solid #ddd;padding: 5px;}
                #tableau_licenses tr:nth-child(even){background-color: #D0D7F9;}
                #tableau_licenses tr:hover {background-color: #0F2C87; color: white;}
                #tableau_licenses th {padding-top: 12px;padding-bottom: 12px;text-align: left;background-color: #04AA6D;color: white;}
                </style>
                </head>
                """

            html_greeting = f"<p>Hello {first_name},</p>"

            html_body = f"""
                {html_header}
                <body>
                {html_greeting}
                <p>The annual Tableau license renewal process has been completed. From this process, 
                 the Tableau license you are currently using is being deprecated and you will need to register a new license number for Tableau Desktop.</p>
                <p>Please see the table below for your updated details.</p>
                <table id='tableau_licenses'>
                <colgroup><col span='1' style='width: 40%;'><col span='1' style='width: 60%;'></colgroup>
                <tr><td><b>Current Tableau License</b></td><td>{key_name}</td></tr>
                <tr><td><b>Current Tableau License Type</b></td><td>{product_name}</td></tr>
                <tr><td><b>Current License Expiry Date</b></td><td>{period_end}</td></tr>
                <tr><td><b>Assigned To</b></td><td>{assigned_user}</td></tr>
                <tr><td><b>Assigned To Email</b></td><td>{assigned_email}</td></tr>
                <tr><td><b>New Tableau License</b></td><td><span style="background-color: #FFFF00"><b>{new_key_name}</b></span></td></tr>
                <tr><td><b>New Tableau License Type</b></td><td>{new_product_name}</td></tr>
                <tr><td><b>New License Expiry Date</b></td><td>{new_period_end}</td></tr>

                </table>
                <p>You will need to first follow the instructions from Tableau to <a href="https://help.tableau.com/current/desktopdeploy/en-us/desktop_deploy_move_or_deactivate.htm">deactivate your current license</a>.</p>
                <p>Once you have deactivated your current license, you will need to follow the instructions from Tableau to <a href="https://help.tableau.com/current/desktopdeploy/en-us/desktop_deploy_activate_license.htm">register your new Tableau license key </a> <span style="background-color: #FFFF00"><b>{new_key_name}</b></span>.</p>
                                
                <p>For any license moves in the future, or if you no longer wish to have a Tableau license, please ensure that you are following the license process
                 available on <a href="https://kimberlyclark.sharepoint.com/sites/c141/Pages/RequestTableauLicense.aspx">Tableau Central</a>.</p>
                <p>If you have any questions, also feel free to reply.</p>
                <p>Thank you!</p>
                </body>
                </html>
                """

            # Standard subject for outbound emails and MSSQL reporting
            subject = "Tableau License: New License Key Assigned"

            # Set BCC for emails, uncomment to/cc for testing
            # to = "swolfe2@gmail.com"
            # cc = "steve.wolfe@kcc.com"
            bcc = "steve.wolfe@kcc.com"

            # Send formatted email to all recipients
            send_email(
                subject=subject,
                to=to,
                cc=cc,
                bcc=bcc,
                html_body=html_body,
            )

            # In case the assigned user does not have a manager, set the CC to just 'UNKNOWN'
            if cc is None:
                cc = "UNKNOWN"

            # Set SQL query for appending
            query = f"""
            INSERT INTO TableauLicenses.dbo.tblSentEmails(SentOn, EmailType, LicenseNumber, ToAddresses, CCaddresses, BCCAddresses, Subject, Message)
            SELECT GETDATE(),'{current_filename}','{key_name}','{to}','{cc}','{bcc}','{subject}','{html_body}'
            """

            # Push SQL query to TableauLicenses.dbo.tblSentEmails
            mssql_database.execute_query(conn, query)


if __name__ == "__main__":
    main()
