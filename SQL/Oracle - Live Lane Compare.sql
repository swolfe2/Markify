SELECT
    llr.ld_leg_id,
    TO_CHAR(strd_dtt, 'MM/DD/YYYY') AS pickup_date,
    TO_CHAR(next_day(strd_dtt, 'MONDAY') - 7, 'MM/DD/YYYY') AS week_start_date,
    latr.origin_zone_id,
    latr.destination_zone_id,
    CASE
        WHEN latr.origin_zone_id IS NOT NULL THEN
            concat(concat(latr.origin_zone_id, '-'), latr.destination_zone_id)
    END AS awardlane,
    /* 6/4/2019 - Had to remove because latr is causing duplicate records
    CASE
        WHEN latr.origin_id IS NOT NULL THEN
            latr.linehaul_rate_per_mile
    END AS awd_rpm,
    */
    CASE
        WHEN llr.eqmt_typ = '53IM' THEN
            'INTERMODAL'
        ELSE
            'TRUCK'
    END AS shipmode,
    CASE
        WHEN lar.corp1_id = 'RM'                    THEN
            'RM-INBOUND'
        WHEN lar.corp1_id = 'RF'                    THEN
            'RF-INBOUND'
        WHEN substr(llr.last_shpg_loc_cd, 1, 1) = 'R' THEN
            'RETURNS'
        WHEN substr(llr.last_shpg_loc_cd, 1, 1) = '1' THEN
            'INTERMILL'
        WHEN substr(llr.last_shpg_loc_cd, 1, 1) = '2' THEN
            'INTERMILL'
        ELSE
            'CUSTOMER'
    END AS order_type,
    CASE
        WHEN lar.corp1_id = 'RM'                    THEN
            'INBOUND'
        WHEN lar.corp1_id = 'RF'                    THEN
            'INBOUND'
        WHEN substr(llr.last_shpg_loc_cd, 1, 1) = 'R' THEN
            'INBOUND'
        ELSE
            'OUTBOUND'
    END AS inbound_outbound,
    CASE
        WHEN MAX(
            CASE
                WHEN latr.origin_id IS NULL THEN
                    0
                ELSE
                    1
            END
        ) = 0 THEN
            'Not Award Lane'
        ELSE
            'Award Lane'
    END AS awardlanestring,
    MAX(
        CASE
            WHEN latr.origin_id IS NULL THEN
                0
            ELSE
                1
        END
    ) AS awardlanemarker,
    CASE
        WHEN MAX(
            CASE
                WHEN lasa.tariff_service IS NULL THEN
                    0
                ELSE
                    1
            END
        ) = 0 THEN
            'Not Award Carrier'
        ELSE
            'Award Carrier'
    END AS awardcarrierstring,
    MAX(
        CASE
            WHEN lasa.tariff_service IS NULL THEN
                0
            ELSE
                1
        END
    ) AS awardcarriermarker,
    llr.carr_cd,
    llr.srvc_cd,
    CASE
        WHEN llr.srvc_cd = 'OPEN' THEN
            llr.carr_cd
        ELSE
            llr.srvc_cd
    END AS carrier,
    carr.name,
    llr.eqmt_typ,
    e.eqmt_typ_desc,
    llr.last_shpg_loc_name,
    llr.cur_optlstat_id     AS status_code,
    s.stat_shrt_desc        AS status_code_table,
    llr.frst_cty_name,
    llr.frst_sta_cd,
    llr.frst_shpg_loc_cd,
    llr.frst_sta_cd
    || replace(llr.frst_cty_name, ' ', '') AS originstcity,
    llr.last_cty_name,
    llr.last_sta_cd,
    llr.last_shpg_loc_cd,
    CASE
        WHEN llr.last_ctry_cd = 'USA' THEN
            '5'
            || llr.last_sta_cd
            || substr(llr.last_pstl_cd, 1, 5)
        ELSE
            llr.last_sta_cd
            || replace(llr.last_cty_name, ' ', '')
    END AS deststcity,
    CASE
        WHEN llr.last_ctry_cd = 'USA' THEN
            substr(llr.last_pstl_cd, 1, 5)
        ELSE
            replace(llr.last_cty_name, ' ', '')
    END AS destst5zip,
    CASE
        WHEN llr.last_ctry_cd = 'USA' THEN
            substr(llr.last_pstl_cd, 1, 3)
        ELSE
            replace(llr.last_cty_name, ' ', '')
    END AS destst3zip,
    a.team_name             AS teamname,
    a.team_group            AS teamgroup,
    llr.actl_chgd_amt_dlr   AS linehaul
