/*DROP TABLE IF EXISTS ##tblAppointmentChangeTemp*/

SELECT data.LoadNumber,
data.StopNumber,
data.Eqmt_Typ,
CAST(data.shpd_dtt AS DATE) AS ShippedDate,
data.DestinationID,
cus.Hierarchy,
cus.CustomerGroup,
data.DestinationName,
data.DestinationCity,
data.DestinationState,
data.DestinationPostalCd,
data.OriginID,
data.OriginName,
data.OriginCity,
data.OriginState,
data.OriginPostalCd,
data.Appointment_Status,
data.ApptChgDateTime,
data.ApptChgDate,
data.ApptChgYear,
data.ApptChgMonth,
data.ApptChgWeek,
data.UserID,
CASE WHEN data.Name IS NULL THEN data.UserID ELSE data.Name END AS Name,
CASE WHEN data.UserType IS NULL THEN 'Robot' ELSE data.UserType END AS UserType,
data.ApptFromDTT,
data.ApptToDTT,
data.FirstDate,
data.Status,
data.First,
data.Rework,
data.Count,
DATEDIFF(DAY, LAG(apptfromdtt, 1) OVER (PARTITION BY loadnumber, stopnumber ORDER BY apptchgdatetime ASC), apptfromdtt) AS DaysFromLastAppt,
DATEDIFF(MINUTE, LAG(apptfromdtt, 1) OVER (PARTITION BY loadnumber, stopnumber ORDER BY apptchgdatetime ASC), apptfromdtt) AS MinFromLastAppt,
DATEDIFF(SECOND, LAG(apptfromdtt, 1) OVER (PARTITION BY loadnumber, stopnumber ORDER BY apptchgdatetime ASC), apptfromdtt) AS SecFromLastAppt,
DATEDIFF(DAY, LAG(apptchgdatetime, 1) OVER (PARTITION BY loadnumber, stopnumber ORDER BY apptchgdatetime ASC), apptchgdatetime) AS DaysFromLastApptChg,
DATEDIFF(MINUTE, LAG(apptchgdatetime, 1) OVER (PARTITION BY loadnumber, stopnumber ORDER BY apptchgdatetime ASC), apptchgdatetime) AS MinFromLastApptChg,
DATEDIFF(SECOND, LAG(apptchgdatetime, 1) OVER (PARTITION BY loadnumber, stopnumber ORDER BY apptchgdatetime ASC), apptchgdatetime) AS SecFromLastApptChg

