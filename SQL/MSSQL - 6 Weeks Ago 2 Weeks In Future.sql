SELECT da.TheDate, 
da.TheDayName, 
da.TheFirstOfWeekMon, 
da.TheLastOfWeekMon,
0 - DATEDIFF(wk, da.TheFirstOfWeekMon, DATEADD(wk, DATEDIFF(wk,0,GETDATE()), 0)) AS WeekDiff,
CASE WHEN 0 - DATEDIFF(wk, da.TheFirstOfWeekMon, DATEADD(wk, DATEDIFF(wk,0,GETDATE()), 0)) = 0 THEN 'Current Week'
WHEN 0 - DATEDIFF(wk, da.TheFirstOfWeekMon, DATEADD(wk, DATEDIFF(wk,0,GETDATE()), 0)) < 0 THEN CONCAT(0 - DATEDIFF(wk, da.TheFirstOfWeekMon, DATEADD(wk, DATEDIFF(wk,0,GETDATE()), 0)),' Weeks Ago')
ELSE CONCAT(0 - DATEDIFF(wk, da.TheFirstOfWeekMon, DATEADD(wk, DATEDIFF(wk,0,GETDATE()), 0)),' Weeks Ahead') END AS WeekFlag
FROM USCTTDEV.dbo.tblDates da
WHERE da.TheDate BETWEEN DATEADD(wk, DATEDIFF(wk, 6, GETDATE()) - 6, 0) AND DATEADD(wk, DATEDIFF(wk, 6, GETDATE()) + 5, -1)