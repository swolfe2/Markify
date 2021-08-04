from docusign_esign import ApiClient
from app.ds_config import DS_JWT

api_client = ApiClient("https://demo.docusign.net/restapi")

token = api_client.request_jwt_user_token(
    client_id=DS_JWT.get("ds_client_id"),
    user_id=DS_JWT.get("ds_impersonated_user_id"),
    oauth_host_name=DS_JWT.get("authorization_server"),
    private_key_bytes=open(DS_JWT.get("private_key_file"), "r").read(),
    expires_in=3600,
)

access_token = token.access_token
token_expires = token.expires_in
token_scope = token.scope
token_type = token.token_type

print("Done.")

"""
ID: narate._trans@kcc.com
password: pricing
865-541-7107
"""

"""
resp = api_client.request_jwt_application_token(
    client_id=DS_JWT.get("ds_client_id"),  # the integrator key
    oauth_host_name=DS_JWT.get("authorization_server"),  # 'account-d.docusign.com'
    private_key_bytes=open(
        DS_JWT.get("private_key_file"), "r"
    ).read(),  # private key temp file containing key in bytes
    expires_in=3600,
)
"""
