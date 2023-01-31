import json
from datetime import datetime

import requests
import utils.mssql_database as mssql_database  # module in utils folder

import pandas as pd


class BearerAuth(requests.auth.AuthBase):
    """
    This class will help pass the correct authorization headers into the requests API call.
    """

    def __init__(self, token):
        self.token = token

    def __call__(self, r):
        r.headers["authorization"] = "Bearer " + self.token
        return r


def get_yammer_users(group_id, url, access_token):
    """
    These are the credentials from Yammer Developer's page.
    This is NOT a best practice to put the login in the same file.
    However, this is being done for ease of use and since it is only a small development effort!
    """

    # The max for Yammer is 50, but go ahead and set the max limit.
    params = {
        "per_page": 50,
    }

    # Set default variables
    page = 1
    errors = 0
    more_available = True
    users = []

    # Continue looping until there are no more pages to view
    while more_available:
        try:
            r = requests.get(
                url + f"?page={page}",
                auth=(BearerAuth(access_token)),
                params=params,
            )
            r_json = r.json()

            """
            with open(f"c:\\temp\\yam{page}.json", "w") as fin:
                fin.write(json.dumps(r_json))
            """

            users += r_json.get("users")
            more_available = r_json.get("more_available", False)

            page += 1

        except:
            if errors > 10:
                break
            pass

    # Return the json object
    return json.dumps(users)


def push_to_mssql(df, conn, temp_table, query):
    "This process calls the processes from the mssql_database module in the same folder"

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

    # Create dictionary of columns and data types
    outputdict = mssql_database.sqlcol(df)

    # Clean dataframe values up
    mssql_database.clean_dataframe(df)

    # Create a temp table, and push values to it from dataframe
    mssql_database.create_temp_table(df, conn, temp_table, outputdict)

    # Clean the temp table by values
    mssql_database.clean_temp_table(df, conn, temp_table)

    # Execute query string
    mssql_database.execute_query(conn, query)

    # Get End Time
    end_time = datetime.now()
    total_seconds = (end_time - start_time).total_seconds()
    # stop = (time.time() - start).total_seconds()
    return print(
        f" Rows: {count_row} Columns: {count_col} Total Seconds: {total_seconds}"
    )


def power_bi_yammer():
    """
    This will get all user data for the Power BI Yammer group into .json.
    Then, it will append that data to MSSQL Server, and mark the Active Directory
    table for when people are members of the Power BI Yammer group.
    """

    # This is required information, which you get from the Yammer Developer account
    power_bi_group_id = "eyJfdHlwZSI6Ikdyb3VwIiwiaWQiOiIxNTg2Mzg5NiJ9"
    power_bi_url = (
        f"https://www.yammer.com/api/v1/users/in_group/{power_bi_group_id}.json"
    )
    power_bi_access_token = "12467-7JI1R5o60GBHRkDu82Wg"

    # Get the json response of all Yammer users
    power_bi_users = get_yammer_users(
        power_bi_group_id, power_bi_url, power_bi_access_token
    )

    # Convert json into dataframe
    df = pd.read_json(power_bi_users)

    # Remove underscores from name
    df.columns = df.columns.str.replace("_", "")

    # Keep only emails
    df = df[["email"]]

    # Connect to MSSQL server
    conn = mssql_database.connect_to_database()

    # Update Active Directory table to "No" for all records
    # 1/30 - Had to escape quotes so that it will work with mssql_database.py text replaces
    query = """
        UPDATE TableauLicenses.dbo.tblActiveDirectory 
        SET YammerPowerBI=\''No\''

        UPDATE TableauLicenses.dbo.tblActiveDirectory 
        SET YammerPowerBI=\''Yes\''
        FROM TableauLicenses.dbo.tblActiveDirectory ad 
        INNER JOIN ##tblPowerBIYammer pbi ON pbi.email = ad.Email
        """

    # Clean dataframe, and push to MSSQL
    push_to_mssql(df, conn, "##tblPowerBIYammer", query)


def main():
    power_bi_yammer()


if __name__ == "__main__":
    main()
