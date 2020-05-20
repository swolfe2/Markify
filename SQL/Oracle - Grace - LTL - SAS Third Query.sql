SELECT DISTINCT
    alrt.load_id            AS load_number,
    CASE
        WHEN alrt.bsn_units IS NULL THEN
            alrt.bsn_units
        ELSE
            alrt.bsn_units
    END AS bus_unit_id,
    alrt.bsn_unit_by_wgt    AS bus_unit_wgt,
    alrt.unit_desc_by_wgt   AS business_unit
FROM
    najdaadm.load_leg_r       llr
    JOIN najdatrn.abpp_ld_rfrc_t   alrt ON alrt.load_id = llr.ld_leg_id
WHERE
    ( ( llr.shpd_dtt >= current_date - 65 )
      AND ( llr.eqmt_typ IN (
        '48FT',
        '48TC',
        '53FT',
        '53TC',
        '53HC',
        '53IM',
        'LTL',
        '53RT',
        'PKG'
    ) )
      AND ( llr.frst_ctry_cd IN (
        'USA',
        'CAN',
        'MEX'
    ) )
      AND ( llr.last_ctry_cd IN (
        'USA',
        'CAN',
        'MEX'
    ) )
      AND ( alrt.bsn_unit_by_wgt IS NOT NULL ) )
ORDER BY
    alrt.load_id