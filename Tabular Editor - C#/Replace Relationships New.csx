/*
===========================================================================================
RELATIONSHIP MIGRATION SCRIPT WITH DETAILED REPORTING (TE2 COMPATIBLE)
-------------------------------------------------------------------------------------------
Author: Steve Wolfe (Data Viz CoE), Revised by Gemini
Purpose:
This script migrates relationships and includes detailed reporting and error handling. If a
relationship cannot be created with its original properties (e.g., bi-directional), it's
created as inactive, and the final report provides clear reasons and remediation steps.

Key Features:
- Detailed final report explaining which relationships failed, why, and how to fix them.
- User-friendly pop-up errors for incorrect table or column names.
- If a relationship creation fails, it's automatically retried as inactive.
- Includes an optional switch to delete old relationships beforehand.

Output:
- A detailed summary of all actions with actionable advice for any failures.

===========================================================================================
*/

// --- CONFIGURATION ---
var oldTableName = "Date";          // Original table to migrate relationships from
var oldColumnName = "Date";         // Key column in the OLD table
var newTableName = "Date Table";    // New table to migrate relationships to
var newColumnName = "Date";         // Key column in the NEW table

// Set to 'true' to delete old relationships first. THIS IS HIGHLY RECOMMENDED.
var deleteOldRelationships = true;

// --- SCRIPT LOGIC ---

// Step 1: Validate all user inputs with specific error messages
var oldTable = Model.Tables.FirstOrDefault(t => t.Name == oldTableName);
if (oldTable == null) { Error("Unable to locate the 'Old Table' named \"" + oldTableName + "\".\nPlease validate your script inputs and try again."); return; }

var newTable = Model.Tables.FirstOrDefault(t => t.Name == newTableName);
if (newTable == null) { Error("Unable to locate the 'New Table' named \"" + newTableName + "\".\nPlease validate your script inputs and try again."); return; }

var oldColumn = oldTable.Columns.FirstOrDefault(c => c.Name == oldColumnName);
if (oldColumn == null) { Error("Unable to locate the 'Old Column' named \"" + oldColumnName + "\" on table \"" + oldTableName + "\".\nPlease validate your script inputs and try again."); return; }

var newColumn = newTable.Columns.FirstOrDefault(c => c.Name == newColumnName);
if (newColumn == null) { Error("Unable to locate the 'New Column' named \"" + newColumnName + "\" on table \"" + newTableName + "\".\nPlease validate your script inputs and try again."); return; }


// Step 2: Collect relationship metadata
var relationshipInfo = new List<dynamic>();
var oldRelationshipsToDelete = new List<dynamic>();
foreach (var oldRel in Model.Relationships.Where(r => (r.FromTable == oldTable && r.FromColumn == oldColumn) || (r.ToTable == oldTable && r.ToColumn == oldColumn)).ToList())
{
    relationshipInfo.Add(new {
        FromColumn = oldRel.FromColumn, ToColumn = oldRel.ToColumn, IsActive = oldRel.IsActive,
        CrossFilteringBehavior = oldRel.CrossFilteringBehavior, SecurityFilteringBehavior = oldRel.SecurityFilteringBehavior,
        RelyOnReferentialIntegrity = oldRel.RelyOnReferentialIntegrity, JoinOnDateBehavior = oldRel.JoinOnDateBehavior,
        FromCardinality = oldRel.FromCardinality, ToCardinality = oldRel.ToCardinality, Name = oldRel.Name,
        OldTableWasFrom = (oldRel.FromTable == oldTable)
    });
    oldRelationshipsToDelete.Add(oldRel);
}

var summary = "RELATIONSHIP MIGRATION SCRIPT:\n";
summary += "Found " + relationshipInfo.Count + " relationships to migrate from '" + oldTableName + "'[" + oldColumnName + "].\n\n";

// Step 3: (OPTIONAL) Delete Old Relationships
if (deleteOldRelationships)
{
    summary += "=== DELETING OLD RELATIONSHIPS (Option Enabled) ===\n";
    foreach (var oldRel in oldRelationshipsToDelete) { oldRel.Delete(); }
    summary += "Deleted " + oldRelationshipsToDelete.Count + " old relationships.\n\n";
}
else
{
    summary += "=== SKIPPING DELETION of old relationships (Option Disabled) ===\n\n";
}

