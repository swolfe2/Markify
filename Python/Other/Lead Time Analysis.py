import pandas as pd #dataframe processing
import numpy as np #math functions
import matplotlib.pyplot as plt #data visualizations
import sqlalchemy as sa #connect to SQL db
from urllib.parse import quote_plus #to handle quotes
from turbodbc import connect, make_options #for MUCH faster write than sqlalchemy
from tabulate import tabulate

# Connect to main MSSQL Database
USCTTDEV_params = quote_plus(   "Driver={ODBC Driver 17 for SQL Server};"
                                "Server=USTCAS98.KCC.COM;Database=USCTTDEV;"
                                "Trusted_Connection=YES;Encrypt=YES;"
                                "TrustServerCertificate=YES")
USCTTDEV_conn_string = f"mssql+pyodbc:///?odbc_connect={USCTTDEV_params}"
USCTTDEV = sa.create_engine(USCTTDEV_conn_string)
USCTTDEVConn = USCTTDEV.connect() 

#Execute query, create dataframe
df_LeadTime = pd.read_sql_query('''
    SELECT DISTINCT 
	ald.Lane,
	ald.LD_LEG_ID,
	ald.CRTD_DTT,
	COUNT(DISTINCT ald.LD_LEG_ID) AS LoadCount,
	CAST(ROUND(AVG(om.TDR_LEAD_HRS),1) AS NUMERIC(18,1)) AS LeadTime,
	CAST(ROUND(AVG(ald.Act_Linehaul),2) AS NUMERIC(18,2)) AS LinehaulCost,
	CASE 
		WHEN CAST(ald.CRTD_DTT AS DATE) BETWEEN CAST('2/1/2020' AS DATE) AND CAST('2/29/2020' AS DATE) THEN 'February Base'
		WHEN CAST(ald.CRTD_DTT AS DATE) BETWEEN CAST('3/1/2020' AS DATE) AND CAST('7/31/2020' AS DATE) THEN 'Middle Set'
	ELSE 'August Forward' END AS DateType
FROM USCTTDEV.dbo.tblOperationalMetrics om
	INNER JOIN USCTTDEV.dbo.tblActualLoadDetail ald ON ald.LD_LEG_ID = om.LD_LEG_ID
WHERE CAST(ald.CRTD_DTT AS DATE) >= CAST('2/1/2020' AS DATE)
GROUP BY ald.Lane,
ald.LD_LEG_ID,
ald.CRTD_DTT,
CASE 
    WHEN CAST(ald.CRTD_DTT AS DATE) BETWEEN CAST('2/1/2020' AS DATE) AND CAST('2/29/2020' AS DATE) THEN 'February Base'
	WHEN CAST(ald.CRTD_DTT AS DATE) BETWEEN CAST('3/1/2020' AS DATE) AND CAST('7/31/2020' AS DATE) THEN 'Middle Set'
ELSE 'August Forward' END
    ''',USCTTDEVConn)

# Get info on the table, for how Pandas interpreted it
print(df_LeadTime.info(verbose=True))

# Get the first 5 rows of the table
print(df_LeadTime.head())

# Pretty print the entire table
pdtabulate = lambda df_LeadTime:tabulate(df_LeadTime,headers='keys', tablefmt='psql')
print(pdtabulate(df_LeadTime))