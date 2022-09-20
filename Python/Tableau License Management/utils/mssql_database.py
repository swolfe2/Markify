from datetime import datetime

import pandas as pd
import sqlalchemy
from turbodbc import connect, make_options

from utils.config import DB_NAME, MSSQL_SERVER  # module in folder


def clean_dataframe(df):
    """
    This will take a dataframe, and change all columns to an object type.
    """
    # Change entire dataframe to object, because holy shit... why are the data types so damn difficult!
    lst = list(df)
    df[lst] = df[lst].astype(str)
    return df


def sqlcol(df):
    """
    This will take a dictionary, loop through a dataframe and change the sqlalchemy types to specific ones
    """
    dtypedict = {}
    for i, j in zip(df.columns, df.dtypes):
        if "object" in str(j):
            dtypedict.update({i: "NVARCHAR(2000)"})

        elif "datetime" in str(j):
            dtypedict.update({i: sqlalchemy.types.NVARCHAR(length=2000)})

        elif "float" in str(j):
            dtypedict.update({i: sqlalchemy.types.NVARCHAR(length=2000)})

        elif "int" in str(j):
            dtypedict.update({i: sqlalchemy.types.NVARCHAR(length=2000)})

    return dtypedict


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


# Executes stored procedure on MSSQL server to append new data to main table, and update existing rows
def execute_stored_procedure(conn, stored_procedure):
    """This will execute a specific MSSQL Stored Procedure"""
    sqlSPString = "EXEC " + stored_procedure
    with conn.cursor() as cursor:
        cursor.execute(str(sqlSPString))
        conn.commit()


# Executes a query on MSSQL Server, and loads rows into dictionary
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


# Executes T-SQL query on MSSQL server
def execute_query(conn, query):
    """This will execute a specific MSSQL T-SQL query"""
    with conn.cursor() as cursor:
        cursor.execute(str(query))
        conn.commit()
