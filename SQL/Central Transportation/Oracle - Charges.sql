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
                'ADLH', 'CATX', 'CONT', 'CUBE', 'CWF1', 'CWF2', 'CWF3', 'CWF4', 'CWT', 'CWTF', 'CWTM', 'DISC', 'DIST', 'DT2', 'FBED'
                , 'FLAT', 'GRI', 'ISPT', 'LMIN', 'LTLD', 'MILE', 'OCFR', 'OCN1', 'PKG1', 'SPOT', 'TC', 'TCM', 'UPD', 'WGT', 'ZNFD'
                , 'ZWND', 'ZJBH', 'ZSPT'
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
                'BAF', 'DFSC', 'FS01', 'FS02', 'FS03', 'FS04', 'FS05', 'FS06', 'FS07', 'FS08', 'FS09', 'FS10', 'FS11', 'FS12', 'FS13'
                , 'FS14', 'FS15', 'FSCA', 'PFSC', 'RFSC', 'WCFS'
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
                'ADLH', 'CATX', 'CONT', 'CUBE', 'CWF1', 'CWF2', 'CWF3', 'CWF4', 'CWT', 'CWTF', 'CWTM', 'DISC', 'DIST', 'DT2', 'FBED'
                , 'FLAT', 'GRI', 'ISPT', 'LMIN', 'LTLD', 'MILE', 'OCFR', 'OCN1', 'PKG1', 'SPOT', 'TC', 'TCM', 'UPD', 'WGT', 'ZNFD'
                , 'ZWND', 'ZJBH', 'ZSPT', 'BAF', 'DFSC', 'FS01', 'FS02', 'FS03', 'FS04', 'FS05', 'FS06', 'FS07', 'FS08', 'FS09', 'FS10'
                , 'FS11', 'FS12', 'FS13', 'FS14', 'FS15', 'FSCA', 'PFSC', 'RFSC', 'WCFS'
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
                'ADLH', 'CATX', 'CONT', 'CUBE', 'CWF1', 'CWF2', 'CWF3', 'CWF4', 'CWT', 'CWTF', 'CWTM', 'DISC', 'DIST', 'DT2', 'FBED'
                , 'FLAT', 'GRI', 'ISPT', 'LMIN', 'LTLD', 'MILE', 'OCFR', 'OCN1', 'PKG1', 'SPOT', 'TC', 'TCM', 'UPD', 'WGT', 'ZNFD'
                , 'ZWND', 'ZJBH', 'ZSPT'
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