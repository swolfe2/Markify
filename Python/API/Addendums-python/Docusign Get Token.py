from app.ds_config import DS_JWT
import app.ds_config as config
import app.docusign.utils as utils
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

PROCESS_TYPE = "Production"

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
