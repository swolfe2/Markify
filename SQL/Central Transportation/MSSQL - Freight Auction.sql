SELECT Data.*, 
FinalStatus.EligibleToBidCount,
FinalStatus.BidCount,
FinalStatus.FinalLoadParticipation,
FinalStatus.WinningBid,
Region.*,
Awards.*,
tariffs.*,
laneAwards.*,
carrier.*,
actuals.ActualCarrier,
actuals.ActualService,
actuals.ActualStatus

FROM OPENQUERY(NAJDAPRD,'SELECT 
fablt.SYSTEM_ID,
fablt.EXTL_LOAD_ID AS LD_LEG_ID,
fablt.BID_LOAD_ID,
fablt.CUR_STAT_ID,
fablt.BID_PEND_YN,
fablt.SUSPEND_YN,
fablt.AUCTION_TYPE,
fablt.ORI_SITE_ID,
fablt.AUCTION_ELIGIBLE_ENU,
fablt.SCHD_PKUP_DTT,
fablt.AUCTION_PKUP_DTT,
fablt.AUCTION_ENTRY_DTT,
fablt.AUCTION_ALERT_DTT,
fablt.CURR_SLOT_INDEX,
fablt.MSG_ID,
fablt.NUM_ROUNDS_ADJUSTED,
fablt.MANUAL_AWARD_YN,
fablt.TDR_ACPD_BY_NAME,
fablt.TOT_SHPM,
fablt.TOT_PCE,
fablt.TOT_SKID,
fablt.TOT_SCLD_WGT,
fablt.TOT_VOL,
fablt.TOT_DIST,
fablt.STRD_DTT,
fablt.END_DTT,
fablt.CRTD_DTT,
fablt.UPDT_DTT,
fablt.CRTD_USR_CD,
fablt.UPDT_USR_CD,
facbt.BID_ACTION_DTT,
facbt.BID_RESPONSE_DTT,
facbt.BID_RESPONSE_ENU,
facbt.RATE_ADJ_AMT_DLR,
facbt.RATE_ADJ_AWARD_AMT_DLR,
CASE WHEN facbt.RATE_ADJ_AWARD_AMT_DLR IS NULL THEN facbt.RATE_ADJ_AMT_DLR ELSE facbt.RATE_ADJ_AWARD_AMT_DLR END + facbt.CONTRACT_AMT_DLR AS TotalBid,
CASE WHEN facbt.BID_ACTION_DTT IS NOT NULL AND facbt.BID_RESPONSE_ENU = ''LOAD_AWARDED'' THEN ''Awarded''
WHEN facbt.BID_ACTION_DTT IS NOT NULL AND (CASE WHEN facbt.RATE_ADJ_AWARD_AMT_DLR IS NULL THEN facbt.RATE_ADJ_AMT_DLR ELSE facbt.RATE_ADJ_AWARD_AMT_DLR END + facbt.CONTRACT_AMT_DLR) IS NOT NULL THEN ''Participated''
WHEN facbt.BID_ACTION_DTT IS NOT NULL AND (facbt.BID_RESPONSE_ENU IS NULL OR facbt.BID_RESPONSE_ENU = ''LOAD_REMOVED'') THEN ''Declined''
ELSE ''Did Not Participate'' END AS Participation,
fablt.ORI_SHPG_LOC_CD,
fablt.ORI_LOC_DESC,
fablt.ORI_LOC_CTRY_CD,
fablt.ORI_LOC_STA_CD,
fablt.ORI_LOC_CTY_NAME,
fablt.ORI_LOC_PSTL_CD,
rmrf.CORP1_ID,
fablt.DEST_SHPG_LOC_CD,
fablt.DEST_LOC_DESC,
fablt.DEST_LOC_CTRY_CD,
fablt.DEST_LOC_CTY_NAME,
fablt.DEST_LOC_STA_CD,
fablt.DEST_LOC_PSTL_CD,
CASE WHEN rmrf.CORP1_ID = ''RM'' THEN ''RM-INBOUND''
WHEN rmrf.CORP1_ID = ''RF'' THEN ''RF-INBOUND'' 
WHEN SUBSTR(DEST_SHPG_LOC_CD,1,1) = ''R'' THEN ''RETURNS''
WHEN SUBSTR(DEST_SHPG_LOC_CD,1,1) = ''1'' THEN ''INTERMILL''
WHEN SUBSTR(DEST_SHPG_LOC_CD,1,1) = ''2'' THEN ''INTERMILL''
WHEN SUBSTR(DEST_SHPG_LOC_CD,1,1) = ''5'' THEN ''CUSTOMER''
WHEN SUBSTR(DEST_SHPG_LOC_CD,1,1) = ''9'' THEN ''CUSTOMER''
ELSE NULL END AS OrderType,
CASE WHEN rmrf.CORP1_ID = ''RM'' THEN fablt.DEST_LOC_STA_CD
WHEN rmrf.CORP1_ID = ''RF'' THEN fablt.DEST_LOC_STA_CD
ELSE fablt.ORI_LOC_STA_CD END AS RegionJoinState,
facbt.COST_VAR_EXCD_YN,
facbt.CARR_CD,
facbt.CARR_DESC,
facbt.SRVC_CD,
facbt.SRVC_DESC,
facbt.EQMT_TYP,
facbt.TFF_ID,
facbt.RATE_CD,
facbt.CONTRACT_AMT_DLR,
facbt.COST_POINTS,
facbt.PERF_POINTS
FROM najdafa.tm_frht_auction_bid_ld_t fablt
INNER JOIN najdafa.tm_frht_auction_car_bid_t facbt ON facbt.bid_load_id = fablt.bid_load_id

LEFT JOIN (
SELECT lar.shpg_loc_cd,  
lar.corp1_id
FROM najdaadm.load_at_r lar
WHERE lar.corp1_id IN (''RM'',''RF'')
) rmrf ON rmrf.shpg_loc_cd = fablt.ORI_SHPG_LOC_CD
WHERE fablt.AUCTION_ENTRY_DTT >= ''2020-03-01''

ORDER BY fablt.bid_load_id ASC, facbt.bid_id asc')Data

/*
Final load status query
*/
LEFT JOIN (
SELECT * FROM OPENQUERY(NAJDAPRD,'SELECT DISTINCT fablt.BID_LOAD_ID,
fablt.EXTL_LOAD_ID AS LD_LEG_ID,
bids.TotalBids As BidCount,
bids.TotalBidders As EligibleToBidCount,
CASE WHEN bids.TotalBids = 0 THEN ''No Participation''
WHEN awards.BID_LOAD_ID IS NULL THEN ''Not Awarded''
WHEN awards.BID_LOAD_ID IS NOT NULL THEN ''Awarded''
END AS FinalLoadParticipation,
awards.TotalBid AS WinningBid,
awards.CARR_CD AS WinningCarrier,
awards.SRVC_CD AS WinningService
FROM najdafa.tm_frht_auction_bid_ld_t fablt
/*
This query contains all of the details about awarded loads
*/
LEFT JOIN (
SELECT DISTINCT facbt.BID_LOAD_ID, 
fablt.EXTL_LOAD_ID AS LD_LEG_ID,
facbt.BID_RESPONSE_ENU,
facbt.RATE_ADJ_AMT_DLR,
facbt.RATE_ADJ_AWARD_AMT_DLR,
facbt.CONTRACT_AMT_DLR,
CASE WHEN facbt.RATE_ADJ_AWARD_AMT_DLR IS NULL THEN facbt.RATE_ADJ_AMT_DLR ELSE facbt.RATE_ADJ_AWARD_AMT_DLR END + facbt.CONTRACT_AMT_DLR AS TotalBid,
facbt.CARR_CD,
facbt.SRVC_CD,
Options.TotalBidders
FROM najdafa.tm_frht_auction_car_bid_t facbt
INNER JOIN najdafa.tm_frht_auction_bid_ld_t fablt ON fablt.bid_load_id = facbt.bid_load_id
LEFT JOIN (SELECT DISTINCT facbt.BID_LOAD_ID, COUNT(*) AS TotalBidders
FROM najdafa.tm_frht_auction_car_bid_t facbt
WHERE facbt.BID_RESPONSE_ENU IS NOT NULL
GROUP BY facbt.BID_LOAD_ID) Options ON Options.BID_LOAD_ID = facbt.BID_LOAD_ID
WHERE facbt.BID_RESPONSE_ENU = ''LOAD_AWARDED''
)awards ON awards.bid_load_id = fablt.BID_LOAD_ID
AND awards.LD_LEG_ID = fablt.EXTL_LOAD_ID

/*
This query contains the total bid/participation count
*/
LEFT JOIN(
SELECT DISTINCT facbt.BID_LOAD_ID, 
COUNT(*) AS TotalBidders,
SUM(CASE WHEN facbt.RATE_ADJ_AMT_DLR IS NOT NULL THEN 1
WHEN facbt.RATE_ADJ_AWARD_AMT_DLR IS NOT NULL THEN 1
ELSE 0 END) AS TotalBids
FROM najdafa.tm_frht_auction_car_bid_t facbt
GROUP BY facbt.BID_LOAD_ID
ORDER BY facbt.BID_LOAD_ID ASC
) bids ON bids.bid_load_id = fablt.BID_LOAD_ID

WHERE fablt.AUCTION_ENTRY_DTT >= ''2020-03-01''

GROUP BY 
fablt.BID_LOAD_ID,
fablt.EXTL_LOAD_ID,
CASE WHEN awards.BID_LOAD_ID IS NOT NULL THEN awards.TotalBidders END,
bids.TotalBids,
bids.TotalBidders,
CASE WHEN bids.TotalBids = 0 THEN ''No Participation''
WHEN awards.BID_LOAD_ID IS NULL THEN ''Not Awarded''
WHEN awards.BID_LOAD_ID IS NOT NULL THEN ''Awarded''
END,
awards.TotalBid,
awards.CARR_CD,
awards.SRVC_CD')FinalStatus
)FinalStatus ON FinalStatus.BID_LOAD_ID = data.BID_LOAD_ID

/*
Get region names
*/
LEFT JOIN(
SELECT Country AS RegionCountry,
StateName AS RegionStateName,
StateAbbv AS RegionState,
Region,
CarrierManager
FROM USCTTDEV.dbo.tblRegionalAssignments
)region ON region.RegionState = data.RegionJoinState

/*
Awarded load details
*/
LEFT JOIN(
SELECT * FROM OPENQUERY(NAJDAPRD,'SELECT DISTINCT BID_LOAD_ID, 
COUNT(DISTINCT SRVC_CD) as EligibleSCACCount, 
SUM(CASE WHEN RATE_ADJ_AMT_DLR IS NOT NULL THEN 1 END) as UniqueBids, 
SUM(CASE WHEN BID_RESPONSE_ENU = ''LOAD_AWARDED'' THEN 1 END) AS WinningBids,
MIN(CASE WHEN RATE_ADJ_AWARD_AMT_DLR IS NULL THEN RATE_ADJ_AMT_DLR ELSE RATE_ADJ_AWARD_AMT_DLR END) AS LowestBidAdjustment,
MIN(CASE WHEN RATE_ADJ_AWARD_AMT_DLR IS NULL THEN RATE_ADJ_AMT_DLR ELSE RATE_ADJ_AWARD_AMT_DLR END + CONTRACT_AMT_DLR ) AS LowestBid,
MIN(CASE WHEN BID_RESPONSE_ENU = ''LOAD_AWARDED'' THEN BID_RESPONSE_USR_CD END) AS AcceptedByUser,
MIN(CASE WHEN BID_RESPONSE_ENU = ''LOAD_AWARDED'' THEN BID_RESPONSE_DTT END) AS AcceptedOnDate,
MIN(CASE WHEN BID_RESPONSE_ENU = ''LOAD_AWARDED'' THEN CARR_CD END) AS AwardedCarrier,
MIN(CASE WHEN BID_RESPONSE_ENU = ''LOAD_AWARDED'' THEN CARR_DESC END) AS AwardedCarrierDesc,
MIN(CASE WHEN BID_RESPONSE_ENU = ''LOAD_AWARDED'' THEN SRVC_CD END) AS AwardedSCAC,
MIN(CASE WHEN BID_RESPONSE_ENU = ''LOAD_AWARDED'' THEN SRVC_DESC END) AS AwardedSCACDesc,
MIN(CASE WHEN BID_RESPONSE_ENU = ''LOAD_AWARDED'' THEN EQMT_TYP END) AS AwardedEquipment,
MIN(CASE WHEN BID_RESPONSE_ENU = ''LOAD_AWARDED'' THEN CASE WHEN RATE_ADJ_AWARD_AMT_DLR IS NULL THEN RATE_ADJ_AMT_DLR ELSE RATE_ADJ_AWARD_AMT_DLR END END + CONTRACT_AMT_DLR) AS AwardedCost,
MIN(CASE WHEN BID_RESPONSE_ENU = ''LOAD_AWARDED'' THEN TFF_ID END) AS AwardedTariff,
MIN(CASE WHEN BID_RESPONSE_ENU = ''LOAD_AWARDED'' THEN RATE_CD END) AS AwardedRateCd,
MIN(CASE WHEN BID_RESPONSE_ENU = ''LOAD_AWARDED'' THEN CONTRACT_AMT_DLR END) AS AwardedContractAmt
FROM najdafa.tm_frht_auction_car_bid_t facbt
GROUP BY BID_LOAD_ID
ORDER BY BID_LOAD_ID ASC'))Awards ON awards.BID_LOAD_ID = data.BID_LOAD_ID
AND awards.AwardedSCAC = data.SRVC_CD

/*
Tariff Query
*/
LEFT JOIN(
SELECT * FROM OPENQUERY(NAJDAPRD,'SELECT
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
            MIN(r.efct_dt)        AS "TM Effective Date",
            MAX(r.expd_dt)        AS "TM Expiration Date",
            MIN(rr.brk_amt_dlr)   AS "Rate Per Mile",
            MIN(r.min_chrg_dlr)   AS "Min Charge",
			MIN(r.bs_chrg_dlr)    AS "BS Charge",
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
    Service')) tariffs ON tariffs.[Tariff Code] = awards.AwardedTariff
	AND tariffs.[Rate Code] = awards.AwardedRateCD
	AND tariffs.service = data.SRVC_CD
	AND tariffs.SHIPMODE = (CASE WHEN data.EQMT_TYP = '53IM' THEN 'INTERMODAL' ELSE 'TRUCK' END)
	AND tariffs.[TM Effective Date] <= data.[AUCTION_ENTRY_DTT]
	AND tariffs.[TM Expiration Date] > data.[AUCTION_ENTRY_DTT]

LEFT JOIN (
SELECT DISTINCT arh.Lane,
arh.LaneID,
/*arh.Mode,
arh.Equipment,*/
CAST(ROUND(
        SUM((arh.CUR_RPM - (CASE WHEN arh.Equipment = '53IM' THEN .15 ELSE 0 END)) * arh.AWARD_PCT) / SUM(arh.AWARD_PCT), 
        2
      ) AS NUMERIC(18,2)) AS WeightedRPM,
/*CAST(ROUND(
        SUM((arh.[Rate Per Mile] - (CASE WHEN arh.Equipment = '53IM' THEN .15 ELSE 0 END)) * arh.AWARD_PCT) / SUM(arh.AWARD_PCT), 
        2
      )AS NUMERIC(18,2)) AS WeightedRPM,*/
SUM(AWARD_PCT) AS AwardPercent,
MIN(dates.EffectiveDate) AS EffectiveDate,
dates.ExpirationDate
FROM USCTTDEV.dbo.tblAwardRatesHistorical arh
INNER JOIN (
SELECT DISTINCT
  arh.Lane,
  arh.EffectiveDate,
  MAX(Expiration.ExpirationDate) AS ExpirationDate
FROM USCTTDEV.dbo.tblAwardRatesHistorical arh
INNER JOIN (SELECT DISTINCT
  Lane,
  EffectiveDate,
  ExpirationDate
FROM USCTTDEV.dbo.tblAwardRatesHistorical) Expiration
  ON arh.Lane = Expiration.Lane
  AND arh.EffectiveDate = Expiration.EffectiveDate
  AND arh.ExpirationDate <= Expiration.ExpirationDate
  AND arh.EffectiveDate <= Expiration.ExpirationDate
GROUP BY arh.Lane,
         arh.EffectiveDate,
         expiration.EffectiveDate
)dates ON dates.Lane = arh.Lane
/*AND arh.EffectiveDate >= dates.EffectiveDate
AND arh.ExpirationDate <= dates.ExpirationDate*/
AND arh.ExpirationDate BETWEEN dates.EffectiveDate AND dates.ExpirationDate 
WHERE arh.ExpirationDate >= '2/1/2020'
--AND arh.LANE = 'GAAUGUST-5FL33811'
GROUP BY arh.Lane,
arh.LaneID,
/*arh.Mode,
arh.Equipment,*/
dates.ExpirationDate
--ORDER BY Lane ASC, EffectiveDate ASC, ExpirationDate ASC
)laneAwards ON laneAwards.Lane = tariffs.[Origin Zone Code] + '-' + tariffs.[Dest Zone Code]
--AND awards.AwardedEquipment = laneAwards.EQUIPMENT
AND CAST(Data.AUCTION_PKUP_DTT AS DATE) >= laneAwards.EffectiveDate
AND CAST(Data.AUCTION_PKUP_DTT AS DATE) <= laneAwards.ExpirationDate

/*
This gets individual carrier details
*/
LEFT JOIN (
SELECT * FROM USCTTDEV.dbo.tblCarriers
) carrier ON data.CARR_CD = carrier.CARR_CD
AND data.SRVC_CD = carrier.SRVC_CD

/*
This compares who won the award to who actually took the load
*/
LEFT JOIN(
SELECT DISTINCT CAST(ald.LD_LEG_ID AS NUMERIC(18,2)) AS ActualLoad, 
ald.CARR_CD AS ActualCarrier,
ald.SRVC_CD AS ActualService,
ald.STATUS AS ActualStatus,
ald.STATUS AS ActualStatus,
CAST(ald.STRD_DTT AS DATE) AS StartDate,
CAST(ald.SHPD_DTT AS DATE) AS ShipDate,
ald.FIXD_ITNR_DIST,
ald.PreRate_Linehaul,
ald.PreRate_Fuel,
ald.PreRateCharge,
ald.Act_Linehaul,
ald.Act_Fuel,
ald.ActualRateCharge
FROM USCTTDEV.dbo.tblActualLoadDetail ald
WHERE CAST(ald.SHPD_DTT AS DATE) > '3/1/2020'
OR ald.SHPD_DTT IS NULL
) actuals ON actuals.ActualLoad = data.LD_LEG_ID

WHERE data.AUCTION_ENTRY_DTT >= '2020-03-01'
AND data.LD_LEG_ID = '518925004'
ORDER BY data.BID_LOAD_ID ASC
