#r "Microsoft.AnalysisServices.Core.dll"
using ToM = Microsoft.AnalysisServices.Tabular;

var refreshType = ToM.RefreshType.DataOnly;
ToM.SaveOptions so = new ToM.SaveOptions();
//so.MaxParallelism = 10;

foreach (var t in Selected.Tables)
{
    string tableName = t.Name;
    Model.Database.TOMDatabase.Model.Tables[tableName].RequestRefresh(refreshType); 
}

Model.Database.TOMDatabase.Model.SaveChanges(so);