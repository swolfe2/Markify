WITH
/********************************************************************************************************************
/* WEIGHTED AVERAGE AWARD LANE DETAIL - ADDED BY STEVE WOLFE - 5/31/2019
/********************************************************************************************************************/ award_weighted_averages AS (
   
    SELECT
    /*
        origin_id,
        destination_id,
        equip_type,
        MAX(from_date) AS from_date,
        MAX(TO_DATE) AS TO_DATE,
        SUM(award_pctof_lane) AS awd_pct,
        origin_zone_id,
        destination_zone_id,
        SUM(weekly_lane_volume) AS awd_vol,
        TO_CHAR(SUM(award_pctof_lane * linehaul_rate_per_mile) / SUM(award_pctof_lane), '$9,999.00') AS awd_weight_rpm,
        ( trunc(SYSDATE) - MAX(trunc(from_date)) ) AS days_active
    FROM
        abpp_laneserviceawards
    WHERE
        award_pctof_lane > 0
        AND linehaul_rate_per_mile > 0
    GROUP BY
        origin_id,
        destination_id,
        equip_type,
        from_date,
        TO_DATE,
        origin_zone_id,
        destination_zone_id
    ORDER BY
        origin_id,
        destination_id,
        equip_type,
        from_date,
        TO_DATE,
        origin_zone_id,
        destination_zone_id
        */
    origin_id,
    destination_id,
    equip_type,
    MIN(from_date) AS from_date,
    MAX(TO_DATE) AS TO_DATE,
    CEIL(AVG(award_pctof_lane)) AS awd_pct,
    CEIL(AVG(weekly_lane_volume)) AS awd_vol,
    TO_CHAR(SUM(award_pctof_lane * linehaul_rate_per_mile) / SUM(award_pctof_lane), '$9,999.00') AS awd_weight_rpm,
    ( trunc(SYSDATE) - MIN(trunc(from_date)) ) AS days_active
FROM
    abpp_laneserviceawards
WHERE
    award_pctof_lane > 0
    AND linehaul_rate_per_mile > 0
    /*
    AND origin_id = '2320-SL01'
    AND destination_id = '5800731062382456'
    */
    AND EQUIP_TYPE = '53FT'
GROUP BY
    origin_id,
    destination_id,
    equip_type
ORDER BY
    origin_id,
    destination_id,
    equip_type
        
        
),

