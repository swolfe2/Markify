USE [USCTTDEV]
GO
/****** Object:  StoredProcedure [dbo].[sp_AuditLoadLeg]    Script Date: 1/17/2020 11:47:21 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Thomas Fraser, thomas.g.fraser2@kcc.com, Central Transportation Team>
-- Create date: <11/25/2019>
-- Description:	<Creates an audit table that houses historical load detailed information>
-- =============================================
ALTER PROCEDURE [dbo].[sp_AuditLoadLeg] 

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

/* Declare variables */
DECLARE @cols AS NVARCHAR(MAX),
@query AS NVARCHAR(MAX),
@dateFrom DATE,
@now AS DATETIME

SET @now = GETDATE()
SET @dateFrom = '2019-01-01'

DROP TABLE IF EXISTS
##tblAuditLoadLegTemp

/*set query */
SET @query = '
SELECT
    audt.*,
    que_dtt,
    strt_dtt,
    cpld_dtt,
    usr_cd AS cst_usr,
    CASE
        WHEN audt_sec_cd = ''TNRD'' THEN
            audt_sec_rank
    END AS load_offer_seq,
    CASE
        WHEN audt_sec_cd IN (
            ''REJD'',
            ''INVD'',
            ''ODLT''
        ) THEN
            audt_sec_rank
    END AS reject_seq,
    CASE
        WHEN audt_sec_cd = ''EXP_'' THEN
            audt_sec_rank
    END AS tender_timeout_seq
FROM
    (
        SELECT
            a.audt_ld_leg_id,
            a.audt_ctl_id,
            a.audt_cnfg_cd,
            a.audt_usr_cd,
            ld_carr_cd,
            ld_srvc_cd,
            a.audt_sec_cd,
            a.audt_sys_dtt,
            ld_strd_dtt,
            ld_end_dtt,
            ld_src_cd,
            a.ld_leg_id,
            ld_optlstat_cd,
            c.audt_sec_desc,
            RANK() OVER(
                PARTITION BY a.ld_leg_id,(
                    CASE
                        WHEN a.audt_sec_cd = ''INVD'' THEN
                            ''REJD''
                        ELSE
                            a.audt_sec_cd
                    END
                )
                ORDER BY
                    audt_ld_leg_id
            ) AS audt_sec_rank,
            la.orig_zn_cd,
            la.dest_zn_cd,
            la.rate_cd,
			t.tff_id,
            t.tff_cd,
            t.tff_desc,
            ms.srvc_desc,
            carr.name
        FROM
            najdaadm.audit_load_leg_r     a
            INNER JOIN najdaadm.load_leg_r           l ON a.ld_leg_id = l.ld_leg_id
            INNER JOIN najdaadm.audit_control_r      c ON a.audt_ctl_id = c.audt_ctl_id
            INNER JOIN najdaadm.lane_association_r   la ON a.ld_ratg_tff_id = la.tff_id
                                                         AND a.lane_assc_id = la.lane_assc_id
            INNER JOIN najdaadm.tariff_r             t ON a.ld_ratg_tff_id = t.tff_id
            INNER JOIN najdaadm.mstr_srvc_t          ms ON a.ld_srvc_cd = ms.srvc_cd
            INNER JOIN najdaadm.carrier_r            carr ON a.ld_carr_cd = carr.carr_cd
        WHERE
            a.audt_sec_cd IN (
                ''LCO_'',
                ''TNRD'',
                ''REJD'',
                ''INVD'',
                ''ACPD'',
                ''PLND'',
                ''EXP_'',
                ''ODLT''
            )
            AND cur_optlstat_id IN (
                310,
                315,
                320,
                325,
                330,
                335,
                345
            )
            AND substr(l.last_shpg_loc_cd, 1, 1) != ''9''
            AND (
                CASE
                    WHEN strd_dtt IS NULL THEN
                        shpd_dtt
                    ELSE
                        strd_dtt
                END
            ) >= trunc(sysdate) - 120
            AND frst_ctry_cd IN (
                ''USA'',
                ''CAN'',
                ''MEX''
            )
            AND last_ctry_cd IN (
                ''USA'',
                ''CAN'',
                ''MEX''
            )
            AND eqmt_typ IN (
                ''53FT'',
                ''53IM'',
                ''53TC'',
                ''53CT'',
                ''53RT'',
                ''48FT'',
                ''48CT'',
                ''53HC''
            )
        ORDER BY
            audt_ld_leg_id
    ) audt
    LEFT JOIN najdaadm.cst_queue_r cst ON audt.ld_leg_id = cst.ld_leg_id
'

/* create a temporary table that will house the data gathered from Oracle */
CREATE TABLE ##tblAuditLoadLegTemp
  ( 

AUDT_LD_LEG_ID				INT,
AUDT_CTL_ID					INT,
AUDT_CNFG_CD				NVARCHAR(100),
AUDT_USR_CD					NVARCHAR(100),
LD_CARR_CD					NVARCHAR(100),
LD_SRVC_CD					NVARCHAR(100),
AUDT_SEC_CD					NVARCHAR(100),
AUDT_SYS_DTT				DATETIME,
LD_STRD_DTT					DATETIME,
LD_END_DTT					DATETIME,
LD_SRC_CD					NVARCHAR(100),
LD_LEG_ID					INT,
LD_OPTLSTAT_CD				NVARCHAR(100),
AUDT_SEC_DESC				NVARCHAR(100),
AUDT_SEC_RANK				INT,
ORIG_ZN_CD					NVARCHAR(100),
DEST_ZN_CD					NVARCHAR(100),
RATE_CD						NVARCHAR(100),
TFF_ID						INT,
TFF_CD						NVARCHAR(100),
TFF_DESC					NVARCHAR(100),
SRVC_DESC					NVARCHAR(100),
NAME						NVARCHAR(100),
QUE_DTT						DATETIME,
STRT_DTT					DATETIME,
CPLD_DTT					DATETIME,
CST_USR						NVARCHAR(100),
LOAD_OFFER_SEQ				INT,
REJECT_SEQ					INT,
TENDER_TIMEOUT_SEQ			INT
)

