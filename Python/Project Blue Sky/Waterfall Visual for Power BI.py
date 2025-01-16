import matplotlib.pyplot as plt

import pandas as pd

"""
Created By: Steve Wolfe - Data Viz CoE
Last Modified: 1.15.2025

To get this to render, you will need to create a measure to calculate the sort order of the X-axis:
Waterfall Sort = 
MIN ( V_PBI_YTD_ACTUAL_VS_PLAN_VALUE_ORDER[VALUE_ORDER] )

Then you will need a measure to calculate the total of the value that will be displayed
Waterfall Value = 
SUM ( V_PBI_YTD_ACTUAL_VS_PLAN_VALUE_ORDER[SUM(VALUE)] )

The other values that are within the visual are [COST_TYPE], [FUNCTION_NAME], and [VALUE_NAME].
These are primarily used for visual level filtering, with [VALUE_NAME] appearing on the X-axis.

"""


# Function to wrap label based on max length
def wrap_label(label, max_length):
    words = label.split()
    wrapped_label = ""
    current_line = ""

    for word in words:
        if len(current_line) + len(word) + 1 <= max_length:
            current_line += " " + word if current_line else word
        else:
            wrapped_label += "\n" + current_line if wrapped_label else current_line
            current_line = word

    if current_line:
        wrapped_label += "\n" + current_line if wrapped_label else current_line

    return wrapped_label


# Replace null values in 'Waterfall Value' with 0
dataset["Waterfall Value"] = dataset["Waterfall Value"].fillna(0)

# Sort the dataset by 'Waterfall Sort'
dataset = dataset.sort_values(by="Waterfall Sort")

# Calculate the cumulative sum and shifted cumulative sum
dataset["Cumulative"] = dataset["Waterfall Value"].cumsum()
dataset["Shifted Cumulative"] = dataset["Cumulative"].shift(1).fillna(0)

# Calculate the bar heights
dataset["Bar Height"] = dataset["Waterfall Value"]

# Replace the value of the last column with the cumulative sum excluding the last value
dataset.at[dataset.index[-1], "Bar Height"] = dataset["Cumulative"].iloc[-2]

# Define colors for the bars
colors = [
    (
        "#0046C8"
        if i == 0 or i == len(dataset) - 1
        else "#FF4B15" if dataset["Bar Height"][i] > 0 else "#3AB026"
    )
    for i in range(len(dataset))
]


# Function to format values as $#,0,,.;($#,0,,.))
def format_value(value):
    return f"(${abs(value)/1000000:,.1f}M)" if value < 0 else f"${value/1000000:,.1f}M"


# Determine the maximum length of a single word in VALUE_NAME
max_length = max(len(word) for label in dataset["VALUE_NAME"] for word in label.split())

# Wrap the VALUE_NAME labels based on the maximum length
dataset["Wrapped VALUE_NAME"] = dataset["VALUE_NAME"].apply(
    lambda x: wrap_label(x, max_length)
)

# Plot the waterfall chart
fig, ax = plt.subplots(figsize=(10, 6))

# Variables to control font sizes
data_label_font_size = 12
x_axis_label_font_size = 12

# Plot the bars with respective colors
bar_width = 0.6
for i in range(len(dataset)):
    ax.bar(
        dataset["Wrapped VALUE_NAME"][i],
        dataset["Bar Height"][i],
        bottom=dataset["Shifted Cumulative"][i] if i < len(dataset) - 1 else 0,
        color=colors[i],
        width=bar_width,
    )
    # Add data labels with formatted values above or below the column based on value increase or decrease
    if dataset["Bar Height"][i] >= 0:
        ax.text(
            i,
            (
                (dataset["Shifted Cumulative"][i] + dataset["Bar Height"][i])
                if i < len(dataset) - 1
                else dataset["Bar Height"][i]
            ),
            format_value(dataset["Bar Height"][i]),
            ha="center",
            va="bottom",
            color="black",
            fontsize=data_label_font_size,
        )
    else:
        ax.text(
            i,
            (
                (dataset["Shifted Cumulative"][i] + dataset["Bar Height"][i])
                if i < len(dataset) - 1
                else dataset["Bar Height"][i]
            ),
            format_value(dataset["Bar Height"][i]),
            ha="center",
            va="top",
            color="black",
            fontsize=data_label_font_size,
        )

# Add connecting lines between bars, including the last column
for i in range(1, len(dataset)):
    x0, x1 = i - 1 + bar_width / 2, i - bar_width / 2
    y0, y1 = dataset["Cumulative"][i - 1], (
        dataset["Shifted Cumulative"][i]
        if i < len(dataset) - 1
        else dataset["Bar Height"].iloc[-1]
    )
    ax.plot([x0, x1], [y0, y1], color="grey", linestyle="--", linewidth=1)

# Remove the left, top, and right borders
ax.spines["left"].set_visible(False)
ax.spines["top"].set_visible(False)
ax.spines["right"].set_visible(False)

# Remove the y-axis values
ax.yaxis.set_ticks([])

# Add labels and title with specified font size for x-axis labels
plt.xticks(rotation=45, fontsize=x_axis_label_font_size)

# Define a variable for padding width
padding_width = 0.05

# Add padding between the x-axis and the visualizations by setting ylim with a bit of padding at bottom
y_min, y_max = ax.get_ylim()
ax.set_ylim(y_min - (y_max - y_min) * padding_width, y_max)


plt.tight_layout()

# Show the plot
plt.show()
