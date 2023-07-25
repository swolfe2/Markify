SELECT DISTINCT
    idlo.load_id            AS load_number,
    idl.dist_locs_id        AS opt_origin_id,
    idlo.load_src           AS opt_load_src,
    ias.status_code         AS opt_status_code,
    idc.carrier_id          AS opt_carrier_id,
    idt.service_code        AS opt_svc_code,
    ide.equipment_code      AS opt_eqp_code,
    iap.plan_desc           AS opt_plan_desc,
    idlo.optm_plan_id       AS opt_plan_id,
    idlo.tot_chrg_grp_amt   AS opt_prerate_inc_fuel,
    idlo.event_log_dt       AS opt_event_log_date
FROM
    tmdw.ia_dist_carr        idc
    JOIN tmdw.ia_dist_loads       idlo ON idlo.carrier_key = idc.carrier_key
    JOIN tmdw.ia_dist_tffsrvc     idt ON idt.tff_srvc_key = idlo.tff_srvc_key
    JOIN tmdw.ia_dist_eqpmt       ide ON ide.dist_eqpmt_key = idlo.dist_eqpmt_key
    JOIN tmdw.ia_plans            iap ON iap.plan_key = idlo.plan_key
    JOIN tmdw.ia_status           ias ON ias.status_key = idlo.op_status_key
    JOIN tmdw.ia_dist_locs        idl ON idl.dist_locs_key = idlo.orig_loc_key
    JOIN tmdw.ia_exception_code   iec ON iec.excpt_code_key = idlo.excpt_code_key
WHERE
    ( ( idlo.event_log_dt >= current_date - 65 )
      AND ( idl.record_type = 'LA' )
      AND ( ias.status_code = 'LL OPEN' )
      AND ( idlo.tot_chrg_grp_amt > 0 )
      AND ( iap.plan_number IN (
        '11',
        '12',
        '13',
        '16',
        '?'
    ) )
      AND ( iec.exception_code LIKE '%\_%' ESCAPE '\' )
      AND ( idlo.load_src IN (
        'OPT',
        'MANUAL'
    ) )
      AND ( idlo.load_id <> 514094044 )
      AND ( ide.equipment_code IN (
        '48FT',
        '48TC',
        '53FT',
        '53TC',
        '53IM',
        '53HC',
        '53RT',
        'LTL',
        'PKG'
    ) ) )
ORDER BY
    idlo.load_id,
    idlo.event_log_dt