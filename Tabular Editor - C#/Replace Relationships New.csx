/*
===========================================================================================
RELATIONSHIP MIGRATION SCRIPT WITH OPTIONAL DELETION
-------------------------------------------------------------------------------------------
Author: Steve Wolfe (Data Viz CoE), Revised by Gemini
Purpose:
This script is designed for use in Tabular Editor to migrate all relationships from a
specific column in an existing table to a new table. It includes an option to delete the
original relationships to prevent ambiguity errors, especially with bi-directional
relationships.

Key Features:
- Adds a boolean switch 'deleteOldRelationships' to control the deletion step.
- Collects all relationships linked to the specified old table and column.
- Optionally deletes the old relationships to prevent validation errors.
- Recreates each relationship using the new table’s column.
- Preserves all critical relationship properties.
- Logs a summary of all operations and highlights any failures.

Use Case:
Ideal for replacing a shared dimension table. You can run it once with deletion disabled
to review, and then run it again with deletion enabled to finalize the migration.

Output:
- A summary of actions and issues is printed to the Output window.

===========================================================================================
*/

// --- CONFIGURATION ---
var oldTableName = "Date";          // Original table to migrate relationships from
var oldColumnName = "Date";         // Key column in the OLD table
var newTableName = "Date Table";    // New table to migrate relationships to
var newColumnName = "Date";         // Key column in the NEW table

// Set this to 'false' to keep the original relationships for validation purposes.
// NOTE: Keeping old relationships may cause failures when creating new bi-directional ones.
var deleteOldRelationships = true;

// --- SCRIPT LOGIC ---

// Retrieve references to the old and new tables
var oldTable = Model.Tables[oldTableName];
var newTable = Model.Tables[newTableName];

// Validate that both tables exist
if (oldTable == null || newTable == null)
{
    Error("One or both tables were not found! Verify table names.");
    return;
}

// Retrieve the key columns from the old and new tables
var oldColumn = oldTable.Columns[oldColumnName];
var newColumn = newTable.Columns[newColumnName];
if (oldColumn == null || newColumn == null)
{
    Error("One or both key columns were not found! Verify column names.");
    return;
}

// Step 1: Collect all relationship metadata involving the old table's specific column
var relationshipInfo = new List<dynamic>();
var oldRelationshipsToDelete = new List<dynamic>();

foreach (var oldRel in Model.Relationships.Where(r => (r.FromTable == oldTable && r.FromColumn == oldColumn) || (r.ToTable == oldTable && r.ToColumn == oldColumn)).ToList())
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
var summary = "RELATIONSHIP MIGRATION SCRIPT:\n";
summary += "Found " + relationshipInfo.Count + " relationships to migrate from '" + oldTableName + "'[" + oldColumnName + "].\n\n";

// ============================================================================
// Step 2: (OPTIONAL) DELETE OLD RELATIONSHIPS
// ============================================================================
if (deleteOldRelationships)
{
    summary += "=== DELETING OLD RELATIONSHIPS (Option Enabled) ===\n";
    if (oldRelationshipsToDelete.Count == 0)
    {
        summary += "No relationships found to delete.\n";
    }
    else
    {
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
    }
}
else
{
    summary += "=== SKIPPING DELETION of old relationships (Option Disabled) ===\n";
}
summary += "\n";

// Step 3: Create new relationships using the new table
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
            newRel.FromColumn = newColumn;
            newRel.ToColumn = relInfo.ToColumn;
        }
        else
        {
            newRel.FromColumn = relInfo.FromColumn;
            newRel.ToColumn = newColumn;
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

// Step 4: Report any failed bidirectional relationships
if (failedBidirectional.Count > 0)
{
    summary += "\n=== MANUAL REVIEW REQUIRED ===\n";
    summary += "The following relationships could not be set to bidirectional:\n";
    foreach (var rel in failedBidirectional)
    {
        summary += "• " + rel + "\n";
    }

    summary += "\nPossible causes:\n";
    if (!deleteOldRelationships)
    {
        // -- FIX WAS HERE --
        summary += "• Ambiguous relationship paths (Recommended fix: Set deleteOldRelationships to true and re-run).\n";
    }
    summary += "• DirectQuery/Import mode mixing (expected limitation).\n";
    summary += "• Other model validation constraints are preventing this path.\n";
}

// Final notes
summary += "\n=== COMPLETION NOTES ===\n";
summary += "• Script completed.\n";
summary += "• Review the log above for any FAILED items.\n";
if (!deleteOldRelationships && failedBidirectional.Count > 0)
{
    // -- AND FIX WAS HERE --
    summary += "• To fix ambiguity failures, set deleteOldRelationships = true; at the top of the script and run it again.\n";
}

// Output the summary to the Output window
Info(summary);
