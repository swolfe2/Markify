import pyodbc
import pandas
import pprint
from pandas import DataFrame, ExcelWriter

# SQL Server Connection
server = 'USTCAS98'
database = 'USCTTDEV'
username = 'CTTUser'
password = 'Transport12345678'
cnxn = pyodbc.connect('Driver={ODBC Driver 17 for SQL Server};SERVER=' +
                      server+';DATABASE='+database+';UID='+username+';PWD='+password)

# Sample SQL Query
sql = ("select Distinct UserID, UserName, Count(*) as Count from USCTTDEV.dbo.tblUsage "
"Group By UserID, UserName Order by UserID ASC")

# Pandas reading values from SQL query, and building table
sqlData = pandas.read_sql_query(sql, cnxn)

# Pandas building dataframe, and exporting .xlsx copy of table
df = DataFrame(data=sqlData)

# Pretty Print the table
pprint.pprint(df)
