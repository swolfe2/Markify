USE [USCTTDEV]
GO
/****** Object:  StoredProcedure [dbo].[sp_OperationalMetrics]    Script Date: 8/30/2021 3:00:03 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
-- =============================================
-- Author:		<Steve Wolfe, steve.wolfe@kcc.com, Central Transportation Team>
-- Create date: <9/6/2019>
-- Last modified: <8/20/2021>
-- Description:	<Executes Tim Zoppa's query against Oracle, loads to temp table, then appends/updates dbo.tblOperationalMetrics>
-- 8/30/2021 - SW - Update SHIP_DATE to only include load_leg_r.SHPD_DTT value, or null when not there
-- 8/20/2021 - SW - Update to include COMPLETION_DATE_TIME Per Jeff Perrot, wanting to measure when the loads are actually picked up. Also added PICKUP_TIME  using logic from him.
-- 4/27/2021 - SW - Update to include the first pickup appointment from/to times for Tableau Reporting
-- 3/30/2021 - SW - Update to include START_DTT for Tableau reporting
-- 3/10/2021 - SW - Update to include Z05 as NON WOVEN order type
-- 3/1/2021 - SW - Changed region logic to also include the Business Unit
-- 1/13/2021 - SW - Added subquery to update TEAM_NAME/TEAM_GROUP with table data from Eric Mailhan
-- 6/29/2020 - SW - Added new fields needed by Katie Haynes for Tableau Reporting, updating directly from Actual Load Detail
-- 6/25/2020 - SW - Added CREATE_DTT, FIRST_APPT_NOTIFIED, FIRST_APPT_CONFIRMED for Curtis Moore, and Appointment Reporting
-- 6/11/2020 - SW - Added TM_AUCT_CNT, and changed First Tendered to exclude CARR_CD 'FRAN' per email from Taylor Rotella
-- 1/24/2020 - SW - Added new queries to handle CORP1_ID from LOAD_AT_R
Added queries to assign Region / Carrier manager to table
-- 1/14/2020 - SW - Update new column, DestCity, with unique dest city value from dbo_tblZoneCities
-- 1/2/2020 - Added Cancelled Loads stored procedure at end
-- 12/2/2019 - Added CARR_ARRIVED_AT_DATETIME from OTC Caps Master
-- 10/28/2019 - Added update query to change status to match RFT if no longer in SQL query

-- =============================================
*/
ALTER PROCEDURE [dbo].[sp_OperationalMetrics]

AS
BEGIN
    -- SET NOCOUNT ON added to prevent extra result sets from
    -- interfering with SELECT statements.
    SET NOCOUNT ON;

    -- Insert statements for procedure here
    /*
This SQL file replicates Tim Zoppa's SQL file, and records historical data to MSSQL since Oracle purges after 90 days
MSSQL AUTHOR: Steve Wolfe
ORACLE AUTHOR: Tim Zoppa
*/

    /*
Delete Temp table, if exists
*/
    DROP TABLE IF EXISTS
##tblOperationalMetricsTemp

    /*
Declare query variable, since query is more than 8,000 characters
*/
    DECLARE @myQuery VARCHAR(MAX)

    /*
Set query
*/
    SET @myQuery = 'SELECT * FROM (WITH

/********************************************************************************************************************

/* MANUAL CUSTOMER GROUPINGS - Updated 10/7/2019

/********************************************************************************************************************/ customer_groupings AS (
    SELECT
        ''HIERARCHY'' AS hierarchy,
        ''CUSTOMER'' AS customer,
        ''PRIORITY'' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58019941'' AS hierarchy,
        ''ACKLAND GRAINGER INC'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58006364'' AS hierarchy,
        ''AFFILIATED FOODS'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58007310'' AS hierarchy,
        ''AMAZON'' AS customer,
        ''TIER 1'' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58064480'' AS hierarchy,
        ''AMAZON'' AS customer,
        ''TIER 1'' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58059586'' AS hierarchy,
        ''AMAZON'' AS customer,
        ''TIER 1'' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58006207'' AS hierarchy,
        ''AMERISOURCEBERGEN'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58006547'' AS hierarchy,
        ''ASSOCIATED FOOD'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58016124'' AS hierarchy,
        ''AUTO ZONE'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58006486'' AS hierarchy,
        ''AWG'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58006496'' AS hierarchy,
        ''AWG'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58008423'' AS hierarchy,
        ''BIG LOTS'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58006634'' AS hierarchy,
        ''BI-MART CORP'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58006900'' AS hierarchy,
        ''BJS WHOLESALE'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58006151'' AS hierarchy,
        ''BOZZUTOS'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58015287'' AS hierarchy,
        ''BRADY INDUSTRIES'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58006446'' AS hierarchy,
        ''BROOKSHIRE GROCERY CO'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58013906'' AS hierarchy,
        ''BUNZL'' AS customer,
        ''TIER 1'' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58019996'' AS hierarchy,
        ''BUNZL'' AS customer,
        ''TIER 1'' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58006032'' AS hierarchy,
        ''C AND S'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58063443'' AS hierarchy,
        ''C AND S'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58063454'' AS hierarchy,
        ''C AND S'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58006478'' AS hierarchy,
        ''CERTCO INC'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58004966'' AS hierarchy,
        ''COSTCO'' AS customer,
        ''TIER 1'' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58003496'' AS hierarchy,
        ''CVS'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58006201'' AS hierarchy,
        ''DELHAIZE'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58006878'' AS hierarchy,
        ''DELHAIZE'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58006155'' AS hierarchy,
        ''DEMOULAS'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58064822'' AS hierarchy,
        ''DIAPER BANKS'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58006763'' AS hierarchy,
        ''DISCOUNT DRUG MART'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58007089'' AS hierarchy,
        ''DOLLAR GENERAL'' AS customer,
        ''TIER 1'' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58013949'' AS hierarchy,
        ''DUNKIN DONUTS'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58062902'' AS hierarchy,
        ''ESSENDANT'' AS customer,
        ''TIER 1'' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58006254'' AS hierarchy,
        ''FAMILY DOLLAR / DOLLAR TREE'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58007093'' AS hierarchy,
        ''FAMILY DOLLAR / DOLLAR TREE'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58008762'' AS hierarchy,
        ''FAMILI-PRIX INC'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58006775'' AS hierarchy,
        ''FAREWAY STORES'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58003605'' AS hierarchy,
        ''FEDERATED CO-OP'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58020237'' AS hierarchy,
        ''FISHER SCIENTIFIC'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58006572'' AS hierarchy,
        ''FOOD 4 LESS'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58006332'' AS hierarchy,
        ''FOOD CITY'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58056179'' AS hierarchy,
        ''FRITO LAY'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58013436'' AS hierarchy,
        ''GENERAL KCP'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58006193'' AS hierarchy,
        ''GIANT EAGLE'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58006181'' AS hierarchy,
        ''GOLUB WHSE'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58008428'' AS hierarchy,
        ''GROCERY OUTLET INC'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58006415'' AS hierarchy,
        ''HARRIS TEETER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58006843'' AS hierarchy,
        ''HEBUTT'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58006458'' AS hierarchy,
        ''HOME DELIVERY INCONTINENCE'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58014425'' AS hierarchy,
        ''HOME DEPOT'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58006500'' AS hierarchy,
        ''HY-VEE'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58063328'' AS hierarchy,
        ''JET.COM'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58006258'' AS hierarchy,
        ''JETRO CASH AND CARRY'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58066013'' AS hierarchy,
        ''KCP CUSTOMER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58013745'' AS hierarchy,
        ''KCP CUSTOMER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58015796'' AS hierarchy,
        ''KCP CUSTOMER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58014239'' AS hierarchy,
        ''KCP CUSTOMER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58015498'' AS hierarchy,
        ''KCP CUSTOMER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58011433'' AS hierarchy,
        ''KCP CUSTOMER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58013729'' AS hierarchy,
        ''KCP CUSTOMER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58059211'' AS hierarchy,
        ''KCP CUSTOMER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58019957'' AS hierarchy,
        ''KCP CUSTOMER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58027580'' AS hierarchy,
        ''KCP CUSTOMER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58014795'' AS hierarchy,
        ''KCP CUSTOMER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58027590'' AS hierarchy,
        ''KCP CUSTOMER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58013894'' AS hierarchy,
        ''KCP CUSTOMER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58027605'' AS hierarchy,
        ''KCP CUSTOMER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58015123'' AS hierarchy,
        ''KCP CUSTOMER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58020259'' AS hierarchy,
        ''KCP CUSTOMER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58058991'' AS hierarchy,
        ''KCP CUSTOMER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58020267'' AS hierarchy,
        ''KCP CUSTOMER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58064604'' AS hierarchy,
        ''KCP CUSTOMER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58004012'' AS hierarchy,
        ''KCP CUSTOMER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58011583'' AS hierarchy,
        ''KCP CUSTOMER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58065128'' AS hierarchy,
        ''KCP CUSTOMER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58014397'' AS hierarchy,
        ''KCP CUSTOMER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58015255'' AS hierarchy,
        ''KCP CUSTOMER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58056525'' AS hierarchy,
        ''KCP CUSTOMER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58027637'' AS hierarchy,
        ''KCP CUSTOMER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58005693'' AS hierarchy,
        ''KCP CUSTOMER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58013832'' AS hierarchy,
        ''KCP CUSTOMER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58056178'' AS hierarchy,
        ''KCP CUSTOMER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58011324'' AS hierarchy,
        ''KCP CUSTOMER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58020059'' AS hierarchy,
        ''KCP CUSTOMER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58015538'' AS hierarchy,
        ''KCP CUSTOMER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58065278'' AS hierarchy,
        ''KCP CUSTOMER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58013681'' AS hierarchy,
        ''KCP CUSTOMER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58013808'' AS hierarchy,
        ''KCP CUSTOMER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58014247'' AS hierarchy,
        ''KCP CUSTOMER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58015462'' AS hierarchy,
        ''KCP CUSTOMER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58020233'' AS hierarchy,
        ''KCP CUSTOMER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58020025'' AS hierarchy,
        ''KCP CUSTOMER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58013653'' AS hierarchy,
        ''KCP CUSTOMER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58020302'' AS hierarchy,
        ''KCP CUSTOMER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58015976'' AS hierarchy,
        ''KCP CUSTOMER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58063481'' AS hierarchy,
        ''KCP CUSTOMER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58018827'' AS hierarchy,
        ''KCP CUSTOMER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58011563'' AS hierarchy,
        ''KCP CUSTOMER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58003441'' AS hierarchy,
        ''K-MART'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58056571'' AS hierarchy,
        ''KC DE MEXICO'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58004860'' AS hierarchy,
        ''KROGER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58003621'' AS hierarchy,
        ''LE GROUPE JEAN COUTU INC'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58020277'' AS hierarchy,
        ''LOBLAWS'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58003614'' AS hierarchy,
        ''LONDON DRUGS'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58064926'' AS hierarchy,
        ''MAKRO GROCERS LLC'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58065443'' AS hierarchy,
        ''MARCHELEOS INC'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58004944'' AS hierarchy,
        ''MARCS DISTRIBUTION'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58011420'' AS hierarchy,
        ''MCKESSON'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58011493'' AS hierarchy,
        ''MCKESSON'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58011426'' AS hierarchy,
        ''MCKESSON'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58004894'' AS hierarchy,
        ''MEIJER'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58017333'' AS hierarchy,
        ''MENARDS'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58003636'' AS hierarchy,
        ''METRO'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58007825'' AS hierarchy,
        ''MILLS FLEET FARM'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58009221'' AS hierarchy,
        ''MINERS WAREHOUSE'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58006296'' AS hierarchy,
        ''NASH FINCH'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58064995'' AS hierarchy,
        ''OCEAN STATE JOBBERS INC'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58064500'' AS hierarchy,
        ''OFFICE DEPOT'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58017541'' AS hierarchy,
        ''OZARK AUTO DIST'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58006857'' AS hierarchy,
        ''PUBLIX'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58007101'' AS hierarchy,
        ''RITEAID'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58006864'' AS hierarchy,
        ''SAFEWAY'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58005988'' AS hierarchy,
        ''SAMS'' AS customer,
        ''TIER 1'' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58006511'' AS hierarchy,
        ''SHOPKO'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58006527'' AS hierarchy,
        ''SCHNUCK MARKETS'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58006823'' AS hierarchy,
        ''SMART AND FINAL'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58060619'' AS hierarchy,
        ''SP RICHARDS'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58018975'' AS hierarchy,
        ''STAPLES'' AS customer,
        ''TIER 1'' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58020701'' AS hierarchy,
        ''STAPLES'' AS customer,
        ''TIER 1'' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58006815'' AS hierarchy,
        ''STATER BROS'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58006819'' AS hierarchy,
        ''SUPER STORE INDUSTRIES'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58006054'' AS hierarchy,
        ''SUPERVALUE'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58003411'' AS hierarchy,
        ''TARGET'' AS customer,
        ''TIER 1'' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58009199'' AS hierarchy,
        ''THE NORTH WEST CO'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58015573'' AS hierarchy,
        ''ULINE'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58009942'' AS hierarchy,
        ''UNITED SALES DISTRIBUTORS'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58006638'' AS hierarchy,
        ''URM STORES'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58015593'' AS hierarchy,
        ''US FOOD SERVICE'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58027733'' AS hierarchy,
        ''VA MEDICAL '' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58015837'' AS hierarchy,
        ''VERITIV'' AS customer,
        ''TIER 1'' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58015716'' AS hierarchy,
        ''VERITIV'' AS customer,
        ''TIER 1'' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58004948'' AS hierarchy,
        ''WAKEFERN'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58007162'' AS hierarchy,
        ''WALGREENS'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58005914'' AS hierarchy,
        ''WALMART'' AS customer,
        ''TIER 1'' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58014837'' AS hierarchy,
        ''WAXIE'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58006185'' AS hierarchy,
        ''WEGMANS FOOD'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58006189'' AS hierarchy,
        ''WEIS MARKET'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58006807'' AS hierarchy,
        ''WINCO FOODS'' AS customer,
        '''' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        ''58006462'' AS hierarchy,
        ''WOODMANS'' AS customer,
        '''' AS priority
    FROM
        dual
),

