/*
Delete Temp tables, if exists
*/
DROP TABLE IF EXISTS 
##tblManuallyTouchedDetails,
##tblManuallyTouchedAggregate,
--##tblSuggestedAppointments, -- Per meeting with John Crumpton on 11/26, do not need. Commenting out!
--##tblConfirmPickedAppointments, -- Per meeting with John Crumpton on 11/26, do not need. Commenting out!
##tblLoadLegDetails,
##tblLightsOutPlanned, --if LD is on table, then "Yes, went through". Then, give status / status desc / UserID ---- PLNDStatus, PLNDStatusDesc, PLNDUserID
##tblLightsOutTendered, --if LD is on table, then "Yes, went through". Then, give status / status desc / UserID ---- TDRStatus, TDRStatusDesc, TDRUserID
--##tblOptimizationDetails, -- Per meeting with John Crumpton on 11/26, do not need. Commenting out!
##tblBusinessUnits,
##tblActualLoadDetailsRFT, -- Total number of touches
##tblManuallyTouchedPivot, -- Dynamically pivoted counts of each reason by Load number
##tblManuallyTouchedHighLevel -- High level count of load numbers, and count of times processed

/*
Declare query variable, since query is more than 8,000 characters
*/
DECLARE @myQuery VARCHAR(MAX)

/*
Get unique manually touched details for loads
SELECT * FROM ##tblManuallyTouchedDetails WHERE LOADNUMBER = '518207369'

SELECT DISTINCT LOADNUMBER, 
SUM(LoadCount) AS TimesTouched, 
Reason, 
Ordinal, 
Count(Distinct USER_LOGIN) as UserCount 
FROM ##tblManuallyTouchedDetails 
WHERE LOADNUMBER = '518207369'
GROUP BY LOADNUMBER, Reason, Ordinal

*/
SELECT * INTO ##tblManuallyTouchedDetails FROM OPENQUERY(NAJDABAP,'SELECT DISTINCT
	IA_DIST_LOADS.LOAD_ID as LoadNumber, 
	Count(distinct IA_DIST_LOADS.EVENT_LOG_DT) as LoadCount,    
    CASE WHEN IA_EXCEPTION_CODE.EXCEPTION_CODE=''ACPD'' THEN ''MANUALLY ACCEPTED''
    WHEN IA_EVNT_TYPE.EVNT_TYPE_CODE=''TENDCNCL'' AND	IA_EXCEPTION_CODE.EXCEPTION_CODE=''PLND'' THEN ''TENDER CANCELLED'' 
    WHEN IA_EXCEPTION_CODE.EXCEPTION_CODE=''REJD'' THEN ''TENDER REJECTED''
    WHEN IA_EXCEPTION_CODE.EXCEPTION_CODE=''REVS'' THEN ''CONFIRM REVERSAL''
    WHEN IA_EXCEPTION_CODE.EXCEPTION_CODE=''LUNS'' THEN ''LOAD UNSUSPENDED''
    WHEN IA_EXCEPTION_CODE.EXCEPTION_CODE=''DKD_'' THEN ''DOCK DELETED''
    WHEN IA_EXCEPTION_CODE.EXCEPTION_CODE=''DKC_'' THEN ''DOCK CREATED''
    WHEN IA_EXCEPTION_CODE.EXCEPTION_CODE=''DKH_'' THEN ''DOCK CHANGED''
    WHEN IA_EXCEPTION_CODE.EXCEPTION_CODE=''APD_'' THEN ''APPOINTMENT DELETED''
    WHEN IA_EVNT_TYPE.EVNT_TYPE_CODE<>''TENDCNCL'' AND IA_EXCEPTION_CODE.EXCEPTION_CODE=''PLND'' THEN ''MANUALLY PLANNED''
    WHEN IA_EVNT_TYPE.EVNT_TYPE_CODE IN(''TENDFRST'',''TENDOTHER'') AND IA_EXCEPTION_CODE.EXCEPTION_CODE=''TNRD'' THEN ''MANUALLY TENDERED''
    END AS Reason,
    
    CASE WHEN IA_EXCEPTION_CODE.EXCEPTION_CODE=''ACPD'' THEN 1
    WHEN IA_EVNT_TYPE.EVNT_TYPE_CODE=''TENDCNCL'' AND	IA_EXCEPTION_CODE.EXCEPTION_CODE=''PLND'' THEN 2 
    WHEN IA_EXCEPTION_CODE.EXCEPTION_CODE=''REJD'' THEN 3
    WHEN IA_EXCEPTION_CODE.EXCEPTION_CODE=''REVS'' THEN 4
    WHEN IA_EXCEPTION_CODE.EXCEPTION_CODE=''LUNS'' THEN 5
    WHEN IA_EXCEPTION_CODE.EXCEPTION_CODE=''DKD_'' THEN 6
    WHEN IA_EXCEPTION_CODE.EXCEPTION_CODE=''DKC_'' THEN 7
    WHEN IA_EXCEPTION_CODE.EXCEPTION_CODE=''DKH_'' THEN 8
    WHEN IA_EXCEPTION_CODE.EXCEPTION_CODE=''APD_'' THEN 9
    WHEN IA_EVNT_TYPE.EVNT_TYPE_CODE<>''TENDCNCL'' AND IA_EXCEPTION_CODE.EXCEPTION_CODE=''PLND'' THEN 10
    WHEN IA_EVNT_TYPE.EVNT_TYPE_CODE IN(''TENDFRST'',''TENDOTHER'') AND IA_EXCEPTION_CODE.EXCEPTION_CODE=''TNRD'' THEN 11
    END AS Ordinal,
	USER_LOGIN,
	USER_NAME,
	IA_DIST_LOADS.EVENT_LOG_DT AS EventDate

FROM  
	TMDW.IA_DIST_LOADS IA_DIST_LOADS 
    JOIN TMDW.IA_EXCEPTION_CODE ON IA_EXCEPTION_CODE.EXCPT_CODE_KEY = IA_DIST_LOADS.EXCPT_CODE_KEY
    JOIN TMDW.IA_USERS ON IA_USERS.USER_KEY = IA_DIST_LOADS.EVNT_USER_KEY
    JOIN TMDW.IA_EVNT_TYPE ON IA_EVNT_TYPE.EVNT_TYPE_KEY = IA_DIST_LOADS.EVNT_TYPE_KEY

WHERE 
	(EXTRACT(YEAR FROM IA_DIST_LOADS.EVENT_LOG_DT) >= EXTRACT(YEAR FROM SYSDATE)-1) AND 
	(
    (IA_EXCEPTION_CODE.EXCEPTION_CODE=''ACPD'') 
    OR (IA_EVNT_TYPE.EVNT_TYPE_CODE=''TENDCNCL'') AND	(IA_EXCEPTION_CODE.EXCEPTION_CODE=''PLND'')
    OR (IA_EXCEPTION_CODE.EXCEPTION_CODE=''REJD'')
    OR (IA_EXCEPTION_CODE.EXCEPTION_CODE=''REVS'')
    OR (IA_EXCEPTION_CODE.EXCEPTION_CODE=''LUNS'')
    OR (IA_EXCEPTION_CODE.EXCEPTION_CODE=''DKD_'')
    OR (IA_EXCEPTION_CODE.EXCEPTION_CODE=''DKC_'')
    OR (IA_EXCEPTION_CODE.EXCEPTION_CODE=''DKH_'')
    OR (IA_EXCEPTION_CODE.EXCEPTION_CODE=''APD_'')
    OR (IA_EXCEPTION_CODE.EXCEPTION_CODE=''PLND'')
    OR (IA_EVNT_TYPE.EVNT_TYPE_CODE IN(''TENDFRST'',''TENDOTHER'')) AND (IA_EXCEPTION_CODE.EXCEPTION_CODE=''TNRD'')
    )
    AND (substr(USER_LOGIN,1,1) Not In (''*'',''9''))

GROUP BY
	IA_DIST_LOADS.LOAD_ID, 
    CASE WHEN IA_EXCEPTION_CODE.EXCEPTION_CODE=''ACPD'' THEN ''MANUALLY ACCEPTED''
    WHEN IA_EVNT_TYPE.EVNT_TYPE_CODE=''TENDCNCL'' AND	IA_EXCEPTION_CODE.EXCEPTION_CODE=''PLND'' THEN ''TENDER CANCELLED'' 
    WHEN IA_EXCEPTION_CODE.EXCEPTION_CODE=''REJD'' THEN ''TENDER REJECTED''
    WHEN IA_EXCEPTION_CODE.EXCEPTION_CODE=''REVS'' THEN ''CONFIRM REVERSAL''
    WHEN IA_EXCEPTION_CODE.EXCEPTION_CODE=''LUNS'' THEN ''LOAD UNSUSPENDED''
    WHEN IA_EXCEPTION_CODE.EXCEPTION_CODE=''DKD_'' THEN ''DOCK DELETED''
    WHEN IA_EXCEPTION_CODE.EXCEPTION_CODE=''DKC_'' THEN ''DOCK CREATED''
    WHEN IA_EXCEPTION_CODE.EXCEPTION_CODE=''DKH_'' THEN ''DOCK CHANGED''
    WHEN IA_EXCEPTION_CODE.EXCEPTION_CODE=''APD_'' THEN ''APPOINTMENT DELETED''
    WHEN IA_EVNT_TYPE.EVNT_TYPE_CODE<>''TENDCNCL'' AND IA_EXCEPTION_CODE.EXCEPTION_CODE=''PLND'' THEN ''MANUALLY PLANNED''
    WHEN IA_EVNT_TYPE.EVNT_TYPE_CODE IN(''TENDFRST'',''TENDOTHER'') AND IA_EXCEPTION_CODE.EXCEPTION_CODE=''TNRD'' THEN ''MANUALLY TENDERED''
    END,
    CASE WHEN IA_EXCEPTION_CODE.EXCEPTION_CODE=''ACPD'' THEN 1
    WHEN IA_EVNT_TYPE.EVNT_TYPE_CODE=''TENDCNCL'' AND	IA_EXCEPTION_CODE.EXCEPTION_CODE=''PLND'' THEN 2 
    WHEN IA_EXCEPTION_CODE.EXCEPTION_CODE=''REJD'' THEN 3
    WHEN IA_EXCEPTION_CODE.EXCEPTION_CODE=''REVS'' THEN 4
    WHEN IA_EXCEPTION_CODE.EXCEPTION_CODE=''LUNS'' THEN 5
    WHEN IA_EXCEPTION_CODE.EXCEPTION_CODE=''DKD_'' THEN 6
    WHEN IA_EXCEPTION_CODE.EXCEPTION_CODE=''DKC_'' THEN 7
    WHEN IA_EXCEPTION_CODE.EXCEPTION_CODE=''DKH_'' THEN 8
    WHEN IA_EXCEPTION_CODE.EXCEPTION_CODE=''APD_'' THEN 9
    WHEN IA_EVNT_TYPE.EVNT_TYPE_CODE<>''TENDCNCL'' AND IA_EXCEPTION_CODE.EXCEPTION_CODE=''PLND'' THEN 10
    WHEN IA_EVNT_TYPE.EVNT_TYPE_CODE IN(''TENDFRST'',''TENDOTHER'') AND IA_EXCEPTION_CODE.EXCEPTION_CODE=''TNRD'' THEN 11
    END,
	USER_LOGIN,
	USER_NAME,
	IA_DIST_LOADS.EVENT_LOG_DT

