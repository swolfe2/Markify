@REM @echo off

@REM ECHO Running Python Program -Regular
@REM start /min "" "C:\Program Files\Python311\Python.exe" "C:\Users\%username%\Desktop\Code\Python\Stay Awake\Stay Awake.py"
@REM if %ERRORLEVEL% neq 0 goto ProcessError-Python

@REM :ProcessError-Python
@REM ECHO Running Python Program -OneDrive
@REM start /min "" "C:\Program Files\Python311\Python.exe" "C:\Users\%username%\OneDrive - Kimberly-Clark\Desktop\Code\Python\Stay Awake\Stay Awake.py"

@REM ECHO Regular version did not work, had to use OneDrive

@echo off

ECHO Running Python Program -Regular
start /min "" "C:\Program Files\Python311\Python.exe" "C:\Users\%username%\Desktop\Code\Python\Stay Awake\Stay Awake - Random.py"
if %ERRORLEVEL% neq 0 goto ProcessError-Python

:ProcessError-Python
ECHO Running Python Program -OneDrive
start /min "" "C:\Program Files\Python311\Python.exe" "C:\Users\%username%\OneDrive - Kimberly-Clark\Desktop\Code\Python\Stay Awake\Stay Awake - Random.py"

ECHO Regular version did not work, had to use OneDrive


