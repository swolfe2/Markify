/*
===========================================================================================
RELATIONSHIP ANALYSIS SCRIPT - V2 (MARKDOWN REPORT)
-------------------------------------------------------------------------------------------
Author: Steve Wolfe (Data Viz CoE), Revised by AI Assistant
Purpose:
This script analyzes all relationships involving a specified table and generates a
detailed, easy-to-read MARKDOWN report.

Output:
- Saves a detailed `.md` report to the user's Desktop.
- Logs the file path in the Tabular Editor Output window.

===========================================================================================
*/

var oldTableName = "table_name";

// Attempt to retrieve the table from the model
var oldTable = Model.Tables[oldTableName];
if (oldTable == null)
{
    Error("Table '" + oldTableName + "' not found!");
    return;
}

// Initialize a summary string to collect analysis output
var summary = "# Relationship Analysis for Table: `" + oldTableName + "`\n";
summary += "*Generated: " + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + "*\n\n";

// Find all relationships where the table is either on the From or To side
var relationships = Model.Relationships.Where(r => r.FromTable == oldTable || r.ToTable == oldTable).ToList();

if (relationships.Count == 0)
{
    summary += "No relationships found for table '" + oldTableName + "'.\n";
}
else
{
    summary += "Found " + relationships.Count + " relationship(s).\n\n";

    for (int i = 0; i < relationships.Count; i++)
    {
        var rel = relationships[i];
        var relNumber = (i + 1).ToString().PadLeft(2, '0');

        summary += "### RELATIONSHIP #" + relNumber + "\n";
        summary += "- **Name**: " + (string.IsNullOrEmpty(rel.Name) ? "*(unnamed)*" : "`" + rel.Name + "`") + "\n";
        summary += "- **From**: `" + rel.FromTable.Name + "`[`" + rel.FromColumn.Name + "`] (" + rel.FromCardinality.ToString() + ")\n";
        summary += "- **To**: `" + rel.ToTable.Name + "`[`" + rel.ToColumn.Name + "`] (" + rel.ToCardinality.ToString() + ")\n";
        summary += "- **Direction relative to `" + oldTableName + "`**: " + (rel.FromTable == oldTable ? "FROM old table" : "TO old table") + "\n";
        summary += "- **Active**: " + rel.IsActive.ToString() + "\n";
        summary += "- **Cross-filtering**: " + rel.CrossFilteringBehavior.ToString() + "\n";
        summary += "- **Security filtering**: " + rel.SecurityFilteringBehavior.ToString() + "\n";

        var otherTable = (rel.FromTable == oldTable) ? rel.ToTable : rel.FromTable;
        summary += "- **Other table**: `" + otherTable.Name + "` (Mode: `" + otherTable.Mode.ToString() + "`)\n";
        summary += "- **`" + oldTableName + "` table mode**: `" + oldTable.Mode.ToString() + "`\n";
        summary += "- **Column Types**: `" + rel.FromColumn.DataType.ToString() + "` -> `" + rel.ToColumn.DataType.ToString() + "`\n\n";
    }

    summary += "## Summary by Cross-Filtering\n";
    var bidirectional = relationships.Where(r => r.CrossFilteringBehavior.ToString() == "BothDirections").ToList();
    var oneDirection = relationships.Where(r => r.CrossFilteringBehavior.ToString() == "OneDirection").ToList();

    summary += "- **Bidirectional (BothDirections)**: " + bidirectional.Count + "\n";
    foreach (var rel in bidirectional)
    {
        var otherTable = (rel.FromTable == oldTable) ? rel.ToTable.Name : rel.FromTable.Name;
        summary += "  - `" + otherTable + "`\n";
    }

    summary += "- **One Direction**: " + oneDirection.Count + "\n";
    foreach (var rel in oneDirection)
    {
        var otherTable = (rel.FromTable == oldTable) ? rel.ToTable.Name : rel.FromTable.Name;
        summary += "  - `" + otherTable + "`\n";
    }
    
    summary += "\n";

    summary += "## Storage Mode Analysis\n";
    summary += "- **`" + oldTableName + "` mode**: `" + oldTable.Mode.ToString() + "`\n";
    summary += "- **Related tables**:\n";
    var relatedTables = relationships.Select(r => (r.FromTable == oldTable) ? r.ToTable : r.FromTable).Distinct().ToList();
    foreach (var table in relatedTables)
    {
        var mixedMode = (table.Mode != oldTable.Mode) ? " **** MIXED MODE ****" : "";
        summary += "  - `" + table.Name + "`: `" + table.Mode.ToString() + "`" + mixedMode + "\n";
    }
    
    summary += "\n";

    summary += "## Potential Migration Issues\n";
    var issues = new List<string>();
    foreach (var rel in relationships)
    {
        var otherTable = (rel.FromTable == oldTable) ? rel.ToTable : rel.FromTable;

        if (rel.CrossFilteringBehavior == CrossFilteringBehavior.BothDirections && otherTable.Mode != oldTable.Mode)
        {
            issues.Add("Bidirectional relationship with `" + otherTable.Name + "` may fail due to mixed storage modes.");
        }

        var sameTableRelCount = relationships.Count(r => ((r.FromTable == oldTable) ? r.ToTable : r.FromTable) == otherTable);
        if (sameTableRelCount > 1)
        {
            issues.Add("Multiple relationships to `" + otherTable.Name + "` may create ambiguous paths.");
        }
    }

    if (issues.Count > 0)
    {
        foreach (var issue in issues.Distinct())
        {
            summary += "- ⚠️  " + issue + "\n";
        }
    }
    else
    {
        summary += "- ✅ No obvious migration issues detected\n";
    }
}

summary += "\n## Migration Checklist\n";
summary += "- [ ] Save this analysis for reference\n";
summary += "- [ ] Note any bidirectional relationships that may fail\n";
summary += "- [ ] Consider storage mode compatibility\n";
summary += "- [ ] Check for ambiguous relationship paths\n";
summary += "- [ ] Run migration script\n";
summary += "- [ ] Verify cross-filtering settings manually\n";

// Save the summary to a file on the Desktop
var fileName = "Relationship_Analysis_" + oldTableName + "_" + DateTime.Now.ToString("yyyyMMdd_HHmmss") + ".md";
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