/* exectue query from Oracle and insert into newly created temporary table */
INSERT INTO ##tblAuditLoadLegTemp
EXEC (@query) AT NAJDAPRD

/* update existing records where there is a match */
UPDATE USCTTDEV.dbo.tblAuditLoadLeg
SET
	audt_ctl_id = t.audt_ctl_id,
	audt_cnfg_cd = t.audt_cnfg_cd,
	audt_usr_cd = t.audt_usr_cd,
	ld_carr_cd = t.ld_carr_cd,
	ld_srvc_cd = t.ld_srvc_cd,
	audt_sec_cd = t.audt_sec_cd,
	audt_sys_dtt = t.audt_sys_dtt,
	ld_strd_dtt = t.ld_strd_dtt,
	ld_end_dtt = t.ld_end_dtt,
	ld_src_cd = t.ld_src_cd,
	ld_leg_id = t.ld_leg_id,
	ld_optlstat_cd = t.ld_optlstat_cd,
	audt_sec_desc = t.audt_sec_desc,
	audt_sec_rank = t.audt_sec_rank,
	orig_zn_cd = t.orig_zn_cd,
	dest_zn_cd = t.dest_zn_cd,
	rate_cd = t.RATE_CD,
	tff_id = t.tff_id,
	tff_cd = t.tff_cd,
	tff_desc = t.tff_desc,
	srvc_desc = t.srvc_desc,
	name = t.name,
	que_dtt = t.que_dtt,
	strt_dtt = t.strt_dtt,
	cpld_dtt = t.cpld_dtt,
	cst_usr = t.cst_usr,
	load_offer_seq = t.load_offer_seq,
	reject_seq = t.reject_seq,
	tender_timeout_seq = t.tender_timeout_seq,
	last_updated = @now
FROM USCTTDEV.dbo.tblAuditLoadLeg tall
INNER JOIN ##tblAuditLoadLegTemp t ON CAST(tall.audt_ld_leg_id AS INT) = CAST(t.audt_ld_leg_id AS INT)

/* insert completely new records */
INSERT INTO USCTTDEV.dbo.tblAuditLoadLeg
	(AUDT_LD_LEG_ID,
	AUDT_CTL_ID,
	AUDT_CNFG_CD,
	AUDT_USR_CD,
	LD_CARR_CD,
	LD_SRVC_CD,
	AUDT_SEC_CD,
	AUDT_SYS_DTT,
	LD_STRD_DTT,
	LD_END_DTT,
	LD_SRC_CD,
	LD_LEG_ID,
	LD_OPTLSTAT_CD,
	AUDT_SEC_DESC,
	AUDT_SEC_RANK,
	ORIG_ZN_CD,
	DEST_ZN_CD,
	RATE_CD,
	TFF_ID,
	TFF_CD,
	TFF_DESC,
	SRVC_DESC,
	NAME,
	QUE_DTT,
	STRT_DTT,
	CPLD_DTT,
	CST_USR,
	LOAD_OFFER_SEQ,
	REJECT_SEQ,
	TENDER_TIMEOUT_SEQ,
	ADDED_ON,
	LAST_UPDATED)
SELECT
	t.AUDT_LD_LEG_ID,
	t.AUDT_CTL_ID,
	t.AUDT_CNFG_CD,
	t.AUDT_USR_CD,
	t.LD_CARR_CD,
	t.LD_SRVC_CD,
	t.AUDT_SEC_CD,
	t.AUDT_SYS_DTT,
	t.LD_STRD_DTT,
	t.LD_END_DTT,
	t.LD_SRC_CD,
	t.LD_LEG_ID,
	t.LD_OPTLSTAT_CD,
	t.AUDT_SEC_DESC,
	t.AUDT_SEC_RANK,
	t.ORIG_ZN_CD,
	t.DEST_ZN_CD,
	TRY_CONVERT(NUMERIC(18, 2), t.RATE_CD) AS RATE_CD,
	t.TFF_ID,
	t.TFF_CD,
	t.TFF_DESC,
	t.SRVC_DESC,
	t.NAME,
	t.QUE_DTT,
	t.STRT_DTT,
	t.CPLD_DTT,
	t.CST_USR,
	t.LOAD_OFFER_SEQ,
	t.REJECT_SEQ,
	t.TENDER_TIMEOUT_SEQ,
	@now AS ADDED_ON,
	@now AS LAST_UPDATED
FROM
	##tblAuditLoadLegTemp t
LEFT JOIN
	USCTTDEV.dbo.tblAuditLoadLeg tall
ON
	t.audt_ld_leg_id = tall.audt_ld_leg_id
WHERE
	tall.audt_ld_leg_id IS NULL


/* drop temporary table */
DROP TABLE IF EXISTS
##tblAuditLoadLegTemp

END