ORDER BY 
	IA_DIST_LOADS.LOAD_ID, Ordinal, IA_DIST_LOADS.EVENT_LOG_DT')


/*
Create Aggregate by LoadNumber / Reason / Ordinal from Detail table
SELECT * FROM ##tblManuallyTouchedDetails ORDER BY LoadNumber, Ordinal, EventDate
SELECT * FROM ##tblManuallyTouchedAggregate ORDER BY LoadNumber, Ordinal
SELECT DISTINCT REASON FROM ##tblManuallyTouchedAggregate
*/
DROP TABLE IF EXISTS ##tblManuallyTouchedAggregate
SELECT DISTINCT LoadNumber, SUM(LoadCount) as TimesTouched, Reason, Ordinal 
INTO ##tblManuallyTouchedAggregate
FROM ##tblManuallyTouchedDetails
GROUP BY LoadNumber, Reason, Ordinal
ORDER BY LoadNumber, Ordinal

/*
Get suggested appointment statuses
Per meeting with John Crumpton on 11/26, do not need. Commenting out!

SELECT * INTO ##tblSuggestedAppointments FROM OPENQUERY(NAJDAPRD,'SELECT DISTINCT
    load_number,
    ship_num,
    appt_chg_time
FROM
    (
        SELECT DISTINCT
            abpp_otc_appointmenthistory.load_number       AS load_number,
            abpp_otc_appointmenthistory.shipment_number   AS ship_num,
            MIN(TO_CHAR(abpp_otc_appointmenthistory.appointment_change_time, ''mm/dd/yy hh:mm:ss'')) AS appt_chg_time
        FROM
            trn_appt.abpp_otc_appointmenthistory   abpp_otc_appointmenthistory,
            najdaadm.load_leg_r                    load_leg_r
        WHERE
            abpp_otc_appointmenthistory.load_number = load_leg_r.ld_leg_id
            AND ( ( load_leg_r.crtd_dtt >= add_months(trunc(SYSDATE, ''mm''), - 12) )
                  AND ( abpp_otc_appointmenthistory.stop_number > ''1'' )
                  AND ( abpp_otc_appointmenthistory.appointment_status = ''Suggested'' )
                  AND ( load_leg_r.frst_ctry_cd IN (
                ''USA'',
                ''CAN'',
                ''MEX''
            ) ) )
        GROUP BY
            abpp_otc_appointmenthistory.load_number,
            abpp_otc_appointmenthistory.shipment_number
        UNION ALL
        SELECT DISTINCT
            abpp_otc_appointmenthistory.load_number       AS load_number,
            abpp_otc_appointmenthistory.shipment_number   AS ship_num,
            MIN(TO_CHAR(abpp_otc_appointmenthistory.appointment_change_time, ''mm/dd/yy hh:mm:ss'')) AS appt_chg_time
        FROM
            trn_appt.abpp_otc_appointmenthistory   abpp_otc_appointmenthistory,
            najdaadm.load_leg_r                    load_leg_r
        WHERE
            abpp_otc_appointmenthistory.load_number = load_leg_r.ld_leg_id
            AND ( ( load_leg_r.crtd_dtt >= add_months(trunc(SYSDATE, ''mm''), - 12) )
                  AND ( abpp_otc_appointmenthistory.stop_number > ''1'' )
                  AND ( abpp_otc_appointmenthistory.appointment_status = ''Suggested'' )
                  AND ( load_leg_r.last_ctry_cd IN (
                ''USA'',
                ''CAN'',
                ''MEX''
            ) ) )
        GROUP BY
            abpp_otc_appointmenthistory.load_number,
            abpp_otc_appointmenthistory.shipment_number
    )
GROUP BY
    load_number,
    ship_num,
    appt_chg_time
ORDER BY
    load_number')
*/

/*
Pull confirm pick appointments
Per meeting with John Crumpton on 11/26, do not need. Commenting out!

SELECT * INTO ##tblConfirmPickedAppointments FROM OPENQUERY(NAJDAPRD,'SELECT DISTINCT
    load_number,
    appt_chg_time
FROM
    (
        SELECT DISTINCT
            TO_CHAR(l.ld_leg_id) AS load_number,
            TO_CHAR(MIN(apt.appointment_change_time), ''mm/dd/yyyy hh:mm:ss'') AS appt_chg_time
        FROM
            NAI2PADM.abpp_otc_appointmenthistory   apt,
            NAI2PADM.load_leg_r                    l
        WHERE
            apt.load_number = l.ld_leg_id
            AND ( l.crtd_dtt >= add_months(trunc(SYSDATE, ''mm''), - 12) )
            AND ( apt.stop_number = 1 )
            AND ( apt.appointment_status = ''Confirmed'' )
            AND ( l.frst_ctry_cd IN (
                ''USA'',
                ''CAN'',
                ''MEX''
            ) )
        GROUP BY
            l.ld_leg_id
        UNION ALL
        SELECT DISTINCT
            TO_CHAR(l.ld_leg_id) AS load_number,
            TO_CHAR(MIN(apt.appointment_change_time), ''mm/dd/yyyy hh:mm:ss'') AS appt_chg_time
        FROM
            NAI2PADM.abpp_otc_appointmenthistory   apt,
            NAI2PADM.load_leg_r                    l
        WHERE
            apt.load_number = l.ld_leg_id
            AND ( l.crtd_dtt >= add_months(trunc(SYSDATE, ''mm''), - 12) )
            AND ( apt.stop_number = 1 )
            AND ( apt.appointment_status = ''Confirmed'' )
            AND ( l.last_ctry_cd IN (
                ''USA'',
                ''CAN'',
                ''MEX''
            ) )
        GROUP BY
            l.ld_leg_id
    ) results
GROUP BY
    load_number,
    appt_chg_time
ORDER BY
    load_number')
*/

/*
Pull Individual LD_LEG_ID details

SELECT * FROM ##tblLoadLegDetails
*/
DROP TABLE IF EXISTS ##tblLoadLegDetails
SELECT * INTO ##tblLoadLegDetails FROM OPENQUERY(NAJDAPRD,'SELECT DISTINCT
    load_number,
    shpm_num,
    load_leg_cnt
FROM
    (
        SELECT DISTINCT
            load_leg_r.ld_leg_id AS load_number,
            MIN(load_leg_detail_r.shpm_num) AS shpm_num,
            COUNT(DISTINCT load_leg_r.ld_leg_id) AS load_leg_cnt
        FROM
            NAI2PADM.load_leg_detail_r   load_leg_detail_r,
            NAI2PADM.load_leg_r          load_leg_r
        WHERE
            load_leg_r.ld_leg_id = load_leg_detail_r.ld_leg_id
            AND (EXTRACT(YEAR FROM CASE WHEN load_leg_r.shpd_dtt IS NOT NULL THEN load_leg_r.shpd_dtt WHEN load_leg_r.strd_dtt IS NOT NULL THEN load_leg_r.strd_dtt ELSE load_leg_r.crtd_dtt END) >= EXTRACT(YEAR FROM SYSDATE)-1)
            AND ( load_leg_r.frst_ctry_cd IN (
                ''USA'',
                ''CAN'',
                ''MEX''
            ) )
            AND ( substr(load_leg_r.frst_shpg_loc_cd, 1, 1) <> ''R'' )
            AND ( substr(load_leg_r.last_shpg_loc_cd, 1, 1) <> ''R'' )
        GROUP BY
            load_leg_r.ld_leg_id
        UNION ALL
        SELECT DISTINCT
            load_leg_r.ld_leg_id AS load_number,
            MIN(load_leg_detail_r.shpm_num) AS shpm_num,
            COUNT(DISTINCT load_leg_r.ld_leg_id) AS load_leg_cnt
        FROM
            NAI2PADM.load_leg_detail_r   load_leg_detail_r,
            NAI2PADM.load_leg_r          load_leg_r
        WHERE
            load_leg_r.ld_leg_id = load_leg_detail_r.ld_leg_id
            AND (EXTRACT(YEAR FROM CASE WHEN load_leg_r.shpd_dtt IS NOT NULL THEN load_leg_r.shpd_dtt WHEN load_leg_r.strd_dtt IS NOT NULL THEN load_leg_r.strd_dtt ELSE load_leg_r.crtd_dtt END) >= EXTRACT(YEAR FROM SYSDATE)-1)
            AND ( load_leg_r.last_ctry_cd IN (
                ''USA'',
                ''CAN'',
                ''MEX''
            ) )
            AND ( substr(load_leg_r.frst_shpg_loc_cd, 1, 1) <> ''R'' )
            AND ( substr(load_leg_r.last_shpg_loc_cd, 1, 1) <> ''R'' )
        GROUP BY
            load_leg_r.ld_leg_id
    )
GROUP BY
    load_number,
    shpm_num,
    load_leg_cnt
ORDER BY
    load_number')

/*
Pull Lights Out Planned Status Details
SELECT * FROM ##tblLightsOutPlanned
SELECT DISTINCT LOAD_NUMBER, COUNT(LOAD_NUMBER) as Count FROM ##tblLightsOutPlanned GROUP BY LOAD_NUMBER HAVING COUNT(LOAD_NUMBER) <> 1
*/
SELECT * INTO ##tblLightsOutPlanned FROM OPENQUERY(NAJDAPRD,'SELECT DISTINCT
    plnd_mnt_dtt,
    plnd_doc_type,
    load_number,
    plnd_operation,
    plnd_status,
    plnd_status_desc,
    plnd_status_date,
    plnd_status_time,
    plnd_mnt_tmestmp,
    plnd_user_id,
    plnd_procssd_cnt
