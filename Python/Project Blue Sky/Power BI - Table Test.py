# The following code to create a dataframe and remove duplicated rows is always executed and acts as a preamble for your script:

# dataset = pandas.DataFrame(COST_TYPE, FUNCTION_NAME, SUM(VALUE), VALUE_NAME, VALUE_ORDER)
# dataset = dataset.drop_duplicates()

import matplotlib.pyplot as plt

import pandas as pd

# Create DataFrame
df = dataset

# Sort DataFrame by VALUE_ORDER
df = df.sort_values(by="VALUE_ORDER")

# Calculate the cumulative sum for the waterfall steps
df["cumulative"] = df["SUM(VALUE)"].cumsum()

# Create a table visual
fig, ax = plt.subplots(figsize=(10, 6))

# Hide axes
ax.xaxis.set_visible(False)
ax.yaxis.set_visible(False)
ax.set_frame_on(False)

# Create the table
table = ax.table(
    cellText=df.values, colLabels=df.columns, cellLoc="center", loc="center"
)

# Adjust layout
plt.tight_layout()

# Show plot
plt.show()
