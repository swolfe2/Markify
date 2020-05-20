echo
set odbc_path="C:\oracle\instantclient_10_2"
set tns_path="\\uskvfn01\SHARE\Transportation\Corporate Transportation\OTC Project\response_files\oracle instant client\NA\tnsnames.ora"

setx PATH "%Path%;C:\Oracle\instantclient_10_2"
setx TNS_ADMIN "C:\Oracle\instantclient_10_2" 

cd %odbc_path%

odbc_install.exe

copy %tns_path% C:\Oracle\instantclient_10_2

pause