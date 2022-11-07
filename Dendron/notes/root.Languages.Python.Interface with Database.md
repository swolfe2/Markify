---
id: g89myd5y5z1f4fgup52vgei
title: Interface with Database
desc: ''
updated: 1667857016960
created: 1666274299083
---

# Intro
When it comes to interfacing Python with a database, the fastest option I have found is [turbodbc](https://turbodbc.readthedocs.io/en/latest/). Here are some different things that I have done to take a Pandas dataframe, and push it to MSSQL or read data from a MSSQL server.

# Packages
```{python} 
from datetime import datetime

import pandas as pd
import sqlalchemy
from turbodbc import connect, make_options
```

## Other Required Things
Inside a config.py file in the same directory, I keep the server and database variables. That way, should I need to change the variables in the future, it makes it much easier to implement those changes.

Examples:
```{python} 
MSSQL_SERVER = "USTCAS24"
DB_NAME = "TableauLicenses"
```
Also, many of the functions below will use outputs from other functions. Be sure to search to see if the function utlizes an output prior to just copy/pasting the code.

# Cleaning a Dataframe
Pandas dataframes can have a bunch of different data types that can have difficulty in translating to MSSQL server. For ease of use, I clean the dataframe to make everything a string.

```{python} 
def clean_dataframe(df):
    """
    This will take a dataframe, and change all columns to an object type.
    """
    # Change entire dataframe to object, because holy shit... why are the data types so damn difficult!
    lst = list(df)
    df[lst] = df[lst].astype(str)
    return df
```

# Changing Dictionary Types
Sometimes, it can be helpful to change datatypes for a dictionary. To make things easy, I always just change things to strings.

```{python} 
def sqlcol(df):
    """
    This will take a dictionary, loop through a dataframe and change the sqlalchemy types to specific ones
    """
    dtypedict = {}
    for i, j in zip(df.columns, df.dtypes):
        if "object" in str(j):
            dtypedict.update({i: "NVARCHAR(2000)"})

        elif "datetime" in str(j):
            dtypedict.update({i: "NVARCHAR(2000)"})

        elif "float" in str(j):
            dtypedict.update({i: "NVARCHAR(2000)"})

        elif "int" in str(j):
            dtypedict.update({i: "NVARCHAR(2000)"})

    return dtypedict
```

# Connecting to a Database
A standard thing that will need to be done for each activty on a database is establishing a connection. The connection will remain active until the process file ends. This also applies to any temp tables made in the temp database, which will be automatically dropped when the connection closes.

```{python} 
def connect_to_database():
    """
    This will open a connection to a MSSQL database
    """
    conn = connect(
        driver="ODBC Driver 17 for SQL Server",
        server=MSSQL_SERVER,
        database=DB_NAME,
        trusted_connection="YES",
        encrypt="YES",
        trustservercertificate="YES",
    )
    return conn
```

# Creating a Temp Table
A very common ETL process is creating a temp table within the temp database in MSSQL server. These tables are used within stored procedures to Append/Update/Delete data that exists on regular tables. Note that there are required variables, which are outputs of processes above in this documentation.

```{python} 
def create_temp_table(df, conn, temp_table, outputdict):
    """
    This will create a temp table from a dataframe with connection to MSSQL
    """

    print("Creating temp table")
    # This temp table contains the individual dataframe data
    print(df.head())
    # Ensure there is no temp table already on the temp database
    with conn.cursor() as cursor:
        cursor.execute(f"DROP TABLE IF EXISTS {temp_table}")
        conn.commit()

    # Create temp table, with default datatypes and standard headers
    temp_sql_create = "CREATE TABLE " + temp_table + "("
    for key, value in outputdict.items():
        temp_sql_create += "[" + key + "] " + value + ", "
    temp_sql_create += ")"
    with conn.cursor() as cursor:
        cursor.execute(temp_sql_create)
        conn.commit()

    # get the array of values
    values = [df[col].values for col in df.columns]

    # preparing columns
    columns = "(["
    columns += "], [".join(df.columns)
    columns += "])"

    # preparing value place holders
    val_place_holder = ["?" for col in df.columns]
    sql_val = "("
    sql_val += ", ".join(val_place_holder)
    sql_val += ")"

    # writing sql query for turbodbc
    sql = f"""
    INSERT INTO {DB_NAME}.{temp_table} {columns}
    VALUES {sql_val}
    """

    # inserts data, for real
    with conn.cursor() as cursor:
        try:
            cursor.executemanycolumns(sql, values)
            conn.commit()
        except Exception as e:
            conn.rollback()
            print("Failed to upload: " + str(e))
```

# Cleaning a Temp Table
When creating a temp table, there may be values that need to be updated to null which were filled with another value in Pandas. This will loop through all of the columns in the temp_table variable, and replace any that match the list with null.

```{python} 
def clean_temp_table(df, conn, temp_table):
    """This will loop through all columns in the temp table, and update to null where they are certain values"""

    for col in df.columns:

        sqlCleanString = (
            "UPDATE "
            + temp_table
            + " SET ["
            + col
            + "] = NULL WHERE ["
            + col
            + "] IN ('0', '0.0', 'nan', '1900-01-01', '')"
        )
        # cleans the previous head insert
        with conn.cursor() as cursor:
            cursor.execute(str(sqlCleanString))
            conn.commit()

        """
        if "Date" in col:
            sqlCleanString = (
                "UPDATE "
                + temp_table
                + " SET ["
                + col
                + "] = CONVERT(NVARCHAR(10), CONVERT(DATE, REPLACE(["
                + col
                + "],'.0',''), 103), 101)"
            )
            # cleans the previous head insert
            with conn.cursor() as cursor:
                cursor.execute(str(sqlCleanString))
                conn.commit()
        """
```

# Execute a Stored Procedure
Executing a stored procedure is very easy, and only requires a string with the stored procedure name in it to be passed in. This would be the same thing used in the EXEC statement in SQL Server.

```{python} 
def execute_stored_procedure(conn, stored_procedure):
    """This will execute a specific MSSQL Stored Procedure"""
    sqlSPString = "EXEC " + stored_procedure
    with conn.cursor() as cursor:
        cursor.execute(str(sqlSPString))
        conn.commit()
```

# Get Query Results into Python Dictionary
This will query a database, utilizing a specific query string that is passed in formatted as "SELECT ..." and return the results into a Python dictionary which can be further processed.

```{python} 
def execute_query_to_dictonary(conn, query):
    """This will execute a specific query, and load the results into a Pandas dataframe and dictionary"""
    with conn.cursor() as cursor:
        cursor.execute(str(query))

        # Get all rows into list
        data = cursor.fetchall()

        # Get all columns into list
        columns = [column[0] for column in cursor.description]

        # Create a dataframe from rows and columns
        df = pd.DataFrame(data=data, columns=columns)

        # Create a dictionary from the dataframe for faster iterations
        data_dict = df.to_dict("index")

        return data_dict
```

# Execute a Query String
You can execute any query, simply by passing the query string into this function.

```{python} 
def execute_query(conn, query):
    """This will execute a specific MSSQL T-SQL query"""
    with conn.cursor() as cursor:
        cursor.execute(str(query))
        conn.commit()
```