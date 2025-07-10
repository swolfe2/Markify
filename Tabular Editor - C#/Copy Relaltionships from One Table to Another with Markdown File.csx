#r "Microsoft.AnalysisServices.Core.dll"
using ToM = Microsoft.AnalysisServices.Tabular;
/*
===========================================================================================
RELATIONSHIP MIGRATION SCRIPT - (FINAL - MARKDOWN REPORT)
-------------------------------------------------------------------------------------------
Author: Steve Wolfe (Data Viz CoE)
Purpose:
This script uses a robust three-phase process to migrate relationships. It is designed
to be failsafe and produce a clear, readable report.

1. CREATE: All relationships are created in a basic, active, single-directional state.
2. VERIFIED UPGRADE: The script attempts to apply original properties and verifies the change.
3. REMEDIATE:
    - If an upgrade fails, it attempts to set the relationship to INACTIVE.
    - If that fails, it DELETES the relationship entirely.

Output:
- A CONCISE summary is shown in the Tabular Editor popup window.
- A FULL, DETAILED report in MARKDOWN format is saved to a text file on your Desktop,
  including step-by-step "recipes" for manually recreating any deleted relationships.

===========================================================================================
*/

// --- CONFIGURATION ---
var oldTableName = "table_name_1";          // Original table to migrate relationships from
var oldColumnName = "column_name_1";        // Key column in the OLD table
var newTableName = "table_name_2";          // New table to migrate relationships to
var newColumnName = "column_name_2";        // Key column in the NEW table

// Set to 'true' to delete old relationships first. THIS IS HIGHLY RECOMMENDED.
var deleteOldRelationships = false;

// --- SCRIPT LOGIC ---

// Initial setup and validation
var summary = "# Relationship Migration Report\n";
summary += "*Generated: " + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + "*\n\n";

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
summary += "Found " + relationshipInfo.Count + " relationships to migrate from table '" + oldTableName + "'.\n";

// Delete old relationships if configured
if (deleteOldRelationships) {
    var oldRels = Model.Relationships.Where(r => (r.FromTable == oldTable && r.FromColumn.Name == oldColumnName) || (r.ToTable == oldTable && r.ToColumn.Name == oldColumnName)).ToList();
    summary += "Deleting " + oldRels.Count + " old relationships...\n";
    foreach (var rel in oldRels) {
        rel.Delete();
    }
}

// Lists to track outcomes through the phases
var creationErrors = new List<string>();
var newlyCreatedRels = new List<dynamic>();
var relsToDeactivate = new List<dynamic>();
var deactivationFailures = new List<string>();
var deletedRelationshipsForManualRebuild = new List<dynamic>();
var successfullyDeactivatedRels = new List<string>();

// === PHASE 1: Create all relationships as Active, Single-Directional ===
summary += "\n## PHASE 1: Creating all relationships as Active and Single-Directional\n";
foreach (var relInfo in relationshipInfo) {
    var fromTableName = relInfo.FromColumn.Table.Name;
    var toTableName = relInfo.ToColumn.Table.Name;
    var fromColName = relInfo.FromColumn.Name;
    var toColName = relInfo.ToColumn.Name;

    var relIdentifier = (fromTableName == oldTableName ? newTableName : fromTableName) + " -> " + (toTableName == oldTableName ? newTableName : toTableName);

    try {
        var newRel = Model.AddRelationship();
        newRel.FromColumn = fromTableName == oldTableName ? newTable.Columns[fromColName] : Model.Tables[fromTableName].Columns[fromColName];
        newRel.ToColumn = toTableName == oldTableName ? newTable.Columns[toColName] : Model.Tables[toTableName].Columns[toColName];

        newRel.FromCardinality = relInfo.FromCardinality;
        newRel.ToCardinality = relInfo.ToCardinality;
        if (!string.IsNullOrEmpty(relInfo.Name)) newRel.Name = relInfo.Name.Replace(oldTableName, newTableName);

        newRel.IsActive = true;
        newRel.CrossFilteringBehavior = CrossFilteringBehavior.OneDirection;

        newlyCreatedRels.Add(new { NewRel = newRel, OriginalInfo = relInfo });
        summary += "- **SUCCESS (Creation)**: `" + relIdentifier + "`\n";
    } catch (Exception ex) {
        summary += "- **CRITICAL FAILURE (Creation)**: `" + relIdentifier + "` - " + ex.Message.Trim() + "\n";
        creationErrors.Add(relIdentifier);
    }
}

try {
    Model.Database.TOMDatabase.Model.SaveChanges();
    summary += "\n*Model changes saved after Phase 1.*\n";
} catch (Exception ex) {
    summary += "\n**Warning**: Model save failed after Phase 1: " + ex.Message + "\n";
}

