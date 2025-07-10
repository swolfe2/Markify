/*
===========================================================================================
RELATIONSHIP MIGRATION SCRIPT - "CREATE SAFE, THEN UPGRADE" LOGIC
-------------------------------------------------------------------------------------------
Author: Steve Wolfe (Data Viz CoE), Revised by Gemini
Purpose:
This script uses a "Create Safe, then Upgrade" strategy. It first creates all new
relationships as INACTIVE and single-directional. It then attempts to "upgrade" them to
their original properties. If the upgrade fails, the relationship is reliably left in its
safe, inactive state for manual review. This is the most robust method.

Key Features:
- "Create Safe, then Upgrade" logic to work with the Tabular engine's transaction model.
- Guarantees failed relationships are left inactive.
- Detailed final report explaining why an upgrade might fail.
- User-friendly pop-up errors for incorrect table or column names.

Output:
- An accurate summary of successful upgrades and relationships left inactive for review.

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

// Step 4: Create new relationships using "Create Safe, then Upgrade" logic
summary += "=== CREATING NEW RELATIONSHIPS ===\n";
var relsThatNeedReview = new List<string>();

foreach (var relInfo in relationshipInfo)
{
    var relIdentifier = relInfo.OldTableWasFrom ? (newTable.Name + " -> " + relInfo.ToColumn.Table.Name) : (relInfo.FromColumn.Table.Name + " -> " + newTable.Name);

    try
    {
        // Create the relationship in a guaranteed-safe state first
        var newRel = Model.AddRelationship();
        if (relInfo.OldTableWasFrom) { newRel.FromColumn = newColumn; newRel.ToColumn = relInfo.ToColumn; } 
        else { newRel.FromColumn = relInfo.FromColumn; newRel.ToColumn = newColumn; }
        
        newRel.FromCardinality = relInfo.FromCardinality; newRel.ToCardinality = relInfo.ToCardinality;
        newRel.SecurityFilteringBehavior = relInfo.SecurityFilteringBehavior; newRel.RelyOnReferentialIntegrity = relInfo.RelyOnReferentialIntegrity;
        newRel.JoinOnDateBehavior = relInfo.JoinOnDateBehavior;
        
        // ** SET TO SAFE STATE **
        newRel.IsActive = false;
        newRel.CrossFilteringBehavior = CrossFilteringBehavior.OneDirection;

        // Now, ATTEMPT to "upgrade" the relationship to its original state
        try
        {
            newRel.CrossFilteringBehavior = relInfo.CrossFilteringBehavior;
            newRel.IsActive = relInfo.IsActive;
            summary += relIdentifier + ": SUCCESS (Created with original properties).\n";
        }
        catch (Exception ex)
        {
            // The upgrade failed. The relationship will be left INACTIVE.
            summary += relIdentifier + ": WARNING - Could not apply original state due to a model conflict (" + ex.Message.Trim() + ").\n";
            summary += "--> ACTION: Relationship was left INACTIVE for manual review.\n";
            relsThatNeedReview.Add(relIdentifier);
        }

        if (!string.IsNullOrEmpty(relInfo.Name)) { newRel.Name = relInfo.Name.Replace(oldTableName, newTableName); }
    }
    catch (Exception ex)
    {
        summary += relIdentifier + ": CRITICAL FAILURE - Could not create relationship. Error: " + ex.Message.Trim() + "\n";
    }
}

// Step 5: Final Summary Report
if (relsThatNeedReview.Count > 0)
{
    summary += "\n===================================================================\n";
    summary += "ACTION REQUIRED: Review Inactive Relationships\n";
    summary += "===================================================================\n";
    summary += "The following relationships could not be upgraded to their original state and were left INACTIVE:\n";
    foreach (var relId in relsThatNeedReview)
    {
        summary += "  • " + relId + "\n";
    }

    summary += "\n--- Why an Upgrade Fails ---\n";
    summary += "An upgrade can fail for several reasons, most commonly:\n";
    summary += "1. Ambiguous Paths: The most frequent cause. This happens if the 'Old Date Table' still has other active relationships creating a conflict in the model.\n";
    summary += "2. DirectQuery Limitations: You cannot create certain bi-directional relationships in a DirectQuery model that is connected to another Power BI semantic model.\n";
    summary += "3. Other Model Constraints: The model may have other validation rules that prevent the relationship.\n";

    summary += "\n--- How to Fix ---\n";
    summary += "1. Ensure Deletion is Enabled: Make sure `deleteOldRelationships = true` at the top of the script.\n";
    summary += "2. Manually Clean the Old Table: Before running the script again, find your 'Old Date Table' in the explorer, expand its 'Relationships' folder, and manually delete any leftover active relationships.\n";
    summary += "3. Re-run the script after cleaning the model.\n";
    summary += "4. You can now find the INACTIVE relationships in the Power BI model view, activate them manually, and resolve any errors the tool presents.\n";
}

summary += "\n=== SCRIPT COMPLETE ===\n";

// Output the summary to the Output window
Info(summary);
