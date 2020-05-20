Sub CDOSentEmail()
    Dim db As DAO.Database
    Dim rs As DAO.Recordset
    Dim sql As String
    Dim iMsg As Object
    Dim iConf As Object
    Dim strbody As String
    Dim Flds As Variant
    Dim xlsxDestinationWorkbook As String
    Dim DistList As String
    Dim delimiter As String
    Dim DateString As String
    Dim helpDocument As String
        
    DateString = Str(Date)
    
    delimiter = ", "
    
    ' Building the complete SQL string
    sql = "SELECT tblDistributionList.EmailAddress " & _
    "FROM tblDistributionList " & _
    "GROUP BY tblDistributionList.EmailAddress " & _
    "ORDER BY tblDistributionList.EmailAddress;"
    
    ' Opening a recordset
    Set db = CurrentDb
    Set rs = db.OpenRecordset(sql)
    Do Until rs.EOF
        ' Here we are looping through the records and, if the value is not NULL,
        ' Concatenate the field value of each record with the delimiter
        If Not IsNull(rs.Fields(0).Value) Then
            retVal = retVal & Nz(rs.Fields(0).Value, "") & delimiter
        End If
        rs.MoveNext
    Loop
    
    ' We cut away the last delimiter
    retVal = Left(retVal, Len(retVal) - Len(delimiter))
    
    ' Folder path to Help Document
    helpDocument = "\\USTCA097\Stage\Database Files\Award Percent by Lane\Over-Under 100 Percent Lane Report.docx"
       
    ' Export to .xlsx file, folder path
    xlsxDestinationWorkbook = "\\USTCA097\Stage\Database Files\Award Percent by Lane\Over-Under 100 Percent Lane Report.xlsx"
    
    ' Delete file in case file already exists, and prevent dupliates
    DeleteFile (xlsxDestinationWorkbook)
    
    ' Export to .xlsx file
    DoCmd.TransferSpreadsheet acExport, acSpreadsheetTypeExcel12Xml, "qryOverUnder100NoMode", xlsxDestinationWorkbook
    
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
    
    'Body is in VB, but could be changed to HTML
    strbody = "Hello," & vbNewLine & vbNewLine & _
        "Please see the attached for this week's Over-Under 100% Lane Reporting." & vbNewLine & _
        "Source - Award Lane = The lane is currently an awarded lane." & vbNewLine & _
        "Source - Bid App Rates Table = The lane is on the Bid App Rates table, but has no award." & vbNewLine & _
        "Source - 2019 Actuals Data = The lane has actuals data, but does not exist on Award or Bid App Rates tables." & vbNewLine & _
        "Source - Bid App Lanes Table = The lane is on the Bid App lanes table, but has no Actuals, Awards, or presence on the Bid App Rates tables." & vbNewLine & vbNewLine & _
        "Should you no longer wish to be on this distribution list, please reach out to steve.wolfe@kcc.com"
    
    ' Email Details
    With iMsg
        Set .Configuration = iConf
        .To = retVal
        .CC = ""
        .BCC = ""
        .FROM = """Rates & Analysis Team"" <steve.wolfe@kcc.com>"
        .Subject = "Weekly Over-Under Report - " & DateString
        .TextBody = strbody
        .AddAttachment xlsxDestinationWorkbook
        .AddAttachment helpDocument
        .Send
    End With

    Set iMsg = Nothing
    Set iConf = Nothing
    Set Flds = Nothing
End Sub

Function FileExists(ByVal FileToTest As String) As Boolean
   FileExists = (Dir(FileToTest) <> "")
End Function

Sub DeleteFile(ByVal FileToDelete As String)
   If FileExists(FileToDelete) Then 'See above
      ' First remove readonly attribute, if set
      SetAttr FileToDelete, vbNormal
      ' Then delete the file
      Kill FileToDelete
   End If
End Sub



'** Email link to share drive file**;
'
'options emailsys=smtp emailhost=mailhost.kcc.com emailport=25;
'
'      FILENAME output EMAIL
'      Subject = "Service Grade Review File"
'      FROM= 'gerina.s.booth@kcc.com'
'      TO= ('OptimizationTeam.Trans@kcc.com')
'      CC= ('gerina.s.booth@kcc.com','Thomas.G.Fraser2@kcc.com','Regina.S.Black@kcc.com','jeffrey.perrot@kcc.com')
'      CT= "text/html";
'      data _null_;
'      ODS HTML headtext= "<h1>Weekly Service Grade Review File</h1>";
'      ODS HTML BODY=output options(pagebreak="no") rs=none text=  "<p>Link to Service Grade Review File. Link will be sent weekly on Wednesdays.<br><br>  Purpose: Review Service Grade Penalties.  Ensure TM and Award Rankings Align. </p>
'      <a href='\\USKVFN01\SHARE\Transportation\Corporate Transportation\Truckload Pricing Event_2018-2019\Go-Live\SG_Check_NEW.xlsx'>SG Check</a>
'
'      <BR><BR><p>Note: This has the new cutoffs blocking rates < 10% above award with no minimum number of carriers</p>";
'      run;
'      ods _all_
