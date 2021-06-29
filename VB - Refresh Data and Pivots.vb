Public Sub Refresh()

Dim wb As Workbook
Dim ws As Worksheet
Dim con As WorkbookConnection
Dim cellValue As String, queryName AS String
Dim i as long

'Set Active Workbook, just in case multiple are open
Set wb = ActiveWorkbook()
Name = wb.Name

'Clear last run date/time
wb.Worksheets("Pivot").Range("D2").Value = ""

'Set primary query name
queryName = "Query - qryServiceAndCompliance"

'Refresh data sources twice, just in case... You can turn this off by commenting out the for loop
For i = 1 to 2

    'Refresh the JDATariffs query first, to get the most recent tariffs
    For Each con In ActiveWorkbook.Connections
        CName = con.Name
        If CName = queryName Then
            With ActiveWorkbook.Connections(CName).OLEDBConnection
                .BackgroundQuery = False  'or true, up to you
                .Refresh
            End With
        End If
    Next

    'Since all others build on that Tariff query, can refresh them next
    For Each con In ActiveWorkbook.Connections
        CName = con.Name
        If Left(con.Name, 8) = "Query - " AND CName <> queryName Then
            With ActiveWorkbook.Connections(CName).OLEDBConnection
                .BackgroundQuery = False  'or true, up to you
                .Refresh
            End With
        End If
    Next

    'Refresh all pivots
    For Each ws In wb.Worksheets
        For Each pt In ws.PivotTables
                    pt.RefreshTable
        Next pt
        ActiveSheet.Cells(1, 1).Select
    Next ws

Next i

'Set the Distribution List worksheet, and activate
Set ws = wb.Worksheets("Pivot")
ws.Activate

'Update the last run date/time
wb.Worksheets("Pivot").Range("D2").Value = Now()
wb.Worksheets("Pivot").Range("D2").NumberFormat = "m/d/yyyy h:mm:ss AM/PM"

End Sub
