# Power BI Model Review and Best Practices Analyzer (Agent Protocol v2)

## 1. Preamble: Understanding the Environment

This protocol is designed for an AI agent to analyze a Power BI data model. It operates by interacting with the **local Modeling MCP (Model Context Protocol) server** that runs alongside an open Power BI Desktop (`.pbix`) file.

There are two types of MCP servers:
*   **Local Modeling Server:** Provides deep, comprehensive access to the model's structure (tables, DAX, M, relationships). This is the server this protocol uses.
*   **Remote Query Server:** A hosted endpoint for querying published semantic models, primarily using natural language to generate DAX.

This protocol focuses exclusively on the **local server** to perform a detailed, offline analysis for development and best-practice auditing.

## 2. Project Goal

To create a command-line tool that connects to an active Power BI data model, efficiently analyzes its components (Power Query, DAX, and Relationships) in a batch process, and generates a markdown report detailing potential issues and recommendations for improvement based on established best practices.

## 3. Pre-flight Checks

Before execution, verify the following conditions are met:
1.  **Tool Availability:** Ensure the agent has access to the required tools: `connection_operations`, `model_operations`, `glob`, `read_file`, `write_file`.
2.  **PBIX File:** The target Power BI Desktop file (`.pbix`) must be open. The local MCP server only runs when the file is open.

---

## 4. Analysis Sections & Best Practices

The analysis will be divided into three main categories.

### 4.1. Power Query (M) Analysis

**Objective:** Ensure queries are efficient, maintainable, and follow best practices for data modeling.

**Checks to Perform:**
*   **Query Folding:** Identify steps that break query folding.
*   **Hard-Coded Values:** Detect hard-coded file paths, server names, or other values that should be parameterized.
*   **Step Naming:** Check for poorly named or default-named steps (e.g., `#"Changed Type"`).
*   **Inefficient Transformations:** Look for overuse of `Table.Buffer` or late filtering/column removal.
*   **Data Type Conversions:** Ensure data types are set early using `Table.TransformColumnTypes`.
*   **Disable Load:** Check if intermediate/staging queries have "Enable Load" disabled.
*   **Commenting:** Check for complex queries lacking `//` or `/*...*/` comments.
*   **Error Handling:** Look for opportunities to use `try...otherwise`.

### 4.2. DAX Analysis (Measures, Calculated Columns, Calculated Tables)

**Objective:** Ensure DAX code is performant, readable, and leverages the engine efficiently.

**Checks to Perform:**
*   **Calculated Columns vs. Measures:** Identify calculated columns on large tables that are better as measures.
*   **Safe Division:** Replace `/` with the `DIVIDE()` function.
*   **Variable Usage:** Ensure complex expressions use variables (`VAR`) for clarity and efficiency.
*   **Iterator Functions (`SUMX`, `FILTER`):** Check for inefficient or deeply nested iterators.
*   **`SELECTEDVALUE`:** Replace `MAX`/`MIN`/`VALUES` with `SELECTEDVALUE()` for retrieving single values from a filter context.
*   **`COUNTROWS` vs. `COUNT`:** Prefer `COUNTROWS` for counting table rows.
*   **`DISTINCTCOUNT`:** Ensure `DISTINCTCOUNT` is used for counting unique values.
*   **Formatting:** Check for readable code formatting.
*   **Avoid Error Functions:** Replace `IFERROR`/`ISERROR` with safer functions like `DIVIDE`.

### 4.3. Relationship Analysis

**Objective:** Ensure the data model schema is robust, efficient, and avoids ambiguity.

**Checks to Perform:**
*   **Bi-Directional Relationships:** Flag all bi-directional ("both") relationships.
*   **Many-to-Many Relationships:** Identify all many-to-many relationships.
*   **Inactive Relationships:** List any inactive relationships and check for `USERELATIONSHIP` usage.

---

## 5. High-Level Execution Plan (Optimized TMDL Strategy)

### Step 1: Connect to Model
1.  Use `connection_operations` to list available local Power BI instances.
    *   **Command:** `connection_operations(request={'operation': 'ListLocalInstances'})`
2.  If multiple instances are found, present the list to the user and ask them to choose one.
3.  Connect to the chosen instance using its `port` number.
    *   **Command:** `connection_operations(request={'operation': 'Connect', 'dataSource': 'localhost:PORT_NUMBER'})`

### Step 2: Export Entire Model to TMDL
1.  Use `model_operations` to export the *entire* model definition into a local directory named `model_definition`. This is the core strategy to minimize token consumption.
    *   **Command:** `model_operations(request={'operation': 'ExportTMDL', 'tmdlExportOptions': {'filePath': './model_definition'}})`

### Step 3: Build In-Memory Model and Analyze
1.  Use `glob` to find all `.tmdl` files within the `./model_definition` directory.
    *   **Command:** `glob(pattern='**/*.tmdl', dir_path='./model_definition')`
2.  **Build In-Memory Representation:** Before analysis, iterate through the file paths. For each file, read its content and parse the TMDL to build a structured, in-memory representation of the entire model (e.g., a dictionary of tables, each containing its columns, measures, M-expression, etc.). This "bulk load" of the model context allows for more efficient and comprehensive cross-object analysis.
3.  **Analyze the In-Memory Model:** Iterate through the structured in-memory model and apply the analysis checks from Section 4 to each object (table, measure, etc.).

### Step 4: Generate and Write Report
1.  For each issue identified, format the finding into a string that strictly follows the template in Section 6.
2.  Concatenate all formatted issue strings into a single report string.
3.  Write the final report string to a file named `model_review.md`.
    *   **Command:** `write_file(file_path='model_review.md', content=FINAL_REPORT_STRING)`

---
## 6. Output Report Structure

The generated `model_review.md` file must follow this structure precisely for each issue found.

```markdown
### [Brief Title of the Issue]

*   **Location:** Table '[TableName]', Measure/Column '[ObjectName]'

**Current Code:**
```dax
// The exact current DAX or M code snippet with the issue
```

*   **Issue:** [A concise, one-sentence description of the problem.]
*   **Why it's an issue:** [A clear explanation of the negative impact on performance, maintainability, or correctness.]
*   **Refactored Code:**
```dax
// The exact refactored DAX or M code snippet that fixes the issue
```
*   **What the refactor specifically addresses:** [A clear, one-sentence explanation of what the new code does better.]

---
```

## 7. Execution Protocols

### 7.1. Error Handling
*   **Connection Failure:** If connection fails, inform the user and advise them to ensure the PBIX file is open. Do not proceed.
*   **TMDL Export Failure:** If `ExportTMDL` fails, report the error to the user. Do not proceed.
*   **File Read/Parse Failure:** If a `.tmdl` file cannot be read or parsed, log the error and continue analysis with the remaining files. Note the failure in the final report.
*   **Analysis Errors:** If an error occurs during the analysis of a specific object, skip that object, log the error, and continue. Note the skipped object in the final report.

### 7.2. Security & Environment
*   This tool operates on a local instance of Power BI Desktop and does not transmit model data to remote services.
*   All analysis is performed on TMDL files stored in the local working directory.
*   For production or sensitive environments, users should be aware of standard security practices for handling model data, even if it is in a local context.