/********************************************************************************************************************

/* REASON CODE DESCRIPTION LIST - COPY DESCRIPTIONS FOR ALL CODES AS D- AND P- CODES

/********************************************************************************************************************/ reason_code_desc AS (
    SELECT
        reason_code,
        MIN(tm_desc) AS "REASON_DESC"
    FROM
        najdatrn.abpp_reason_code_score
    GROUP BY
        reason_code
    UNION ALL
    SELECT
        ''D-'' || reason_code,
        MIN(tm_desc) AS "REASON_DESC"
    FROM
        najdatrn.abpp_reason_code_score
    GROUP BY
        reason_code
    UNION ALL
    SELECT
        ''P-'' || reason_code,
        MIN(tm_desc) AS "REASON_DESC"
    FROM
        najdatrn.abpp_reason_code_score
    GROUP BY
        reason_code
),

/********************************************************************************************************************

/* SALES ORG WITH THE MOST CUBIC VOLUME ON EACH LOAD

/********************************************************************************************************************/ sales_org AS (
    SELECT
        ld_leg_id,
        rfrc_num10 AS "SALES_ORG"
    FROM
        (
            SELECT
                ll.ld_leg_id,
                sh.rfrc_num10,
                SUM(sh.bs_vol),
                ROW_NUMBER() OVER(
                    PARTITION BY ll.ld_leg_id
                    ORDER BY
                        SUM(sh.bs_vol) DESC
                ) AS row_nbr
            FROM
                najdaadm.load_leg_r          ll
                JOIN najdaadm.load_leg_detail_r   lld ON ll.ld_leg_id = lld.ld_leg_id
                JOIN najdaadm.shipment_r          sh ON lld.shpm_id = sh.shpm_id
            GROUP BY
                ll.ld_leg_id,
                sh.rfrc_num10
        )
    WHERE
        row_nbr = 1
),

/********************************************************************************************************************

/* GET THE FREIGHT TYPE FOR EACH LOAD.  MATERIAL TYPES OF N100 OR NULL ARE CONSIDERED FINISHED GOODS.

/********************************************************************************************************************/ freight_type AS (
    SELECT
        ld_leg_id,
        CASE
            WHEN rfrc_num = ''N100'' THEN
                ''FG''
            WHEN rfrc_num IS NULL THEN
                ''FG''
            ELSE
                ''NFG''
        END AS "FREIGHT_TYPE"
    FROM
        (
            SELECT
                ll.ld_leg_id,
                rn.rfrc_num,
                ROW_NUMBER() OVER(
                    PARTITION BY ll.ld_leg_id
                    ORDER BY
                        rn.rfrc_num ASC
                ) AS row_nbr
            FROM
                najdaadm.load_leg_r           ll
                JOIN najdaadm.load_leg_detail_r    lld ON ll.ld_leg_id = lld.ld_leg_id
                JOIN najdaadm.shipment_r           sh ON lld.shpm_id = sh.shpm_id
                JOIN najdaadm.shipment_item_r      si ON sh.shpm_id = si.shpm_id
                LEFT OUTER JOIN najdaadm.reference_number_r   rn ON si.shpm_itm_id = rn.shpm_itm_id
                                                                  AND rn.rfrc_num_qlfr_id = 1215
        )
    WHERE
        row_nbr = 1
),

/********************************************************************************************************************

/* FIRST TENDER RESPONSE

/********************************************************************************************************************/ first_tender AS (
    SELECT
        ld_leg_id,
        carr_cd,
        srvc_cd,
        fta_cnt,
        crtd_dtt AS "TDR_DTT",
        round((strd_dtt - crtd_dtt) * 24, 1) AS "TDR_LEAD_HRS"
    FROM
        (
            SELECT
                trt.*,
                CASE
                    WHEN rsps_sec_cd = ''ACPD'' THEN
                        1
                    ELSE
                        0
                END AS "FTA_CNT",
                ROW_NUMBER() OVER(
                    PARTITION BY trt.ld_leg_id
                    ORDER BY
                        trt.tdr_req_id
                ) AS row_nbr
            FROM
                najdaadm.tdr_req_t trt
				WHERE CARR_CD <> ''FRAN'' 
        )
    WHERE
        row_nbr = 1
),

/********************************************************************************************************************

/* LOAD ON-TIME DELIVERY SERVICE PERFORMANCE - THIS IS AGGREGATED.  A MULT-STOP DELIVERY WILL BE REFLECTED AS 1 LOAD

/********************************************************************************************************************/ load_otd_service AS (
    SELECT
        load_id,
        team_name,
        team_group,
        MAX(base_appointment_datetime) AS "LAST_STOP_BASE_APPT_DATETIME",
        MAX(final_appointment_datetime) AS "LAST_STOP_FINAL_APPT_DATETIME",
        MAX(arrived_at_datetime) AS "LAST_STOP_ACTUAL_ARRIVAL",
        MIN(caps_reason) AS "CAPS_REASON_CD",
        MIN(csrs_reason) AS "CSRS_REASON_CD",
        COUNT(load_id) AS stop_cnt,
        SUM(
            CASE
                WHEN arrived_at_datetime IS NOT NULL
                     AND caps_reason <> ''MEFC'' THEN
                    1
                ELSE
                    0
            END
        ) AS "STOP_RESPONSE_CNT",

  /* STOPS SCORED CAPS ON-TIME BUT DELIVERED A CALENDAR DAY EARLY REPORTED AS EARLY */
        SUM(
            CASE
                WHEN arrived_at_datetime IS NOT NULL
                     AND caps_late = ''N''
                     AND trunc(arrived_at_datetime) < trunc(final_appointment_datetime) THEN
                    1
                ELSE
                    0
            END
        ) AS "CAPS_EARLY_STOP_CNT",
        SUM(
            CASE
                WHEN arrived_at_datetime IS NOT NULL
                     AND caps_late = ''N''
                     AND trunc(arrived_at_datetime) >= trunc(final_appointment_datetime) THEN
                    1
                ELSE
                    0
            END
        ) AS "CAPS_ONTIME_STOP_CNT",
        SUM(
            CASE
                WHEN arrived_at_datetime IS NOT NULL
                     AND caps_late = ''Y'' THEN
                    1
                ELSE
                    0
            END
        ) AS "CAPS_LATE_STOP_CNT",
        SUM(
            CASE
                WHEN arrived_at_datetime IS NOT NULL THEN
                    1
                ELSE
                    0
            END
        ) AS "CAPS_DELIVERED_STOP_CNT",

  /* STOPS SCORED CAPS ON-TIME BUT DELIVERED A CALENDAR DAY EARLY REPORTED AS EARLY */
        SUM(
            CASE
                WHEN arrived_at_datetime IS NOT NULL
                     AND trunc(arrived_at_datetime) < trunc(base_appointment_datetime) THEN
                    1
                ELSE
                    0
            END
        ) AS "CSRS_EARLY_STOP_CNT",
        SUM(
            CASE
                WHEN arrived_at_datetime IS NOT NULL
                     AND csrs_late = ''N''
                     AND trunc(arrived_at_datetime) >= trunc(base_appointment_datetime) THEN
                    1
                ELSE
                    0
            END
        ) AS "CSRS_ONTIME_STOP_CNT",
        SUM(
            CASE
                WHEN arrived_at_datetime IS NOT NULL
                     AND csrs_late = ''Y''
                     AND trunc(arrived_at_datetime) >= trunc(base_appointment_datetime) THEN
                    1
                ELSE
                    0
            END
        ) AS "CSRS_LATE_STOP_CNT",
        SUM(
            CASE
                WHEN arrived_at_datetime IS NOT NULL THEN
                    1
                ELSE
                    0
            END
        ) AS "CSRS_DELIVERED_STOP_CNT"
    FROM
        najdatrn.abpp_otc_caps_master
    WHERE
        stop_num > 1
    GROUP BY
        load_id,
        team_name,
        team_group
),

/********************************************************************************************************************

/* GET PICK LOCATION AND ACTUAL PICK TIME FROM CAPS WHEN IT EXISTS

/********************************************************************************************************************/ caps_pick_stops AS (
    SELECT
        load_id,
        location_num                AS "PICK_LOCATION_ID",
        base_appointment_datetime   AS "PICK_APPOINTMENT_DATETIME",
        departed_datetime           AS "CARR_DEPARTED_PICK_DATETIME",
		arrived_at_datetime			AS "CARR_ARRIVED_AT_DATETIME",
        team_name,
        team_group
    FROM
        najdatrn.abpp_otc_caps_master
    WHERE
        stop_num = 1
),

