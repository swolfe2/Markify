/*
===========================================================================================
RELATIONSHIP MIGRATION SCRIPT - "DETECT AND REPORT" LOGIC
-------------------------------------------------------------------------------------------
Author: Steve Wolfe (Data Viz CoE), Revised by Gemini
Purpose:
This script's goal is to accurately report on relationship migration. It attempts to
create relationships with their original properties. It then uses explicit VERIFICATION to
detect any "silent failures" where the model changes a property. It does NOT attempt to
fix the relationship, but instead produces a clear report of discrepancies for manual correction.

Key Features:
- "Detect and Report" philosophy for 100% accurate feedback.
- Explicit verification to reliably catch silent property changes.
- A final report that serves as a clear "to-do list" for manual corrections.
- User-friendly pop-up errors for incorrect table or column names.

Output:
- An accurate summary of successful creations and a list of relationships requiring manual correction.

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

// Step 4: Create new relationships and verify them
summary += "=== CREATING AND VERIFYING RELATIONSHIPS ===\n";
var mismatchedRels = new List<dynamic>();

foreach (var relInfo in relationshipInfo)
{
    var relIdentifier = relInfo.OldTableWasFrom ? (newTable.Name + " -> " + relInfo.ToColumn.Table.Name) : (relInfo.FromColumn.Table.Name + " -> " + newTable.Name);

    try
    {
        var newRel = Model.AddRelationship();

        if (relInfo.OldTableWasFrom) { newRel.FromColumn = newColumn; newRel.ToColumn = relInfo.ToColumn; } 
        else { newRel.FromColumn = relInfo.FromColumn; newRel.ToColumn = newColumn; }
        
        newRel.FromCardinality = relInfo.FromCardinality; newRel.ToCardinality = relInfo.ToCardinality;
        newRel.SecurityFilteringBehavior = relInfo.SecurityFilteringBehavior; newRel.RelyOnReferentialIntegrity = relInfo.RelyOnReferentialIntegrity;
        newRel.JoinOnDateBehavior = relInfo.JoinOnDateBehavior;

        // Attempt to set properties "hot"
        newRel.CrossFilteringBehavior = relInfo.CrossFilteringBehavior;
        newRel.IsActive = relInfo.IsActive;

        // VERIFY if the properties were applied correctly
        bool propsMatch = (newRel.CrossFilteringBehavior == relInfo.CrossFilteringBehavior) && (newRel.IsActive == relInfo.IsActive);
        
        string originalState = string.Format("Active={0}, Filter={1}", relInfo.IsActive, relInfo.CrossFilteringBehavior);
        string actualState = string.Format("Active={0}, Filter={1}", newRel.IsActive, newRel.CrossFilteringBehavior);

        if (propsMatch) {
            summary += relIdentifier + ": SUCCESS (Created with original properties).\n";
        } else {
            summary += relIdentifier + ": WARNING - Model silently changed relationship properties.\n";
            summary += "--> Requested: " + originalState + ".  Actual Result: " + actualState + ".\n";
            mismatchedRels.Add( new { Identifier = relIdentifier, Requested = originalState, Actual = actualState });
        }

        if (!string.IsNullOrEmpty(relInfo.Name)) { newRel.Name = relInfo.Name.Replace(oldTableName, newTableName); }
    }
    catch (Exception ex)
    {
        summary += relIdentifier + ": CRITICAL FAILURE - Could not create relationship. Error: " + ex.Message.Trim() + "\n";
    }
}

// Step 5: Final Summary Report
if (mismatchedRels.Count > 0)
{
    summary += "\n===================================================================\n";
    summary += "!! ACTION REQUIRED: Manually Correct Relationships !!\n";
    summary += "===================================================================\n";
    summary += "The script detected that the model could not create the following relationships with their original properties. \n";
    summary += "These relationships have been left in the state the model assigned them. YOU MUST CORRECT THEM MANUALLY.\n";
    
    foreach (var item in mismatchedRels)
    {
        summary += "\n  • Relationship: " + item.Identifier + "\n";
        summary += "    - Requested: " + item.Requested + "\n";
        summary += "    - Final State in Model: " + item.Actual + "\n";
    }

    summary += "\n--- Why This Happens ---\n";
    summary += "This can happen when the data model rejects or silently changes a property, usually for one of these reasons:\n";
    summary += "1. Ambiguous Paths: The most common cause. Another active relationship path already exists.\n";
    summary += "2. DirectQuery Limitations: Certain bi-directional relationships are not allowed in some DirectQuery modes.\n";

    summary += "\n--- YOUR MANUAL ACTIONS ---\n";
    summary += "1. Go to the Model View in Power BI or Tabular Editor.\n";
    summary += "2. Find each relationship listed above.\n";
    summary += "3. Manually edit its properties. You may need to set it to Inactive or fix the ambiguity in your model so the desired properties can be applied.\n";
}

summary += "\n=== SCRIPT COMPLETE ===\n";

// Output the summary to the Output window
Info(summary);
