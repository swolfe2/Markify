SELECT loads.AUDT_LD_LEG_ID,
loads.AUDT_SYS_DTT,
loads.MostRecent,
loads.LD_LEG_ID,
loads.AUDT_CNFG_CD,
loads.LD_CARR_CD,
loads.LD_SRVC_CD,
loads.AuditType,
loads.Count,
loads.STRD_DTT,
loads.CurrentSRVCCD,
loads.EQMT_TYP,
loads.CUR_OPTLSTAT_ID,
loads.STAT_SHRT_DESC,
loads.FRST_SHPG_LOC_CD,
loads.FRST_SHPG_LOC_NAME,
loads.FRST_CTRY_CD,
loads.FRST_STA_CD,
loads.FRST_CTY_NAME,
loads.FRST_PSTL_CD,
loads.LAST_SHPG_LOC_CD,
loads.LAST_SHPG_LOC_NAME,
loads.LAST_CTRY_CD,
loads.LAST_STA_CD,
loads.LAST_CTY_NAME,
loads.LAST_PSTL_CD,
/*loads.ORIG_ZN_CD,
inbZones.ZN_CD,*/
CASE WHEN loads.ORIG_ZN_CD NOT LIKE 'KCIL%' AND inbZones.ZN_CD IS NOT NULL THEN inbZones.ZN_CD ELSE loads.ORIG_ZN_CD END AS ORIGIN_ZONE,
loads.DEST_ZN_CD,
laneAwards.AwardCarriers,
laneAwards.AwardPercent,
loads.CST,
cstCarriers.CSTCarrierCount,
cstCarriers.CSTCarriers,
loads.CST_QUE_DTT,
loads.CST_CPLD_DTT,
loads.CST_USR_CD,
loads.CST_USR_NAME,
loads.AUTO_TDR_STAT_ENU,
CASE WHEN fa.LD_LEG_ID IS NOT NULL THEN 'Y' END AS FreightAuction,
fa.BID_LOAD_ID,
fa.AUCTION_ENTRY_DTT,
fa.FinalLoadParticipation,
fa.BidCount,
fa.EligibleToBidCount,
fa.WinningService,
CASE WHEN origAAO.SHPG_LOC_CD IS NOT NULL THEN 'Y' END AS ORIG_AAO,
origAAO.CHRG_CD AS ORIG_AAO_CD,
origAAO.SRVC_CDS AS ORIG_AAO_SRVC_CD,
CASE WHEN destAAO.SHPG_LOC_CD IS NOT NULL THEN 'Y' END AS DEST_AAO,
destAAO.CHRG_CD AS DEST_AAO_CD,
destAAO.SRVC_CDS AS DEST_AAO_SRVC_CD
FROM OPENQUERY(NAJDAPRD,'SELECT allr.audt_ld_leg_id,
			allr.AUDT_SYS_DTT,
			CASE WHEN allr.audt_ld_leg_id = 
            max(allr.audt_ld_leg_id) keep (dense_rank last order by allr.audt_sys_dtt) over (partition by allr.ld_leg_id)
            THEN ''Most Recent'' END AS MostRecent,
			allr.ld_leg_id,
			allr.audt_cnfg_cd,
			allr.ld_carr_cd,
			allr.ld_srvc_cd,
			CASE 
				WHEN allr.audt_cnfg_cd = ''TENDREJ''
					THEN ''Reject''
				WHEN allr.audt_cnfg_cd = ''TENDACC''
					THEN ''Accept''
				WHEN allr.audt_cnfg_cd = ''TENDCNCL''
					THEN ''Cancel''
				ELSE ''Tender''
				END AS audittype,
			1 AS count,
			CASE 
				WHEN cqr.ld_leg_id IS NOT NULL
					AND cqr.cpld_dtt IS NOT NULL
					THEN ''CST Completed''
				WHEN cqr.ld_leg_id IS NOT NULL
					THEN ''CST Queued''
				ELSE ''NO CST''
				END AS cst,
			cqr.que_dtt AS cst_que_dtt,
			cqr.cpld_dtt AS cst_cpld_dtt,
			cqr.usr_cd AS cst_usr_cd,
			u.name AS cst_usr_name,
			llr.auto_tdr_stat_enu,
			llr.strd_dtt,
			llr.srvc_cd AS currentsrvccd,
			llr.eqmt_typ,
			llr.cur_optlstat_id,
			sr.stat_shrt_desc,
			llr.frst_shpg_loc_cd,
			llr.frst_shpg_loc_name,
			llr.frst_ctry_cd,
			llr.frst_sta_cd,
			llr.frst_cty_name,
			llr.frst_pstl_cd,
			llr.last_shpg_loc_cd,
			llr.last_shpg_loc_name,
			llr.last_ctry_cd,
			llr.last_sta_cd,
			llr.last_cty_name,
			llr.last_pstl_cd,
			lar.orig_zn_cd,
			CASE 
				WHEN llr.last_ctry_cd = ''USA''
					THEN ''5'' || llr.last_sta_cd || substr(llr.last_pstl_cd, 1, 5)
				ELSE lar.dest_zn_cd
				END AS dest_zn_cd,
			CASE WHEN fa.LD_LEG_ID IS NOT NULL THEN ''Y'' END AS FreightAuction,
			fa.AUCTION_ENTRY_DTT,
			fa.AUCTION_STATUS
		FROM najdaadm.load_leg_r llr
		INNER JOIN najdaadm.status_r sr ON sr.stat_id = llr.cur_optlstat_id
		LEFT JOIN najdaadm.lane_association_r lar ON lar.lane_assc_id = llr.lane_assc_id
		LEFT JOIN najdaadm.cst_queue_r cqr ON cqr.ld_leg_id = llr.ld_leg_id
		LEFT JOIN najdaadm.usr_t u ON u.usr_cd = cqr.usr_cd
			AND usr_grp_cd <> ''Terminated''
			AND login_dtt >= sysdate - 14
		INNER JOIN najdaadm.audit_load_leg_r allr ON allr.ld_leg_id = llr.ld_leg_id
		LEFT JOIN (
		SELECT DISTINCT max(AUCTION_ENTRY_DTT) keep (dense_rank last order by BID_LOAD_ID) over (partition by EXTL_LOAD_ID) AUCTION_ENTRY_DTT,
		max(CUR_STAT_ID) keep (dense_rank last order by BID_LOAD_ID) over (partition by EXTL_LOAD_ID) AS AUCTION_STATUS,
		EXTL_LOAD_ID AS LD_LEG_ID
		FROM najdafa.tm_frht_auction_bid_ld_t
		) fa ON fa.LD_LEG_ID = llr.LD_LEG_ID


		WHERE llr.cur_optlstat_id BETWEEN 300
				AND 315
			AND to_date(CASE 
					WHEN llr.shpd_dtt IS NULL
						THEN llr.strd_dtt
					ELSE llr.shpd_dtt
					END) BETWEEN next_day(sysdate - 60, ''Sunday'')
				AND next_day(sysdate + 21, ''Saturday'')
			AND upper(llr.eqmt_typ) IN (''48FT'', ''48TC'', ''53FT'', ''53TC'', ''53IM'', ''53RT'', ''53HC'')
			AND llr.last_ctry_cd IN (''USA'', ''CAN'', ''MEX'')
			AND llr.frst_ctry_cd IN (''USA'', ''CAN'', ''MEX'')
			AND llr.last_shpg_loc_cd NOT LIKE ''LCL%''
			AND substr(allr.audt_cnfg_cd, 1, 4) IN (''TEND'')
') loads


LEFT JOIN USCTTDEV.dbo.tblTMSZones inbZones
ON inbZones.CTRY_CD = loads.FRST_CTRY_CD
AND inbZones.CTY_CD = loads.FRST_CTY_NAME
AND inbZones.STA_CD = loads.FRST_STA_CD
AND inbZones.ZN_CD <> 'ILROMEOV'


LEFT JOIN (
SELECT 
bal.Lane,
bal.LaneID, 
/*bal.AAO,*/
      /* stuff( (SELECT ', '+SCAC 
               FROM USCTTDEV.dbo.tblBidAppRates bar1
			   WHERE bal.LaneID = bar1.LaneID
			    ORDER BY SCAC ASC
               FOR XML PATH(''), TYPE).value('.', 'varchar(max)')
            ,1,1,'')
       AS RateHolders,*/
	          stuff( (SELECT ', '+ CONCAT(SCAC ,' - (',FORMAT(award_pct,'P0'),')')
               FROM USCTTDEV.dbo.tblBidAppRates bar1
			   WHERE bal.LaneID = bar1.LaneID
			   AND bar1.AWARD_PCT IS NOT NULL
			    ORDER BY AWARD_PCT DESC
               FOR XML PATH(''), TYPE).value('.', 'varchar(max)')
            ,1,1,'')
       AS AwardCarriers,
CAST(ROUND(
        SUM((bar.CUR_RPM - (CASE WHEN bar.Equipment = '53IM' THEN .15 ELSE 0 END)) * bar.AWARD_PCT) / SUM(bar.AWARD_PCT), 
        2
      ) AS NUMERIC(18,2)) AS WeightedRPM,
/*CAST(ROUND(
        SUM((arh.[Rate Per Mile] - (CASE WHEN arh.Equipment = '53IM' THEN .15 ELSE 0 END)) * arh.AWARD_PCT) / SUM(arh.AWARD_PCT), 
        2
      )AS NUMERIC(18,2)) AS WeightedRPM,*/
FORMAT(SUM(AWARD_PCT),'P0') AS AwardPercent
FROM USCTTDEV.dbo.tblBidAppLanes bal
INNER JOIN USCTTDEV.dbo.tblBidAppRates bar ON bar.LaneID = bal.LaneID
WHERE bar.AWARD_PCT IS NOT NULL
GROUP BY bal.Lane, bal.LaneID/*, bal.AAO*/
)laneAwards ON laneAwards.Lane =CASE WHEN loads.ORIG_ZN_CD NOT LIKE 'KCIL%' AND inbZones.ZN_CD IS NOT NULL THEN inbZones.ZN_CD ELSE loads.ORIG_ZN_CD END + '-' +
loads.DEST_ZN_CD

LEFT JOIN (
SELECT * FROM OPENQUERY(NAJDAPRD,'
SELECT DISTINCT fablt.BID_LOAD_ID,
fablt.EXTL_LOAD_ID AS LD_LEG_ID,
bids.TotalBids As BidCount,
bids.TotalBidders As EligibleToBidCount,
CASE WHEN bids.TotalBids = 0 THEN ''No Participation''
WHEN awards.BID_LOAD_ID IS NULL THEN ''Not Awarded''
WHEN awards.BID_LOAD_ID IS NOT NULL THEN ''Awarded''
END AS FinalLoadParticipation,
awards.TotalBid AS WinningBid,
awards.CARR_CD AS WinningCarrier,
awards.SRVC_CD AS WinningService,
CASE WHEN fablt.BID_LOAD_ID = max(fablt.BID_LOAD_ID) keep (dense_rank last order by fablt.BID_LOAD_ID) over (partition by fablt.EXTL_LOAD_ID) THEN ''Most Recent'' END AS MostRecent,
fablt.AUCTION_ENTRY_DTT
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
/*ORDER BY facbt.BID_LOAD_ID ASC*/
) bids ON bids.bid_load_id = fablt.BID_LOAD_ID

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
awards.SRVC_CD,
fablt.AUCTION_ENTRY_DTT
')
) fa ON fa.LD_LEG_ID = loads.LD_LEG_ID
AND fa.MostRecent = 'Most Recent'

LEFT JOIN (
SELECT DISTINCT 
aao.SHPG_LOC_CD,
aao.CHRG_CD,
stuff((SELECT distinct ', ' + cast(SRVC_CD as varchar(10))
           FROM USCTTDEV.dbo.tblLaneAAOLocation aao1
           WHERE aao1.SHPG_LOC_CD = aao.SHPG_LOC_CD
		   AND aao1.Eligible = aao.Eligible
		   AND aao1.CHRG_CD = aao.CHRG_CD
           FOR XML PATH('')),1,1,'')  AS SRVC_CDS
FROM USCTTDEV.dbo.tblLaneAAOLocation aao
WHERE aao.Eligible = 'Y'
GROUP BY aao.SHPG_LOC_CD,
aao.CHRG_CD,
aao.Eligible
) origAAO ON origAAO.SHPG_LOC_CD = loads.FRST_SHPG_LOC_CD

LEFT JOIN (
SELECT DISTINCT 
aao.SHPG_LOC_CD,
aao.CHRG_CD,
stuff((SELECT distinct ', ' + cast(SRVC_CD as varchar(10))
           FROM USCTTDEV.dbo.tblLaneAAOLocation aao1
           WHERE aao1.SHPG_LOC_CD = aao.SHPG_LOC_CD
		   AND aao1.Eligible = aao.Eligible
		   AND aao1.CHRG_CD = aao.CHRG_CD
           FOR XML PATH('')),1,1,'')  AS SRVC_CDS
FROM USCTTDEV.dbo.tblLaneAAOLocation aao
WHERE aao.Eligible = 'Y'
GROUP BY aao.SHPG_LOC_CD,
aao.CHRG_CD,
aao.Eligible
) destAAO ON destAAO.SHPG_LOC_CD = loads.LAST_SHPG_LOC_CD

LEFT JOIN(
SELECT carriers.LD_LEG_ID,
LEFT(
	REPLACE(
		RTRIM(
			 SUBSTRING(carriers.CSTCarriers, 12, 10)
			+ SUBSTRING(carriers.CSTCarriers, 33, 10)
			+ SUBSTRING(carriers.CSTCarriers, 54, 10)
			+ SUBSTRING(carriers.CSTCarriers, 75, 10)
			+ SUBSTRING(carriers.CSTCarriers, 96, 10)
			+ SUBSTRING(carriers.CSTCarriers, 117, 10)
			+ SUBSTRING(carriers.CSTCarriers, 138, 10)
			)
		,',',', '),
	LEN(REPLACE(
		RTRIM(
			SUBSTRING(carriers.CSTCarriers, 12, 10)
			+ SUBSTRING(carriers.CSTCarriers, 33, 10)
			+ SUBSTRING(carriers.CSTCarriers, 54, 10)
			+ SUBSTRING(carriers.CSTCarriers, 75, 10)
			+ SUBSTRING(carriers.CSTCarriers, 96, 10)
			+ SUBSTRING(carriers.CSTCarriers, 117, 10)
			+ SUBSTRING(carriers.CSTCarriers, 138, 10)
			)
	,',',', ')) -1)
AS CSTCarriers,
LEN(carriers.CSTCarriers) - LEN(REPLACE(carriers.CSTCarriers,'(','')) AS CSTCarrierCount
FROM(
SELECT LD_LEG_ID,
	REPLACE(
		REPLACE(
			REPLACE(
				REPLACE(
					REPLACE(
						REPLACE(
							REPLACE(
								REPLACE(
									REPLACE(
										REPLACE(
											REPLACE(
												REPLACE(
													REPLACE(
														REPLACE(
															ELGB_CARRS
														, ' ', ',')
													,',,,,,',',')
												,',,,,',',')
											,',,,',',')
										,',,',',')
									,',000A,','(ACC),') /*000A = Accepted */
								,',000R,','(REJ),') /*000R = Rejected */
							,',000C,','(CXL),') /*000C = Cancelled */
						,',000T,','(TDR),') /*000C = Tendered */
					,',000F,','(FLD),') /*000F = Failed */
				,',000P,','(PCT),') /*000P = Exceeds cost percentage threshold */
			,',000S,','(STP),') /*000S = CST Stopped */
		,',000,','(N/A),')  /*000 = NO CST Response */
	,'HUB,', 'HUB ,')
 AS CSTCarriers,
 ELGB_CARRS
FROM
OPENQUERY(NAJDAPRD,'SELECT DISTINCT LD_LEG_ID,
ELGB_CARRS
FROM NAJDAADM.AUTO_TDR_INFO_T atit
WHERE ELGB_CARRS IS NOT NULL
			AND to_date(SCDD_DTT) BETWEEN next_day(sysdate - 60, ''Sunday'')
				AND next_day(sysdate + 21, ''Saturday'')') data
) carriers
) cstCarriers ON cstCarriers.LD_LEG_ID = loads.LD_LEG_ID
ORDER BY loads.LD_LEG_ID ASC, loads.AUDT_SYS_DTT ASC, loads.AUDT_LD_LEG_ID ASC