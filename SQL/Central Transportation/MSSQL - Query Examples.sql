-- Querying the local tables we built
Select * FROM  [NAJDAPRD]..[NAI2PADM].[TBLCUSTOMERS]
GO

-- Querying other standard NAJDAPRD tables
Select * FROM  [NAJDAPRD]..[NAJDAADM].[LOAD_LEG_R]
WHERE LOAD_LEG_R.LD_LEG_ID = '517269571'
GO

-- Getting column information from temp table, to use when building an actual table
SELECT
  tempdb.sys.columns.NAME,
  tempdb.sys.columns.Column_ID,
  tempdb.sys.columns.max_length AS DataLength,
  tempdb.sys.columns.SYSTem_type_ID,
  types.Name,
  types.max_length,
  types.precision,
  types.scale
FROM tempdb.sys.columns
INNER JOIN sys.types types
  ON types.system_type_id = tempdb.sys.columns.system_type_id
WHERE object_id = OBJECT_ID('tempdb..##tblActualLoadDetailsRFT')
AND types.Name <> 'sysname'
ORDER BY tempdb.sys.columns.Column_ID ASC;

-- Getting column information from schema table, to use when building an actual table
SELECT
  USCTTDEV.sys.columns.NAME,
  USCTTDEV.sys.columns.Column_ID,
  USCTTDEV.sys.columns.max_length AS DataLength,
  USCTTDEV.sys.columns.SYSTem_type_ID,
  types.Name,
  types.max_length,
  types.precision,
  types.scale
FROM USCTTDEV.sys.columns
INNER JOIN sys.types types
  ON types.system_type_id = USCTTDEV.sys.columns.system_type_id
WHERE object_id = OBJECT_ID('dbo.tblActualLoadDetail')
AND types.Name <> 'sysname'
ORDER BY USCTTDEV.sys.columns.Column_ID ASC;

--SELECT Max field length, and then show all distinct values
DECLARE @table NVARCHAR(30),
@field AS NVARCHAR(30)
SET @table = '##tblActualLoadDetailsRFT' --This is a table
SET @field = 'team_name'
EXEC('SELECT MAX(LEN(' + @field + ')) AS MaxLen FROM ' + @table)
EXEC('SELECT DISTINCT ' + @field + ' FROM ' + @table + ' ORDER BY ' + @field + ' ASC')