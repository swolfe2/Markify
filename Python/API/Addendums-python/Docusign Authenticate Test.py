import os
import base64
import requests
import pandas as pd
import win32com.client as win32
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
from shutil import move
from win32com import client

# Get token for Docusign API
def getDocusignAPIToken():
    
    def printer(response):
        print(response)

    def getuser(access_token, base_path):
        api_client = utils.create_api_client(
            base_path=base_path, access_token=access_token
        )
        authApi = AuthenticationApi(api_client)
        loginInfo = authApi.login(callback=printer)
        # print(loginInfo)

    global processType
    processType = "Production"

    global base_path

    if processType == "Production":
        authorization_server = "prod_authorization_server"
        base_path = "https://na2.docusign.net/restapi"
        userID = "prod_user_id"
        private_key_file = "prod_private_key_file"
    else:
        authorization_server = "dev_authorization_server"
        base_path = "https://demo.docusign.net/restapi"
        userID = "ds_impersonated_user_id"
        private_key_file = "dev_private_key_file"

    api_client = ApiClient(base_path)

    global token
    token = api_client.request_jwt_user_token(
        client_id=config.DS_JWT.get("ds_client_id"),
        user_id=config.DS_JWT.get(userID),
        oauth_host_name=config.DS_JWT.get(authorization_server),
        private_key_bytes=open(config.DS_JWT.get(private_key_file), "r").read(),
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
    global url
    url = "https://" + config.DS_JWT.get(authorization_server) + "/oauth/userinfo"

    global auth
    auth = {"Authorization": "Bearer " + ds_access_token}

    global response
    response = requests.get(url, headers=auth).json()

    global account_id
    account_id = response["accounts"][0]["account_id"]
    print("Done With ID " + account_id)

    global base_uri
    base_uri = response["accounts"][0]["base_uri"] + "/restapi"
    # base_uri = base_uri.replace("na2", "na3")

    getuser(ds_access_token, base_path)


# Get token for Docusign API, which will be good for the day
getDocusignAPIToken()