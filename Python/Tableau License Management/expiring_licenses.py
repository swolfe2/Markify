import datetime
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
        "SELECT * FROM TableauLicenses.dbo.v_ExpiringLicenses WHERE EmailSentOn IS NULL",
    )

    # Get current python file name, for MSSQL appends
    current_filename = Path(__file__).name

    # Loop though list, and send email from variable values
    if len(data_dict) > 0:
        print(
            "Starting to loop through "
            + str(len(data_dict))
            + " Tableau license keys that are expiring in the current + 2 calendar months."
        )

        today = datetime.date.today()
        friday = today + (datetime.timedelta((11 - today.weekday()) % 14))

        # Get specific fields from the data dictionary of the index
        for index in range(len(data_dict)):

            key_name = data_dict[index]["KeyName"]
            period_end = str(data_dict[index]["PeriodEnd"])
            assigned_user = data_dict[index]["UserName"]
            assigned_email = data_dict[index]["AssignedEmail"].lower()
            last_registered_user_name = data_dict[index]["LastRegisteredUserName"]
            registered_email = data_dict[index]["RegisteredEmail"].lower()
            last_installed = str(data_dict[index]["LastInstalled"])
            days_remaining = str(data_dict[index]["DaysRemaining"])

            if data_dict[index]["AssignedManagerEmail"] == None:
                assigned_email_manager = ""
            else:
                assigned_email_manager = data_dict[index][
                    "AssignedManagerEmail"
                ].lower()

            to = assigned_email
            cc = assigned_email_manager

            # Calculate what the original Friday date would have been from where the email was previously sent
            previously_sent = data_dict[index]["EmailSentOn"]

            if previously_sent != None:
                previous_friday = previously_sent + (
                    datetime.timedelta((11 - today.weekday()) % 14)
                )

            html_header = """
                <!DOCTYPE html> 
                <html>
                <head>
                <style>
                #tableau_licenses {font-family: Arial, Helvetica, sans-serif;border-collapse: collapse;width: 70%;}
                #tableau_licenses td, #tableau_licenses th {border: 1px solid #ddd;padding: 5px;}
                #tableau_licenses tr:nth-child(even){background-color: #D0D7F9;}
                #tableau_licenses tr:hover {background-color: #0F2C87; color: white;}
                #tableau_licenses th {padding-top: 12px;padding-bottom: 12px;text-align: left;background-color: #04AA6D;color: white;}
                </style>
                </head>
                """

            html_greeting = "<p>Hello,</p>"

            html_body = f"""
                {html_header}
                <body>
                {html_greeting}
                <p>During a current audit on Tableau licenses, it was discovered that the assigned Tableau license below will expire in {days_remaining} days.</p>
                <table id='tableau_licenses'>
                <colgroup><col span='1' style='width: 40%;'><col span='1' style='width: 60%;'></colgroup>
                <tr><td><b>Tableau License</b></td><td>{key_name}</td></tr>
                <tr><td><b>License Expiry Date</b></td><td>{period_end}</td></tr>
                <tr><td><b>Assigned To</b></td><td>{assigned_user}</td></tr>
                <tr><td><b>Assigned To Email</b></td><td>{assigned_email}</td></tr>
                <tr><td><b>Last Registered On</b></td><td>{last_installed}</td></tr>
                </table>
                <p>In order to resolve this issue, <span style="background-color: #FFFF00"><b>please reply all to this email by EOB {friday}</b></span> 
                if you intend to renew this license at $840 annually, which will be charged to your cost center. If no response is received by {friday},
                 then the license will be unassigned and will not be renewed once expired.</p> 
                <p>Note: If you are in a region / work area that purchases licenses outside of the standard process, you may ignore this message.</p>
                <p>If you have any questions, also feel free to reply.</p>
                <p>Thank you</p>
                </body>
                </html>
                """

            # Standard subject for outbound emails and MSSQL reporting
            subject = "Tableau License: Key Expiration"

            # Set BCC for emails, uncomment to/cc for testing
            # to = "steve.wolfe@kcc.com"
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

            # Set SQL query for appending
            query = f"""
            INSERT INTO TableauLicenses.dbo.tblSentEmails(SentOn, EmailType, LicenseNumber, ToAddresses, CCaddresses, BCCAddresses, Subject, Message)
            SELECT GETDATE(),'{current_filename}','{key_name}','{to}','{cc}','{bcc}','{subject}','{html_body}'
            """

            # Push SQL query to TableauLicenses.dbo.tblSentEmails
            mssql_database.execute_query(conn, query)


if __name__ == "__main__":
    main()
