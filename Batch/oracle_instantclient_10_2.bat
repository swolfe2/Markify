echo

set unzip_path="\\uskvfn01\share\Transportation\Corporate Transportation\OTC Project\Resource Kit\unzip.exe"
set file_path="\\uskvfn01\share\Transportation\Corporate Transportation\OTC Project"
set install_path=C:\Oracle
set dest_path=C:\Resource_Kit\

mkdir %dest_path%

copy %unzip_path% %dest_path%

set Path=%Path%;%dest_path%

unzip %file_path%\instantclient-basic-win32-10.2.0.4.zip -d %install_path%
unzip %file_path%\instantclient-odbc-win32-10.2.0.4.zip -d %install_path%

pause