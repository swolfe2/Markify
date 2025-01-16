import matplotlib.pyplot as plt

import pandas as pd

# Sample data
data = {
    "FUNCTION_NAME": [
        "Enterprise",
        "Enterprise",
        "Enterprise",
        "Enterprise",
        "Enterprise",
        "Enterprise",
    ],
    "VALUE_NAME": [
        "YTD Plan",
        "Headcount",
        "Cost per FTE",
        "Other",
        "Forex Variance",
        "YTD Actuals",
    ],
    "VALUE_ORDER": [1, 2, 3, 4, 5, 6],
    "SUM(VALUE)": [95, 17, 78, 100, 45, 335],
    "COST_TYPE": ["LABOR", "LABOR", "LABOR", "LABOR", "LABOR", "LABOR"],
}

# Create DataFrame
df = pd.DataFrame(data)

# Sort DataFrame by VALUE_ORDER
df = df.sort_values(by="VALUE_ORDER")

# Calculate the cumulative sum for the waterfall steps
df["cumulative"] = df["SUM(VALUE)"].cumsum()

# Create the waterfall plot
fig, ax = plt.subplots(figsize=(10, 6))

# Initialize variables for the waterfall plot
previous_value = 0
colors = []

for i in range(len(df)):
    if i == 0:
        # First bar (initial value)
        bar = ax.bar(df["VALUE_NAME"][i], df["SUM(VALUE)"][i], color="blue")
        colors.append("blue")
    elif i == len(df) - 1:
        # Last bar (total value)
        bar = ax.bar(
            df["VALUE_NAME"][i],
            df["SUM(VALUE)"][i],
            bottom=previous_value,
            color="green",
        )
        colors.append("green")
    else:
        # Intermediate bars (changes)
        bar = ax.bar(
            df["VALUE_NAME"][i],
            df["SUM(VALUE)"][i],
            bottom=previous_value,
            color="orange",
        )
        colors.append("orange")

    previous_value += df["SUM(VALUE)"][i]

# Add labels and title
ax.set_xlabel("VALUE_NAME")
ax.set_ylabel("SUM(VALUE)")
ax.set_title("Waterfall Chart")

# Rotate x-axis labels for better readability
plt.xticks(rotation=45)

# Show plot
plt.tight_layout()
plt.show()