/*INTO ##tblAppointmentChangeTemp*/
FROM OPENQUERY(NAJDAPRD,'SELECT DISTINCT
    load_leg_detail_r.ld_leg_id           AS loadnumber,
    load_leg_detail_r.dlvy_stop_seq_num   AS stopnumber,
	load_leg_r.eqmt_typ,
	load_leg_r.shpd_dtt,
    load_leg_detail_r.to_shpg_loc_cd      AS destinationid,
    load_leg_detail_r.to_shpg_loc_name    AS destinationname,
    load_leg_detail_r.to_cty_name         AS destinationcity,
    load_leg_detail_r.to_sta_cd           AS destinationstate,
    load_leg_detail_r.to_pstl_cd          AS destinationpostalcd,
    load_leg_r.frst_shpg_loc_cd           AS originid,
    load_leg_r.frst_shpg_loc_name         AS originname,
    load_leg_r.frst_cty_name              AS origincity,
    load_leg_r.frst_sta_cd                AS originstate,
    load_leg_r.frst_pstl_cd               AS originpostalcd,
    CASE
        WHEN appointments.appointment_status IS NULL THEN
            ''No Appointments''
        ELSE
            appointments.appointment_status
    END AS appointment_status,
    appointments.apptchgdatetime,
    appointments.apptchgdate,
    appointments.apptchgyear,
    appointments.apptchgmonth,
    appointments.apptchgweek,
    appointments.userid,
    appointments.name,
	appointments.usertype,
    appointments.apptfromdtt,
    appointments.appttodtt,
    appointments.firstdate,
    appointments.status,
    appointments.first,
    appointments.rework,
    appointments.count
FROM
    najdaadm.load_leg_r              load_leg_r
    INNER JOIN najdaadm.load_leg_detail_r       load_leg_detail_r ON load_leg_detail_r.ld_leg_id = load_leg_r.ld_leg_id
    INNER JOIN najdaadm.distribution_center_r   distribution_center_r ON distribution_center_r.shpg_loc_cd = load_leg_detail_r.to_shpg_loc_cd
    INNER JOIN (
        SELECT DISTINCT
            load_number,
            stop_number,
            appointment_status,
            apptchgdatetime,
            CAST(TRUNC(apptchgdatetime, ''DD'') AS DATE) AS apptchgdate,
            EXTRACT(YEAR FROM apptchgdatetime) AS apptchgyear,
            EXTRACT(MONTH FROM apptchgdatetime) AS apptchgmonth,
            trunc(apptchgdatetime, ''IW'') AS apptchgweek,
            userid,
            name,
			usertype,
            usr_grp_cd,
            apptfromdtt,
            appttodtt,
            firstdate,
            CASE
                WHEN firstdate = apptchgdatetime THEN
                    appointment_status || '' First''
                ELSE
                    appointment_status || '' Rework''
            END AS status,
            CASE
                WHEN firstdate = apptchgdatetime THEN
                    1
                ELSE
                    0
            END AS first,
            CASE
                WHEN firstdate <> apptchgdatetime THEN
                    1
                ELSE
                    0
            END AS rework,
            1 AS count
        FROM
            (
                SELECT DISTINCT
                    abpp_otc_appointmenthistory.load_number,
                    abpp_otc_appointmenthistory.stop_number,
                    abpp_otc_appointmenthistory.appointment_status,
					TO_TIMESTAMP(TO_CHAR(abpp_otc_appointmenthistory.appointment_change_time, ''YYYY-MM-DD HH24:MI:SS''),''YYYY-MM-DD HH24:MI:SS'')  AS apptchgdatetime,
                    abpp_otc_appointmenthistory.appointment_change_time,
                    upper(abpp_otc_appointmenthistory.appointment_changed_by) AS userid,
                    users.name,
					users.usertype,
                    users.usr_grp_cd,
                    abpp_otc_appointmenthistory.appointment_from_time     AS apptfromdtt,
                    abpp_otc_appointmenthistory.appointment_to_time       AS appttodtt,
                    MIN(TO_TIMESTAMP(TO_CHAR(abpp_otc_appointmenthistory.appointment_change_time, ''YYYY-MM-DD HH24:MI:SS''),''YYYY-MM-DD HH24:MI:SS'')  ) KEEP(DENSE_RANK FIRST ORDER BY abpp_otc_appointmenthistory
                    .appointment_change_time ASC) OVER(
                        PARTITION BY abpp_otc_appointmenthistory.load_number, appointment_status, stop_number
                    ) AS firstdate
                FROM
                    trn_appt.abpp_otc_appointmenthistory abpp_otc_appointmenthistory
                    LEFT JOIN (
                        SELECT DISTINCT
                            upper(usr_cd) AS userid,
                            name,
							CASE WHEN NAME IN (''Blue Prism Robot - Appts'',''Kapow Robot'')
							OR (UPPER(usr_cd) LIKE ''%*%'' OR UPPER(usr_cd) LIKE''%VOICEBOT%'') THEN ''Robot'' 
							ELSE ''Technician'' END AS UserType,
                            usr_grp_cd
                        FROM
                            nai2padm.usr_t
                    ) users ON upper(users.userid) = upper(abpp_otc_appointmenthistory.appointment_changed_by)
                WHERE
            EXTRACT( YEAR FROM abpp_otc_appointmenthistory.appointment_change_time) >= EXTRACT(YEAR FROM SYSDATE) - 1
            AND
                    ( abpp_otc_appointmenthistory.stop_number > ''1'' )
                    AND ( abpp_otc_appointmenthistory.appointment_status IN (
                        ''Confirmed'',
                        ''Notified''
                    ) )
            /*AND load_number = ''519013136''*/
                GROUP BY
                    abpp_otc_appointmenthistory.load_number,
                    abpp_otc_appointmenthistory.stop_number,
                    abpp_otc_appointmenthistory.appointment_status,
                    abpp_otc_appointmenthistory.appointment_change_time,
                    upper(abpp_otc_appointmenthistory.appointment_changed_by),
                    users.name,
					users.usertype,
                    users.usr_grp_cd,
                    abpp_otc_appointmenthistory.appointment_from_time,
                    abpp_otc_appointmenthistory.appointment_to_time
                ORDER BY
                    abpp_otc_appointmenthistory.load_number,
                    abpp_otc_appointmenthistory.stop_number,
                    abpp_otc_appointmenthistory.appointment_change_time
            ) appointments
    ) appointments ON appointments.load_number = load_leg_detail_r.ld_leg_id
                      AND appointments.stop_number = load_leg_detail_r.dlvy_stop_seq_num
WHERE
      EXTRACT(YEAR FROM load_leg_r.shpd_dtt) >= EXTRACT(YEAR FROM SYSDATE) - 1
	  /*AND ( ( load_leg_r.shpd_dtt >= add_months(trunc(SYSDATE, ''MM''), - 2) )*/
      /*AND  substr(to_shpg_loc_cd, 1, 8) NOT IN (
        ''58005914'',
        ''58004952'',
        ''58005988'',
        ''58003441'',
        ''58003411''
    ) */
      AND  load_leg_detail_r.dlvy_stop_seq_num > 1 
      AND  load_leg_detail_r.to_ctry_cd IN (
        ''USA'',
        ''CAN'',
		''MEX''
    ) 
      /*AND  load_leg_detail_r.to_pnt_typ_enu = ''Distribution Center'' */
      AND  load_leg_r.eqmt_typ IN (
        ''48FT'',
        ''53FT'',
        ''53IM'',
        ''53HC'',
        ''53RT''
    ) 
      AND  distribution_center_r.apt_rqrd_yn = ''Y'' 
	  /*AND LOAD_LEG_R.LD_LEG_ID = ''519013136''*/
ORDER BY
    load_leg_detail_r.ld_leg_id,
    load_leg_detail_r.dlvy_stop_seq_num,
    apptchgdatetime
	') data
	LEFT JOIN USCTTDEV.dbo.tblCustomers cus ON cus.HierarchyNum = CASE WHEN data.DestinationID LIKE '5%' THEN LEFT(data.DestinationID,8) ELSE data.DestinationID END
	/*ORDER BY CAST(SHPD_DTT AS DATE) ASC, LoadNumber ASC, StopNumber ASC, ApptChgDateTime ASC*/