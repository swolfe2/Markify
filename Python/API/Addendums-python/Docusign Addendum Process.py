import os
import base64
from shutil import move
import win32com.client as win32
from docusign_esign import (
    AuthenticationApi,
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
import requests
import pandas as pd
import app.ds_config as config
import app.docusign.utils as utils

# Main global variables used in the rest of the file
def global_variables():
    # Get Username
    global CURRENT_USER_ID
    CURRENT_USER_ID = os.getlogin()

    # Set starting directory
    global PENDING_DIR
    PENDING_DIR = (
        "C:\\Users\\"
        + CURRENT_USER_ID
        + "\\Kimberly-Clark\\Rates and Pricing - Agreements\\Addendums-Pending\\"
    )

    # Set finished directory
    global SENT_DIR
    SENT_DIR = (
        "C:\\Users\\"
        + CURRENT_USER_ID
        + "\\Kimberly-Clark\\Rates and Pricing - Agreements\\Addendums-Sent\\"
    )

    # Set the run type of the script
    global PROCESS_TYPE
    PROCESS_TYPE = "Production"
    # Comment out below for production
    # PROCESS_TYPE = "Testing"


def deleteXLSXFromProcess():
    # See if file already exists in Addendums-Sent directory. If so, delete the .xlsx copy from Addendums-Pending
    addendums_to_process_folder = (
        "\\\\IN00AAP024\\Contract Data\\Production\\Addendums To Process\\"
    )
    for filename in os.listdir(addendums_to_process_folder):
        # Get the filename without extension
        file_name_no_extension = os.path.basename(filename).split(".")[0]

        # Get text character positions in file name for parsing
        marker_a = filename.find("-")

        # Parse carier
        carrier_name = filename[0:marker_a]
        final_filepath = (
            SENT_DIR + carrier_name + "\\" + file_name_no_extension + ".xlsx"
        )
        if os.path.isfile(final_filepath) or os.path.isfile(
            final_filepath.replace(".xlsx", ".pdf")
        ):
            print(
                addendums_to_process_folder
                + filename
                + " already exists in "
                + carrier_name
                + "'s Addendums-Sent folder. Deleting from Addendums-Pending folder."
            )
            if os.path.isfile(PENDING_DIR + file_name_no_extension + ".xlsx"):
                os.remove(PENDING_DIR + file_name_no_extension + ".xlsx")
            if os.path.isfile(PENDING_DIR + file_name_no_extension + ".pdf"):
                os.remove(PENDING_DIR + file_name_no_extension + ".pdf")
            if os.path.isfile(
                addendums_to_process_folder + file_name_no_extension + ".xlsx"
            ):
                os.remove(
                    addendums_to_process_folder + file_name_no_extension + ".xlsx"
                )


# Convert all of the Addendums-Pending .xlsx files to .pdf
def convert_xlsx_to_pdf():
    """This converts all of the .xlsx files within the directory into .pdf files for Docusign to use."""

    # See if file already exists in Addendums-Sent directory. If so, delete the .pdf copy and the .xlsx copy from Addendums-Pending
    deleteXLSXFromProcess()

    for filename in os.listdir(PENDING_DIR):
        # Get the filename without extension
        file_name_no_extension = os.path.basename(filename).split(".")[0]

        # Get text character positions in file name for parsing
        marker_a = filename.find("-")

        # Parse carier
        carrier_name = filename[0:marker_a]
        if os.path.isfile(
            PENDING_DIR.replace(
                "Addendums-Pending",
                "Addendums-Sent\\"
                + carrier_name
                + "\\"
                + file_name_no_extension
                + ".xlsx",
            )
        ) or os.path.isfile(
            PENDING_DIR.replace(
                "Addendums-Pending",
                "Addendums-Sent\\"
                + carrier_name
                + "\\"
                + file_name_no_extension
                + ".pdf",
            )
        ):
            print(
                filename
                + " already exists in "
                + carrier_name
                + "'s Addendums-Sent folder. Deleting from Addendums-Pending folder."
            )
            if os.path.isfile(PENDING_DIR + file_name_no_extension + ".xlsx"):
                os.remove(PENDING_DIR + file_name_no_extension + ".xlsx")
            if os.path.isfile(PENDING_DIR + file_name_no_extension + ".pdf"):
                os.remove(PENDING_DIR + file_name_no_extension + ".pdf")
            if os.path.isfile(
                "\\\\IN00AAP024\\Contract Data\\Production\\Addendums To Process\\"
                + file_name_no_extension
                + ".xlsx"
            ):
                os.remove(
                    "\\\\IN00AAP024\\Contract Data\\Production\\Addendums To Process\\"
                    + file_name_no_extension
                    + ".xlsx"
                )

    # Loop through all addendum files, and convert them to .pdf
    for filename in os.listdir(PENDING_DIR):
        if filename.endswith(".xlsx"):
            filepath = PENDING_DIR + filename
            pdfpath = filepath.replace(".xlsx", ".pdf")
            if not os.path.isfile(pdfpath):

                # Open Microsoft Excel
                excel = win32.Dispatch("Excel.Application")

                # Read Excel File
                sheets = excel.Workbooks.Open(filepath)
                work_sheets = sheets.Worksheets[0]

                # Convert into PDF File
                work_sheets.ExportAsFixedFormat(0, pdfpath)

                # Close workbook once complete
                sheets.Close(False)

    global FILE_COUNT
    FILE_COUNT = 0
    for filename in os.listdir(PENDING_DIR):
        if filename.endswith(".pdf") and "TEST" not in filename:
            FILE_COUNT += 1


# Get Docusign Emails from Sharepoint file
def get_sharepoint_emails():
    """This gets"""
    sharepoint_file = (
        "C:\\Users\\"
        + CURRENT_USER_ID
        + "\\Kimberly-Clark\\Contracts & Pricing - Shared Documents\\Docusign Emails.xlsx"
    )
    xl = pd.ExcelFile(sharepoint_file)
    df = xl.parse("Docusign Emails")
    global SHAREPOINT_EMAILS
    SHAREPOINT_EMAILS = df.fillna("")


def missing_email(carrier_name, filepath):
    """if there is no email for the CARRIER, send alert and skip"""
    outlook = win32.Dispatch("outlook.application")
    mail = outlook.CreateItem(0)
    mail.To = "schrysan@kcc.com; jbhook@kcc.com; scarpent@kcc.com; slindsey@kcc.com"
    mail.Cc = "Regina.S.Black@kcc.com; Steve.Wolfe@kcc.com"
    mail.SendUsingAccount = "strategyandanalysis.ctt@kcc.com"
    mail.SentOnBehalfOfName = "strategyandanalysis.ctt@kcc.com"
    mail.Subject = "Rate Loading: Missing CARRIER Email"
    # mail.Body="Message body"
    mail.HTMLBody = (
        """Hello, <br><br>
    No CARRIER email address was found for CARRIER """
        + carrier_name
        + """, and no Docusign envelope could be created.
    Please add this CARRIER asap to the <a href="https://kimberlyclark.sharepoint.com/:x:/t/A286/Rates/ContractsPricing/EU5lSxD-mFBOvOW1VMrZIKUBxN5LvEjksFCudHnUcy0qiQ?e=I5H6ZK">Docusign Emails File</a>. <br><br>
    The attached files have been removed from the <a href="https://kimberlyclark.sharepoint.com/Sites/A120/ratesandpricing/Document/Addendums-Pending/">Addendums-Pending Folder on Sharepoint</a>. <br><br>
    <b><span style="background-color: #FFFF00">This addendum will need to be manually processed through Docusign.</span></b><br><br>
    Thanks, <br><br>
    -Strategy & Analysis
    """
    )

    # To attach a file to the email (optional):
    pdf_file = filepath
    xlsx_file = filepath.replace(".pdf", ".xlsx")
    mail.Attachments.Add(pdf_file)
    mail.Attachments.Add(xlsx_file)

    mail.Send()

    # Attempt to delete the .pdf file
    try:
        os.remove(pdf_file)
    except OSError:
        pass

    # Attempt to delete the .xlsx file
    try:
        os.remove(xlsx_file)
    except OSError:
        pass


def kill_outlook():
    """Close Outlook object"""
    win_management = win32.GetObject("winmgmts:")
    for process in win_management.ExecQuery(
        'select * from Win32_Process where Name="Outlook.exe"'
    ):
        # os.system("taskkill /pid /F /IM " + str(p.ProcessId))
        os.kill(process.ProcessId, 9)


def addendums_not_moved():
    """If there are still addendums in the folder, send an email to NARate._Trans@kcc.com
    that something's wrong. All files should have been moved
    to the CARRIER's Addendums-Sent folder"""
    print(
        "Looking through Addendums-Pending folder. There should be NO files in here at all. "
        "If there are any, going to send an email."
    )

    # Intialize counter
    i = 0
    for filename in os.listdir(PENDING_DIR):
        if filename.endswith(".pdf") and "TEST" not in filename:
            i += 1

    if i >= 1:
        if i == 1:
            file_string = "file"
            it_they = "it has"
        else:
            file_string = "files"
            it_they = "they have"

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
        You can find the CARRIER's current email listing by going to the <a href="https://kimberlyclark.sharepoint.com/:x:/t/A286/Rates/ContractsPricing/EU5lSxD-mFBOvOW1VMrZIKUBxN5LvEjksFCudHnUcy0qiQ?e=I5H6ZK">Docusign Emails File on Sharepoint</a>. <br><br> 
        If """
            + it_they
            + """ already been processed through Docusign, please move the .pdf copy of the """
            + file_string
            + """ to the carriers's individual folder in the <a href="https://kimberlyclark.sharepoint.com/Sites/A120/ratesandpricing/Document/Addendums-Sent/">Addendums-Sent Folder on Sharepoint</a>,
        and delete the .xlsx """
            + file_string
            + """.<br><br>
        Thanks, <br><br>
        -Strategy & Analysis
        """
        )

        mail.Send()


# Process each .pdf file
def process_addendums():
    """This function is what actually processes all of the addendums 1:1"""

    def make_and_send_envelope(args):
        """
        Creates envelope
        Document 1: PDF Version of Addendum that was previously made
        DocuSign will convert all of the documents to the PDF format.
        """
        global DOCUSIGN_FILE
        DOCUSIGN_FILE = args["filepath"]

        # Create the envelope definition
        env = EnvelopeDefinition(
            email_subject="Please Docusign: Addendum - "
            + args["CARRIER"]
            + "-"
            + args["SCAC"]
            + "("
            + args["ADDENDUM_NUMBER"]
            + ")"
            + "--Created "
            + args["ADDENDUM_DATE"]
        )

        # If testing, update the email subject
        if PROCESS_TYPE == "Testing":
            env.email_subject = "TESTING! - " + env.email_subject

        # doc1_b64 = base64.b64encode(bytes(cls.create_document1(args), "utf-8")).decode(
        #    "ascii"
        # )

        # Read .pdf file from local directory, will raise an exception if the file is not available!
        with open(args["filepath"], "rb") as file:
            pdf_file_bytes = file.read()
        doc1_b64 = base64.b64encode(pdf_file_bytes).decode("ascii")

        # Create the document models
        pdf_file = Document(  # create the DocuSign document object
            document_base64=doc1_b64,
            name="Addendum " + args["ADDENDUM_NUMBER"] + " Signable",
            # can be different from actual file name
            file_extension="pdf",  # many different document types are accepted
            document_id="1",  # a label used to reference the doc
            apply_anchor_tabs=True,
        )

        """
        Cannot attach just an Excel file. 
        Docusign converts the Excel file to .pdf format automatically.

        with open(args["filepath"], "rb") as file:
            xlsx_fileBytes = file.read()
        xlsx_b64 = base64.b64encode(xlsx_fileBytes).decode("ascii")

        xlsx_file = Document(  # create the DocuSign document object
            document_base64=xlsx_b64,
            name="Addendum " + args["ADDENDUM_NUMBER"] + " Excel Copy",
            # can be different from actual file name
            file_extension="xlsx",  # many different document types are accepted
            document_id="2",  # a label used to reference the doc
        )
        """

        # The order in the docs array determines the order in the envelope
        env.documents = [pdf_file]

        # Create signature array, and always add the first CARRIER kc_signature carrier_signature_1 carrier_signature_2
        signature_tabs = []
        kc_signature = SignHere(
            anchor_string="/*kc_signature*/",
            anchor_units="pixels",
            anchor_y_offset="-7",
            anchor_x_offset="0",
            name="kc_signature",
            tab_label="kc_signature",
            page_number=1,
            document_id=1,
            recipient_id="6",
        )
        signature_tabs.append(kc_signature)

        carrier_signature_1 = SignHere(
            anchor_string="/*carrier_signature_1*/",
            anchor_units="pixels",
            anchor_y_offset="-7",
            anchor_x_offset="0",
            name="carrier_signature_1",
            tab_label="carrier_signature_1",
            page_number=1,
            document_id=1,
            recipient_id="4",
        )
        signature_tabs.append(carrier_signature_1)

        # Will only add this to the signature tabs if the CARRIER has a second signer
        carrier_signature_2 = SignHere(
            anchor_string="/*carrier_signature_2*/",
            anchor_units="pixels",
            anchor_y_offset="-7",
            anchor_x_offset="0",
            name="carrier_signature_2",
            tab_label="carrier_signature_2",
            page_number=1,
            document_id=1,
            recipient_id="5",
        )
        if args["docusign_email2"] != "":
            signature_tabs.append(carrier_signature_2)

        """
        Here's where the routing logic starts

        routingOrder (lower means earlier) determines the order of deliveries
        to the recipients. Parallel routing order is supported by using the
        same integer as the order for two or more recipients.
        """
        if PROCESS_TYPE == "Testing":

            carrier_signer_test_1 = Signer(
                email="StrategyAndAnalysis.ctt@kcc.com",
                name=args["CARRIER"] + " Representative 1",
                recipient_id="4",
                routing_order="2",
                tabs=Tabs(sign_here_tabs=[carrier_signature_1]),
            )

            carrier_signer_test_2 = Signer(
                email="swolfe2@gmail.com",
                name=args["CARRIER"] + " Representative 2",
                recipient_id="5",
                routing_order="2",
                tabs=Tabs(sign_here_tabs=[carrier_signature_2]),
            )

            kc_signer_test = Signer(
                email="Steve.Wolfe@kcc.com",
                name="K-C Representative",
                recipient_id="6",
                routing_order="1",
                tabs=Tabs(sign_here_tabs=[kc_signature]),
            )

            cc_test = CarbonCopy(
                email="Regina.S.Black@kcc.com",
                name="Regina Black -Copy",
                recipient_id="10",
                routing_order="3",
            )
        else:
            # Mimic Template Order
            # CC CARRIER Manager in group 1
            cc_cm = CarbonCopy(
                email="CarrierManagementTeam.Addendums@kcc.com",
                name="K-C Carrier Management",
                recipient_id="1",
                routing_order="1",
            )

            # CC ConData in group 2
            cc_condata = CarbonCopy(
                email="opsmail@condata.com",
                name="ConData",
                recipient_id="2",
                routing_order="2",
            )

            # CC US Bank in group 2
            cc_usbank = CarbonCopy(
                email="usbank.pricing@usbank.com",
                name="US Bank - Copy",
                recipient_id="3",
                routing_order="2",
            )

            # Add the CARRIER Representative for Signature in group 3
            carrier_signer_1 = Signer(
                email=args["docusign_email1"],
                name=args["CARRIER"] + " Representative",
                recipient_id="4",
                routing_order="3",
                tabs=Tabs(sign_here_tabs=[carrier_signature_1]),
            )

            # Add the CARRIER Representative for Signature in group 3
            carrier_signer_2 = Signer(
                email=args["docusign_email2"],
                name=args["CARRIER"] + " Representative",
                recipient_id="5",
                routing_order="3",
                tabs=Tabs(sign_here_tabs=[carrier_signature_2]),
            )

            # Add the K-C Representative for Signature in group 4
            kc_signer = Signer(
                email="Purvi.Naik@kcc.com",
                name="K-C Representative",
                recipient_id="6",
                routing_order="4",
                tabs=Tabs(sign_here_tabs=[kc_signature]),
            )

            # CC Sharepoint in group 5
            cc_sharepoint = CarbonCopy(
                email="kccarrier.addendums@kcc.com",
                name="CTT SharePoint",
                recipient_id="7",
                routing_order="5",
            )

        # Create final sender array
        signers = []

        # if testing, only apply 2 people
        if PROCESS_TYPE != "Testing":
            signers.append(carrier_signer_1)
            # If there's a second CARRIER signature, add them
            if args["docusign_email2"] != "":
                signers.append(carrier_signer_2)
            signers.append(kc_signer)
        else:
            signers.append(kc_signer_test)
            signers.append(carrier_signer_test_1)
            signers.append(carrier_signer_test_2)

        # Create final CC list
        carbon_copies = []

        # If testing, only cc Strategy and Analysis Group Box

        if PROCESS_TYPE != "Testing":
            carbon_copies.append(cc_cm)
            carbon_copies.append(cc_condata)
            carbon_copies.append(cc_usbank)
            carbon_copies.append(cc_sharepoint)

            """
            Loop through CARRIER cc list and append carbon copies
            Create the CC recipient to receive a copy of the documents for the CARRIER
            If there's a second CARRIER, increase the recipient ID
            """
            cc_id = 0
            cc_count = args["cc_count"]

            """
            Per Regina Black 10/15/2021
            They do need to go through DocuSign as you had it, but if you could remove the carrier cc piece
            then it’s perfect.  Con Data, US Bank, and Share Point all need the copy, and you can copy the
            new CM mailbox like you have it.
            """

            if args["CARRIER"] != "NFIL" and args["SCAC"] != "WEDV":
                while cc_count > 0:
                    carbon_copies.append(
                        CarbonCopy(
                            email=args["cc" + str(cc_id)],
                            name="CARRIER Carbon Copy " + str(cc_id + 1),
                            recipient_id=str(cc_id + 1 + 10),
                            routing_order="3",
                        )
                    )
                    cc_id += 1
                    cc_count -= 1
        else:
            carbon_copies.append(cc_test)

        # Add the tabs model (including the sign_here tabs) to the signer
        # The Tabs object wants arrays of the different field/tab types
        # if CARRIER = 'NFIL' or SCAC = 'WEDV', then just do copies and do NOT try to get signatures from anyone.
        if args["CARRIER"] != "NFIL" and args["SCAC"] != "WEDV":
            # pdf_file.tabs = Tabs(sign_here_tabs=signature_tabs)
            recipients = Recipients(signers=signers, carbon_copies=carbon_copies)
        else:
            recipients = Recipients(carbon_copies=carbon_copies)

        # Add final recipients to model
        env.recipients = recipients

        # Add the text for the email and the envelope
        env.email_blurb = (
            "The attached addendum needs to be reviewed and electronically signed via DocuSign "
            "within 2 business days. Thank you."
        )

        # Request that the envelope be sent by setting |status| to "sent".
        # To request that the envelope be created as a draft, set to "created"
        env.status = "sent"

        # open file for writing
        # f = open(r"C:\Users\U15405\Desktop\env.txt", "w")

        # write file
        # f.write(str(env))

        # close file
        # f.close()

        # Send the envelope with arguements
        send_envelope(env)
        # return env

    def send_envelope(args):
        """
        Create the envelope request object
        Send the envelope
        """

        # Create the envelope request object
        # envelope_definition = make_envelope(args)
        api_client = utils.create_api_client(
            base_path=BASE_URI, access_token=DS_ACCESS_TOKEN
        )

        # Call Envelopes::create API method
        # Exceptions will be caught by the calling function
        envelopes_api = EnvelopesApi(api_client)

        results = envelopes_api.create_envelope(
            account_id=ACCOUNT_ID, envelope_definition=args
        )
        envelope_id = results.envelope_id

        print("Envelope ID: " + envelope_id + " successfully made for " + DOCUSIGN_FILE)

        return {"envelope_id": envelope_id}

    def send_excel_file(
        filename,
        carrier_name,
        scac_name,
        excel_docusign_email,
        excel_cc_addresses,
        excel_addendum_number,
    ):
        # Kill any previously running Outlook applications
        # kill_outlook()

        # Convert back to Excel file structure
        filename = filename.replace(".pdf", ".xlsx")

        print("Sending " + filename + " to " + carrier_name)
        outlook = win32.Dispatch("outlook.application")
        mail = outlook.CreateItem(0)
        mail.To = excel_docusign_email
        mail.Cc = excel_cc_addresses
        mail.Bcc = "strategyandanalysis.ctt@kcc.com"
        mail.SendUsingAccount = "strategyandanalysis.ctt@kcc.com"
        mail.SentOnBehalfOfName = "strategyandanalysis.ctt@kcc.com"
        mail.Subject = (
            "Addendum - "
            + carrier_name
            + "-"
            + scac_name
            + "("
            + excel_addendum_number
            + ")"
        )
        # mail.Body="Message body"
        mail.HTMLBody = (
            """Hello, <br><br>
        Please see the attached for an Excel copy of addendum """
            + excel_addendum_number
            + """.<br>
        <p style="color:red">This is to help you review the rates and you don’t need to return via DocuSign.</p>
        Thanks, <br><br>
        -Strategy & Analysis <br>
        <p><b><i><span style="background-color:yellow">This email address only sends outbound emails, and replies will not be viewed.</span></i></b></p>
        """
        )

        # To attach a file to the email (optional):
        mail.Attachments.Add(filename)

        mail.Send()

    def move_file_to_sent_folder(sent_pdf_file, sent_carrier):
        # This will preserve the .pdf file by moving it to the CARRIER's completed folder, and will delete the .xlsx copy
        print(
            "Starting to move .pdf addendum for "
            + sent_carrier
            + " to their Addendums-Sent folder"
        )

        # If, for some reason, there is no folder for the CARRIER in Addendums-Sent, create it
        if not os.path.isdir(SENT_DIR + sent_carrier):
            print(
                sent_carrier
                + "'s folder does not exist in Addendums-Sent. Creating folder for CARRIER."
            )
            os.makedirs(SENT_DIR + sent_carrier)

        # Delete the .pdf file of aleardy exists
        if os.path.exists(SENT_DIR + "\\" + sent_carrier + sent_pdf_file):
            print(
                ".pdf Addendum already exists for "
                + sent_carrier
                + ". Deleting previous file, and replacing with new."
            )
            os.remove(SENT_DIR + "\\" + sent_carrier + sent_pdf_file)

        # Move the .pdf file
        print(
            "Moving "
            + sent_pdf_file
            + " now Addendums-Pending to Addendums-Sent for "
            + sent_carrier
        )
        move(
            PENDING_DIR + sent_pdf_file,
            SENT_DIR + "\\" + sent_carrier + "\\" + sent_pdf_file,
        )

        # Delete the .xlsx file
        if os.path.exists(PENDING_DIR + sent_pdf_file.replace(".pdf", ".xlsx")):
            print("Deleting Excel copy of addendum from Addendums-Pending")
            os.remove(PENDING_DIR + sent_pdf_file.replace(".pdf", ".xlsx"))

        # Delete the .xlsx file from the Contract Data Addendums To Process
        if os.path.exists(
            "\\\\IN00AAP024\\Contract Data\\Production\\Addendums To Process\\"
            + sent_pdf_file.replace(".pdf", ".xlsx")
        ):
            print("Deleting Excel copy of addendum from Addendums To Process")
            os.remove(
                "\\\\IN00AAP024\\Contract Data\\Production\\Addendums To Process\\"
                + sent_pdf_file.replace(".pdf", ".xlsx")
            )

    # Begin processing addendums
    for filename in os.listdir(PENDING_DIR):
        if filename.endswith(".pdf") and "TEST" not in filename:

            # Create dictionary for Docusign Details
            docusign_details = {}
            docusign_details["PROCESS_TYPE"] = PROCESS_TYPE

            filepath = PENDING_DIR + filename
            docusign_details["filepath"] = filepath

            # Get text character positions in file name for parsing
            marker_a = filename.find("-")
            marker_b = filename.find("(")
            marker_c = filename.find(")")
            marker_d = filename.rfind("-")

            # Parse strings from file name
            global CARRIER
            CARRIER = filename[0:marker_a]
            docusign_details["CARRIER"] = CARRIER

            global SCAC
            SCAC = filename[marker_a + 1 : marker_b]
            docusign_details["SCAC"] = SCAC

            global ADDENDUM_NUMBER
            ADDENDUM_NUMBER = filename[marker_b + 1 : marker_c]
            docusign_details["ADDENDUM_NUMBER"] = ADDENDUM_NUMBER

            global ADDENDUM_DATE
            ADDENDUM_DATE = filename[marker_d + 2 : len(filename.replace(".pdf", ""))]
            docusign_details["ADDENDUM_DATE"] = ADDENDUM_DATE

            # CARRIER Contact Dataframe
            carrier_df = SHAREPOINT_EMAILS.loc[SHAREPOINT_EMAILS["Carrier"] == CARRIER]

            # If there's no matching CARRIER email, send notification to people, attach files, then delete from Addendums-Pending folder and go to next file
            if carrier_df.empty:
                missing_email(CARRIER, filepath)
                continue

            # Set To Email Address
            global DOCUSIGN_EMAIL
            DOCUSIGN_EMAIL = (
                carrier_df["Signer Emails (To Addresses)"].values[0].replace(" ", "")
            )

            # Get up to 2 email addresses, and replace with testing if needed
            if ";" in DOCUSIGN_EMAIL:
                docusign_details["docusign_email1"] = DOCUSIGN_EMAIL.split(";", 1)[0]
                docusign_details["docusign_email2"] = DOCUSIGN_EMAIL.split(";", 1)[1]
                if docusign_details["PROCESS_TYPE"] == "Testing":
                    docusign_details["docusign_email1"] = "steve.wolfe@kcc.com"
                    docusign_details["docusign_email2"] = "steve.wolfe@kcc.com"
            else:
                docusign_details["docusign_email1"] = DOCUSIGN_EMAIL
                docusign_details["docusign_email2"] = ""
                if docusign_details["PROCESS_TYPE"] == "Testing":
                    docusign_details["docusign_email1"] = "steve.wolfe@kcc.com"
                    docusign_details["docusign_email2"] = ""

            # Set CC Email Address
            global CC_ADDRESSES
            CC_ADDRESSES = (
                carrier_df["Notification Emails (CC Addresses)"]
                .values[0]
                .replace(" ", "")
            )

            # Set individual
            seq = CC_ADDRESSES.split(";")
            cc_list = seq[0:]
            # ccListCount = len(cc_list)

            cc_count = 0
            # Loop through CC's, and load each into separate variable and add to global dictionary
            for cc_address in cc_list:
                # dynamically create key
                key = "cc"
                # calculate value
                value = str(cc_count)
                cc_number = key + value
                if docusign_details["PROCESS_TYPE"] == "Testing":
                    docusign_details[cc_number] = "steve.wolfe@kcc.com"
                else:
                    if cc_list[int(value)] != "":
                        docusign_details[cc_number] = cc_address
                        cc_count += 1

            # Append total number of CC's to Docusign Details Dictionary
            docusign_details["cc_count"] = cc_count

            # If we're testing, overwrite To/CC_ADDRESSES
            if docusign_details["PROCESS_TYPE"] == "Testing":
                DOCUSIGN_EMAIL = "steve.wolfe@kcc.com"
                CC_ADDRESSES = "strategyandanalysis.ctt@kcc.com"

            # Create the docusign envelope
            make_and_send_envelope(docusign_details)

            # Send .xlsx copy of file
            send_excel_file(
                str(PENDING_DIR) + str(filename),
                str(CARRIER),
                str(SCAC),
                str(DOCUSIGN_EMAIL),
                str(CC_ADDRESSES),
                str(ADDENDUM_NUMBER),
            )

            # Move the .pdf copy to the Addendums-Sent folder for the CARRIER, and delete the Excel copy
            move_file_to_sent_folder(filename, CARRIER)


# Get TOKEN for Docusign API
def get_docusign_api_token():
    """This is the function to get the API token from credential file in nested directory."""

    def printer(response_value):
        print(response_value)

    def getuser(access_token, base_path_value):
        api_client = utils.create_api_client(
            base_path=base_path_value, access_token=access_token
        )
        authApi = AuthenticationApi(api_client)
        loginInfo = authApi.login(callback=printer)
        # print(loginInfo)

    global BASE_PATH

    if PROCESS_TYPE == "Production":
        authorization_server = "prod_authorization_server"
        BASE_PATH = "https://na2.docusign.net/restapi"
        USER_ID = "prod_user_id"
        private_key_file = "prod_private_key_file"
    else:
        authorization_server = "dev_authorization_server"
        BASE_PATH = "https://demo.docusign.net/restapi"
        USER_ID = "ds_impersonated_user_id"
        private_key_file = "dev_private_key_file"

    api_client = ApiClient(BASE_PATH)

    global TOKEN
    TOKEN = api_client.request_jwt_user_token(
        client_id=config.DS_JWT.get("ds_client_id"),
        user_id=config.DS_JWT.get(USER_ID),
        oauth_host_name=config.DS_JWT.get(authorization_server),
        private_key_bytes=open(config.DS_JWT.get(private_key_file), "r").read(),
        expires_in=3600,
    )
    global DS_ACCESS_TOKEN
    DS_ACCESS_TOKEN = TOKEN.access_token

    global DS_TOKEN_EXPIRES
    DS_TOKEN_EXPIRES = TOKEN.expires_in

    global DS_TOKEN_SCOPE
    DS_TOKEN_SCOPE = TOKEN.scope

    global DS_TOKEN_TYPE
    DS_TOKEN_TYPE = TOKEN.token_type

    """Make request to the API to get the user information"""
    # Determine user, ACCOUNT_ID, base_url by calling OAuth::getUserInfo
    # See https://developers.docusign.com/esign-rest-api/guides/authentication/user-info-endpoints
    global URL
    URL = "https://" + config.DS_JWT.get(authorization_server) + "/oauth/userinfo"

    global AUTH
    AUTH = {"Authorization": "Bearer " + DS_ACCESS_TOKEN}

    global RESPONSE
    RESPONSE = requests.get(URL, headers=AUTH).json()

    global ACCOUNT_ID
    ACCOUNT_ID = RESPONSE["accounts"][0]["account_id"]
    print("Done With ID " + ACCOUNT_ID)

    global BASE_URI
    BASE_URI = RESPONSE["accounts"][0]["base_uri"] + "/restapi"
    # BASE_URI = BASE_URI.replace("na2", "na3")

    getuser(DS_ACCESS_TOKEN, BASE_PATH)


"""This is the full process for Docusign Addendum automation"""
# set global variables
global_variables()

# Get emails from Sharepoint file
get_sharepoint_emails()

# Convert all of the Addendums-Pending .xlsx files to .pdf
convert_xlsx_to_pdf()

# If there are no files to process, quit entire script
if FILE_COUNT == 0:
    print("No pending new addendums to send through Docusign. Quitting!")
    quit()

# Get TOKEN for Docusign API, which will be good for the day
get_docusign_api_token()

# Process each .pdf file, and send through docusign then archive
process_addendums()

# Check to make sure Addendums-Pend
addendums_not_moved()

# Kill the Outlook process
# kill_outlook()

print("Processed " + str(FILE_COUNT) + " addendums! A pretty good day's work!")
