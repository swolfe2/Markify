# Import the pandas library
import pandas as pd

# Create a DataFrame with one column "col1" that contains a list of integers in each row
df = pd.DataFrame({"col1": [[602192, 123123], 602290, 602192, 600291, 600129, 602324]})

# Add a new column "col2" to the DataFrame that contains the length of the list in each row of "col1"
df["col2"] = df["col1"].apply(lambda x: len([x]))

# Add a new column "col3" to the DataFrame that contains the length of the list in each row of "col1", or 1 if the element is not a list
df["col3"] = df["col1"].apply(lambda x: len(x) if isinstance(x, list) else 1)

# Print the DataFrame
print(df)
