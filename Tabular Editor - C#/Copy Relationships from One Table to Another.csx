/*
===========================================================================================
RELATIONSHIP MIGRATION SCRIPT WITH OPTIONAL CLEANUP
-------------------------------------------------------------------------------------------
Author: Steve Wolfe (Data Viz CoE)
Purpose:
This script is designed for use in Tabular Editor to migrate all relationships from an 
existing table (e.g., a DAX-generated "Date" table) to a new table (e.g., a Power Query-
based "Date Table"). It preserves all relationship properties and optionally deletes the 
original relationships to avoid ambiguous paths or validation issues.

Key Features:
- Collects all relationships involving the old table
- Recreates each relationship using the new table’s column
- Preserves:
    • Active/inactive status
    • Cross-filtering behavior (with explicit enum handling)
    • Security filtering
    • Referential integrity
    • Join-on-date behavior
    • Cardinality (from/to)
- Optionally deletes old relationships (commented section)
- Logs success/failure of each relationship recreation
- Identifies failed bidirectional relationships and suggests remediation

Use Case:
Ideal for replacing a shared dimension table (like a Date table) while maintaining 
relationship integrity and avoiding ambiguous paths or DirectQuery/Import conflicts.

Optional: 
-Delete any existing relationships after creating a new one to avoid ambiguous paths.

Output:
- Summary of actions and issues is printed to the Output window

===========================================================================================
*/

var oldTableName = "Date";              // Original table to migrate relationships from
var newTableName = "Date Table";        // New table to migrate relationships to
var dateColumnName = "Date";            // Key column used in relationships

// Retrieve references to the old and new tables
var oldTable = Model.Tables[oldTableName];
var newTable = Model.Tables[newTableName];

// Validate that both tables exist
if (oldTable == null || newTable == null)
{
    Error("Tables not found!");
    return;
}

// Retrieve the key column from the new table
var newDateColumn = newTable.Columns[dateColumnName];
if (newDateColumn == null)
{
    Error("Date column not found in new table!");
    return;
}

// Step 1: Collect all relationship metadata involving the old table
var relationshipInfo = new List<dynamic>();
var oldRelationshipsToDelete = new List<dynamic>();

foreach (var oldRel in Model.Relationships.Where(r => r.FromTable == oldTable || r.ToTable == oldTable).ToList())
{
    relationshipInfo.Add(new {
        FromColumn = oldRel.FromColumn,
        ToColumn = oldRel.ToColumn,
        IsActive = oldRel.IsActive,
        CrossFilteringBehavior = oldRel.CrossFilteringBehavior,
        SecurityFilteringBehavior = oldRel.SecurityFilteringBehavior,
        RelyOnReferentialIntegrity = oldRel.RelyOnReferentialIntegrity,
        JoinOnDateBehavior = oldRel.JoinOnDateBehavior,
        FromCardinality = oldRel.FromCardinality,
        ToCardinality = oldRel.ToCardinality,
        Name = oldRel.Name,
        OldTableWasFrom = (oldRel.FromTable == oldTable)
    });
    oldRelationshipsToDelete.Add(oldRel);
}

// Initialize a summary log
var summary = "RELATIONSHIP MIGRATION WITH OPTIONAL CLEANUP:\n";
summary += "Found " + relationshipInfo.Count + " relationships to migrate\n\n";

// ============================================================================
// OPTIONAL: DELETE OLD RELATIONSHIPS TO PREVENT AMBIGUOUS PATHS
// Uncomment this section if you want to remove the old relationships
// ============================================================================
/*
summary += "=== DELETING OLD RELATIONSHIPS ===\n";
foreach (var oldRel in oldRelationshipsToDelete)
{
    try
    {
        var relName = oldRel.FromTable.Name + " -> " + oldRel.ToTable.Name;
        oldRel.Delete();
        summary += "Deleted: " + relName + "\n";
    }
    catch (Exception ex)
    {
        summary += "Failed to delete relationship: " + ex.Message + "\n";
    }
}
summary += "\n";
*/

