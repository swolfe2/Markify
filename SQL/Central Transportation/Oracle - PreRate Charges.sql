SELECT
    l.ld_leg_id,
    c.chrg_cd,
    CASE
        WHEN l.srvc_cd IN (
            'HJBM',
            'OPEN',
            'NFIL',
            'WEDV',
            'WEND'
        )
             AND c.chrg_cd IN (
            'ADLH',
            'CATX',
            'CONT',
            'CUBE',
            'CWF1',
            'CWF2',
            'CWF3',
            'CWF4',
            'CWT',
            'CWTF',
            'CWTM',
            'DISC',
            'DIST',
            'DT2',
            'FBED',
            'FLAT',
            'GRI',
            'ISPT',
            'LMIN',
            'LTLD',
            'MILE',
            'OCFR',
            'OCN1',
            'PKG1',
            'SPOT',
            'TC',
            'TCM',
            'UPD',
            'WGT',
            'ZNFD',
            'ZWND',
            'ZJBH',
            'ZSPT'
        ) THEN
            'PreRate_Linehaul'
        WHEN l.srvc_cd NOT IN (
            'HJBM',
            'OPEN',
            'NFIL',
            'WEDV',
            'WEND'
        )
             AND c.chrg_cd IN (
            'ADLH',
            'CATX',
            'CONT',
            'CUBE',
            'CWF1',
            'CWF2',
            'CWF3',
            'CWF4',
            'CWT',
            'CWTF',
            'CWTM',
            'DISC',
            'DIST',
            'DT2',
            'FBED',
            'FLAT',
            'GRI',
            'ISPT',
            'LMIN',
            'LTLD',
            'MILE',
            'OCFR',
            'OCN1',
            'PKG1',
            'SPOT',
            'TC',
            'TCM',
            'UPD',
            'WGT',
            'ZNFD',
            'ZWND',
            'ZJBH',
            'ZSPT'
        ) THEN
            'PreRate_Linehaul'
        WHEN c.chrg_cd IN (
            'BAF',
            'DFSC',
            'FS01',
            'FS02',
            'FS03',
            'FS04',
            'FS05',
            'FS06',
            'FS07',
            'FS08',
            'FS09',
            'FS10',
            'FS11',
            'FS12',
            'FS13',
            'FS14',
            'FS15',
            'FSCA',
            'PFSC',
            'RFSC',
            'WCFS'
        ) THEN
            'PreRate_Fuel'
        WHEN c.chrg_cd IN (
            'ZREP',
            'ZDHM'
        ) THEN
            'PreRate_Repo'
		WHEN c.chrg_cd IN (
            'ZUSB'
        ) THEN
            'PreRate_ZUSB'
        ELSE
            'PreRate_Accessorials'
    END AS chargetype,
    c.chrg_amt_dlr    AS chargeamount,
    c.pymnt_amt_dlr   AS paymentamount
FROM
    najdaadm.charge_detail_r   c
	JOIN najdaadm.load_leg_r   l ON l.ld_leg_id = c.ld_leg_id
WHERE
  EXTRACT(YEAR FROM
        CASE
            WHEN l.shpd_dtt IS NULL THEN
                l.strd_dtt
            ELSE
                l.shpd_dtt
        END
    ) >= EXTRACT(YEAR FROM SYSDATE)-1
    AND l.cur_optlstat_id IN (
        300,
        305,
        310,
        320,
        325,
        335,
        345
    )
    AND l.eqmt_typ IN (
        '48FT',
        '48TC',
        '53FT',
        '53TC',
        '53IM',
        '53RT',
        '53HC',
		'LTL'
    )
    AND l.srvc_cd NOT IN (
        'OPAF',
        'OPEC',
        'OPEX',
        'OPKG'
    )
    AND l.frst_ctry_cd IN (
        'USA',
        'CAN',
        'MEX'
    )
    AND l.last_ctry_cd IN (
        'USA',
        'CAN',
        'MEX'
    )
    AND c.chrg_cd IS NOT NULL
    AND c.chrg_amt_dlr <> 0
	AND l.last_shpg_loc_cd NOT LIKE 'LCL%'
    AND l.ld_leg_id = '518334985'