// Step 4: Create new relationships with inactive fallback
summary += "=== CREATING NEW RELATIONSHIPS ===\n";
var inactiveFallbackRels = new List<string>();

foreach (var relInfo in relationshipInfo)
{
    var relIdentifier = relInfo.OldTableWasFrom ? (newTable.Name + " -> " + relInfo.ToColumn.Table.Name) : (relInfo.FromColumn.Table.Name + " -> " + newTable.Name);

    try
    {
        var newRel = Model.AddRelationship();

        // Assign columns and "safe" properties first
        if (relInfo.OldTableWasFrom) {
            newRel.FromColumn = newColumn; newRel.ToColumn = relInfo.ToColumn;
        } else {
            newRel.FromColumn = relInfo.FromColumn; newRel.ToColumn = newColumn;
        }
        newRel.FromCardinality = relInfo.FromCardinality;
        newRel.ToCardinality = relInfo.ToCardinality;
        newRel.SecurityFilteringBehavior = relInfo.SecurityFilteringBehavior;
        newRel.RelyOnReferentialIntegrity = relInfo.RelyOnReferentialIntegrity;
        newRel.JoinOnDateBehavior = relInfo.JoinOnDateBehavior;

        // Now, try to set properties that can cause ambiguity errors
        try
        {
            newRel.CrossFilteringBehavior = relInfo.CrossFilteringBehavior;
            newRel.IsActive = relInfo.IsActive;
            summary += relIdentifier + ": SUCCESS (Created with original properties).\n";
        }
        catch (Exception ex)
        {
            newRel.IsActive = false;
            newRel.CrossFilteringBehavior = CrossFilteringBehavior.OneDirection;
            
            summary += relIdentifier + ": WARNING - Could not create as specified. (" + ex.Message.Trim() + ")\n";
            summary += "--> ACTION: This relationship was created as INACTIVE for manual review.\n";
            inactiveFallbackRels.Add(relIdentifier);
        }

        if (!string.IsNullOrEmpty(relInfo.Name)) {
            newRel.Name = relInfo.Name.Replace(oldTableName, newTableName);
        }
    }
    catch (Exception ex)
    {
        summary += relIdentifier + ": CRITICAL FAILURE - Could not create relationship. Error: " + ex.Message.Trim() + "\n";
    }
}

// Step 5: Final Summary Report
if (inactiveFallbackRels.Count > 0)
{
    summary += "\n===================================================================\n";
    summary += "ACTION REQUIRED: Review Fallback Relationships\n";
    summary += "===================================================================\n";
    summary += "The following relationships could not be created with their original properties and were created as INACTIVE instead:\n";
    foreach (var rel in inactiveFallbackRels)
    {
        summary += "  • " + rel + "\n";
    }

    summary += "\n--- Why This Happens ---\n";
    summary += "This fallback is triggered when the data model rejects a property, usually for one of these reasons:\n";
    summary += "1. Ambiguous Paths: The most common cause. This happens if the 'Old Date Table' still has other active relationships creating a conflict.\n";
    summary += "2. DirectQuery Limitations: You cannot create certain bi-directional relationships in a DirectQuery model that is connected to another Power BI semantic model.\n";
    summary += "3. Other Model Constraints: The model may have other validation rules that prevent the relationship.\n";

    summary += "\n--- How to Fix ---\n";
    summary += "1. Ensure Deletion is Enabled: Make sure `deleteOldRelationships = true` at the top of the script.\n";
    summary += "2. Manually Clean the Old Table: Before running the script again, find your 'Old Date Table' in the explorer, expand its 'Relationships' folder, and manually delete any leftover active relationships.\n";
    summary += "3. Re-run the script after cleaning the model.\n";
    summary += "4. For relationships that still fail, you must manually activate them in the Power BI model view and resolve any errors the tool presents.\n";
}

summary += "\n=== SCRIPT COMPLETE ===\n";

// Output the summary to the Output window
Info(summary);