/********************************************************************************************************************
/* WEIGHTED AVERAGE AWARD LANE DETAIL - ADDED BY STEVE WOLFE - 5/31/2019
/********************************************************************************************************************/ charges AS (
    SELECT
        l.ld_leg_id,
-- Need to average to count for duplication
        AVG(l.mile_dist) AS miles,
    /* Commenting out: Can add back in if you need to see individual buckets.
    SUM(
        CASE
            WHEN c.chrg_cd IN(
                'ADLH', 'CATX', 'CONT', 'CUBE', 'CWF1', 'CWF2', 'CWF3', 'CWF4', 'CWT', 'CWTF', 'CWTM', 'DISC', 'DIST', 'DT2', 'FBED'
                , 'FLAT', 'GRI', 'ISPT', 'LMIN', 'LTLD', 'MILE', 'OCFR', 'OCN1', 'PKG1', 'SPOT', 'TC', 'TCM', 'UPD', 'WGT', 'ZNFD'
                , 'ZWND', 'ZJBH', 'ZSPT'
            ) THEN
                c.chrg_amt_dlr
            ELSE
                .00
        END
    ) AS prerate_linehaul,
    SUM(
        CASE
            WHEN c.chrg_cd IN(
                'BAF', 'DFSC', 'FS01', 'FS02', 'FS03', 'FS04', 'FS05', 'FS06', 'FS07', 'FS08', 'FS09', 'FS10', 'FS11', 'FS12', 'FS13'
                , 'FS14', 'FS15', 'FSCA', 'PFSC', 'RFSC', 'WCFS'
            ) THEN
                c.chrg_amt_dlr
            ELSE
                .00
        END
    ) AS prerate_fuel,
    SUM(
        CASE
            WHEN c.chrg_cd NOT IN(
                'ADLH', 'CATX', 'CONT', 'CUBE', 'CWF1', 'CWF2', 'CWF3', 'CWF4', 'CWT', 'CWTF', 'CWTM', 'DISC', 'DIST', 'DT2', 'FBED'
                , 'FLAT', 'GRI', 'ISPT', 'LMIN', 'LTLD', 'MILE', 'OCFR', 'OCN1', 'PKG1', 'SPOT', 'TC', 'TCM', 'UPD', 'WGT', 'ZNFD'
                , 'ZWND', 'ZJBH', 'ZSPT', 'BAF', 'DFSC', 'FS01', 'FS02', 'FS03', 'FS04', 'FS05', 'FS06', 'FS07', 'FS08', 'FS09', 'FS10'
                , 'FS11', 'FS12', 'FS13', 'FS14', 'FS15', 'FSCA', 'PFSC', 'RFSC', 'WCFS'
            ) THEN
                c.chrg_amt_dlr
            ELSE
                .00
        END
    ) AS prerate_accessorials,
    SUM(
        CASE
            WHEN c.chrg_cd IN(
                'ADLH', 'CATX', 'CONT', 'CUBE', 'CWF1', 'CWF2', 'CWF3', 'CWF4', 'CWT', 'CWTF', 'CWTM', 'DISC', 'DIST', 'DT2', 'FBED'
                , 'FLAT', 'GRI', 'ISPT', 'LMIN', 'LTLD', 'MILE', 'OCFR', 'OCN1', 'PKG1', 'SPOT', 'TC', 'TCM', 'UPD', 'WGT', 'ZNFD'
                , 'ZWND', 'ZJBH', 'ZSPT'
            ) THEN
                c.pymnt_amt_dlr
            ELSE
                .00
        END
    ) AS act_linehaul,
    SUM(
        CASE
            WHEN c.chrg_cd IN(
                'BAF', 'DFSC', 'FS01', 'FS02', 'FS03', 'FS04', 'FS05', 'FS06', 'FS07', 'FS08', 'FS09', 'FS10', 'FS11', 'FS12', 'FS13'
                , 'FS14', 'FS15', 'FSCA', 'PFSC', 'RFSC', 'WCFS'
            ) THEN
                c.pymnt_amt_dlr
            ELSE
                .00
        END
    ) AS act_fuel,
    SUM(
        CASE
            WHEN c.chrg_cd NOT IN(
                'ADLH', 'CATX', 'CONT', 'CUBE', 'CWF1', 'CWF2', 'CWF3', 'CWF4', 'CWT', 'CWTF', 'CWTM', 'DISC', 'DIST', 'DT2', 'FBED'
                , 'FLAT', 'GRI', 'ISPT', 'LMIN', 'LTLD', 'MILE', 'OCFR', 'OCN1', 'PKG1', 'SPOT', 'TC', 'TCM', 'UPD', 'WGT', 'ZNFD'
                , 'ZWND', 'ZJBH', 'ZSPT', 'BAF', 'DFSC', 'FS01', 'FS02', 'FS03', 'FS04', 'FS05', 'FS06', 'FS07', 'FS08', 'FS09', 'FS10'
                , 'FS11', 'FS12', 'FS13', 'FS14', 'FS15', 'FSCA', 'PFSC', 'RFSC', 'WCFS'
            ) THEN
                c.pymnt_amt_dlr
            ELSE
                .00
        END
    ) AS act_accessorials,
    SUM(c.chrg_amt_dlr) AS chargeamt,
    SUM(c.pymnt_amt_dlr) AS paymentamt,
*/
        CASE
            WHEN v.ld_leg_id IS NOT NULL
                 AND f.cur_stat_id IN (
                910,
                915,
                925,
                930
            ) THEN
                'Actuals'
            ELSE
                'PreRate'
        END AS paymenttype,
        TO_CHAR(SUM(
            CASE
                WHEN c.chrg_cd IN(
                    'ADLH', 'CATX', 'CONT', 'CUBE', 'CWF1', 'CWF2', 'CWF3', 'CWF4', 'CWT', 'CWTF', 'CWTM', 'DISC', 'DIST', 'DT2',
                    'FBED', 'FLAT', 'GRI', 'ISPT', 'LMIN', 'LTLD', 'MILE', 'OCFR', 'OCN1', 'PKG1', 'SPOT', 'TC', 'TCM', 'UPD', 'WGT'
                    , 'ZNFD', 'ZWND', 'ZJBH', 'ZSPT'
                ) THEN
                    (
                        CASE
                            WHEN v.ld_leg_id IS NOT NULL
                                 AND f.cur_stat_id IN(
                                910, 915, 925, 930
                            ) THEN
                                c.pymnt_amt_dlr
                            ELSE
                                c.chrg_amt_dlr
                        END
                    )
                ELSE
                    .00
            END
        ), '$9,999.00') AS linehaul,
        TO_CHAR(SUM(
            CASE
                WHEN c.chrg_cd IN(
                    'BAF', 'DFSC', 'FS01', 'FS02', 'FS03', 'FS04', 'FS05', 'FS06', 'FS07', 'FS08', 'FS09', 'FS10', 'FS11', 'FS12'
                    , 'FS13', 'FS14', 'FS15', 'FSCA', 'PFSC', 'RFSC', 'WCFS'
                ) THEN
                    (
                        CASE
                            WHEN v.ld_leg_id IS NOT NULL
                                 AND f.cur_stat_id IN(
                                910, 915, 925, 930
                            ) THEN
                                c.pymnt_amt_dlr
                            ELSE
                                c.chrg_amt_dlr
                        END
                    )
                ELSE
                    .00
            END
        ), '$9,999.00') AS fuel,
        TO_CHAR(SUM(
            CASE
                WHEN c.chrg_cd NOT IN(
                    'ADLH', 'CATX', 'CONT', 'CUBE', 'CWF1', 'CWF2', 'CWF3', 'CWF4', 'CWT', 'CWTF', 'CWTM', 'DISC', 'DIST', 'DT2',
                    'FBED', 'FLAT', 'GRI', 'ISPT', 'LMIN', 'LTLD', 'MILE', 'OCFR', 'OCN1', 'PKG1', 'SPOT', 'TC', 'TCM', 'UPD', 'WGT'
                    , 'ZNFD', 'ZWND', 'ZJBH', 'ZSPT', 'BAF', 'DFSC', 'FS01', 'FS02', 'FS03', 'FS04', 'FS05', 'FS06', 'FS07', 'FS08'
                    , 'FS09', 'FS10', 'FS11', 'FS12', 'FS13', 'FS14', 'FS15', 'FSCA', 'PFSC', 'RFSC', 'WCFS'
                ) THEN
                    (
                        CASE
                            WHEN v.ld_leg_id IS NOT NULL
                                 AND f.cur_stat_id IN(
                                910, 915, 925, 930
                            ) THEN
                                c.pymnt_amt_dlr
                            ELSE
                                c.chrg_amt_dlr
                        END
                    )
                ELSE
                    .00
            END
        ), '$9,999.00') AS accessorials,
        TO_CHAR(SUM(
            CASE
                WHEN c.chrg_cd IN(
                    'ADLH', 'CATX', 'CONT', 'CUBE', 'CWF1', 'CWF2', 'CWF3', 'CWF4', 'CWT', 'CWTF', 'CWTM', 'DISC', 'DIST', 'DT2',
                    'FBED', 'FLAT', 'GRI', 'ISPT', 'LMIN', 'LTLD', 'MILE', 'OCFR', 'OCN1', 'PKG1', 'SPOT', 'TC', 'TCM', 'UPD', 'WGT'
                    , 'ZNFD', 'ZWND', 'ZJBH', 'ZSPT'
                ) THEN
                    (
                        CASE
                            WHEN v.ld_leg_id IS NOT NULL
                                 AND f.cur_stat_id IN(
                                910, 915, 925, 930
                            ) THEN
                                c.pymnt_amt_dlr
                            ELSE
                                c.chrg_amt_dlr
                        END
                    )
                ELSE
                    .00
            END
        ) / AVG(
            CASE
                WHEN l.mile_dist > 0 THEN
                    l.mile_dist
                ELSE
            -- Use 1 if no Miles are loaded. Note: Unsure why it would have 0 miles.
                    1
            END
        ), '$9,999.00') AS linehaulrpm,
        TO_CHAR(SUM(
            CASE
                WHEN v.ld_leg_id IS NOT NULL
                     AND f.cur_stat_id IN(
                    910, 915, 925, 930
                ) THEN
                    c.pymnt_amt_dlr
                ELSE
                    c.chrg_amt_dlr
            END
        ) / AVG(
            CASE
                WHEN l.mile_dist > 0 THEN
                    l.mile_dist
                ELSE
            -- Use 1 if no Miles are loaded. Note: Unsure why it would have 0 miles.
                    1
            END
        ), '$9,999.00') AS fullrpm
    FROM
        load_leg_r        l
        JOIN charge_detail_r   c ON l.ld_leg_id = c.ld_leg_id
        LEFT JOIN voucher_ap_r      v ON l.ld_leg_id = v.ld_leg_id
                                    AND c.vchr_num_ap = v.vchr_num
        JOIN freight_bill_r    f ON v.frht_bill_num = f.frht_bill_num
                                 AND v.frht_invc_id = f.frht_invc_id
    WHERE
        ( TO_CHAR(l.strd_dtt, 'YYYYMMDD') >= '20190101'
          OR l.strd_dtt IS NULL )
        AND TO_CHAR(l.shpd_dtt, 'YYYYMMDD') >= '20190101'
        AND l.cur_optlstat_id BETWEEN 315 AND 350
        AND l.eqmt_typ IN (
            '48FT',
            '48TC',
            '53FT',
            '53TC',
            '53IM',
            '53RT',
            '53HC'
        )
        AND l.srvc_cd NOT IN (
            'OPAF',
            'OPEC',
            'OPEX',
            'OPKG'
        )
        AND l.frst_ctry_cd IN (
            'USA',
            'CAN',
            'MEX'
        )
        AND l.last_ctry_cd IN (
            'USA',
            'CAN',
            'MEX'
        )
        AND c.chrg_cd IS NOT NULL
        AND c.chrg_amt_dlr <> 0
    GROUP BY
        l.ld_leg_id,
        CASE
                WHEN v.ld_leg_id IS NOT NULL
                     AND f.cur_stat_id IN (
                    910,
                    915,
                    925,
                    930
                ) THEN
                    'Actuals'
                ELSE
                    'PreRate'
            END
    ORDER BY
        l.ld_leg_id

/*
517390524 – Tendered
517365168 – Tender Accepted
517385823 - Confirming
517332570 – Intransit – Voucher Pending
517283377 – Intransit – Voucher Created
517315875 – Intransit – Voucher Matched
517315291 – Completed – Voucher Pending
517317206 – Completed – Voucher Created
517235591 – Completed – Voucher Matched – Frt bill P794930 – Status – Accounts Payable
517307745 – Completed – Voucher Matched - Frt bill 7000290654 – Status - Approved
517274509 – Completed – Voucher Matched - Frt bill 32000291 – Status - Unapproved
*/
),