/********************************************************************************************************************

/* GET BASE AND FINAL APPOINTMENTS FROM THE FIRST DROP STOP

/********************************************************************************************************************/ caps_first_drop_stops AS (
    SELECT
        load_id,
        base_appointment_datetime   AS "DROP_APPOINTMENT_DATETIME",
        arrived_at_datetime         AS "CARR_ARRIVE_FRST_DROP_DATE"
    FROM
        najdatrn.abpp_otc_caps_master
    WHERE
        stop_num = 2
),

/********************************************************************************************************************

/* GET THE DISTANCE TO FIRST DROP STOP PLUS CURRENT APPOINTMENT

/********************************************************************************************************************/ dist_to_first_drop AS (
    SELECT
        sr.ld_leg_id,
        sr.frmprevstop_dist,
        ar.apt_frm_dtt   AS "CURRENT_FRMAPT_DATETIME",
        ar.apt_to_dtt    AS "CURRENT_TOAPT_DATETIME",
        ad.cty_name,
        ad.sta_cd
    FROM
        najdaadm.stop_r          sr
        JOIN najdaadm.address_r       ad ON ad.addr_id = sr.addr_id
        LEFT OUTER JOIN najdaadm.appointment_r   ar ON sr.apt_id = ar.apt_id
    WHERE
        seq_num = 2
)

/********************************************************************************************************************

/* METRICS QUERY

/********************************************************************************************************************/
SELECT
    llr.ld_leg_id,
    so.sales_org,
    ft.freight_type,
    CASE
        WHEN so.sales_org IN (
            ''2810'',
            ''2820'',
            ''Z01''
        ) THEN
            ''KCNA''
        WHEN so.sales_org IN (
            ''2811'',
            ''2821'',
            ''Z02'',
            ''Z04'',
            ''Z06'',
            ''Z07''
        ) THEN
            ''KCP''
        WHEN so.sales_org = ''Z05'' THEN
            car.corp1_id
        WHEN so.sales_org IS NULL
             AND substr(lar.corp1_id, 1, 2) = ''RF'' THEN
            ''KCP''
        WHEN so.sales_org IS NULL
             AND substr(lar.corp1_id, 1, 2) <> ''RF'' THEN
            car.corp1_id
        WHEN so.sales_org IS NULL
             AND lar.corp1_id IS NULL THEN
            car.corp1_id
    END AS "BUSINESS_UNIT",
    stat.stat_shrt_desc            AS "LOAD_STATUS",
    llr.carr_cd,
    llr.srvc_cd,
    llr.eqmt_typ,
    CASE
        WHEN substr(llr.frst_shpg_loc_cd, 5, 1) = ''-''
             AND substr(llr.last_shpg_loc_cd, 5, 1) = ''-'' THEN
            ''STO''
        WHEN substr(llr.frst_shpg_loc_cd, 5, 1) = ''-''
             AND substr(llr.last_shpg_loc_cd, 1, 1) = ''5'' THEN
            ''CUSTOMER''
        WHEN substr(llr.frst_shpg_loc_cd, 5, 1) = ''-''
             AND llr.last_shpg_loc_cd = ''99999999'' THEN
            ''CUSTOMER''
        WHEN substr(llr.frst_shpg_loc_cd, 1, 1) = ''V''
             AND substr(lar.corp1_id, 1, 2) = ''RM'' THEN
            ''MATERIALS''
        WHEN substr(llr.frst_shpg_loc_cd, 1, 1) = ''V''
             AND substr(lar.corp1_id, 1, 2) = ''RF'' THEN
            ''RECFIBER''
        ELSE
            ''UNKNOWN''
    END AS "SHIP_TYPE",
    CASE
        WHEN lar.corp2_id IS NULL THEN
            lar.name
        ELSE
            lar.corp2_id
    END AS ship_from_name,
    llr.frst_cty_name
    || '', ''
    || llr.frst_sta_cd
    || '' to ''
    ||
        CASE
            WHEN llr.last_ctry_cd = ''USA'' THEN
                substr(llr.last_pstl_cd, 1, 5)
            ELSE
                llr.last_cty_name
                || '', ''
                || llr.last_sta_cd
        END
    AS "LANE_DESC",
    llr.frst_shpg_loc_cd,
    llr.frst_cty_name,
    llr.frst_sta_cd,
    CASE
        WHEN llr.frst_ctry_cd = ''USA'' THEN
            substr(llr.frst_pstl_cd, 1, 5)
        WHEN llr.frst_ctry_cd = ''CAN'' THEN
            substr(llr.frst_pstl_cd, 1, 6)
        ELSE
            llr.frst_pstl_cd
    END AS frst_zip_cd,
    llr.frst_ctry_cd,
    llr.last_shpg_loc_cd,
    CASE
        WHEN customer_groupings.customer IS NOT NULL THEN
            customer_groupings.customer
        ELSE
            CASE
                WHEN substr(llr.last_shpg_loc_cd, 5, 1) = ''-''          THEN
                    ''K-C''
                WHEN substr(llr.last_shpg_loc_cd, 1, 2) = ''58''         THEN
                    ''OTHER CUSTOMER''
                WHEN substr(llr.last_shpg_loc_cd, 5, 1) = ''99999999''   THEN
                    ''OTHER CUSTOMER''
                WHEN substr(llr.last_shpg_loc_cd, 1, 2) = ''AK''         THEN
                    ''HUB''
                WHEN substr(llr.last_shpg_loc_cd, 1, 2) = ''HI''         THEN
                    ''HUB''
                WHEN substr(llr.last_shpg_loc_cd, 1, 4) = ''LCL-''       THEN
                    ''HUB''
                ELSE
                    ''UNKNOWN''
            END
    END AS "SELL_TO_CUST",
    llr.last_cty_name              AS "FINAL_CITY_NAME",
    llr.last_sta_cd                AS "FINAL_STA_CD",
    llr.last_ctry_cd               AS "FINAL_CTRY_CD",
    CASE
        WHEN llr.last_ctry_cd = ''USA'' THEN
            substr(llr.last_pstl_cd, 1, 5)
        WHEN llr.last_ctry_cd = ''CAN'' THEN
            substr(llr.last_pstl_cd, 1, 6)
        ELSE
            llr.last_pstl_cd
    END AS final_zip_cd,
    dtfd.frmprevstop_dist          AS "DISTANCE_TO_FRST_STOP",
    cps.team_name,
    cps.team_group,
    llr.chgd_amt_dlr,
    trunc(ft.tdr_dtt) AS "FRST_TENDER_DATE",
    cps.pick_appointment_datetime,
    cps.carr_departed_pick_datetime,
    CASE
        WHEN llr.shpd_dtt IS NULL THEN
            /*trunc(cps.pick_appointment_datetime)*/
			null
        ELSE
            llr.shpd_dtt
    END AS ship_date,
    CASE
        WHEN llr.shpd_dtt IS NULL THEN
            /*TO_CHAR(cps.pick_appointment_datetime - 1, ''D'')
            || ''-''
            || TO_CHAR(cps.pick_appointment_datetime, ''DY'')*/
			null
        ELSE
            TO_CHAR(llr.shpd_dtt - 1, ''D'')
            || ''-''
            || TO_CHAR(llr.shpd_dtt, ''DY'')
    END AS ship_dow,
    CASE
        WHEN llr.shpd_dtt IS NULL THEN
            /*trunc(cps.pick_appointment_datetime, ''IW'')*/
			null
        ELSE
            trunc(llr.shpd_dtt, ''IW'')
    END AS ship_week,
    CASE
        WHEN llr.shpd_dtt IS NULL THEN
            /*trunc(cps.pick_appointment_datetime, ''MM'')*/
			null
        ELSE
            trunc(llr.shpd_dtt, ''MM'')
    END AS ship_month,
    los.last_stop_base_appt_datetime,
    los.last_stop_final_appt_datetime,
    TO_CHAR(los.last_stop_final_appt_datetime - 1, ''D'')
    || ''-''
    || TO_CHAR(los.last_stop_final_appt_datetime, ''DY'') AS final_appt_dow,
    trunc(los.last_stop_final_appt_datetime, ''IW'') AS final_appt_week,
    trunc(los.last_stop_final_appt_datetime, ''MM'') AS final_appt_month,
    los.last_stop_actual_arrival   AS "ACTUAL_DELIVERY_DATE",
    TO_CHAR(los.last_stop_actual_arrival - 1, ''D'')
    || ''-''
    || TO_CHAR(los.last_stop_actual_arrival, ''DY'') AS actual_delivery_dow,
    trunc(los.last_stop_actual_arrival, ''IW'') AS actual_delivery_week,
    trunc(los.last_stop_actual_arrival, ''MM'') AS actual_delivery_month,
    llr.mile_dist                  AS "TOTAL_MILES",
    1 AS "LOAD_COUNT",
    los.stop_cnt                   AS "STOP_COUNT",
    los.stop_response_cnt          AS "STOP_RESPONSE_COUNT",
    ft.fta_cnt,
    ft.tdr_lead_hrs,
    los.caps_early_stop_cnt,
    los.caps_ontime_stop_cnt,
    los.caps_late_stop_cnt,
    los.caps_delivered_stop_cnt,
    CASE
        WHEN rsd1.reason_desc IS NULL THEN
            los.caps_reason_cd
        ELSE
            rsd1.reason_desc
    END AS "CAPS_REASON_DESC",
    los.csrs_early_stop_cnt,
    los.csrs_ontime_stop_cnt,
    los.csrs_late_stop_cnt,
    los.csrs_delivered_stop_cnt,
    CASE
        WHEN rsd2.reason_desc IS NULL THEN
            los.csrs_reason_cd
        ELSE
            rsd2.reason_desc
    END AS "CSRS_REASON_DESC",
    trunc(SYSDATE, ''MI'') AS "LAST_REFRESHED_TIME",
    CASE
        WHEN MAX(
            CASE
                WHEN latr.origin_id IS NULL THEN
                    0
                ELSE
                    1
            END
        ) = 0 THEN
            ''Not Award Lane''
        ELSE
            ''Award Lane''
    END AS award_lane_status,
    MAX(
        CASE
            WHEN latr.origin_id IS NULL THEN
                0
            ELSE
                1
        END
    ) AS award_lane_cnt,
    CASE
        WHEN MAX(
            CASE
                WHEN lasa.tariff_service IS NULL THEN
                    0
                ELSE
                    1
            END
        ) = 0 THEN
            ''Not Award Carrier''
        ELSE
            ''Award Carrier''
    END AS award_service_status,
    MAX(
        CASE
            WHEN lasa.tariff_service IS NULL THEN
                0
            ELSE
                1
        END
    ) AS award_service_cnt,
	cps.CARR_ARRIVED_AT_DATETIME,
	lar.corp1_id,
	CASE WHEN LLR.RFRC_NUM16 IS NOT NULL THEN 1 ELSE 0 END AS TM_AUCT_CNT,
	llr.crtd_dtt AS CREATE_DTT,
	llr.strd_dtt AS START_DTT
