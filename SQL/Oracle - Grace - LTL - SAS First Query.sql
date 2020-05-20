SELECT DISTINCT
    idld.schd_ship_dt       AS create_date,
    idld.act_ship_dt        AS actual_ship_date,
    idld.load_id            AS load_number,
    idld.schd_start_dt      AS sched_start_date,
    idld.load_src           AS load_src,
    idld.tot_chrg_grp_amt   AS prerate_inc_fuel,
    idl.record_type         AS orig_type,
    idl.dist_locs_id        AS orig_id,
    idl.dist_locs_nm        AS orig_name,
    idl.city_name           AS orig_city,
    idl.state_code          AS orig_st,
    idl.postal_code         AS orig_zip,
    idl.country_code        AS orig_ctry,
    idl.corp1_id            AS orig_corp_id,
    idl_1.record_type       AS dest_type,
    idl_1.dist_locs_id      AS dest_id,
    idl_1.dist_locs_nm      AS dest_name,
    idl_1.city_name         AS dest_city,
    idl_1.state_code        AS dest_st,
    idl_1.postal_code       AS dest_zip,
    idl_1.country_code      AS dest_ctry,
    idld.carr_chg_flg       AS carrier_chg_flag,
    idld.cost_chg_flg       AS cost_chg_flag,
    idld.cpst_chg_flg       AS comp_chg_flag,
    idld.optmzd_flg         AS opt_flag,
    idld.schdl_chg_flg      AS schd_chg_flag,
    idld.srvc_chg_flg       AS svc_chg_flag,
    idld.tdr_acc_flg        AS tdr_accept_flag,
    idld.tendered_flg       AS tdrd_flag,
    idld.cancelled_flg      AS cncld_flag,
    idc.carrier_id          AS carrier_id,
    idt.service_code        AS svc_code,
    ide.equipment_code      AS eq_code,
    idld.tot_stop_cnt       AS stops,
    iap.plan_desc           AS plan_desc,
    ias.status_code         AS status_code,
    aoca.team_group         AS team_group,
    aoca.team_name          AS team_name,
    aoca.team_leader_id     AS team_ldr_id,
    aoca.team_leader_name   AS team_ldr_name,
    aoca.analyst_id         AS analyst_id,
    aoca.analyst_name       AS analyst_name,
    current_date            AS data_last_refresh
FROM abpp.abpp_otc_caps_analyst   aoca
JOIN tmdw.ia_dist_locs            idl ON idl.dist_locs_id = aoca.location_id
JOIN tmdw.ia_dist_loads_dbm       idld ON idld.orig_loc_key = idl.dist_locs_key
JOIN tmdw.ia_dist_tffsrvc         idt ON idt.tff_srvc_key = idld.tff_srvc_key
JOIN tmdw.ia_dist_locs            idl_1 ON idl_1.dist_locs_key = idld.dest_loc_key
JOIN tmdw.ia_dist_eqpmt           ide ON ide.dist_eqpmt_key = idld.dist_eqpmt_key
JOIN tmdw.ia_plans                iap ON iap.plan_key = idld.plan_key
JOIN tmdw.ia_status               ias ON ias.status_key = idld.op_status_key
JOIN tmdw.ia_dist_carr            idc ON idc.carrier_key = idld.carrier_key
WHERE ( ( idld.schd_ship_dt >= current_date - 65
          AND idld.schd_ship_dt >= aoca.from_date
          AND idld.schd_ship_dt < ( aoca.TO_DATE + 1 ) )
        AND ( idld.cancelled_flg = 0 )
        AND ( idl.country_code IN ( 'USA',
                                    'CAN',
                                    'MEX' ) )
        AND ( ide.equipment_code IN ( '48FT',
                                      '48TC',
                                      '53FT',
                                      '53TC',
                                      '53IM',
                                      '53HC',
                                      '53RT',
                                      'LTL',
                                      'PKG' ) )
        AND ( idl.record_type = 'LA' )
        AND ( idld.load_src IN ( 'OPT',
                                 'MANUAL' ) )
        AND ( idl_1.country_code IN ( 'USA',
                                      'CAN',
                                      'MEX' ) )
        AND ( iap.plan_number IN ( '11',
                                   '12',
                                   '13',
                                   '16',
                                   '?' ) )
        AND ( ias.status_code NOT IN ( 'LL CANCELLED',
                                       'LL DELETE',
                                       'LL OPEN' ) )
        AND ( idl_1.dist_locs_id NOT LIKE 'LCL%' ) )
ORDER BY idl.dist_locs_id,
         idld.load_id