SELECT * FROM OPENQUERY(NAJDAQAX,'SELECT 
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
WHEN facbt.BID_ACTION_DTT IS NOT NULL THEN ''Participated''
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
CASE WHEN rmrf.CORP1_ID = ''RM'' THEN ''fablt.DEST_LOC_STA_CD''
WHEN rmrf.CORP1_ID = ''RF'' THEN ''fablt.DEST_LOC_STA_CD'' 
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
ORDER BY fablt.bid_load_id ASC, facbt.bid_id asc')Data