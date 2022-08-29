import datetime
import os

import numpy as np
import pandas as pd


def main():
    """
    This function will loop over .xlsx files in a folder, and append all data
    into a single dataframe, which will then be exported to a single place.
    """

    # You would change this variable to the \\kcfiles\share\ path to your files
    data_file_folder = os.path.join(
        os.path.join(os.environ["USERPROFILE"]), "Desktop\\Excel File Example\\"
    )

    # Standardized Excel sheet name
    sheet_name = "Data"

    def make_folder(data_file_folder):
        """
        Check to see if Excel File Example folder exists on current Desktop
        If does not exist, create it.
        Also, if it does exist, it will delete any files that exist.
        """
        print("Ensuring folder exists")
        if not os.path.exists(data_file_folder):
            os.makedirs(data_file_folder)

        print("Deleting any files that exist in folder...")
        for f in os.listdir(data_file_folder):
            os.remove(os.path.join(data_file_folder, f))

    def create_excel_files(loops, data_file_folder, sheet_name):
        """
        This function will create x number of Excel files.
        Data is a randomized dataframe with specific shape.

        https://pandas.pydata.org/docs/reference/api/pandas.DataFrame.to_excel.html
        https://www.interviewqs.com/ddi-code-snippets/create-df-random-integers
        """
        i = 1
        while i <= loops:
            # Create dataframe with 15 random rows and 4 columns
            df = pd.DataFrame(
                np.random.randint(0, 100, size=(15, 4)), columns=list("ABCD")
            )
            # Add timestamp column
            df["Current Time"] = datetime.datetime.utcnow().strftime(
                "%Y-%m-%dT%H:%M:%SZ"
            )

            print("Creating Excel file " + str(i) + " out of " + str(loops))
            # Create Excel file from dataframe, and place in folder
            df.to_excel(
                data_file_folder + str(i) + ".xlsx", sheet_name=sheet_name, index=False
            )

            i += 1

        print("All " + str(loops) + " Excel files created.")

    def append_dataframes(data_file_folder, sheet_name):
        """
        This function will loop through a directory,
        If file ends with .xlsx, it will append the sheet_name
        to a single dataframe, and save a final Excel file to
        the working directory.

        Also, df.append is deprecated. Use the array/concat method instead.

        https://pandas.pydata.org/docs/reference/api/pandas.DataFrame.to_excel.html
        https://pandas.pydata.org/docs/reference/api/pandas.concat.html
        """
        print("Creating final dataframe and Excel file...")
        dfs = []
        for file in os.listdir(data_file_folder):
            if file.endswith(".xlsx"):
                print("Appending " + str(file))
                data = pd.read_excel(data_file_folder + file, sheet_name=sheet_name)
                dfs.append(data)

        # Create the final dataframe, and export to Excel file
        df = pd.concat(dfs, ignore_index=True)
        df = df.loc[
            :, ~df.columns.str.contains("^Unnamed")
        ]  # Delete any unnamed columns from final dataframe
        df.to_excel(
            data_file_folder + "Final Data.xlsx", sheet_name=sheet_name, index=False
        )
        print("Final Excel file created!")

    make_folder(data_file_folder)  # Make the Desktop folder if it doesn't exist

    create_excel_files(
        3, data_file_folder, sheet_name
    )  # Create x number of Excel files with random dataframes

    append_dataframes(
        data_file_folder, sheet_name
    )  # Create the finalized Excel file from all available files


"""
You always want to wrap your automation fo;e like this for function reusability
For more info: https://www.freecodecamp.org/news/if-name-main-python-example/
"""
if __name__ == "__main__":
    main()