FROM
    (
        SELECT DISTINCT
            TO_CHAR(abpp_otc_autmttrans_srvcs.mnt_tmestmp, ''yyyymmdd'') AS plnd_mnt_dtt,
            abpp_otc_autmttrans_srvcs.doc_typ       AS plnd_doc_type,
            TO_CHAR(abpp_otc_autmttrans_srvcs.doc_numb) AS load_number,
            abpp_otc_autmttrans_srvcs.operation     AS plnd_operation,
            abpp_otc_autmttrans_srvcs.status        AS plnd_status,
            abpp_otc_autmttrans_srvcs.status_desc   AS plnd_status_desc,
            TO_CHAR(abpp_otc_autmttrans_srvcs.status_dt, ''yyyymmdd'') AS plnd_status_date,
            abpp_otc_autmttrans_srvcs.status_time   AS plnd_status_time,
            abpp_otc_autmttrans_srvcs.mnt_tmestmp   AS plnd_mnt_tmestmp,
            abpp_otc_autmttrans_srvcs.usr_id        AS plnd_user_id,
            abpp_otc_autmttrans_srvcs.procssd_cnt   AS plnd_procssd_cnt
        FROM
            nai2padm.abpp_otc_autmttrans_srvcs   abpp_otc_autmttrans_srvcs
            JOIN nai2padm.load_leg_r                  load_leg_r ON load_leg_r.ld_leg_id = abpp_otc_autmttrans_srvcs.doc_numb
        WHERE
            ( abpp_otc_autmttrans_srvcs.operation = ''STLP'' )
			AND (EXTRACT(YEAR FROM CASE WHEN load_leg_r.shpd_dtt IS NOT NULL THEN load_leg_r.shpd_dtt WHEN load_leg_r.strd_dtt IS NOT NULL THEN load_leg_r.strd_dtt ELSE load_leg_r.crtd_dtt END) >= EXTRACT(YEAR FROM SYSDATE)-1)
            AND ( load_leg_r.crtd_dtt <= trunc(SYSDATE, ''DDD'') )
            AND ( load_leg_r.frst_ctry_cd IN (
                ''USA'',
                ''CAN'',
                ''MEX''
            ) )
            AND ( substr(load_leg_r.frst_shpg_loc_cd, 1, 1) <> ''R'' )
            AND ( substr(load_leg_r.last_shpg_loc_cd, 1, 1) <> ''R'' )
        UNION ALL
        SELECT DISTINCT
            TO_CHAR(abpp_otc_autmttrans_srvcs.mnt_tmestmp, ''yyyymmdd'') AS plnd_mnt_dtt,
            abpp_otc_autmttrans_srvcs.doc_typ       AS plnd_doc_type,
            TO_CHAR(abpp_otc_autmttrans_srvcs.doc_numb) AS load_number,
            abpp_otc_autmttrans_srvcs.operation     AS plnd_operation,
            abpp_otc_autmttrans_srvcs.status        AS plnd_status,
            abpp_otc_autmttrans_srvcs.status_desc   AS plnd_status_desc,
            TO_CHAR(abpp_otc_autmttrans_srvcs.status_dt, ''yyyymmdd'') AS plnd_status_date,
            abpp_otc_autmttrans_srvcs.status_time   AS plnd_status_time,
            abpp_otc_autmttrans_srvcs.mnt_tmestmp   AS plnd_mnt_tmestmp,
            abpp_otc_autmttrans_srvcs.usr_id        AS plnd_user_id,
            abpp_otc_autmttrans_srvcs.procssd_cnt   AS plnd_procssd_cnt
        FROM
            nai2padm.abpp_otc_autmttrans_srvcs   abpp_otc_autmttrans_srvcs
            JOIN nai2padm.load_leg_r                  load_leg_r ON load_leg_r.ld_leg_id = abpp_otc_autmttrans_srvcs.doc_numb
        WHERE
            ( abpp_otc_autmttrans_srvcs.operation = ''STLP'' )
            AND (EXTRACT(YEAR FROM CASE WHEN load_leg_r.shpd_dtt IS NOT NULL THEN load_leg_r.shpd_dtt WHEN load_leg_r.strd_dtt IS NOT NULL THEN load_leg_r.strd_dtt ELSE load_leg_r.crtd_dtt END) >= EXTRACT(YEAR FROM SYSDATE)-1)
            AND ( load_leg_r.crtd_dtt <= trunc(SYSDATE, ''DDD'') )
            AND ( load_leg_r.last_ctry_cd IN (
                ''USA'',
                ''CAN'',
                ''MEX''
            ) )
            AND ( substr(load_leg_r.frst_shpg_loc_cd, 1, 1) <> ''R'' )
            AND ( substr(load_leg_r.last_shpg_loc_cd, 1, 1) <> ''R'' )
    )
GROUP BY
    plnd_mnt_dtt,
    plnd_doc_type,
    load_number,
    plnd_operation,
    plnd_status,
    plnd_status_desc,
    plnd_status_date,
    plnd_status_time,
    plnd_mnt_tmestmp,
    plnd_user_id,
    plnd_procssd_cnt
ORDER BY
    load_number')

/*
Pull Lights Out Load Tendered Details
SELECT * FROM ##tblLightsOutTendered
SELECT DISTINCT LOAD_NUMBER, COUNT(LOAD_NUMBER) as Count FROM ##tblLightsOutTendered GROUP BY LOAD_NUMBER HAVING COUNT(LOAD_NUMBER) <> 1
*/
SELECT * INTO ##tblLightsOutTendered FROM OPENQUERY(NAJDAPRD,'SELECT DISTINCT
    tdr_time,
    tdr_doc_type,
    load_number,
    tdr_operation,
    tdr_status,
    tdr_status_desc,
    tdr_status_dtt,
    tdr_status_time,
    tdr_mnt_tmestmp,
    tdr_usr_id,
    tdr_procssd_cnt
FROM
    (
        SELECT DISTINCT
            TO_CHAR(abpp_otc_autmttrans_srvcs.mnt_tmestmp, ''yyyymmdd'') AS tdr_time,
            abpp_otc_autmttrans_srvcs.doc_typ       AS tdr_doc_type,
            TO_CHAR(abpp_otc_autmttrans_srvcs.doc_numb) AS load_number,
            abpp_otc_autmttrans_srvcs.operation     AS tdr_operation,
            abpp_otc_autmttrans_srvcs.status        AS tdr_status,
            abpp_otc_autmttrans_srvcs.status_desc   AS tdr_status_desc,
            TO_CHAR(abpp_otc_autmttrans_srvcs.status_dt, ''yyyymmdd'') AS tdr_status_dtt,
            abpp_otc_autmttrans_srvcs.status_time   AS tdr_status_time,
            abpp_otc_autmttrans_srvcs.mnt_tmestmp   AS tdr_mnt_tmestmp,
            abpp_otc_autmttrans_srvcs.usr_id        AS tdr_usr_id,
            abpp_otc_autmttrans_srvcs.procssd_cnt   AS tdr_procssd_cnt
        FROM
            nai2padm.abpp_otc_autmttrans_srvcs   abpp_otc_autmttrans_srvcs
            JOIN nai2padm.load_leg_r                  load_leg_r ON load_leg_r.ld_leg_id = abpp_otc_autmttrans_srvcs.doc_numb
        WHERE
            ( abpp_otc_autmttrans_srvcs.operation = ''STLT'' )
            AND (EXTRACT(YEAR FROM CASE WHEN load_leg_r.shpd_dtt IS NOT NULL THEN load_leg_r.shpd_dtt WHEN load_leg_r.strd_dtt IS NOT NULL THEN load_leg_r.strd_dtt ELSE load_leg_r.crtd_dtt END) >= EXTRACT(YEAR FROM SYSDATE)-1)
            AND ( load_leg_r.crtd_dtt <= trunc(SYSDATE, ''DDD'') )
            AND ( load_leg_r.frst_ctry_cd IN (
                ''USA'',
                ''CAN'',
                ''MEX''
            ) )
            AND ( substr(load_leg_r.frst_shpg_loc_cd, 1, 1) <> ''R'' )
            AND ( substr(load_leg_r.last_shpg_loc_cd, 1, 1) <> ''R'' )
        UNION ALL
        SELECT DISTINCT
            TO_CHAR(abpp_otc_autmttrans_srvcs.mnt_tmestmp, ''yyyymmdd'') AS tdr_time,
            abpp_otc_autmttrans_srvcs.doc_typ       AS tdr_doc_type,
            TO_CHAR(abpp_otc_autmttrans_srvcs.doc_numb) AS load_number,
            abpp_otc_autmttrans_srvcs.operation     AS tdr_operation,
            abpp_otc_autmttrans_srvcs.status        AS tdr_status,
            abpp_otc_autmttrans_srvcs.status_desc   AS tdr_status_desc,
            TO_CHAR(abpp_otc_autmttrans_srvcs.status_dt, ''yyyymmdd'') AS tdr_status_dtt,
            abpp_otc_autmttrans_srvcs.status_time   AS tdr_status_time,
            abpp_otc_autmttrans_srvcs.mnt_tmestmp   AS tdr_mnt_tmestmp,
            abpp_otc_autmttrans_srvcs.usr_id        AS tdr_usr_id,
            abpp_otc_autmttrans_srvcs.procssd_cnt   AS tdr_procssd_cnt
        FROM
            nai2padm.abpp_otc_autmttrans_srvcs   abpp_otc_autmttrans_srvcs
            JOIN nai2padm.load_leg_r                  load_leg_r ON load_leg_r.ld_leg_id = abpp_otc_autmttrans_srvcs.doc_numb
        WHERE
            ( abpp_otc_autmttrans_srvcs.operation = ''STLT'' )
        AND (EXTRACT(YEAR FROM CASE WHEN load_leg_r.shpd_dtt IS NOT NULL THEN load_leg_r.shpd_dtt WHEN load_leg_r.strd_dtt IS NOT NULL THEN load_leg_r.strd_dtt ELSE load_leg_r.crtd_dtt END) >= EXTRACT(YEAR FROM SYSDATE)-1)
            AND ( load_leg_r.crtd_dtt <= trunc(SYSDATE, ''DDD'') )
            AND ( load_leg_r.last_ctry_cd IN (
                ''USA'',
                ''CAN'',
                ''MEX''
            ) )
            AND ( substr(load_leg_r.frst_shpg_loc_cd, 1, 1) <> ''R'' )
            AND ( substr(load_leg_r.last_shpg_loc_cd, 1, 1) <> ''R'' )
    )
GROUP BY
    tdr_time,
    tdr_doc_type,
    load_number,
    tdr_operation,
    tdr_status,
    tdr_status_desc,
    tdr_status_dtt,
    tdr_status_time,
    tdr_mnt_tmestmp,
    tdr_usr_id,
    tdr_procssd_cnt
ORDER BY
    load_number,
    tdr_mnt_tmestmp')

/*
Pull Optimization Details
-- Per meeting with John Crumpton on 11/26, do not need. Commenting out!

SELECT * INTO ##tblOptimizationDetails FROM OPENQUERY(NAJDAPRD,'SELECT
	OPMR_QUE_T.QUE_DTT as OPT_QUE_DATE,
	OPMR_QUE_T.QUE_ID as OPT_QUE_ID,
	OPMR_QUE_T.PLAN_ID as OPT_PLAN_ID,
	OPMR_QUE_T.STRT_DTT as OPT_START_DATE,
	OPMR_QUE_T.CPLD_DTT as OPT_CMPL_DATE,
	OPMR_QUE_T.NUM_SHPMLEG as NUM_SHIPLEGS,
	OPMR_QUE_T.USR_CD as USER_ID
FROM
	NAI2PADM.OPMR_QUE_T OPMR_QUE_T

WHERE
	(OPMR_QUE_T.QUE_DTT>= add_months(trunc(SYSDATE, ''mm''), - 12) )

ORDER BY
	OPMR_QUE_T.QUE_ID')
*/

/*
Get Business Unit for Each Load from ABPP_LD_RFRC_T
SELECT * FROM ##tblBusinessUnits
*/
DROP TABLE IF EXISTS ##tblBusinessUnits
Select * into ##tblBusinessUnits from OPENQUERY(NAJDAPRD,'SELECT DISTINCT
    ld_leg_id,
    ob_bu
