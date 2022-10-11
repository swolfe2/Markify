"""
This process was created by Steve Wolfe - Data Visualization CoE

Ensure that you have successfully pip installed requirements.txt!

Required packages needed to work:
https://pypi.org/project/pandas/ - version 1.4.3
https://pypi.org/project/pywin32/ - version 304
https://pypi.org/project/turbodbc/ - version 4.5.5

Process was developed using Python Version 3.10.5

Last update: 9/9/2022

Process steps overview:
1. Create dataframe from flat file
2. Push dataframe to MSSQL server
3. Execute MSSQL stored procedure

"""

import os
import sys
from datetime import datetime

import pandas as pd

import utils.mssql_database as mssql_database  # module in utils folder
from utils.config import DB_NAME, MSSQL_SERVER  # module in utils folder
from utils.send_email import send_error_email  # module in utils folder


def push_to_mssql(df, conn):
    "This process calls the processes from the mssql_database module in the same folder"

    temp_table = "##tblActiveDirectoryTemp"

    # Get dataframe size
    count_row, count_col = (
        df.shape[0],
        df.shape[1],
    )  # gives number of row/column count

    # Get Start Time
    start_time = datetime.now()

    # Fill all NA values with something
    for col in df:
        # get dtype for column
        d_type = df[col].dtype
        # check if it is a number
        if d_type == int or d_type == float:
            df[col].fillna(0, inplace=True)
        else:
            df[col].fillna("", inplace=True)

    print("Creating temp table")

    # Create dictionary of columns and data types
    outputdict = mssql_database.sqlcol(df)

    # Clean dataframe values up
    mssql_database.clean_dataframe(df)

    # Create a temp table, and push values to it from dataframe
    mssql_database.create_temp_table(df, conn, temp_table, outputdict)

    # Clean the temp table by values
    mssql_database.clean_temp_table(df, conn, temp_table)

    # Execute Stored Procedure
    mssql_database.execute_stored_procedure(conn, "dbo.sp_ActiveDirectoryAutomation")

    # Get End Time
    end_time = datetime.now()
    total_seconds = (end_time - start_time).total_seconds()
    # stop = (time.time() - start).total_seconds()
    return print(
        " Rows:"
        + str(count_row)
        + " Columns: "
        + str(count_col)
        + " Total Seconds: "
        + str(total_seconds)
    )


def create_dataframe():
    """This process will create the active directory dataframe utilized in the rest of the automation"""
    file_path = (
        r"\\kcfiles\share\Corporate\ITS\Application Solutions\Shared\Global HR Data"
    )
    file_name = r"ADUsersWithManagementChain.txt"
    full_file_path = os.path.join(file_path, file_name)

    # Get the last time the file was modified
    time_modified = datetime.fromtimestamp(os.path.getmtime(full_file_path))

    # Get the current time
    time_current = datetime.now()

    # Get the difference
    time_difference = time_current - time_modified

    # Get the difference in hours
    time_difference_days = int(divmod(time_difference.total_seconds(), 86400)[0])

    # If it has been more than max_days days since the file was modified, send email and stop process
    max_days = 3
    if time_difference_days > max_days:
        error_message = (
            """It has been """
            + str(time_difference_days)
            + """ days since the """
            + full_file_path
            + """ file was modified, which is more than the """
            + str(max_days)
            + """ day limit allowed by the Tableau automation. Please ensure file is processing correctly."""
        )

        to_addresses = (
            "steve.wolfe@kcc.com; ankit.kesharwani@kcc.com; mario.sarmiento@kcc.com"
        )
        process_step = "Active Directory Automation - Flat File Modified Failure"
        send_error_email(
            error_message=error_message,
            to=to_addresses,
            process_step=process_step,
        )

    # Get current file size, and send email if something is wrong
    file_size = os.path.getsize(full_file_path)
    if file_size < 1000:
        error_message = (
            """There appears to be an issue with the file size of """
            + full_file_path
            + """, with it being less than 1 MB. Please review process steps to ensure the file is being created correctly."""
        )

        to_addresses = (
            "steve.wolfe@kcc.com; ankit.kesharwani@kcc.com; mario.sarmiento@kcc.com"
        )
        process_step = "Active Directory Automation - Flat File Size Failure"
        send_error_email(
            error_message=error_message,
            to=to_addresses,
            process_step=process_step,
        )

        # Connect to MSSQL server
        conn = mssql_database.connect_to_database()

        query = (
            """INSERT INTO TableauLicenses.dbo.tblSentEmails(SentOn, EmailType, ToAddresses, Subject, Message)
        SELECT GETDATE(),'"""
            + process_step
            + """','"""
            + str(to_addresses).replace("'", "''")
            + """','Tableau License Automation Failure: """
            + process_step
            + """','"""
            + error_message
            + """'"""
        )

        mssql_database.execute_query(conn, query)
        sys.exit()

    # Create dataframe from file data
    df = pd.read_csv(full_file_path, sep="|", dtype=str)

    # Add the current date/time to dataframe
    df["CurrentTime"] = str(time_current)
    return df


def main():
    # Create dataframe
    df = create_dataframe()

    # Connect to MSSQL server
    conn = mssql_database.connect_to_database()

    # Appends dataframe to MSSQL Server
    push_to_mssql(df, conn)


if __name__ == "__main__":
    main()