// === PHASE 2: Upgrade relationships and VERIFY properties ===
summary += "\n## PHASE 2: Upgrading relationships and verifying properties\n";
foreach (var item in newlyCreatedRels) {
    var newRel = item.NewRel as TabularEditor.TOMWrapper.SingleColumnRelationship;
    var originalInfo = item.OriginalInfo;
    var relIdentifier = newRel.FromTable.Name + " -> " + newRel.ToTable.Name;

    bool upgradeSuccessful = true;
    string upgradeError = "";

    try {
        if (originalInfo.CrossFilteringBehavior != CrossFilteringBehavior.OneDirection) {
            var originalCrossFilter = newRel.CrossFilteringBehavior;
            newRel.CrossFilteringBehavior = originalInfo.CrossFilteringBehavior;
            if (newRel.CrossFilteringBehavior != originalInfo.CrossFilteringBehavior) {
                upgradeSuccessful = false;
                upgradeError += "CrossFilteringBehavior assignment failed silently. ";
                newRel.CrossFilteringBehavior = originalCrossFilter;
            }
        }
    } catch (Exception ex) {
        upgradeSuccessful = false;
        upgradeError += "CrossFilteringBehavior error: " + ex.Message + ". ";
    }

    try {
        newRel.SecurityFilteringBehavior = originalInfo.SecurityFilteringBehavior;
        if (newRel.SecurityFilteringBehavior != originalInfo.SecurityFilteringBehavior) {
            upgradeSuccessful = false;
            upgradeError += "SecurityFilteringBehavior assignment failed silently. ";
        }
    } catch (Exception ex) {
        upgradeSuccessful = false;
        upgradeError += "SecurityFilteringBehavior error: " + ex.Message + ". ";
    }

    try {
        newRel.IsActive = originalInfo.IsActive;
        if (newRel.IsActive != originalInfo.IsActive) {
            upgradeSuccessful = false;
            upgradeError += "IsActive assignment failed silently. ";
        }
    } catch (Exception ex) {
        upgradeSuccessful = false;
        upgradeError += "IsActive error: " + ex.Message + ". ";
    }

    bool finalVerification = (newRel.CrossFilteringBehavior == originalInfo.CrossFilteringBehavior) &&
                           (newRel.SecurityFilteringBehavior == originalInfo.SecurityFilteringBehavior) &&
                           (newRel.IsActive == originalInfo.IsActive);

    if (upgradeSuccessful && finalVerification) {
        summary += "- **SUCCESS (Upgrade)**: `" + relIdentifier + "` matches original properties.\n";
    } else {
        string originalState = string.Format("Active={0}, Filter={1}, Security={2}", originalInfo.IsActive, originalInfo.CrossFilteringBehavior, originalInfo.SecurityFilteringBehavior);
        string actualState = string.Format("Active={0}, Filter={1}, Security={2}", newRel.IsActive, newRel.CrossFilteringBehavior, newRel.SecurityFilteringBehavior);
        summary += "- **WARNING (Upgrade Failed)**: `" + relIdentifier + "`. " + upgradeError.Trim() + "\n";
        summary += "  - `Original`: " + originalState + "\n";
        summary += "  - `Actual`: " + actualState + ". Flagged for remediation.\n";
        relsToDeactivate.Add(new { RelToFix = newRel, OriginalInfo = originalInfo });
    }
}

// === PHASE 3: Deactivate or Delete relationships that failed to upgrade ===
summary += "\n## PHASE 3: Deactivating or Deleting relationships that failed to upgrade\n";
if (relsToDeactivate.Count > 0) {
    summary += "Attempting to remediate " + relsToDeactivate.Count + " relationship(s) that failed to upgrade.\n";
    
    foreach (var item in relsToDeactivate) {
        var rel = item.RelToFix as TabularEditor.TOMWrapper.SingleColumnRelationship;
        var originalInfo = item.OriginalInfo;
        var relIdentifier = rel.FromTable.Name + " -> " + rel.ToTable.Name;
        
        try {
            rel.IsActive = false;
            rel.CrossFilteringBehavior = CrossFilteringBehavior.OneDirection;
            
            if (!rel.IsActive) {
                summary += "- **SUCCESS (Deactivated)**: `" + relIdentifier + "` has been set to INACTIVE for manual review.\n";
                successfullyDeactivatedRels.Add(relIdentifier);
            } else {
                throw new InvalidOperationException("Deactivation failed silently. Relationship remains active.");
            }
        } catch (Exception ex) {
            summary += "- **WARNING (Deactivation Failed)**: Could not set `" + relIdentifier + "` to inactive. Reason: " + ex.Message.Trim() + "\n";
            try {
                var fromTableName = rel.FromTable.Name;
                var toTableName = rel.ToTable.Name;
                rel.Delete();
                deletedRelationshipsForManualRebuild.Add(originalInfo);
                summary += "  - **SUCCESS (Deleted)**: The relationship between `" + fromTableName + "` and `" + toTableName + "` has been **DELETED** and must be created manually.\n";
            } catch (Exception deleteEx) {
                summary += "  - **CRITICAL FAILURE (Deletion Failed)**: Could not delete `" + relIdentifier + "`. MANUAL INTERVENTION IS URGENTLY REQUIRED. Reason: " + deleteEx.Message.Trim() + "\n";
                deactivationFailures.Add(relIdentifier);
            }
        }
    }
} else {
    summary += "No relationships required remediation.\n";
}

