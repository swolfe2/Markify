import pyodbc
import pandas
from pandas import DataFrame, ExcelWriter

# SQL Server Connection
server = '158.52.179.7'
database = 'Telephony'
username = 'tcsodbc'
password = 'tcsodbc'
cnxn = pyodbc.connect('Driver={ODBC Driver 17 for SQL Server};SERVER=' +
                      server+';DATABASE='+database+';UID='+username+';PWD='+password)

# Sample SQL Query
sql = 'select * from tblActiveEmployees'

# Pandas reading values from SQL query, and building table
sqlData = pandas.read_sql_query(sql, cnxn)

# Pandas building dataframe, and exporting .xlsx copy of table
df = DataFrame(data=sqlData)
df.to_excel('tblActiveEmployees.xlsx',
            header=True, index=False)