FROM
    (
        SELECT
            ld_leg_id,
            CASE
                WHEN business IS NULL THEN
                    bus_unit
                ELSE
                    business
            END AS ob_bu,
            vol_rank
        FROM
            (
                SELECT DISTINCT
                    l.ld_leg_id,
                    sh.rfrc_num10 AS bu,
                    sh.vol,
                    CASE
                        WHEN substr(last_shpg_loc_cd, 1, 4) IN (
                            ''2000'',
                            ''2019'',
                            ''2022'',
                            ''2023'',
                            ''2024'',
                            ''2026'',
                            ''2027'',
                            ''2028'',
                            ''2029'',
                            ''2031'',
                            ''2032'',
                            ''2035'',
                            ''2036'',
                            ''2038'',
                            ''2041'',
                            ''2049'',
                            ''2050'',
                            ''2054'',
                            ''2063'',
                            ''2075'',
                            ''2094'',
                            ''2100'',
                            ''2137'',
                            ''2138'',
                            ''2142'',
                            ''2170'',
                            ''2171'',
                            ''2172'',
                            ''2183'',
                            ''2187'',
                            ''2191'',
                            ''2197'',
                            ''2210'',
                            ''2213'',
                            ''2240'',
                            ''2275'',
                            ''2283'',
                            ''2291'',
                            ''2292'',
                            ''2300'',
                            ''2303'',
                            ''2307'',
                            ''2314'',
                            ''2320'',
                            ''2331'',
                            ''2336'',
                            ''2347'',
                            ''2353'',
                            ''2358'',
                            ''2359'',
                            ''2360'',
                            ''2369'',
                            ''2370'',
                            ''2385'',
                            ''2399'',
                            ''2408'',
                            ''2412'',
                            ''2414'',
                            ''2419'',
                            ''2422'',
                            ''2443'',
                            ''2463'',
                            ''2483'',
                            ''2487'',
                            ''2489'',
                            ''2496'',
                            ''2500'',
                            ''2510'',
                            ''2511'',
                            ''2822'',
                            ''2839''
                        ) THEN
                            ''CONSUMER''
                        WHEN substr(last_shpg_loc_cd, 1, 4) IN (
                            ''2034'',
                            ''2039'',
                            ''2040'',
                            ''2042'',
                            ''2043'',
                            ''2044'',
                            ''2048'',
                            ''2051'',
                            ''2079'',
                            ''2080'',
                            ''2091'',
                            ''2096'',
                            ''2099'',
                            ''2104'',
                            ''2106'',
                            ''2111'',
                            ''2112'',
                            ''2113'',
                            ''2124'',
                            ''2126'',
                            ''2161'',
                            ''2177'',
                            ''2200'',
                            ''2234'',
                            ''2299'',
                            ''2301'',
                            ''2302'',
                            ''2304'',
                            ''2310'',
                            ''2323'',
                            ''2325'',
                            ''2334'',
                            ''2348'',
                            ''2349'',
                            ''2350'',
                            ''2356'',
                            ''2362'',
                            ''2363'',
                            ''2375'',
                            ''2386'',
                            ''2415'',
                            ''2416'',
                            ''2425'',
                            ''2429'',
                            ''2446'',
                            ''2449'',
                            ''2459'',
                            ''2460'',
                            ''2467'',
                            ''2474'',
                            ''2476'',
                            ''2477'',
                            ''2485'',
                            ''2495'',
                            ''2505'',
                            ''2827'',
                            ''2833'',
                            ''2834'',
                            ''2837''
                        ) THEN
                            ''KCP''
                        ELSE
                            ''UNKNOWN''
                    END bus_unit,
                    CASE
                        WHEN sh.rfrc_num10 IN (
                            ''2810'',
                            ''2820'',
                            ''Z01''
                        ) THEN
                            ''CONSUMER''
                        WHEN sh.rfrc_num10 IN (
                            ''2811'',
                            ''2821'',
                            ''Z02'',
                            ''Z04'',
                            ''Z06'',
                            ''Z07''
                        ) THEN
                            ''KCP''
                        WHEN sh.rfrc_num10 = ''Z05'' THEN
                            ''NON WOVENS''
                        ELSE
                            NULL
                    END business,
                    RANK() OVER(
                        PARTITION BY l.ld_leg_id
                        ORDER BY
                            sh.nmnl_wgt DESC
                    ) AS vol_rank
                FROM
                    najdaadm.load_leg_r          l,
                    najdaadm.load_leg_detail_r   ld,
                    najdaadm.shipment_r          sh
                WHERE
                    l.ld_leg_id = ld.ld_leg_id
                    AND ld.shpm_num = sh.shpm_num
                    AND (l.cur_optlstat_id >= 300 AND l.cur_optlstat_id < 400)
                    AND EXTRACT(YEAR FROM
						CASE
							WHEN l.shpd_dtt IS NOT NULL THEN l.shpd_dtt
							WHEN l.shpd_dtt IS NOT NULL THEN l.shpd_dtt							
							ELSE l.shpd_dtt	
						END
					) >= EXTRACT(YEAR FROM SYSDATE)-1
                    AND (last_ctry_cd IN (
                        ''MEX'',
                        ''CAN'',
                        ''USA''
                    ) OR frst_ctry_cd IN (
                        ''MEX'',
                        ''CAN'',
                        ''USA''
                    ) )
            )
    )
WHERE
    vol_rank = 1')

/*
Create Actual Load Details Table
SELECT * FROM ##tblActualLoadDetailsRFT WHERE LOAD_NUMBER = 516579480
SELECT DISTINCT load_number, count(*) as COUNT FROM ##tblActualLoadDetailsRFT GROUP BY load_number HAVING Count(*) <>1

SELECT COUNT (DISTINCT LOAD_NUMBER) FROM ##tblActualLoadDetailsRFT

SELECT * FROM ##tblActualLoadDetailsRFT ald
LEFT JOIN ##tblBusinessUnits bu on bu.ld_leg_id = ald.load_number
WHERE bu.ob_bu is null
*/

DROP TABLE IF EXISTS ##tblActualLoadDetailsRFT
CREATE TABLE ##tblActualLoadDetailsRFT
    (
        SHIPMENT_TYPE           NVARCHAR(max),
        importexport            NVARCHAR(max),
        DomesticInt             NVARCHAR(max),
        shpd_dtt                datetime,
        ymd_ship_dte            NVARCHAR(max),
        date_last_refreshed     datetime,
        load_number             nvarchar(max),
        origin_id               nvarchar(max),
        origin_name             nvarchar(max),
        orig_city               nvarchar(max),
        orig_state              nvarchar(max),
        orig_zip                nvarchar(max),
        orig_country            nvarchar(max),
        stop_num                int,
        shpm_num_count          int,
		RowNumber				int,
        dest_id                 nvarchar(max),
        dest_name               nvarchar(max),
        dest_city               nvarchar(max),
        dest_state              nvarchar(max),
        dest_zip                nvarchar(max),
        dest_country            nvarchar(max),
        carrier                 nvarchar(max),
        service                 nvarchar(max),
        eq_type                 nvarchar(max),
        miles                   decimal(18,2),
        num_stop                int,
        num_shpm                int,
        que_id                  nvarchar(max),
        ld_source               nvarchar(max),
        plan_id                 nvarchar(max),
        team_name               nvarchar(max),
        team_leader_id          nvarchar(max),
        team_leader_name        nvarchar(max),
        analyst_id              nvarchar(max),
        analyst_name            nvarchar(max),
        ld_compl_yn             nvarchar(max),
        corp_id                 nvarchar(max),
        currentstatus           nvarchar(max),
        currentStatusDesc       nvarchar(max),
        createdate              datetime
    )

/*
Pull Shipped Loads Details
*/
DECLARE @myQuery VARCHAR(MAX)
SET @myQuery = 'SELECT DISTINCT
CASE WHEN SUBSTR(DEST_ID,1,2)=''58'' THEN ''CUSTOMER''
	WHEN SUBSTR(DEST_ID,1,2) = ''99'' THEN ''CUSTOMER''
	WHEN CORP_ID = ''RM'' THEN ''RM-INBOUND''
	WHEN CORP_ID = ''RF'' THEN ''RF-INBOUND''
	WHEN SUBSTR(ORIG_NAME,1,2) = ''RM'' THEN ''RM-INBOUND''
	WHEN SUBSTR(ORIG_NAME,1,2) = ''RF'' THEN ''RF-INBOUND''
	WHEN SUBSTR (ORIGIN_ID,1,1) = ''V'' THEN ''INBOUND''
	ELSE ''INTERMILL'' END AS SHIPMENT_TYPE,
    CASE
        WHEN ( orig_country NOT IN (
            ''USA'',
            ''CAN'',
            ''MEX''
        ) )
             AND ( dest_country IN (
            ''USA'',
            ''CAN'',
            ''MEX''
        ) ) THEN
            ''IMPORT''
        WHEN ( orig_country IN (
            ''USA'',
            ''CAN'',
            ''MEX''
        ) )
             AND ( dest_country NOT IN (
            ''USA'',
            ''CAN'',
            ''MEX''
        ) ) THEN
            ''EXPORT''
        ELSE
            ''DOMESTIC''
    END AS importexport,
	    CASE
        WHEN ( orig_country IN (
            ''USA'',
            ''CAN'',
            ''MEX''
        ) )
             AND ( dest_country IN (
            ''USA'',
            ''CAN'',
            ''MEX''
        ) ) THEN
            ''DOMESTIC''
        ELSE
            ''INTERNATIONAL''
    END AS DomesticInt,
    shpd_dtt,
    ymd_ship_dte,
    date_last_refreshed,
    load_number,
    origin_id,
    orig_name,
    orig_city,
    orig_state,
    orig_zip,
    orig_country,
    stop_num,
    COUNT(DISTINCT shpm_num) AS shpm_num_count,
	ROW_NUMBER() OVER (PARTITION BY load_number ORDER BY stop_num DESC) AS RowNumber,
    dest_id,
    dest_name,
    dest_city,
    dest_state,
    dest_zip,
    dest_country,
    carrier,
    service,
    eq_type,
    miles,
    num_stop,
    num_shpm,
    que_id,
    ld_source,
    plan_id,
    team_name,
    team_leader_id,
    team_leader_name,
    analyst_id,
    analyst_name,
    ld_cmpl_yn,
    corp_id,
    currentStatus,
    currentStatusDesc,
	CreateDate
