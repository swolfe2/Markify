***************************************************************************************************************************;
**  THE PURPOSE OF THIS PROGRAM IS TO PROVIDE RIGHT FIRST TIME (RFT) DATA                                                 *;
***************************************************************************************************************************;

ODS HTML CLOSE;
ODS HTML;
dm 'clear log';
dm 'clear output';

%let id  = 'TMDW';
%let pwd = 'F2KYlqUWIfTwW7zI';

*************************************************************************************************************************;
** PULL LOAD TENDER ACCEPT DETAILS                                                                                     **;
*************************************************************************************************************************;

PROC SQL;
      connect to oracle (path='NAJDABAP' user=&id password=&pwd);
      create table TNDR_ACCEPT as select * from connection to oracle

(SELECT DISTINCT
	IA_DIST_LOADS.LOAD_ID as Load_Number, 
	Count(distinct IA_DIST_LOADS.EVENT_LOG_DT) as Accept_Cnt

FROM  
	IA_DIST_LOADS IA_DIST_LOADS, 
	IA_EXCEPTION_CODE IA_EXCEPTION_CODE,
	IA_USERS IA_USERS

WHERE 
	IA_DIST_LOADS.EXCPT_CODE_KEY = IA_EXCEPTION_CODE.EXCPT_CODE_KEY AND 
	IA_DIST_LOADS.EVNT_USER_KEY = IA_USERS.USER_KEY AND
	(IA_DIST_LOADS.EVENT_LOG_DT>=add_months(trunc(SYSDATE, 'mm'), - 2)) AND 
	(IA_EXCEPTION_CODE.EXCEPTION_CODE='ACPD') AND 
	(substr(USER_LOGIN,1,1) Not In ('*','9'))

GROUP BY
	IA_DIST_LOADS.LOAD_ID

ORDER BY 
	IA_DIST_LOADS.LOAD_ID

);

DISCONNECT FROM ORACLE;

QUIT; 

RUN; 

*************************************************************************************************************************;
** PULL LOAD TENDER CANCEL DETAILS                                                                                            **;
*************************************************************************************************************************;


PROC SQL;
      connect to oracle (path='NAJDABAP' user=&id password=&pwd);
      create table TNDR_CNCL as select * from connection to oracle

(SELECT DISTINCT
	IA_DIST_LOADS.LOAD_ID as Load_Number, 
	Count(distinct IA_DIST_LOADS.EVENT_LOG_DT) as Tender_Cncl_Cnt

FROM 
	IA_DIST_LOADS IA_DIST_LOADS,
	IA_EVNT_TYPE IA_EVNT_TYPE,
	IA_EXCEPTION_CODE IA_EXCEPTION_CODE,
	IA_USERS IA_USERS

WHERE 
	IA_DIST_LOADS.EVNT_TYPE_KEY = IA_EVNT_TYPE.EVNT_TYPE_KEY AND
	IA_DIST_LOADS.EXCPT_CODE_KEY = IA_EXCEPTION_CODE.EXCPT_CODE_KEY AND
	IA_DIST_LOADS.EVNT_USER_KEY = IA_USERS.USER_KEY AND
	((IA_DIST_LOADS.EVENT_LOG_DT>=add_months(trunc(SYSDATE, 'mm'), - 2)) AND
	(IA_EVNT_TYPE.EVNT_TYPE_CODE='TENDCNCL') AND
	(IA_EXCEPTION_CODE.EXCEPTION_CODE='PLND') AND
	(substr(USER_LOGIN,1,1) Not In ('*','9')))

GROUP BY
	IA_DIST_LOADS.LOAD_ID

ORDER BY
	IA_DIST_LOADS.LOAD_ID

);

DISCONNECT FROM ORACLE;

QUIT; 

RUN; 

*************************************************************************************************************************;
** PULL LOAD TENDER REJECT DETAILS                                                                                     **;
*************************************************************************************************************************;


PROC SQL;
      connect to oracle (path='NAJDABAP' user=&id password=&pwd);
      create table TNDR_REJ as select * from connection to oracle

(SELECT DISTINCT 
	IA_DIST_LOADS.LOAD_ID as Load_Number, 
	Count(distinct IA_DIST_LOADS.EVENT_LOG_DT) as Tender_Rej_Cnt

FROM  
	IA_DIST_LOADS IA_DIST_LOADS, 
	IA_EXCEPTION_CODE IA_EXCEPTION_CODE,
	IA_USERS IA_USERS

WHERE 
	IA_DIST_LOADS.EXCPT_CODE_KEY = IA_EXCEPTION_CODE.EXCPT_CODE_KEY AND 
	IA_DIST_LOADS.EVNT_USER_KEY = IA_USERS.USER_KEY and
	((IA_DIST_LOADS.EVENT_LOG_DT>=add_months(trunc(SYSDATE, 'mm'), - 2)) AND 
	(IA_EXCEPTION_CODE.EXCEPTION_CODE='REJD') AND 
	(substr(USER_LOGIN,1,1) Not In ('*','9')))

GROUP BY
	IA_DIST_LOADS.LOAD_ID

ORDER BY 
	IA_DIST_LOADS.LOAD_ID

);

DISCONNECT FROM ORACLE;

QUIT; 

RUN; 

*************************************************************************************************************************;
** PULL LOAD CONFIRMATION REVERSAL DETAILS                                                                                            **;
*************************************************************************************************************************;

PROC SQL;
      connect to oracle (path='NAJDABAP' user=&id password=&pwd);
      create table CNFRM_REV as select * from connection to oracle

(SELECT DISTINCT 
	IA_DIST_LOADS.LOAD_ID as Load_Number, 
	Count(distinct IA_DIST_LOADS.EVENT_LOG_DT) as Confirm_Reversal_Cnt

FROM  
	IA_DIST_LOADS IA_DIST_LOADS, 
	IA_EXCEPTION_CODE IA_EXCEPTION_CODE,
	IA_USERS IA_USERS

WHERE 
	IA_DIST_LOADS.EXCPT_CODE_KEY = IA_EXCEPTION_CODE.EXCPT_CODE_KEY AND 
	IA_DIST_LOADS.EVNT_USER_KEY = IA_USERS.USER_KEY and
	((IA_DIST_LOADS.EVENT_LOG_DT>=add_months(trunc(SYSDATE, 'mm'), - 2)) AND 
	(IA_EXCEPTION_CODE.EXCEPTION_CODE='REVS') AND 
	(substr(USER_LOGIN,1,1) Not In ('*','9')))

GROUP BY
	IA_DIST_LOADS.LOAD_ID

ORDER BY 
	IA_DIST_LOADS.LOAD_ID

);

DISCONNECT FROM ORACLE;

QUIT;

RUN;

*************************************************************************************************************************;
** PULL LOAD UNSUSPEND DETAILS                                                                                            **;
*************************************************************************************************************************;


PROC SQL;
      connect to oracle (path='NAJDABAP' user=&id password=&pwd);
      create table UNSUSPEND as select * from connection to oracle

(SELECT DISTINCT 
	IA_DIST_LOADS.LOAD_ID as Load_Number, 
	Count(distinct IA_DIST_LOADS.EVENT_LOG_DT) as Load_Unsuspend_Cnt

FROM  
	IA_DIST_LOADS IA_DIST_LOADS, 
	IA_EXCEPTION_CODE IA_EXCEPTION_CODE,
	IA_USERS IA_USERS

WHERE 
	IA_DIST_LOADS.EXCPT_CODE_KEY = IA_EXCEPTION_CODE.EXCPT_CODE_KEY AND 
	IA_DIST_LOADS.EVNT_USER_KEY = IA_USERS.USER_KEY and
	((IA_DIST_LOADS.EVENT_LOG_DT>=add_months(trunc(SYSDATE, 'mm'), - 2)) AND 
	(IA_EXCEPTION_CODE.EXCEPTION_CODE='LUNS') AND 
	(substr(USER_LOGIN,1,1) Not In ('*','9')))

GROUP BY
	IA_DIST_LOADS.LOAD_ID

ORDER BY 
	IA_DIST_LOADS.LOAD_ID

);

DISCONNECT FROM ORACLE;

QUIT;

RUN;

*************************************************************************************************************************;
** PULL DOCK DELETE DETAILS                                                                                            **;
*************************************************************************************************************************;

