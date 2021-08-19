# import all the libraries
from office365.runtime.auth.authentication_context import AuthenticationContext
from office365.runtime.auth.user_credential import UserCredential
from office365.sharepoint.client_context import ClientContext
from office365.sharepoint.files.file import File

import io
import pandas as pd


# target url taken from sharepoint and credentials
url = r"\\kimberlyclark.sharepoint.com\Teams\A286\Rates\ContractsPricing\Shared Documents\Docusign Emails.xlsx"
site_url = "https://fee2180b-69b6-4afe-9f14-ccd70bd4c737.sharepoint.com"
ctx = ClientContext(site_url).with_credentials(
    UserCredential("{username}", "{password}")
)

username = UserCredential("{username}", "{password}")

web = ctx.web
ctx.load(web)
ctx.execute_query()
print("Web title: {0}".format(web.properties["Title"]))


ctx_auth = AuthenticationContext(url)
if ctx_auth.acquire_token_for_user(UserCredential["username"]):
    ctx = ClientContext(url, ctx_auth)
    web = ctx.web
    ctx.load(web)
    ctx.execute_query()
    print("Authentication successful")

response = File.open_binary(ctx, url)

# save data to BytesIO stream
bytes_file_obj = io.BytesIO()
bytes_file_obj.write(response.content)
bytes_file_obj.seek(0)  # set file object to start

# read excel file and each sheet into pandas dataframe
df = pd.read_excel(bytes_file_obj, sheetname=None)
