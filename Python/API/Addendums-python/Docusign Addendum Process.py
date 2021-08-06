import os
import base64
import requests
import pandas as pd
import win32com.client as win32
import app.ds_config as config
import app.docusign.utils as utils
from docusign_esign import (
    ApiClient,
    EnvelopesApi,
    EnvelopeDefinition,
    Document,
    Signer,
    CarbonCopy,
    SignHere,
    Tabs,
    Recipients,
)
from shutil import copyfile, move
from win32com import client

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
        + "\\Kimberly-Clark\\Rates and Pricing - Agreements\\Addendums-Pending\\"
    )

    # Set finished directory
    global sentDir
    sentDir = (
        "C:\\Users\\"
        + userid
        + "\\Kimberly-Clark\\Rates and Pricing - Agreements\\Addendums-Sent\\"
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
            filepath = pendingDir + filename
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


# Get Docusign Emails from Sharpeoint file
def sharepointEmails():
    sharepointFile = r"\\kimberlyclark.sharepoint.com\Teams\A286\Rates\ContractsPricing\Shared Documents\Docusign Emails.xlsx"
    # sharepointFile = r"https://kimberlyclark.sharepoint.com/Teams/A286/Rates/ContractsPricing/Shared%20Documents/Docusign%20Emails.xlsx"
    xl = pd.ExcelFile(sharepointFile)
    global sharepointEmails
    df = xl.parse("Docusign Emails")
    sharepointEmails = df.fillna("")


# if there is no email for the carrier, send alert and skip
def missingEmail(carrier, filepath):
    outlook = win32.Dispatch("outlook.application")
    mail = outlook.CreateItem(0)
    mail.To = "Steve.Wolfe@kcc.com"
    mail.SendUsingAccount = "strategyandanalysis.ctt@kcc.com"
    mail.SentOnBehalfOfName = "strategyandanalysis.ctt@kcc.com"
    mail.Subject = "Rate Loading: Missing Carrier Email"
    # mail.Body="Message body"
    mail.HTMLBody = (
        """Hello, <br><br>
    No carrier email address was found for carrier """
        + carrier
        + """, and no Docusign envelope could be created.
    Please add this carrier asap to the <a href="https://kimberlyclark.sharepoint.com/:x:/t/A286/Rates/ContractsPricing/EU5lSxD-mFBOvOW1VMrZIKUBxN5LvEjksFCudHnUcy0qiQ?e=I5H6ZK">Docusign Emails File</a>. <br><br>
    The attached files have been removed from the <a href="https://kimberlyclark.sharepoint.com/Sites/A120/ratesandpricing/Document/Addendums-Pending/">Addendums-Pending Folder on Sharepoint</a>. <br><br>
    <b><span style="background-color: #FFFF00">This addendum will need to be manually processed through Docusign.</span></b><br><br>
    Thanks, <br><br>
    -Strategy & Analysis
    """
    )

    # To attach a file to the email (optional):
    pdfFile = filepath
    xlsxFile = filepath.replace(".pdf", ".xlsx")
    mail.Attachments.Add(pdfFile)
    mail.Attachments.Add(xlsxFile)

    mail.Send()

    # Attempt to delete the .pdf file
    try:
        os.remove(pdfFile)
    except OSError:
        pass

    # Attempt to delete the .xlsx file
    try:
        os.remove(xlsxFile)
    except OSError:
        pass


def killOutlook():
    # Close Outlook object
    WMI = win32.GetObject("winmgmts:")
    for p in WMI.ExecQuery('select * from Win32_Process where Name="Outlook.exe"'):
        # os.system("taskkill /pid /F /IM " + str(p.ProcessId))
        os.kill(p.ProcessId, 9)


def addendumsNotMoved():
    # If there are still addendums in the folder, send an email to NARate._Trans@kcc.com that something's wrong.
    # All files should have been moved to the carrier's Addendums-Sent folder
    print(
        "Looking through Addendums-Pending folder. There should be NO files in here at all. If there are any, going to send an email."
    )

    # Intialize counter
    i = 0
    for filename in os.listdir(pendingDir):
        if filename.endswith(".pdf"):
            i += 1

    if i >= 1:
        if i == 1:
            fileString = "file"
            itthey = "it has"
        else:
            fileString = "files"
            itthey = "they have"

        print("Leftover addendums found. Sending alert email.")
        outlook = win32.Dispatch("outlook.application")
        mail = outlook.CreateItem(0)
        mail.To = "Steve.Wolfe@kcc.com"
        mail.SendUsingAccount = "strategyandanalysis.ctt@kcc.com"
        mail.SentOnBehalfOfName = "strategyandanalysis.ctt@kcc.com"
        mail.Subject = "Rate Loading: Docusign Addendums Still Pending"
        # mail.Body="Message body"
        mail.HTMLBody = (
            """Hello, <br><br>
        An error appears to have happend during the Docusign Addendum process. <br><br>
        There are still """
            + str(i)
            + """ .pdf files in the <a href="https://kimberlyclark.sharepoint.com/Sites/A120/ratesandpricing/Document/Addendums-Pending/">Addendums-Pending Folder on Sharepoint</a>. <br><br>
        <b><span style="background-color: #FFFF00">Please ensure that these files have NOT been processed through Docusign ASAP!</span></b><br><br>
        You can find the carrier's current email listing by going to the <a href="https://kimberlyclark.sharepoint.com/:x:/t/A286/Rates/ContractsPricing/EU5lSxD-mFBOvOW1VMrZIKUBxN5LvEjksFCudHnUcy0qiQ?e=I5H6ZK">Docusign Emails File on Sharepoint</a>. <br><br> 
        If """
            + itthey
            + """ already been processed through Docusign, please move the .pdf copy of the """
            + fileString
            + """ to the carriers's individual folder in the <a href="https://kimberlyclark.sharepoint.com/Sites/A120/ratesandpricing/Document/Addendums-Sent/">Addendums-Sent Folder on Sharepoint</a>,
        and delete the .xlsx """
            + fileString
            + """.<br><br>
        Thanks, <br><br>
        -Strategy & Analysis
        """
        )

        mail.Send()


# Process each .pdf file
def processAddendums():
    def makeAndSendEnvelope(args):
        """
        Creates envelope
        Document 1: PDF Version of Addendum that was previously made
        DocuSign will convert all of the documents to the PDF format.
        """

        # Create the envelope definition
        env = EnvelopeDefinition(
            email_subject="Please Docusign: Addendum "
            + args["carrier"]
            + "-"
            + args["scac"]
            + "("
            + args["addendumNumber"]
            + ")"
            + "--Created "
            + args["addendumDate"]
        )

        # If testing, update the email subject
        if processType == "Testing":
            env.email_subject = "TESTING! - " + env.email_subject

        # doc1_b64 = base64.b64encode(bytes(cls.create_document1(args), "utf-8")).decode(
        #    "ascii"
        # )

        # Read .pdf file from local directory, will raise an exception if the file is not available!
        with open(args["filepath"], "rb") as file:
            pdfFileBytes = file.read()
        doc1_b64 = base64.b64encode(pdfFileBytes).decode("ascii")

        # Create the document models
        pdfFile = Document(  # create the DocuSign document object
            document_base64=doc1_b64,
            name="Addendum " + args["addendumNumber"] + " Signable",
            # can be different from actual file name
            file_extension="pdf",  # many different document types are accepted
            document_id="1",  # a label used to reference the doc
            apply_anchor_tabs=True,
        )

        """
        Cannot attach just an Excel file. Docusign converts the Excel file to .pdf format automatically.

        with open(args["filepath"], "rb") as file:
            xlsxFileBytes = file.read()
        xlsx_b64 = base64.b64encode(xlsxFileBytes).decode("ascii")

        xlsxFile = Document(  # create the DocuSign document object
            document_base64=xlsx_b64,
            name="Addendum " + args["addendumNumber"] + " Excel Copy",
            # can be different from actual file name
            file_extension="xlsx",  # many different document types are accepted
            document_id="2",  # a label used to reference the doc
        )
        """

        # The order in the docs array determines the order in the envelope
        env.documents = [pdfFile]

        # Create signature array, and always add the first carrier
        signatureTabs = []
        kcSignature = SignHere(
            anchor_string="/*Kimberly-ClarkSignature*/",
            anchor_units="pixels",
            anchor_y_offset="-7",
            anchor_x_offset="0",
            name="KCSignature",
            tab_label="KCSignature",
            page_number=1,
            document_id=1,
            recipient_id="6",
        )
        signatureTabs.append(kcSignature)

        carrierSignature1 = SignHere(
            anchor_string="/*CarrierSignature1*/",
            anchor_units="pixels",
            anchor_y_offset="-7",
            anchor_x_offset="0",
            name="CarrierSignature1",
            tab_label="CarrierSignature1",
            page_number=1,
            document_id=1,
            recipient_id="4",
        )
        signatureTabs.append(carrierSignature1)

        # Will only add this to the signature tabs if the carrier has a second signer
        carrierSignature2 = SignHere(
            anchor_string="/*CarrierSignature2*/",
            anchor_units="pixels",
            anchor_y_offset="-7",
            anchor_x_offset="0",
            name="CarrierSignature2",
            tab_label="CarrierSignature2",
            page_number=1,
            document_id=1,
            recipient_id="5",
        )
        if args["docusignEmail2"] != "":
            signatureTabs.append(carrierSignature2)

        """
        Here's where the routing logic starts

        routingOrder (lower means earlier) determines the order of deliveries
        to the recipients. Parallel routing order is supported by using the
        same integer as the order for two or more recipients.
        """
        if processType == "Testing":

            carrierSignerTest1 = Signer(
                email="StrategyAndAnalysis.ctt@kcc.com",
                name=args["carrier"] + " Representative 1",
                recipient_id="4",
                routing_order="2",
                tabs=Tabs(sign_here_tabs=[carrierSignature1]),
            )

            carrierSignerTest2 = Signer(
                email="swolfe2@gmail.com",
                name=args["carrier"] + " Representative 2",
                recipient_id="5",
                routing_order="2",
                tabs=Tabs(sign_here_tabs=[carrierSignature2]),
            )

            kcSignerTest = Signer(
                email="Steve.Wolfe@kcc.com",
                name="K-C Representative",
                recipient_id="6",
                routing_order="1",
                tabs=Tabs(sign_here_tabs=[kcSignature]),
            )

            ccTest = CarbonCopy(
                email="Regina.S.Black@kcc.com",
                name="Regina Black -Copy",
                recipient_id="10",
                routing_order="3",
            )
        else:
            # Mimic Template Order
            # CC Carrier Manager in group 1
            ccCM = CarbonCopy(
                email="schrysan@kcc.com",
                name="Stelios Chrysandreas",
                recipient_id="1",
                routing_order="1",
            )

            # CC ConData in group 2
            ccCondata = CarbonCopy(
                email="opsmail@condata.com",
                name="ConData",
                recipient_id="2",
                routing_order="2",
            )

            # CC US Bank in group 2
            ccUSBank = CarbonCopy(
                email="usbank.pricing@usbank.com",
                name="US Bank - Copy",
                recipient_id="3",
                routing_order="2",
            )

            # Add the K-C Representative for Signature in group 4
            kcSigner = Signer(
                email="Purvi.Naik@kcc.com",
                name="K-C Representative",
                recipient_id="4",
                routing_order="3",
                tabs=Tabs(sign_here_tabs=[kcSignature]),
            )

            # Add the Carrier Representative for Signature in group 3
            carrierSigner1 = Signer(
                email=args["docusignEmail1"],
                name=args["carrier"] + " Representative",
                recipient_id="5",
                routing_order="4",
                tabs=Tabs(sign_here_tabs=[carrierSignature1]),
            )

            # Add the Carrier Representative for Signature in group 3
            carrierSigner2 = Signer(
                email=args["docusignEmail2"],
                name=args["carrier"] + " Representative",
                recipient_id="6",
                routing_order="4",
                tabs=Tabs(sign_here_tabs=[carrierSignature2]),
            )

            # CC Sharepoint in group 5
            ccSharepoint = CarbonCopy(
                email="kccarrier.addendums@kcc.com",
                name="CTT SharePoint",
                recipient_id="7",
                routing_order="5",
            )

        # Create final sender array
        signers = []

        # if testing, only apply 2 people
        if processType != "Testing":
            signers.append(carrierSigner1)
            # If there's a second carrier signature, add them
            if args["docusignEmail2"] != "":
                signers.append(carrierSigner2)
            signers.append(kcSigner)
        else:
            signers.append(kcSignerTest)
            signers.append(carrierSignerTest1)
            signers.append(carrierSignerTest2)

        # Create final CC list
        carbon_copies = []

        # If testing, only cc Strategy and Analysis Group Box

        if processType != "Testing":
            carbon_copies.append(ccCM)
            carbon_copies.append(ccCondata)
            carbon_copies.append(ccUSBank)
            carbon_copies.append(ccSharepoint)

            """
            Loop through carrier cc list and append carbon copies
            Create the CC recipient to receive a copy of the documents for the carrier
            If there's a second carrier, increase the recipient ID
            """
            ccID = 0
            ccCount = args["ccCount"]
            while ccCount > 0:
                # ccCarrierEmail = args["cc" + str(ccID - 2)]
                carbon_copies.append(
                    CarbonCopy(
                        email=args["cc" + str(ccID)],
                        name="Carrier Carbon Copy " + str(ccID + 1),
                        recipient_id=str(ccID + 1 + 10),
                        routing_order="4",
                    )
                )
                ccID += 1
                ccCount -= 1
        else:
            carbon_copies.append(ccTest)

        # Add the tabs model (including the sign_here tabs) to the signer
        # The Tabs object wants arrays of the different field/tab types
        # if Carrier = 'NFIL' or SCAC = 'WEDV', then just do copies and do NOT try to get signatures from anyone.
        if args["carrier"] != "NFIL" and args["scac"] != "WEDV":
            # pdfFile.tabs = Tabs(sign_here_tabs=signatureTabs)
            recipients = Recipients(signers=signers, carbon_copies=carbon_copies)
        else:
            recipients = Recipients(carbon_copies=carbon_copies)

        # Add final recipients to model
        env.recipients = recipients

        # Add the text for the email and the envelope
        env.email_blurb = "The attached addendum needs to be reviewed and electronically signed via DocuSign within 2 business days. Thank you."

        # Request that the envelope be sent by setting |status| to "sent".
        # To request that the envelope be created as a draft, set to "created"
        env.status = "sent"

        # open file for writing
        f = open(r"C:\Users\U15405\Desktop\env.txt", "w")

        # write file
        f.write(str(env))

        # close file
        f.close()

        # Send the envelope with arguements
        sendEnvelope(env)
        # return env

    def sendEnvelope(args):
        """
        Create the envelope request object
        Send the envelope
        """

        # Create the envelope request object
        # envelope_definition = make_envelope(args)
        api_client = utils.create_api_client(
            base_path=base_path, access_token=ds_access_token
        )

        # Call Envelopes::create API method
        # Exceptions will be caught by the calling function
        envelopes_api = EnvelopesApi(api_client)
        results = envelopes_api.create_envelope(
            account_id=account_id, envelope_definition=args
        )
        envelope_id = results.envelope_id
        return {"envelope_id": envelope_id}

    def moveFileToSentFolder(pdfFile, carrier):
        # This will preserve the .pdf file by moving it to the carrier's completed folder, and will delete the .xlsx copy
        print(
            "Starting to move .pdf addendum for "
            + carrier
            + " to their Addendums-Sent folder"
        )

        # If, for some reason, there is no folder for the carrier in Addendums-Sent, create it
        if not os.path.isdir(sentDir + carrier):
            print(
                carrier
                + "'s folder does not exist in Addendums-Sent. Creating folder for Carrier."
            )
            os.makedirs(sentDir + carrier)

        # Move the .pdf file
        print("Moving file now Addendums-Pending to Addendums-Sent for " + carrier)
        move(pendingDir + pdfFile, sentDir + "\\" + carrier)

        # Delete the .xlsx file
        if os.path.exists(pendingDir + pdfFile.replace(".pdf", ".xlsx")):
            print("Deleting Excel copy of addendum from Addendums-Pending")
            os.remove(pendingDir + pdfFile.replace(".pdf", ".xlsx"))

    # Begin processing addendums
    for filename in os.listdir(pendingDir):
        if filename.endswith(".pdf"):

            # Create dictionary for Docusign Details
            docusignDetails = {}
            docusignDetails["processType"] = processType

            filepath = pendingDir + filename
            docusignDetails["filepath"] = filepath

            # Get text character positions in file name for parsing
            markerA = filename.find("-")
            markerB = filename.find("(")
            markerC = filename.find(")")
            markerD = filename.rfind("-")

            # Parse strings from file name
            global carrier
            carrier = filename[0:markerA]
            docusignDetails["carrier"] = carrier

            global scac
            scac = filename[markerA + 1 : markerB]
            docusignDetails["scac"] = scac

            global addendumNumber
            addendumNumber = filename[markerB + 1 : markerC]
            docusignDetails["addendumNumber"] = addendumNumber

            global addendumDate
            addendumDate = filename[markerD + 2 : len(filename.replace(".pdf", ""))]
            docusignDetails["addendumDate"] = addendumDate

            # Carrier Contact Dataframe
            carrier_df = sharepointEmails.loc[sharepointEmails["Carrier"] == carrier]

            # If there's no matching carrier email, send notification to people, attach files, then delete from Addendums-Pending folder and go to next file
            if carrier_df.empty == True:
                missingEmail(carrier, filepath)
                continue

            # Set To Email Address
            global docusignEmail
            docusignEmail = (
                carrier_df["Signer Emails (To Addresses)"].values[0].replace(" ", "")
            )

            # Get up to 2 email addresses, and replace with testing if needed
            if ";" in docusignEmail:
                docusignDetails["docusignEmail1"] = docusignEmail.split(";", 1)[0]
                docusignDetails["docusignEmail2"] = docusignEmail.split(";", 1)[1]
                if docusignDetails["processType"] == "Testing":
                    docusignDetails["docusignEmail1"] = "steve.wolfe@kcc.com"
                    docusignDetails["docusignEmail2"] = "steve.wolfe@kcc.com"
            else:
                docusignDetails["docusignEmail"] = docusignEmail
                docusignDetails["docusignEmail2"] = ""
                if docusignDetails["processType"] == "Testing":
                    docusignDetails["docusignEmail1"] = "steve.wolfe@kcc.com"
                    docusignDetails["docusignEmail2"] = ""

            # Set CC Email Address
            global ccAddresses
            ccAddresses = (
                carrier_df["Notification Emails (CC Addresses)"]
                .values[0]
                .replace(" ", "")
            )

            # Set individual
            seq = ccAddresses.split(";")
            ccList = seq[0:]
            ccListCount = len(ccList)

            ccCount = 0
            # Loop through CC's, and load each into separate variable and add to global dictionary
            for ccAddress in ccList:
                # dynamically create key
                key = "cc"
                # calculate value
                value = str(ccCount)
                ccNumber = key + value
                if docusignDetails["processType"] == "Testing":
                    docusignDetails[ccNumber] = "steve.wolfe@kcc.com"
                else:
                    docusignDetails[ccNumber] = ccAddress
                ccCount += 1

            # Append total number of CC's to Docusign Details Dictionary
            docusignDetails["ccCount"] = ccListCount

            # Create the docusign envelope
            makeAndSendEnvelope(docusignDetails)

            # Move the .pdf copy to the Addendums-Sent folder for the carrier, and delete the Excel copy
            moveFileToSentFolder(filename, carrier)


# Get token for Docusign API
def getDocusignAPIToken():

    global base_path
    base_path = "https://demo.docusign.net/restapi"

    api_client = ApiClient(base_path)
    token = api_client.request_jwt_user_token(
        client_id=config.DS_JWT.get("ds_client_id"),
        user_id=config.DS_JWT.get("ds_impersonated_user_id"),
        oauth_host_name=config.DS_JWT.get("authorization_server"),
        private_key_bytes=open(config.DS_JWT.get("private_key_file"), "r").read(),
        expires_in=3600,
    )
    global ds_access_token
    ds_access_token = token.access_token

    global ds_token_expires
    ds_token_expires = token.expires_in

    global ds_token_scope
    ds_token_scope = token.scope

    global ds_token_type
    ds_token_type = token.token_type

    """Make request to the API to get the user information"""
    # Determine user, account_id, base_url by calling OAuth::getUserInfo
    # See https://developers.docusign.com/esign-rest-api/guides/authentication/user-info-endpoints
    url = config.DS_CONFIG["authorization_server"] + "/oauth/userinfo"
    auth = {"Authorization": "Bearer " + ds_access_token}
    response = requests.get(url, headers=auth).json()

    global account_id
    account_id = response["accounts"][0]["account_id"]
    print(account_id)
    print("Done With ID")


# set global variables
globalVariables()

# Get emails from Sharepoint file
sharepointEmails()

# Convert all of the Addendums-Pending .xlsx files to .pdf
convertXLSXtoPDF()

# If there are no files to process, quit entire script
if fileCount == 0:
    quit()

# Get token for Docusign API, which will be good for the day
getDocusignAPIToken()

# Process each .pdf file, and send through docusign then archive
processAddendums()

# Check to make sure Addendums-Pend
addendumsNotMoved()

print("Done")