FROM
    (
        SELECT DISTINCT
    load_leg_r.shpd_dtt                      AS shpd_dtt,
    TO_CHAR(load_leg_r.shpd_dtt, ''yyyymmdd'') AS ymd_ship_dte,
    SYSDATE                                  AS date_last_refreshed,
    TO_CHAR(load_leg_r.ld_leg_id) AS load_number,
    load_leg_r.frst_shpg_loc_cd              AS origin_id,
    load_leg_r.frst_shpg_loc_name            AS orig_name,
    load_leg_r.frst_cty_name                 AS orig_city,
    load_leg_r.frst_sta_cd                   AS orig_state,
    load_leg_r.frst_pstl_cd                  AS orig_zip,
    load_leg_r.frst_ctry_cd                  AS orig_country,
    load_leg_detail_r.dlvy_stop_seq_num      AS stop_num,
    load_leg_detail_r.shpm_num               AS shpm_num,
    load_leg_detail_r.to_shpg_loc_cd         AS dest_id,
    load_leg_detail_r.to_shpg_loc_name       AS dest_name,
    load_leg_detail_r.to_cty_name            AS dest_city,
    load_leg_detail_r.to_sta_cd              AS dest_state,
    load_leg_detail_r.to_pstl_cd             AS dest_zip,
    load_leg_detail_r.to_ctry_cd             AS dest_country,
    load_leg_r.carr_cd                       AS carrier,
    load_leg_r.srvc_cd                       AS service,
    load_leg_r.eqmt_typ                      AS eq_type,
    load_leg_r.fixd_itnr_dist                AS miles,
    load_leg_r.num_stop                      AS num_stop,
    load_leg_r.num_shpm                      AS num_shpm,
    load_leg_r.que_id                        AS que_id,
    load_leg_r.ld_src_enu                    AS ld_source,
    load_leg_r.optm_plan_id                  AS plan_id,
    abpp_otc_caps_analyst.team_name          AS team_name,
    abpp_otc_caps_analyst.team_leader_id     AS team_leader_id,
    abpp_otc_caps_analyst.team_leader_name   AS team_leader_name,
    abpp_otc_caps_analyst.analyst_id         AS analyst_id,
    abpp_otc_caps_analyst.analyst_name       AS analyst_name,
    load_leg_r.ld_schd_cmpd_yn               AS ld_cmpl_yn,
    load_at_r.corp1_id                       AS corp_id,
    load_leg_r.CUR_OPTLSTAT_ID               AS currentStatus,
    status_r.stat_shrt_desc                  AS currentStatusDesc,
	load_leg_r.CRTD_DTT                      AS CreateDate
    
FROM
    nai2padm.load_leg_r						   load_leg_r
    LEFT JOIN nai2padm.load_leg_detail_r       load_leg_detail_r ON load_leg_r.ld_leg_id = load_leg_detail_r.ld_leg_id
    LEFT JOIN najdaadm.load_at_r               load_at_r ON load_at_r.shpg_loc_cd = load_leg_r.frst_shpg_loc_cd
    LEFT JOIN najdaadm.status_r                status_r ON load_leg_r.cur_optlstat_id = status_r.stat_id
    LEFT JOIN nai2padm.abpp_otc_caps_analyst   abpp_otc_caps_analyst ON load_leg_r.frst_shpg_loc_cd = abpp_otc_caps_analyst.location_id
                                                                      AND load_leg_r.shpd_dtt >= abpp_otc_caps_analyst.from_date
                                                                      AND load_leg_r.shpd_dtt < ( abpp_otc_caps_analyst.TO_DATE +
                                                                      1 )
WHERE
    ((EXTRACT(YEAR FROM CASE WHEN load_leg_r.shpd_dtt IS NOT NULL THEN load_leg_r.shpd_dtt WHEN load_leg_r.strd_dtt IS NOT NULL THEN load_leg_r.strd_dtt ELSE load_leg_r.crtd_dtt END) >= EXTRACT(YEAR FROM SYSDATE)-1)
      AND ( load_leg_r.frst_ctry_cd IN (
        ''USA'',
        ''CAN'',
        ''MEX''
    ) or load_leg_r.frst_ctry_cd is null)
      AND (( substr(frst_shpg_loc_cd, 1, 1) <> ''R'' ) or frst_shpg_loc_cd is null)
      AND (( substr(last_shpg_loc_cd, 1, 1) <> ''R'' ) or last_shpg_loc_cd is null))
	  AND (load_leg_r.CUR_OPTLSTAT_ID between 300 and 400)
        UNION ALL
        
        SELECT DISTINCT
    load_leg_r.shpd_dtt                      AS shpd_dtt,
    TO_CHAR(load_leg_r.shpd_dtt, ''yyyymmdd'') AS ymd_ship_dte,
    SYSDATE                                  AS date_last_refreshed,
    TO_CHAR(load_leg_r.ld_leg_id)			 AS load_number,
    load_leg_r.frst_shpg_loc_cd              AS origin_id,
    load_leg_r.frst_shpg_loc_name            AS orig_name,
    load_leg_r.frst_cty_name                 AS orig_city,
    load_leg_r.frst_sta_cd                   AS orig_state,
    load_leg_r.frst_pstl_cd                  AS orig_zip,
    load_leg_r.frst_ctry_cd                  AS orig_country,
    load_leg_detail_r.dlvy_stop_seq_num      AS stop_num,
    load_leg_detail_r.shpm_num               AS shpm_num,
    load_leg_detail_r.to_shpg_loc_cd         AS dest_id,
    load_leg_detail_r.to_shpg_loc_name       AS dest_name,
    load_leg_detail_r.to_cty_name            AS dest_city,
    load_leg_detail_r.to_sta_cd              AS dest_state,
    load_leg_detail_r.to_pstl_cd             AS dest_zip,
    load_leg_detail_r.to_ctry_cd             AS dest_country,
    load_leg_r.carr_cd                       AS carrier,
    load_leg_r.srvc_cd                       AS service,
    load_leg_r.eqmt_typ                      AS eq_type,
    load_leg_r.fixd_itnr_dist                AS miles,
    load_leg_r.num_stop                      AS num_stop,
    load_leg_r.num_shpm                      AS num_shpm,
    load_leg_r.que_id                        AS que_id,
    load_leg_r.ld_src_enu                    AS ld_source,
    load_leg_r.optm_plan_id                  AS plan_id,
    abpp_otc_caps_analyst.team_name          AS team_name,
    abpp_otc_caps_analyst.team_leader_id     AS team_leader_id,
    abpp_otc_caps_analyst.team_leader_name   AS team_leader_name,
    abpp_otc_caps_analyst.analyst_id         AS analyst_id,
    abpp_otc_caps_analyst.analyst_name       AS analyst_name,
    load_leg_r.ld_schd_cmpd_yn               AS ld_cmpl_yn,
    load_at_r.corp1_id                       AS corp_id,
    load_leg_r.CUR_OPTLSTAT_ID               AS currentStatus,
    status_r.stat_shrt_desc                  AS currentStatusDesc,
	load_leg_r.CRTD_DTT                      AS CreateDate
FROM
    nai2padm.load_leg_r              load_leg_r
    LEFT JOIN nai2padm.load_leg_detail_r       load_leg_detail_r ON load_leg_r.ld_leg_id = load_leg_detail_r.ld_leg_id
    LEFT JOIN najdaadm.load_at_r               load_at_r ON load_at_r.shpg_loc_cd = load_leg_r.frst_shpg_loc_cd
    LEFT JOIN najdaadm.status_r                status_r ON load_leg_r.cur_optlstat_id = status_r.stat_id
    LEFT JOIN nai2padm.abpp_otc_caps_analyst   abpp_otc_caps_analyst ON load_leg_r.frst_shpg_loc_cd = abpp_otc_caps_analyst.location_id
                                                                      AND load_leg_r.shpd_dtt >= abpp_otc_caps_analyst.from_date
                                                                      AND load_leg_r.shpd_dtt < ( abpp_otc_caps_analyst.TO_DATE +
                                                                      1 )
WHERE
    ( (EXTRACT(YEAR FROM CASE WHEN load_leg_r.shpd_dtt IS NOT NULL THEN load_leg_r.shpd_dtt WHEN load_leg_r.strd_dtt IS NOT NULL THEN load_leg_r.strd_dtt ELSE load_leg_r.crtd_dtt END) >= EXTRACT(YEAR FROM SYSDATE)-1)
      AND ( load_leg_r.last_ctry_cd IN (
        ''USA'',
        ''CAN'',
        ''MEX''
    )  or load_leg_r.frst_ctry_cd is null)
      AND (( substr(frst_shpg_loc_cd, 1, 1) <> ''R'' ) or frst_shpg_loc_cd is null)
      AND (( substr(last_shpg_loc_cd, 1, 1) <> ''R'' ) or last_shpg_loc_cd is null))
	  AND (load_leg_r.CUR_OPTLSTAT_ID between 300 and 400)
    )  
 
WHERE dest_id <> ''NOTRELEVANT''
GROUP BY
    shpd_dtt,
    ymd_ship_dte,
    date_last_refreshed,
    load_number,
    origin_id,
    orig_name,
    orig_city,
    orig_state,
    orig_zip,
    orig_country,
    stop_num,
    dest_id,
    dest_name,
    dest_city,
    dest_state,
    dest_zip,
    dest_country,
    carrier,
    service,
    eq_type,
    miles,
    num_stop,
    num_shpm,
    que_id,
    ld_source,
    plan_id,
    team_name,
    team_leader_id,
    team_leader_name,
    analyst_id,
    analyst_name,
    ld_cmpl_yn,
    corp_id,
    currentStatus,
    currentStatusDesc,
	CreateDate
    
ORDER BY
    load_number,
    stop_num'

/*
Execute Query
SELECT * FROM ##tblActualLoadDetailsRFT
*/
INSERT INTO ##tblActualLoadDetailsRFT
EXEC (@myQuery) AT NAJDAPRD

/*
Delete from ##tblActualLoadDetailsRFT where the stop number is NOT the max stop
*/
DELETE FROM ##tblActualLoadDetailsRFT
WHERE RowNumber <> 1

/*
Business Unit
Drop column from ##tblActualLoadDetailsRFT if it exists
If it doesn't exist, then add it to the table

SELECT DISTINCT load_number, COUNT(*) AS COUNT FROM ##tblActualLoadDetailsRFT GROUP BY load_number HAVING COUNT(*) <> 1
SELECT * FROM ##tblActualLoadDetailsRFT WHERE LOAD_NUMBER = '516621044'

select * from ##tblActualLoadDetailsRFT where BU is null
*/
ALTER TABLE ##tblActualLoadDetailsRFT DROP COLUMN IF EXISTS BU
ALTER TABLE ##tblActualLoadDetailsRFT ADD BU NVARCHAR(10)

UPDATE ##tblActualLoadDetailsRFT
SET BU = bu.ob_bu
FROM ##tblActualLoadDetailsRFT ald
INNER JOIN ##tblBusinessUnits bu on bu.ld_leg_id = ald.load_number

/*
If still null, update from Actual Load Detail
*/
UPDATE ##tblActualLoadDetailsRFT
SET BU = ald.BU
FROM ##tblActualLoadDetailsRFT rft
INNER JOIN USCTTDEV.dbo.tblActualLoadDetail ald ON ald.LD_LEG_ID = rft.load_number
WHERE rft.BU IS NULL

/*
If it's still null, may God have mercy on your soul
Otherwise, just update to 'UNKNOWN
*/
UPDATE ##tblActualLoadDetailsRFT
SET BU = 'UNKNOWN'
FROM ##tblActualLoadDetailsRFT rft
WHERE rft.BU IS NULL

