import csv
import json
import re

import requests
from azure.identity import ClientSecretCredential, DefaultAzureCredential
from azure.keyvault.secrets import SecretClient

# -------------------------------
# CONFIGURATION
# -------------------------------
# --- Azure AD & Key Vault Configuration ---
TENANT_ID = "fee2180b-69b6-4afe-9f14-ccd70bd4c737"
CLIENT_ID = "33c3797a-cd9d-4653-b2d6-a97fb5544505"
VAULT_URL = "https://kv-dvcoeazuresql-sp.vault.azure.net"
SECRET_NAME = "dvcoeazuresql-sp-p-1"

# Power BI API scope
SCOPE = ["https://analysis.windows.net/powerbi/api/.default"]

# --- Acquire Access Token ---
try:
    # Authenticate to Key Vault using DefaultAzureCredential.
    # This will use your logged-in Azure credentials (e.g., from Azure CLI 'az login').
    kv_credential = DefaultAzureCredential()
    secret_client = SecretClient(vault_url=VAULT_URL, credential=kv_credential)

    # Retrieve the client secret from Key Vault
    client_secret_value = secret_client.get_secret(SECRET_NAME).value
    print("Successfully retrieved client secret from Key Vault.")

    # Now, use the retrieved secret to get the Power BI access token
    powerbi_credential = ClientSecretCredential(
        tenant_id=TENANT_ID, client_id=CLIENT_ID, client_secret=client_secret_value
    )
    token_response = powerbi_credential.get_token(*SCOPE)
    ACCESS_TOKEN = token_response.token
    print("Successfully obtained Power BI access token.")

except Exception as e:
    print(f"An error occurred during authentication: {e}")
    ACCESS_TOKEN = None

# Exit if token acquisition failed
if not ACCESS_TOKEN:
    print("Failed to retrieve access token. Exiting.")
    exit()

# List of Dataflow URLs
dataflow_urls = [
    "https://app.powerbi.com/groups/a04966ab-98e7-419b-9374-7ebf0e10fcc4/dataflows/010ee6c4-fc54-4790-b1cb-19c0f98736da",
    "https://app.powerbi.com/groups/a04966ab-98e7-419b-9374-7ebf0e10fcc4/dataflows/d8cdec60-01f2-4f1c-9f49-6482dbf7da4f",
    "https://app.powerbi.com/groups/a04966ab-98e7-419b-9374-7ebf0e10fcc4/dataflows/64a40b42-b06f-4638-ae14-b73856c4a0e4",
]


# -------------------------------
# FUNCTIONS
# -------------------------------
def extract_ids(url):
    """Extract groupId and dataflowId from Power BI URL."""
    pattern = r"groups/([a-f0-9\\-]+)/dataflows/([a-f0-9\\-]+)"
    match = re.search(pattern, url)
    if match:
        return match.group(1), match.group(2)
    return None, None


def get_dataflow_definition(group_id, dataflow_id):
    """Call Power BI REST API to get dataflow definition."""
    api_url = (
        f"https://api.powerbi.com/v1.0/myorg/groups/{group_id}/dataflows/{dataflow_id}"
    )
    headers = {"Authorization": f"Bearer {ACCESS_TOKEN}"}
    response = requests.get(api_url, headers=headers)
    response.raise_for_status()
    return response.json()


def download_model_json(model_url):
    """Download model.json from the provided URL."""
    headers = {"Authorization": f"Bearer {ACCESS_TOKEN}"}
    response = requests.get(model_url, headers=headers)
    response.raise_for_status()
    return response.json()


def parse_entities(model_json):
    """Extract table names and column definitions from model.json."""
    entities = model_json.get("entities", [])
    parsed_data = []
    for entity in entities:
        table_name = entity.get("name")
        for attr in entity.get("attributes", []):
            parsed_data.append(
                {
                    "Table": table_name,
                    "Column": attr.get("name"),
                    "DataType": attr.get("dataType"),
                }
            )
    return parsed_data


# -------------------------------
# MAIN LOGIC
# -------------------------------
all_results = []

for url in dataflow_urls:
    group_id, dataflow_id = extract_ids(url)
    if group_id and dataflow_id:
        print(f"Processing Dataflow: {dataflow_id}")
        dataflow_def = get_dataflow_definition(group_id, dataflow_id)

        # Get model.json URL from API response
        model_url = dataflow_def.get("modelUrl")
        if not model_url:
            print(f"No modelUrl found for Dataflow {dataflow_id}")
            continue

        model_json = download_model_json(model_url)
        parsed_data = parse_entities(model_json)

        for row in parsed_data:
            row["GroupID"] = group_id
            row["DataflowID"] = dataflow_id
        all_results.extend(parsed_data)

# -------------------------------
# OUTPUT TO CSV
# -------------------------------
output_file = "dataflow_table_definitions.csv"
with open(output_file, mode="w", newline="", encoding="utf-8") as csvfile:
    fieldnames = ["GroupID", "DataflowID", "Table", "Column", "DataType"]
    writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(all_results)

print(
    f"✅ Extracted table definitions for {len(dataflow_urls)} dataflows and saved to {output_file}."
)
