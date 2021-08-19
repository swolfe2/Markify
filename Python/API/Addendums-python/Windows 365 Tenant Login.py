import msal
from office365.graph_client import GraphClient


def acquire_token():
    """
    Acquire token via MSAL
    """
    authority_url = (
        "https://login.microsoftonline.com/fee2180b-69b6-4afe-9f14-ccd70bd4c737"
    )
    app = msal.ConfidentialClientApplication(
        authority=authority_url,
        client_id="{client_id}",
        client_credential="{client_secret}",
    )
    token = app.acquire_token_for_client(
        scopes=["https://graph.microsoft.com/.default"]
    )
    return token


client = GraphClient(acquire_token)