/*
Add columns for Lights Out Planned and Lights Out Tendered
SELECT * FROM ##tblActualLoadDetailsRFT
SELECT * FROM ##tblLightsOutPlanned
SELECT * FROM ##tblLightsOutTendered

Descriptions can be crazy long...
SELECT DISTINCT LEN(PLND_STATUS_DESC) Length, PLND_STATUS_DESC  from ##tblLightsOUtPlanned GROUP BY PLND_STATUS_DESC ORDER BY LEN(PLND_STATUS_DESC) DESC
*/
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'LOPlannedStatus'	AND TABLE_NAME LIKE '##tblActualLoadDetailsRFT') ALTER TABLE ##tblActualLoadDetailsRFT ADD [LOPlannedStatus]	NVARCHAR(10) NULL	--##tblLightsOutPlanned.PLND_STATUS
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'LOPlannedDesc'		AND TABLE_NAME LIKE '##tblActualLoadDetailsRFT') ALTER TABLE ##tblActualLoadDetailsRFT ADD [LOPlannedDesc]		NVARCHAR(300) NULL	--##tblLightsOutPlanned.PLND_STATUS_DESC
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'LOPlannedOn'		AND TABLE_NAME LIKE '##tblActualLoadDetailsRFT') ALTER TABLE ##tblActualLoadDetailsRFT ADD [LOPlannedOn]		DATETIME NULL		--##tblLightsOutPlanned.PLND_MNT_TMESTMP
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'LOPlannedUserID'	AND TABLE_NAME LIKE '##tblActualLoadDetailsRFT') ALTER TABLE ##tblActualLoadDetailsRFT ADD [LOPlannedUserID]	NVARCHAR(30) NULL	--##tblLightsOutPlanned.PLND_USER_ID
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'LOPlannedCount'		AND TABLE_NAME LIKE '##tblActualLoadDetailsRFT') ALTER TABLE ##tblActualLoadDetailsRFT ADD [LOPlannedCount]		INT NULL			--##tblLightsOutPlanned.PLND_PROCSSD_CNT
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'LOTenderedStatus'	AND TABLE_NAME LIKE '##tblActualLoadDetailsRFT') ALTER TABLE ##tblActualLoadDetailsRFT ADD [LOTenderedStatus]	NVARCHAR(10) NULL	--##tblLightsOutTendered.TDR_STATUS
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'LOTenderedDesc'		AND TABLE_NAME LIKE '##tblActualLoadDetailsRFT') ALTER TABLE ##tblActualLoadDetailsRFT ADD [LOTenderedDesc]		NVARCHAR(300) NULL	--##tblLightsOutTendered.TDR_STATUS_DESC
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'LOTenderedOn'		AND TABLE_NAME LIKE '##tblActualLoadDetailsRFT') ALTER TABLE ##tblActualLoadDetailsRFT ADD [LOTenderedOn]		DATETIME NULL		--##tblLightsOutTendered.TDR_MNT_TMESTMP
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'LOTenderedUserID'	AND TABLE_NAME LIKE '##tblActualLoadDetailsRFT') ALTER TABLE ##tblActualLoadDetailsRFT ADD [LOTenderedUserID]	NVARCHAR(30) NULL	--##tblLightsOutTendered.TDR_USR_ID
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'LOTenderedCount'	AND TABLE_NAME LIKE '##tblActualLoadDetailsRFT') ALTER TABLE ##tblActualLoadDetailsRFT ADD [LOTenderedCount]	INT NULL			--##tblLightsOutTendered.TDR_PROCSSD_CNT

/*
Update with Lights Out Planned Details
SELECT * FROM ##tblLightsOutPlanned
*/
UPDATE ##tblActualLoadDetailsRFT
SET LOPlannedStatus = lop.PLND_STATUS,
LOPlannedDesc		= lop.PLND_STATUS_DESC,
LOPlannedOn			= lop.PLND_MNT_TMESTMP,
LOPlannedUserID		= lop.PLND_USER_ID,
LOPlannedCount		= lop.PLND_PROCSSD_CNT
FROM ##tblActualLoadDetailsRFT ald
INNER JOIN ##tblLightsOutPlanned lop ON ald.load_number = lop.load_number

/*
Update with Lights Out Tendered Details
SELECT * FROM ##tblLightsOutTendered

SELECT * FROM ##tblActualLoadDetailsRFT
*/
UPDATE ##tblActualLoadDetailsRFT
SET LOTenderedStatus	= lot.TDR_STATUS,
LOTenderedDesc			= lot.TDR_STATUS_DESC,
LOTenderedOn			= lot.TDR_MNT_TMESTMP,
LOTenderedUserID		= lot.TDR_USR_ID,
LOTenderedCount			= lot.TDR_PROCSSD_CNT
FROM ##tblActualLoadDetailsRFT ald
INNER JOIN ##tblLightsOutTendered lot ON ald.load_number = lot.load_number

/*
Create count columns, and update from ##tblManuallyTouchedAggregate
SELECT * FROM ##tblManuallyTouchedAggregate

SELECT * FROM ##tblManuallyTouchedAggregate where LoadNumber = '516700339'

SELECT * FROM ##tblActualLoadDetailsRFT WHERE LOAD_NUMBER = '516700339'
SELECT DISTINCT Reason, Ordinal, SUM(TimesTouched) as TimesTouched, Count (Distinct LoadNumber) as LoadCount FROM ##tblManuallyTouchedAggregate GROUP BY Reason, Ordinal ORDER BY Ordinal ASC
*/
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'LOPlanned'				AND TABLE_NAME LIKE '##tblActualLoadDetailsRFT') ALTER TABLE ##tblActualLoadDetailsRFT ADD LOPlanned				INT NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'LOTendered'				AND TABLE_NAME LIKE '##tblActualLoadDetailsRFT') ALTER TABLE ##tblActualLoadDetailsRFT ADD LOTendered				INT NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'AppointmentDeleted'		AND TABLE_NAME LIKE '##tblActualLoadDetailsRFT') ALTER TABLE ##tblActualLoadDetailsRFT ADD [AppointmentDeleted]		INT NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'ConfirmReversal'		AND TABLE_NAME LIKE '##tblActualLoadDetailsRFT') ALTER TABLE ##tblActualLoadDetailsRFT ADD [ConfirmReversal]		INT NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'DockChanged'			AND TABLE_NAME LIKE '##tblActualLoadDetailsRFT') ALTER TABLE ##tblActualLoadDetailsRFT ADD [DockChanged]			INT NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'DockCreated'			AND TABLE_NAME LIKE '##tblActualLoadDetailsRFT') ALTER TABLE ##tblActualLoadDetailsRFT ADD [DockCreated]			INT NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'DockDeleted'			AND TABLE_NAME LIKE '##tblActualLoadDetailsRFT') ALTER TABLE ##tblActualLoadDetailsRFT ADD [DockDeleted]			INT NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'LoadUnsuspended'		AND TABLE_NAME LIKE '##tblActualLoadDetailsRFT') ALTER TABLE ##tblActualLoadDetailsRFT ADD [LoadUnsuspended]		INT NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'ManuallyAccepted'		AND TABLE_NAME LIKE '##tblActualLoadDetailsRFT') ALTER TABLE ##tblActualLoadDetailsRFT ADD [ManuallyAccepted]		INT NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'ManuallyPlanned'		AND TABLE_NAME LIKE '##tblActualLoadDetailsRFT') ALTER TABLE ##tblActualLoadDetailsRFT ADD [ManuallyPlanned]		INT NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'ManuallyTendered'		AND TABLE_NAME LIKE '##tblActualLoadDetailsRFT') ALTER TABLE ##tblActualLoadDetailsRFT ADD [ManuallyTendered]		INT NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'TenderCancelled'		AND TABLE_NAME LIKE '##tblActualLoadDetailsRFT') ALTER TABLE ##tblActualLoadDetailsRFT ADD [TenderCancelled]		INT NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'TenderRejected'			AND TABLE_NAME LIKE '##tblActualLoadDetailsRFT') ALTER TABLE ##tblActualLoadDetailsRFT ADD [TenderRejected]			INT NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'CAPSManuallyReviewed'	AND TABLE_NAME LIKE '##tblActualLoadDetailsRFT') ALTER TABLE ##tblActualLoadDetailsRFT ADD [CAPSManuallyReviewed]	INT NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'TotalTouches'			AND TABLE_NAME LIKE '##tblActualLoadDetailsRFT') ALTER TABLE ##tblActualLoadDetailsRFT ADD [TotalTouches]			INT NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'TotalProcessTouches'	AND TABLE_NAME LIKE '##tblActualLoadDetailsRFT') ALTER TABLE ##tblActualLoadDetailsRFT ADD [TotalProcessTouches]	INT NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'FirstFailure'			AND TABLE_NAME LIKE '##tblActualLoadDetailsRFT') ALTER TABLE ##tblActualLoadDetailsRFT ADD [FirstFailure]			NVARCHAR(50) NULL

/*
Create temp table for Dynamically Pivoted Reason Table
SELECT * FROM ##tblManuallyTouchedAggregate
SELECT * FROM ##tblManuallyTouchedPivot
SELECT * FROM ##tblManuallyTouchedHighLevel
*/
DECLARE @cols AS NVARCHAR(MAX),
@query AS NVARCHAR(MAX)
DROP TABLE IF EXISTS ##tblManuallyTouchedPivot

SET @cols = STUFF((
			SELECT DISTINCT ',' + QUOTENAME(c.Reason)
			FROM ##tblManuallyTouchedAggregate c
			FOR XML PATH(''),
				TYPE
			).value('.', 'NVARCHAR(MAX)'), 1, 1, '')

SET @query = 'SELECT LoadNumber as LoadNumber, ' + @cols + ' from 
            (
                select prdr.LoadNumber
                    , prdr.Reason
					, prdr.TimesTouched

                from ##tblManuallyTouchedAggregate	prdr	
           ) x
            pivot 
            (
                 SUM(TimesTouched)
                for Reason in (' + @cols + ')
            ) p '
SET @query = 'select * into ##tblManuallyTouchedPivot from (' + @query + ') y'
EXECUTE (@query)

