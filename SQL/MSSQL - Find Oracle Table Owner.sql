--Declare and set table variable name
declare @tablename nvarchar(100)
SET @tablename = 'ABPP_OTC_CAPS_MASTER'

--Execute Stored Procedure to get base information about table name
EXEC sp_tables_ex @table_server = 'NAJDAPRD', @table_name = @tablename

--Execute query against linked server to get detail information about table
SELECT * FROM OPENQUERY(NAJDAPRD, 'SELECT* from all_all_tables ORDER BY TABLE_NAME') where TABLE_NAME = @tablename;