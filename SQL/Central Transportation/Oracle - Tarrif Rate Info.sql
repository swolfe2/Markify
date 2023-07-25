SELECT
    *
FROM
    (
        SELECT DISTINCT
            t.carr_cd        AS Carrier,
            c.name           AS "Carrier Name",
            l.srvc_cd        AS Service,
            mst.srvc_desc    AS "Service Description",
            CASE
                WHEN upper(mst.srvc_desc) LIKE '%INTERMODAL%' THEN
                    'INTERMODAL'
                WHEN upper(mst.srvc_desc) LIKE '%TRAIN%' THEN
                    'INTERMODAL'
                WHEN upper(mst.srvc_desc) LIKE '%TOFC%' THEN
                    'INTERMODAL'
                WHEN upper(mst.srvc_desc) LIKE '%INTERMILL%' THEN
                    'INTERMODAL'
                ELSE
                    'TRUCK'
            END AS shipmode,
            l.orig_zn_cd     AS "Origin Zone Code",
            org.zn_desc      AS "Origin City",
            l.dest_zn_cd     AS "Dest Zone Code",
            dest.zn_desc     AS "Dest State/ZIP",
            r.efct_dt        AS "TM Effective Date",
            r.expd_dt        AS "TM Expiration Date",
            rr.brk_amt_dlr   AS "Rate Per Mile",
            r.min_chrg_dlr   AS "Min Charge",
            r.chrg_cd        AS "Charge Code",
            RANK() OVER(
                PARTITION BY l.orig_zn_cd, l.dest_zn_cd
                ORDER BY
                    rr.brk_amt_dlr ASC, l.min_chrg_dlr ASC, l.tff_id ASC
            ) AS Rank,
            l.tff_id         AS "Tariff ID",
            t.tff_cd         AS "Tariff Code",
            r.rate_cd        AS "Rate Code",
            current_date     AS "Last Refreshed"
        FROM
            najdaadm.tff_t         t
            INNER JOIN najdaadm.lane_assc_t   l ON l.tff_id = t.tff_id
            INNER JOIN najdaadm.rate_t        r ON l.tff_id = r.tff_id
                                            AND l.rate_cd = r.rate_cd
            INNER JOIN najdaadm.rng_rate_t    rr ON rr.rate_id = r.rate_id
            LEFT JOIN najdaadm.zone_r        org ON l.orig_zn_cd = org.zn_cd
            LEFT JOIN najdaadm.zone_r        dest ON l.dest_zn_cd = dest.zn_cd
            INNER JOIN najdaadm.carrier_r     c ON t.carr_cd = c.carr_cd
            LEFT JOIN najdaadm.mstr_srvc_t   mst ON l.srvc_cd = mst.srvc_cd
        WHERE
            r.efct_dt <= SYSDATE
            -- AND r.expd_dt > SYSDATE
            AND rr.brk_amt_dlr >.01
            AND r.chrg_cd = 'MILE'
            AND upper(mst.srvc_desc) NOT LIKE '%INTERMODAL%'
            AND upper(mst.srvc_desc) NOT LIKE '%TRAIN%'
            AND upper(mst.srvc_desc) NOT LIKE '%TOFC%'
            AND upper(mst.srvc_desc) NOT LIKE '%INTERMILL%'
            --AND    t.tff_cd   = 'HHWY-KC10-D'
            --AND r.rate_cd = '105405'
    --AND mst.srvc_desc NOT LIKE '%TRAIN%' AND mst.srvc_desc NOT LIKE '%TOFC%' AND mst.srvc_desc NOT LIKE '%INTERMILL%'
    )/*
WHERE
    rank <= 5*/

ORDER BY
    "Origin Zone Code",
    "Dest Zone Code",
    Shipmode,
    Rank,
    Service