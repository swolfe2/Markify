SELECT DISTINCT
    load_leg_detail_r.ld_leg_id,
    load_leg_detail_r.dlvy_stop_seq_num,
    load_leg_r.frst_shpg_loc_cd,
    load_leg_r.frst_shpg_loc_name,
    load_leg_r.frst_cty_name,
    load_leg_r.frst_sta_cd,
    load_leg_r.frst_pstl_cd,
    load_leg_detail_r.to_shpg_loc_cd,
    load_leg_detail_r.to_shpg_loc_name,
    load_leg_detail_r.to_cty_name,
    load_leg_detail_r.to_sta_cd,
    load_leg_detail_r.to_pstl_cd,
    load_leg_r.srvc_cd,
    load_leg_r.eqmt_typ,
    abpp_otc_caps_master.base_appointment_datetime,
    abpp_otc_caps_master.base_appt_reason,
    abpp_otc_caps_master.final_appointment_datetime,
    abpp_otc_caps_master.final_appt_reason,
    abpp_otc_caps_master.arrived_at_datetime,
    abpp_otc_caps_master.departed_datetime,
    load_leg_r.fixd_itnr_dist,
    abpp_otc_caps_master.carr_rdy_dtt,
    abpp_otc_caps_master.caps_late,
    abpp_otc_caps_master.caps_reason,
    abpp_otc_caps_master.adv_notif,
    abpp_otc_caps_master.adv_reason_code,
    abpp_otc_caps_master.confirm_delivery_datetime,
    abpp_otc_caps_master.entry_date,
    abpp_otc_caps_master.space_maker,
    abpp_otc_caps_master.review_required,
    abpp_otc_caps_master.reviewed_by,
    abpp_otc_caps_master.reviewed_date,
    abpp_otc_caps_master.scored_by,
    abpp_otc_caps_master.updates_num,
    abpp_otc_caps_master.corporate_id
FROM
    nai2ptrn.abpp_otc_caps_master   abpp_otc_caps_master,
    nai2padm.load_leg_detail_r      load_leg_detail_r,
    nai2padm.load_leg_r             load_leg_r
WHERE
    load_leg_detail_r.ld_leg_id = load_leg_r.ld_leg_id
    AND load_leg_detail_r.ld_leg_id = abpp_otc_caps_master.load_id
    AND load_leg_detail_r.dlvy_stop_seq_num = abpp_otc_caps_master.stop_num
    AND ( ( abpp_otc_caps_master.final_appointment_datetime >= '01-JAN-19'
            AND abpp_otc_caps_master.final_appointment_datetime < '25-JUN-19' )
          AND ( load_leg_detail_r.dlvy_stop_seq_num > 1 )
          AND ( substr(frst_shpg_loc_cd, 1, 1) IN (
        '2',
        'V'
    ) )
          AND ( load_leg_r.eqmt_typ IN (
        '48FT',
        '48TC',
        '53FT',
        '53TC',
        '53IM',
        '53HC',
        '53RT'
    ) )
          AND ( load_leg_r.carr_cd = 'AHLY'
                OR load_leg_r.carr_cd = 'GATI'
                OR load_leg_r.carr_cd = 'MLXO'
                OR load_leg_r.carr_cd = 'MSLV'
                OR load_leg_r.carr_cd = 'THOM'
                OR load_leg_r.carr_cd = 'TKRK' )
          AND ( abpp_otc_caps_master.review_required = 'N' ) )
ORDER BY
    load_leg_detail_r.ld_leg_id,
    load_leg_detail_r.dlvy_stop_seq_num