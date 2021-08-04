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

Public Sub RefreshAndEmail()
Dim wb As Workbook, mainwb As Workbook, newwb As Workbook
Dim dSheet As Worksheet
Dim lo As ListObject
Dim newWBname As String, newWBPath As String, lastSentStr As String
Dim currentDate As Date, lastSent As Date
Dim copySheets As String
Dim copySheetsArray As Variant
Dim i As Long, hoursAgo As Long, hourDiff As Long

'Open Macro file
Set wb = ActiveWorkbook()
wb.Activate

'Set main workbook
Set mainwb = Workbooks(wb.Name)

'Set main listobject
Set lo = mainwb.Worksheets("Refresh").ListObjects("tblRefresh")

'Get the most recent emailed date
lastSentStr = lo.ListColumns("Last Emailed").DataBodyRange.Value

'Get the last sent date/time
If IsEmpty(lastSentStr) Or lastSentStr = "" Then
    lastSent = "1/1/1900"
Else
    lastSent = lo.ListColumns("Last Emailed").DataBodyRange.Value
End If

'If the email was sent today, don't send again. You can adjust this value.
hoursAgo = 24
hourDiff = dateDiff("h", lastSent, Now())
If hourDiff < hoursAgo Then
    'Ensure the user wants to update the record
    i = MsgBox("Emails were sent " & hourDiff & " hours ago. Are you sure you want to send another one?", vbYesNo, "Confirmation")
        'If the user presses No, then exit sub
        If i = vbNo Then
            Exit Sub
        Else
            GoTo Continue
        End If
End If

Continue:
'Refresh data
Call RefreshData

'Save as import file
Application.DisplayAlerts = False

'Create a new workbook specifically for the RateChanges tab
Set newwb = Workbooks.Add

'Set new workbook name
'newWBname = "\\IN00AAP024\Contract Data\Production\ImportFiles\Archive\Rate Loading Success - " & Format(Date, "m.d.yyyy") & ".xlsb"
newWBname = "International Shipment Analysis - " & Format(Date, "m.d.yyyy") & ".xlsb"

'Array to hold sheets to copy
copySheets = ("CV_MM03 List, CV_OSM_PURCHASE_ORDERS, Sharepoint Data Full")

'Split the array by delimiter
copySheetsArray = Split(copySheets, ", ")

'Loop through array, and create individual sheets
For Each Name In copySheetsArray
    sheetName = Name
    Set dSheet = mainwb.Worksheets(sheetName)
    dSheet.Activate
    
    'Copying a worksheet from ThisWorkbook into newly creadted workbook in the above statement
    dSheet.Copy Before:=newwb.Sheets(1)
        
Next Name

'Dekete the Sheet1 that's always made with new workbooks
newwb.Sheets("Sheet1").Delete

'Save as .xlsb version
newwb.SaveAs Filename:=CreateObject("WScript.Shell").SpecialFolders("Desktop") & "\" & newWBname, FileFormat _
:=xlExcel12, CreateBackup:=False

'Get filepath to new workbook
newWBPath = newwb.Path

'Close new .xlsb workbook
newwb.Close

'Save as .xlsm version
'wb.SaveAs Filename:="\\IN00AAP024\Contract Data\Production\Automation\Carrier Rate Change Import Process.xlsm", FileFormat _
:=xlOpenXMLWorkbookMacroEnabled, CreateBackup:=False

'Select main worksheet
mainwb.Worksheets("Refresh").Activate

'Save as parent workbook
mainwb.Save

Application.DisplayAlerts = True