/********************************************************************************************************************
/* MANUAL CUSTOMER GROUPINGS
/********************************************************************************************************************/ customer_groupings AS (
    SELECT
        'HIERARCHY' AS hierarchy,
        'CUSTOMER' AS customer,
        'PRIORITY' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        '58007310' AS hierarchy,
        'AMAZON' AS customer,
        'TIER 1' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        '58064480' AS hierarchy,
        'AMAZON' AS customer,
        'TIER 1' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        '58059586' AS hierarchy,
        'AMAZON' AS customer,
        'TIER 1' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        '58006486' AS hierarchy,
        'AWG' AS customer,
        '' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        '58006496' AS hierarchy,
        'AWG' AS customer,
        '' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        '58008423' AS hierarchy,
        'BIG LOTS' AS customer,
        '' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        '58006900' AS hierarchy,
        'BJS WHOLESALE' AS customer,
        '' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        '58006151' AS hierarchy,
        'BOZZUTOS' AS customer,
        '' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        '58015287' AS hierarchy,
        'BRADY INDUSTRIES' AS customer,
        '' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        '58013906' AS hierarchy,
        'BUNZL' AS customer,
        'TIER 1' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        '58019996' AS hierarchy,
        'BUNZL' AS customer,
        'TIER 1' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        '58006032' AS hierarchy,
        'C AND S' AS customer,
        '' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        '58004966' AS hierarchy,
        'COSTCO' AS customer,
        'TIER 1' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        '58003496' AS hierarchy,
        'CVS' AS customer,
        '' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        '58007089' AS hierarchy,
        'DOLLAR GENERAL' AS customer,
        'TIER 1' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        '58062902' AS hierarchy,
        'ESSENDANT' AS customer,
        'TIER 1' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        '58007093' AS hierarchy,
        'FAMILY DOLLAR' AS customer,
        '' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        '58013436' AS hierarchy,
        'GENERAL KCP' AS customer,
        '' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        '58006193' AS hierarchy,
        'GIANT EAGLE' AS customer,
        '' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        '58006415' AS hierarchy,
        'HARRIS TEETER' AS customer,
        '' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        '58006843' AS hierarchy,
        'HEBUTT' AS customer,
        '' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        '58063328' AS hierarchy,
        'JET.COM' AS customer,
        '' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        '58056571' AS hierarchy,
        'KC DE MEXICO' AS customer,
        '' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        '58004860' AS hierarchy,
        'KROGER' AS customer,
        '' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        '58004944' AS hierarchy,
        'MARCS DISTRIBUTION' AS customer,
        '' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        '58011420' AS hierarchy,
        'MCKESSON' AS customer,
        '' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        '58004894' AS hierarchy,
        'MEIJER' AS customer,
        '' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        '58017333' AS hierarchy,
        'MENARDS' AS customer,
        '' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        '58006857' AS hierarchy,
        'PUBLIX' AS customer,
        '' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        '58007101' AS hierarchy,
        'RITEAID' AS customer,
        '' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        '58006864' AS hierarchy,
        'SAFEWAY' AS customer,
        '' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        '58005988' AS hierarchy,
        'SAMS' AS customer,
        'TIER 1' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        '58006511' AS hierarchy,
        'SHOPKO' AS customer,
        '' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        '58060619' AS hierarchy,
        'SP RICHARDS' AS customer,
        '' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        '58018975' AS hierarchy,
        'STAPLES' AS customer,
        'TIER 1' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        '58020701' AS hierarchy,
        'STAPLES' AS customer,
        'TIER 1' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        '58006054' AS hierarchy,
        'SUPERVALUE' AS customer,
        '' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        '58003411' AS hierarchy,
        'TARGET' AS customer,
        'TIER 1' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        '58015593' AS hierarchy,
        'US FOOD SERVICE' AS customer,
        '' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        '58015837' AS hierarchy,
        'VERITIV' AS customer,
        'TIER 1' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        '58015716' AS hierarchy,
        'VERITIV' AS customer,
        'TIER 1' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        '58004948' AS hierarchy,
        'WAKEFERN' AS customer,
        '' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        '58007162' AS hierarchy,
        'WALGREENS' AS customer,
        '' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        '58005914' AS hierarchy,
        'WALMART' AS customer,
        'TIER 1' AS priority
    FROM
        dual
    UNION ALL
    SELECT
        '58014837' AS hierarchy,
        'WAXIE' AS customer,
        '' AS priority
    FROM
        dual
),
/********************************************************************************************************************
/* REASON CODE DESCRIPTION LIST - COPY DESCRIPTIONS FOR ALL CODES AS D- AND P- CODES
/********************************************************************************************************************/ reason_code_desc AS (
    SELECT
        reason_code,
        MIN(tm_desc) AS "REASON_DESC"
    FROM
        abpp_reason_code_score
    GROUP BY
        reason_code
    UNION ALL
    SELECT
        'D-' || reason_code,
        MIN(tm_desc) AS "REASON_DESC"
    FROM
        abpp_reason_code_score
    GROUP BY
        reason_code
    UNION ALL
    SELECT
        'P-' || reason_code,
        MIN(tm_desc) AS "REASON_DESC"
    FROM
        abpp_reason_code_score
    GROUP BY
        reason_code
),
/********************************************************************************************************************
/* SALES ORG WITH THE MOST CUBIC VOLUME ON EACH LOAD
/********************************************************************************************************************/ sales_org AS (
    SELECT
        ld_leg_id,
        rfrc_num10 AS "SALES_ORG"
    FROM
        (
            SELECT
                ll.ld_leg_id,
                sh.rfrc_num10,
                SUM(sh.bs_vol),
                ROW_NUMBER() OVER(
                    PARTITION BY ll.ld_leg_id
                    ORDER BY
                        SUM(sh.bs_vol) DESC
                ) AS row_nbr
            FROM
                load_leg_r          ll
                JOIN load_leg_detail_r   lld ON ll.ld_leg_id = lld.ld_leg_id
                JOIN shipment_r          sh ON lld.shpm_id = sh.shpm_id
            GROUP BY
                ll.ld_leg_id,
                sh.rfrc_num10
        )
    WHERE
        row_nbr = 1
),
/********************************************************************************************************************
/* FIRST TENDER RESPONSE 
/********************************************************************************************************************/ first_tender AS (
    SELECT
        ld_leg_id,
        carr_cd,
        srvc_cd,
        fta_cnt,
        crtd_dtt AS "TDR_DTT",
        round((strd_dtt - crtd_dtt) * 24, 1) AS "TDR_LEAD_HRS"
    FROM
        (
            SELECT
                trt.*,
                CASE
                    WHEN rsps_sec_cd = 'ACPD' THEN
                        1
                    ELSE
                        0
                END AS "FTA_CNT",
                ROW_NUMBER() OVER(
                    PARTITION BY trt.ld_leg_id
                    ORDER BY
                        trt.tdr_req_id
                ) AS row_nbr
            FROM
                tdr_req_t trt
        )
    WHERE
        row_nbr = 1
),
/********************************************************************************************************************
/* LOAD ON-TIME DELIVERY SERVICE PERFORMANCE - THIS IS AGGREGATED.  A MULT-STOP DELIVERY WILL BE REFLECTED AS 1 LOAD
/********************************************************************************************************************/ load_otd_service AS (
    SELECT
        load_id,
        team_name,
        team_group,
        MAX(base_appointment_datetime) AS "LAST_STOP_BASE_APPT_DATETIME",
        MAX(final_appointment_datetime) AS "LAST_STOP_FINAL_APPT_DATETIME",
        MAX(arrived_at_datetime) AS "LAST_STOP_ACTUAL_ARRIVAL",
        CASE
            WHEN MAX(caps_late) = 'Y' THEN
                0
            ELSE
                1
        END AS "CAPS_ONTIME_CNT",
        MIN(caps_reason) AS "CAPS_REASON_CD",
        CASE
            WHEN MAX(csrs_late) = 'Y' THEN
                0
            ELSE
                1
        END AS "CSRS_ONTIME_CNT",
        MIN(csrs_reason) AS "CSRS_REASON_CD",
        COUNT(load_id) AS stop_cnt,
        SUM(
            CASE
                WHEN arrived_at_datetime IS NOT NULL
                     AND caps_reason <> 'MEFC' THEN
                    1
                ELSE
                    0
            END
        ) AS "STOP_RESPONSE_CNT",
        SUM(
            CASE
                WHEN arrived_at_datetime IS NOT NULL
                     AND caps_late = 'N' THEN
                    1
                ELSE
                    0
            END
        ) AS "CAPS_ONTIME_STOP_CNT",
        SUM(
            CASE
                WHEN arrived_at_datetime IS NOT NULL
                     AND csrs_late = 'N' THEN
                    1
                ELSE
                    0
            END
        ) AS "CSRS_ONTIME_STOP_CNT"
    FROM
        abpp_otc_caps_master
    WHERE
        stop_num > 1
    GROUP BY
        load_id,
        team_name,
        team_group
),
/********************************************************************************************************************
/* GET PICK LOCATION AND ACTUAL PICK TIME FROM CAPS WHEN IT EXISTS 
/********************************************************************************************************************/ caps_pick_stops AS (
    SELECT
        load_id,
        location_num                AS "PICK_LOCATION_ID",
        base_appointment_datetime   AS "PICK_APPOINTMENT_DATETIME",
        departed_datetime           AS "CARR_DEPARTED_PICK_DATETIME",
        team_name,
        team_group
    FROM
        abpp_otc_caps_master
    WHERE
        stop_num = 1
),
/********************************************************************************************************************
/* GET BASE AND FINAL APPOINTMENTS FROM THE FIRST DROP STOP
/********************************************************************************************************************/ caps_first_drop_stops AS (
    SELECT
        load_id,
        base_appointment_datetime   AS "DROP_APPOINTMENT_DATETIME",
        arrived_at_datetime         AS "CARR_ARRIVE_FRST_DROP_DATE"
    FROM
        abpp_otc_caps_master
    WHERE
        stop_num = 2
),
/********************************************************************************************************************
/* GET THE DISTANCE TO FIRST DROP STOP PLUS CURRENT APPOINTMENT 
/********************************************************************************************************************/ dist_to_first_drop AS (
    SELECT
        sr.ld_leg_id,
        sr.frmprevstop_dist,
        ar.apt_frm_dtt   AS "CURRENT_FRMAPT_DATETIME",
        ar.apt_to_dtt    AS "CURRENT_TOAPT_DATETIME",
        ad.cty_name,
        ad.sta_cd
    FROM
        stop_r          sr
        JOIN address_r       ad ON ad.addr_id = sr.addr_id
        LEFT OUTER JOIN appointment_r   ar ON sr.apt_id = ar.apt_id
    WHERE
        seq_num = 2
)
/********************************************************************************************************************
/* METRICS QUERY
/********************************************************************************************************************/
SELECT
    llr.ld_leg_id,
