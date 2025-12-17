# Power BI Refresh Performance Optimization Suggestions

Based on the best practices outlined in your project documentation, here is a set of recommendations to help reduce your model's refresh time from 35 minutes to under 25 minutes.

---

## 1. Power Query (M) Optimizations

Your Power Query scripts are the foundation of your data model. Inefficiencies here will have a significant impact on refresh times.

### Key Areas to Investigate:

*   **Ensure Query Folding is Working:**
    *   **What it is:** Query folding is the process where Power Query translates your M script transformations into a single native query that can be executed by the source system (e.g., a SQL server). This is the single most important factor for refresh performance.
    *   **How to Check:** Right-click on the last step in your query and see if "View Native Query" is enabled. If it is greyed out, query folding has been broken at some point.
    *   **Common Folding Breakers:**
        *   Using non-foldable transformations (e.g., `Table.Buffer`, many `Table.AddColumn` operations with complex logic, custom M functions).
        *   Transformations on columns with complex data types.
        *   Accessing data from different sources in the same query.
    *   **Recommendation:** Restructure your queries to ensure as many steps as possible are folded back to the source. Perform transformations that break folding as late as possible.

*   **Reduce Data Volume Early:**
    *   **Issue:** Loading unnecessary columns and rows into Power Query consumes memory and processing time.
    *   **Recommendation:**
        *   Use the "Choose Columns" action to remove any columns you don't need for your report **as one of the very first steps**.
        *   Filter your data as early as possible. For example, if you only need data for the last 2 years, filter it at the source or in an early step.

*   **Review Data Types:**
    *   **Issue:** Incorrect data types can cause errors or prevent query folding. Power Query's automatic "Changed Type" step can sometimes be inefficient.
    *   **Recommendation:** Set the correct data types for your columns as early as possible in your queries. Remove any redundant "Changed Type" steps.

*   **Disable "Allow data preview to download in the background":**
    *   **Location:** `File > Options and settings > Options > Data Load`.
    *   **Why:** This setting can consume resources by refreshing previews for queries you aren't currently viewing. Disabling it can free up resources for the main refresh process.

## 2. DAX and Data Model Optimizations

A poorly designed data model or inefficient DAX can slow down not just report interactivity, but also the processing portion of a refresh.

### Key Areas to Investigate:

*   **Calculated Columns vs. Measures:**
    *   **Issue:** Calculated columns are computed during the refresh process and are stored in the model, increasing its size and refresh time. Measures are calculated at query time and do not impact refresh.
    *   **Recommendation:** Wherever possible, convert calculated columns into measures. If a calculated column is necessary (e.g., for use in a slicer or as a relationship key), try to create it in Power Query instead of DAX.

*   **Relationship Structure:**
    *   **Bi-Directional Relationships:** These can introduce ambiguity and create complex, slow query plans. While sometimes necessary, they should be used with caution.
    *   **Many-to-Many Relationships:** These can also degrade performance and should be avoided if possible by using a bridge table.
    *   **Recommendation:** Review your data model for these types of relationships. In most cases, relationships should be one-to-many and have a single direction.

*   **Auto Date/Time:**
    *   **Issue:** Power BI automatically creates a hidden date table for every date field in your model. This can add a significant number of tables and relationships, bloating the model.
    *   **Recommendation:** Disable "Auto date/time" in the Data Load settings (`File > Options and settings > Options`) and create your own dedicated calendar/date table.

## 3. Advanced Strategy: Incremental Refresh

*   **What it is:** If your dataset is very large, you can configure incremental refresh to only refresh a subset of your data (e.g., the last 7 days) instead of truncating and reloading the entire dataset each time.
*   **When to use it:** This is one of the most effective ways to dramatically reduce refresh times for large fact tables.
*   **How it works:** You will need to define `RangeStart` and `RangeEnd` parameters in Power Query and configure the incremental refresh policy on your table in Power BI Desktop. This requires a Power BI Premium or Premium-Per-User license to work in the service.

---

By systematically reviewing these areas, you should be able to identify the key bottlenecks and significantly improve your model's refresh performance.