// Step 2: Create new relationships using the new table
summary += "=== CREATING NEW RELATIONSHIPS ===\n";
var failedBidirectional = new List<string>();

foreach (var relInfo in relationshipInfo)
{
    try
    {
        var newRel = Model.AddRelationship();

        // Assign the correct From/To columns based on the original direction
        if (relInfo.OldTableWasFrom)
        {
            newRel.FromColumn = newDateColumn;
            newRel.ToColumn = relInfo.ToColumn;
        }
        else
        {
            newRel.FromColumn = relInfo.FromColumn;
            newRel.ToColumn = newDateColumn;
        }

        // Set cardinality and other relationship properties
        newRel.FromCardinality = relInfo.FromCardinality;
        newRel.ToCardinality = relInfo.ToCardinality;
        newRel.IsActive = relInfo.IsActive;
        newRel.SecurityFilteringBehavior = relInfo.SecurityFilteringBehavior;
        newRel.RelyOnReferentialIntegrity = relInfo.RelyOnReferentialIntegrity;
        newRel.JoinOnDateBehavior = relInfo.JoinOnDateBehavior;

        // Set cross-filtering behavior using explicit enum mapping
        var originalCrossFilter = relInfo.CrossFilteringBehavior.ToString();
        if (originalCrossFilter == "BothDirections")
        {
            newRel.CrossFilteringBehavior = CrossFilteringBehavior.BothDirections;
        }
        else if (originalCrossFilter == "OneDirection")
        {
            newRel.CrossFilteringBehavior = CrossFilteringBehavior.OneDirection;
        }
        else if (originalCrossFilter == "Automatic")
        {
            newRel.CrossFilteringBehavior = CrossFilteringBehavior.Automatic;
        }

        // Verify if the cross-filtering behavior was applied successfully
        var actualResult = newRel.CrossFilteringBehavior.ToString();
        var success = (actualResult == originalCrossFilter) ? "SUCCESS" : "FAILED";
        summary += newRel.FromTable.Name + " -> " + newRel.ToTable.Name + ": " + success + " (" + originalCrossFilter + " -> " + actualResult + ")\n";

        // Track failed bidirectional attempts for review
        if (success == "FAILED" && originalCrossFilter == "BothDirections")
        {
            failedBidirectional.Add(newRel.FromTable.Name + " -> " + newRel.ToTable.Name);
        }

        // Rename the relationship if it had a name
        if (!string.IsNullOrEmpty(relInfo.Name))
        {
            newRel.Name = relInfo.Name.Replace(oldTableName, newTableName);
        }
    }
    catch (Exception ex)
    {
        summary += "Failed to create relationship: " + ex.Message + "\n";
    }
}

// Step 3: Report any failed bidirectional relationships
if (failedBidirectional.Count > 0)
{
    summary += "\n=== MANUAL REVIEW REQUIRED ===\n";
    summary += "The following relationships could not be set to bidirectional:\n";
    foreach (var rel in failedBidirectional)
    {
        summary += "• " + rel + "\n";
    }

    summary += "\nPossible causes:\n";
    summary += "• DirectQuery/Import mode mixing (expected limitation)\n";
    summary += "• Ambiguous relationship paths (try deleting old relationships first)\n";
    summary += "• Model validation constraints\n";

    summary += "\nTO FIX AMBIGUOUS PATHS:\n";
    summary += "1. Uncomment the 'DELETE OLD RELATIONSHIPS' section above\n";
    summary += "2. Re-run this script\n";
    summary += "3. Or manually delete old relationships first, then run script\n";
}

// Final notes
summary += "\n=== COMPLETION NOTES ===\n";
summary += "• Script completed successfully\n";
summary += "• Review failed bidirectional relationships manually\n";
summary += "• Consider deleting old relationships if ambiguous paths exist\n";
summary += "• DirectQuery/Import cross-filtering limitations are normal\n";

// Output the summary to the Output window
Info(summary);
