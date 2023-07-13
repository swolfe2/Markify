"""
pip install --upgrade snowflake-connector-python
"""
import snowflake.connector

import pandas as pd

# Snowflake connection config
conn = snowflake.connector.connect(
    account="https://kcc.east-us-2.azure.snowflakecomputing.com/",
    authenticator="externalbrowser",
    disable_request_password=True,
    user="steve.wolfe@kcc.com",
    application="okta",  # name of your Okta app
    # browser_autorun_path=r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    warehouse="SYNDICATED_GBL_BI_WH",
    role="SNOWFLAKE_P_CORE_DVLPR",
)

# Query to get data from Snowflake table
sql = "SELECT * FROM STAGING.WORKER"

# Load data into Pandas DataFrame
df = pd.read_sql(sql, conn)

# Close connection
conn.close()

print(df.head())
