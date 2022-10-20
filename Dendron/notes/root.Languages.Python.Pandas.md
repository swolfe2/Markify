---
id: 6uj89of8onki629s0uqadyh
title: Pandas
desc: ''
updated: 1666281808445
created: 1666279180113
---

# Intro
[Pandas](https://pandas.pydata.org/) is the most popular package to create tabular (rows/columns) data models in Python. There are many use cases for it, and this note page is going to document some of the different tricks I have picked up.

# Package Standard
The most common way to use Pandas is to alias the package as "pd"

```{python} 
import pandas as pd
```

# Create a Dataframe from Excel with Exact Column Match
This function will read an Excel file, and ensure that the columns it reads are the same exact ones expected from a Python list.

```{python}
def create_dataframe():
    """
    This function will get user input for where an Excel file is located, then perform some validation activity to ensure:
    1) The file has the correct number of columns
    2) The file has the correct column headers
    """
    # Get the filepath to the Excel file
    user_input = input("What is the filepath to the Excel file?")
    # user_input = r"C:\Users\U15405\OneDrive - Kimberly-Clark\Desktop\Licenses.xlsx"

    # Create dataframe from Excel values
    df = pd.read_excel(user_input)

    # Validate that the appropriate column headers are in place
    print("Validating Excel column headers...")
    valid_columns = [
        "KeyName",
        "ProductName",
        "AribaTitle",
        "PurchasingUnit",
        "CompanyCode",
        "ERPReferenceID",
        "FinalApprovalDate",
        "TableauQuote",
        "PurchaseRequest",
        "OrderID",
        "FullQuoteAmount",
        "LicensesInBundle",
    ]

    # Get dataframe size row/column count
    count_row, count_col = (
        df.shape[0],
        df.shape[1],
    )

    # Compare the actual column count against how many columns there should be
    len_valid_columns = len(valid_columns)
    if count_col != len_valid_columns:
        print(
            f"The {input} file currently has {count_col} columns, but should have {len_valid_columns} per the documentation. Please correct, and try again."
        )
        sys.exit()

    # Compare each positional header against what it should be
    excel_columns = df.columns
    for idx, i in enumerate(excel_columns):
        valid_column = valid_columns[idx]
        if i != valid_column:
            print(
                f"The {input} file currently has {i} in column {idx + 1}, but it should have {valid_column} per the documentation. Please correct, and try again."
            )
            sys.exit()

    return df
```

# Push Dataframe to Database
This will take a Pandas dataframe, and push it to a MSSQL database. Note that it uses some functions which are documented in the Interface with Database documentation.
```{python}
def push_to_mssql(df, conn):
    "This process calls the processes from the mssql_database module in the same folder"

    temp_table = "##tblTableauQuotesTemp"

    # Get dataframe size
    count_row, count_col = (
        df.shape[0],
        df.shape[1],
    )  # gives number of row/column count

    # Get Start Time
    start_time = datetime.datetime.now()

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

    # Execute Stored Procedure
    mssql_database.execute_stored_procedure(conn, "dbo.sp_TableauQuotes")

    # Get End Time
    end_time = datetime.datetime.now()
    total_seconds = (end_time - start_time).total_seconds()
    # stop = (time.time() - start).total_seconds()
    return print(
        f"Rows: {count_row} Columns: {count_col} Total Seconds: {total_seconds}"
    )
```

# Loop Through Dataframe
Usually, you'd really rather loop through a Python list or dictionary for speed. However, it really doesn't matter for small automations!
```{python}
for i, row in df.iterrows():
filter_index = i
filter_value_row_1 = row["Column1"]
filter_value_row_2 = row["Column2"]
```

# Filter a Dataframe to Values
This will filter an entire dataframe to specific values.
```{python}
filter_assigned = df_filter.loc[
    (df_filter["Student Name & Grade"] == filter_name)
    & (df_filter["Ranking"] == filter_ranking)
    & (df_filter["Choice"] == filter_choice)
    & (df_filter["Timestamp"] == filter_timestamp),
    "Assigned Flag",
].iat[0]
```

# Get Specific Dataframe Value
This is similar to doing an XLOOKUP or Index/Match against a dataframe.
```{python}
slots_open = df[
    df["Filter Column Choice"] == filter_choice
]["Matching Dataframe Column"].values[0]
```


