import datetime

import pandas as pd

import utils.mssql_database as mssql_database  # module in utils folder
from utils.send_email import send_email  # module in utils folder


def main():

    # Connect to MSSQL server
    conn = mssql_database.connect_to_database()

    # Create a list of columns and data for iterating
    data_dict = mssql_database.execute_query_to_dictonary(
        conn, "SELECT * FROM TableauLicenses.dbo.v_AssignedRegisteredEmailMismatch"
    )

    # Loop though list, and send email from variable values
    if len(data_dict) > 0:
        print("Starting to loop through " + str(len(data_dict)) + " mismatches.")

        today = datetime.date.today()
        friday = today + (datetime.timedelta((11 - today.weekday()) % 14))

        # Get specific fields from the data dictionary of the index
        for index in range(len(data_dict)):

            KeyName = data_dict[index]["KeyName"]
            PeriodEnd = str(data_dict[index]["PeriodEnd"])
            AssignedUser = data_dict[index]["UserName"]
            AssignedEmail = data_dict[index]["AssignedEmail"]
            LastRegisteredUserName = data_dict[index]["LastRegisteredUserName"]
            RegisteredEmail = data_dict[index]["RegisteredEmail"]
            LastInstalled = str(data_dict[index]["LastInstalled"])

            RegisteredEmailManager = data_dict[index]["RegisteredEmailManager"]
            AssignedEmailManager = data_dict[index]["AssignedEmailManager"]

            to = [RegisteredEmail, AssignedEmail]
            cc = [RegisteredEmailManager, AssignedEmailManager]

            html_body = (
                """
                <!DOCTYPE html> 
                <html>
                <head>
                <style>
                #tableau_licenses {font-family: Arial, Helvetica, sans-serif;border-collapse: collapse;width: 60%;}
                #tableau_licenses td, #tableau_licenses th {border: 1px solid #ddd;padding: 5px;}
                #tableau_licenses tr:nth-child(even){background-color: #D0D7F9;}
                #tableau_licenses tr:hover {background-color: #0F2C87; color: white;}
                #tableau_licenses th {padding-top: 12px;padding-bottom: 12px;text-align: left;background-color: #04AA6D;color: white;}
                </style>
                </head>
                <body>
                <p>Hello,</p>
                <p>During a current audit on Tableau licenses, we have discovered a discrepancy between a user the license is assigned to and who last registered the license.</p>
                <table id="tableau_licenses">
                <colgroup><col span="1" style="width: 35%;"><col span="1" style="width: 65%;"></colgroup>
                <tr><td><b>Tableau License</b></td><td>"""
                + KeyName
                + """</td></tr>
                <tr><td><b>License Expiry Date</b></td><td>"""
                + PeriodEnd
                + """</td></tr>
                <tr><td><b>Assigned To</b></td><td>"""
                + AssignedUser
                + """</td></tr>
                <tr><td><b>Assigned To Email</b></td><td>"""
                + AssignedEmail
                + """</td></tr>
                <tr><td><b>Registered By</b></td><td>"""
                + LastRegisteredUserName
                + """</td></tr>
                <tr><td><b>Registered Email</b></td><td>"""
                + RegisteredEmail
                + """</td></tr>
                <tr><td><b>Last Registered On</b></td><td>"""
                + LastInstalled
                + """</td></tr>
                </table>
                <p>In order to resolve the discrepancy, <span style="background-color: #FFFF00"><b>please reply all to this email by EOB """
                + str(friday)
                + """</b></span> 
                with which user is intended for this Tableau License. If no response is received by """
                + str(friday)
                + """, then the license will be removed for any current users. </p> 
                <p>Also, for any license moves in the future, please ensure that you are following the license process 
                available on <a href="https://kimberlyclark.sharepoint.com/sites/c141/Pages/RequestTableauLicense.aspx">Tableau Server</a>.</p>
                <p>If you have any questions, also feel free to reply.</p>
                <p>Thank you</p>
                </body>
                </html>
                """
            )

            # print(html_body)

            send_email(
                subject="Tableau License: Assigned to and Registered Mismatch",
                to="swolfe2@gmail.com",
                cc="",
                html_body=html_body,
            )


if __name__ == "__main__":
    main()
