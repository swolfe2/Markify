import pyodbc
[x for x in pyodbc.drivers() if x.startswith('Microsoft Access Driver')]

connstr = (
    r"DRIVER={Microsoft Access Driver (*.mdb, *.accdb)};"
    r"DBQ=C:\Users\wolfes\Desktop\Innowera Files - DO NOT DELETE\Multi-Family Calendar\Multi-Family Calendar.accdb;"
    )
cnxn = pyodbc.connect(connstr)

# Sample SQL Query to get Data
sql = 'select * from tblMFOpenDeliveryInfoToPush'
cursor = cnxn.cursor()
cursor.execute(sql)
list(cursor.fetchall())

print("Building Pandas Dataframe")