USE [USCTTDEV]
GO
/****** Object:  StoredProcedure [dbo].[sp_FourKitesNonDelivered]    Script Date: 8/4/2021 9:37:40 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Steve Wolfe, steve.wolfe@kcc.com, Central Transportation Team
-- Create date: 8/4/2021
-- Last modified: --
-- Description:	Get non-delivered load data from Snowflake DB containing FourKites data
-- =============================================

ALTER PROCEDURE [dbo].[sp_FourKitesNonDelivered]

AS
BEGIN
    -- SET NOCOUNT ON added to prevent extra result sets from
    -- interfering with SELECT statements.
    SET NOCOUNT ON;

    /*
Query written by: Steve Wolfe - KCNA Central Transportation

Why use this query?
If you're looking for FourKites tracking data for non-delivered loads. Note: Some loads may have actually delivered, and will 

What is this query doing?
1) Get non-delivered loads from Actual Load Detail (@loads)
2) Divide those loads into groups of no more than 500 loads each, so that passthrough query can execute (@loadGroups)
3) Loop through those groups, and transpose rows into text strings (@loadNumberStrings)
4) Loop through aggregate @loadNumberStrings table, and execute query against Snowflake DB for each group, then append to final table (@fourKitesData)

Logic for joining tables was provided by Ravi Gour to Steve Wolfe on 8/4/2021
*/

    /*
Get distinct Load Numbers to pass through, along with a string version with single quotes
*/
    DECLARE @loads TABLE(RowNumber        INT,
        LoadNumber       VARCHAR(20),
        LoadNumberString VARCHAR(30))
    INSERT INTO @loads
    SELECT
        ROW_NUMBER() OVER (ORDER BY loads.LD_LEG_ID ASC) AS RowNum,
        loads.LD_LEG_ID,
        loads.LD_LEG_ID_STRING
    FROM
        (
    SELECT
            DISTINCT
            ald.LD_LEG_ID,
            '''''' + CAST(ald.LD_LEG_ID AS VARCHAR(20)) + '''''' AS LD_LEG_ID_STRING
        FROM
            USCTTDEV.dbo.tblActualLoadDetail ald
        WHERE ald.DLVY_DTT IS NULL AND ald.SHPD_DTT IS NOT NULL AND ald.EQMT_TYP <> 'LTL'
            AND ald.LD_LEG_ID NOT LIKE '%-%') loads

    /*
Declare an integer that will evenly divide the full recordset into 500 loads each
*/
    DECLARE @loadGroupings INT, @i INT, @loadCount INT
    SET @loadGroupings = (SELECT
        CEILING(COUNT(*) / CAST (500 AS NUMERIC(10,2)))
    FROM
        @loads)
    SET @i = 1

    /*
Create a recordset with unique group numbers for each 500 records to process since the is a limit from Snowflake
*/
    DECLARE @loadGroups TABLE(RowNumber        INT,
        LoadNumber       VARCHAR(20),
        LoadNumberString VARCHAR(30),
        GroupNumber      INT)
    INSERT INTO @loadGroups
    SELECT
        RowNumber,
        LoadNumber,
        LoadNumberString,
        NTILE(@loadGroupings) OVER (ORDER BY RowNumber ASC) AS GroupNumber
    FROM
        @loads

    /*
Declare table to hold long strings, along with integers for load counts and text strings
*/
    DECLARE @loadNumberStrings TABLE (GroupNumber INT,
        LoadCount   INT,
        LoadArray   NVARCHAR(MAX))

    /*
Loop through groupings, and insert texts into subtable
*/
    WHILE @i <= @loadGroupings
	BEGIN
        /*
		Loop through each group number, and create SQL strings
		*/

        /*
		Convert @loads table variable into a single comma separated string
		*/
        DECLARE @loadNumbers NVARCHAR(MAX)

        /*
		Create the comma separated strings
		*/
        SET @loadNumbers = (
		 SELECT
            DISTINCT
            STUFF((
				SELECT
                ',' + u.LoadNumberString
            FROM
                @loadGroups u
            WHERE u.LoadNumber = LoadNumber
                AND u.GroupNumber = @i
            ORDER BY u.LoadNumber
            FOR XML PATH('')
			),1,1,'') AS LoadArray
        FROM
            @loadGroups
        WHERE GroupNumber = @i
        GROUP BY LoadNumber)

        /*
		Set the count of load numbers
		Not used for anything further, other than troubleshooting
		*/
        SET @loadCount = (SELECT
            COUNT(*)
        FROM
            @loadGroups
        WHERE GroupNumber = @i)

        /*
		Insert into @loadNumberStrings CTE for faster processing through SQL, since it will have a limited number of rows to process
		SELECT * FROM @loadNumberStrings
		*/
        INSERT INTO @loadNumberStrings
        SELECT
            @i,
            @loadCount,
            @loadNumbers

        SET @i =  @i + 1
    END

    /*
Create temp in memory table to hold results from open query
*/
    DECLARE @fourKitesData TABLE (SHIPMENT_NUM                         NVARCHAR(20),
        DELIVERY_HUB_HASHKEY_PK              NVARCHAR(50),
        SHIPMENT_HUB_HASHKEY_PK              NVARCHAR(50),
        DELIVERY_SHIPMENT_LINK_HASHKEY_PK    NVARCHAR(50),
        LOAD_DATE                            NVARCHAR(50),
        DESTINATION_STOP_ID                  NVARCHAR(25),
        DELIVERY_NUM                         NVARCHAR(20),
        FOURKITES_EXPECTED_DELIVERY_DATETIME DATETIME,
        FOURKITES_ACTUAL_ARRIVAL_DATETIME    DATETIME,
        FOURKITES_ACTUAL_DEPARTURE_DATETIME  DATETIME)

    /*
Reset @i counter
*/
    SET @i = 1

    /*
Set the linked server name, and beginning of passthrough
*/
    DECLARE @openquery NVARCHAR(100), @linkedServer NVARCHAR(50)
    SET @linkedServer = '[KCC.EAST-US-2.AZURE]'
    SET @openquery =  'SELECT * FROM OPENQUERY('+ @LinkedServer + ','

    /*
Set the query variable for passthrough
SELECT * FROM OPENQUERY([KCC.EAST-US-2.AZURE],'SELECT TOP 1 * FROM CONTROL_TOWER.INT.SHIPMENT_HUB')
SELECT * FROM OPENQUERY([KCC.EAST-US-2.AZURE],'SELECT TOP 1 * FROM CONTROL_TOWER.INT.DELIVERY_SHIPMENT_LINK')
SELECT * FROM OPENQUERY([KCC.EAST-US-2.AZURE],'SELECT TOP 1 * FROM CONTROL_TOWER.INT.DELIVERY_4K_STOPS_DETAILS_SATELITE')
SELECT * FROM OPENQUERY([KCC.EAST-US-2.AZURE],'SELECT TOP 1 * FROM CONTROL_TOWER.INT.FOUR_KITES_TRACK_DETAILS_SATELITE')

SELECT * FROM OPENQUERY([KCC.EAST-US-2.AZURE],'SELECT TOP 10 * FROM CONTROL_TOWER.INT.SHIPMENT_HUB WHERE SHIPMENT_NUM = ''522183890''')
SELECT * FROM OPENQUERY([KCC.EAST-US-2.AZURE],'SELECT TOP 10 * FROM CONTROL_TOWER.INT.DELIVERY_4K_STOPS_DETAILS_SATELITE WHERE DELIVERY_HUB_HASHKEY_PK = ''7f9080059d142a2f95d804ba5122f458''')
SELECT * FROM OPENQUERY([KCC.EAST-US-2.AZURE],'SELECT TOP 10 * FROM CONTROL_TOWER.INT.FOUR_KITES_TRACK_DETAILS_SATELITE WHERE SHIPMENT_HUB_HASHKEY_PK = ''7f9080059d142a2f95d804ba5122f458''')

*/
    DECLARE @queryString NVARCHAR(MAX)

    /*
Loop through groupings, and insert texts into subtable
*/

    WHILE @i <= @loadGroupings
	BEGIN

        /*
	Get the text string for each LoadArray for the unique iteratble group number -
	*/
        SET @LoadNumbers = (SELECT
            LoadArray
        FROM
            @loadNumberStrings
        WHERE GroupNumber = @i)

        SET @queryString = '''
		SELECT
		  sh.shipment_num,
		  Z.*,
		  stop_details.DESTINATION_STOP_ID,
		  stop_details.DELIVERY_NUM,
		  CASE WHEN STOP_DETAILS.FOURKITES_EXPECTED_DELIVERY_DATETIME = ''''-'''' THEN NULL ELSE STOP_DETAILS.FOURKITES_EXPECTED_DELIVERY_DATETIME END,
		  CASE WHEN STOP_DETAILS.FOURKITES_ACTUAL_ARRIVAL_DATETIME = ''''-'''' THEN NULL ELSE STOP_DETAILS.FOURKITES_ACTUAL_ARRIVAL_DATETIME END,
		  CASE WHEN STOP_DETAILS.FOURKITES_ACTUAL_DEPARTURE_DATETIME = ''''-'''' THEN NULL ELSE STOP_DETAILS.FOURKITES_ACTUAL_DEPARTURE_DATETIME END
		FROM CONTROL_TOWER.INT.shipment_hub sh
		INNER JOIN (SELECT
		  cc.DELIVERY_HUB_HASHKEY_PK,
		  cc.SHIPMENT_HUB_HASHKEY_PK,
		  cc.DELIVERY_SHIPMENT_LINK_HASHKEY_PK,
		  cc.LOAD_DATE AS LOAD_DATE
		FROM CONTROL_TOWER.INT.DELIVERY_SHIPMENT_LINK cc

		INNER JOIN (SELECT
		  DELIVERY_HUB_HASHKEY_PK,
		  MAX(LOAD_DATE) AS LOAD_DATE
		FROM CONTROL_TOWER.INT.DELIVERY_SHIPMENT_LINK
		GROUP BY DELIVERY_HUB_HASHKEY_PK) latest
		  ON cc.DELIVERY_HUB_HASHKEY_PK = latest.DELIVERY_HUB_HASHKEY_PK
		  AND cc.load_date = latest.load_date
		  AND counter = 1) Z
		  ON sh.SHIPMENT_HUB_HASHKEY_PK = z.SHIPMENT_HUB_HASHKEY_PK

		INNER JOIN (SELECT
		  ref.*
		FROM CONTROL_TOWER.INT.DELIVERY_4K_STOPS_DETAILS_SATELITE ref
		INNER JOIN (SELECT
		  DELIVERY_HUB_HASHKEY_PK,
		  MAX(LOAD_DATE) AS LOAD_DATE
		FROM CONTROL_TOWER.INT.DELIVERY_4K_STOPS_DETAILS_SATELITE
		GROUP BY DELIVERY_HUB_HASHKEY_PK) latest
		  ON ref.DELIVERY_HUB_HASHKEY_PK = latest.DELIVERY_HUB_HASHKEY_PK
		  AND ref.LOAD_DATE = latest.LOAD_DATE) stop_details
		  ON stop_details.DELIVERY_HUB_HASHKEY_PK = Z.DELIVERY_HUB_HASHKEY_PK
		WHERE sh.SHIPMENT_NUM IN (' + @loadNumbers + ')'')'


        /*
		Insert into @loadNumberStrings CTE for faster processing through SQL, since it will have a limited number of rows to process
		*/
        INSERT INTO @fourKitesData
        EXEC(@openquery + @querystring)

        SET @i =  @i + 1
    END

    /*
Select final data
*/
    SELECT
        *
    FROM
        @fourKitesData

END