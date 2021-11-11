/*
Create server memory table
*/
DECLARE @SERVERS TABLE (ID              INT          IDENTITY(1,1),
    SASDSN          NVARCHAR(50),
    Server          NVARCHAR(50),
    DefaultDatabase NVARCHAR(50) )

/*
Append values to server memory table
*/
INSERT INTO @SERVERS
    (SASDSN, Server, DefaultDatabase)
    SELECT
        'BEECH' AS [SASDSN],
        'UST2AS42' AS [Server],
        'WMS_WFM_USBI_BEECH' AS [DefaultDatabase]
UNION ALL
    SELECT
        'MODC' AS [SASDSN],
        'UST2AS42' AS [Server],
        'WMS_WFM_CAMO_MIL' AS [DefaultDatabase]
UNION ALL
    SELECT
        'NMC' AS [SASDSN],
        'UST2AS42' AS [Server],
        'WMS_WFM_USNM_NMC' AS [DefaultDatabase]
UNION ALL
    SELECT
        'JENKS' AS [SASDSN],
        'UST2AS43' AS [Server],
        'WMS_WFM_USOK_JNKS' AS [DefaultDatabase]
UNION ALL
    SELECT
        'MOBILE' AS [SASDSN],
        'UST2AS43' AS [Server],
        'WMS_WFM_USMO_MOB' AS [DefaultDatabase]
UNION ALL
    SELECT
        'FULLERTON' AS [SASDSN],
        'UST2AS44' AS [Server],
        'WMS_WFM_USFU_FUL' AS [DefaultDatabase]
UNION ALL
    SELECT
        'LADC' AS [SASDSN],
        'UST2AS44' AS [Server],
        'WMS_WFM_USOL_LADC' AS [DefaultDatabase]
UNION ALL
    SELECT
        'NWDC' AS [SASDSN],
        'UST2AS44' AS [Server],
        'WMS_WFM_USWW_NWDC' AS [DefaultDatabase]
UNION ALL
    SELECT
        'OGDEN' AS [SASDSN],
        'UST2AS44' AS [Server],
        'WMS_WFM_USOG_OGD' AS [DefaultDatabase]
UNION ALL
    SELECT
        'PNDC' AS [SASDSN],
        'UST2AS44' AS [Server],
        'WMS_WFM_CL3' AS [DefaultDatabase]
UNION ALL
    SELECT
        'SWDC' AS [SASDSN],
        'UST2AS44' AS [Server],
        'WMS_WFM_USLA' AS [DefaultDatabase]
UNION ALL
    SELECT
        'ERDC' AS [SASDSN],
        'UST2AS45' AS [Server],
        'WMS_WFM_USPT' AS [DefaultDatabase]
UNION ALL
    SELECT
        'SDDC' AS [SASDSN],
        'UST2AS46' AS [Server],
        'WMS_WFM_USSD_SDDC' AS [DefaultDatabase]
UNION ALL
    SELECT
        'SRDC' AS [SASDSN],
        'UST2AS46' AS [Server],
        'WMS_WFM_USAG' AS [DefaultDatabase]
UNION ALL
    SELECT
        'RBW' AS [SASDSN],
        'UST2AS86' AS [Server],
        'WMS2019_CL1' AS [DefaultDatabase]
UNION ALL
    SELECT
        'NCDC' AS [SASDSN],
        'USTWAS08' AS [Server],
        'WMS_WFM_USCH_NCDC' AS [DefaultDatabase]
UNION ALL
    SELECT
        'NCOF' AS [SASDSN],
        'USTWAS08' AS [Server],
        'WMS_WFM_USCH_NCOF' AS [DefaultDatabase]
UNION ALL
    SELECT
        'NCSF' AS [SASDSN],
        'USTWAS08' AS [Server],
        'WMS_WFM_CL6' AS [DefaultDatabase]
UNION ALL
    SELECT
        'PARIS' AS [SASDSN],
        'USTWAS08' AS [Server],
        'WMS_WFM_USPA_PARIS' AS [DefaultDatabase]
UNION ALL
    SELECT
        'NEDC' AS [SASDSN],
        'UST2AS45' AS [Server],
        'WMS_WFM_USPW_SMDC' AS [DefaultDatabase]
UNION ALL
    SELECT
        'NCOF' AS [SASDSN],
        'USTWAS008' AS [Server],
        'WMS2019_CL6' AS [DefaultDatabase]
UNION ALL
    SELECT
        'MIDSOUTH' AS [SASDSN],
        'UST2AS47' AS [Server],
        'WMS2019_CL2' AS [DefaultDatabase]
UNION ALL
    SELECT
        'MAUMELLE' AS [SASDSN],
        'UST2AS83' AS [Server],
        'WMS2019_CL5' AS [DefaultDatabase]
UNION ALL
    SELECT
        'CHESTER' AS [SASDSN],
        'UST2AS86' AS [Server],
        'WMS2019_CL1' AS [DefaultDatabase];

/*
Set beginning variables
*/
DECLARE @TOTALCOUNT INT = @@ROWCOUNT;
DECLARE @SQL NVARCHAR(MAX);
DECLARE @INDEXVAR INT = 1;
DECLARE @SASDSN SYSNAME;
DECLARE @CURSERVER SYSNAME
;
DECLARE @DEFAULTDATABASE SYSNAME;

/*
Drop temp table if exists
*/
DROP TABLE IF EXISTS ##tblLiveLoadTemp;

/*
Create live load temp table
*/
CREATE TABLE ##tblLiveLoadTemp
(
    LD_LEG_ID       NVARCHAR(20),
    SASDSN          NVARCHAR(20),
    Server          NVARCHAR(20),
    DefaultDatabase NVARCHAR(30)
);

WHILE @INDEXVAR <= @TOTALCOUNT  
BEGIN
    -- Get value of current indexed server  
    SELECT
        @SASDSN = SASDSN
    FROM
        @SERVERS
    WHERE ID = @INDEXVAR;
    SELECT
        @CURSERVER = Server
    FROM
        @SERVERS
    WHERE ID = @INDEXVAR;
    SELECT
        @DEFAULTDATABASE = DefaultDatabase
    FROM
        @SERVERS
    WHERE ID = @INDEXVAR;

    /*
Loop through all linked servers, and append to temp table
*/
    BEGIN
        SET @SQL = N'INSERT INTO ##tblLiveLoadTemp (LD_LEG_ID, SASDSN, Server, DefaultDatabase) SELECT DISTINCT doc_num, ''' + @SASDSN + ''', ''' + @CURSERVER + ''', ''' + @DEFAULTDATABASE + ''' FROM OPENQUERY(' + QUOTENAME(@CURSERVER) + N', ''SELECT * FROM ' + QUOTENAME(@DEFAULTDATABASE) + N'.dbo.CAR_MOVE cm WHERE cm.VC_EQUIP IS NOT NULL'')';
        PRINT @SQL;
        EXEC sp_executesql @SQL;
        SET @INDEXVAR += 1;
    END;
END;

/*
Dump final records for review
*/
SELECT
    *
FROM
    ##tblLiveLoadTemp;