/*
Create temp table for high level counts
SELECT * FROM ##tblManuallyTouchedHighLevel
*/
DROP TABLE IF EXISTS ##tblManuallyTouchedHighLevel
SELECT * INTO ##tblManuallyTouchedHighLevel FROM (SELECT mta.LoadNumber, min.MinOrdinal, mta.Reason as FirstFailure, count.TotalProcessTouches, Count.TotalTouches
FROM ##tblManuallyTouchedAggregate mta
INNER JOIN (SELECT LoadNumber, MIN(Ordinal) as MinOrdinal FROM ##tblManuallyTouchedAggregate GROUP BY LoadNumber) min on min.LoadNumber = mta.LoadNumber and min.MinOrdinal = mta.Ordinal
INNER JOIN (Select LoadNumber, SUM(TimesTouched) as TotalTouches, COUNT(LoadNumber) as TotalProcessTouches FROM ##tblManuallyTouchedAggregate mta GROUP BY LoadNumber) count on count.LoadNumber = mta.LoadNumber)data

/*
Need to add missing pivot columns, just in case they don't appear in the raw data
SELECT * FROM ##tblManuallyTouchedPivot
*/
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'Appointment Deleted'	AND TABLE_NAME LIKE '##tblManuallyTouchedPivot') ALTER TABLE ##tblManuallyTouchedPivot ADD [Appointment Deleted]	INT NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'Confirm Reversal'		AND TABLE_NAME LIKE '##tblManuallyTouchedPivot') ALTER TABLE ##tblManuallyTouchedPivot ADD [Confirm Reversal]		INT NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'Dock Changed'			AND TABLE_NAME LIKE '##tblManuallyTouchedPivot') ALTER TABLE ##tblManuallyTouchedPivot ADD [Dock Changed]			INT NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'Dock Created'			AND TABLE_NAME LIKE '##tblManuallyTouchedPivot') ALTER TABLE ##tblManuallyTouchedPivot ADD [Dock Created]			INT NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'Dock Deleted'			AND TABLE_NAME LIKE '##tblManuallyTouchedPivot') ALTER TABLE ##tblManuallyTouchedPivot ADD [Dock Deleted]			INT NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'Load Unsuspended'		AND TABLE_NAME LIKE '##tblManuallyTouchedPivot') ALTER TABLE ##tblManuallyTouchedPivot ADD [Load Unsuspended]		INT NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'Manually Accepted'		AND TABLE_NAME LIKE '##tblManuallyTouchedPivot') ALTER TABLE ##tblManuallyTouchedPivot ADD [Manually Accepted]		INT NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'Manually Planned'		AND TABLE_NAME LIKE '##tblManuallyTouchedPivot') ALTER TABLE ##tblManuallyTouchedPivot ADD [Manually Planned]		INT NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'Manually Tendered'		AND TABLE_NAME LIKE '##tblManuallyTouchedPivot') ALTER TABLE ##tblManuallyTouchedPivot ADD [Manually Tendered]		INT NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'Tender Cancelled'		AND TABLE_NAME LIKE '##tblManuallyTouchedPivot') ALTER TABLE ##tblManuallyTouchedPivot ADD [Tender Cancelled]		INT NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'Tender Rejected'		AND TABLE_NAME LIKE '##tblManuallyTouchedPivot') ALTER TABLE ##tblManuallyTouchedPivot ADD [Tender Rejected]		INT NULL

/*
Update ##tblActualLoadDetails to match Pivot table and ##tblManuallyTouchedHighlevl
SELECT * FROM ##tblManuallyTouchedAggregate WHERE LoadNumber = 516796667
SELECT * FROM ##tblActualLoadDetailsRFT Where LOAD_NUMBER = 516796667
SELECT * FROM ##tblManuallyTouchedHighLevel WHERE LoadNumber = 516796667
*/

UPDATE ##tblActualLoadDetailsRFT
SET AppointmentDeleted = mtp.[Appointment Deleted],
ConfirmReversal = mtp.[Confirm Reversal],
DockChanged = mtp.[Dock Changed],
DockCreated = mtp.[Dock Created],
DockDeleted = mtp.[Dock Deleted],
LoadUnsuspended = mtp.[Load Unsuspended],
ManuallyAccepted = mtp.[Manually Accepted],
ManuallyPlanned = mtp.[Manually Planned],
ManuallyTendered = mtp.[Manually Tendered],
TenderCancelled = mtp.[Tender Cancelled],
TenderRejected = mtp.[Tender Rejected],
TotalTouches = mthl.[TotalTouches],
TotalProcessTouches = mthl.[TotalProcessTouches],
FirstFailure = mthl.FirstFailure 
FROM ##tblActualLoadDetailsRFT ald
INNER JOIN ##tblManuallyTouchedPivot mtp ON mtp.LoadNumber = ald.load_number
INNER JOIN ##tblManuallyTouchedHighLevel mthl on mthl.LoadNumber = ald.load_number

/*
SELECT * FROM USCTTDEV.dbo.tblRFTDetailDataHistoricalNew
Update USCTTDEV.dbo.tblRFTDetailDataHistoricalNew to match all data from ##tblActualLoadDetailsRFT
SELECT DISTINCT LOTenderedOn FROM  ##tblActualLoadDetailsRFT
*/
UPDATE USCTTDEV.dbo.tblRFTDetailDataHistoricalNew
SET 
LastUpdated = GETDATE(),
currentstatus = rfdh.currentstatus,
currentStatusDesc = rfdh.currentStatusDesc,
LOPlannedStatus = rfdh.LOPlannedStatus,
LOPlannedDesc = rfdh.LOPlannedDesc,
LOPlannedOn = rfdh.LOPlannedOn,
LOPlannedUserID = rfdh.LOPlannedUserID,
LOPlannedCount = rfdh.LOPlannedCount,
LOTenderedStatus = rfdh.LOTenderedStatus,
LOTenderedDesc = rfdh.LOTenderedDesc,
LOTenderedOn = rfdh.LOTenderedOn,
LOTenderedUserID = rfdh.LOTenderedUserID,
LOTenderedCount = rfdh.LOTenderedCount,
AppointmentDeleted = rfdh.AppointmentDeleted,
ConfirmReversal = rfdh.ConfirmReversal,
DockChanged = rfdh.DockChanged,
DockCreated = rfdh.DockCreated,
DockDeleted = rfdh.DockDeleted,
LoadUnsuspended = rfdh.LoadUnsuspended,
ManuallyAccepted = rfdh.ManuallyAccepted,
ManuallyPlanned = rfdh.ManuallyPlanned,
ManuallyTendered = rfdh.ManuallyTendered,
TenderCancelled = rfdh.TenderCancelled,
TenderRejected = rfdh.TenderRejected,
TotalTouches = rfdh.TotalTouches,
TotalProcessTouches = rfdh.TotalProcessTouches,
FirstFailure = rfdh.FirstFailure,
LOPlanned = rfdh.LOPlanned,
LOTendered = rfdh.LOTendered,
CAPSManuallyReviewed = rfdh.CAPSManuallyReviewed
FROM USCTTDEV.dbo.tblRFTDetailDataHistoricalNew rfdh
INNER JOIN ##tblActualLoadDetailsRFT ald ON ald.load_number = rfdh.load_number

/*
Add new lines to tblRFTDetailDataHistoricalNew from ##tblActualLoadDetailsRFT where they don't exist
*/
INSERT INTO USCTTDEV.dbo.tblRFTDetailDataHistoricalNew(
AddedOn,
LastUpdated,
Shipment_Type,
ImportExport,
DomesticInt,
shpd_dtt,
load_number,
origin_id,
origin_name,
orig_city,
orig_state,
orig_zip,
orig_country,
stop_num,
shpm_num_count,
dest_id,
dest_name,
dest_city,
dest_state,
dest_zip,
dest_country,
carrier,
service,
eq_type,
miles,
num_stop,
num_shpm,
que_id,
ld_source,
plan_id,
team_name,
team_leader_id,
team_leader_name,
analyst_id,
analyst_name,
ld_compl_yn,
corp_id,
currentstatus,
currentStatusDesc,
createdate,
BU,
LOPlannedStatus,
LOPlannedDesc,
LOPlannedOn,
LOPlannedUserID,
LOPlannedCount,
LOTenderedStatus,
LOTenderedDesc,
LOTenderedOn,
LOTenderedUserID,
LOTenderedCount,
FirstFailure,
TotalTouches,
TotalProcessTouches,
LOPlanned,
LOTendered,
ManuallyAccepted,
TenderCancelled,
TenderRejected,
ConfirmReversal,
LoadUnsuspended,
DockDeleted,
DockCreated,
DockChanged,
AppointmentDeleted,
ManuallyPlanned,
ManuallyTendered,
CAPSManuallyReviewed)
SELECT 
GETDATE(),
GETDATE(),
ald.Shipment_Type,
ald.ImportExport,
ald.DomesticInt,
ald.shpd_dtt,
ald.load_number,
ald.origin_id,
ald.origin_name,
ald.orig_city,
ald.orig_state,
ald.orig_zip,
ald.orig_country,
ald.stop_num,
ald.shpm_num_count,
ald.dest_id,
ald.dest_name,
ald.dest_city,
ald.dest_state,
ald.dest_zip,
ald.dest_country,
ald.carrier,
ald.service,
ald.eq_type,
ald.miles,
ald.num_stop,
ald.num_shpm,
ald.que_id,
ald.ld_source,
ald.plan_id,
ald.team_name,
ald.team_leader_id,
ald.team_leader_name,
ald.analyst_id,
ald.analyst_name,
ald.ld_compl_yn,
ald.corp_id,
ald.currentstatus,
ald.currentStatusDesc,
ald.createdate,
ald.BU,
ald.LOPlannedStatus,
ald.LOPlannedDesc,
ald.LOPlannedOn,
ald.LOPlannedUserID,
ald.LOPlannedCount,
ald.LOTenderedStatus,
ald.LOTenderedDesc,
ald.LOTenderedOn,
ald.LOTenderedUserID,
ald.LOTenderedCount,
ald.FirstFailure,
ald.TotalTouches,
ald.TotalProcessTouches,
ald.LOPlanned,
ald.LOTendered,
ald.ManuallyAccepted,
ald.TenderCancelled,
ald.TenderRejected,
ald.ConfirmReversal,
ald.LoadUnsuspended,
ald.DockDeleted,
ald.DockCreated,
ald.DockChanged,
ald.AppointmentDeleted,
ald.ManuallyPlanned,
ald.ManuallyTendered,
ald.CAPSManuallyReviewed
FROM ##tblActualLoadDetailsRFT ald      
LEFT JOIN USCTTDEV.dbo.tblRFTDetailDataHistoricalNew rfdh ON rfdh.load_number = ald.load_number
WHERE rfdh.load_number IS NULL
ORDER BY ald.CreateDate ASC, load_number ASC

/*
Add Manually Touched Details to USCTTDEV.dbo.tblRFTManuallyTouchedDetails
*/
INSERT INTO USCTTDEV.dbo.tblRFTManuallyTouchedDetails(AddedOn, LoadNumber, LoadCount, Reason, Ordinal, User_Login, User_Name, EventDate)
SELECT GETDATE(), mtdt.LoadNumber, mtdt.LoadCount, mtdt.Reason, mtdt.Ordinal, mtdt.User_Login, mtdt.User_Name, mtdt.EventDate
FROM ##tblManuallyTouchedDetails mtdt
LEFT JOIN USCTTDEV.dbo.tblRFTManuallyTouchedDetails mtd ON mtd.LoadNumber = mtdt.LoadNumber AND mtd.EventDate = mtdt.EventDate
WHERE mtd.LoadNumber IS NULL AND mtd.EventDate IS NULL
ORDER BY mtdt.LoadNumber ASC, mtdt.Ordinal ASC, mtdt.EventDate ASC

/*
CAPS Manually Reviewed Details
Create temp table with CAPS Manually Reviewed Details	

SELECT * FROM ##tblCAPSManuallyReviewed
*/
DROP TABLE IF EXISTS ##tblCAPSManuallyReviewed
SELECT * INTO ##tblCAPSManuallyReviewed FROM OPENQUERY(NAJDAPRD, '
SELECT DISTINCT
    load_id,
    COUNT(*) AS LoadCount,
    ''CAPS MANUALLY REVIEWED'' AS Reason,
    12 AS Ordinal,
    SCORED_BY AS USER_LOGIN,
    NAME AS USER_NAME,
    REVIEWED_DATE AS EVENTDATE
FROM
    (
        SELECT DISTINCT
            aocm.load_id,
            aocm.stop_num,
            aocm.updates_num,
            aocm.reviewed_date,
            aocm.carrier_scac,
            aocm.service,
            aocm.caps_memo,
            aocm.scoring_type,
            aocm.scored_by,
            usr.name
        FROM
            najdatrn.abpp_otc_caps_master   aocm
            INNER JOIN nai2padm.usr_t       usr ON usr.usr_cd = scored_by
    ) data
GROUP BY
    load_id, ''CAPS MANUALLY REVIEWED'', 12, SCORED_BY, NAME, 
REVIEWED_DATE
')

/*
Add CAPS Manually Reviewed Details to dbo.tblRFTManuallyTouchedDetails
*/
INSERT INTO USCTTDEV.dbo.tblRFTManuallyTouchedDetails(AddedOn, LoadNumber, LoadCount, Reason, Ordinal, User_Login, User_Name, EventDate)
SELECT GETDATE(), cmr.Load_ID, cmr.LoadCount, cmr.Reason, cmr.Ordinal, cmr.User_Login, cmr.User_Name, cmr.EventDate
FROM ##tblCAPSManuallyReviewed cmr
LEFT JOIN USCTTDEV.dbo.tblRFTManuallyTouchedDetails mtd ON mtd.LoadNumber = cmr.Load_ID AND mtd.EventDate = cmr.EventDate
WHERE mtd.LoadNumber IS NULL AND mtd.EventDate IS NULL
ORDER BY cmr.Load_ID ASC, cmr.Ordinal ASC, cmr.EventDate ASC

/*
Create temp table for Dynamically Pivoted Reason Table
*/
DROP TABLE IF EXISTS ##tblManuallyTouchedPivotFinal
DECLARE @cols AS NVARCHAR(MAX),
@query AS NVARCHAR(MAX)
SET @cols = STUFF((
			SELECT DISTINCT ',' + QUOTENAME(c.Reason)
			FROM USCTTDEV.dbo.tblRFTManuallyTouchedDetails c
			FOR XML PATH(''),
				TYPE
			).value('.', 'NVARCHAR(MAX)'), 1, 1, '')

SET @query = 'SELECT LoadNumber as LoadNumber, ' + @cols + ' from 
            (
                select prdr.LoadNumber
                    , prdr.Reason
					, prdr.LoadCount

                from USCTTDEV.dbo.tblRFTManuallyTouchedDetails prdr	
           ) x
            pivot 
            (
                 SUM(LoadCount)
                for Reason in (' + @cols + ')
            ) p '
SET @query = 'select * into ##tblManuallyTouchedPivotFinal from (' + @query + ') y'
EXECUTE (@query)

IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'Appointment Deleted'	AND TABLE_NAME LIKE '##tblManuallyTouchedPivotFinal') ALTER TABLE ##tblManuallyTouchedPivotFinal ADD [Appointment Deleted]			INT NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'Confirm Reversal'		AND TABLE_NAME LIKE '##tblManuallyTouchedPivotFinal') ALTER TABLE ##tblManuallyTouchedPivotFinal ADD [Confirm Reversal]				INT NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'Dock Changed'			AND TABLE_NAME LIKE '##tblManuallyTouchedPivotFinal') ALTER TABLE ##tblManuallyTouchedPivotFinal ADD [Dock Changed]					INT NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'Dock Created'			AND TABLE_NAME LIKE '##tblManuallyTouchedPivotFinal') ALTER TABLE ##tblManuallyTouchedPivotFinal ADD [Dock Created]					INT NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'Dock Deleted'			AND TABLE_NAME LIKE '##tblManuallyTouchedPivotFinal') ALTER TABLE ##tblManuallyTouchedPivotFinal ADD [Dock Deleted]					INT NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'Load Unsuspended'		AND TABLE_NAME LIKE '##tblManuallyTouchedPivotFinal') ALTER TABLE ##tblManuallyTouchedPivotFinal ADD [Load Unsuspended]				INT NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'Manually Accepted'		AND TABLE_NAME LIKE '##tblManuallyTouchedPivotFinal') ALTER TABLE ##tblManuallyTouchedPivotFinal ADD [Manually Accepted]			INT NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'Manually Planned'		AND TABLE_NAME LIKE '##tblManuallyTouchedPivotFinal') ALTER TABLE ##tblManuallyTouchedPivotFinal ADD [Manually Planned]				INT NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'Manually Tendered'		AND TABLE_NAME LIKE '##tblManuallyTouchedPivotFinal') ALTER TABLE ##tblManuallyTouchedPivotFinal ADD [Manually Tendered]			INT NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'Tender Cancelled'		AND TABLE_NAME LIKE '##tblManuallyTouchedPivotFinal') ALTER TABLE ##tblManuallyTouchedPivotFinal ADD [Tender Cancelled]				INT NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'Tender Rejected'		AND TABLE_NAME LIKE '##tblManuallyTouchedPivotFinal') ALTER TABLE ##tblManuallyTouchedPivotFinal ADD [Tender Rejected]				INT NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'CAPS Manually Reviewed'	AND TABLE_NAME LIKE '##tblManuallyTouchedPivotFinal') ALTER TABLE ##tblManuallyTouchedPivotFinal ADD [CAPS Manually Reviewed]		INT NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'FirstFailure'			AND TABLE_NAME LIKE '##tblManuallyTouchedPivotFinal') ALTER TABLE ##tblManuallyTouchedPivotFinal ADD [FirstFailure]					NVARCHAR(100) NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'TotalTouches'			AND TABLE_NAME LIKE '##tblManuallyTouchedPivotFinal') ALTER TABLE ##tblManuallyTouchedPivotFinal ADD [TotalTouches]					INT NULL
IF NOT EXISTS (SELECT * FROM TempDB.INFORMATION_SCHEMA.COLUMNS WHERE COLUMN_NAME = 'TotalProcessTouches'	AND TABLE_NAME LIKE '##tblManuallyTouchedPivotFinal') ALTER TABLE ##tblManuallyTouchedPivotFinal ADD [TotalProcessTouches]			INT NULL

