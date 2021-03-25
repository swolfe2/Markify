Public Sub Refresh()

'Run Transit Time macro - NEW 12/11/2019 per Regina Black
'TransitTimes
    Dim wb As Workbook
    Dim conn As Variant
    Dim Query As Variant
    Dim pt As PivotTable
    Dim ws As Worksheet
    Dim name As String
    Dim conntype As Variant
    
    Set wb = ThisWorkbook
    
    'First refresh all connections
    For Each conn In wb.Connections
    name = conn.name
    conntype = conn.Type
    If conntype = "2" Then 'for MSAccess queries
        conn.ODBCConnection.BackgroundQuery = False
        conn.Refresh
        conn.ODBCConnection.BackgroundQuery = True
    Else 'for MSSQL queries
        conn.OLEDBConnection.BackgroundQuery = False
        conn.Refresh
        conn.OLEDBConnection.BackgroundQuery = True
    End If
    Next conn
    
    'Let's refresh them all again just for the heck of it
    For Each conn In wb.Connections
    name = conn.name
    conntype = conn.Type
    If conntype = "2" Then 'for MSAccess queries
        conn.ODBCConnection.BackgroundQuery = False
        conn.Refresh
        conn.ODBCConnection.BackgroundQuery = True
    Else 'for MSSQL queries
        conn.OLEDBConnection.BackgroundQuery = False
        conn.Refresh
        conn.OLEDBConnection.BackgroundQuery = True
    End If
    Next conn

    'ActiveWorkbook.RefreshAll
    
    'Refresh all pivots
    For Each ws In wb.Worksheets
        For Each pt In ws.PivotTables
                    pt.RefreshTable
        Next pt
        ActiveSheet.Cells(1, 1).Select
    Next ws
    
    'Set the Distribution List worksheet, and activate
    Set ws = wb.Worksheets("Distribution List")
    ws.Activate
    
    'Format them high level ranges in case they get FUBAR
    ws.Range("tblCurrentMonth[[#All],[Year]:[Difference]]").Select
    Selection.NumberFormat = "General"
    ws.Range("tblCurrentMonth[[#All],[Intermodal Impact]:[Missed Opportunities]]").Select
    Selection.NumberFormat = "$#,##0"
    ws.Range("tblCurrentMonthBU[[#Headers],[Year]:[Difference]]").Select
    ws.Range(Selection, Selection.End(xlDown)).Select
    ws.Range("tblCurrentMonthBU[[#Headers],[Intermodal Impact]]").Select
    ws.Range(Selection, Selection.End(xlToRight)).Select
    ws.Range(Selection, Selection.End(xlDown)).Select
    Selection.NumberFormat = "$#,##0"
    ActiveSheet.Cells(1, 1).Select
    
    'Select the Monthly View sheet, and select cell A1
    wb.Worksheets("Monthly View").Select
    ActiveSheet.Cells(1, 1).Select
    
    'Save Workbook
    Save
    
End Sub