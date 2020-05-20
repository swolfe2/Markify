

SELECT DISTINCT
    lldr.ld_leg_id,
    lldr.dlvy_stop_seq_num,
    llr.frst_shpg_loc_cd,
    llr.frst_shpg_loc_name,
    llr.frst_cty_name,
    llr.frst_sta_cd,
    llr.frst_pstl_cd,
    lldr.to_shpg_loc_cd,
    lldr.to_shpg_loc_name,
    lldr.to_cty_name,
    lldr.to_sta_cd,
    lldr.to_pstl_cd,
    llr.srvc_cd,
    llr.eqmt_typ,
    cm.base_appointment_datetime,
    cm.base_appt_reason,
    cm.final_appointment_datetime,
    cm.final_appt_reason,
    cm.arrived_at_datetime,
    cm.departed_datetime,
    llr.fixd_itnr_dist,
    cm.carr_rdy_dtt,
    cm.caps_late,
    cm.caps_reason,
    cm.adv_notif,
    cm.adv_reason_code,
    cm.confirm_delivery_datetime,
    cm.entry_date,
    cm.space_maker,
    cm.review_required,
    cm.reviewed_by,
    cm.reviewed_date,
    cm.scored_by,
    cm.updates_num,
    cm.corporate_id
FROM
nai2padm.load_leg_r             llr
JOIN load_leg_detail_r      lldr ON lldr.ld_leg_id = llr.ld_leg_id
JOIN abpp_otc_caps_master      cm ON cm.load_id = llr.ld_leg_id
                                    and lldr.dlvy_stop_seq_num = cm.stop_num

WHERE
 ( ( lldr.dlvy_stop_seq_num > 1 )
          AND ( substr(frst_shpg_loc_cd, 1, 1) IN (
        '2',
        'V'
    ) )
          AND ( llr.eqmt_typ IN (
        '48FT',
        '48TC',
        '53FT',
        '53TC',
        '53IM',
        '53HC',
        '53RT'
    ) )
          AND ( cm.review_required = 'N' ) )
ORDER BY
    lldr.ld_leg_id,
    lldr.dlvy_stop_seq_num