FROM
    load_leg_r               llr
    JOIN abpp_otc_caps_analyst    a ON llr.frst_shpg_loc_cd = a.location_id
    JOIN status_r                 s ON llr.cur_optlstat_id = s.stat_id
    JOIN eqmt_typ_t               e ON llr.eqmt_typ = e.eqmt_typ_cd
    JOIN load_at_r                lar ON llr.frst_shpg_loc_cd = lar.shpg_loc_cd
    LEFT OUTER JOIN abpp_laneserviceawards   lasa ON lasa.origin_id = llr.frst_shpg_loc_cd
                                                   AND lasa.destination_id = llr.last_shpg_loc_cd
                                                   AND lasa.tariff_service = llr.srvc_cd
                                                   AND llr.strd_dtt BETWEEN lasa.from_date AND lasa.TO_DATE
    LEFT OUTER JOIN abpp_laneawards_tl_r     latr ON latr.origin_id = llr.frst_shpg_loc_cd
                                                 AND latr.destination_id = llr.last_shpg_loc_cd
                                                 AND llr.strd_dtt BETWEEN latr.from_date AND latr.TO_DATE
    LEFT OUTER JOIN carrier_r                carr ON
        CASE
            WHEN llr.srvc_cd = 'OPEN' THEN
                llr.carr_cd
            ELSE
                llr.srvc_cd
        END
    = carr.carr_cd
WHERE
    llr.last_ctry_cd IN (
        'USA',
        'MEX',
        'CAN'
    )
    AND llr.strd_dtt > SYSDATE - 2
    AND llr.strd_dtt < SYSDATE + 14
    AND a.TO_DATE > SYSDATE
    AND ( substr(eqmt_typ, 1, 2) = '48'
          OR substr(eqmt_typ, 1, 2) = '53' )
GROUP BY
    llr.ld_leg_id,
    TO_CHAR(strd_dtt, 'MM/DD/YYYY'),
    TO_CHAR(next_day(strd_dtt, 'MONDAY') - 7, 'MM/DD/YYYY'),
    latr.origin_zone_id,
    latr.destination_zone_id,
    CASE
            WHEN latr.origin_zone_id IS NOT NULL THEN
                concat(concat(latr.origin_zone_id, '-'), latr.destination_zone_id)
        END,
    CASE
            WHEN llr.eqmt_typ = '53IM' THEN
                'INTERMODAL'
            ELSE
                'TRUCK'
        END,
    CASE
            WHEN lar.corp1_id = 'RM'                    THEN
                'RM-INBOUND'
            WHEN lar.corp1_id = 'RF'                    THEN
                'RF-INBOUND'
            WHEN substr(llr.last_shpg_loc_cd, 1, 1) = 'R' THEN
                'RETURNS'
            WHEN substr(llr.last_shpg_loc_cd, 1, 1) = '1' THEN
                'INTERMILL'
            WHEN substr(llr.last_shpg_loc_cd, 1, 1) = '2' THEN
                'INTERMILL'
            ELSE
                'CUSTOMER'
        END,
    CASE
            WHEN lar.corp1_id = 'RM'                    THEN
                'INBOUND'
            WHEN lar.corp1_id = 'RF'                    THEN
                'INBOUND'
            WHEN substr(llr.last_shpg_loc_cd, 1, 1) = 'R' THEN
                'INBOUND'
            ELSE
                'OUTBOUND'
        END,
    llr.carr_cd,
    llr.srvc_cd,
    CASE
            WHEN llr.srvc_cd = 'OPEN' THEN
                llr.carr_cd
            ELSE
                llr.srvc_cd
        END,
    carr.name,
    llr.eqmt_typ,
    e.eqmt_typ_desc,
    llr.last_shpg_loc_name,
    llr.cur_optlstat_id,
    s.stat_shrt_desc,
    llr.frst_cty_name,
    llr.frst_sta_cd,
    llr.frst_shpg_loc_cd,
    llr.frst_sta_cd
    || replace(llr.frst_cty_name, ' ', ''),
    llr.last_cty_name,
    llr.last_sta_cd,
    llr.last_shpg_loc_cd,
    CASE
            WHEN llr.last_ctry_cd = 'USA' THEN
                '5'
                || llr.last_sta_cd
                || substr(llr.last_pstl_cd, 1, 5)
            ELSE
                llr.last_sta_cd
                || replace(llr.last_cty_name, ' ', '')
        END,
    CASE
            WHEN llr.last_ctry_cd = 'USA' THEN
                substr(llr.last_pstl_cd, 1, 5)
            ELSE
                replace(llr.last_cty_name, ' ', '')
        END,
    CASE
            WHEN llr.last_ctry_cd = 'USA' THEN
                substr(llr.last_pstl_cd, 1, 3)
            ELSE
                replace(llr.last_cty_name, ' ', '')
        END,
    a.team_name,
    a.team_group,
    llr.actl_chgd_amt_dlr
ORDER BY
    pickup_date,
    status_code,
    originstcity,
    last_sta_cd,
    last_cty_name ASC