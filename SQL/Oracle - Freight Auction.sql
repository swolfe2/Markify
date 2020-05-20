SELECT DISTINCT fablt.BID_LOAD_ID, 
fablt.CUR_STAT_ID, 
fablt.BID_PEND_YN, 
fablt.SUSPEND_YN, 
fablt.ORI_SITE_ID, 
fablt.AUCTION_PKUP_DTT, 
TRUNC(fablt.AUCTION_PKUP_DTT) as AuctionDate,
fablt.MSG_ID,
fablt.ORI_SHPG_LOC_CD,
fablt.ORI_LOC_DESC,
fablt.ORI_LOC_CTRY_CD,
fablt.ORI_LOC_STA_CD,
fablt.ORI_LOC_CTY_NAME,
fablt.ORI_LOC_PSTL_CD,
fablt.DEST_SHPG_LOC_CD,
fablt.DEST_LOC_DESC,
fablt.DEST_LOC_CTRY_CD,
fablt.DEST_LOC_CTY_NAME,
fablt.DEST_LOC_STA_CD,
fablt.DEST_LOC_PSTL_CD,
fablt.EXTL_LOAD_ID,
fablt.TOT_SHPM,
fablt.TOT_PCE,
fablt.TOT_SCLD_WGT,
fablt.TOT_VOL,
fablt.TOT_DIST,
fablt.CRTD_DTT,
fablt.CRTD_USR_CD,
fablt.UPDT_DTT,
fablt.UPDT_USR_CD,
bids.UniqueBids,
bids.UniqueSCAC,
bids.WinningBids,
bids.LowestBid,
bids.AcceptedByUser,
bids.AcceptedOnDate,
bids.AwardedCarrier,
bids.AwardedCarrierDesc,
bids.AwardedSCAC,
bids.AwardedSCACDesc,
bids.AwardedEquipment,
bids.AwardedCost,
bids.AwardedTariff,
bids.AwardedRateCd,
bids.AwardedContractAmt,
tariffs."Origin Zone Code",
tariffs."Dest Zone Code",
CAST(tariffs."Rate Per Mile" AS NUMBER(18,2)) AS "Rate Per Mile",
tariffs.Rank
FROM najdafa.TM_FRHT_AUCTION_BID_LD_T fablt

INNER JOIN(
SELECT DISTINCT BID_LOAD_ID, 
COUNT(BID_ID) as UniqueBids, 
COUNT(DISTINCT SRVC_CD) as UniqueSCAC, 
SUM(CASE WHEN BID_RESPONSE_ENU = 'LOAD_AWARDED' THEN 1 END) AS WinningBids,
MIN(RATE_ADJ_AWARD_AMT_DLR) AS LowestBid,
MIN(CASE WHEN BID_RESPONSE_ENU = 'LOAD_AWARDED' THEN BID_RESPONSE_USR_CD END) AS AcceptedByUser,
MIN(CASE WHEN BID_RESPONSE_ENU = 'LOAD_AWARDED' THEN BID_RESPONSE_DTT END) AS AcceptedOnDate,
MIN(CASE WHEN BID_RESPONSE_ENU = 'LOAD_AWARDED' THEN CARR_CD END) AS AwardedCarrier,
MIN(CASE WHEN BID_RESPONSE_ENU = 'LOAD_AWARDED' THEN CARR_DESC END) AS AwardedCarrierDesc,
MIN(CASE WHEN BID_RESPONSE_ENU = 'LOAD_AWARDED' THEN SRVC_CD END) AS AwardedSCAC,
MIN(CASE WHEN BID_RESPONSE_ENU = 'LOAD_AWARDED' THEN SRVC_DESC END) AS AwardedSCACDesc,
MIN(CASE WHEN BID_RESPONSE_ENU = 'LOAD_AWARDED' THEN EQMT_TYP END) AS AwardedEquipment,
MIN(CASE WHEN BID_RESPONSE_ENU = 'LOAD_AWARDED' THEN RATE_ADJ_AWARD_AMT_DLR END) AS AwardedCost,
MIN(CASE WHEN BID_RESPONSE_ENU = 'LOAD_AWARDED' THEN TFF_ID END) AS AwardedTariff,
MIN(CASE WHEN BID_RESPONSE_ENU = 'LOAD_AWARDED' THEN RATE_CD END) AS AwardedRateCd,
MIN(CASE WHEN BID_RESPONSE_ENU = 'LOAD_AWARDED' THEN CONTRACT_AMT_DLR END) AS AwardedContractAmt
FROM najdafa.tm_frht_auction_car_bid_t facbt
GROUP BY BID_LOAD_ID) bids ON bids.BID_LOAD_ID = fablt.BID_LOAD_ID

LEFT JOIN (
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
            --AND upper(mst.srvc_desc) NOT LIKE '%INTERMODAL%'
            AND upper(mst.srvc_desc) NOT LIKE '%TRAIN%'
            AND upper(mst.srvc_desc) NOT LIKE '%TOFC%'
            AND upper(mst.srvc_desc) NOT LIKE '%INTERMILL%'
    --AND mst.srvc_desc NOT LIKE '%TRAIN%' AND mst.srvc_desc NOT LIKE '%TOFC%' AND mst.srvc_desc NOT LIKE '%INTERMILL%'
    )/*
WHERE
    rank <= 5*/
)tariffs on tariffs."Tariff Code" = bids.AwardedTariff
AND tariffs."Rate Code" = bids.AwardedRateCd
--AND fablt.AUCTION_PKUP_DTT BETWEEN tariffs."TM Effective Date" AND tariffs."TM Expiration Date"

ORDER BY fablt.BID_LOAD_ID ASC