-- Ship Mode logic from Thomas Fraser's 2019 Freight Spend Detail SAS program
    CASE
        WHEN llr.eqmt_typ = '53IM' THEN
            'INTERMODAL'
        ELSE
            'TRUCK'
    END AS ship_mode,    
 -- Order Type logic from Thomas Fraser's 2019 Freight Spend Detail SAS program   
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
-- Inbound/Outbound logic from Thomas Fraser's 2019 Freight Spend Detail SAS program
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
-- Award Lane logic from Tim Pool's 2019 Excel File
    CASE
        WHEN MAX(
            CASE
                WHEN awa.origin_id IS NULL THEN
                    0
                ELSE
                    1
            END
        ) = 0 THEN
            'Not Award Lane'
        ELSE
            'Award Lane'
    END AS awd_ln_str,
    MAX(
        CASE
            WHEN awa.origin_id IS NULL THEN
                0
            ELSE
                1
        END
    ) AS awd_ln_mkr,
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
    END AS awd_carr_str,
    MAX(
        CASE
            WHEN lasa.tariff_service IS NULL THEN
                0
            ELSE
                1
        END
    ) AS awd_carr_mkr,
    CASE
        WHEN awa.origin_id IS NOT NULL THEN
            awa.awd_weight_rpm
    END AS awd_rpm,
    cg.miles,
    cg.paymenttype,
    cg.linehaul,
    cg.fuel,
    cg.accessorials,
    cg.linehaulrpm,
    cg.fullrpm,
    so.sales_org,
    stat.stat_shrt_desc        AS "LOAD_STATUS",
    llr.carr_cd,
    llr.srvc_cd,
    llr.eqmt_typ,
    CASE
        WHEN substr(llr.frst_shpg_loc_cd, 5, 1) = '-'
             AND substr(llr.last_shpg_loc_cd, 5, 1) = '-' THEN
            'STO'
        WHEN substr(llr.frst_shpg_loc_cd, 5, 1) = '-'
             AND substr(llr.last_shpg_loc_cd, 1, 1) = '5' THEN
            'CUSTOMER'
        WHEN substr(llr.frst_shpg_loc_cd, 5, 1) = '-'
             AND llr.last_shpg_loc_cd = '99999999' THEN
            'CUSTOMER'
        WHEN substr(llr.frst_shpg_loc_cd, 1, 1) = 'V'
             AND substr(lar.corp1_id, 1, 2) = 'RM' THEN
            'MATERIALS'
        WHEN substr(llr.frst_shpg_loc_cd, 1, 1) = 'V'
             AND substr(lar.corp1_id, 1, 2) = 'RF' THEN
            'RECFIBER'
        ELSE
            'UNKNOWN'
    END AS "SHIP_TYPE",
    llr.frst_cty_name
    || ', '
    || llr.frst_sta_cd
    || ' to '
    ||
        CASE
            WHEN llr.last_ctry_cd = 'USA' THEN
                substr(llr.last_pstl_cd, 1, 5)
            ELSE
                llr.last_cty_name
                || ', '
                || llr.last_sta_cd
        END
    AS "LANE_DESC",
    llr.frst_shpg_loc_cd,
    llr.frst_cty_name,
    llr.frst_sta_cd,
    CASE
        WHEN llr.frst_ctry_cd = 'USA' THEN
            substr(llr.frst_pstl_cd, 1, 5)
        WHEN llr.frst_ctry_cd = 'CAN' THEN
            substr(llr.frst_pstl_cd, 1, 6)
        ELSE
            llr.frst_pstl_cd
    END AS frst_zip_cd,
    llr.frst_ctry_cd,
    llr.last_shpg_loc_cd,
    CASE
        WHEN customer_groupings.customer IS NOT NULL THEN
            customer_groupings.customer
        ELSE
            CASE
                WHEN substr(llr.last_shpg_loc_cd, 5, 1) = '-'      THEN
                    'K-C'
                WHEN substr(llr.last_shpg_loc_cd, 1, 2) = '58'     THEN
                    'OTHER CUSTOMER'
                WHEN substr(llr.last_shpg_loc_cd, 5, 1) = '99999999' THEN
                    'OTHER CUSTOMER'
                WHEN substr(llr.last_shpg_loc_cd, 1, 2) = 'AK'     THEN
                    'HUB'
                WHEN substr(llr.last_shpg_loc_cd, 1, 2) = 'HI'     THEN
                    'HUB'
                WHEN substr(llr.last_shpg_loc_cd, 1, 4) = 'LCL-'   THEN
                    'HUB'
                ELSE
                    'UNKNOWN'
            END
    END AS "SELL_TO_CUST",
    llr.last_cty_name          AS "FINAL_CITY_NAME",
    llr.last_sta_cd            AS "FINAL_STA_CD",
    llr.last_ctry_cd           AS "FINAL_CTRY_CD",
    CASE
        WHEN llr.last_ctry_cd = 'USA' THEN
            substr(llr.last_pstl_cd, 1, 5)
        WHEN llr.last_ctry_cd = 'CAN' THEN
            substr(llr.last_pstl_cd, 1, 6)
        ELSE
            llr.last_pstl_cd
    END AS final_zip_cd,
    dtfd.frmprevstop_dist      AS "DISTANCE_TO_FRST_STOP",
