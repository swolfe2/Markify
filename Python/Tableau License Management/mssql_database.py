from datetime import datetime

import pandas as pd
import sqlalchemy
from turbodbc import connect, make_options


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


def connect_to_database(server, db):
    """
    This will open a connection to a MSSQL database
    """
    conn = connect(
        driver="ODBC Driver 17 for SQL Server",
        server=server,
        database=db,
        trusted_connection="YES",
        encrypt="YES",
        trustservercertificate="YES",
    )
    return conn


def create_temp_table(df, db, conn, temp_table, outputdict):
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
    INSERT INTO {db}.{temp_table} {columns}
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
