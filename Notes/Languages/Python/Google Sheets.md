# Intro
For documentation on Python and Google Sheets, be sure to view the [Sheets API Python Quickstart guide](https://developers.google.com/sheets/api/quickstart/python). This will create a .json file that you must have in the working directory, which is used for authentication with the Sheets API. Also, the system account using this authentication must also be added to the Edit credentials of the Google Sheet.

# Packages
```python
"""
Process created with the following:
Python Vers: 3.10.6 (64-bit)
Google client libs from Quickstart guide
https://developers.google.com/sheets/api/quickstart/python
Package information:
google-api-core             2.8.2    
google-api-python-client    2.57.0   
google-auth                 2.10.0   
google-auth-httplib2        0.1.0    
google-auth-oauthlib        0.5.2    
googleapis-common-protos    1.56.4   
gspread                     5.4.0
gspread-dataframe           3.3.0
pandas                      1.4.3
Other Notes:
1) MUST have powell-high-school-service-account.json file in working directory
"""

import os
from datetime import datetime

import gspread
import pandas as pd
from gspread_dataframe import set_with_dataframe

pd.options.mode.chained_assignment = None
```

# Authenticate with Google Sheets
```python
def auth():
    """
    This authenticates using the gspread library against the service account .json file.
    The file MUST be in the same working directory as the .py file!
    This will also force other subprocesses to use the same standard Google Sheet connection.
    Also, you need to make sure you've shared the sheet with the email address from the Google API file
    8.22 - SW - Updated filepath location in GC to handle Mac and Windows paths
    """
    print("Authenticating...")
    filepath = os.path.dirname(os.path.abspath(__file__))
    global GC
    GC = gspread.service_account(
        os.path.join(filepath, "powell-high-school-service-account.json")
    )
    global GS
    GS = GC.open_by_key("PLACE THE SHEET ID HERE")
    print("Authenticated!")
```

# Create a Dataframe From a Specific Google Sheet
```python
def get_database_df():
    """
    This will create a global dataframe of form response data that can be used in other processes
    Comes from the "Database" tab of the Sheet
    """
    print("Getting Database tab values...")
    # get worksheet by title
    worksheet = GS.worksheet("Database")

    global DATABASE_DF
    DATABASE_DF = pd.DataFrame(worksheet.get_all_values())
    DATABASE_DF = DATABASE_DF.iloc[1:, :]  # get rid of opening header
    new_header = DATABASE_DF.iloc[0]  # grab the first row for the header
    DATABASE_DF = DATABASE_DF[1:]  # take the data less the header row
    DATABASE_DF.columns = new_header  # set the header row as the df header
    print(
        "Database values loaded with "
        + str(DATABASE_DF.shape[0])
        + " rows and "
        + str(DATABASE_DF.shape[1])
        + " columns!"
    )
```

# Create a Dataframe From a Specific Google Sheet with Explicit Types
```python
def get_allotment_df():
    """
    This will create a global dataframe of club sizes that can be used in other processes
    Comes from the "Monitor and Setup" tab of the Sheet
    """
    print("Getting Allotment dataframe...")
    # get worksheet by title
    worksheet = GS.worksheet("Monitor and Setup")

    global ALLOTMENT_DF
    ALLOTMENT_DF = pd.DataFrame(worksheet.get("L2:O1000"))
    new_header = ALLOTMENT_DF.iloc[0]  # grab the first row for the header
    ALLOTMENT_DF = ALLOTMENT_DF[1:]  # take the data less the header row
    ALLOTMENT_DF.columns = new_header  # set the header row as the df header
    print(
        "Allotment values loaded with "
        + str(ALLOTMENT_DF.shape[0])
        + " rows and "
        + str(ALLOTMENT_DF.shape[1])
        + " columns!"
    )
    ALLOTMENT_DF["Open Slots"] = ALLOTMENT_DF["Num. Slots"]
    ALLOTMENT_DF["Filled Slots"] = 0
    ALLOTMENT_DF = ALLOTMENT_DF.astype(
        {
            "Pasted Club Name": str,
            "Name Matches": str,
            "Index": int,
            "Num. Slots": int,
            "Open Slots": int,
            "Filled Slots": int,
        }
    )
```

# Push Dataframe to Google Sheets
This will take a Dataframe, and push it back to Google Sheets on a specific tab after clearing the Sheet.
```python
def push_to_sheets():
    """
    This will push the finalized dataframes to Google Sheets
    """
    print("Pushing main data to Sheets on Python Club Assignments")
    ws = GS.worksheet("Python Club Assignments")
    # write to Google Sheet
    ws.clear()
    set_with_dataframe(
        worksheet=ws,
        dataframe=ASSIGNMENT_DF_FINAL,
        include_index=False,
        include_column_header=True,
        resize=True,
    )

    print("Pushing allotment data to Sheets on Python Club Fillments")
    ws = GS.worksheet("Python Club Fillments")
    # write to Google Sheet
    ws.clear()
    set_with_dataframe(
        worksheet=ws,
        dataframe=ALLOTMENT_DF_FINAL,
        include_index=False,
        include_column_header=True,
        resize=True,
    )
```

# Powell High School Sorting Hat
This function uses a lot of really neat things, looping through dataframes and comparing values between one record and an index against another one. This would be like comparing how many open slots exist in club selections, and adding students to rosters until the allotment is full. Note the use of the [iterrows()](https://pandas.pydata.org/docs/reference/api/pandas.DataFrame.iterrows.html) function from Pandas to loop through dataframe. Typically, you'd want to use lists/dictionaries since they're faster. However, it really doesn't matter for small automations! #DoWhatFeelsGood

```python
def sorting_hat():
    """
    This process will take all of the dataframes that have been created above,
    sort them by student request, and then assign students to each group until full.
    Once the group is full, then it will not allow other students into it.
    """

    # Use this array to rename specific indexes from dataframes
    column_renames = ["Choice", "Points"]

    # Create dataframe of 1st place options
    df_first_place = DATABASE_DF[
        [
            "Student Name & Grade",
            "Choice #1 (this is your top pick and the one you want the most)",
            "1st Choice Points",
            "Timestamp",
            "Integer Grade",
        ]
    ]
    df_first_place["Ranking"] = "First Choice"
    df_first_place["Ranking Integer"] = 1
    df_first_place_old_names = df_first_place.columns[
        [1, 2]
    ]  # Remember they're index 0
    df_first_place.rename(
        columns=dict(zip(df_first_place_old_names, column_renames)),
        inplace=True,
    )
    # print(df_first_place)

    # Create dataframe of 2nd place options
    df_second_place = DATABASE_DF[
        [
            "Student Name & Grade",
            "Choice #2",
            "2nd Choice Points",
            "Timestamp",
            "Integer Grade",
        ]
    ]
    df_second_place["Ranking"] = "Second Choice"
    df_second_place["Ranking Integer"] = 2
    df_second_place_old_names = df_second_place.columns[
        [1, 2]
    ]  # Remember they're index 0
    df_second_place.rename(
        columns=dict(zip(df_second_place_old_names, column_renames)),
        inplace=True,
    )

    # Create dataframe of 3rd place options
    df_third_place = DATABASE_DF[
        [
            "Student Name & Grade",
            "Choice #3",
            "3rd Choice Points",
            "Timestamp",
            "Integer Grade",
        ]
    ]
    df_third_place["Ranking"] = "Third Choice"
    df_third_place["Ranking Integer"] = 3
    df_third_place_old_names = df_third_place.columns[
        [1, 2]
    ]  # Remember they're index 0
    df_third_place.rename(
        columns=dict(zip(df_third_place_old_names, column_renames)),
        inplace=True,
    )

    # Create dataframe of 4th place options
    df_fourth_place = DATABASE_DF[
        [
            "Student Name & Grade",
            "Choice #4",
            "4th Choice Points",
            "Timestamp",
            "Integer Grade",
        ]
    ]
    df_fourth_place["Ranking"] = "Fourth Choice"
    df_fourth_place["Ranking Integer"] = 4
    df_fourth_place_old_names = df_fourth_place.columns[
        [1, 2]
    ]  # Remember they're index 0
    df_fourth_place.rename(
        columns=dict(zip(df_fourth_place_old_names, column_renames)),
        inplace=True,
    )

    # Create union/merge of all dataframes so far
    frames = [df_first_place, df_second_place, df_third_place, df_fourth_place]
    df_union = pd.concat(frames)  # Union 'em together
    df_union["Index"] = df_union.reset_index().index + 1  # Create new index column
    df_union.set_index("Index", inplace=True)  # Reset dataframe index to new column

    # Add flags for assigned and unassigned
    df_union["Assigned Flag"] = ""

    # Add flag to mark as duplicated
    df_union["Duplicate"] = (
        df_union.groupby(["Student Name & Grade", "Choice"]).cumcount() + 1
    )

    # If duplicate flag <>1, mark Assigned Flag as "Duplicate Choice". Will only keep first selection.
    df_union["Assigned Flag"] = df_union["Duplicate"].apply(
        lambda x: "Not Assigned | Duplicate" if x != 1 else ""
    )

    # Duplicate dataframe
    # df_union_dupes = df_union[df_union["Assigned Flag"] == "Duplicate"]
    # print(df_union_dupes)

    # Force data types
    df_union = df_union.astype(
        {
            "Student Name & Grade": str,
            "Choice": str,
            "Points": int,
            "Integer Grade": int,
            "Ranking": str,
            "Ranking Integer": int,
            "Assigned Flag": str,
            "Duplicate": int,
        }
    )
    df_union["Timestamp"] = pd.to_datetime(df_union["Timestamp"])
    # print(df_union.dtypes)

    # Sort unioned dataframe by descending order by multiple fields
    df_union.sort_values(
        by=["Integer Grade", "Timestamp", "Ranking Integer"],
        ascending=[False, True, True],
        na_position="first",
        inplace=True,
    )
    # print(df_union)

    df_union["Unique"] = df_union["Student Name & Grade"] + df_union[
        "Timestamp"
    ].astype(str)

    # Get unique names from df_union for looping
    unique_names = df_union["Unique"].unique()
    for unique in unique_names:

        # Create small dataframe for each student to loop and update
        df_filter = df_union.loc[df_union["Unique"] == unique]

        # Set parent variables from top row
        filter_name = df_filter["Student Name & Grade"].iat[0]
        filter_timestamp = df_filter["Timestamp"].iat[0]
        filter_grade = df_filter["Integer Grade"].iat[0]  # unused, but for debugging

        print("Assigning student: " + filter_name)

        # Iterate over rows, and attempt to assign. If a group
        # can be assigned, mark the rest of the rows to prevent
        # them from being assigned
        for i, row in df_filter.iterrows():

            filter_index = i  # unused, but for debugging
            filter_ranking = row["Ranking"]
            filter_choice = row["Choice"]

            # Get the current Assigned Flag from the df_filter dataframe since it's much smaller
            # if you comment out code that updates df_filter, you'll need to update to df_union
            filter_assigned = df_filter.loc[
                (df_filter["Student Name & Grade"] == filter_name)
                & (df_filter["Ranking"] == filter_ranking)
                & (df_filter["Choice"] == filter_choice)
                & (df_filter["Timestamp"] == filter_timestamp),
                "Assigned Flag",
            ].iat[0]

            if len(filter_assigned) == 0:  # Skip rows that have already been assigned

                # if there's no choice, update df_union["Assigned Flag"] = "No Choice"
                if len(filter_choice) == 0:
                    no_selection_text = "Not Assigned | No Choice Selected"  # Set what you want it to say here; want to keep the pipe in though for final

                    # Apply text to the df_filter in case you want to print it out to watch it work
                    # You can comment this whole thing out if you want to increase speed.
                    df_filter.loc[
                        (df_filter["Student Name & Grade"] == filter_name)
                        & (df_filter["Ranking"] == filter_ranking),
                        "Assigned Flag",
                    ] = no_selection_text
                    # print(df_filter)

                    # Update the Assigned Flag of the main dataframe with the text for the option/student
                    df_union.loc[
                        (df_union["Student Name & Grade"] == filter_name)
                        & (df_union["Ranking"] == filter_ranking),
                        "Assigned Flag",
                    ] = no_selection_text

                else:  # There is a choice that has been selected

                    # Get values from ALLOTMENT_DF to see if there's space to assign
                    slots = ALLOTMENT_DF[
                        ALLOTMENT_DF["Pasted Club Name"] == filter_choice
                    ]["Num. Slots"].values[
                        0
                    ]  # unused, but for debugging
                    slots_open = ALLOTMENT_DF[
                        ALLOTMENT_DF["Pasted Club Name"] == filter_choice
                    ]["Open Slots"].values[0]
                    slots_filled = ALLOTMENT_DF[
                        ALLOTMENT_DF["Pasted Club Name"] == filter_choice
                    ]["Filled Slots"].values[0]

                    if int(slots_open) > 0:
                        # Add 1 to the counter of slots open
                        ALLOTMENT_DF.loc[
                            (ALLOTMENT_DF["Pasted Club Name"] == filter_choice),
                            "Open Slots",
                        ] = (
                            slots_open - 1
                        )

                        # Add 1 to the counter of slots filled
                        ALLOTMENT_DF.loc[
                            (ALLOTMENT_DF["Pasted Club Name"] == filter_choice),
                            "Filled Slots",
                        ] = (
                            slots_filled + 1
                        )

                        # Update the Assigned Flag of the main dataframe with the text for the option/student
                        df_union.loc[
                            (df_union["Student Name & Grade"] == filter_name)
                            & (df_union["Ranking"] == filter_ranking)
                            & (df_union["Timestamp"] == filter_timestamp),
                            "Assigned Flag",
                        ] = filter_choice

                        # Update the Assigned Flag of the main dataframe when null to Previously Assigned
                        df_union.loc[
                            (df_union["Student Name & Grade"] == filter_name)
                            & (df_union["Assigned Flag"] == "")
                            & (df_union["Timestamp"] == filter_timestamp),
                            "Assigned Flag",
                        ] = (
                            "Previously Assigned | " + filter_choice
                        )

                        # Update the Assigned Flag of the filter dataframe when null to Previously Assigned
                        # You can comment this whole thing out if you don't want to see it to improve speed
                        df_filter.loc[
                            (df_filter["Student Name & Grade"] == filter_name)
                            & (df_filter["Ranking"] == filter_ranking)
                            & (df_filter["Timestamp"] == filter_timestamp),
                            "Assigned Flag",
                        ] = filter_choice
                        df_filter.loc[
                            (df_filter["Student Name & Grade"] == filter_name)
                            & (df_filter["Assigned Flag"] == "")
                            & (df_filter["Timestamp"] == filter_timestamp),
                            "Assigned Flag",
                        ] = (
                            "Previously Assigned | " + filter_choice
                        )

                    else:  # If the club is at capacity, and cannot take more students
                        # Update the Assigned Flag of the main dataframewith text stating "At Capacity"
                        df_union.loc[
                            (df_union["Student Name & Grade"] == filter_name)
                            & (df_union["Ranking"] == filter_ranking)
                            & (df_union["Timestamp"] == filter_timestamp),
                            "Assigned Flag",
                        ] = (
                            "At Capacity | " + filter_choice
                        )

                        # Update the Assigned Flag of the main dataframewith text stating "At Capacity"
                        # You can comment this whole thing out if you don't want to see it to improve speed
                        df_filter.loc[
                            (df_filter["Student Name & Grade"] == filter_name)
                            & (df_filter["Ranking"] == filter_ranking)
                            & (df_filter["Timestamp"] == filter_timestamp),
                            "Assigned Flag",
                        ] = (
                            "At Capacity | " + filter_choice
                        )

        # print(df_filter)

    # print(df_union)
```