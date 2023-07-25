SELECT DISTINCT
    t3.chrg_cd,
    t3.chrg_desc,
    t2.tff_id,
    t2.tff_cd,
    t2.tff_desc,
    t2.carr_cd,
    t3.srvc_cd,
    t2.tff_stat_enu,
    t3.chrg_cond_yn,
    t2.expd_dt,
    SYSDATE,
    t4.shpg_loc_cd,
    t5.name,
    t6.cty_name,
    t6.sta_cd,
    CASE
        WHEN t6.ctry_cd = 'USA' THEN
            substr(t6.pstl_cd, 1, 5)
        ELSE
            t6.pstl_cd
    END AS pstl5,
    'Load At' AS type,
    t7.extl_cd1 as extl_cd1,
    t7.extl_cd2 as extl_cd2
FROM
    najdaadm.carrier_r               t1
    JOIN najdaadm.tariff_r                t2 ON t2.carr_cd = t1.carr_cd
    JOIN najdaadm.tariff_charge_r         t3 ON t3.tff_id = t2.tff_id
    JOIN najdaadm.auto_applied_option_r   t4 ON t4.chrg_cd = t3.chrg_cd
    JOIN najdaadm.load_at_r               t5 ON t5.shpg_loc_cd = t4.shpg_loc_cd
    JOIN najdaadm.address_r               t6 ON t6.addr_id = t5.addr_id
    JOIN najdaadm.master_charges_r        t7 ON t7.chrg_cd = t3.chrg_cd 
WHERE
    ( ( t3.chrg_cond_yn = 'N' )
      AND ( t2.tff_stat_enu = 'Active' )
      AND ( t3.srvc_cd NOT IN (
        'OPEN',
        'ZAR',
        'ZARL',
        'UYSN',
        'ASFH',
        'BEDF',
        'CNWY',
        'FXFE',
        'FXNL',
        'ODFL',
        'RETL',
        'UPGF',
        'VITY'
    ) )
      AND ( t2.expd_dt >= SYSDATE )
      AND ( substr(t3.chrg_cd, 1, 1) >= 'A'
            AND substr(t3.chrg_cd, 1, 1) <= 'W' )
      AND t3.chrg_cd NOT IN (
        'USPS',
        'SDSD',
        'HAZM'
    )
      AND t6.ctry_cd IN (
        'USA',
        'CAN',
        'MEX'
    )
      AND t6.sta_cd NOT IN (
        '00'
    )
      AND ( t1.carr_typ = 'Road' )
      AND t4.aply_frm_ap_enu = 'Apply When Routing and Rating' )
UNION ALL
SELECT DISTINCT
    t3.chrg_cd,
    t3.chrg_desc,
    t2.tff_id,
    t2.tff_cd,
    t2.tff_desc,
    t2.carr_cd,
    t3.srvc_cd,
    t2.tff_stat_enu,
    t3.chrg_cond_yn,
    t2.expd_dt,
    SYSDATE,
    t4.shpg_loc_cd,
    t5.name,
    t6.cty_name,
    t6.sta_cd,
    CASE
        WHEN t6.ctry_cd = 'USA' THEN
            substr(t6.pstl_cd, 1, 5)
        ELSE
            t6.pstl_cd
    END AS pstl5,
    'Distribution Center' AS type,
    t7.extl_cd1 as extl_cd1,
    t7.extl_cd2 as extl_cd2
FROM
    najdaadm.carrier_r               t1
    JOIN najdaadm.tariff_r                t2 ON t2.carr_cd = t1.carr_cd
    JOIN najdaadm.tariff_charge_r         t3 ON t3.tff_id = t2.tff_id
    JOIN najdaadm.auto_applied_option_r   t4 ON t4.chrg_cd = t3.chrg_cd
    JOIN najdaadm.distribution_center_r   t5 ON t5.shpg_loc_cd = t4.dc_shpg_loc_cd
    JOIN najdaadm.address_r               t6 ON t6.addr_id = t5.addr_id
    JOIN najdaadm.master_charges_r        t7 ON t7.chrg_cd = t3.chrg_cd 
WHERE
    ( ( t3.chrg_cond_yn = 'N' )
      AND ( t2.tff_stat_enu = 'Active' )
      AND ( t3.srvc_cd NOT IN (
        'OPEN',
        'ZAR',
        'ZARL',
        'UYSN',
        'ASFH',
        'BEDF',
        'CNWY',
        'FXFE',
        'FXNL',
        'ODFL',
        'RETL',
        'UPGF',
        'VITY'
    ) )
      AND ( t2.expd_dt >= SYSDATE )
      AND ( substr(t3.chrg_cd, 1, 1) >= 'A'
            AND substr(t3.chrg_cd, 1, 1) <= 'W' )
      AND t3.chrg_cd NOT IN (
        'USPS',
        'SDSD',
        'HAZM'
    )
      AND t6.ctry_cd IN (
        'USA',
        'CAN',
        'MEX'
    )
      AND t6.sta_cd NOT IN (
        '00'
    )
      AND ( t1.carr_typ = 'Road' )
      AND t4.aply_frm_ap_enu = 'Apply When Routing and Rating' )
ORDER BY
    chrg_cd,
    srvc_cd