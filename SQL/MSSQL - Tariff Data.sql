SELECT tariffs.*, ca.Broker FROM OPENQUERY(NAJDAPRD,'SELECT
    *
FROM
    (
        SELECT DISTINCT
            t.carr_cd        AS Carrier,
            c.name           AS "Carrier Name",
            l.srvc_cd        AS Service,
            mst.srvc_desc    AS "Service Description",
            CASE
                WHEN upper(mst.srvc_desc) LIKE ''%INTERMODAL%'' THEN
                    ''INTERMODAL''
                WHEN upper(mst.srvc_desc) LIKE ''%TRAIN%'' THEN
                    ''INTERMODAL''
                WHEN upper(mst.srvc_desc) LIKE ''%TOFC%'' THEN
                    ''INTERMODAL''
                WHEN upper(mst.srvc_desc) LIKE ''%INTERMILL%'' THEN
                    ''INTERMODAL''
                ELSE
                    ''TRUCK''
            END AS shipmode,
            MIN(l.orig_zn_cd)     AS "Origin Zone Code",
            MIN(org.zn_desc)      AS "Origin City",
            MIN(l.dest_zn_cd)     AS "Dest Zone Code",
            MIN(dest.zn_desc)     AS "Dest State/ZIP",
			CASE WHEN MIN(l.orig_zn_cd) = ''ALLUSA'' OR MIN(l.dest_zn_cd)  = ''ALLUSA'' THEN ''Y'' END AS CatchAll,
            MIN(r.efct_dt)        AS "TM Effective Date",
            MAX(r.expd_dt)        AS "TM Expiration Date",
            MIN(rr.brk_amt_dlr)   AS "Rate Per Mile",
            MIN(r.min_chrg_dlr)   AS "Min Charge",
			/*MIN(r.bs_chrg_dlr)    AS "BS Charge",*/
            MIN(r.chrg_cd)        AS "Charge Code",
            RANK() OVER(
                PARTITION BY MIN(l.orig_zn_cd), MIN(l.dest_zn_cd)
                ORDER BY
                    MIN(rr.brk_amt_dlr) ASC, MIN(l.min_chrg_dlr) ASC, MIN(l.tff_id) ASC
            ) AS Rank,
            l.tff_id         AS "Tariff ID",
            t.tff_cd         AS "Tariff Code",
            r.rate_cd        AS "Rate Code",
            r.rate_id        AS "Rate ID",
            current_date     AS "Last Refreshed"
        FROM
            najdaadm.tff_t         t
            LEFT JOIN najdaadm.lane_assc_t   l ON l.tff_id = t.tff_id
            LEFT JOIN najdaadm.rate_t        r ON l.tff_id = r.tff_id
                                            AND l.rate_cd = r.rate_cd
            LEFT JOIN najdaadm.rng_rate_t    rr ON rr.rate_id = r.rate_id
            LEFT JOIN najdaadm.zone_r        org ON l.orig_zn_cd = org.zn_cd
            LEFT JOIN najdaadm.zone_r        dest ON l.dest_zn_cd = dest.zn_cd
            LEFT JOIN najdaadm.carrier_r     c ON t.carr_cd = c.carr_cd
            LEFT JOIN najdaadm.mstr_srvc_t   mst ON l.srvc_cd = mst.srvc_cd
        WHERE
            (r.efct_dt <= SYSDATE OR EXTRACT(YEAR FROM r.efct_dt) = EXTRACT(YEAR FROM SYSDATE))
			AND SUBSTR(l.orig_zn_cd,1,1) NOT IN (''5'',''9'')
            AND r.expd_dt > SYSDATE
            AND (r.chrg_cd = ''MILE'' OR CHRG_CD = ''ZTEM'')
			/*AND t.tff_cd = ''HJBM-KC10-F''
			AND r.rate_cd = ''C10002''*/
		GROUP BY 
			t.carr_cd,
            c.name,
            l.srvc_cd,
            mst.srvc_desc,
            CASE
                WHEN upper(mst.srvc_desc) LIKE ''%INTERMODAL%'' THEN
                    ''INTERMODAL''
                WHEN upper(mst.srvc_desc) LIKE ''%TRAIN%'' THEN
                    ''INTERMODAL''
                WHEN upper(mst.srvc_desc) LIKE ''%TOFC%'' THEN
                    ''INTERMODAL''
                WHEN upper(mst.srvc_desc) LIKE ''%INTERMILL%'' THEN
                    ''INTERMODAL''
                ELSE
                    ''TRUCK''
            END,
			l.tff_id,
            t.tff_cd,
            r.rate_cd,
            r.rate_id
    ) rpm 

ORDER BY
    "Origin Zone Code",
    "Dest Zone Code",
    Shipmode,
    Rank,
    Service') tariffs
	LEFT JOIN USCTTDEV.dbo.tblCarriers ca ON ca.SRVC_CD = tariffs.SERVICE