/*
===========================================================================================
RELATIONSHIP ANALYSIS SCRIPT FOR TABULAR EDITOR
-------------------------------------------------------------------------------------------
Author: Steve Wolfe (Data Viz CoE)
Purpose:
This script analyzes all relationships involving a specified table (e.g., "Date") in a 
Tabular model. It generates a detailed report that includes:

- Relationship direction, cardinality, and filtering behavior
- Storage mode compatibility between related tables
- Data types of columns involved in each relationship
- Summary of cross-filtering configurations
- Identification of potential migration issues such as:
    • Mixed storage modes with bidirectional filters
    • Ambiguous paths due to multiple relationships to the same table
- A migration checklist for follow-up actions

Output:
- Saves a detailed `.txt` report to the user's Desktop
- Also logs the file path in the Output window

Use Case:
Ideal for preparing to migrate a table (e.g., replacing a DAX Date table with a Power Query 
version) while preserving or replicating its relationships safely.

===========================================================================================
*/

var oldTableName = "Date";

// Attempt to retrieve the table from the model
var oldTable = Model.Tables[oldTableName];
if (oldTable == null)
{
    Error("Table '" + oldTableName + "' not found!");
    return;
}

// Initialize a summary string to collect analysis output
var summary = "=== RELATIONSHIP ANALYSIS FOR TABLE: " + oldTableName + " ===\n";
summary += "Generated: " + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + "\n\n";

// Find all relationships where the table is either on the From or To side
var relationships = Model.Relationships.Where(r => r.FromTable == oldTable || r.ToTable == oldTable).ToList();

if (relationships.Count == 0)
{
    summary += "No relationships found for table '" + oldTableName + "'.\n";
}
else
{
    summary += "Found " + relationships.Count + " relationship(s):\n\n";

    for (int i = 0; i < relationships.Count; i++)
    {
        var rel = relationships[i];
        var relNumber = (i + 1).ToString().PadLeft(2, '0');

        summary += "--- RELATIONSHIP #" + relNumber + " ---\n";
        summary += "Name: " + (string.IsNullOrEmpty(rel.Name) ? "(unnamed)" : rel.Name) + "\n";
        summary += "From: " + rel.FromTable.Name + "[" + rel.FromColumn.Name + "] (" + rel.FromCardinality.ToString() + ")\n";
        summary += "To: " + rel.ToTable.Name + "[" + rel.ToColumn.Name + "] (" + rel.ToCardinality.ToString() + ")\n";
        summary += "Direction: " + (rel.FromTable == oldTable ? "OLD TABLE is FROM" : "OLD TABLE is TO") + "\n";
        summary += "Active: " + rel.IsActive.ToString() + "\n";
        summary += "Cross-filtering: " + rel.CrossFilteringBehavior.ToString() + "\n";
        summary += "Security filtering: " + rel.SecurityFilteringBehavior.ToString() + "\n";
        summary += "Referential integrity: " + rel.RelyOnReferentialIntegrity.ToString() + "\n";
        summary += "Join on date behavior: " + rel.JoinOnDateBehavior.ToString() + "\n";

        var otherTable = (rel.FromTable == oldTable) ? rel.ToTable : rel.FromTable;
        summary += "Other table: " + otherTable.Name + " (Mode: " + otherTable.Mode.ToString() + ")\n";
        summary += "Old table mode: " + oldTable.Mode.ToString() + "\n";
        summary += "From column type: " + rel.FromColumn.DataType.ToString() + "\n";
        summary += "To column type: " + rel.ToColumn.DataType.ToString() + "\n\n";
    }

    summary += "=== SUMMARY BY CROSS-FILTERING ===\n";
    var bidirectional = relationships.Where(r => r.CrossFilteringBehavior.ToString() == "BothDirections").ToList();
    var oneDirection = relationships.Where(r => r.CrossFilteringBehavior.ToString() == "OneDirection").ToList();
    var automatic = relationships.Where(r => r.CrossFilteringBehavior.ToString() == "Automatic").ToList();

    summary += "Bidirectional (BothDirections): " + bidirectional.Count + "\n";
    foreach (var rel in bidirectional)
    {
        var otherTable = (rel.FromTable == oldTable) ? rel.ToTable.Name : rel.FromTable.Name;
        summary += "  • " + otherTable + "\n";
    }

    summary += "One Direction: " + oneDirection.Count + "\n";
    foreach (var rel in oneDirection)
    {
        var otherTable = (rel.FromTable == oldTable) ? rel.ToTable.Name : rel.FromTable.Name;
        summary += "  • " + otherTable + "\n";
    }

    summary += "Automatic: " + automatic.Count + "\n";
    foreach (var rel in automatic)
    {
        var otherTable = (rel.FromTable == oldTable) ? rel.ToTable.Name : rel.FromTable.Name;
        summary += "  • " + otherTable + "\n";
    }

    summary += "\n=== STORAGE MODE ANALYSIS ===\n";
    summary += "Old table (" + oldTableName + ") mode: " + oldTable.Mode.ToString() + "\n";
    summary += "Related tables:\n";
    var relatedTables = relationships.Select(r => (r.FromTable == oldTable) ? r.ToTable : r.FromTable).Distinct().ToList();
    foreach (var table in relatedTables)
    {
        var mixedMode = (table.Mode.ToString() != oldTable.Mode.ToString()) ? " *** MIXED MODE ***" : "";
        summary += "  • " + table.Name + ": " + table.Mode.ToString() + mixedMode + "\n";
    }

    summary += "\n=== POTENTIAL MIGRATION ISSUES ===\n";
    var issues = new List<string>();
    foreach (var rel in relationships)
    {
        var otherTable = (rel.FromTable == oldTable) ? rel.ToTable : rel.FromTable;

        if (rel.CrossFilteringBehavior.ToString() == "BothDirections" && 
            otherTable.Mode.ToString() != oldTable.Mode.ToString())
        {
            issues.Add("Bidirectional relationship with " + otherTable.Name + " may fail due to mixed storage modes");
        }

        var sameTableRelCount = relationships.Count(r => 
            ((r.FromTable == oldTable) ? r.ToTable : r.FromTable) == otherTable);
        if (sameTableRelCount > 1)
        {
            issues.Add("Multiple relationships to " + otherTable.Name + " may create ambiguous paths");
        }
    }

    if (issues.Count > 0)
    {
        foreach (var issue in issues.Distinct())
        {
            summary += "⚠️  " + issue + "\n";
        }
    }
    else
    {
        summary += "✅ No obvious migration issues detected\n";
    }
}

summary += "\n=== MIGRATION CHECKLIST ===\n";
summary += "□ Save this analysis for reference\n";
summary += "□ Note any bidirectional relationships that may fail\n";
summary += "□ Consider storage mode compatibility\n";
summary += "□ Check for ambiguous relationship paths\n";
summary += "□ Run migration script\n";
summary += "□ Verify cross-filtering settings manually\n";

// Save the summary to a file on the Desktop
var fileName = "Relationship_Analysis_" + oldTableName + "_" + DateTime.Now.ToString("yyyyMMdd_HHmmss") + ".txt";
var filePath = Environment.GetFolderPath(Environment.SpecialFolder.Desktop) + "\\" + fileName;

try 
{
    System.IO.File.WriteAllText(filePath, summary);
    Info("Analysis saved to: " + filePath);
}
catch (Exception ex)
{
    Info("Could not save file: " + ex.Message);
}

// Optionally, also show the summary in the Output window
// Output(summary);