try {
    Model.Database.TOMDatabase.Model.SaveChanges();
    summary += "\n*Final model save completed.*\n";
} catch (Exception ex) {
    summary += "\n**Warning**: Final model save failed: " + ex.Message + "\n";
}

// === PHASE 4: Final Summary Report ===
summary += "\n\n# FINAL SUMMARY & ACTION ITEMS\n";

if (creationErrors.Count == 0 && successfullyDeactivatedRels.Count == 0 && deletedRelationshipsForManualRebuild.Count == 0 && deactivationFailures.Count == 0) {
    summary += "\n**✅ All relationships migrated successfully with no issues detected.**\n";
}

if(creationErrors.Count > 0) {
    summary += "\n### The following relationships failed during initial creation and DO NOT EXIST in the model:\n";
    foreach(var id in creationErrors) summary += "- `" + id + "`\n";
}

if(successfullyDeactivatedRels.Count > 0) {
    summary += "\n### The following relationships were successfully set to INACTIVE for manual review:\n";
    foreach(var id in successfullyDeactivatedRels) summary += "- `" + id + "`\n";
}

if(deletedRelationshipsForManualRebuild.Count > 0) {
    summary += "\n### **MANUAL ACTION**: The following relationships were DELETED and must be recreated manually:\n";
    foreach(var info in deletedRelationshipsForManualRebuild) {
        var fromTable = info.FromColumn.Table.Name == oldTableName ? newTableName : info.FromColumn.Table.Name;
        var toTable = info.ToColumn.Table.Name == oldTableName ? newTableName : info.ToColumn.Table.Name;
        
        summary += "\n> #### Rebuild Recipe:\n";
        summary += string.Format(
            "> - **From**: `{0}`[`{1}`]\n> - **To**: `{2}`[`{3}`]\n",
            fromTable, info.FromColumn.Name,
            toTable, info.ToColumn.Name
        );
        summary += string.Format(
            "> - **Properties**: `IsActive={0}`, `Cardinality={1}-to-{2}`, `CrossFilter={3}`, `SecurityFilter={4}`\n",
            info.IsActive, info.FromCardinality, info.ToCardinality, 
            info.CrossFilteringBehavior, info.SecurityFilteringBehavior
        );
    }
}

if(deactivationFailures.Count > 0) {
    summary += "\n### **CRITICAL**: The following relationships could NOT be deactivated OR deleted automatically:\n";
    foreach(var id in deactivationFailures) summary += "- `" + id + "`\n";
    summary += "> These relationships may be in an inconsistent state and require **URGENT** manual intervention.\n";
}

summary += "\n### Why Upgrades Fail\n";
summary += "- **Ambiguous Paths**: The most common cause. Another active relationship path already exists.\n";
summary += "- **DirectQuery Limitations**: Certain bi-directional relationships are not allowed in some DirectQuery modes.\n";
summary += "- **Model State**: The Tabular Object Model may have state consistency issues.\n";


summary += "\n\n# SCRIPT COMPLETE\n";
summary += "- **Total relationships processed**: " + relationshipInfo.Count + "\n";
summary += "- **Successfully created/upgraded**: " + (relationshipInfo.Count - relsToDeactivate.Count - creationErrors.Count) + "\n";
summary += "- **Successfully deactivated**: " + successfullyDeactivatedRels.Count + "\n";
summary += "- **Deleted for manual rebuild**: " + deletedRelationshipsForManualRebuild.Count + "\n";
summary += "- **Critical failures (unresolved)**: " + deactivationFailures.Count + "\n";

// --- SAVE FULL REPORT AND SHOW CONCISE SUMMARY ---

var fileName = "Relationship_Migration_Report_" + DateTime.Now.ToString("yyyyMMdd_HHmmss") + ".md";
var filePath = Environment.GetFolderPath(Environment.SpecialFolder.Desktop) + "\\" + fileName;
var popupSummary = "";

try 
{
    System.IO.File.WriteAllText(filePath, summary);
    popupSummary += "SCRIPT COMPLETE.\n\n";
    popupSummary += "Successfully created/upgraded: " + (relationshipInfo.Count - relsToDeactivate.Count - creationErrors.Count) + "\n";
    popupSummary += "Successfully deactivated: " + successfullyDeactivatedRels.Count + "\n";
    popupSummary += "Deleted for manual rebuild: " + deletedRelationshipsForManualRebuild.Count + "\n";
    popupSummary += "Critical failures: " + deactivationFailures.Count + "\n\n";
    popupSummary += "A detailed Markdown report has been saved to your Desktop:\n" + fileName;
}
catch (Exception ex)
{
    popupSummary = "SCRIPT COMPLETE. Could not save full report to Desktop: " + ex.Message;
}

// Show the concise summary in the Tabular Editor Output window
Info(popupSummary); 