FROM
    najdaadm.load_leg_r               llr
    JOIN najdaadm.load_at_r                lar ON llr.frst_shpg_loc_cd = lar.shpg_loc_cd
    LEFT OUTER JOIN najdaadm.consignee_r              car ON llr.last_shpg_loc_cd = car.shpg_loc_cd
    JOIN najdaadm.status_r                 stat ON llr.cur_optlstat_id = stat.stat_id
    JOIN caps_pick_stops                   cps ON cps.load_id = llr.ld_leg_id
    JOIN caps_first_drop_stops             cds ON cds.load_id = llr.ld_leg_id
    JOIN load_otd_service                  los ON los.load_id = llr.ld_leg_id
    JOIN first_tender                      ft ON ft.ld_leg_id = llr.ld_leg_id
    JOIN dist_to_first_drop                dtfd ON dtfd.ld_leg_id = llr.ld_leg_id
    JOIN sales_org                         so ON so.ld_leg_id = llr.ld_leg_id
    JOIN freight_type                      ft ON ft.ld_leg_id = llr.ld_leg_id
    LEFT OUTER JOIN customer_groupings ON customer_groupings.hierarchy = substr(llr.last_shpg_loc_cd, 1, 8)
    LEFT OUTER JOIN reason_code_desc                  rsd1 ON los.caps_reason_cd = rsd1.reason_code
    LEFT OUTER JOIN reason_code_desc                  rsd2 ON los.csrs_reason_cd = rsd2.reason_code
    LEFT OUTER JOIN najdatrn.abpp_laneserviceawards   lasa ON lasa.origin_id = llr.frst_shpg_loc_cd
                                                            AND lasa.destination_id = llr.last_shpg_loc_cd
                                                            AND lasa.tariff_service = llr.srvc_cd
                                                            AND llr.strd_dtt BETWEEN lasa.from_date AND lasa.TO_DATE
    LEFT OUTER JOIN najdatrn.abpp_laneawards_tl_r     latr ON latr.origin_id = llr.frst_shpg_loc_cd
                                                          AND latr.destination_id = llr.last_shpg_loc_cd
                                                          AND llr.strd_dtt BETWEEN latr.from_date AND latr.TO_DATE
WHERE
    llr.cur_optlstat_id BETWEEN 300 AND 350
    AND llr.eqmt_typ IN (
        ''48FT'',
        ''53FT'',
        ''53IM'',
        ''53RT'',
        ''53TC'',
        ''53HC''
    )
GROUP BY
    llr.ld_leg_id,
    so.sales_org,
    ft.freight_type,
    CASE
            WHEN so.sales_org IN (
                ''2810'',
                ''2820'',
                ''Z01''
            ) THEN
                ''KCNA''
            WHEN so.sales_org IN (
                ''2811'',
                ''2821'',
                ''Z02'',
                ''Z04'',
                ''Z06'',
                ''Z07''
            ) THEN
                ''KCP''
            WHEN so.sales_org = ''Z05'' THEN
                car.corp1_id
            WHEN so.sales_org IS NULL
                 AND substr(lar.corp1_id, 1, 2) = ''RF'' THEN
                ''KCP''
            WHEN so.sales_org IS NULL
                 AND substr(lar.corp1_id, 1, 2) <> ''RF'' THEN
                car.corp1_id
            WHEN so.sales_org IS NULL
                 AND lar.corp1_id IS NULL THEN
                car.corp1_id
        END,
    stat.stat_shrt_desc,
    llr.carr_cd,
    llr.srvc_cd,
    llr.eqmt_typ,
    CASE
            WHEN substr(llr.frst_shpg_loc_cd, 5, 1) = ''-''
                 AND substr(llr.last_shpg_loc_cd, 5, 1) = ''-'' THEN
                ''STO''
            WHEN substr(llr.frst_shpg_loc_cd, 5, 1) = ''-''
                 AND substr(llr.last_shpg_loc_cd, 1, 1) = ''5'' THEN
                ''CUSTOMER''
            WHEN substr(llr.frst_shpg_loc_cd, 5, 1) = ''-''
                 AND llr.last_shpg_loc_cd = ''99999999'' THEN
                ''CUSTOMER''
            WHEN substr(llr.frst_shpg_loc_cd, 1, 1) = ''V''
                 AND substr(lar.corp1_id, 1, 2) = ''RM'' THEN
                ''MATERIALS''
            WHEN substr(llr.frst_shpg_loc_cd, 1, 1) = ''V''
                 AND substr(lar.corp1_id, 1, 2) = ''RF'' THEN
                ''RECFIBER''
            ELSE
                ''UNKNOWN''
        END,
    CASE
            WHEN lar.corp2_id IS NULL THEN
                lar.name
            ELSE
                lar.corp2_id
        END,
    llr.frst_cty_name
    || '', ''
    || llr.frst_sta_cd
    || '' to ''
    ||
        CASE
            WHEN llr.last_ctry_cd = ''USA'' THEN
                substr(llr.last_pstl_cd, 1, 5)
            ELSE
                llr.last_cty_name
                || '', ''
                || llr.last_sta_cd
        END,
    llr.frst_shpg_loc_cd,
    llr.frst_cty_name,
    llr.frst_sta_cd,
    CASE
            WHEN llr.frst_ctry_cd = ''USA'' THEN
                substr(llr.frst_pstl_cd, 1, 5)
            WHEN llr.frst_ctry_cd = ''CAN'' THEN
                substr(llr.frst_pstl_cd, 1, 6)
            ELSE
                llr.frst_pstl_cd
        END,
    llr.frst_ctry_cd,
    llr.last_shpg_loc_cd,
    CASE
            WHEN customer_groupings.customer IS NOT NULL THEN
                customer_groupings.customer
            ELSE
                CASE
                    WHEN substr(llr.last_shpg_loc_cd, 5, 1) = ''-''          THEN
                        ''K-C''
                    WHEN substr(llr.last_shpg_loc_cd, 1, 2) = ''58''         THEN
                        ''OTHER CUSTOMER''
                    WHEN substr(llr.last_shpg_loc_cd, 5, 1) = ''99999999''   THEN
                        ''OTHER CUSTOMER''
                    WHEN substr(llr.last_shpg_loc_cd, 1, 2) = ''AK''         THEN
                        ''HUB''
                    WHEN substr(llr.last_shpg_loc_cd, 1, 2) = ''HI''         THEN
                        ''HUB''
                    WHEN substr(llr.last_shpg_loc_cd, 1, 4) = ''LCL-''       THEN
                        ''HUB''
                    ELSE
                        ''UNKNOWN''
                END
        END,
    llr.last_cty_name,
    llr.last_sta_cd,
    llr.last_ctry_cd,
    CASE
            WHEN llr.last_ctry_cd = ''USA'' THEN
                substr(llr.last_pstl_cd, 1, 5)
            WHEN llr.last_ctry_cd = ''CAN'' THEN
                substr(llr.last_pstl_cd, 1, 6)
            ELSE
                llr.last_pstl_cd
        END,
    dtfd.frmprevstop_dist,
    cps.team_name,
    cps.team_group,
    llr.chgd_amt_dlr,
    trunc(ft.tdr_dtt),
    cps.pick_appointment_datetime,
    cps.carr_departed_pick_datetime,
    CASE
        WHEN llr.shpd_dtt IS NULL THEN
            /*trunc(cps.pick_appointment_datetime)*/
			null
        ELSE
            llr.shpd_dtt
    END,
    CASE
        WHEN llr.shpd_dtt IS NULL THEN
            /*TO_CHAR(cps.pick_appointment_datetime - 1, ''D'')
            || ''-''
            || TO_CHAR(cps.pick_appointment_datetime, ''DY'')*/
			null
        ELSE
            TO_CHAR(llr.shpd_dtt - 1, ''D'')
            || ''-''
            || TO_CHAR(llr.shpd_dtt, ''DY'')
    END,
    CASE
        WHEN llr.shpd_dtt IS NULL THEN
            /*trunc(cps.pick_appointment_datetime, ''IW'')*/
			null
        ELSE
            trunc(llr.shpd_dtt, ''IW'')
    END,
    CASE
        WHEN llr.shpd_dtt IS NULL THEN
            /*trunc(cps.pick_appointment_datetime, ''MM'')*/
			null
        ELSE
            trunc(llr.shpd_dtt, ''MM'')
    END,
    los.last_stop_base_appt_datetime,
    los.last_stop_final_appt_datetime,
    TO_CHAR(los.last_stop_final_appt_datetime - 1, ''D'')
    || ''-''
    || TO_CHAR(los.last_stop_final_appt_datetime, ''DY''),
    trunc(los.last_stop_final_appt_datetime, ''IW''),
    trunc(los.last_stop_final_appt_datetime, ''MM''),
    los.last_stop_actual_arrival,
    TO_CHAR(los.last_stop_actual_arrival - 1, ''D'')
    || ''-''
    || TO_CHAR(los.last_stop_actual_arrival, ''DY''),
    trunc(los.last_stop_actual_arrival, ''IW''),
    trunc(los.last_stop_actual_arrival, ''MM''),
    llr.mile_dist,
    1,
    los.stop_cnt,
    los.stop_response_cnt,
    ft.fta_cnt,
    ft.tdr_lead_hrs,
    los.caps_early_stop_cnt,
    los.caps_ontime_stop_cnt,
    los.caps_late_stop_cnt,
    los.caps_delivered_stop_cnt,
    CASE
            WHEN rsd1.reason_desc IS NULL THEN
                los.caps_reason_cd
            ELSE
                rsd1.reason_desc
        END,
    los.csrs_early_stop_cnt,
    los.csrs_ontime_stop_cnt,
    los.csrs_late_stop_cnt,
    los.csrs_delivered_stop_cnt,
    CASE
            WHEN rsd2.reason_desc IS NULL THEN
                los.csrs_reason_cd
            ELSE
                rsd2.reason_desc
        END,
    trunc(SYSDATE, ''MI''),
	cps.CARR_ARRIVED_AT_DATETIME,
	lar.corp1_id,
	CASE WHEN LLR.RFRC_NUM16 IS NOT NULL THEN 1 ELSE 0 END,
	llr.crtd_dtt,
	llr.strd_dtt
    ) 
