# Markify Demo Document

This document showcases Markify's conversion capabilities.

# 1. Header Support

## 1.1 Sub-header (Level 2)

Markify detects Word heading styles and converts them to Markdown headers.

# 2. Formatting & Links

Text can be bold or italic. Visit https://github.com for more info.

# 3. Sample Table

| ID | Name | Role |
| --- | --- | --- |
| 001 | Alice | Developer |
| 002 | Bob | PM |
| 003 | Carol | Designer |

# 4. Power Query (M)

```powerquery
let
    Source = Excel.Workbook(File.Contents("data.xlsx")),
```

Output = Source{0}[Data]

in

Output

# 5. DAX Example

Revenue := SUMX(Sales, Sales[Qty] * Sales[Price])

# 6. Python Example

import pandas as pd

def load_data(path):

return pd.read_csv(path)