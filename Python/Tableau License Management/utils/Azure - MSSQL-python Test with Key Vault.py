# -*- coding: utf-8 -*-
"""
Connection test using mssql_python with Azure Key Vault + AAD Service Principal.
Forces explicit 'User' and 'Password' in the ODBC connection string and
adds defensive checks + masked logging to catch empty values early.
"""

from azure.identity import AzureCliCredential
from azure.keyvault.secrets import SecretClient
from config import AZURE_CLIENT_ID  # <-- The AAD App (Service Principal) Client ID
from config import (
    AZURE_SERVICE_PRINCIPAL,
)  # <-- The Key Vault secret NAME that stores the SP secret VALUE
from config import (
    AZURE_DATABASE,  # make sure this import path is correct
    AZURE_SERVER,
    AZURE_VAULT_URL,
)
from mssql_python import connect  # you confirmed this works on your box

# ---------- 1) Retrieve the SP secret from Key Vault ----------
credential = AzureCliCredential()
kv_client = SecretClient(vault_url=AZURE_VAULT_URL, credential=credential)

sp_secret_value = kv_client.get_secret(AZURE_SERVICE_PRINCIPAL).value  # actual password


# ---------- 2) Defensive checks (fail fast, with masked hints) ----------
def must_have(name, value):
    if not value or not str(value).strip():
        raise ValueError(f"Required setting '{name}' is empty / missing.")


must_have("AZURE_SERVER", AZURE_SERVER)
must_have("AZURE_DATABASE", AZURE_DATABASE)
must_have("AZURE_CLIENT_ID", AZURE_CLIENT_ID)  # User
must_have("KeyVault secret value", sp_secret_value)  # Password

print(
    f"[diag] server='{AZURE_SERVER}', db='{AZURE_DATABASE}', "
    f"user='{AZURE_CLIENT_ID[:8]}...'(len={len(AZURE_CLIENT_ID)}), "
    f"secret_len={len(sp_secret_value)}"
)

# ---------- 3) Build explicit ODBC connection string ----------
conn_str = (
    "Driver={ODBC Driver 18 for SQL Server};"
    f"Server=tcp:{AZURE_SERVER},1433;"
    f"Database={AZURE_DATABASE};"
    "Authentication=ActiveDirectoryServicePrincipal;"
    f"User={AZURE_CLIENT_ID};"  # << MUST be the Client ID
    f"Password={sp_secret_value};"  # << MUST be the secret VALUE
    "Encrypt=yes;"
    "TrustServerCertificate=yes;"
    "Connection Timeout=30;"
)

# ---------- 4) Connect + smoke test ----------
try:
    conn = connect(conn_str)
    cur = conn.cursor()
    cur.execute("SELECT TOP (3) name FROM sys.databases;")
    for r in cur.fetchall():
        print(r)
finally:
    try:
        cur.close()
        conn.close()
    except Exception:
        pass
