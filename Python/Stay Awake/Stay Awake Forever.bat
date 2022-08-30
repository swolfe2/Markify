@echo off

ECHO Running Python Program -Regular
start /min "" "C:\Program Files\Python310\Python.exe" "C:\Users\%username%\Desktop\Code\Python\Stay Awake\Stay Awake Forever.py"
if %ERRORLEVEL% neq 0 goto ProcessError-Python

:ProcessError-Python
Running Python Program -OneDrive
start /min "" "C:\Program Files\Python310\Python.exe" "C:\Users\%username%\OneDrive - Kimberly-Clark\Desktop\Code\Python\Stay Awake\Stay Awake Forever.py"

ECHO Regular version did not work, had to use OneDrive

