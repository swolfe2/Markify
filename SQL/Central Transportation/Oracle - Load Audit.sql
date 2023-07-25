SELECT DISTINCT ld_leg_id,
	cst,
	cst_que_dtt,
	cst_cpld_dtt,
	cst_usr_cd,
	cst_usr_name,
	auto_tdr_stat_enu,
	strd_dtt,
	currentsrvccd,
	eqmt_typ,
	cur_optlstat_id,
	stat_shrt_desc,
	frst_shpg_loc_cd,
	frst_shpg_loc_name,
	frst_ctry_cd,
	frst_sta_cd,
	frst_pstl_cd,
	last_shpg_loc_cd,
	last_shpg_loc_name,
	last_ctry_cd,
	last_sta_cd,
	last_pstl_cd,
	orig_zn_cd,
	dest_zn_cd,
	MAX(CASE 
			WHEN audittype = 'Tender'
				THEN description
			END) AS tender,
	MAX(CASE 
			WHEN audittype = 'Tender'
				THEN regexp_count(description, ',')
			END) + 1 AS tendercount,
	MAX(CASE 
			WHEN audittype = 'Reject'
				THEN description
			END) AS reject,
	MAX(CASE 
			WHEN audittype = 'Reject'
				THEN regexp_count(description, ',')
			END) + 1 AS rejectcount,
	MAX(CASE 
			WHEN audittype = 'Cancel'
				THEN description
			END) AS cancel,
	MAX(CASE 
			WHEN audittype = 'Cancel'
				THEN regexp_count(description, ',')
			END) + 1 AS cancelcount,
	MAX(CASE 
			WHEN audittype = 'Accept'
				THEN description
			END) AS accept,
	MAX(CASE 
			WHEN audittype = 'Accept'
				THEN regexp_count(description, ',')
			END) + 1 AS acceptcount
FROM (
	SELECT ld_leg_id,
		audittype,
		LISTAGG(ld_srvc_cd, ', ') WITHIN
	GROUP (
			ORDER BY audt_ld_leg_id
			) AS description,
		cst,
		cst_que_dtt,
		cst_cpld_dtt,
		cst_usr_cd,
		cst_usr_name,
		auto_tdr_stat_enu,
		strd_dtt,
		currentsrvccd,
		eqmt_typ,
		cur_optlstat_id,
		stat_shrt_desc,
		frst_shpg_loc_cd,
		frst_shpg_loc_name,
		frst_ctry_cd,
		frst_sta_cd,
		frst_pstl_cd,
		last_shpg_loc_cd,
		last_shpg_loc_name,
		last_ctry_cd,
		last_sta_cd,
		last_pstl_cd,
		orig_zn_cd,
		dest_zn_cd
	FROM (
		SELECT allr.audt_ld_leg_id,
			allr.ld_leg_id,
			allr.audt_cnfg_cd,
			allr.ld_carr_cd,
			allr.ld_srvc_cd,
			CASE 
				WHEN allr.audt_cnfg_cd = 'TENDREJ'
					THEN 'Reject'
				WHEN allr.audt_cnfg_cd = 'TENDACC'
					THEN 'Accept'
				WHEN allr.audt_cnfg_cd = 'TENDCNCL'
					THEN 'Cancel'
				ELSE 'Tender'
				END AS audittype,
			1 AS count,
			CASE 
				WHEN cqr.ld_leg_id IS NOT NULL
					AND cqr.cpld_dtt IS NOT NULL
					THEN 'CST Completed'
				WHEN cqr.ld_leg_id IS NOT NULL
					THEN 'CST Queued'
				ELSE 'NO CST'
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
			llr.frst_pstl_cd,
			llr.last_shpg_loc_cd,
			llr.last_shpg_loc_name,
			llr.last_ctry_cd,
			llr.last_sta_cd,
			llr.last_pstl_cd,
			lar.orig_zn_cd,
			CASE 
				WHEN llr.last_ctry_cd = 'USA'
					THEN '5' || llr.last_sta_cd || substr(llr.last_pstl_cd, 1, 5)
				ELSE lar.dest_zn_cd
				END AS dest_zn_cd
		FROM najdaadm.load_leg_r llr
		INNER JOIN najdaadm.status_r sr ON sr.stat_id = llr.cur_optlstat_id
		LEFT JOIN najdaadm.lane_association_r lar ON lar.lane_assc_id = llr.lane_assc_id
		LEFT JOIN najdaadm.cst_queue_r cqr ON cqr.ld_leg_id = llr.ld_leg_id
		LEFT JOIN najdaadm.usr_t u ON u.usr_cd = cqr.usr_cd
			AND usr_grp_cd <> 'Terminated'
			AND login_dtt >= sysdate - 14
		INNER JOIN najdaadm.audit_load_leg_r allr ON allr.ld_leg_id = llr.ld_leg_id
		WHERE llr.cur_optlstat_id BETWEEN 300
				AND 315
			AND to_date(CASE 
					WHEN llr.shpd_dtt IS NULL
						THEN llr.strd_dtt
					ELSE llr.shpd_dtt
					END) BETWEEN next_day(sysdate - 8, 'Sunday')
				AND next_day(sysdate + 7, 'Saturday')
			AND upper(llr.eqmt_typ) IN ('48FT', '48TC', '53FT', '53TC', '53IM', '53RT', '53HC', 'LTL')
			AND llr.last_ctry_cd IN ('USA', 'CAN', 'MEX')
			AND llr.frst_ctry_cd IN ('USA', 'CAN', 'MEX')
			AND llr.last_shpg_loc_cd NOT LIKE 'LCL%'
			AND substr(allr.audt_cnfg_cd, 1, 4) IN ('TEND')
		) data
	GROUP BY ld_leg_id,
		audittype,
		cst,
		cst_que_dtt,
		cst_cpld_dtt,
		cst_usr_cd,
		cst_usr_name,
		auto_tdr_stat_enu,
		strd_dtt,
		currentsrvccd,
		eqmt_typ,
		cur_optlstat_id,
		stat_shrt_desc,
		frst_shpg_loc_cd,
		frst_shpg_loc_name,
		frst_ctry_cd,
		frst_sta_cd,
		frst_pstl_cd,
		last_shpg_loc_cd,
		last_shpg_loc_name,
		last_ctry_cd,
		last_sta_cd,
		last_pstl_cd,
		orig_zn_cd,
		dest_zn_cd
	) data
