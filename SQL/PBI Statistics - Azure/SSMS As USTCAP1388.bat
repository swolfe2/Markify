@echo off
set "SSMS_PATH=C:\Program Files\Microsoft SQL Server Management Studio 21\Release\Common7\IDE\SSMS.exe"
if not exist "%SSMS_PATH%" (
  echo Could not find SSMS at "%SSMS_PATH%". Update the path and try again.
  pause
  exit /b 1
)

echo You will be prompted for the KCUS\USTCAP1388 password. Typing is invisible by design.
runas /netonly /user:KCUS\USTCAP1388 "%SSMS_PATH%"
pause
