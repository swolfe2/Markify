Public Sub Refresh()

Dim wb As Workbook
Dim ws As Worksheet
Dim con As WorkbookConnection
Dim i As long
Dim Name As String, CName As String

'Set Active Workbook, just in case multiple are open
Set wb = ActiveWorkbook()
Name = wb.Name

'Refresh data sources twice, just in case... You can turn this off by commenting out the for loop
For i = 1 to 2

    'Refresh the JDATariffs query first, to get the most recent tariffs
    For Each con In ActiveWorkbook.Connections
        CName = con.Name
            With ActiveWorkbook.Connections(CName).OLEDBConnection
                .BackgroundQuery = False  'or true, up to you
                .Refresh
            End With
    Next

    'Refresh specific LO
    Application.StatusBar = "Refreshing View Service Tariff Cross Ref"
    wb.Worksheets("View Service Tariff Cross Ref").ListObjects("Table_USTWAS03_tfr0nedb_MD_Service_TM_Tariff_Xref").QueryTable.Refresh BackgroundQuery:=False  

    Application.StatusBar = "Refreshing Manage Addendum Status"
    wb.Worksheets("Manage Addendum Status").Unprotect
    wb.Worksheets("Manage Addendum Status").ListObjects("Table_ExternalData_1").QueryTable.Refresh BackgroundQuery:=False
    wb.Worksheets("Manage Addendum Status").Protect

    'Refresh all pivots
    For Each ws In wb.Worksheets
        For Each pt In ws.PivotTables
                    pt.RefreshTable
        Next pt
        ActiveSheet.Cells(1, 1).Select
    Next ws

Next i

'Set the worksheet, and activate
Set ws = wb.Worksheets("Pivot")
ws.Activate

'Update the last run date/time
wb.Worksheets("Pivot").Range("D2").Value = Now()
wb.Worksheets("Pivot").Range("D2").NumberFormat = "m/d/yyyy h:mm:ss AM/PM"

End Sub