'

    /*
Create Temp table
*/
    CREATE TABLE ##tblOperationalMetricsTemp
    (
        LD_LEG_ID                     NVARCHAR(20),
        SALES_ORG                     NVARCHAR(10),
        FREIGHT_TYPE                  NVARCHAR(5),
        BUSINESS_UNIT                 NVARCHAR(10),
        LOAD_STATUS                   NVARCHAR(20),
        CARR_CD                       NVARCHAR(5),
        SRVC_CD                       NVARCHAR(5),
        EQMT_TYP                      NVARCHAR(5),
        SHIP_TYPE                     NVARCHAR(10),
        SHIP_FROM_NAME                NVARCHAR(75),
        LANE_DESC                     NVARCHAR(75),
        FRST_SHPG_LOC_CD              NVARCHAR(20),
        FRST_CTY_NAME                 NVARCHAR(50),
        FRST_STA_CD                   NVARCHAR(2),
        FRST_ZIP_CD                   NVARCHAR(10),
        FRST_CTRY_CD                  NVARCHAR(3),
        LAST_SHPG_LOC_CD              NVARCHAR(20),
        SELL_TO_CUST                  NVARCHAR(40),
        FINAL_CITY_NAME               NVARCHAR(50),
        FINAL_STA_CD                  NVARCHAR(2),
        FINAL_CTRY_CD                 NVARCHAR(3),
        FINAL_ZIP_CD                  NVARCHAR(10),
        DISTANCE_TO_FRST_STOP         NUMERIC(18, 2),
        TEAM_NAME                     NVARCHAR(20),
        TEAM_GROUP                    NVARCHAR(5),
        CHGD_AMT_DLR                  NUMERIC(18, 2),
        FRST_TENDER_DATE              DATETIME,
        PICK_APPOINTMENT_DATETIME     DATETIME,
        CARR_DEPARTED_PICK_DATETIME   DATETIME,
        SHIP_DATE                     DATETIME,
        SHIP_DOW                      NVARCHAR(5),
        SHIP_WEEK                     DATETIME,
        SHIP_MONTH                    DATETIME,
        LAST_STOP_BASE_APPT_DATETIME  DATETIME,
        LAST_STOP_FINAL_APPT_DATETIME DATETIME,
        FINAL_APPT_DOW                NVARCHAR(5),
        FINAL_APPT_WEEK               DATETIME,
        FINAL_APPT_MONTH              DATETIME,
        ACTUAL_DELIVERY_DATE          DATETIME,
        ACTUAL_DELIVERY_DOW           NVARCHAR(10),
        ACTUAL_DELIVERY_WEEK          DATETIME,
        ACTUAL_DELIVERY_MONTH         DATETIME,
        TOTAL_MILES                   NUMERIC(18, 2),
        LOAD_COUNT                    INT,
        STOP_COUNT                    INT,
        STOP_RESPONSE_COUNT           INT,
        FTA_CNT                       INT,
        TDR_LEAD_HRS                  DECIMAL(18, 2),
        CAPS_EARLY_STOP_CNT           INT,
        CAPS_ONTIME_STOP_CNT          INT,
        CAPS_LATE_STOP_CNT            INT,
        CAPS_DELIVERED_STOP_CNT       INT,
        CAPS_REASON_DESC              NVARCHAR(50),
        CSRS_EARLY_STOP_CNT           INT,
        CSRS_ONTIME_STOP_CNT          INT,
        CSRS_LATE_STOP_CNT            INT,
        CSRS_DELIVERED_STOP_CNT       INT,
        CSRS_REASON_DESC              NVARCHAR(50),
        LAST_REFRESHED_TIME           DATETIME,
        AWARD_LANE_STATUS             NVARCHAR(20),
        AWARD_LANE_CNT                INT,
        AWARD_SERVICE_STATUS          NVARCHAR(20),
        AWARD_SERVICE_CNT             INT,
        CARR_ARRIVED_AT_DATETIME      DATETIME,
        CORP1_ID                      NVARCHAR(20),
        TM_AUCT_CNT                   INT,
        CREATE_DTT                    DATETIME,
        START_DTT                     DATETIME
    )

    /*
  Append records from giant Oracle query into MSSQL temp table
  SELECT * FROM ##tblOperationalMetricsTemp
  */
    INSERT INTO ##tblOperationalMetricsTemp
    EXEC (@myQuery) AT NAJDAPRD

    /*
  Append new values from ##tblOperationalMetricsTemp to USCTTDEV.DBO.TBLOPERATIONALMETRICS, where the LD_LEG_ID value does not exist
  */
    INSERT INTO USCTTDEV.DBO.TBLOPERATIONALMETRICS
        (LD_LEG_ID,
        SALES_ORG,
        FREIGHT_TYPE,
        BUSINESS_UNIT,
        LOAD_STATUS,
        CARR_CD,
        SRVC_CD,
        EQMT_TYP,
        SHIP_TYPE,
        SHIP_FROM_NAME,
        LANE_DESC,
        FRST_SHPG_LOC_CD,
        FRST_CTY_NAME,
        FRST_STA_CD,
        FRST_ZIP_CD,
        FRST_CTRY_CD,
        LAST_SHPG_LOC_CD,
        SELL_TO_CUST,
        FINAL_CITY_NAME,
        FINAL_STA_CD,
        FINAL_CTRY_CD,
        FINAL_ZIP_CD,
        DISTANCE_TO_FRST_STOP,
        TEAM_NAME,
        TEAM_GROUP,
        CHGD_AMT_DLR,
        FRST_TENDER_DATE,
        PICK_APPOINTMENT_DATETIME,
        CARR_DEPARTED_PICK_DATETIME,
        SHIP_DATE,
        SHIP_DOW,
        SHIP_WEEK,
        SHIP_MONTH,
        LAST_STOP_BASE_APPT_DATETIME,
        LAST_STOP_FINAL_APPT_DATETIME,
        FINAL_APPT_DOW,
        FINAL_APPT_WEEK,
        FINAL_APPT_MONTH,
        ACTUAL_DELIVERY_DATE,
        ACTUAL_DELIVERY_DOW,
        ACTUAL_DELIVERY_WEEK,
        ACTUAL_DELIVERY_MONTH,
        TOTAL_MILES,
        LOAD_COUNT,
        STOP_COUNT,
        STOP_RESPONSE_COUNT,
        FTA_CNT,
        TDR_LEAD_HRS,
        CAPS_EARLY_STOP_CNT,
        CAPS_ONTIME_STOP_CNT,
        CAPS_LATE_STOP_CNT,
        CAPS_DELIVERED_STOP_CNT,
        CAPS_REASON_DESC,
        CSRS_EARLY_STOP_CNT,
        CSRS_ONTIME_STOP_CNT,
        CSRS_LATE_STOP_CNT,
        CSRS_DELIVERED_STOP_CNT,
        CSRS_REASON_DESC,
        LAST_REFRESHED_TIME,
        AWARD_LANE_STATUS,
        AWARD_LANE_CNT,
        AWARD_SERVICE_STATUS,
        AWARD_SERVICE_CNT,
        CARR_ARRIVED_AT_DATETIME,
        CORP1_ID,
        TM_AUCT_CNT,
        CREATE_DTT,
        START_DTT)
    SELECT
        OMT.LD_LEG_ID,
        OMT.SALES_ORG,
        OMT.FREIGHT_TYPE,
        OMT.BUSINESS_UNIT,
        OMT.LOAD_STATUS,
        OMT.CARR_CD,
        OMT.SRVC_CD,
        OMT.EQMT_TYP,
        OMT.SHIP_TYPE,
        OMT.SHIP_FROM_NAME,
        OMT.LANE_DESC,
        OMT.FRST_SHPG_LOC_CD,
        OMT.FRST_CTY_NAME,
        OMT.FRST_STA_CD,
        OMT.FRST_ZIP_CD,
        OMT.FRST_CTRY_CD,
        OMT.LAST_SHPG_LOC_CD,
        OMT.SELL_TO_CUST,
        OMT.FINAL_CITY_NAME,
        OMT.FINAL_STA_CD,
        OMT.FINAL_CTRY_CD,
        OMT.FINAL_ZIP_CD,
        OMT.DISTANCE_TO_FRST_STOP,
        OMT.TEAM_NAME,
        OMT.TEAM_GROUP,
        OMT.CHGD_AMT_DLR,
        OMT.FRST_TENDER_DATE,
        OMT.PICK_APPOINTMENT_DATETIME,
        OMT.CARR_DEPARTED_PICK_DATETIME,
        OMT.SHIP_DATE,
        OMT.SHIP_DOW,
        OMT.SHIP_WEEK,
        OMT.SHIP_MONTH,
        OMT.LAST_STOP_BASE_APPT_DATETIME,
        OMT.LAST_STOP_FINAL_APPT_DATETIME,
        OMT.FINAL_APPT_DOW,
        OMT.FINAL_APPT_WEEK,
        OMT.FINAL_APPT_MONTH,
        OMT.ACTUAL_DELIVERY_DATE,
        OMT.ACTUAL_DELIVERY_DOW,
        OMT.ACTUAL_DELIVERY_WEEK,
        OMT.ACTUAL_DELIVERY_MONTH,
        OMT.TOTAL_MILES,
        OMT.LOAD_COUNT,
        OMT.STOP_COUNT,
        OMT.STOP_RESPONSE_COUNT,
        OMT.FTA_CNT,
        OMT.TDR_LEAD_HRS,
        OMT.CAPS_EARLY_STOP_CNT,
        OMT.CAPS_ONTIME_STOP_CNT,
        OMT.CAPS_LATE_STOP_CNT,
        OMT.CAPS_DELIVERED_STOP_CNT,
        OMT.CAPS_REASON_DESC,
        OMT.CSRS_EARLY_STOP_CNT,
        OMT.CSRS_ONTIME_STOP_CNT,
        OMT.CSRS_LATE_STOP_CNT,
        OMT.CSRS_DELIVERED_STOP_CNT,
        OMT.CSRS_REASON_DESC,
        OMT.LAST_REFRESHED_TIME,
        OMT.AWARD_LANE_STATUS,
        OMT.AWARD_LANE_CNT,
        OMT.AWARD_SERVICE_STATUS,
        OMT.AWARD_SERVICE_CNT,
        OMT.CARR_ARRIVED_AT_DATETIME,
        OMT.CORP1_ID,
        OMT.TM_AUCT_CNT,
        OMT.CREATE_DTT,
        OMT.START_DTT
    FROM
        ##TBLOPERATIONALMETRICSTEMP AS OMT
        LEFT JOIN USCTTDEV.DBO.TBLOPERATIONALMETRICS OM
        ON OM.LD_LEG_ID = OMT.LD_LEG_ID
    WHERE  OM.LD_LEG_ID IS NULL

    /*
Declare and set variable for current date/time to use on AddedOn/LastUpdated
*/
    DECLARE @currentDateTime AS DATETIME
    SET @currentDateTime = GETDATE()

    /*
Update ALL fields on MSSQL Server table to match what's currently in Temp table
*/
    UPDATE OM