--ROUND(DTFD.FRMPREVSTOP_DIST / 46,1) AS "DRIVE_HOURS_TO_FRST_STOP",
--CASE 
--    WHEN LLR.EQMT_TYP = '53IM' THEN
--        ROUND((CDS.DROP_APPOINTMENT_DATETIME - CPS.PICK_APPOINTMENT_DATETIME)*24,1)
--    ELSE
--        ROUND((DTFD.FRMPREVSTOP_DIST / 46) + ((FLOOR((DTFD.FRMPREVSTOP_DIST / 46)/11)*11)+2),1)
--END  AS "TRIP_HOURS",
    cps.team_name,
    cps.team_group,
    llr.chgd_amt_dlr,
    trunc(ft.tdr_dtt) AS "FRST_TENDER_DATE",
    cps.pick_appointment_datetime,
    cps.carr_departed_pick_datetime,
    CASE
        WHEN llr.shpd_dtt IS NULL THEN
            trunc(cps.pick_appointment_datetime)
        ELSE
            llr.shpd_dtt
    END AS ship_date,
    CASE
        WHEN llr.shpd_dtt IS NULL THEN
            TO_CHAR(cps.pick_appointment_datetime - 1, 'D')
            || '-'
            || TO_CHAR(cps.pick_appointment_datetime, 'DY')
        ELSE
            TO_CHAR(llr.shpd_dtt - 1, 'D')
            || '-'
            || TO_CHAR(llr.shpd_dtt, 'DY')
    END AS ship_dow,
    CASE
        WHEN llr.shpd_dtt IS NULL THEN
            trunc(cps.pick_appointment_datetime, 'IW')
        ELSE
            trunc(llr.shpd_dtt, 'IW')
    END AS ship_week,
    CASE
        WHEN llr.shpd_dtt IS NULL THEN
            trunc(cps.pick_appointment_datetime, 'MM')
        ELSE
            trunc(llr.shpd_dtt, 'MM')
    END AS ship_month,
--CASE
--    WHEN LLR.EQMT_TYP = '53IM' THEN
--        TRUNC(CPS.PICK_APPOINTMENT_DATETIME) + 1
--    ELSE
--        CDS.DROP_APPOINTMENT_DATETIME - (((DTFD.FRMPREVSTOP_DIST / 46) + ((FLOOR((DTFD.FRMPREVSTOP_DIST / 46)/11)*11)+2))/24)
--END AS "DROP_DEAD_PICK_DATETIME",
--CDS.DROP_APPOINTMENT_DATETIME AS "FRST_STOP_BASE_APPT_DATETIME",
    los.last_stop_base_appt_datetime,
    los.last_stop_final_appt_datetime,
    TO_CHAR(los.last_stop_final_appt_datetime - 1, 'D')
    || '-'
    || TO_CHAR(los.last_stop_final_appt_datetime, 'DY') AS final_appt_dow,
    trunc(los.last_stop_final_appt_datetime, 'IW') AS final_appt_week,
    trunc(los.last_stop_final_appt_datetime, 'MM') AS final_appt_month,
    trunc(los.last_stop_actual_arrival) AS "ACTUAL_DELIVERY_DATE",
    TO_CHAR(los.last_stop_actual_arrival - 1, 'D')
    || '-'
    || TO_CHAR(los.last_stop_actual_arrival, 'DY') AS actual_delivery_dow,
    trunc(los.last_stop_actual_arrival, 'IW') AS actual_delivery_week,
    trunc(los.last_stop_actual_arrival, 'MM') AS actual_delivery_month,
    llr.mile_dist              AS "TOTAL_MILES",
    1 AS "LOAD_COUNT",
    los.stop_cnt               AS "STOP_COUNT",
    los.stop_response_cnt      AS "STOP_RESPONSE_COUNT",
    ft.fta_cnt,
    ft.tdr_lead_hrs,
    CASE
        WHEN llr.eqmt_typ = '53IM' THEN
            CASE
                WHEN cps.carr_departed_pick_datetime IS NULL
                     AND SYSDATE > trunc(cps.pick_appointment_datetime) + 1 THEN
                    0
                WHEN cps.carr_departed_pick_datetime IS NULL
                     AND SYSDATE <= trunc(cps.pick_appointment_datetime) + 1 THEN
                    1
                WHEN cps.carr_departed_pick_datetime IS NOT NULL
                     AND cps.carr_departed_pick_datetime > trunc(cps.pick_appointment_datetime) + 1 THEN
                    0
                ELSE
                    1
            END
        ELSE
            CASE
                WHEN cps.carr_departed_pick_datetime IS NULL
                     AND SYSDATE > cds.drop_appointment_datetime - ( ( ( dtfd.frmprevstop_dist / 46 ) + ( ( floor((dtfd.frmprevstop_dist
                     / 46) / 11) * 11 ) + 2 ) ) / 24 ) THEN
                    0
                WHEN cps.carr_departed_pick_datetime IS NULL
                     AND SYSDATE <= cds.drop_appointment_datetime - ( ( ( dtfd.frmprevstop_dist / 46 ) + ( ( floor((dtfd.frmprevstop_dist
                     / 46) / 11) * 11 ) + 2 ) ) / 24 ) THEN
                    1
                WHEN cps.carr_departed_pick_datetime IS NOT NULL
                     AND cps.carr_departed_pick_datetime > cds.drop_appointment_datetime - ( ( ( dtfd.frmprevstop_dist / 46 ) + (
                     ( floor((dtfd.frmprevstop_dist / 46) / 11) * 11 ) + 2 ) ) / 24 ) THEN
                    0
                ELSE
                    1
            END
    END AS "CAPS_OTP_CNT",
    los.caps_ontime_cnt        AS "CAPS_OTD_CNT",
    los.caps_ontime_stop_cnt   AS "CAPS_OTD_STOP_CNT",
    CASE
        WHEN rsd1.reason_desc IS NULL THEN
            los.caps_reason_cd
        ELSE
            rsd1.reason_desc
    END AS "CAPS_REASON_DESC",
    los.csrs_ontime_cnt        AS "CSRS_OTD_CNT",
    los.csrs_ontime_stop_cnt   AS "CSRS_OTD_STOP_CNT",
    CASE
        WHEN rsd2.reason_desc IS NULL THEN
            los.csrs_reason_cd
        ELSE
            rsd2.reason_desc
    END AS "CSRS_REASON_DESC",
    trunc(SYSDATE, 'MI') AS "LAST_REFRESHED_TIME"
FROM
    load_leg_r                llr
    JOIN abpp_otc_caps_master      cm ON cm.load_id = llr.ld_leg_id
    LEFT OUTER JOIN abpp_laneserviceawards    lasa ON lasa.origin_id = llr.frst_shpg_loc_cd
                                                   AND lasa.destination_id = llr.last_shpg_loc_cd
                                                   AND lasa.tariff_service = llr.srvc_cd
                                                   AND lasa.equip_type = llr.eqmt_typ
                                                   AND llr.strd_dtt BETWEEN lasa.from_date AND lasa.TO_DATE
    LEFT OUTER JOIN award_weighted_averages   awa ON awa.origin_id = llr.frst_shpg_loc_cd
                                                   AND awa.destination_id = llr.last_shpg_loc_cd
                                                   AND awa.equip_type = llr.eqmt_typ
                                                   AND llr.strd_dtt BETWEEN awa.from_date AND awa.TO_DATE
    JOIN load_at_r                 lar ON llr.frst_shpg_loc_cd = lar.shpg_loc_cd
    JOIN status_r                  stat ON llr.cur_optlstat_id = stat.stat_id
    JOIN caps_pick_stops           cps ON cps.load_id = llr.ld_leg_id
    JOIN caps_first_drop_stops     cds ON cds.load_id = llr.ld_leg_id
    JOIN load_otd_service          los ON los.load_id = llr.ld_leg_id
    JOIN first_tender              ft ON ft.ld_leg_id = llr.ld_leg_id
    JOIN dist_to_first_drop        dtfd ON dtfd.ld_leg_id = llr.ld_leg_id
    JOIN sales_org                 so ON so.ld_leg_id = llr.ld_leg_id
    JOIN charges                   cg ON cg.ld_leg_id = llr.ld_leg_id
    LEFT OUTER JOIN customer_groupings ON customer_groupings.hierarchy = substr(llr.last_shpg_loc_cd, 1, 8)
    LEFT OUTER JOIN reason_code_desc          rsd1 ON los.caps_reason_cd = rsd1.reason_code
    LEFT OUTER JOIN reason_code_desc          rsd2 ON los.csrs_reason_cd = rsd2.reason_code
