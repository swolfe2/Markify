SELECT DISTINCT
    tbllanes.laneid,
    tbllanes.orig_city_state     AS originzone,
    tbllanes.origin,
    tbllanes.dest_city_state     AS destzone,
    tbllanes.dest,
    tbllaneaudit.updated_loads   AS laneannvol,
    dbms_lob.substr(tbllaneaudit.comments) AS lanecomments,
    laneeff,
    laneexp,
    tblawards.scac               AS service,
    awardpct,
    dbms_lob.substr(tblawards.comments) AS awardcomments,
    CASE
        WHEN round(awardpct *(updated_loads / 52), 1) < 1 THEN
            1
        ELSE
            round(awardpct *(updated_loads / 52), 1)
    END AS carrwkvol,
    CASE
        WHEN round((awardpct *(updated_loads / 52)) * 1.15, 0) < 1 THEN
            1
        ELSE
            round((awardpct *(updated_loads / 52)) * 1.15, 0)
    END AS carrwkvol_surge,
    awardeff,
    awardexp,
    '' AS rank,
    CASE
        WHEN ship_mode = 'IM' THEN
            '53IM'
        ELSE
            CASE
                WHEN tblawards.scac = 'WALM' THEN
                    '53RT'
                ELSE
                    '53FT'
            END
    END AS equiptype,
    brk_amt_dlr                  AS rpm,
    min_chrg_dlr                 AS mincharge,
    CASE
        WHEN ( brk_amt_dlr * miles ) > min_chrg_dlr THEN
            brk_amt_dlr
        ELSE
            ( min_chrg_dlr ) / (
                CASE
                    WHEN miles < 1 THEN
                        1
                    ELSE
                        miles
                END
            )
    END AS awardrpm,
    efct_dt                      AS rateeff,
    expd_dt                      AS rateexp,
    miles                        AS mileage,
    reason
FROM
    tbllanes,
    tbllaneaudit,
    tblawards,
    tblcarriers,
    tbltmrates
WHERE
    tbllanes.laneid = tbllaneaudit.laneid
    AND tbllanes.laneid = tblawards.laneid
    AND tbllanes.laneid = tbltmrates.laneid
    AND tblawards.scac = tblcarriers.scac
    AND tblawards.scac = tbltmrates.scac
    AND tblawards.awardpct > 0
    AND tbllanes.laneid > 0
    --AND tblawards.scac = 'WALM'