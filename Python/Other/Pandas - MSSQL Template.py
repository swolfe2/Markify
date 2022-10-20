import pandas as pd  # dataframe processing
import numpy as np  # math functions
import matplotlib.pyplot as plt  # data visualizations
import sqlalchemy as sa  # connect to SQL db
from urllib.parse import quote_plus  # to handle quotes
from turbodbc import connect, make_options  # for MUCH faster write than sqlalchemy
from tabulate import tabulate

# Connect to main MSSQL Database
USCTTDEV_params = quote_plus(
    "Driver={ODBC Driver 17 for SQL Server};"
    "Server=USTCAS98.KCC.COM;Database=USCTTDEV;"
    "Trusted_Connection=YES;Encrypt=YES;"
    "TrustServerCertificate=YES"
)
USCTTDEV_conn_string = f"mssql+pyodbc:///?odbc_connect={USCTTDEV_params}"
USCTTDEV = sa.create_engine(USCTTDEV_conn_string)
USCTTDEVConn = USCTTDEV.connect()

# Execute query, create dataframe
df_Carriers = pd.read_sql_query(
    """
    SELECT * FROM USCTTDEV.dbo.tblCarriers
    """,
    USCTTDEVConn,
)

# Get info on the table, for how Pandas interpreted it
print(df_Carriers.info(verbose=True))

# Get the first 5 rows of the table
print(df_Carriers.head())

# Pretty print the entire table
pdtabulate = lambda df_Carriers: tabulate(df_Carriers, headers="keys", tablefmt="psql")
print(pdtabulate(df_Carriers))