SET 
OM.AddedOn = CASE WHEN OM.AddedOn IS NULL THEN @currentDateTime ELSE OM.AddedOn END,
OM.LastUpdated = @currentDateTime,
OM.LD_LEG_ID = OMT.LD_LEG_ID,
OM.SALES_ORG = OMT.SALES_ORG,
OM.FREIGHT_TYPE = OMT.FREIGHT_TYPE,
OM.BUSINESS_UNIT = OMT.BUSINESS_UNIT,
OM.LOAD_STATUS = OMT.LOAD_STATUS,
OM.CARR_CD = OMT.CARR_CD,
OM.SRVC_CD = OMT.SRVC_CD,
OM.EQMT_TYP = OMT.EQMT_TYP,
OM.SHIP_TYPE = OMT.SHIP_TYPE,
OM.SHIP_FROM_NAME = OMT.SHIP_FROM_NAME,
OM.LANE_DESC = OMT.LANE_DESC,
OM.FRST_SHPG_LOC_CD = OMT.FRST_SHPG_LOC_CD,
OM.FRST_CTY_NAME = OMT.FRST_CTY_NAME,
OM.FRST_STA_CD = OMT.FRST_STA_CD,
OM.FRST_ZIP_CD = OMT.FRST_ZIP_CD,
OM.FRST_CTRY_CD = OMT.FRST_CTRY_CD,
OM.LAST_SHPG_LOC_CD = OMT.LAST_SHPG_LOC_CD,
OM.SELL_TO_CUST = OMT.SELL_TO_CUST,
OM.FINAL_CITY_NAME = OMT.FINAL_CITY_NAME,
OM.FINAL_STA_CD = OMT.FINAL_STA_CD,
OM.FINAL_CTRY_CD = OMT.FINAL_CTRY_CD,
OM.FINAL_ZIP_CD = OMT.FINAL_ZIP_CD,
OM.DISTANCE_TO_FRST_STOP = OMT.DISTANCE_TO_FRST_STOP,
OM.TEAM_NAME = OMT.TEAM_NAME,
OM.TEAM_GROUP = OMT.TEAM_GROUP,
OM.CHGD_AMT_DLR = OMT.CHGD_AMT_DLR,
OM.FRST_TENDER_DATE = OMT.FRST_TENDER_DATE,
OM.PICK_APPOINTMENT_DATETIME = OMT.PICK_APPOINTMENT_DATETIME,
OM.CARR_DEPARTED_PICK_DATETIME = OMT.CARR_DEPARTED_PICK_DATETIME,
OM.SHIP_DATE = OMT.SHIP_DATE,
OM.SHIP_DOW = OMT.SHIP_DOW,
OM.SHIP_WEEK = OMT.SHIP_WEEK,
OM.SHIP_MONTH = OMT.SHIP_MONTH,
OM.LAST_STOP_BASE_APPT_DATETIME = OMT.LAST_STOP_BASE_APPT_DATETIME,
OM.LAST_STOP_FINAL_APPT_DATETIME = OMT.LAST_STOP_FINAL_APPT_DATETIME,
OM.FINAL_APPT_DOW = OMT.FINAL_APPT_DOW,
OM.FINAL_APPT_WEEK = OMT.FINAL_APPT_WEEK,
OM.FINAL_APPT_MONTH = OMT.FINAL_APPT_MONTH,
OM.ACTUAL_DELIVERY_DATE = OMT.ACTUAL_DELIVERY_DATE,
OM.ACTUAL_DELIVERY_DOW = OMT.ACTUAL_DELIVERY_DOW,
OM.ACTUAL_DELIVERY_WEEK = OMT.ACTUAL_DELIVERY_WEEK,
OM.ACTUAL_DELIVERY_MONTH = OMT.ACTUAL_DELIVERY_MONTH,
OM.TOTAL_MILES = OMT.TOTAL_MILES,
OM.LOAD_COUNT = OMT.LOAD_COUNT,
OM.STOP_COUNT = OMT.STOP_COUNT,
OM.STOP_RESPONSE_COUNT = OMT.STOP_RESPONSE_COUNT,
OM.FTA_CNT = OMT.FTA_CNT,
OM.TDR_LEAD_HRS = OMT.TDR_LEAD_HRS,
OM.CAPS_EARLY_STOP_CNT = OMT.CAPS_EARLY_STOP_CNT,
OM.CAPS_ONTIME_STOP_CNT = OMT.CAPS_ONTIME_STOP_CNT,
OM.CAPS_LATE_STOP_CNT = OMT.CAPS_LATE_STOP_CNT,
OM.CAPS_DELIVERED_STOP_CNT = OMT.CAPS_DELIVERED_STOP_CNT,
OM.CAPS_REASON_DESC = OMT.CAPS_REASON_DESC,
OM.CSRS_EARLY_STOP_CNT = OMT.CSRS_EARLY_STOP_CNT,
OM.CSRS_ONTIME_STOP_CNT = OMT.CSRS_ONTIME_STOP_CNT,
OM.CSRS_LATE_STOP_CNT = OMT.CSRS_LATE_STOP_CNT,
OM.CSRS_DELIVERED_STOP_CNT = OMT.CSRS_DELIVERED_STOP_CNT,
OM.CSRS_REASON_DESC = OMT.CSRS_REASON_DESC,
OM.LAST_REFRESHED_TIME = OMT.LAST_REFRESHED_TIME,
OM.AWARD_LANE_STATUS = OMT.AWARD_LANE_STATUS,
OM.AWARD_LANE_CNT = OMT.AWARD_LANE_CNT,
OM.AWARD_SERVICE_STATUS = OMT.AWARD_SERVICE_STATUS,
OM.AWARD_SERVICE_CNT = OMT.AWARD_SERVICE_CNT,
OM.CARR_ARRIVED_AT_DATETIME = OMT.CARR_ARRIVED_AT_DATETIME,
OM.CORP1_ID = OMT.CORP1_ID,
OM.TM_AUCT_CNT = OMT.TM_AUCT_CNT,
OM.CREATE_DTT = OMT.CREATE_DTT,
OM.START_DTT = OMT.START_DTT
FROM
        USCTTDEV.DBO.TBLOPERATIONALMETRICS AS OM
        INNER JOIN ##TBLOPERATIONALMETRICSTEMP AS OMT
        ON OM.LD_LEG_ID = OMT.LD_LEG_ID

    /*
Redundant, but I do it anyway! : D 
Delete Temp table, if exists
*/
    DROP TABLE IF EXISTS
##tblOperationalMetricsTemp

    /*
Update USCTTDEV.dbo.tblOperationalMetrics if no longer appears on Oracle query, to whatever status matches from USCTTDEV.dbo.tblRFTDetailDataHistoricalNew
*/
    UPDATE USCTTDEV.dbo.tblOperationalMetrics
SET LOAD_STATUS = rft.CurrentStatusDesc, LastUpdated = rft.LastUpdated
FROM
        USCTTDEV.dbo.tblOperationalMetrics om
        LEFT JOIN USCTTDEV.dbo.tblRFTDetailDataHistoricalNew rft ON rft.load_number = om.ld_leg_id
WHERE LOAD_STATUS <> rft.CurrentStatusDesc
        AND rft.FirstFailure IS NOT NULL
        AND LOAD_STATUS <> 'Completed'
        AND om.LastUpdated < rft.LastUpdated-1

    /*
Update Actual Load Details with new city names, when there's something weird
*/
    UPDATE USCTTDEV.dbo.tblActualLoadDetail
SET DestCity =
              CASE
                WHEN zc.ZONE IS NOT NULL AND
        zc.CityName IS NOT NULL THEN zc.UpdatedCityName
                ELSE ald.LAST_CTY_NAME
              END
FROM
        USCTTDEV.dbo.tblActualLoadDetail ald
        LEFT JOIN USCTTDEV.dbo.tblZoneCities zc
        ON zc.Zone = ald.Dest_Zone
            AND zc.CityName = ald.LAST_CTY_NAME

    /*
Update Operational Metrics if CORP1_ID = 'RF' and SHIP_TYPE = 'RECFIBER', 
but CORP1_ID is still null for some reason
*/
    UPDATE USCTTDEV.dbo.tblOperationalMetrics
SET CORP1_ID = 'RF'
WHERE SHIP_TYPE = 'RECFIBER'
        AND CORP1_ID IS NULL

    /*
Determine order type for each Load
SELECT * FROM USCTTDEV.dbo.tblOperationalMetrics WHERE ORDERTYPE IS NULL AND LOAD_STATUS <> 'CANCELED'
*/
    UPDATE USCTTDEV.dbo.tblOperationalMetrics
SET OrderType = 
CASE WHEN CORP1_ID = 'RM' THEN 'RM-INBOUND'
WHEN CORP1_ID = 'RF' THEN 'RF-INBOUND' 
WHEN substring(LAST_SHPG_LOC_CD,1,1) = 'R' THEN 'RETURNS'
WHEN substring(LAST_SHPG_LOC_CD,1,1) = '1' THEN 'INTERMILL'
WHEN substring(LAST_SHPG_LOC_CD,1,1) = '2' THEN 'INTERMILL'
WHEN substring(LAST_SHPG_LOC_CD,1,1) = '5' THEN 'CUSTOMER'
WHEN substring(LAST_SHPG_LOC_CD,1,1) = '9' THEN 'CUSTOMER'
ELSE NULL
END

    /*
Determine CarrierManager, Region, Join State for each load
SELECT * FROM USCTTDEV.dbo.tblOperationalMetrics WHERE ID <20
*/
    UPDATE USCTTDEV.dbo.tblOperationalMetrics
SET CarrierManager = ra.CarrierManager,
Region = ra.Region,
RegionJoinState = ra.StateAbbv,
RegionJoinCountry = ra.Country