/*
SELECT * FROM ##tblManuallyTouchedPivotFinal
SELECT DISTINCT Ordinal, Reason FROM USCTTDEV.dbo.tblRFTManuallyTouchedDetails ORDER BY ORDINAL ASC
1	MANUALLY ACCEPTED
2	TENDER CANCELLED
3	TENDER REJECTED
4	CONFIRM REVERSAL
5	LOAD UNSUSPENDED
6	DOCK DELETED
7	DOCK CREATED
8	DOCK CHANGED
9	APPOINTMENT DELETED
10	MANUALLY PLANNED
11	MANUALLY TENDERED
12	CAPS MANUALLY REVIEWED
*/

/*
Create final pivoted table for all change reasons/people

SELECT * FROM ##tblManuallyTouchedPivotFinal
*/
UPDATE ##tblManuallyTouchedPivotFinal
SET FirstFailure = CASE WHEN [MANUALLY ACCEPTED] IS NOT NULL THEN 'MANUALLY ACCEPTED'
WHEN [TENDER CANCELLED] IS NOT NULL THEN 'TENDER CANCELLED'
WHEN [TENDER REJECTED] IS NOT NULL THEN 'TENDER REJECTED'
WHEN [CONFIRM REVERSAL] IS NOT NULL THEN 'CONFIRM REVERSAL'
WHEN [LOAD UNSUSPENDED] IS NOT NULL THEN 'LOAD UNSUSPENDED'
WHEN [DOCK DELETED] IS NOT NULL THEN 'DOCK DELETED'
WHEN [DOCK CREATED] IS NOT NULL THEN 'DOCK CREATED'
WHEN [DOCK CHANGED] IS NOT NULL THEN 'DOCK CHANGED'
WHEN [APPOINTMENT DELETED] IS NOT NULL THEN 'APPOINTMENT DELETED'
WHEN [MANUALLY PLANNED] IS NOT NULL THEN 'MANUALLY PLANNED'
WHEN [MANUALLY TENDERED] IS NOT NULL THEN 'MANUALLY TENDERED'
WHEN [CAPS MANUALLY REVIEWED] IS NOT NULL THEN 'CAPS MANUALLY REVIEWED'
END,
TotalTouches = COALESCE([MANUALLY ACCEPTED],0) + 
COALESCE([TENDER CANCELLED],0) +
COALESCE([TENDER REJECTED],0) + 
COALESCE([CONFIRM REVERSAL],0) + 
COALESCE([LOAD UNSUSPENDED],0) +
COALESCE([DOCK DELETED],0) + 
COALESCE([DOCK CREATED],0) + 
COALESCE([DOCK CHANGED],0) + 
COALESCE([APPOINTMENT DELETED],0) + 
COALESCE([MANUALLY PLANNED],0) + 
COALESCE([MANUALLY TENDERED],0) + 
COALESCE([CAPS MANUALLY REVIEWED],0),
TotalProcessTouches = IIF([Manually Accepted] IS NOT NULL,1,0) +
IIF([TENDER CANCELLED] IS NOT NULL,1,0) +
IIF([TENDER REJECTED] IS NOT NULL,1,0) +
IIF([CONFIRM REVERSAL] IS NOT NULL,1,0) +
IIF([LOAD UNSUSPENDED] IS NOT NULL,1,0) +
IIF([DOCK DELETED] IS NOT NULL,1,0) +
IIF([DOCK CREATED] IS NOT NULL,1,0) +
IIF([DOCK CHANGED] IS NOT NULL,1,0) +
IIF([APPOINTMENT DELETED] IS NOT NULL,1,0) +
IIF([MANUALLY PLANNED] IS NOT NULL,1,0) +
IIF([MANUALLY TENDERED] IS NOT NULL,1,0) +
IIF([CAPS MANUALLY REVIEWED] IS NOT NULL,1,0)

/*
SELECT * FROM USCTTDEV.dbo.tblRFTDetailDataHistoricalNew WHERE ID < 100
SELECT DISTINCT LoadNumber, COUNT(*) AS COUNT FROM ##tblManuallyTouchedPivotFinal GROUP BY LoadNumber HAVING COUNT(*)<>1

1	MANUALLY ACCEPTED
2	TENDER CANCELLED
3	TENDER REJECTED
4	CONFIRM REVERSAL
5	LOAD UNSUSPENDED
6	DOCK DELETED
7	DOCK CREATED
8	DOCK CHANGED
9	APPOINTMENT DELETED
10	MANUALLY PLANNED
11	MANUALLY TENDERED
12	CAPS MANUALLY REVIEWED

SELECT * FROM USCTTDEV.dbo.tblRFTDetailDataHistoricalNew ORDER BY ID ASC
*/

UPDATE USCTTDEV.dbo.tblRFTDetailDataHistoricalNew
SET ManuallyAccepted  = mtpf.[MANUALLY ACCEPTED],
TenderCancelled = mtpf.[TENDER CANCELLED],
TenderRejected = mtpf.[TENDER REJECTED],
ConfirmReversal = mtpf.[CONFIRM REVERSAL],
LoadUnsuspended = mtpf.[LOAD UNSUSPENDED],
DockDeleted = mtpf.[DOCK DELETED],
DockCreated = mtpf.[DOCK CREATED],
DockChanged = mtpf.[DOCK CHANGED],
AppointmentDeleted = mtpf.[APPOINTMENT DELETED],
ManuallyPlanned = mtpf.[MANUALLY PLANNED],
ManuallyTendered = mtpf.[MANUALLY TENDERED],
CAPSManuallyReviewed = mtpf.[CAPS MANUALLY REVIEWED],
FirstFailure = mtpf.FirstFailure,
TotalTouches = mtpf.TotalTouches,
TotalProcessTouches = mtpf.TotalProcessTouches
FROM USCTTDEV.dbo.tblRFTDetailDataHistoricalNew rftNew
INNER JOIN ##tblManuallyTouchedPivotFinal mtpf ON mtpf.LoadNumber = rftNew.load_number