# Markify Demo Document

This document showcases Markify's conversion capabilities.

# 1. Header Support

## 1.1 Sub-header (Level 2)

Markify detects Word heading styles and emoji headers like 🔐 Security.

# 2. Formatting & Links

Text can be **bold** or *italic*. Links work too: [Visit GitHub](https://github.com)

# 3. Lists

- Item A

- Item B (nested below)

  - Sub-item B1

# 4. Tables

| ID | Name | Role |
| --- | --- | --- |
| 001 | Alice | Dev |
| 002 | Bob | PM |

# 5. Power Query (M)

```powerquery
let
  Source = Excel.Workbook(File.Contents("data.xlsx"))
in
  Source
```

# 6. DAX

```dax
Revenue :=
SUMX ( Sales, Sales[Qty] * Sales[Price] )
```

# 7. Python

```python
import pandas as pd
def load_data(path):
    return pd.read_csv(path)
```