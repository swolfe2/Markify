/*
===========================================================================================
RELATIONSHIP MIGRATION SCRIPT - THREE-PHASE LOGIC
-------------------------------------------------------------------------------------------
Author: Steve Wolfe (Data Viz CoE), Revised by Gemini
Purpose:
This script uses a three-phase process for maximum reliability.
1. CREATE: All relationships are created as ACTIVE and SINGLE-DIRECTIONAL.
2. UPGRADE: The script attempts to apply the original properties (bi-directional, etc.).
3. REMEDIATE: Any relationship that failed the upgrade is reliably set to INACTIVE.

Key Features:
- Multi-phase logic to ensure commands are processed reliably by the Tabular engine.
- Clear separation of error types for creation vs. upgrade failures.
- Detailed final report serves as a clear "to-do list" for manual corrections.

Output:
- A phased summary of all actions and a final report on relationships needing review.

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

// Initial setup and validation
var summary = "RELATIONSHIP MIGRATION SCRIPT:\n";
var oldTable = Model.Tables.FirstOrDefault(t => t.Name == oldTableName);
if (oldTable == null) { Error("Unable to locate the 'Old Table' named \"" + oldTableName + "\"."); return; }
var newTable = Model.Tables.FirstOrDefault(t => t.Name == newTableName);
if (newTable == null) { Error("Unable to locate the 'New Table' named \"" + newTableName + "\"."); return; }
var oldColumn = oldTable.Columns.FirstOrDefault(c => c.Name == oldColumnName);
if (oldColumn == null) { Error("Unable to locate the 'Old Column' named \"" + oldColumnName + "\" on table \"" + oldTableName + "\"."); return; }
var newColumn = newTable.Columns.FirstOrDefault(c => c.Name == newColumnName);
if (newColumn == null) { Error("Unable to locate the 'New Column' named \"" + newColumnName + "\" on table \"" + newTableName + "\"."); return; }

// Collect original relationship metadata
var relationshipInfo = new List<dynamic>();
foreach (var oldRel in Model.Relationships.Where(r => (r.FromTable == oldTable && r.FromColumn == oldColumn) || (r.ToTable == oldTable && r.ToColumn == oldColumn)).ToList()) {
    relationshipInfo.Add(new {
        FromColumn = oldRel.FromColumn, ToColumn = oldRel.ToColumn, IsActive = oldRel.IsActive,
        CrossFilteringBehavior = oldRel.CrossFilteringBehavior, SecurityFilteringBehavior = oldRel.SecurityFilteringBehavior,
        RelyOnReferentialIntegrity = oldRel.RelyOnReferentialIntegrity, JoinOnDateBehavior = oldRel.JoinOnDateBehavior,
        FromCardinality = oldRel.FromCardinality, ToCardinality = oldRel.ToCardinality, Name = oldRel.Name
    });
}
summary += "Found " + relationshipInfo.Count + " relationships to migrate.\n";

// Delete old relationships if configured
if (deleteOldRelationships) {
    summary += "Deleting " + relationshipInfo.Count + " old relationships...\n";
    foreach (var relInfo in relationshipInfo) {
        var oldRel = Model.Relationships.FirstOrDefault(r => r.FromColumn == relInfo.FromColumn && r.ToColumn == relInfo.ToColumn);
        if(oldRel != null) oldRel.Delete();
    }
}

// Lists to track outcomes through the phases
var creationErrors = new List<string>();
var newlyCreatedRels = new List<dynamic>();
var relsToDeactivate = new List<TabularEditor.TOMWrapper.SingleColumnRelationship>();

// === PHASE 1: Create all relationships as Active, Single-Directional ===
summary += "\n=== PHASE 1: Creating all relationships as Active and Single-Directional ===\n";
foreach (var relInfo in relationshipInfo) {
    var relIdentifier = relInfo.FromColumn.Table.Name.Replace(oldTableName, newTableName) + " -> " + relInfo.ToColumn.Table.Name.Replace(oldTableName, newTableName);
    try {
        var newRel = Model.AddRelationship();
        var fromTblName = relInfo.FromColumn.Table.Name;
        newRel.FromColumn = fromTblName == oldTableName ? newTable.Columns[relInfo.FromColumn.Name] : relInfo.FromColumn;
        newRel.ToColumn = fromTblName == oldTableName ? relInfo.ToColumn : newTable.Columns[relInfo.ToColumn.Name];
        newRel.FromCardinality = relInfo.FromCardinality;
        newRel.ToCardinality = relInfo.ToCardinality;
        if (!string.IsNullOrEmpty(relInfo.Name)) newRel.Name = relInfo.Name.Replace(oldTableName, newTableName);

        // Create in a safe, active state
        newRel.IsActive = true;
        newRel.CrossFilteringBehavior = CrossFilteringBehavior.OneDirection;

        newlyCreatedRels.Add(new { NewRel = newRel, OriginalInfo = relInfo });
        summary += "  • SUCCESS (Creation): " + relIdentifier + "\n";
    } catch (Exception ex) {
        summary += "  • CRITICAL FAILURE (Creation): " + relIdentifier + " - " + ex.Message.Trim() + "\n";
        creationErrors.Add(relIdentifier);
    }
}

// === PHASE 2: Attempt to upgrade relationships to match original properties ===
summary += "\n=== PHASE 2: Upgrading relationships to match original properties ===\n";
foreach (var item in newlyCreatedRels) {
    var newRel = item.NewRel as TabularEditor.TOMWrapper.SingleColumnRelationship;
    var originalInfo = item.OriginalInfo;
    var relIdentifier = newRel.FromTable.Name + " -> " + newRel.ToTable.Name;
    try {
        // Attempt to apply original properties
        newRel.SecurityFilteringBehavior = originalInfo.SecurityFilteringBehavior;
        newRel.CrossFilteringBehavior = originalInfo.CrossFilteringBehavior;
        
        // Final check for IsActive, as some might have been originally inactive
        newRel.IsActive = originalInfo.IsActive;

        summary += "  • SUCCESS (Upgrade): " + relIdentifier + "\n";
    } catch (Exception ex) {
        summary += "  • WARNING (Upgrade Failed): " + relIdentifier + " - " + ex.Message.Trim() + ". Flagged for deactivation.\n";
        relsToDeactivate.Add(newRel);
    }
}

// === PHASE 3: Deactivate relationships that failed to upgrade ===
summary += "\n=== PHASE 3: Deactivating relationships that failed to upgrade ===\n";
if (relsToDeactivate.Count > 0) {
    summary += "Forcing " + relsToDeactivate.Count + " relationship(s) to INACTIVE state.\n";
    foreach (var rel in relsToDeactivate) {
        rel.IsActive = false;
        summary += "  • REMEDIATED: " + rel.FromTable.Name + " -> " + rel.ToTable.Name + "\n";
    }
} else {
    summary += "No relationships required deactivation.\n";
}

// === PHASE 4: Final Summary Report ===
if (creationErrors.Count > 0 || relsToDeactivate.Count > 0) {
    summary += "\n===================================================================\n";
    summary += "ACTION REQUIRED: Review Relationship Creation Issues\n";
    summary += "===================================================================\n";

    if(creationErrors.Count > 0) {
        summary += "\nThe following relationships failed during initial creation and DO NOT EXIST in the model:\n";
        foreach(var id in creationErrors) summary += "  • " + id + "\n";
    }

    if(relsToDeactivate.Count > 0) {
        summary += "\nThe following relationships could not be upgraded and were reliably forced to be INACTIVE:\n";
        foreach (var rel in relsToDeactivate) summary += "  • " + rel.FromTable.Name + " -> " + rel.ToTable.Name + "\n";
    }

    summary += "\n--- Why Upgrades Fail ---\n";
    summary += "An upgrade typically fails due to:\n";
    summary += "1. Ambiguous Paths: The most common cause. Another active relationship path already exists.\n";
    summary += "2. DirectQuery Limitations: Certain bi-directional relationships are not allowed in some DirectQuery modes.\n";

    summary += "\n--- YOUR MANUAL ACTIONS ---\n";
    summary += "1. For relationships that failed creation, you must create them manually.\n";
    summary += "2. For relationships left INACTIVE, find them in the model view, activate them, and resolve any errors Power BI presents.\n";
}

summary += "\n=== SCRIPT COMPLETE ===\n";

// Output the summary to the Output window
Info(summary);
