/*
===========================================================================================
RELATIONSHIP MIGRATION SCRIPT - THREE-PHASE LOGIC WITH VERIFICATION
-------------------------------------------------------------------------------------------
Author: Steve Wolfe (Data Viz CoE), Revised by AI Assistant
Purpose:
This script uses a three-phase process with enhanced deactivation logic.
1. CREATE: All relationships are created as ACTIVE and SINGLE-DIRECTIONAL.
2. VERIFIED UPGRADE: The script attempts to apply original properties with try-catch
   and EXPLICITLY VERIFIES that the change was successful. If not, it's flagged.
3. REMEDIATE: Any relationship that failed verification is reliably set to INACTIVE
   with explicit error handling and model refresh.

Key Features:
- Enhanced error handling with try-catch blocks for property assignments
- Explicit model refresh between phases to ensure state consistency
- Multiple verification attempts with different strategies
- Forced deactivation with explicit error handling

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
    var oldRels = Model.Relationships.Where(r => (r.FromTable == oldTable && r.FromColumn.Name == oldColumnName) || (r.ToTable == oldTable && r.ToColumn.Name == oldColumnName)).ToList();
    summary += "Deleting " + oldRels.Count + " old relationships...\n";
    foreach (var rel in oldRels) {
        rel.Delete();
    }
}

// Lists to track outcomes through the phases
var creationErrors = new List<string>();
var newlyCreatedRels = new List<dynamic>();
var relsToDeactivate = new List<TabularEditor.TOMWrapper.SingleColumnRelationship>();
var deactivationFailures = new List<string>();

// === PHASE 1: Create all relationships as Active, Single-Directional ===
summary += "\n=== PHASE 1: Creating all relationships as Active and Single-Directional ===\n";
foreach (var relInfo in relationshipInfo) {
    var fromTableName = relInfo.FromColumn.Table.Name;
    var toTableName = relInfo.ToColumn.Table.Name;
    var fromColName = relInfo.FromColumn.Name;
    var toColName = relInfo.ToColumn.Name;

    // Determine the identifier for logging before potential errors
    var relIdentifier = (fromTableName == oldTableName ? newTableName : fromTableName) + " -> " + (toTableName == oldTableName ? newTableName : toTableName);

    try {
        var newRel = Model.AddRelationship();
        
        // Determine correct from/to columns for the new relationship
        newRel.FromColumn = fromTableName == oldTableName ? newTable.Columns[fromColName] : Model.Tables[fromTableName].Columns[fromColName];
        newRel.ToColumn = toTableName == oldTableName ? newTable.Columns[toColName] : Model.Tables[toTableName].Columns[toColName];

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

// Force model state update after Phase 1
try {
    Model.Database.TOMDatabase.Model.SaveChanges();
    summary += "Model changes saved after Phase 1.\n";
} catch (Exception ex) {
    summary += "Warning: Model save failed after Phase 1: " + ex.Message + "\n";
}

// === PHASE 2: Upgrade relationships and VERIFY properties ===
summary += "\n=== PHASE 2: Upgrading relationships and verifying properties ===\n";
foreach (var item in newlyCreatedRels) {
    var newRel = item.NewRel as TabularEditor.TOMWrapper.SingleColumnRelationship;
    var originalInfo = item.OriginalInfo;
    var relIdentifier = newRel.FromTable.Name + " -> " + newRel.ToTable.Name;

    bool upgradeSuccessful = true;
    string upgradeError = "";

    // Attempt to apply original properties with explicit error handling
    try {
        // Try to set CrossFilteringBehavior first (most likely to fail)
        if (originalInfo.CrossFilteringBehavior != CrossFilteringBehavior.OneDirection) {
            var originalCrossFilter = newRel.CrossFilteringBehavior;
            newRel.CrossFilteringBehavior = originalInfo.CrossFilteringBehavior;
            
            // Immediate verification
            if (newRel.CrossFilteringBehavior != originalInfo.CrossFilteringBehavior) {
                upgradeSuccessful = false;
                upgradeError += "CrossFilteringBehavior assignment failed silently. ";
                newRel.CrossFilteringBehavior = originalCrossFilter; // Revert
            }
        }
    } catch (Exception ex) {
        upgradeSuccessful = false;
        upgradeError += "CrossFilteringBehavior error: " + ex.Message + ". ";
    }

    try {
        // Try to set SecurityFilteringBehavior
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
        // Try to set IsActive
        newRel.IsActive = originalInfo.IsActive;
        if (newRel.IsActive != originalInfo.IsActive) {
            upgradeSuccessful = false;
            upgradeError += "IsActive assignment failed silently. ";
        }
    } catch (Exception ex) {
        upgradeSuccessful = false;
        upgradeError += "IsActive error: " + ex.Message + ". ";
    }

    // Final verification after all property assignments
    bool finalVerification = (newRel.CrossFilteringBehavior == originalInfo.CrossFilteringBehavior) &&
                           (newRel.SecurityFilteringBehavior == originalInfo.SecurityFilteringBehavior) &&
                           (newRel.IsActive == originalInfo.IsActive);

    if (upgradeSuccessful && finalVerification) {
        summary += "  • SUCCESS (Upgrade): " + relIdentifier + " matches original properties.\n";
    } else {
        // The upgrade failed. Flag for deactivation.
        string originalState = string.Format("Active={0}, Filter={1}, Security={2}", 
            originalInfo.IsActive, originalInfo.CrossFilteringBehavior, originalInfo.SecurityFilteringBehavior);
        string actualState = string.Format("Active={0}, Filter={1}, Security={2}", 
            newRel.IsActive, newRel.CrossFilteringBehavior, newRel.SecurityFilteringBehavior);
        summary += "  • WARNING (Upgrade Failed): " + relIdentifier + ". " + upgradeError.Trim() + "\n";
        summary += "    Original: " + originalState + "\n";
        summary += "    Actual: " + actualState + ". Flagged for deactivation.\n";
        relsToDeactivate.Add(newRel);
    }
}

// === PHASE 3: Deactivate relationships that failed to upgrade ===
summary += "\n=== PHASE 3: Deactivating relationships that failed to upgrade ===\n";
if (relsToDeactivate.Count > 0) {
    summary += "Forcing " + relsToDeactivate.Count + " relationship(s) to INACTIVE state.\n";
    
    foreach (var rel in relsToDeactivate) {
        var relIdentifier = rel.FromTable.Name + " -> " + rel.ToTable.Name;
        bool deactivationSuccessful = false;
        string deactivationError = "";
        
        // Multiple deactivation strategies
        try {
            // Strategy 1: Direct deactivation
            rel.IsActive = false;
            rel.CrossFilteringBehavior = CrossFilteringBehavior.OneDirection;
            
            // Verify deactivation worked
            if (!rel.IsActive && rel.CrossFilteringBehavior == CrossFilteringBehavior.OneDirection) {
                deactivationSuccessful = true;
                summary += "  • SUCCESS (Deactivated): " + relIdentifier + " is now INACTIVE.\n";
            } else {
                deactivationError = "Direct deactivation verification failed. ";
            }
        } catch (Exception ex) {
            deactivationError += "Direct deactivation error: " + ex.Message + ". ";
        }
        
                 // Strategy 2: If direct deactivation failed, try save changes and retry
         if (!deactivationSuccessful) {
             try {
                 // Force model state save to commit any pending changes
                 Model.Database.TOMDatabase.Model.SaveChanges();
                 
                 // Retry deactivation
                 rel.IsActive = false;
                 rel.CrossFilteringBehavior = CrossFilteringBehavior.OneDirection;
                 
                 if (!rel.IsActive) {
                     deactivationSuccessful = true;
                     summary += "  • SUCCESS (Deactivated after save): " + relIdentifier + " is now INACTIVE.\n";
                 } else {
                     deactivationError += "Retry after save failed. ";
                 }
             } catch (Exception ex) {
                 deactivationError += "Save and retry error: " + ex.Message + ". ";
             }
         }
        
        // Strategy 3: If all else fails, try to delete and recreate as inactive
        if (!deactivationSuccessful) {
            try {
                // Store relationship details before deletion
                var fromCol = rel.FromColumn;
                var toCol = rel.ToColumn;
                var fromCard = rel.FromCardinality;
                var toCard = rel.ToCardinality;
                var relName = rel.Name;
                
                // Delete the problematic relationship
                rel.Delete();
                
                // Recreate as inactive
                var newInactiveRel = Model.AddRelationship();
                newInactiveRel.FromColumn = fromCol;
                newInactiveRel.ToColumn = toCol;
                newInactiveRel.FromCardinality = fromCard;
                newInactiveRel.ToCardinality = toCard;
                if (!string.IsNullOrEmpty(relName)) newInactiveRel.Name = relName;
                newInactiveRel.IsActive = false;
                newInactiveRel.CrossFilteringBehavior = CrossFilteringBehavior.OneDirection;
                
                if (!newInactiveRel.IsActive) {
                    deactivationSuccessful = true;
                    summary += "  • SUCCESS (Recreated as inactive): " + relIdentifier + " recreated as INACTIVE.\n";
                } else {
                    deactivationError += "Recreation as inactive failed. ";
                }
            } catch (Exception ex) {
                deactivationError += "Delete and recreate error: " + ex.Message + ". ";
            }
        }
        
        if (!deactivationSuccessful) {
            summary += "  • CRITICAL FAILURE (Deactivation): " + relIdentifier + " - " + deactivationError.Trim() + "\n";
            deactivationFailures.Add(relIdentifier);
        }
    }
} else {
    summary += "No relationships required deactivation.\n";
}

// Final model save
try {
    Model.Database.TOMDatabase.Model.SaveChanges();
    summary += "Final model save completed.\n";
} catch (Exception ex) {
    summary += "Warning: Final model save failed: " + ex.Message + "\n";
}

// === PHASE 4: Final Summary Report ===
if (creationErrors.Count > 0 || deactivationFailures.Count > 0 || relsToDeactivate.Count > 0) {
    summary += "\n===================================================================\n";
    summary += "ACTION REQUIRED: Review Relationship Issues\n";
    summary += "===================================================================\n";

    if(creationErrors.Count > 0) {
        summary += "\nThe following relationships failed during initial creation and DO NOT EXIST in the model:\n";
        foreach(var id in creationErrors) summary += "  • " + id + "\n";
    }

    if(deactivationFailures.Count > 0) {
        summary += "\nCRITICAL: The following relationships could NOT be deactivated automatically:\n";
        foreach(var id in deactivationFailures) summary += "  • " + id + "\n";
        summary += "These relationships may be in an inconsistent state and require MANUAL intervention.\n";
    }

    var successfulDeactivations = relsToDeactivate.Count - deactivationFailures.Count;
    if(successfulDeactivations > 0) {
        summary += "\nThe following relationships were successfully set to INACTIVE:\n";
        summary += "Count: " + successfulDeactivations + " relationships\n";
        summary += "(These relationships exist but are disabled until you manually resolve conflicts)\n";
    }

    summary += "\n--- Why Upgrades Fail ---\n";
    summary += "An upgrade typically fails due to:\n";
    summary += "1. Ambiguous Paths: The most common cause. Another active relationship path already exists.\n";
    summary += "2. DirectQuery Limitations: Certain bi-directional relationships are not allowed in some DirectQuery modes.\n";
    summary += "3. Model State: The Tabular Object Model may have state consistency issues.\n";

    summary += "\n--- YOUR MANUAL ACTIONS ---\n";
    summary += "1. For relationships that failed creation, you must create them manually.\n";
    summary += "2. For relationships that couldn't be deactivated, manually set them to inactive in the model view.\n";
    summary += "3. For successfully deactivated relationships, find them in the model view, activate them, and resolve any errors Power BI presents.\n";
    summary += "4. If you see CRITICAL deactivation failures, save your work and restart Tabular Editor.\n";
}

summary += "\n=== SCRIPT COMPLETE ===\n";
summary += "Total relationships processed: " + relationshipInfo.Count + "\n";
summary += "Creation failures: " + creationErrors.Count + "\n";
summary += "Upgrade failures (deactivated): " + relsToDeactivate.Count + "\n";
summary += "Deactivation failures: " + deactivationFailures.Count + "\n";

// Output the summary to the Output window
Info(summary);