WHERE
    llr.cur_optlstat_id BETWEEN 315 AND 350
    AND llr.eqmt_typ IN (
        '48FT',
        '53FT',
        '53IM',
        '53RT',
        '53TC',
        '53HC'
    )
GROUP BY
    llr.ld_leg_id,
    CASE
            WHEN llr.eqmt_typ = '53IM' THEN
                'INTERMODAL'
            ELSE
                'TRUCK'
        END,
    llr.eqmt_typ,
    '53IM',
    'INTERMODAL',
    'TRUCK',
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
    lar.corp1_id,
    'RM',
    'RM-INBOUND',
    lar.corp1_id,
    'RF',
    'RF-INBOUND',
    substr(llr.last_shpg_loc_cd, 1, 1),
    llr.last_shpg_loc_cd,
    1,
    1,
    'R',
    'RETURNS',
    substr(llr.last_shpg_loc_cd, 1, 1),
    llr.last_shpg_loc_cd,
    1,
    1,
    '1',
    'INTERMILL',
    substr(llr.last_shpg_loc_cd, 1, 1),
    llr.last_shpg_loc_cd,
    1,
    1,
    '2',
    'INTERMILL',
    'CUSTOMER',
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
    lar.corp1_id,
    'RM',
    'INBOUND',
    lar.corp1_id,
    'RF',
    'INBOUND',
    substr(llr.last_shpg_loc_cd, 1, 1),
    llr.last_shpg_loc_cd,
    1,
    1,
    'R',
    'INBOUND',
    'OUTBOUND',
    CASE
            WHEN awa.origin_id IS NOT NULL THEN
                awa.awd_weight_rpm
        END,
    awa.origin_id,
    awa.awd_weight_rpm,
    cg.miles,
    cg.paymenttype,
    cg.linehaul,
    cg.fuel,
    cg.accessorials,
    cg.linehaulrpm,
    cg.fullrpm,
    so.sales_org,
    stat.stat_shrt_desc,
    llr.carr_cd,
    llr.srvc_cd,
    llr.eqmt_typ,
    CASE
            WHEN substr(llr.frst_shpg_loc_cd, 5, 1) = '-'
                 AND substr(llr.last_shpg_loc_cd, 5, 1) = '-' THEN
                'STO'
            WHEN substr(llr.frst_shpg_loc_cd, 5, 1) = '-'
                 AND substr(llr.last_shpg_loc_cd, 1, 1) = '5' THEN
                'CUSTOMER'
            WHEN substr(llr.frst_shpg_loc_cd, 5, 1) = '-'
                 AND llr.last_shpg_loc_cd = '99999999' THEN
                'CUSTOMER'
            WHEN substr(llr.frst_shpg_loc_cd, 1, 1) = 'V'
                 AND substr(lar.corp1_id, 1, 2) = 'RM' THEN
                'MATERIALS'
            WHEN substr(llr.frst_shpg_loc_cd, 1, 1) = 'V'
                 AND substr(lar.corp1_id, 1, 2) = 'RF' THEN
                'RECFIBER'
            ELSE
                'UNKNOWN'
        END,
    substr(llr.frst_shpg_loc_cd, 5, 1),
    llr.frst_shpg_loc_cd,
    5,
    1,
    '-',
    substr(llr.last_shpg_loc_cd, 5, 1),
    llr.last_shpg_loc_cd,
    5,
    1,
    '-',
    'STO',
    substr(llr.frst_shpg_loc_cd, 5, 1),
    llr.frst_shpg_loc_cd,
    5,
    1,
    '-',
    substr(llr.last_shpg_loc_cd, 1, 1),
    llr.last_shpg_loc_cd,
    1,
    1,
    '5',
    'CUSTOMER',
    substr(llr.frst_shpg_loc_cd, 5, 1),
    llr.frst_shpg_loc_cd,
    5,
    1,
    '-',
    llr.last_shpg_loc_cd,
    '99999999',
    'CUSTOMER',
    substr(llr.frst_shpg_loc_cd, 1, 1),
    llr.frst_shpg_loc_cd,
    1,
    1,
    'V',
    substr(lar.corp1_id, 1, 2),
    lar.corp1_id,
    1,
    2,
    'RM',
    'MATERIALS',
    substr(llr.frst_shpg_loc_cd, 1, 1),
    llr.frst_shpg_loc_cd,
    1,
    1,
    'V',
    substr(lar.corp1_id, 1, 2),
    lar.corp1_id,
    1,
    2,
    'RF',
    'RECFIBER',
    'UNKNOWN',
    llr.frst_cty_name
    || ', '
    || llr.frst_sta_cd
    || ' to '
    ||
        CASE
            WHEN llr.last_ctry_cd = 'USA' THEN
                substr(llr.last_pstl_cd, 1, 5)
            ELSE
                llr.last_cty_name
                || ', '
                || llr.last_sta_cd
        END,
    ', ',
    llr.frst_sta_cd,
    ' to ',
    CASE
            WHEN llr.last_ctry_cd = 'USA' THEN
                substr(llr.last_pstl_cd, 1, 5)
            ELSE
                llr.last_cty_name
                || ', '
                || llr.last_sta_cd
        END,
    llr.last_ctry_cd,
    'USA',
    substr(llr.last_pstl_cd, 1, 5),
    llr.last_pstl_cd,
    1,
    5,
    llr.last_cty_name
    || ', '
    || llr.last_sta_cd,
    ', ',
    llr.last_sta_cd,
    llr.frst_shpg_loc_cd,
    llr.frst_cty_name,
    llr.frst_sta_cd,
    CASE
            WHEN llr.frst_ctry_cd = 'USA' THEN
                substr(llr.frst_pstl_cd, 1, 5)
            WHEN llr.frst_ctry_cd = 'CAN' THEN
                substr(llr.frst_pstl_cd, 1, 6)
            ELSE
                llr.frst_pstl_cd
        END,
    llr.frst_ctry_cd,
    'USA',
    substr(llr.frst_pstl_cd, 1, 5),
    llr.frst_pstl_cd,
    1,
    5,
    llr.frst_ctry_cd,
    'CAN',
    substr(llr.frst_pstl_cd, 1, 6),
    llr.frst_pstl_cd,
    1,
    6,
    llr.frst_pstl_cd,
    llr.frst_ctry_cd,
    llr.last_shpg_loc_cd,
    CASE
            WHEN customer_groupings.customer IS NOT NULL THEN
                customer_groupings.customer
            ELSE
                CASE
                    WHEN substr(llr.last_shpg_loc_cd, 5, 1) = '-'      THEN
                        'K-C'
                    WHEN substr(llr.last_shpg_loc_cd, 1, 2) = '58'     THEN
                        'OTHER CUSTOMER'
                    WHEN substr(llr.last_shpg_loc_cd, 5, 1) = '99999999' THEN
                        'OTHER CUSTOMER'
                    WHEN substr(llr.last_shpg_loc_cd, 1, 2) = 'AK'     THEN
                        'HUB'
                    WHEN substr(llr.last_shpg_loc_cd, 1, 2) = 'HI'     THEN
                        'HUB'
                    WHEN substr(llr.last_shpg_loc_cd, 1, 4) = 'LCL-'   THEN
                        'HUB'
                    ELSE
                        'UNKNOWN'
                END
        END,
    customer_groupings.customer,
    customer_groupings.customer,
    CASE
            WHEN substr(llr.last_shpg_loc_cd, 5, 1) = '-'      THEN
                'K-C'
            WHEN substr(llr.last_shpg_loc_cd, 1, 2) = '58'     THEN
                'OTHER CUSTOMER'
            WHEN substr(llr.last_shpg_loc_cd, 5, 1) = '99999999' THEN
                'OTHER CUSTOMER'
            WHEN substr(llr.last_shpg_loc_cd, 1, 2) = 'AK'     THEN
                'HUB'
            WHEN substr(llr.last_shpg_loc_cd, 1, 2) = 'HI'     THEN
                'HUB'
            WHEN substr(llr.last_shpg_loc_cd, 1, 4) = 'LCL-'   THEN
                'HUB'
            ELSE
                'UNKNOWN'
        END,
    substr(llr.last_shpg_loc_cd, 5, 1),
    llr.last_shpg_loc_cd,
    5,
    1,
    '-',
    'K-C',
    substr(llr.last_shpg_loc_cd, 1, 2),
    llr.last_shpg_loc_cd,
    1,
    2,
    '58',
    'OTHER CUSTOMER',
    substr(llr.last_shpg_loc_cd, 5, 1),
    llr.last_shpg_loc_cd,
    5,
    1,
    '99999999',
    'OTHER CUSTOMER',
    substr(llr.last_shpg_loc_cd, 1, 2),
    llr.last_shpg_loc_cd,
    1,
    2,
    'AK',
    'HUB',
    substr(llr.last_shpg_loc_cd, 1, 2),
    llr.last_shpg_loc_cd,
    1,
    2,
    'HI',
    'HUB',
    substr(llr.last_shpg_loc_cd, 1, 4),
    llr.last_shpg_loc_cd,
    1,
    4,
    'LCL-',
    'HUB',
    'UNKNOWN',
    llr.last_cty_name,
    llr.last_sta_cd,
    llr.last_ctry_cd,
    CASE
            WHEN llr.last_ctry_cd = 'USA' THEN
                substr(llr.last_pstl_cd, 1, 5)
            WHEN llr.last_ctry_cd = 'CAN' THEN
                substr(llr.last_pstl_cd, 1, 6)
            ELSE
                llr.last_pstl_cd
        END,
    llr.last_ctry_cd,
    'USA',
    substr(llr.last_pstl_cd, 1, 5),
    llr.last_pstl_cd,
    1,
    5,
    llr.last_ctry_cd,
    'CAN',
    substr(llr.last_pstl_cd, 1, 6),
    llr.last_pstl_cd,
    1,
    6,
    llr.last_pstl_cd,
    dtfd.frmprevstop_dist,
    cps.team_name,
    cps.team_group,
    llr.chgd_amt_dlr,
    trunc(ft.tdr_dtt),
    ft.tdr_dtt,
    cps.pick_appointment_datetime,
    cps.carr_departed_pick_datetime,
    CASE
            WHEN llr.shpd_dtt IS NULL THEN
                trunc(cps.pick_appointment_datetime)
            ELSE
                llr.shpd_dtt
        END,
    llr.shpd_dtt,
    trunc(cps.pick_appointment_datetime),
    cps.pick_appointment_datetime,
    llr.shpd_dtt,
    CASE
            WHEN llr.shpd_dtt IS NULL THEN
                TO_CHAR(cps.pick_appointment_datetime - 1, 'D')
                || '-'
                || TO_CHAR(cps.pick_appointment_datetime, 'DY')
            ELSE
                TO_CHAR(llr.shpd_dtt - 1, 'D')
                || '-'
                || TO_CHAR(llr.shpd_dtt, 'DY')
        END,
    llr.shpd_dtt,
    TO_CHAR(cps.pick_appointment_datetime - 1, 'D')
    || '-'
    || TO_CHAR(cps.pick_appointment_datetime, 'DY'),
    cps.pick_appointment_datetime - 1,
    1,
    'D',
    '-',
    TO_CHAR(cps.pick_appointment_datetime, 'DY'),
    cps.pick_appointment_datetime,
    'DY',
    TO_CHAR(llr.shpd_dtt - 1, 'D')
    || '-'
    || TO_CHAR(llr.shpd_dtt, 'DY'),
    llr.shpd_dtt - 1,
    1,
    'D',
    '-',
    TO_CHAR(llr.shpd_dtt, 'DY'),
    llr.shpd_dtt,
    'DY',
    CASE
            WHEN llr.shpd_dtt IS NULL THEN
                trunc(cps.pick_appointment_datetime, 'IW')
            ELSE
                trunc(llr.shpd_dtt, 'IW')
        END,
    llr.shpd_dtt,
    trunc(cps.pick_appointment_datetime, 'IW'),
    cps.pick_appointment_datetime,
    'IW',
    trunc(llr.shpd_dtt, 'IW'),
    llr.shpd_dtt,
    'IW',
    CASE
            WHEN llr.shpd_dtt IS NULL THEN
                trunc(cps.pick_appointment_datetime, 'MM')
            ELSE
                trunc(llr.shpd_dtt, 'MM')
        END,
    llr.shpd_dtt,
    trunc(cps.pick_appointment_datetime, 'MM'),
    cps.pick_appointment_datetime,
    'MM',
    trunc(llr.shpd_dtt, 'MM'),
    llr.shpd_dtt,
    'MM',
    los.last_stop_base_appt_datetime,
    los.last_stop_final_appt_datetime,
    TO_CHAR(los.last_stop_final_appt_datetime - 1, 'D')
    || '-'
    || TO_CHAR(los.last_stop_final_appt_datetime, 'DY'),
    los.last_stop_final_appt_datetime - 1,
    1,
    'D',
    '-',
    TO_CHAR(los.last_stop_final_appt_datetime, 'DY'),
    los.last_stop_final_appt_datetime,
    'DY',
    trunc(los.last_stop_final_appt_datetime, 'IW'),
    los.last_stop_final_appt_datetime,
    'IW',
    trunc(los.last_stop_final_appt_datetime, 'MM'),
    los.last_stop_final_appt_datetime,
    'MM',
    trunc(los.last_stop_actual_arrival),
    los.last_stop_actual_arrival,
    TO_CHAR(los.last_stop_actual_arrival - 1, 'D')
    || '-'
    || TO_CHAR(los.last_stop_actual_arrival, 'DY'),
    los.last_stop_actual_arrival - 1,
    1,
    'D',
    '-',
    TO_CHAR(los.last_stop_actual_arrival, 'DY'),
    los.last_stop_actual_arrival,
    'DY',
    trunc(los.last_stop_actual_arrival, 'IW'),
    los.last_stop_actual_arrival,
    'IW',
    trunc(los.last_stop_actual_arrival, 'MM'),
    los.last_stop_actual_arrival,
    'MM',
    llr.mile_dist,
    1,
    los.stop_cnt,
    los.stop_response_cnt,
    ft.fta_cnt,
    ft.tdr_lead_hrs,
    CASE
            WHEN llr.eqmt_typ = '53IM' THEN
                CASE
                    WHEN cps.carr_departed_pick_datetime IS NULL
                         AND SYSDATE > trunc(cps.pick_appointment_datetime) + 1 THEN
                        0
                    WHEN cps.carr_departed_pick_datetime IS NULL
                         AND SYSDATE <= trunc(cps.pick_appointment_datetime) + 1 THEN
                        1
                    WHEN cps.carr_departed_pick_datetime IS NOT NULL
                         AND cps.carr_departed_pick_datetime > trunc(cps.pick_appointment_datetime) + 1 THEN
                        0
                    ELSE
                        1
                END
            ELSE
                CASE
                    WHEN cps.carr_departed_pick_datetime IS NULL
                         AND SYSDATE > cds.drop_appointment_datetime - ( ( ( dtfd.frmprevstop_dist / 46 ) + ( ( floor((dtfd.frmprevstop_dist
                         / 46) / 11) * 11 ) + 2 ) ) / 24 ) THEN
                        0
                    WHEN cps.carr_departed_pick_datetime IS NULL
                         AND SYSDATE <= cds.drop_appointment_datetime - ( ( ( dtfd.frmprevstop_dist / 46 ) + ( ( floor((dtfd.frmprevstop_dist
                         / 46) / 11) * 11 ) + 2 ) ) / 24 ) THEN
                        1
                    WHEN cps.carr_departed_pick_datetime IS NOT NULL
                         AND cps.carr_departed_pick_datetime > cds.drop_appointment_datetime - ( ( ( dtfd.frmprevstop_dist / 46 )
                         + ( ( floor((dtfd.frmprevstop_dist / 46) / 11) * 11 ) + 2 ) ) / 24 ) THEN
                        0
                    ELSE
                        1
                END
        END,
    llr.eqmt_typ,
    '53IM',
    CASE
            WHEN cps.carr_departed_pick_datetime IS NULL
                 AND SYSDATE > trunc(cps.pick_appointment_datetime) + 1 THEN
                0
            WHEN cps.carr_departed_pick_datetime IS NULL
                 AND SYSDATE <= trunc(cps.pick_appointment_datetime) + 1 THEN
                1
            WHEN cps.carr_departed_pick_datetime IS NOT NULL
                 AND cps.carr_departed_pick_datetime > trunc(cps.pick_appointment_datetime) + 1 THEN
                0
            ELSE
                1
        END,
    cps.carr_departed_pick_datetime,
    SYSDATE,
    trunc(cps.pick_appointment_datetime) + 1,
    cps.pick_appointment_datetime,
    1,
    0,
    cps.carr_departed_pick_datetime,
    SYSDATE,
    trunc(cps.pick_appointment_datetime) + 1,
    cps.pick_appointment_datetime,
    1,
    1,
    cps.carr_departed_pick_datetime,
    cps.carr_departed_pick_datetime,
    trunc(cps.pick_appointment_datetime) + 1,
    cps.pick_appointment_datetime,
    1,
    0,
    1,
    CASE
            WHEN cps.carr_departed_pick_datetime IS NULL
                 AND SYSDATE > cds.drop_appointment_datetime - ( ( ( dtfd.frmprevstop_dist / 46 ) + ( ( floor((dtfd.frmprevstop_dist
                 / 46) / 11) * 11 ) + 2 ) ) / 24 ) THEN
                0
            WHEN cps.carr_departed_pick_datetime IS NULL
                 AND SYSDATE <= cds.drop_appointment_datetime - ( ( ( dtfd.frmprevstop_dist / 46 ) + ( ( floor((dtfd.frmprevstop_dist
                 / 46) / 11) * 11 ) + 2 ) ) / 24 ) THEN
                1
            WHEN cps.carr_departed_pick_datetime IS NOT NULL
                 AND cps.carr_departed_pick_datetime > cds.drop_appointment_datetime - ( ( ( dtfd.frmprevstop_dist / 46 ) + ( ( floor
                 ((dtfd.frmprevstop_dist / 46) / 11) * 11 ) + 2 ) ) / 24 ) THEN
                0
            ELSE
                1
        END,
    cps.carr_departed_pick_datetime,
    SYSDATE,
    cds.drop_appointment_datetime - ( ( ( dtfd.frmprevstop_dist / 46 ) + ( ( floor((dtfd.frmprevstop_dist / 46) / 11) * 11 ) + 2 )
    ) / 24 ),
    ( ( ( dtfd.frmprevstop_dist / 46 ) + ( ( floor((dtfd.frmprevstop_dist / 46) / 11) * 11 ) + 2 ) ) / 24 ),
    ( ( dtfd.frmprevstop_dist / 46 ) + ( ( floor((dtfd.frmprevstop_dist / 46) / 11) * 11 ) + 2 ) ) / 24,
    ( dtfd.frmprevstop_dist / 46 ) + ( ( floor((dtfd.frmprevstop_dist / 46) / 11) * 11 ) + 2 ),
    dtfd.frmprevstop_dist / 46,
    46,
    ( ( floor((dtfd.frmprevstop_dist / 46) / 11) * 11 ) + 2 ),
    ( floor((dtfd.frmprevstop_dist / 46) / 11) * 11 ) + 2,
    floor((dtfd.frmprevstop_dist / 46) / 11) * 11,
    ( dtfd.frmprevstop_dist / 46 ) / 11,
    dtfd.frmprevstop_dist / 46,
    46,
    11,
    11,
    2,
    24,
    0,
    cps.carr_departed_pick_datetime,
    SYSDATE,
    cds.drop_appointment_datetime - ( ( ( dtfd.frmprevstop_dist / 46 ) + ( ( floor((dtfd.frmprevstop_dist / 46) / 11) * 11 ) + 2 )
    ) / 24 ),
    ( ( ( dtfd.frmprevstop_dist / 46 ) + ( ( floor((dtfd.frmprevstop_dist / 46) / 11) * 11 ) + 2 ) ) / 24 ),
    ( ( dtfd.frmprevstop_dist / 46 ) + ( ( floor((dtfd.frmprevstop_dist / 46) / 11) * 11 ) + 2 ) ) / 24,
    ( dtfd.frmprevstop_dist / 46 ) + ( ( floor((dtfd.frmprevstop_dist / 46) / 11) * 11 ) + 2 ),
    dtfd.frmprevstop_dist / 46,
    46,
    ( ( floor((dtfd.frmprevstop_dist / 46) / 11) * 11 ) + 2 ),
    ( floor((dtfd.frmprevstop_dist / 46) / 11) * 11 ) + 2,
    floor((dtfd.frmprevstop_dist / 46) / 11) * 11,
    ( dtfd.frmprevstop_dist / 46 ) / 11,
    dtfd.frmprevstop_dist / 46,
    46,
    11,
    11,
    2,
    24,
    1,
    cps.carr_departed_pick_datetime,
    cps.carr_departed_pick_datetime,
    cds.drop_appointment_datetime - ( ( ( dtfd.frmprevstop_dist / 46 ) + ( ( floor((dtfd.frmprevstop_dist / 46) / 11) * 11 ) + 2 )
    ) / 24 ),
    ( ( ( dtfd.frmprevstop_dist / 46 ) + ( ( floor((dtfd.frmprevstop_dist / 46) / 11) * 11 ) + 2 ) ) / 24 ),
    ( ( dtfd.frmprevstop_dist / 46 ) + ( ( floor((dtfd.frmprevstop_dist / 46) / 11) * 11 ) + 2 ) ) / 24,
    ( dtfd.frmprevstop_dist / 46 ) + ( ( floor((dtfd.frmprevstop_dist / 46) / 11) * 11 ) + 2 ),
    dtfd.frmprevstop_dist / 46,
    46,
    ( ( floor((dtfd.frmprevstop_dist / 46) / 11) * 11 ) + 2 ),
    ( floor((dtfd.frmprevstop_dist / 46) / 11) * 11 ) + 2,
    floor((dtfd.frmprevstop_dist / 46) / 11) * 11,
    ( dtfd.frmprevstop_dist / 46 ) / 11,
    dtfd.frmprevstop_dist / 46,
    46,
    11,
    11,
    2,
    24,
    0,
    1,
    los.caps_ontime_cnt,
    los.caps_ontime_stop_cnt,
    CASE
            WHEN rsd1.reason_desc IS NULL THEN
                los.caps_reason_cd
            ELSE
                rsd1.reason_desc
        END,
    rsd1.reason_desc,
    los.caps_reason_cd,
    rsd1.reason_desc,
    los.csrs_ontime_cnt,
    los.csrs_ontime_stop_cnt,
    CASE
            WHEN rsd2.reason_desc IS NULL THEN
                los.csrs_reason_cd
            ELSE
                rsd2.reason_desc
        END,
    rsd2.reason_desc,
    los.csrs_reason_cd,
    rsd2.reason_desc,
    trunc(SYSDATE, 'MI'),
    SYSDATE,
    'MI' 

    

    
/* 
COMMENTED OUT BY STEVE WOLFE ON 5/29/2019 - WILL NOW RETURN ALL RECORDS ON CAPS TABLE
    AND

--USE SHIP DATE IF IT IS AVAILABLE, ELSE USE PICK APPOINTMENT DATE
     ( ( llr.shpd_dtt IS NULL
            AND trunc(cps.pick_appointment_datetime) BETWEEN add_months(last_day(trunc(SYSDATE)) + 1, - 2) AND add_months(last_day
            (trunc(SYSDATE)), + 1) )
          OR trunc(llr.shpd_dtt) BETWEEN add_months(last_day(trunc(SYSDATE)) + 1, - 2) AND add_months(last_day(trunc(SYSDATE)), +
          1) )
*/