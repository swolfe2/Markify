Option Compare Database

Public Function tblAutomation()
Dim db As DAO.Database
Dim rs As DAO.Recordset
Dim Process, UserID, sql As String
Dim MaxID As Integer
Dim StartTime, EndTime, LastRan As Date

' Bring in tblAutomation from \\USTCA097\Stage\Database Files\Automation\Automation.accdb
' Be sure to make it a linked table!

' Get Current Process Name
Process = Application.CurrentProject.Name

' Get current System ID
UserID = Environ("USERNAME")

' Get Current Time
StartTime = Now()

' Opening a recordset
Set db = CurrentDb
DoCmd.SetWarnings False

' Get MaxID for Selected Process
sql = "SELECT Max(tblAutomation.ID) AS MaxOfID, tblAutomation.Process " & _
"FROM tblAutomation " & _
"WHERE (((tblAutomation.EndTime) Is Not Null)) " & _
"GROUP BY tblAutomation.Process " & _
"HAVING (((tblAutomation.Process)='" & Process & "'));"
Set rs = db.OpenRecordset(sql)

' Set MaxID
On Error Resume Next
MaxID = rs("MaxOfID")

' Get Full Recordset for MaxID
sql = "SELECT tblAutomation.ID, tblAutomation.Process, tblAutomation.StartTime, tblAutomation.EndTime, tblAutomation.UserID " & _
"FROM tblAutomation " & _
"GROUP BY tblAutomation.ID, tblAutomation.Process, tblAutomation.StartTime, tblAutomation.EndTime, tblAutomation.UserID " & _
"HAVING (((tblAutomation.ID)= " & MaxID & " ) AND ((tblAutomation.Process)='" & Process & "'));"
Set rs = db.OpenRecordset(sql)

' Set LastRan
LastRan = rs("StartTime")

'Compare Last Ran Date to today, and exit MSAccess if ran today
TodaysDate = DateValue(Now())
LastRan = DateValue(LastRan)

If LastRan >= TodaysDate Then
Application.Quit
Exit Function
Else

' Append record to tblAutomation, record begin of process
sql = "INSERT INTO tblAutomation ( Process, StartTime, UserID ) " & _
"SELECT '" & Process & "' AS Process, Now() AS StartTime, '" & UserID & "' AS UserID;"
DoCmd.RunSQL (sql)

' Get New MaxID for Selected Process
sql = "SELECT Max(tblAutomation.ID) AS MaxOfID, tblAutomation.Process " & _
"FROM tblAutomation " & _
"WHERE (((tblAutomation.EndTime) Is Null)) " & _
"GROUP BY tblAutomation.Process " & _
"HAVING (((tblAutomation.Process)='" & Process & "'));"
Set rs = db.OpenRecordset(sql)

' Set MaxID
MaxID = rs("MaxOfID")

' Run Main Macro (Replace MacroName with actual Macro name)
DoCmd.RunMacro "mcrRFTRefresh"

' Update EndTime of MaxID to now(), and calculate runtime in seconds
sql = "UPDATE tblAutomation SET tblAutomation.EndTime = Now(), tblAutomation.RunTime = DateDiff('s',[StartTime],Now()) " & _
"WHERE (((tblAutomation.ID)=" & MaxID & ") AND ((tblAutomation.Process)='" & Process & "'));"
DoCmd.RunSQL (sql)

End If

' Quit MSAccess
Application.Quit

End Function