ODS HTML CLOSE;
ODS HTML;
dm 'clear log';
dm 'clear output';

%let id  = 'TMDW';
%let pwd = 'F2KYlqUWIfTwW7zI';

PROC SQL;
      connect to oracle (path='NAJDABAP' user=&id password=&pwd);
      create table DOCK_DEL as select * from connection to oracle

(SELECT DISTINCT 
	IA_DIST_LOADS.LOAD_ID as Load_Number, 
	Count(distinct IA_DIST_LOADS.EVENT_LOG_DT) as Dock_Delete_Cnt

FROM  
	IA_DIST_LOADS IA_DIST_LOADS, 
	IA_EXCEPTION_CODE IA_EXCEPTION_CODE,
	IA_USERS IA_USERS

WHERE 
	IA_DIST_LOADS.EXCPT_CODE_KEY = IA_EXCEPTION_CODE.EXCPT_CODE_KEY AND 
	IA_DIST_LOADS.EVNT_USER_KEY = IA_USERS.USER_KEY and
	((IA_DIST_LOADS.EVENT_LOG_DT>=add_months(trunc(SYSDATE, 'mm'), - 2)) AND 
	(IA_EXCEPTION_CODE.EXCEPTION_CODE='DKD_') AND 
	(substr(USER_LOGIN,1,1) Not In ('*','9')))

GROUP BY
	IA_DIST_LOADS.LOAD_ID

ORDER BY 
	IA_DIST_LOADS.LOAD_ID

);

DISCONNECT FROM ORACLE;

QUIT;

RUN;

*************************************************************************************************************************;
** PULL DOCK CREATE DETAILS                                                                                            **;
*************************************************************************************************************************;

PROC SQL;
      connect to oracle (path='NAJDABAP' user=&id password=&pwd);
      create table DOCK_CRT as select * from connection to oracle

(SELECT DISTINCT 
	IA_DIST_LOADS.LOAD_ID as Load_Number, 
	Count(distinct IA_DIST_LOADS.EVENT_LOG_DT) as Dock_Create_Cnt

FROM  
	IA_DIST_LOADS IA_DIST_LOADS, 
	IA_EXCEPTION_CODE IA_EXCEPTION_CODE,
	IA_USERS IA_USERS

WHERE 
	IA_DIST_LOADS.EXCPT_CODE_KEY = IA_EXCEPTION_CODE.EXCPT_CODE_KEY AND 
	IA_DIST_LOADS.EVNT_USER_KEY = IA_USERS.USER_KEY AND
	((IA_DIST_LOADS.EVENT_LOG_DT>=add_months(trunc(SYSDATE, 'mm'), - 2)) AND
	(IA_EXCEPTION_CODE.EXCEPTION_CODE='DKC_') AND 
	(substr(USER_LOGIN,1,1) Not In ('*','9')))

GROUP BY
	IA_DIST_LOADS.LOAD_ID

ORDER BY 
	IA_DIST_LOADS.LOAD_ID

);

DISCONNECT FROM ORACLE;

QUIT;

RUN;

*************************************************************************************************************************;
** PULL DOCK CHANGE DETAILS                                                                                            **;
*************************************************************************************************************************;

PROC SQL;
      connect to oracle (path='NAJDABAP' user=&id password=&pwd);
      create table DOCK_CHG as select * from connection to oracle

(SELECT DISTINCT 
	IA_DIST_LOADS.LOAD_ID as Load_Number, 
	Count(distinct IA_DIST_LOADS.EVENT_LOG_DT) as Dock_Change_Cnt

FROM  
	IA_DIST_LOADS IA_DIST_LOADS, 
	IA_EXCEPTION_CODE IA_EXCEPTION_CODE,
	IA_USERS IA_USERS

WHERE 
	IA_DIST_LOADS.EXCPT_CODE_KEY = IA_EXCEPTION_CODE.EXCPT_CODE_KEY AND 
	IA_DIST_LOADS.EVNT_USER_KEY = IA_USERS.USER_KEY AND
	((IA_DIST_LOADS.EVENT_LOG_DT>=add_months(trunc(SYSDATE, 'mm'), - 2)) AND
	(IA_EXCEPTION_CODE.EXCEPTION_CODE='DKH_') AND 
	(substr(USER_LOGIN,1,1) Not In ('*','9')))

GROUP BY
	IA_DIST_LOADS.LOAD_ID

ORDER BY 
	IA_DIST_LOADS.LOAD_ID

);

DISCONNECT FROM ORACLE;

QUIT;

RUN;

*************************************************************************************************************************;
** PULL APPOINTMENT DELETE DETAILS                                                                                     **;
*************************************************************************************************************************;


PROC SQL;
      connect to oracle (path='NAJDABAP' user=&id password=&pwd);
      create table APPT_DEL as select * from connection to oracle

(SELECT DISTINCT 
	IA_DIST_LOADS.LOAD_ID as Load_Number, 
	Count(distinct IA_DIST_LOADS.EVENT_LOG_DT) as Appt_Delete_Cnt

FROM  
	IA_DIST_LOADS IA_DIST_LOADS, 
	IA_EXCEPTION_CODE IA_EXCEPTION_CODE,
	IA_USERS IA_USERS

WHERE 
	IA_DIST_LOADS.EXCPT_CODE_KEY = IA_EXCEPTION_CODE.EXCPT_CODE_KEY AND 
	IA_DIST_LOADS.EVNT_USER_KEY = IA_USERS.USER_KEY AND
	((IA_DIST_LOADS.EVENT_LOG_DT>=add_months(trunc(SYSDATE, 'mm'), - 2)) AND
	(IA_EXCEPTION_CODE.EXCEPTION_CODE='APD_') AND 
	(substr(USER_LOGIN,1,1) Not In ('*','9')))

GROUP BY
	IA_DIST_LOADS.LOAD_ID

ORDER BY 
	IA_DIST_LOADS.LOAD_ID

);

DISCONNECT FROM ORACLE;

QUIT;

RUN;

*************************************************************************************************************************;
** PULL SUGGESTED APPOINTMENT STATUS                                                                                   **;
*************************************************************************************************************************;

ODS HTML CLOSE;
ODS HTML;
dm 'clear log';
dm 'clear output';

%let id  = 'NAI2PADM';
%let pwd = 'nai2padm';

PROC SQL;
      connect to oracle (path='NAJDAPRD' user=&id password=&pwd);
      create table SUG_APPT as select * from connection to oracle

