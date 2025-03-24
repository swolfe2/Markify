from azure.identity import AzureCliCredential
from azure.keyvault.secrets import SecretClient
from config import (
    AZURE_DATABASE,
    AZURE_SERVER,
    AZURE_SERVICE_PRINCIPAL,
    AZURE_VAULT_URL,
)
from turbodbc import connect, make_options

# Set up the Key Vault client with AzureCliCredential
credential = AzureCliCredential()
client = SecretClient(vault_url=AZURE_VAULT_URL, credential=credential)

# Retrieve the secret
secret = client.get_secret(AZURE_SERVICE_PRINCIPAL)

# Load the secret value and Service Principal ID into variables
retrieved_secret = secret.value
retrieved_service_principal_id = secret.properties.content_type

# Use IP address and port number in the connection string
connection_string = (
    f"Driver={{ODBC Driver 18 for SQL Server}};"
    f"Server=tcp:{AZURE_SERVER},1433;"  # Ensure the port number is correct
    f"Database={AZURE_DATABASE};"
    f"Uid={retrieved_service_principal_id};"
    f"Pwd={retrieved_secret};"
    f"Encrypt=yes;"
    f"TrustServerCertificate=yes;"
    f"Connection Timeout=30;"
    f"Authentication=ActiveDirectoryServicePrincipal;"  # Specify AAD Service Principal authentication
)

# Connect to the database
connection = connect(connection_string=connection_string)
cursor = connection.cursor()

# Execute a query
cursor.execute("SELECT TOP 3 name FROM sys.databases")
for row in cursor.fetchall():
    print(row)
