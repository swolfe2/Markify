import os
from win32com import client
import win32com.client as win32

# Main global variables used in the rest of the file
def globalVariables():
    # Get Username
    global userid
    userid = os.getlogin()

    # Set starting directory
    global pendingDir
    pendingDir = (
        "C:\\Users\\"
        + userid
        + "\\Kimberly-Clark\\Rates and Pricing - Agreements\\Addendums-Pending"
    )

    # Set finished directory
    global sentDir
    sentDir = (
        "C:\\Users\\"
        + userid
        + "\\Kimberly-Clark\\Rates and Pricing - Agreements\\Addendums-Sent"
    )

    # Set the run type of the script
    global processType
    processType = "Production"
    # Comment out below for production
    processType = "Testing"


# Convert all of the Addendums-Pending .xlsx files to .pdf
def convertXLSXtoPDF():
    # Loop through all addendum files, and convert them to .pdf
    for filename in os.listdir(pendingDir):
        if filename.endswith(".xlsx"):
            filepath = pendingDir + "\\" + filename
            pdfpath = filepath.replace(".xlsx", ".pdf")
            if not os.path.isfile(pdfpath):

                # Open Microsoft Excel
                excel = client.Dispatch("Excel.Application")

                # Read Excel File
                sheets = excel.Workbooks.Open(filepath)
                work_sheets = sheets.Worksheets[0]

                # Convert into PDF File
                work_sheets.ExportAsFixedFormat(0, pdfpath)

                # Close workbook once complete
                sheets.Close(False)

    global fileCount
    fileCount = 0
    for filename in os.listdir(pendingDir):
        fileCount += 1


globalVariables()
convertXLSXtoPDF()