FROM
        USCTTDEV.dbo.tblOperationalMetrics om
        INNER JOIN USCTTDEV.dbo.tblRegionalAssignments AS ra
        ON ( ra.StateAbbv = 
    CASE WHEN om.[OrderType] LIKE '%INBOUND%' AND om.BUSINESS_UNIT <> 'NON WOVENS' THEN
        FINAL_STA_CD
        ELSE
        FRST_STA_CD
    END)

    /*
Execute Cancelled Loads Stored Procedure
*/
    EXEC USCTTDEV.dbo.sp_CancelledLoads

    /*
Create a table of temp appointment data for the past 2 calendar years
*/

    DROP TABLE IF EXISTS ##tblAppointments
    SELECT
        *
    INTO ##tblAppointments
    FROM
        OPENQUERY(NAJDAPRD, 'SELECT DISTINCT
    load_leg_detail_r.ld_leg_id           AS loadnumber,
    load_leg_detail_r.dlvy_stop_seq_num   AS stopnumber,
    load_leg_detail_r.to_shpg_loc_cd      AS destinationid,
    load_leg_detail_r.to_shpg_loc_name    AS destinationname,
    load_leg_detail_r.to_cty_name         AS destinationcity,
    load_leg_detail_r.to_sta_cd           AS destinationstate,
    load_leg_detail_r.to_pstl_cd          AS destinationpostalcd,
    load_leg_r.frst_shpg_loc_cd           AS originid,
    load_leg_r.frst_shpg_loc_name         AS originname,
    load_leg_r.frst_cty_name              AS origincity,
    load_leg_r.frst_sta_cd                AS originstate,
    load_leg_r.frst_pstl_cd               AS originpostalcd,
    CASE
        WHEN appointments.appointment_status IS NULL THEN
            ''No Appointments''
        ELSE
            appointments.appointment_status
    END AS appointment_status,
    appointments.apptchgdatetime,
    appointments.apptchgdate,
    appointments.apptcghyear,
    appointments.apptchgmonth,
    appointments.apptchgweek,
    appointments.userid,
    appointments.name,
    appointments.apptfromdtt,
    appointments.appttodtt,
    appointments.firstdate,
    appointments.status,
    appointments.first,
    appointments.rework,
    appointments.count
FROM
    najdaadm.load_leg_r              load_leg_r
    INNER JOIN najdaadm.load_leg_detail_r       load_leg_detail_r ON load_leg_detail_r.ld_leg_id = load_leg_r.ld_leg_id
    INNER JOIN najdaadm.distribution_center_r   distribution_center_r ON distribution_center_r.shpg_loc_cd = load_leg_detail_r.to_shpg_loc_cd
    INNER JOIN (
        SELECT DISTINCT
            load_number,
            stop_number,
            appointment_status,
            apptchgdatetime,
            CAST(TRUNC(apptchgdatetime, ''DD'') AS DATE) AS apptchgdate,
            EXTRACT(YEAR FROM apptchgdatetime) AS apptcghyear,
            EXTRACT(MONTH FROM apptchgdatetime) AS apptchgmonth,
            trunc(apptchgdatetime, ''IW'') AS apptchgweek,
            userid,
            name,
            usr_grp_cd,
            apptfromdtt,
            appttodtt,
            firstdate,
            CASE
                WHEN firstdate = apptchgdatetime THEN
                    appointment_status || '' First''
                ELSE
                    appointment_status || '' Rework''
            END AS status,
            CASE
                WHEN firstdate = apptchgdatetime THEN
                    1
                ELSE
                    0
            END AS first,
            CASE
                WHEN firstdate <> apptchgdatetime THEN
                    1
                ELSE
                    0
            END AS rework,
            1 AS count
        FROM
            (
                SELECT DISTINCT
                    abpp_otc_appointmenthistory.load_number,
                    abpp_otc_appointmenthistory.stop_number,
                    abpp_otc_appointmenthistory.appointment_status,
                    abpp_otc_appointmenthistory.appointment_change_time   AS apptchgdatetime,
                    upper(abpp_otc_appointmenthistory.appointment_changed_by) AS userid,
                    users.name,
                    users.usr_grp_cd,
                    abpp_otc_appointmenthistory.appointment_from_time     AS apptfromdtt,
                    abpp_otc_appointmenthistory.appointment_to_time       AS appttodtt,
                    MIN(abpp_otc_appointmenthistory.appointment_change_time) KEEP(DENSE_RANK FIRST ORDER BY abpp_otc_appointmenthistory
                    .appointment_change_time ASC) OVER(
                        PARTITION BY abpp_otc_appointmenthistory.load_number, appointment_status, stop_number
                    ) AS firstdate
                FROM
                    trn_appt.abpp_otc_appointmenthistory abpp_otc_appointmenthistory
                    LEFT JOIN (
                        SELECT DISTINCT
                            upper(usr_cd) AS userid,
                            name,
                            usr_grp_cd
                        FROM
                            nai2padm.usr_t
                    ) users ON upper(users.userid) = upper(abpp_otc_appointmenthistory.appointment_changed_by)
                WHERE
            EXTRACT( YEAR FROM abpp_otc_appointmenthistory.appointment_change_time) >= EXTRACT(YEAR FROM SYSDATE) - 2
            AND
                    ( abpp_otc_appointmenthistory.stop_number > ''1'' )
                    AND ( abpp_otc_appointmenthistory.appointment_status IN (
                        ''Confirmed'',
                        ''Notified''
                    ) )
            /*AND load_number = ''518606710''*/
                GROUP BY
                    abpp_otc_appointmenthistory.load_number,
                    abpp_otc_appointmenthistory.stop_number,
                    abpp_otc_appointmenthistory.appointment_status,
                    abpp_otc_appointmenthistory.appointment_change_time,
                    upper(abpp_otc_appointmenthistory.appointment_changed_by),
                    users.name,
                    users.usr_grp_cd,
                    abpp_otc_appointmenthistory.appointment_from_time,
                    abpp_otc_appointmenthistory.appointment_to_time
                ORDER BY
                    abpp_otc_appointmenthistory.load_number,
                    abpp_otc_appointmenthistory.stop_number,
                    abpp_otc_appointmenthistory.appointment_change_time
            ) appointments
    ) appointments ON appointments.load_number = load_leg_detail_r.ld_leg_id
                      AND appointments.stop_number = load_leg_detail_r.dlvy_stop_seq_num
WHERE
    (/* ( load_leg_r.shpd_dtt >= add_months(trunc(SYSDATE, ''MM''), - 2) )*/
	EXTRACT(YEAR FROM load_leg_r.shpd_dtt) >= EXTRACT(YEAR FROM SYSDATE) -2
      AND ( load_leg_detail_r.dlvy_stop_seq_num > 1 )
      AND ( load_leg_detail_r.to_ctry_cd IN (
        ''USA'',
        ''CAN'',
		''MEX''
    ) )
      AND ( load_leg_detail_r.to_pnt_typ_enu = ''Distribution Center'' )
      AND ( load_leg_r.eqmt_typ IN (
        ''48FT'',
        ''53FT'',
        ''53IM'',
        ''53RT'',
        ''53TC'',
        ''53HC''
    ) )
      AND ( distribution_center_r.apt_rqrd_yn = ''Y'' ) ) /*AND
    LOAD_LEG_R.LD_LEG_ID = ''518606710''*/
ORDER BY
    load_leg_detail_r.ld_leg_id,
    load_leg_detail_r.dlvy_stop_seq_num,
    appointments.apptchgdatetime') data

    /*
Create a table of MIN appointment stuff, for when the first appointment was made for Notified and Confirmed
SELECT TOP 50 * FROM ##tblAppointments ORDER BY LOADNUMBER ASC, APPTCHGDATETIME ASC

*/
    DROP TABLE IF EXISTS ##tblAppointmentsMin
    SELECT
        DISTINCT
        LoadNumber
    INTO ##tblAppointmentsMin
    FROM
        ##tblAppointments

    /*
Add FIRST_APPT_NOTIFIED and FIRST_APPT_CONFIRMED to ##tblAppointmentsMin
SELECT TOP 50  * FROM ##tblAppointmentsMin
*/
    IF NOT EXISTS (SELECT
        *
    FROM
        TempDB.INFORMATION_SCHEMA.COLUMNS
    WHERE COLUMN_NAME = 'FIRST_APPT_NOTIFIED' AND TABLE_NAME LIKE '##tblAppointmentsMin') ALTER TABLE ##tblAppointmentsMin ADD [FIRST_APPT_NOTIFIED] 		DATETIME NULL
    IF NOT EXISTS (SELECT
        *
    FROM
        TempDB.INFORMATION_SCHEMA.COLUMNS
    WHERE COLUMN_NAME = 'FIRST_APPT_CONFIRMED' AND TABLE_NAME LIKE '##tblAppointmentsMin') ALTER TABLE ##tblAppointmentsMin ADD [FIRST_APPT_CONFIRMED]	DATETIME NULL

    /*
Update ##tblAppointmentsMin with first appointment notified datetime
SELECT * FROM ##tblAppointmentsMin
*/
    UPDATE ##tblAppointmentsMin
SET FIRST_APPT_NOTIFIED = notified.FIRST_APPT_NOTIFIED
FROM
        ##tblAppointmentsMin aptm
        INNER JOIN(
	SELECT
            LoadNumber,
            MIN(apt.APPTCHGDATETIME) AS FIRST_APPT_NOTIFIED
        FROM
            ##tblAppointments apt
        WHERE apt.STATUS = 'Notified First'
        GROUP BY LoadNumber) notified ON notified.LoadNumber = aptm.LoadNumber

    /*
Update ##tblAppointmentsMin with first appointment notified datetime
*/
    UPDATE ##tblAppointmentsMin
SET FIRST_APPT_CONFIRMED = confirmed.FIRST_APPT_CONFIRMED
FROM
        ##tblAppointmentsMin aptm
        INNER JOIN(
	SELECT
            LoadNumber,
            MIN(apt.APPTCHGDATETIME) AS FIRST_APPT_CONFIRMED
        FROM
            ##tblAppointments apt
        WHERE apt.STATUS = 'Confirmed First'
        GROUP BY LoadNumber) confirmed ON confirmed.LoadNumber = aptm.LoadNumber


    /*
Update Operational Metrics with FIRST_APPT_NOTIFIED and FIRST_APPT_CONFIRMED
*/
    UPDATE USCTTDEV.dbo.tblOperationalMetrics
SET FIRST_APPT_NOTIFIED = min.FIRST_APPT_NOTIFIED,
FIRST_APPT_CONFIRMED = min.FIRST_APPT_CONFIRMED
FROM
        USCTTDEV.dbo.tblOperationalMetrics om
        INNER JOIN ##tblAppointmentsMin min ON min.LoadNumber = om.LD_LEG_ID

    /*
Attempt to update Business Unit from Actual Load Detail.
Otherwise, assume that it's KCNA
*/
    UPDATE USCTTDEV.dbo.tblOperationalMetrics
SET BUSINESS_UNIT = CASE WHEN om.BUSINESS_UNIT IS NOT NULL THEN om.BUSINESS_UNIT
WHEN ald.BU IS NULL THEN 'KCNA' ELSE ald.BU END
FROM
        USCTTDEV.dbo.tblOperationalMetrics om
        LEFT JOIN USCTTDEV.dbo.tblActualLoadDetail ald ON ald.LD_LEG_ID = om.LD_LEG_ID
WHERE om.BUSINESS_UNIT IS NULL
        AND CAST(om.LastUpdated AS DATE) = CAST(GETDATE() AS DATE)

    /*
Force to KCNA or KCP Business Units
*/
    UPDATE USCTTDEV.dbo.tblOperationalMetrics
SET BUSINESS_UNIT = CASE WHEN BUSINESS_UNIT = 'KCP' THEN 'KCP'
ELSE 'KCNA' END
WHERE CAST(LastUpdated AS DATE) = CAST(GETDATE() AS DATE)

    /*
Update Operational Metrics with new fields from Actual Load Detail
*/
    UPDATE USCTTDEV.dbo.tblOperationalMetrics
SET FRAN = CASE WHEN ald.FRAN = 'eAuction' THEN 'eAuction' ELSE NULL END,
AwardLane = ald.AwardLane,
AWARD_LANE_STATUS = CASE WHEN ald.AwardLane = 'Y' THEN 'Award Lane' ELSE 'Not Award Lane' END,
AWARD_LANE_CNT = CASE WHEN ald.AwardLane = 'Y' THEN '1' ELSE '0' END,
AwardCarrier = ald.AwardCarrier,
AWARD_SERVICE_STATUS = CASE WHEN ald.AwardCarrier = 'Y' THEN 'Award Carrier' ELSE 'Not Award Carrier' END,
AWARD_SERVICE_CNT = CASE WHEN ald.AwardCarrier = 'Y' THEN '1' ELSE '0' END,
Broker = ald.Broker,
Spacemaker = ald.Spacemaker,
WeightedAwardRPM = ald.WeightedAwardRPM,
BUSegment = CASE WHEN ald.BUSegment IS NULL THEN 'UNKNOWN' ELSE ald.BUSegment END,
Dedicated = ald.Dedicated,
RateType = CASE WHEN ald.RateType IS NULL THEN 'UNKNOWN' ELSE ald.RateType END,
LiveLoad = ald.LiveLoad
FROM
        USCTTDEV.dbo.tblOperationalMetrics om
        LEFT JOIN USCTTDEV.dbo.tblActualLoadDetail ald ON ald.LD_LEG_ID = om.LD_LEG_ID
WHERE (CAST(om.LastUpdated AS DATE) = CAST(GETDATE() AS DATE) OR CAST(ald.LastUpdated AS DATE) = CAST(GETDATE() AS DATE))

    /*
New 1/13/2021
Update Team Name/Groups where different with data from Eric Mailhan
*/
    UPDATE USCTTDEV.dbo.tblOperationalMetrics
SET TEAM_GROUP = ca.TEAM_GROUP,
TEAM_NAME = ca.TEAM_NAME
FROM
        USCTTDEV.dbo.tblOperationalMetrics om
        INNER JOIN (
SELECT
            *
        FROM
            OPENQUERY(NAJDAPRD,'
SELECT DISTINCT ca.LOCATION_ID,
ca.TEAM_NAME,
TEAM_ID,
TEAM_GROUP
FROM NAJDAADM.ABPP_OTC_CAPS_ANALYST ca
WHERE CAST(TO_DATE AS DATE) >= CAST(SYSDATE AS DATE)
') data
)ca ON ca.LOCATION_ID = om.FRST_SHPG_LOC_CD
WHERE (om.TEAM_GROUP <> ca.TEAM_GROUP OR om.TEAM_GROUP IS NULL)
        OR (om.TEAM_NAME <> ca.TEAM_NAME OR om.TEAM_NAME IS NULL)

    /*
Update the Order Type to NON WOVEN when Sales Org = "Z05"
Per Katie Haynes / 3/10/2021
*/
    UPDATE USCTTDEV.dbo.tblOperationalMetrics
SET OrderType = 'NON WOVENS',
SHIP_TYPE = 'NON WOVENS'
WHERE SALES_ORG = 'Z05'

    /*
4/27/2021
Per Katie Haynes / Melanie, capture the first pickup appointment date time for use in Tableau Pickup Dashboard
*/
    UPDATE USCTTDEV.dbo.tblOperationalMetrics
SET ORIGINAL_PICKUP_FROM_DTT = pickupAppt.APPOINTMENT_FROM_TIME,
ORIGINAL_PICKUP_TO_DTT = pickupAppt.APPOINTMENT_TO_TIME 
FROM
        USCTTDEV.dbo.tblOperationalMetrics om
        INNER JOIN (
	SELECT
            *
        FROM
            OPENQUERY(NAJDAPRD,'
	SELECT 
	LOAD_NUMBER,
	APPOINTMENT_FROM_TIME,
	APPOINTMENT_TO_TIME,
	APPOINTMENT_CHANGE_TIME,
	LOAD_STATUS,
	REASON_CODE,
	REASON_DESC,
	ROW_NUMBER() OVER (PARTITION BY LOAD_NUMBER ORDER BY APPOINTMENT_CHANGE_TIME ASC) AS Rank
	FROM NAI2PADM.abpp_otc_appointmenthistory
	WHERE STOP_NUMBER = 1
	AND EXTRACT(YEAR FROM APPOINTMENT_CHANGE_TIME) >= EXTRACT(YEAR FROM SYSDATE) - 2
	/*AND LOAD_NUMBER = ''521182291''*/
	ORDER BY APPOINTMENT_CHANGE_TIME ASC
	') data
) pickupAppt ON pickupAppt.LOAD_NUMBER = om.LD_LEG_ID
WHERE pickupAppt.Rank = 1

    /*
Clear appointment temp tables
*/
    DROP TABLE IF EXISTS ##tblAppointments
    DROP TABLE IF EXISTS ##tblAppointmentsMin

    /*
Update 8/20/2021
Per Jeff Perrot, COMPLETION_DATE_TIME wanting to measure when the loads are actually picked up
*/
    UPDATE USCTTDEV.dbo.tblOperationalMetrics
SET COMPLETION_DATE_TIME = data.COMPLETION_DATE_TIME
FROM
        USCTTDEV.dbo.tblOperationalMetrics om
        INNER JOIN (
SELECT
            *
        FROM
            OPENQUERY(NAJDAPRD,'
SELECT cm.LOAD_ID,
llr.STRD_DTT,
cm.ARRIVED_AT_DATETIME,
cm.COMPLETION_DATE_TIME,
llr.SHPD_DTT,
REPLACE(CASE
    WHEN INSTR(llr.FRST_SHPG_LOC_CD,''-'') > 0 THEN
	SUBSTR(llr.FRST_SHPG_LOC_CD, 0, INSTR(llr.FRST_SHPG_LOC_CD,''-'')-1)
    ELSE
        llr.FRST_SHPG_LOC_CD
END , ''V'','''') AS FRST_SHPG_PLANT,
llr.FRST_SHPG_LOC_CD,
CASE WHEN cust.cust_cd IS NOT NULL THEN cust.name
	ELSE
		CASE 
		WHEN SUBSTR(llr.FRST_SHPG_LOC_CD,1,1) = ''V'' THEN SUBSTR(llr.FRST_SHPG_LOC_CD,1,9)
		WHEN CAST(SUBSTR(llr.FRST_SHPG_LOC_CD,1,1) AS VARCHAR(1)) IN ( ''1'', ''2'') THEN CAST(SUBSTR(llr.FRST_SHPG_LOC_CD,1,4) AS VARCHAR(4)) || '' - '' || llr.FRST_CTY_NAME
		ELSE ''UNKNOWN'' 
	END 
END AS OriginPlant
FROM
NAI2PADM.ABPP_OTC_CAPS_MASTER cm
INNER JOIN NAJDAADM.LOAD_LEG_R llr ON llr.LD_LEG_ID = cm.LOAD_ID
LEFT JOIN NAJDAADM.CUST_TV cust ON cust.CUST_CD = SUBSTR(llr.FRST_SHPG_LOC_CD,2,8)
WHERE TRUNC(llr.STRD_DTT) IS NOT NULL
AND cm.STOP_NUM = 1
') data ) data ON data.LOAD_ID = om.LD_LEG_ID

    /*
Set Pickup Date/Time
Logic from Jeff Perrot 8/20/2021
Pickup_Time = min(ABPP_OTC_CAPS_MASTER.ARRIVED_AT_DATETIME, LOAD_LEG_R.SHPD_DTT).  If both are NULL then we have to assume the load has not picked up yet.
*/
    UPDATE USCTTDEV.dbo.tblOperationalMetrics
SET PICKUP_TIME = CASE WHEN CARR_ARRIVED_AT_DATETIME <= SHIP_DATE THEN CARR_ARRIVED_AT_DATETIME
WHEN SHIP_DATE < CARR_ARRIVED_AT_DATETIME THEN SHIP_DATE
WHEN SHIP_DATE IS NOT NULL THEN SHIP_DATE
WHEN CARR_ARRIVED_AT_DATETIME IS NOT NULL THEN CARR_ARRIVED_AT_DATETIME
ELSE NULL END

    /*
Update RateType to "Spot' if it went on eAuction process and is still marked as contract
8/27/2021
*/
    UPDATE USCTTDEV.dbo.tblOperationalMetrics
SET RateType = 'Spot'
FROM
        USCTTDEV.dbo.tblOperationalMetrics om
        INNER JOIN (
SELECT
            *
        FROM
            OPENQUERY(NAJDAPRD,'SELECT DISTINCT fablt.BID_LOAD_ID,
fablt.EXTL_LOAD_ID AS LD_LEG_ID,
bids.TotalBids As BidCount,
bids.TotalBidders As EligibleToBidCount,
CASE WHEN bids.TotalBids = 0 THEN ''No Participation''
WHEN awards.BID_LOAD_ID IS NULL THEN ''Not Awarded''
WHEN awards.BID_LOAD_ID IS NOT NULL THEN ''Awarded''
END AS FinalLoadParticipation,
awards.TotalBid AS WinningBid,
awards.CARR_CD AS WinningCarrier,
awards.SRVC_CD AS WinningService
FROM najdafa.tm_frht_auction_bid_ld_t fablt

/*
This query contains all of the details about awarded loads
*/
LEFT JOIN (
SELECT DISTINCT facbt.BID_LOAD_ID, 
fablt.EXTL_LOAD_ID AS LD_LEG_ID,
facbt.BID_RESPONSE_ENU,
facbt.RATE_ADJ_AMT_DLR,
facbt.RATE_ADJ_AWARD_AMT_DLR,
facbt.CONTRACT_AMT_DLR,
CASE WHEN facbt.RATE_ADJ_AWARD_AMT_DLR IS NULL THEN facbt.RATE_ADJ_AMT_DLR ELSE facbt.RATE_ADJ_AWARD_AMT_DLR END + facbt.CONTRACT_AMT_DLR AS TotalBid,
facbt.CARR_CD,
facbt.SRVC_CD,
Options.TotalBidders
FROM najdafa.tm_frht_auction_car_bid_t facbt
INNER JOIN najdafa.tm_frht_auction_bid_ld_t fablt ON fablt.bid_load_id = facbt.bid_load_id
LEFT JOIN (SELECT DISTINCT facbt.BID_LOAD_ID, COUNT(*) AS TotalBidders
FROM najdafa.tm_frht_auction_car_bid_t facbt
WHERE facbt.BID_RESPONSE_ENU IS NOT NULL
GROUP BY facbt.BID_LOAD_ID) Options ON Options.BID_LOAD_ID = facbt.BID_LOAD_ID
WHERE facbt.BID_RESPONSE_ENU = ''LOAD_AWARDED''
)awards ON awards.bid_load_id = fablt.BID_LOAD_ID
AND awards.LD_LEG_ID = fablt.EXTL_LOAD_ID

/*
This query contains the total bid/participation count
*/
LEFT JOIN(
SELECT DISTINCT facbt.BID_LOAD_ID, 
COUNT(*) AS TotalBidders,
SUM(CASE WHEN facbt.RATE_ADJ_AMT_DLR IS NOT NULL THEN 1
WHEN facbt.RATE_ADJ_AWARD_AMT_DLR IS NOT NULL THEN 1
ELSE 0 END) AS TotalBids
FROM najdafa.tm_frht_auction_car_bid_t facbt
GROUP BY facbt.BID_LOAD_ID
ORDER BY facbt.BID_LOAD_ID ASC
) bids ON bids.bid_load_id = fablt.BID_LOAD_ID

/*
Only use the most recent BID_LOAD_ID details
*/
INNER JOIN (
SELECT MAX (fablt.BID_LOAD_ID) AS MaxID,
fablt.EXTL_LOAD_ID AS LD_LEG_ID
FROM najdafa.tm_frht_auction_bid_ld_t fablt
GROUP BY fablt.EXTL_LOAD_ID
) maxID ON maxID.MaxID = fablt.BID_LOAD_ID

WHERE fablt.AUCTION_ENTRY_DTT >= ''2020-03-01''

GROUP BY 
fablt.BID_LOAD_ID,
fablt.EXTL_LOAD_ID,
CASE WHEN awards.BID_LOAD_ID IS NOT NULL THEN awards.TotalBidders END,
bids.TotalBids,
bids.TotalBidders,
CASE WHEN bids.TotalBids = 0 THEN ''No Participation''
WHEN awards.BID_LOAD_ID IS NULL THEN ''Not Awarded''
WHEN awards.BID_LOAD_ID IS NOT NULL THEN ''Awarded''
END,
awards.TotalBid,
awards.CARR_CD,
awards.SRVC_CD')FinalStatus
        WHERE FinalStatus.FinalLoadParticipation = 'Awarded'
) eAuction ON eAuction.LD_LEG_ID = om .LD_LEG_ID
            AND eAuction.WinningCarrier = om .CARR_CD
            AND eAuction.WinningService = om .SRVC_CD
WHERE om .RateType <> 'Spot'

    /*
Update UNKNOWN Rate type to "Contract" since it didn't appear in the above query and still isn't on ALD
*/
    UPDATE USCTTDEV.dbo.tblOperationalMetrics
SET RateType = 'Contract'
WHERE RateType = 'UNKNOWN'
        AND CAST(LastUpdated AS DATE) = CAST(GETDATE() AS DATE)

    /*
Update Null order type if it wasn't on ALD when it ran
*/
    UPDATE USCTTDEV.dbo.tblOperationalMetrics
SET OrderType = 
CASE WHEN CORP1_ID = 'RM' THEN 'RM-INBOUND'
WHEN CORP1_ID = 'RF' THEN 'RF-INBOUND' 
WHEN SUBSTRING(LAST_SHPG_LOC_CD,1,1) = 'R' THEN 'RETURNS'
WHEN SUBSTRING(LAST_SHPG_LOC_CD,1,1) = '1' THEN 'INTERMILL'
WHEN SUBSTRING(LAST_SHPG_LOC_CD,1,1) = '2' THEN 'INTERMILL'
WHEN SUBSTRING(LAST_SHPG_LOC_CD,1,1) = '5' THEN 'CUSTOMER'
WHEN SUBSTRING(LAST_SHPG_LOC_CD,1,1) = '9' THEN 'CUSTOMER'
WHEN LAST_SHPG_LOC_CD LIKE '%HUB%' THEN 'CUSTOMER'
ELSE NULL
END
WHERE CAST(LastUpdated AS DATE) = CAST(GETDATE() AS DATE)

END