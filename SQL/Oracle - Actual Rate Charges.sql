SELECT
    l.ld_leg_id,
    c.chrg_cd,
    f.frht_bill_num,
    v.frht_invc_id,
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
            'Act_Linehaul'
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
            'Act_Linehaul'
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
            'Act_Fuel'
        WHEN c.chrg_cd IN (
            'ZREP',
            'ZDHM'
        ) THEN
            'Act_Repo'
		WHEN c.chrg_cd IN (
            'ZUSB'
        ) THEN
            'Act_ZUSB'
        ELSE
            'Act_Accessorials'
    END AS chargetype,
    c.chrg_amt_dlr    AS chargeamount,
    c.pymnt_amt_dlr   AS paymentamount
FROM
    NAJDAADM.charge_detail_r   c,
    NAJDAADM.freight_bill_r    f,
    NAJDAADM.load_leg_r        l,
    NAJDAADM.voucher_ap_r      v
WHERE
    f.frht_bill_num = v.frht_bill_num
    AND f.frht_invc_id = v.frht_invc_id
    AND v.vchr_num = c.vchr_num_ap
    AND v.ld_leg_id = l.ld_leg_id
    AND l.cur_optlstat_id > 320
    AND EXTRACT(YEAR FROM
        CASE
            WHEN l.shpd_dtt IS NULL THEN
                l.strd_dtt
            ELSE
                l.shpd_dtt
        END
    ) >= EXTRACT(YEAR FROM SYSDATE)-1
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
    AND f.cur_stat_id IN (
        910,
        915,
        925,
        930
    )
    AND c.chrg_cd IS NOT NULL
	AND l.last_shpg_loc_cd NOT LIKE 'LCL%'
    AND l.LD_LEG_ID = '518334985'