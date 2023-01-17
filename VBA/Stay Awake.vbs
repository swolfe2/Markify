SET wsc = CreateObject("WScript.Shell")
DO
WScript.Sleep(4*60*1000)
wsc.SendKeys("{F13}")
Loop