(SELECT DISTINCT
    load_number,
    ship_num,
    appt_chg_time
FROM
    (
        SELECT DISTINCT
            abpp_otc_appointmenthistory.load_number       AS load_number,
            abpp_otc_appointmenthistory.shipment_number   AS ship_num,
            MIN(TO_CHAR(abpp_otc_appointmenthistory.appointment_change_time, 'mm/dd/yy hh:mm:ss')) AS appt_chg_time
        FROM
            trn_appt.abpp_otc_appointmenthistory   abpp_otc_appointmenthistory,
            najdaadm.load_leg_r                    load_leg_r
        WHERE
            abpp_otc_appointmenthistory.load_number = load_leg_r.ld_leg_id
            AND ( ( load_leg_r.crtd_dtt >= add_months(trunc(SYSDATE, 'mm'), - 2) )
                  AND ( abpp_otc_appointmenthistory.stop_number > '1' )
                  AND ( abpp_otc_appointmenthistory.appointment_status = 'Suggested' )
                  AND ( load_leg_r.frst_ctry_cd IN (
                'USA',
                'CAN',
                'MEX'
            ) ) )
        GROUP BY
            abpp_otc_appointmenthistory.load_number,
            abpp_otc_appointmenthistory.shipment_number
        UNION ALL
        SELECT DISTINCT
            abpp_otc_appointmenthistory.load_number       AS load_number,
            abpp_otc_appointmenthistory.shipment_number   AS ship_num,
            MIN(TO_CHAR(abpp_otc_appointmenthistory.appointment_change_time, 'mm/dd/yy hh:mm:ss')) AS appt_chg_time
        FROM
            trn_appt.abpp_otc_appointmenthistory   abpp_otc_appointmenthistory,
            najdaadm.load_leg_r                    load_leg_r
        WHERE
            abpp_otc_appointmenthistory.load_number = load_leg_r.ld_leg_id
            AND ( ( load_leg_r.crtd_dtt >= add_months(trunc(SYSDATE, 'mm'), - 2) )
                  AND ( abpp_otc_appointmenthistory.stop_number > '1' )
                  AND ( abpp_otc_appointmenthistory.appointment_status = 'Suggested' )
                  AND ( load_leg_r.last_ctry_cd IN (
                'USA',
                'CAN',
                'MEX'
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
    load_number);

DISCONNECT FROM ORACLE;

QUIT;

RUN;

*************************************************************************************************************************;
** PULL CONFIRM PICK APPOINTMENTS                                                                                      **;
*************************************************************************************************************************;

ODS HTML CLOSE;
ODS HTML;
dm 'clear log';
dm 'clear output';

%let id  = 'NAI2PADM';
%let pwd = 'nai2padm';

PROC SQL;
      connect to oracle (path='NAJDAPRD' user=&id password=&pwd);
      create table CONFIRM_PICK_APPT as select * from connection to oracle

(SELECT DISTINCT
    load_number,
    appt_chg_time
FROM
    (
        SELECT DISTINCT
            TO_CHAR(l.ld_leg_id) AS load_number,
            TO_CHAR(MIN(apt.appointment_change_time), 'mm/dd/yyyy hh:mm:ss') AS appt_chg_time
        FROM
            abpp_otc_appointmenthistory   apt,
            load_leg_r                    l
        WHERE
            apt.load_number = l.ld_leg_id
            AND ( l.crtd_dtt >= add_months(trunc(SYSDATE, 'mm'), - 2) )
            AND ( apt.stop_number = 1 )
            AND ( apt.appointment_status = 'Confirmed' )
            AND ( l.frst_ctry_cd IN (
                'USA',
                'CAN',
                'MEX'
            ) )
        GROUP BY
            l.ld_leg_id
        UNION ALL
        SELECT DISTINCT
            TO_CHAR(l.ld_leg_id) AS load_number,
            TO_CHAR(MIN(apt.appointment_change_time), 'mm/dd/yyyy hh:mm:ss') AS appt_chg_time
        FROM
            abpp_otc_appointmenthistory   apt,
            load_leg_r                    l
        WHERE
            apt.load_number = l.ld_leg_id
            AND ( l.crtd_dtt >= add_months(trunc(SYSDATE, 'mm'), - 2) )
            AND ( apt.stop_number = 1 )
            AND ( apt.appointment_status = 'Confirmed' )
            AND ( l.last_ctry_cd IN (
                'USA',
                'CAN',
                'MEX'
            ) )
        GROUP BY
            l.ld_leg_id
    ) results
GROUP BY
    load_number,
    appt_chg_time
ORDER BY
    load_number);

DISCONNECT FROM ORACLE;

QUIT;

RUN;

*************************************************************************************************************************;
** PULL UNROUTABLES DETAIL                                                                                             **;
*************************************************************************************************************************;

/*ODS HTML CLOSE;
ODS HTML;
dm 'clear log';
dm 'clear output'

%let id  = 'TMDW';;
%let pwd = 'F2KYlqUWIfTwW7zI';

PROC SQL;
      connect to oracle (path='NAJDABAP' user=&id password=&pwd);
      create table UNROUTABLES as select * from connection to oracle

(SELECT DISTINCT
	IA_DIST_SHPLEG.SHPM_NUM as Shpm_Num, 
	max(IA_DIST_SHPLEG.SYS_AUDT_DT) as System_Audit_Date

FROM 
	IA_DIST_SHPLEG IA_DIST_SHPLEG

WHERE 
	(IA_DIST_SHPLEG.OPT_QUE_ID Is Not Null) AND
	(IA_DIST_SHPLEG.OP_STATUS_KEY='378042') AND
	(IA_DIST_SHPLEG.SYS_AUDT_DT>=sysdate-5)

GROUP BY
	IA_DIST_SHPLEG.SHPM_NUM

ORDER BY 
	IA_DIST_SHPLEG.SHPM_NUM

);

DISCONNECT FROM ORACLE;

QUIT;

RUN;*/

*************************************************************************************************************************;
** PULL LOAD/SHIPMENT TABLE                                                                                            **;
*************************************************************************************************************************;

ODS HTML CLOSE;
ODS HTML;
dm 'clear log';
dm 'clear output';

%let id  = 'NAI2PADM';
%let pwd = 'nai2padm';


PROC SQL;
      connect to oracle (path='NAJDAPRD' user=&id password=&pwd);
      create table LOAD_SHPMNT as select * from connection to oracle

(SELECT DISTINCT
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
            load_leg_detail_r   load_leg_detail_r,
            load_leg_r          load_leg_r
        WHERE
            load_leg_r.ld_leg_id = load_leg_detail_r.ld_leg_id
            AND ( load_leg_r.crtd_dtt >= add_months(trunc(SYSDATE, 'mm'), - 2) )
            AND ( load_leg_r.frst_ctry_cd IN (
                'USA',
                'CAN',
                'MEX'
            ) )
            AND ( substr(load_leg_r.frst_shpg_loc_cd, 1, 1) <> 'R' )
            AND ( substr(load_leg_r.last_shpg_loc_cd, 1, 1) <> 'R' )
        GROUP BY
            load_leg_r.ld_leg_id
        UNION ALL
        SELECT DISTINCT
            load_leg_r.ld_leg_id AS load_number,
            MIN(load_leg_detail_r.shpm_num) AS shpm_num,
            COUNT(DISTINCT load_leg_r.ld_leg_id) AS load_leg_cnt
        FROM
            load_leg_detail_r   load_leg_detail_r,
            load_leg_r          load_leg_r
        WHERE
            load_leg_r.ld_leg_id = load_leg_detail_r.ld_leg_id
            AND ( load_leg_r.crtd_dtt >= add_months(trunc(SYSDATE, 'mm'), - 2) )
            AND ( load_leg_r.last_ctry_cd IN (
                'USA',
                'CAN',
                'MEX'
            ) )
            AND ( substr(load_leg_r.frst_shpg_loc_cd, 1, 1) <> 'R' )
            AND ( substr(load_leg_r.last_shpg_loc_cd, 1, 1) <> 'R' )
        GROUP BY
            load_leg_r.ld_leg_id
    )
GROUP BY
    load_number,
    shpm_num,
    load_leg_cnt
ORDER BY
    load_number);

DISCONNECT FROM ORACLE;

QUIT;

RUN;

*************************************************************************************************************************;
** PULL LIGHTS OUT PLANNED STATUS DETAILS                                                                              **;
*************************************************************************************************************************;

ODS HTML CLOSE;
ODS HTML;
dm 'clear log';
dm 'clear output';

%let id  = 'NAI2PADM';
%let pwd = 'NAI2PADM';

PROC SQL;
      connect to oracle (path='NAJDAPRD' user=&id password=&pwd);
      create table LD_PLND as select * from connection to oracle

(SELECT DISTINCT
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
            TO_CHAR(abpp_otc_autmttrans_srvcs.mnt_tmestmp, 'yyyymmdd') AS plnd_mnt_dtt,
            abpp_otc_autmttrans_srvcs.doc_typ       AS plnd_doc_type,
            TO_CHAR(abpp_otc_autmttrans_srvcs.doc_numb) AS load_number,
            abpp_otc_autmttrans_srvcs.operation     AS plnd_operation,
            abpp_otc_autmttrans_srvcs.status        AS plnd_status,
            abpp_otc_autmttrans_srvcs.status_desc   AS plnd_status_desc,
            TO_CHAR(abpp_otc_autmttrans_srvcs.status_dt, 'yyyymmdd') AS plnd_status_date,
            abpp_otc_autmttrans_srvcs.status_time   AS plnd_status_time,
            abpp_otc_autmttrans_srvcs.mnt_tmestmp   AS plnd_mnt_tmestmp,
            abpp_otc_autmttrans_srvcs.usr_id        AS plnd_user_id,
            abpp_otc_autmttrans_srvcs.procssd_cnt   AS plnd_procssd_cnt
        FROM
            nai2padm.abpp_otc_autmttrans_srvcs   abpp_otc_autmttrans_srvcs
            JOIN nai2padm.load_leg_r                  load_leg_r ON load_leg_r.ld_leg_id = abpp_otc_autmttrans_srvcs.doc_numb
        WHERE
            ( abpp_otc_autmttrans_srvcs.operation = 'STLP' )
            AND ( load_leg_r.crtd_dtt >= add_months(trunc(SYSDATE, 'mm'), - 2) )
            AND ( load_leg_r.crtd_dtt <= trunc(SYSDATE, 'DDD') )
            AND ( load_leg_r.frst_ctry_cd IN (
                'USA',
                'CAN',
                'MEX'
            ) )
            AND ( substr(load_leg_r.frst_shpg_loc_cd, 1, 1) <> 'R' )
            AND ( substr(load_leg_r.last_shpg_loc_cd, 1, 1) <> 'R' )
        UNION ALL
        SELECT DISTINCT
            TO_CHAR(abpp_otc_autmttrans_srvcs.mnt_tmestmp, 'yyyymmdd') AS plnd_mnt_dtt,
            abpp_otc_autmttrans_srvcs.doc_typ       AS plnd_doc_type,
            TO_CHAR(abpp_otc_autmttrans_srvcs.doc_numb) AS load_number,
            abpp_otc_autmttrans_srvcs.operation     AS plnd_operation,
            abpp_otc_autmttrans_srvcs.status        AS plnd_status,
            abpp_otc_autmttrans_srvcs.status_desc   AS plnd_status_desc,
            TO_CHAR(abpp_otc_autmttrans_srvcs.status_dt, 'yyyymmdd') AS plnd_status_date,
            abpp_otc_autmttrans_srvcs.status_time   AS plnd_status_time,
            abpp_otc_autmttrans_srvcs.mnt_tmestmp   AS plnd_mnt_tmestmp,
            abpp_otc_autmttrans_srvcs.usr_id        AS plnd_user_id,
            abpp_otc_autmttrans_srvcs.procssd_cnt   AS plnd_procssd_cnt
        FROM
            nai2padm.abpp_otc_autmttrans_srvcs   abpp_otc_autmttrans_srvcs
            JOIN nai2padm.load_leg_r                  load_leg_r ON load_leg_r.ld_leg_id = abpp_otc_autmttrans_srvcs.doc_numb
        WHERE
            ( abpp_otc_autmttrans_srvcs.operation = 'STLP' )
            AND ( load_leg_r.crtd_dtt >= add_months(trunc(SYSDATE, 'mm'), - 2) )
            AND ( load_leg_r.crtd_dtt <= trunc(SYSDATE, 'DDD') )
            AND ( load_leg_r.last_ctry_cd IN (
                'USA',
                'CAN',
                'MEX'
            ) )
            AND ( substr(load_leg_r.frst_shpg_loc_cd, 1, 1) <> 'R' )
            AND ( substr(load_leg_r.last_shpg_loc_cd, 1, 1) <> 'R' )
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
    load_number);

DISCONNECT FROM ORACLE;

QUIT;

RUN;

*************************************************************************************************************************;
** PULL LOAD MANUALLY SET TO PLANNED DETAILS                                                                           **;
*************************************************************************************************************************;
ODS HTML CLOSE;
ODS HTML;
dm 'clear log';
dm 'clear output';

%let id  = 'TMDW';
%let pwd = 'F2KYlqUWIfTwW7zI';


PROC SQL;
      connect to oracle (path='NAJDABAP' user=&id password=&pwd);
      create table MAN_PLAN as select * from connection to oracle

(SELECT distinct 
	IA_DIST_LOADS.LOAD_ID AS Load_Number, 
	Count(distinct IA_DIST_LOADS.EVENT_LOG_DT) AS Man_Plan_Cnt

FROM 
	IA_DIST_LOADS IA_DIST_LOADS, 
	IA_EVNT_TYPE IA_EVNT_TYPE, 
	IA_EXCEPTION_CODE IA_EXCEPTION_CODE, 
	IA_USERS IA_USERS

WHERE 
	IA_DIST_LOADS.EVNT_TYPE_KEY = IA_EVNT_TYPE.EVNT_TYPE_KEY AND
	IA_DIST_LOADS.EXCPT_CODE_KEY = IA_EXCEPTION_CODE.EXCPT_CODE_KEY AND
	IA_DIST_LOADS.EVNT_USER_KEY = IA_USERS.USER_KEY AND
	((IA_DIST_LOADS.EVENT_LOG_DT>=add_months(trunc(SYSDATE, 'mm'), - 2)) AND 
	(IA_EXCEPTION_CODE.EXCEPTION_CODE='PLND') AND 
	(substr(USER_LOGIN,1,1) Not In ('*','9')))

GROUP BY
IA_DIST_LOADS.LOAD_ID

ORDER BY 
IA_DIST_LOADS.LOAD_ID

);

DISCONNECT FROM ORACLE;

QUIT;

RUN;

*************************************************************************************************************************;
** PULL LIGHTS OUT LOAD TENDERED DETAILS                                                                               **;
*************************************************************************************************************************;

ODS HTML CLOSE;
ODS HTML;
dm 'clear log';
dm 'clear output';

%let id  = 'NAI2PADM';
%let pwd = 'NAI2PADM';


PROC SQL;
      connect to oracle (path='NAJDAPRD' user=&id password=&pwd);
      create table LD_TNDRD as select * from connection to oracle

(SELECT DISTINCT
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
            TO_CHAR(abpp_otc_autmttrans_srvcs.mnt_tmestmp, 'yyyymmdd') AS tdr_time,
            abpp_otc_autmttrans_srvcs.doc_typ       AS tdr_doc_type,
            TO_CHAR(abpp_otc_autmttrans_srvcs.doc_numb) AS load_number,
            abpp_otc_autmttrans_srvcs.operation     AS tdr_operation,
            abpp_otc_autmttrans_srvcs.status        AS tdr_status,
            abpp_otc_autmttrans_srvcs.status_desc   AS tdr_status_desc,
            TO_CHAR(abpp_otc_autmttrans_srvcs.status_dt, 'yyyymmdd') AS tdr_status_dtt,
            abpp_otc_autmttrans_srvcs.status_time   AS tdr_status_time,
            abpp_otc_autmttrans_srvcs.mnt_tmestmp   AS tdr_mnt_tmestmp,
            abpp_otc_autmttrans_srvcs.usr_id        AS tdr_usr_id,
            abpp_otc_autmttrans_srvcs.procssd_cnt   AS tdr_procssd_cnt
        FROM
            nai2padm.abpp_otc_autmttrans_srvcs   abpp_otc_autmttrans_srvcs
            JOIN nai2padm.load_leg_r                  load_leg_r ON load_leg_r.ld_leg_id = abpp_otc_autmttrans_srvcs.doc_numb
        WHERE
            ( abpp_otc_autmttrans_srvcs.operation = 'STLT' )
            AND ( load_leg_r.crtd_dtt >= add_months(trunc(SYSDATE, 'mm'), - 2) )
            AND ( load_leg_r.crtd_dtt <= trunc(SYSDATE, 'DDD') )
            AND ( load_leg_r.frst_ctry_cd IN (
                'USA',
                'CAN',
                'MEX'
            ) )
            AND ( substr(load_leg_r.frst_shpg_loc_cd, 1, 1) <> 'R' )
            AND ( substr(load_leg_r.last_shpg_loc_cd, 1, 1) <> 'R' )
        UNION ALL
        SELECT DISTINCT
            TO_CHAR(abpp_otc_autmttrans_srvcs.mnt_tmestmp, 'yyyymmdd') AS tdr_time,
            abpp_otc_autmttrans_srvcs.doc_typ       AS tdr_doc_type,
            TO_CHAR(abpp_otc_autmttrans_srvcs.doc_numb) AS load_number,
            abpp_otc_autmttrans_srvcs.operation     AS tdr_operation,
            abpp_otc_autmttrans_srvcs.status        AS tdr_status,
            abpp_otc_autmttrans_srvcs.status_desc   AS tdr_status_desc,
            TO_CHAR(abpp_otc_autmttrans_srvcs.status_dt, 'yyyymmdd') AS tdr_status_dtt,
            abpp_otc_autmttrans_srvcs.status_time   AS tdr_status_time,
            abpp_otc_autmttrans_srvcs.mnt_tmestmp   AS tdr_mnt_tmestmp,
            abpp_otc_autmttrans_srvcs.usr_id        AS tdr_usr_id,
            abpp_otc_autmttrans_srvcs.procssd_cnt   AS tdr_procssd_cnt
        FROM
            nai2padm.abpp_otc_autmttrans_srvcs   abpp_otc_autmttrans_srvcs
            JOIN nai2padm.load_leg_r                  load_leg_r ON load_leg_r.ld_leg_id = abpp_otc_autmttrans_srvcs.doc_numb
        WHERE
            ( abpp_otc_autmttrans_srvcs.operation = 'STLT' )
            AND ( load_leg_r.crtd_dtt >= add_months(trunc(SYSDATE, 'mm'), - 2) )
            AND ( load_leg_r.crtd_dtt <= trunc(SYSDATE, 'DDD') )
            AND ( load_leg_r.last_ctry_cd IN (
                'USA',
                'CAN',
                'MEX'
            ) )
            AND ( substr(load_leg_r.frst_shpg_loc_cd, 1, 1) <> 'R' )
            AND ( substr(load_leg_r.last_shpg_loc_cd, 1, 1) <> 'R' )
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
    tdr_mnt_tmestmp);

DISCONNECT FROM ORACLE;

QUIT;

RUN;

*************************************************************************************************************************;
** PULL MANUALLY TENDERED LOAD DETAILS                                                                                 **;
*************************************************************************************************************************;

ODS HTML CLOSE;
ODS HTML;
dm 'clear log';
dm 'clear output';

%let id  = 'TMDW';
%let pwd = 'F2KYlqUWIfTwW7zI';


PROC SQL;
      connect to oracle (path='NAJDABAP' user=&id password=&pwd);
      create table MAN_TDRD as select * from connection to oracle

(SELECT DISTINCT 
	IA_DIST_LOADS.LOAD_ID AS Load_Number,
	Count(DISTINCT IA_DIST_LOADS.EVENT_LOG_DT) AS Man_Tdr_Cnt

FROM 
	IA_DIST_LOADS IA_DIST_LOADS,
	IA_EVNT_TYPE IA_EVNT_TYPE,
	IA_EXCEPTION_CODE IA_EXCEPTION_CODE,
	IA_USERS IA_USERS

WHERE 
	IA_DIST_LOADS.EVNT_TYPE_KEY = IA_EVNT_TYPE.EVNT_TYPE_KEY AND
	IA_DIST_LOADS.EXCPT_CODE_KEY = IA_EXCEPTION_CODE.EXCPT_CODE_KEY AND
	IA_DIST_LOADS.EVNT_USER_KEY = IA_USERS.USER_KEY AND
	((IA_DIST_LOADS.EVENT_LOG_DT>=add_months(trunc(SYSDATE, 'mm'), - 2)) AND
	(IA_EVNT_TYPE.EVNT_TYPE_CODE IN('TENDFRST','TENDOTHER')) AND
	(IA_EXCEPTION_CODE.EXCEPTION_CODE='TNRD') AND
	(substr(USER_LOGIN,1,1) Not In ('*','9')))

GROUP BY
	IA_DIST_LOADS.LOAD_ID

ORDER BY 
	IA_DIST_LOADS.LOAD_ID

);

DISCONNECT FROM ORACLE;

QUIT;

RUN;

*************************************************************************************************************************;
** PULL SHIPMENT TYPE DETAILS                                                                                            **;
*************************************************************************************************************************;

/*ODS HTML CLOSE;
ODS HTML;
dm 'clear log';
dm 'clear output';

%let id  = 'NAI2PADM';
%let pwd = 'nai2padm';

PROC SQL;
      connect to oracle (path='NAJDAPRD' user=&id password=&pwd);
      create table SHIP_TYPE as select * from connection to oracle

(SELECT DISTINCT
	LOAD_LEG_R.LD_LEG_ID as LD_LEG_ID,
	LOAD_LEG_R.FRST_SHPG_LOC_CD as ORIG_ID,
	LOAD_LEG_R.LAST_SHPG_LOC_CD as DEST_ID

FROM
	LOAD_LEG_R LOAD_LEG_R

WHERE
	(LOAD_LEG_R.SHPD_DTT>=sysdate-2 AND
	(LOAD_LEG_R.FRST_CTRY_CD In ('USA’,’CAN’,’MEX')) AND
	(LOAD_LEG_R.LAST_CTRY_CD In ('USA’,’CAN’,’MEX')) AND
	(substr(LOAD_LEG_R.FRST_SHPG_LOC_CD,1,1)<>'R') AND
	(substr(LOAD_LEG_R.LAST_SHPG_LOC_CD,1,1)<>'R')

ORDER BY
	LOAD_LEG_R.LD_LEG_ID

);

DISCONNECT FROM ORACLE;

QUIT;

RUN;*/


*************************************************************************************************************************;
** PULL OPTIMIZATION DETAILS                                                                                            **;
*************************************************************************************************************************;

ODS HTML;
dm 'clear log';
dm 'clear output';

%let id  = 'NAI2PADM';
%let pwd = 'nai2padm';

PROC SQL;
      connect to oracle (path='NAJDAPRD' user=&id password=&pwd);
      create table OPT_DETAILS as select * from connection to oracle

(SELECT
	OPMR_QUE_T.QUE_DTT as OPT_QUE_DATE,
	OPMR_QUE_T.QUE_ID as OPT_QUE_ID,
	OPMR_QUE_T.PLAN_ID as OPT_PLAN_ID,
	OPMR_QUE_T.STRT_DTT as OPT_START_DATE,
	OPMR_QUE_T.CPLD_DTT as OPT_CMPL_DATE,
	OPMR_QUE_T.NUM_SHPMLEG as NUM_SHIPLEGS,
	OPMR_QUE_T.USR_CD as USER_ID

FROM
	OPMR_QUE_T OPMR_QUE_T

WHERE
	(OPMR_QUE_T.QUE_DTT>=sysdate-100)

ORDER BY
	OPMR_QUE_T.QUE_ID

);

DISCONNECT FROM ORACLE;

QUIT;

RUN;


*************************************************************************************************************************;
** GET BUSINESS UNIT FOR EACH LOAD FROM ABPP_LD_RFRC_T                                                                                                                             **;
*************************************************************************************************************************;

ODS HTML CLOSE;
ODS HTML;
dm 'clear log';
dm 'clear output';

%let id  = 'NAI2PADM';
%let pwd = 'nai2padm';

PROC SQL;
      connect to oracle (path='NAJDAPRD' user=&id password=&pwd);
      create table Bus_In as select * from connection to oracle

(SELECT DISTINCT
    ld_num,
    bus_unit_id,
    bus_unit_wgt,
    business_unit
FROM
    (
        SELECT DISTINCT
            abpp_ld_rfrc_t.load_id            AS ld_num,
            CASE
                WHEN abpp_ld_rfrc_t.bsn_units IS NULL THEN
                    abpp_ld_rfrc_t.bsn_units
                ELSE
                    abpp_ld_rfrc_t.bsn_units
            END AS bus_unit_id,
            abpp_ld_rfrc_t.bsn_unit_by_wgt    AS bus_unit_wgt,
            abpp_ld_rfrc_t.unit_desc_by_wgt   AS business_unit
        FROM
            najdatrn.abpp_ld_rfrc_t   abpp_ld_rfrc_t,
            najdaadm.load_leg_r       load_leg_r
        WHERE
            abpp_ld_rfrc_t.load_id = load_leg_r.ld_leg_id
            AND ( load_leg_r.crtd_dtt >= trunc(trunc(SYSDATE, 'MM') - 2, 'MM') )
            AND
	/*(LOAD_LEG_R.EQMT_TYP In ('48FT','48TC','53FT','53TC','53HC','53IM','LTL','53RT')) AND  */ ( load_leg_r.frst_ctry_cd IN (
                'USA',
                'CAN',
                'MEX'
            ) )
        UNION ALL
        SELECT DISTINCT
            abpp_ld_rfrc_t.load_id            AS ld_num,
            CASE
                WHEN abpp_ld_rfrc_t.bsn_units IS NULL THEN
                    abpp_ld_rfrc_t.bsn_units
                ELSE
                    abpp_ld_rfrc_t.bsn_units
            END AS bus_unit_id,
            abpp_ld_rfrc_t.bsn_unit_by_wgt    AS bus_unit_wgt,
            abpp_ld_rfrc_t.unit_desc_by_wgt   AS business_unit
        FROM
            najdatrn.abpp_ld_rfrc_t   abpp_ld_rfrc_t,
            najdaadm.load_leg_r       load_leg_r
        WHERE
            abpp_ld_rfrc_t.load_id = load_leg_r.ld_leg_id
            AND ( load_leg_r.crtd_dtt >= trunc(trunc(SYSDATE, 'MM') - 2, 'MM') )
            AND
	/*(LOAD_LEG_R.EQMT_TYP In ('48FT','48TC','53FT','53TC','53HC','53IM','LTL','53RT')) AND  */ ( load_leg_r.last_ctry_cd IN (
                'USA',
                'CAN',
                'MEX'
            ) )
    )
GROUP BY
    ld_num,
    bus_unit_id,
    bus_unit_wgt,
    business_unit
ORDER BY
    ld_num);

DISCONNECT FROM ORACLE;

QUIT; 

RUN; 



/*         ASSIGN BUSINESS WHEN MISSING       */

PROC SORT DATA = BUS_IN;
	BY LD_NUM;
RUN;

DATA BUS;
	SET BUS_IN;
		BY LD_NUM;
	IF BUSINESS_UNIT = '' THEN DO;
		IF BUS_UNIT_ID = '2810' THEN BUSINESS_UNIT = 'CONSUMER';
		IF BUS_UNIT_ID = '2811' THEN BUSINESS_UNIT = 'KCP';
		IF BUS_UNIT_ID = '2820' THEN BUSINESS_UNIT = 'CONSUMER';
		IF BUS_UNIT_ID = '2821' THEN BUSINESS_UNIT = 'KCP';
		IF BUS_UNIT_ID = 'Z01' THEN BUSINESS_UNIT = 'CONSUMER';
		IF BUS_UNIT_ID = 'Z02' THEN BUSINESS_UNIT = 'KCP';
		IF BUS_UNIT_ID = 'Z04' THEN BUSINESS_UNIT = 'KCP';
		IF BUS_UNIT_ID = 'Z05' THEN BUSINESS_UNIT = 'NON WOVENS';
		IF BUS_UNIT_ID = 'Z06' THEN BUSINESS_UNIT = 'KCP';
		IF BUS_UNIT_ID = 'Z07' THEN BUSINESS_UNIT = 'KCP';		
	END;
	BUSINESS_UNIT = UPCASE(BUSINESS_UNIT);
	DROP BUS_UNIT_ID BUS_UNIT_WGT;
	IF FIRST.LD_NUM THEN OUTPUT BUS;
RUN;


DATA BUSINESS; SET BUS;
	LOAD_NUMBER = PUT(LD_NUM, BEST9.);
RUN;

PROC SORT DATA = BUSINESS;
	BY LOAD_NUMBER;
RUN;


*************************************************************************************************************************;
** PULL SHIPPED LOADS DETAILS                                                                                            **;
*************************************************************************************************************************;

ODS HTML CLOSE;
ODS HTML;
dm 'clear log';
dm 'clear output';

%let id  = 'NAI2PADM';
%let pwd = 'nai2padm';

PROC SQL;
      connect to oracle (path='NAJDAPRD' user=&id password=&pwd);
      create table LOADS_IN as select * from connection to oracle

(SELECT DISTINCT
    CASE
        WHEN ( orig_country NOT IN (
            'USA',
            'CAN',
            'MEX'
        ) )
             AND ( dest_country IN (
            'USA',
            'CAN',
            'MEX'
        ) ) THEN
            'IMPORT'
        WHEN ( orig_country IN (
            'USA',
            'CAN',
            'MEX'
        ) )
             AND ( dest_country NOT IN (
            'USA',
            'CAN',
            'MEX'
        ) ) THEN
            'EXPORT'
        ELSE
            'DOMESTIC'
    END AS importexport,
	    CASE
        WHEN ( orig_country IN (
            'USA',
            'CAN',
            'MEX'
        ) )
             AND ( dest_country IN (
            'USA',
            'CAN',
            'MEX'
        ) ) THEN
            'DOMESTIC'
        ELSE
            'INTERNATIONAL'
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
    shpm_num,
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
    TO_CHAR(load_leg_r.shpd_dtt, 'yyyymmdd') AS ymd_ship_dte,
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
    nai2padm.load_leg_r              load_leg_r
    LEFT JOIN nai2padm.load_leg_detail_r       load_leg_detail_r ON load_leg_r.ld_leg_id = load_leg_detail_r.ld_leg_id
    LEFT JOIN najdaadm.load_at_r               load_at_r ON load_at_r.shpg_loc_cd = load_leg_r.frst_shpg_loc_cd
    LEFT JOIN najdaadm.status_r                status_r ON load_leg_r.cur_optlstat_id = status_r.stat_id
    LEFT JOIN nai2padm.abpp_otc_caps_analyst   abpp_otc_caps_analyst ON load_leg_r.frst_shpg_loc_cd = abpp_otc_caps_analyst.location_id
                                                                      AND load_leg_r.shpd_dtt >= abpp_otc_caps_analyst.from_date
                                                                      AND load_leg_r.shpd_dtt < ( abpp_otc_caps_analyst.TO_DATE +
                                                                      1 )
WHERE
    ( ( load_leg_r.crtd_dtt >= add_months(trunc(SYSDATE, 'mm'), - 2) )
      AND ( load_leg_r.frst_ctry_cd IN (
        'USA',
        'CAN',
        'MEX'
    ) or load_leg_r.frst_ctry_cd is null)
      AND (( substr(frst_shpg_loc_cd, 1, 1) <> 'R' ) or frst_shpg_loc_cd is null)
      AND (( substr(last_shpg_loc_cd, 1, 1) <> 'R' ) or last_shpg_loc_cd is null))
	  AND (load_leg_r.CUR_OPTLSTAT_ID between 300 and 400)
        UNION ALL
        
        SELECT DISTINCT
    load_leg_r.shpd_dtt                      AS shpd_dtt,
    TO_CHAR(load_leg_r.shpd_dtt, 'yyyymmdd') AS ymd_ship_dte,
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
    nai2padm.load_leg_r              load_leg_r
    LEFT JOIN nai2padm.load_leg_detail_r       load_leg_detail_r ON load_leg_r.ld_leg_id = load_leg_detail_r.ld_leg_id
    LEFT JOIN najdaadm.load_at_r               load_at_r ON load_at_r.shpg_loc_cd = load_leg_r.frst_shpg_loc_cd
    LEFT JOIN najdaadm.status_r                status_r ON load_leg_r.cur_optlstat_id = status_r.stat_id
    LEFT JOIN nai2padm.abpp_otc_caps_analyst   abpp_otc_caps_analyst ON load_leg_r.frst_shpg_loc_cd = abpp_otc_caps_analyst.location_id
                                                                      AND load_leg_r.shpd_dtt >= abpp_otc_caps_analyst.from_date
                                                                      AND load_leg_r.shpd_dtt < ( abpp_otc_caps_analyst.TO_DATE +
                                                                      1 )
WHERE
    ( ( load_leg_r.crtd_dtt >= add_months(trunc(SYSDATE, 'mm'), - 2) )
      AND ( load_leg_r.last_ctry_cd IN (
        'USA',
        'CAN',
        'MEX'
    )  or load_leg_r.frst_ctry_cd is null)
      AND (( substr(frst_shpg_loc_cd, 1, 1) <> 'R' ) or frst_shpg_loc_cd is null)
      AND (( substr(last_shpg_loc_cd, 1, 1) <> 'R' ) or last_shpg_loc_cd is null))
	  AND (load_leg_r.CUR_OPTLSTAT_ID between 300 and 400)
    )  
    
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
    shpm_num,
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
    stop_num);

DISCONNECT FROM ORACLE;

QUIT;

RUN;

*************************************************************************************************************************;
** PULL SHIPMENT TYPE DETAIL FOR LOAD SHIPPED TABLE                                                                    **;
*************************************************************************************************************************;
DATA LOADS;

	SET LOADS_IN;

	BY LOAD_NUMBER;

	LENGTH SHIPMENT_TYPE $10;

	IF SUBSTR(DEST_ID,1,2)='58' THEN SHIPMENT_TYPE = 'CUSTOMER';
	ELSE
	IF SUBSTR(DEST_ID,1,2) = '99' THEN SHIPMENT_TYPE = 'CUSTOMER';
	ELSE
	IF CORP_ID = 'RM' THEN SHIPMENT_TYPE = 'RM-INBOUND';
	ELSE
	IF CORP_ID = 'RF' THEN SHIPMENT_TYPE = 'RF-INBOUND';
	ELSE
	IF SUBSTR(ORIG_NAME,1,2) = 'RM' THEN SHIPMENT_TYPE = 'RM-INBOUND';
	ELSE
	IF SUBSTR(ORIG_NAME,1,2) = 'RF' THEN SHIPMENT_TYPE = 'RF-INBOUND';
	ELSE
	IF SUBSTR (ORIGIN_ID,1,1) = 'V' THEN SHIPMENT_TYPE = 'INBOUND';
	ELSE SHIPMENT_TYPE = 'INTERMILL';

RUN;


*************************************************************************************************************************;
** MERGE LOAD SHIPPED TABLE WITH BUSINESS UNIT TABLE                                                                   **;
*************************************************************************************************************************;

PROC SORT DATA = BUSINESS;
	BY Load_Number;
RUN;


PROC SORT DATA = LOADS;
	BY Load_Number;
RUN;

DATA LD_SHPD;
	MERGE LOADS (IN=A) BUSINESS;
		BY Load_Number;
		IF A;
RUN;


*************************************************************************************************************************;
** MERGE LOAD SHIPPED TABLE WITH MANUAL TENDER TABLE                                                                   **;
*************************************************************************************************************************;

PROC SORT DATA = MAN_TDRD;
	BY Load_Number;
RUN;


PROC SORT DATA = LD_SHPD;
	BY Load_Number;
RUN;

DATA LOAD_DETAIL_MAN_TDRD;
	MERGE LD_SHPD (IN=A) MAN_TDRD;
		BY Load_Number;
		IF A;
RUN;


*************************************************************************************************************************;
** MERGE LOAD SHIPPED TABLE WITH TENDER ACCEPT TABLE                                                                   **;
*************************************************************************************************************************;

PROC SORT DATA = TNDR_ACCEPT;
	BY Load_Number;
RUN;


PROC SORT DATA = LOAD_DETAIL_MAN_TDRD;
	BY Load_Number;
RUN;


DATA LOAD_DETAIL_MAN_TNDR_ACCPT;
	MERGE LOAD_DETAIL_MAN_TDRD (IN=A) TNDR_ACCEPT;
		BY Load_Number;
		IF A;
		IF LD_SOURCE = 'Optimization'
		THEN MANUAL_BUILT= 'N';
		ELSE DO;
		MANUAL_BUILT = 'Y';
		END;
RUN;


*************************************************************************************************************************;
** MERGE LOAD SHIPPED TABLE WITH TENDER CANCEL TABLE                                                                   **;
*************************************************************************************************************************;

PROC SORT DATA = TNDR_CNCL;
	BY Load_Number;
RUN;


PROC SORT DATA = LOAD_DETAIL_MAN_TNDR_ACCPT;
	BY Load_Number;
RUN;


DATA LOAD_DETAIL_TNDR_ACCPT_CNCL;
	MERGE LOAD_DETAIL_MAN_TNDR_ACCPT (IN=A) TNDR_CNCL;
		BY Load_Number;
		IF A;
RUN;

*************************************************************************************************************************;
** MERGE LOAD SHIPPED TABLE WITH TENDER REJECT TABLE                                                                   **;
*************************************************************************************************************************;

PROC SORT DATA = TNDR_REJ;
	BY Load_Number;
RUN;


PROC SORT DATA = LOAD_DETAIL_TNDR_ACCPT_CNCL;
	BY Load_Number;
RUN;


DATA LOAD_DETAIL_TNDR_ACCPT_CNCL_REJ;
	MERGE LOAD_DETAIL_TNDR_ACCPT_CNCL (IN=A) TNDR_REJ;
		BY Load_Number;
		IF A;
RUN;

*************************************************************************************************************************;
** MERGE LOAD SHIPPED/TENDER TABLE WITH CONFIRMATION REVERSE TABLE                                                     **;
*************************************************************************************************************************;

PROC SORT DATA = CNFRM_REV;
	BY Load_Number;
RUN;


PROC SORT DATA = LOAD_DETAIL_TNDR_ACCPT_CNCL_REJ;
	BY Load_Number;
RUN;


DATA LOAD_DETAIL_TNDR_CNFRM_REV;
	MERGE LOAD_DETAIL_TNDR_ACCPT_CNCL_REJ (IN=A) CNFRM_REV;
		BY Load_Number;
		IF A;
RUN;

*************************************************************************************************************************;
** MERGE LOAD SHIPPED/TENDER/CONF REV TABLE WITH UNSUSPEND TABLE                                                       **;
*************************************************************************************************************************;

PROC SORT DATA = UNSUSPEND;
	BY Load_Number;
RUN;


PROC SORT DATA = LOAD_DETAIL_TNDR_CNFRM_REV;
	BY Load_Number;
RUN;


DATA LOAD_DTL_TDR_CFM_REV_UNSPND;
	MERGE LOAD_DETAIL_TNDR_CNFRM_REV (IN=A) UNSUSPEND;
		BY Load_Number;
		IF A;
RUN;

*************************************************************************************************************************;
** MERGE LOAD SHIPPED/TENDER/CONF REV/UNSUSPEND TABLE WITH DOCK DELETE TABLE                                           **;
*************************************************************************************************************************;

PROC SORT DATA = DOCK_DEL;
	BY Load_Number;
RUN;


PROC SORT DATA = LOAD_DTL_TDR_CFM_REV_UNSPND;
	BY Load_Number;
RUN;


DATA LOAD_DTL_DOCK_DEL;
	MERGE LOAD_DTL_TDR_CFM_REV_UNSPND (IN=A) DOCK_DEL;
		BY Load_Number;
		IF A;
RUN;

*************************************************************************************************************************;
** MERGE LOAD SHIPPED/TENDER/CONF REV/UNSUSPEND/DOCK DELETE TABLE WITH DOCK CREATE TABLE                               **;
*************************************************************************************************************************;

PROC SORT DATA = DOCK_CRT;
	BY Load_Number;
RUN;


PROC SORT DATA = LOAD_DTL_DOCK_DEL;
	BY Load_Number;
RUN;


DATA LOAD_DTL_DOCK_DEL_CRT;
	MERGE LOAD_DTL_DOCK_DEL (IN=A) DOCK_CRT;
		BY Load_Number;
		IF A;
RUN;

*************************************************************************************************************************;
** MERGE LOAD SHIPPED/TENDER/CONF REV/UNSUSPEND/DOCK DELETE/CREATE TABLE WITH DOCK CHANGE TABLE                        **;
*************************************************************************************************************************;

PROC SORT DATA = DOCK_CHG;
	BY Load_Number;
RUN;


PROC SORT DATA = LOAD_DTL_DOCK_DEL_CRT;
	BY Load_Number;
RUN;


DATA LOAD_DTL_DOCK_DTL;
	MERGE LOAD_DTL_DOCK_DEL_CRT (IN=A) DOCK_CHG;
		BY Load_Number;
		IF A;
RUN;

*************************************************************************************************************************;
** MERGE LOAD SHIPPED/TENDER/CONF REV/UNSUSPEND/DOCK DETAIL TABLE WITH APPT DELETE TABLE                               **;
*************************************************************************************************************************;

PROC SORT DATA = APPT_DEL;
	BY Load_Number;
RUN;


PROC SORT DATA = LOAD_DTL_DOCK_DTL;
	BY Load_Number;
RUN;


DATA LOAD_DTL_DOCK_DTL_APPT_DEL;
	MERGE LOAD_DTL_DOCK_DTL (IN=A) APPT_DEL;
		BY Load_Number;
		IF A;
RUN;

*************************************************************************************************************************;
** MERGE LOAD SHIPPED/TENDER/CONF REV/UNSUSPEND/DOCK DETAIL/APPT DELETE TABLE WITH CONFIRM_PICK_APPT TABLE             **;
*************************************************************************************************************************;

PROC SORT DATA = CONFIRM_PICK_APPT;
	BY Load_Number;
RUN;


PROC SORT DATA = LOAD_DTL_DOCK_DTL;
	BY Load_Number;
RUN;


DATA LOAD_DTL_DOCK_DTL_PICK_APPT;
	MERGE LOAD_DTL_DOCK_DTL_APPT_DEL (IN=A) CONFIRM_PICK_APPT;
		BY Load_Number;
		IF A;
RUN;

*************************************************************************************************************************;
** MERGE LOAD SHIPPED/TENDER/CONF REV/UNSUSPEND/DOCK DETAIL/APPT CONF PICK DETAIL TABLE WITH SUGGESTED APPT TABLE      **;
*************************************************************************************************************************;

PROC SORT DATA = SUG_APPT;
	BY Load_Number;
RUN;


PROC SORT DATA = LOAD_DTL_DOCK_DTL_PICK_APPT;
	BY Load_Number;
RUN;


DATA LOAD_DTL_DOCK_DTL_APPT_DTL;
	MERGE LOAD_DTL_DOCK_DTL_PICK_APPT (IN=A) SUG_APPT;
		BY Load_Number;
		IF A;
RUN;


*************************************************************************************************************************;
** MERGE LOAD SHIPPED/TENDER/CONF REV/UNSUSPEND/DOCK/APPT DETAIL TABLE WITH PLANNED LOAD TABLE                         **;
*************************************************************************************************************************;

PROC SORT DATA = LD_PLND;
	BY Load_Number;
RUN;


PROC SORT DATA = LOAD_DTL_DOCK_DTL_APPT_DTL;
	BY Load_Number;
RUN;


DATA LOAD_DTL_DOCK_DTL_APPT_DTL_PLND;
	MERGE LOAD_DTL_DOCK_DTL_APPT_DTL (IN=A) LD_PLND;
		BY Load_Number;
		IF A;
RUN;


*************************************************************************************************************************;
** MERGE LOAD SHIPPED/TENDER/CONF REV/UNSUSPEND/DOCK/APPT/PLANNED DETAIL TABLE WITH TENDERED TABLE                     **;
*************************************************************************************************************************;

PROC SORT DATA = LD_TNDRD;
	BY Load_Number;
RUN;


PROC SORT DATA = LOAD_DTL_DOCK_DTL_APPT_DTL_PLND;
	BY Load_Number;
RUN;


DATA LD_DTL_DOCK_DTL_APPT_DTL_PLD_TDR;
	MERGE LOAD_DTL_DOCK_DTL_APPT_DTL_PLND (IN=A) LD_TNDRD;
		BY Load_Number;
		IF A;
RUN;

*************************************************************************************************************************;
** MERGE LOAD SHIPPED/TENDER/CONF REV/UNSUSPEND/DOCK/APPT/PLANNED DETAIL TABLE WITH MANUALLY SET TO PLANNED TABLE      **;
*************************************************************************************************************************;

PROC SORT DATA = MAN_PLAN;
	BY Load_Number;
RUN;


PROC SORT DATA = LD_DTL_DOCK_DTL_APPT_DTL_PLD_TDR;
	BY Load_Number;
RUN;


DATA FINAL_RFT_DETAILS;
	MERGE LD_DTL_DOCK_DTL_APPT_DTL_PLD_TDR (IN=A) MAN_PLAN;
		BY Load_Number;
		IF A;
*	IF PLND_STATUS ^= 'SUCC' THEN DO;
*		MAN_PLN=1;
*		END;
*		ELSE DO;

		if substr(PLND_USER_ID,1,1) Not In ('*','9') THEN DO;
		MAN_PLN=1;
*		MAN_PLN=MAN_PLAN_CNT;
		END;
RUN;


*************************************************************************************************************************;
** SUM MANUAL TOUCH OCCURRENCES TO DETERMINE MANUAL TOUCH FREQUENCY                                                     **;
*************************************************************************************************************************;

DATA FNL_RFT_DTL;
	SET FINAL_RFT_DETAILS;
	TOTAL=SUM(of ACCEPT_CNT TENDER_REJ_CNT TENDER_CNCL_CNT CONFIRM_REVERSAL_CNT LOAD_UNSUSPEND_CNT DOCK_DELETE_CNT DOCK_CREATE_CNT DOCK_CHANGE_CNT APPT_DELETE_CNT MAN_PLN MAN_TDR_CNT);
RUN;



DATA FINAL (KEEP=DATE_LAST_REFRESHED IMPORTEXPORT DOMESTICINT LOAD_NUMBER SHPM_NUM YMD_SHIP_DTE ORIGIN_ID ORIG_NAME ORIG_CITY ORIG_STATE ORIG_ZIP ORIG_COUNTRY STOP_NUM 
			DEST_ID DEST_NAME DEST_CITY DEST_STATE DEST_ZIP DEST_COUNTRY CARRIER SERVICE EQ_TYPE MILES NUM_STOP NUM_SHPM QUE_ID LD_SOURCE 
			PLAN_ID TEAM_NAME TEAM_LEADER_ID TEAM_LEADER_NAME ANALYST_ID ANALYST_NAME LD_CMPL_YN SHIPMENT_TYPE BUSINESS_UNIT ACCEPT_CNT MANUAL_BUILT TENDER_REJ_CNT TENDER_CNCL_CNT CONFIRM_REVERSAL_CNT
			LOAD_UNSUSPEND_CNT DOCK_DELETE_CNT DOCK_CREATE_CNT DOCK_CHANGE_CNT APPT_DELETE_CNT PLND_STATUS PLND_STATUS_DESC PLND_USER_ID
			PLND_PROCSSD_CNT MAN_PLAN_CNT MAN_PLN TDR_TIME TDR_STATUS TDR_STATUS_DESC TDR_STATUS_DTT TDR_USR_ID TDR_PROCSSD_CNT MAN_TDR_CNT TOTAL MAN_TOUCH CURRENTSTATUS CURRENTSTATUSDESC CREATEDATE); 
		
			RETAIN DATE_LAST_REFRESHED IMPORTEXPORT DOMESTICINT LOAD_NUMBER SHPM_NUM YMD_SHIP_DTE ORIGIN_ID ORIG_NAME ORIG_CITY ORIG_STATE ORIG_ZIP ORIG_COUNTRY STOP_NUM 
			DEST_ID DEST_NAME DEST_CITY DEST_STATE DEST_ZIP DEST_COUNTRY CARRIER SERVICE EQ_TYPE MILES NUM_STOP NUM_SHPM QUE_ID LD_SOURCE 
			PLAN_ID TEAM_NAME TEAM_LEADER_ID TEAM_LEADER_NAME ANALYST_ID ANALYST_NAME LD_CMPL_YN SHIPMENT_TYPE BUSINESS_UNIT ACCEPT_CNT MANUAL_BUILT TENDER_REJ_CNT TENDER_CNCL_CNT CONFIRM_REVERSAL_CNT
			LOAD_UNSUSPEND_CNT DOCK_DELETE_CNT DOCK_CREATE_CNT DOCK_CHANGE_CNT APPT_DELETE_CNT PLND_STATUS PLND_STATUS_DESC PLND_USER_ID
			PLND_PROCSSD_CNT MAN_PLAN_CNT MAN_PLN TDR_TIME TDR_STATUS TDR_STATUS_DESC TDR_STATUS_DTT TDR_USR_ID TDR_PROCSSD_CNT MAN_TDR_CNT TOTAL MAN_TOUCH CURRENTSTATUS CURRENTSTATUSDESC CREATEDATE; 
	
	SET FNL_RFT_DTL;

	BY Load_Number;

	IF MANUAL_BUILT='Y' OR TOTAL>0 THEN DO;
		MAN_TOUCH='Y';
	END;
		ELSE DO;
		MAN_TOUCH='N';
	END;
RUN;


**************************************************************************************************************************;
** EXPORT FINAL RFT DETAIL DATA TO EXCEL                                                                                **;
**************************************************************************************************************************;

proc export data=FINAL
    outfile="\\USTCA097\Stage\Database Files\RFT Detail Data\RFT Detail Data.xlsx"
    dbms=xlsx
    replace;
	Sheet="Detail";
run;

LIBNAME XLS EXCEL "\\USTCA097\Stage\Database Files\RFT Detail Data\RFT Detail Data.xlsx";

PROC DATASETS LIB = XLS NOLIST;
DELETE Detail;
QUIT;

DATA XLS.Detail;
SET FINAL;
RUN;

LIBNAME XLS CLEAR;
