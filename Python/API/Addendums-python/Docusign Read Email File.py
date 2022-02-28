import pandas as pd

# Get Docusign Emails from Sharepoint file
def get_sharepoint_emails():
    """This gets all Emails from central Sharepoint file"""
    sharepoint_file = "\\\\IN00AAP024\\Contract Data\\Production\\Automation\\Carrier Rate Change Import Process.xlsm"
    xl = pd.ExcelFile(sharepoint_file)
    df = xl.parse("Docusign Emails")
    print(df)
    global SHAREPOINT_EMAILS
    SHAREPOINT_EMAILS = df.fillna("")


get_sharepoint_emails()
