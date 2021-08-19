import os
import pandas as pd
import seaborn as sns
import matplotlib.pyplot as plt

# Sets the global data frame, used in all other definitions
def globalDataframe():
    # Set global df variable
    global df

    print("Reading base Excel file from folder.")

    # Import data to a dataframe
    df = pd.read_excel(
        os.path.join(os.path.join(os.environ["USERPROFILE"]), "Desktop")
        + "\\sf\\"
        + "datalabshiringassessment.xlsx",
        "Data",
        parse_dates=True,
        engine="openpyxl",
    )
    print("Data imported successfully.")

    # Remove any blank columns that might come over
    df.dropna(how="all", axis=1, inplace=True)

    # Ensure all columns in dataframe other than "Date" are int
    for col in df.columns:
        if col != "Date":
            df[col] = pd.to_numeric(df[col])

    # Keep only the first row, if there are duplicates
    df.duplicated(keep="first")

    # Print total number of rows/columns to terminal
    print(
        "There are "
        + str(len(df))
        + " rows and "
        + str(len(df.columns))
        + " columns in full dataset."
    )


# Creates the critical path variables/aggregations, and matching visualization
def criticalPath():
    # Definine business critical headers
    CriticalPath = ["Shopped", "Started Project", "Added to Cart", "Checkout"]

    # Create an additional field in dataframe that combines the bit fields into a single field
    df["Critical Path"] = df[CriticalPath].apply(
        lambda row: "-".join(row.values.astype(str)), axis=1
    )

    # Create an aggregation dataframe of unique Critical Path values, with sums of Audience and Purchased within 7 days
    dfAgg = (
        df.groupby("Critical Path")
        .agg(
            {
                "Date": "count",  # Get the count of rows
                "Audience": sum,  # Get the total audience
                "Purchased within 7 Days": sum,  # Get the total number purchased
            }
        )
        .reset_index()
    )

    # Calculate total percentage purchased
    dfAgg["Percentage Purchased"] = dfAgg["Purchased within 7 Days"] / dfAgg["Audience"]

    # Sort dataframe descending by Percentage Purchased
    dfAgg.sort_values(by="Percentage Purchased", ascending=False, inplace=True)

    # Reset index in new aggregate dataframe
    dfAgg.reset_index(drop=True, inplace=True)

    # Print total number of rows/columns to terminal
    print(
        "There are "
        + str(len(dfAgg))
        + " rows and "
        + str(len(dfAgg.columns))
        + " columns in aggregation dataset."
    )

    # Present full dataframe
    print(dfAgg)

    # Clear previous plots
    plt.figure()

    # Plot horizontal barplot
    plt.figure(figsize=(20, 10))
    ax = sns.barplot(
        x="Percentage Purchased",
        y="Critical Path",
        data=dfAgg,
        orient="h",
        palette="flare_r",
    )
    ax.set(title="Total Success Percent by Critical Path")

    # Label each bar in barplot
    for p in ax.patches:
        height = p.get_height()
        width = p.get_width()
        # Adding text to each bar
        ax.text(
            width,
            p.get_y() + height / 2.0,
            s="{:.6f}".format(width),
            fontsize=8,
            fontweight="bold",
            ha="left",
            va="center",
        )

    # Save plot as "Total Success Percent by Critical Path"
    plt.savefig(
        os.path.join(os.path.join(os.environ["USERPROFILE"]), "Desktop")
        + "\\sf\\"
        + "Python - Total Success Percent by Critical Path.png"
    )
    print("Total Success Percent by Critical Path.png saved to folder")


# Creates the full path, based on all variables, dataframe aggregation and visualization for top 25 rows
def fullPath():

    # Get full path, all variables
    FullPath = [
        "Shopped",
        "Started Project",
        "Added to Cart",
        "Checkout",
        "Uploaded Photos",
        "Visited on Previous Day",
        "# of Different Products",
        "Number of Platforms",
    ]

    # Create an additional field in dataframe that combines the bit fields into a single field
    df["Full Path"] = df[FullPath].apply(
        lambda row: "-".join(row.values.astype(str)), axis=1
    )

    # Create an aggregation dataframe of unique Full Path values, with sums of Audience and Purchased within 7 days
    dfAgg2 = (
        df.groupby("Full Path")
        .agg(
            {
                "Date": "count",  # Get the count of rows
                "Audience": sum,  # Get the total audience
                "Purchased within 7 Days": sum,  # Get the total number purchased
            }
        )
        .reset_index()
    )

    # Print total number of rows/columns to terminal
    print(
        "There are "
        + str(len(dfAgg2))
        + " rows and "
        + str(len(dfAgg2.columns))
        + " columns in full aggregation dataset."
    )

    # Calculate total percentage purchased
    dfAgg2["Percentage Purchased"] = (
        dfAgg2["Purchased within 7 Days"] / dfAgg2["Audience"]
    )

    # Sort dataframe descending by Percentage Purchased
    dfAgg2.sort_values(by="Percentage Purchased", ascending=False, inplace=True)

    # Count the number of unique dates in dataframe agg
    uniqueDates = df["Date"].nunique()

    # Only keep rows that happen 75% of the time, based on unique date count
    dateIndex = dfAgg2[dfAgg2["Date"] < (uniqueDates * 0.75)].index

    # Delete these row indexes from dataFrame
    dfAgg2.drop(dateIndex, inplace=True)

    # Reset index in new aggregate dataframe
    dfAgg2.reset_index(drop=True, inplace=True)

    # Keep only top 25 rows from dataframe
    dfAgg2 = dfAgg2.head(25)

    # Print total number of rows/columns to terminal
    print(
        "There are "
        + str(len(dfAgg2))
        + " rows and "
        + str(len(dfAgg2.columns))
        + " columns in limited aggregation dataset."
    )

    # Present full dataframe
    print(dfAgg2)

    # Clear previous plots
    plt.figure()

    # Plot horizontal barplot
    plt.figure(figsize=(30, 15))
    ax2 = sns.barplot(
        x="Percentage Purchased",
        y="Full Path",
        data=dfAgg2,
        orient="h",
        palette="flare_r",
    )
    ax2.set(title="Total Success Percent by Full Path")

    # Label each bar in barplot
    for p2 in ax2.patches:
        height2 = p2.get_height()
        width2 = p2.get_width()
        # Adding text to each bar
        ax2.text(
            width2,
            p2.get_y() + height2 / 2.0,
            s="{:.6f}".format(width2),
            fontsize=15,
            fontweight="bold",
            ha="left",
            va="center",
        )

    # Save plot as "Total Success Percent by Full Path"
    plt.savefig(
        os.path.join(os.path.join(os.environ["USERPROFILE"]), "Desktop")
        + "\\sf\\"
        + "Python - Total Success Percent by Full Path.png"
    )
    print("Total Success Percent by Full Path.png saved to folder")


def multiVariate():
    corr_df = df.corr(method="pearson")

    # Clear previous plots
    plt.figure()

    plt.figure(figsize=(15, 15))
    sns.heatmap(corr_df, annot=True, annot_kws={"size": 15}, linewidths=0.5)

    # Save plot as "Total Success Percent by Critical Path"
    plt.savefig(
        os.path.join(os.path.join(os.environ["USERPROFILE"]), "Desktop")
        + "\\sf\\"
        + "Python - Multivariate Analysis.png"
    )
    print("Python - Multivariate Analysis.png saved to folder")


# Sets global data frame
globalDataframe()

# Outputs for critical path only
criticalPath()

# Outputs for all int fields
fullPath()

# Run multivariate analysis to see what all moves together
multiVariate()
