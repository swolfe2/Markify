USE USCTTDEV;

CREATE TABLE ##NFILRejects
(
	LD_LEG_ID NVARCHAR (10),
	REJECT_DATE_TIME datetime,
	TENDERED_READY_DATE datetime,
	TENDERED_END_DATE datetime,
	ORIGINCITYSTATE NVARCHAR (50),
	DEST5ZIP NVARCHAR (5),
	DESTCITYSTATE NVARCHAR (75),
	DESTSTATE NVARCHAR (5),
	LAST_SHPG_LOC_NAME NVARCHAR (100),
	EQMT_TYP NVARCHAR (4),
	LD_SRVC_CD NVARCHAR (4),
	AUDIT_CNFG_CD NVARCHAR(10)
)

INSERT INTO ##NFILRejects
SELECT * FROM OPENQUERY(NAJDAPRD, 'SELECT
    l.ld_leg_id,
    TO_CHAR(a.audt_sys_dtt, ''MM/DD/YYYY'')   AS reject_date_time,
    TO_CHAR(a.ld_strd_dtt, ''MM/DD/YYYY'')    AS tendered_ready_date,
    TO_CHAR(a.ld_end_dtt, ''MM/DD/YYYY'')     AS tendered_end_date,
    CASE
        WHEN l.frst_shpg_loc_cd IN (
            ''2292-NB01'',
            ''2358-NC04'',
            ''2358-NC05''
        ) THEN
            l.frst_cty_name
            || ''-NOF-''
            || l.frst_sta_cd
        WHEN l.frst_shpg_loc_cd IN (
            ''2323-KR01''
        ) THEN
            l.frst_cty_name
            || ''-KCP-''
            || l.frst_sta_cd
        WHEN l.frst_shpg_loc_cd IN (
            ''2474-RV01''
        ) THEN
            l.frst_cty_name
            || ''-SKINCARE-''
            || l.frst_sta_cd
        WHEN l.frst_cty_name = ''FLETCHER'' THEN
            ''HENDERSONVILLE-NC'' /*combining Hendersonville and Fletcher*/
        ELSE
            frst_cty_name
            || ''-''
            || frst_sta_cd
    END AS origincitystate,
    CASE
        WHEN last_ctry_cd = ''CAN'' THEN
            substr(last_pstl_cd, 1, 6)
        ELSE
            substr(last_pstl_cd, 1, 5)
    END AS dest5zip,
    last_cty_name
    || ''-''
    || last_sta_cd AS destcitystate,
    last_sta_cd      AS deststate,
    last_shpg_loc_name,
    l.eqmt_typ,
    a.ld_srvc_cd,
    a.audt_cnfg_cd
FROM
    nai2padm.audit_load_leg_r   a,
    najdaadm.load_leg_r         l
WHERE
    ( l.cur_optlstat_id IN (
        320,
        325,
        335,
        345
    ) )
    --AND TO_CHAR(a.audt_sys_dtt, ''YYYYMMDD'') BETWEEN TO_CHAR(SYSDATE - 7, ''YYYYMMDD'') AND TO_CHAR(SYSDATE - 1, ''YYYYMMDD'')
	--AND a.audt_sys_dtt >= sysdate - 7
	AND a.audt_sys_dtt between SYSDATE - 7 and SYSDATE
    AND a.ld_srvc_cd = ''NFIL''
    AND ( l.ld_leg_id = a.ld_leg_id )
    AND a.audt_cnfg_cd IN (
        ''TENDREJ''
    )
    AND l.eqmt_typ IN (
        ''53FT'',
        ''53IM''
    )
    AND l.last_ctry_cd IN (
        ''USA'',
        ''MEX'',
        ''CAN''
    )
    AND last_shpg_loc_cd <> ''99999999''
	ORDER BY ORIGINCITYSTATE, REJECT_DATE_TIME, LD_LEG_ID ASC')


--select * from [USCTTDEV].[dbo].[tblCustomers])