GROUP BY ld_leg_id,
	cst,
	cst_que_dtt,
	cst_cpld_dtt,
	cst_usr_cd,
	cst_usr_name,
	auto_tdr_stat_enu,
	strd_dtt,
	currentsrvccd,
	eqmt_typ,
	cur_optlstat_id,
	stat_shrt_desc,
	frst_shpg_loc_cd,
	frst_shpg_loc_name,
	frst_ctry_cd,
	frst_sta_cd,
	frst_pstl_cd,
	last_shpg_loc_cd,
	last_shpg_loc_name,
	last_ctry_cd,
	last_sta_cd,
	last_pstl_cd,
	orig_zn_cd,
	dest_zn_cd
	/*
SELECT DISTINCT SCAC_TYP, 
    LISTAGG(CARR_CD, ', ') WITHIN GROUP(ORDER BY CARR_CD) AS description,
    COUNT(*) AS RecordCount
FROM NAJDAADM.CARRIER_R
GROUP BY SCAC_TYP
HAVING COUNT(*) > 1

SELECT DISTINCT SCAC_TYP, 
    RTRIM(RTRIM(REPLACE(REPLACE(XMLAgg(XMLElement("x", CARR_CD) ORDER BY CARR_CD), '<x>'), '</x>', ', ')), ', ') AS description,
    COUNT(*) AS RecordCount
FROM NAJDAADM.CARRIER_R
GROUP BY SCAC_TYP
HAVING COUNT(*) > 1
*/

/*
SELECT carriers.LD_LEG_ID,

LEFT(
	REPLACE(
		RTRIM(
			 SUBSTRING(carriers.Carriers, 12, 10)
			+ SUBSTRING(carriers.Carriers, 33, 10)
			+ SUBSTRING(carriers.Carriers, 54, 10)
			+ SUBSTRING(carriers.Carriers, 75, 10)
			+ SUBSTRING(carriers.Carriers, 96, 10)
			+ SUBSTRING(carriers.Carriers, 117, 10)
			+ SUBSTRING(carriers.Carriers, 138, 10)
			)
		,',',', '),
	LEN(REPLACE(
		RTRIM(
			SUBSTRING(carriers.Carriers, 12, 10)
			+ SUBSTRING(carriers.Carriers, 33, 10)
			+ SUBSTRING(carriers.Carriers, 54, 10)
			+ SUBSTRING(carriers.Carriers, 75, 10)
			+ SUBSTRING(carriers.Carriers, 96, 10)
			+ SUBSTRING(carriers.Carriers, 117, 10)
			+ SUBSTRING(carriers.Carriers, 138, 10)
			)
		,',',', ')) -1)
AS Carriers,
LEN(carriers.Carriers) - LEN(REPLACE(carriers.Carriers,'(','')) AS CSTCarrierCount
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
				,',000P,','(PCT),') /*000P = Unknown? */
			,',000S,','(STP),') /*000S = Unknown? */
		,',000,','(N/A),')  /*000 = Unknown? */
	,'HUB,', 'HUB ,')
 AS Carriers,
 ELGB_CARRS
FROM
OPENQUERY(NAJDAPRD,'SELECT DISTINCT LD_LEG_ID,
ELGB_CARRS
FROM NAJDAADM.AUTO_TDR_INFO_T atit
WHERE ELGB_CARRS IS NOT NULL
			AND to_date(SCDD_DTT) BETWEEN next_day(sysdate - 8, ''Sunday'')
				AND next_day(sysdate + 7, ''Saturday'')') data
) carriers
*/
