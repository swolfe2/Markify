SELECT
    shipment_r.ld_leg_id,
    shipment_r.shpm_num,
    shipment_r.frm_pkup_dtt,
    shipment_r.to_pkup_dtt,
    shipment_r.frm_dlvy_dtt,
    shipment_r.to_dlvy_dtt,
    shipment_r.crtd_dtt,
    shipment_r.scld_wgt,
    shipment_r.vol,
    shipment_r.inpt_src_enu,
    shipment_r.frm_shpg_loc_cd,
    shipment_r.frm_name,
    shipment_r.frm_cty_name,
    shipment_r.frm_sta_cd,
    shipment_r.frm_pstl_cd,
    shipment_r.frm_ctry_cd,
    shipment_r.to_shpg_loc_cd,
    shipment_r.to_name,
    shipment_r.to_cty_name,
    shipment_r.to_sta_cd,
    shipment_r.to_pstl_cd,
    shipment_r.to_ctry_cd,
    shipment_r.plan_id,
    shipment_r.rfrc_num1,
    shipment_r.rfrc_num5,
    shipment_r.rfrc_num8,
    shipment_r.rfrc_num12,
    shipment_r.ovrd_frm_pkup_dtt,
    shipment_r.ovrd_to_pkup_dtt,
    shipment_r.ovrd_frm_dlvy_dtt,
    shipment_r.ovrd_to_dlvy_dtt
FROM
    nai2padm.shipment_r shipment_r
WHERE (TO_CHAR(shipment_r.crtd_dtt, 'YYYYMMDD') >= '20190101') 
AND (SHIPMENT_R.SHPM_NUM Like '8%') 
ORDER by shipment_r.shpm_num