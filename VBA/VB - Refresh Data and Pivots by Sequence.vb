Public Sub RefreshData()

Dim wb As Workbook
Dim ws As Worksheet
Dim con As WorkbookConnection
Dim lo As ListObject
Dim lrow As Range
Dim stepNumber As String, queryName As String

'Set Active Workbook, just in case multiple are open
Set wb = ActiveWorkbook()
Name = wb.Name

'Turn on the status bar
Application.DisplayStatusBar = True

'Set the Distribution List worksheet, and activate
Set ws = wb.Worksheets("Refresh")
ws.Activate

'Clear last run date/time
ws.Range("C2:E2").Value = ""

'Clear Total Run Time
ws.Range("C5:E100").Value = ""

'Loop through refresh process table
Set lo = ws.ListObjects("tblRefreshProcess")

    For Each lrow In lo.DataBodyRange.Rows
    
        'Get the step number
        stepNumber = Intersect(lrow, lo.ListColumns("Step").Range).Value
    
        'Get the step name
        queryName = Intersect(lrow, lo.ListColumns("Step Name").Range).Value
        
        'Set the status bar message
        Application.StatusBar = "Refreshing Step " & stepNumber & " : " & queryName
        
        'Get the step name
        Intersect(lrow, lo.ListColumns("Refresh Started").Range).Value = Now()
        
            For Each con In ActiveWorkbook.Connections
                CName = con.Name
                If CName = "Query - " & queryName Then
                    With ActiveWorkbook.Connections(CName).OLEDBConnection
                        .BackgroundQuery = False  'or true, up to you if you feel spicy
                        .Refresh
                    End With
                End If
            Next
            
        'Get the step name
        Intersect(lrow, lo.ListColumns("Refresh Finished").Range).Value = Now()
        
        'Get the seconds difference
        Intersect(lrow, lo.ListColumns("Total Run Time").Range).Formula = "=IF(OR(ISBLANK([@[Refresh Started]]),ISBLANK([@[Refresh Finished]])),"""",ROUND(([@[Refresh Finished]]-[@[Refresh Started]])*86400,0))"
     
Next lrow

'Set status bar message
Application.StatusBar = "Refreshing step " & stepNumber & " : " & queryName

'Refresh all pivots
For Each ws In wb.Worksheets
    For Each pt In ws.PivotTables
                Application.StatusBar = "Refreshing pivot table : " & pt.Name
                pt.RefreshTable
    Next pt
    ActiveSheet.Cells(1, 1).Select
Next ws

'Make sure main sheet is active
Set ws = wb.Worksheets("Refresh")
ws.Activate

'Update the final run time values
ws.ListObjects("tblRefresh").ListColumns("Refresh Started").DataBodyRange.Formula = "=MIN(tblRefreshProcess[Refresh Started])"
ws.Range("C2").Formula = ""

'Set status bar message
Application.StatusBar = "Full refresh complete!"

'Set total run time
ws.ListObjects("tblRefresh").ListColumns("Refresh Started").DataBodyRange.Formula = "=MIN(tblRefreshProcess[Refresh Started])"
ws.ListObjects("tblRefresh").ListColumns("Refresh Finished").DataBodyRange.Formula = "=MAX(tblRefreshProcess[Refresh Finished])"
ws.ListObjects("tblRefresh").ListColumns("Total Run Time").DataBodyRange.Formula = "=SUM(tblRefreshProcess[Total Run Time])"

'Set number formats
ws.Range("C2:D2").NumberFormat = "M/D/YY H:MM:SS AM/PM"
ws.Range("E2").NumberFormat = "#,##0"
ws.Range("C5:D100").NumberFormat = "M/D/YY H:MM:SS AM/PM"
ws.Range("E100").NumberFormat = "#,##0"
ws.Range("F2:F100").NumberFormat = "M/D/YY H:MM:SS AM/PM"
ws.Range("C1:F100").HorizontalAlignment = xlCenter
ws.Range("C1:F100").VerticalAlignment = xlCenter

'Turn off the status bar
Application.DisplayStatusBar = False

End Sub