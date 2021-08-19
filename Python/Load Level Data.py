from turbodbc import connect, make_options
import json
import requests
import pandas as pd


# Set turboodbc options
options = make_options(parameter_sets_to_buffer=1000)

# Set turbodbc connection
mssql_connection = connect(
    driver="ODBC Driver 17 for SQL Server",
    server="USTCAS98.KCC.COM",
    database="USCTTDEV",
    trusted_connection="YES",
    encrypt="YES",
    trustservercertificate="YES",
)

# Put MSSQL results into dataframe
# df = pd.read_sql_query("EXEC USCTTDEV.dbo.sp_LoadLevelData", mssql_connection)

# Export to .csv file on Desktop
# df.to_csv("C://Users//U15405//Desk#top//load_level_dataframe.csv", encoding="utf-8")
# df.to_csv(
#    r"C:\Users\U15405\Desktop\load_level_dataframe.csv",
#    index=False,
#    header=True,
#    encoding="utf-8",
# )


# Set SQL cursor, and execute stored procedure
cursor = mssql_connection.cursor()
query = cursor.execute("EXEC USCTTDEV.dbo.sp_LoadLevelData")

# Convert SQL data results by row to payload dictionary
payload = [
    dict(zip([column[0] for column in cursor.description], row))
    for row in cursor.fetchall()
]

# Do some formatting on the json so that it looks pretty
payload_dumps = json.dumps(payload, indent=4, default=str)
dict_paylod = json.loads(payload_dumps)


# In case you want to look at the JSON output, pretty-ly, put the below back in

# open file for writing
f = open(r"C:\Users\U15405\Desktop\Load Level JSON.txt", "w")

# write file
f.write(json.dumps(json.loads(payload_dumps), indent=4, sort_keys=True, default=str))

# close file
f.close()


print("Done!")