'Send the email
Call CDOSendSuccessEmailReport(newWBPath & "\" & newWBname)

'Set the current time tthe email was sent
lo.ListColumns("Last Emailed").DataBodyRange.Formula = Format(Now(), "M/D/YY H:M:SS AM/PM")

End Sub

Function GetToEmails() As String
Dim RowCount As Integer, StartRow As Integer, EndRow As Integer
Dim tbl As ListObject

Set tbl = ThisWorkbook.Sheets("Distribution List").ListObjects("tblDistributionTo")

'Get the max number of filled in rows in Setup(A:A)
RowCount = tbl.Range.Rows.Count

'Set the starting row
StartRow = 2

'Set the end row, +1 to account for hepader
EndRow = RowCount + 1

Do While StartRow < EndRow
    If Len(ToAddresses) < 1 Then
        ToAddresses = tbl.Range(StartRow).Value
    Else
        ToAddresses = ToAddresses & ";" & tbl.Range(StartRow).Value
    End If
    
    'Increase Start Row
    StartRow = StartRow + 1

Loop

'Set final string
GetToEmails = ToAddresses

End Function

Function GetCCEmails() As String
Dim RowCount As Integer, StartRow As Integer, EndRow As Integer
Dim tbl As ListObject

Set tbl = ThisWorkbook.Sheets("Distribution List").ListObjects("tblDistributionCC")

'Get the max number of filled in rows in Setup(A:A)
RowCount = tbl.Range.Rows.Count

'Set the starting row
StartRow = 2

'Set the end row, +1 to account for hepader
EndRow = RowCount + 1

Do While StartRow < EndRow
    If Len(CCAddresses) < 1 Then
        CCAddresses = tbl.Range(StartRow).Value
    Else
        CCAddresses = CCAddresses & ";" & tbl.Range(StartRow).Value
    End If
    
    'Increase Start Row
    StartRow = StartRow + 1

Loop

'Set final string
GetCCEmails = CCAddresses

End Function

Sub CDOSendSuccessEmailReport(strFileName As String)
    
    Dim iMsg As Object
    Dim iConf As Object
    Dim strbody As String
    Dim Flds As Variant
    Dim delimiter As String
    Dim DateString As String
    Dim helpDocument As String
    Dim emailBodyDateStr As String
    Dim strEmailSubj As String
    Dim ToEmails As String
    Dim CCEmails As String
    
    'Get to emails
    ToEmails = GetToEmails
    
    'Get CC emails
    CCEmails = GetCCEmails
    
    'Set subject
    strEmailSubj = "International Shipment Analysis: " & Format(Date, "m/d/yyyy")
    
    'Change Semicolon to Comma
    'Emails = Replace(Emails, ";", ",")
    
    'Comment out for production
    'ToEmails = "steve.wolfe@kcc.com"
    'CCEmails = ""
    delimiter = ", "
    
' Start Email Message
    Set iMsg = CreateObject("CDO.Message")
    Set iConf = CreateObject("CDO.Configuration")
    
    iConf.Load -1    ' CDO Source Defaults
    Set Flds = iConf.Fields
    With Flds
        .Item("http://schemas.microsoft.com/cdo/configuration/sendusing") = 2
        .Item("http://schemas.microsoft.com/cdo/configuration/smtpserver") = "mailhost.kcc.com"
        .Item("http://schemas.microsoft.com/cdo/configuration/smtpserverport") = 25
        .Update
    End With


'Body in HTML
    HTMLBody = "<html><head><style> " & _
                "table {border-collapse: collapse;} " & _
                "th, td {border:2px black solid !important;} " & _
                "th {background-color: #3C93CB; color: white; padding: 5px; } " & _
                "td {text-align: left; padding: 5px; } " & _
                "</style></head><body> " & _
    "<p>Hello, <br><br> " & _
    "Please see the attached document for the most recent data refresh of International Shipment data.<br><br> " & _
    "<span style='color:orange'><i><b>*Note: This email address only sends outbound emails, and replies will not be looked at.</b></i></span>" & _
    "</body>"

' Email Ds
    With iMsg
        Set .Configuration = iConf
        .To = ToEmails
        .CC = CCEmails
        .BCC = "strategyandanalysis.ctt@kcc.com"
        .FROM = """Strategy & Analysis Team"" <strategyandanalysis.ctt@kcc.com>"
        .Subject = strEmailSubj
'.TextBody = strbody
        .HTMLBody = HTMLBody
        .AddAttachment strFileName
'.AddAttachment helpDocument
        .Send
    End With
    
    Set iMsg = Nothing
    Set iConf = Nothing
    Set Flds = Nothing
End Sub
