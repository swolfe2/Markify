@echo off

ECHO Running Python Program -Regular
start /min "" "C:\Program Files\Python311\Python.exe" "C:\Users\%username%\Desktop\Code\Python\Tableau License Management\full_process.py"
if %ERRORLEVEL% neq 0 goto ProcessError-Python

:ProcessError-Python
ECHO Running Python Program -OneDrive
start /min "" "C:\Program Files\Python311\Python.exe" "C:\Users\%username%\OneDrive - Kimberly-Clark\Desktop\Code\Python\Tableau License Management\full_process.py"

ECHO Regular version did not work, had to use OneDrive

