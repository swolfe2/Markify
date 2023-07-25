SELECT
    l.carr_cd,
    l.srvc_cd,
    l.shpd_dtt,
    l.strd_dtt,
    l.ld_leg_id,
    -- Base SQL only looks for shipments with 8*; why? Wouldn't the equipment type make more sense?
    sh.shpm_num,
    l.frst_shpg_loc_cd,
    l.frst_shpg_loc_name,
    l.frst_cty_name,
    l.frst_sta_cd,
    CASE
        WHEN frst_ctry_cd = 'CAN'
             OR frst_cty_name = 'ROMEOVILLE' THEN
            frst_pstl_cd
        ELSE
            substr(frst_pstl_cd, 1, 5)
    END origin_zip,
    CASE
        WHEN last_ctry_cd = 'CAN' THEN
            last_pstl_cd
        ELSE
            substr(last_pstl_cd, 1, 5)
    END dest_zip,
    l.frst_pstl_cd,
    l.frst_ctry_cd,
    l.last_shpg_loc_cd,
    l.last_shpg_loc_name,
    l.last_cty_name,
    l.last_sta_cd,
    l.last_pstl_cd,
    l.last_ctry_cd,
    l.eqmt_typ,
    l.fixd_itnr_dist,
    l.tot_tot_pce,
    l.tot_scld_wgt,
    l.tot_vol,
    l.actl_chgd_amt_dlr,
    la.corp1_id
FROM
    load_leg_r          l
    JOIN load_at_r           la ON l.frst_shpg_loc_cd = la.shpg_loc_cd
    JOIN load_leg_detail_r   lldr ON l.ld_leg_id = lldr.ld_leg_id
    LEFT JOIN shipment_r          sh ON sh.shpm_num = lldr.shpm_num
    JOIN address_r           ad ON l.frst_addr_id = ad.addr_id
    JOIN address_r           ad1 ON l.last_addr_id = ad1.addr_id
WHERE
    TO_CHAR(l.strd_dtt, 'YYYYMMDD') >= '20190101'
    AND TO_CHAR(l.shpd_dtt, 'YYYYMMDD') >= '20190101'
    AND l.cur_optlstat_id IN (
        320,
        325,
        335,
        345
    )
    AND l.eqmt_typ IN (
        'LTL'
    )
    AND l.last_ctry_cd IN (
        'USA',
        'CAN',
        'MEX'
    )