import os
import sys
from pathlib import Path

# --- Python/.NET interop ---
import clr  # provided by pythonnet (works even if AddReference isn't there)

# --- Auth / HTTP / Data ---
import msal
import pyodbc
import pythonnet

pythonnet.load("coreclr")  # Load .NET runtime

import clr
from System.Reflection import Assembly
from tqdm import tqdm

import pandas as pd

# ==============================
# CONFIG: Paths and Endpoints
# ==============================
AMO_DIR = r"C:\AMO"  # <-- put your AMO/TOM DLLs here
TABULAR_DLL = os.path.join(AMO_DIR, "Microsoft.AnalysisServices.Tabular.dll")
CORE_DLL = os.path.join(AMO_DIR, "Microsoft.AnalysisServices.Core.dll")

# Azure SQL Database connection details
sql_server = "sql-pbi-platform-p-scus-1.database.windows.net"
sql_database = "db-pbi-platform-p-scus-1"

# Power BI / XMLA
client_id = (
    "04b07795-8ddb-461a-bbee-02f9e1bf7b46"  # Azure CLI public client (Device Code)
)
authority_url = "https://login.microsoftonline.com/common"
scopes = ["https://analysis.windows.net/powerbi/api/.default"]  # Power BI resource
xmla_root = "powerbi://api.powerbi.com/v1.0/myorg"


# ==============================
# Load TOM assemblies (no AddReference needed)
# ==============================
def _load_tom_assemblies():
    missing = []
    for dll in (CORE_DLL, TABULAR_DLL):
        if not os.path.isfile(dll):
            missing.append(dll)
    if missing:
        raise FileNotFoundError(
            "Missing TOM/AMO assemblies:\n  "
            + "\n  ".join(missing)
            + "\nPlace the DLLs in AMO_DIR or update AMO_DIR path."
        )
    Assembly.LoadFrom(CORE_DLL)
    Assembly.LoadFrom(TABULAR_DLL)


_load_tom_assemblies()

# After assemblies are loaded, import TOM types
from Microsoft.AnalysisServices.Tabular import Server

# ==============================
# Authenticate (Device Code)
# ==============================
app = msal.PublicClientApplication(client_id=client_id, authority=authority_url)
flow = app.initiate_device_flow(scopes=scopes)
print(flow["message"])  # Follow the device login instructions
token = app.acquire_token_by_device_flow(flow)
if "access_token" not in token:
    raise RuntimeError(f"Auth failed: {token}")
access_token = token["access_token"]

# ==============================
# Get recordset from Azure SQL
# ==============================
conn_str = (
    f"DRIVER={{ODBC Driver 17 for SQL Server}};"
    f"SERVER={sql_server};"
    f"DATABASE={sql_database};"
    f"Authentication=ActiveDirectoryInteractive"
)

query = """
SELECT dd.datasetID, dd.workspaceID, wd.WorkspaceName
FROM PBI_Platform_Automation.DatasetDetail dd
INNER JOIN PBI_Platform_Automation.WorkspaceDetail wd
    ON wd.WorkspaceID = dd.WorkspaceID
WHERE wd.IsOnDedicatedCapacity = 1
  AND wd.WorkspaceState = 'Active'
  AND wd.WorkspaceName = 'GL DV CoE - Adhoc'
"""

with pyodbc.connect(conn_str) as conn:
    df = pd.read_sql(query, conn)


# ==============================
# XMLA helpers
# ==============================
def xmla_conn_str(workspace_name: str) -> str:
    # Power BI XMLA endpoint per workspace
    return f"{xmla_root}/{workspace_name}"


def is_large_model_via_xmla(workspace_name: str, dataset_id: str, token: str):
    """
    Connect to the workspace XMLA endpoint using the bearer token and check if
    the dataset (database) uses PremiumFiles (Large Model format).
    """
    try:
        server = Server()
        # Connect overload: Connect(connectionString, password_or_token)
        # For Power BI XMLA, pass the OAuth access token as the "password" parameter.
        server.Connect(xmla_conn_str(workspace_name), token)

        # Enumerate databases (datasets) in the workspace
        for db in server.Databases:
            # db.ID is the dataset GUID in Power BI
            if str(db.ID).lower() == dataset_id.lower():
                # StorageEngineUsed returns 'Abf' or 'PremiumFiles'
                engine = str(db.Model.StorageEngineUsed).lower()
                # Debug print (optional)
                print(
                    f"[DEBUG] {workspace_name} :: {dataset_id} -> StorageEngineUsed={engine}"
                )
                return engine == "premiumfiles"
        # If not found in this workspace (name mismatch or permissions)
        print(f"[WARN] Dataset {dataset_id} not found in workspace '{workspace_name}'.")
        return None
    except Exception as ex:
        print(
            f"[ERROR] XMLA check failed for WS='{workspace_name}', DS='{dataset_id}': {ex}"
        )
        return None
    finally:
        try:
            # Dispose connection gracefully
            if "server" in locals() and server.Connected:
                server.Disconnect()
        except Exception:
            pass


# ==============================
# Iterate and collect results
# ==============================
rows = []
for _, r in tqdm(df.iterrows(), total=len(df), desc="Checking via XMLA", unit="model"):
    ds_id = r["datasetID"]
    ws_name = r["WorkspaceName"]
    enabled = is_large_model_via_xmla(ws_name, ds_id, access_token)
    rows.append(
        {"datasetID": ds_id, "workspaceName": ws_name, "isLargeFormatEnabled": enabled}
    )

result_df = pd.DataFrame(rows)
print(result_df)

# ==============================
# Save to Excel
# ==============================
desktop = Path.home() / "OneDrive - Kimberly-Clark" / "Desktop"
desktop.mkdir(parents=True, exist_ok=True)
out_path = desktop / "LargeModelAudit_XMLA.xlsx"
result_df.to_excel(out_path, index=False)
print(f"\n✅ Excel saved: {out_path}")

# Summary
true_count = sum(1 for x in rows if x["isLargeFormatEnabled"] is True)
false_count = sum(1 for x in rows if x["isLargeFormatEnabled"] is False)
none_count = sum(1 for x in rows if x["isLargeFormatEnabled"] is None)
print("\n📊 Summary")
print(f"✔ Checked: {len(rows)} semantic models")
print(f"🏰 Large Model = True : {true_count}")
print(f"🪵 Large Model = False: {false_count}")
print(f"❓ Not found / error : {none_count}")
