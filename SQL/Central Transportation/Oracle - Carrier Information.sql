SELECT DISTINCT
    l.carr_cd,
    c.name,
    l.srvc_cd,
    mst.srvc_desc,
    CASE WHEN EQMT_TYP = '53IM' THEN 'INTERMODAL' ELSE 'TRUCK' END ShipMode,
    CASE WHEN l.carr_cd IN (
    'CLLQ',
    'ECHD',
    'HHWY',
    'KNBK',
    'NFBR',
    'RBCL',
    'RCXV',
    'SNLE',
    'SWOA',
    'UFLB',
    'WVAS'
    ) THEN 'Y' END AS Broker,
    COUNT(DISTINCT l.ld_leg_id) ShipmentCount,
    max(l.shpd_dtt) MaxShipDate
FROM
    najdaadm.load_leg_r    l
    INNER JOIN najdaadm.load_at_r     la ON l.frst_shpg_loc_cd = la.shpg_loc_cd
    INNER JOIN najdaadm.status_r      s ON l.cur_optlstat_id = s.stat_id
    INNER JOIN najdaadm.carrier_r     c ON l.carr_cd = c.carr_cd
    LEFT JOIN najdaadm.mstr_srvc_t   mst ON l.srvc_cd = mst.srvc_cd
WHERE
    EXTRACT(YEAR FROM
        CASE
            WHEN l.shpd_dtt IS NULL THEN
                l.strd_dtt
            ELSE
                l.shpd_dtt
        END
    ) >= EXTRACT(YEAR FROM SYSDATE)
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
        '53HC'
    )
    AND l.last_ctry_cd IN (
        'USA',
        'CAN',
        'MEX'
    ) group by l.carr_cd, c.name, l.srvc_cd, mst.srvc_desc, 
CASE WHEN EQMT_TYP = '53IM' THEN 'INTERMODAL' ELSE 'TRUCK' END, CASE WHEN l.carr_cd IN ( 'CLLQ', 'ECHD', 'HHWY', 'KNBK', 'NFBR', 'RBCL', 'RCXV', 'SNLE', 'SWOA', 'UFLB', 'WVAS' ) THEN 'Y' END 

ORDER BY
    carr_cd ASC,
    srvc_cd ASC