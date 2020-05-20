SELECT 
    aph.load_number   AS load_number,
    aph.shipment_number,
    first.originalappointment,
    first.originalappointmentadded,
    aph.appointment_from_time,
    aph.appointment_change_time,
    aph.appointment_changed_by,
    usr.name,
    aph.reason_code,
    aph.reason_desc,
    CAST(aph.stop_number AS INT) AS stop_number,
    aph.load_status,
    sh.rfrc_num14     AS requestor,
FROM
    nai2padm.abpp_otc_appointmenthistory   aph
    LEFT JOIN nai2padm.usr_t                         usr ON usr.usr_cd = aph.appointment_changed_by
    INNER JOIN najdaadm.shipment_r                    sh ON sh.shpm_num = aph.shipment_number
    INNER JOIN (
    SELECT ca.location_id, ca.team_id FROM NAJDAADM.abpp_otc_caps_analyst ca
        INNER JOIN(
        SELECT LOCATION_ID, MAX(TO_DATE) AS MaxDate
        from NAJDAADM.abpp_otc_caps_analyst 
        WHERE TEAM_ID = 'IB'
        GROUP BY LOCATION_ID
        ) max on max.location_Id = ca.location_id
        AND max.maxdate = ca.to_date
    ) loc ON loc.LOCATION_ID = sh.frm_shpg_loc_cd
    
    INNER JOIN (
        SELECT
            aph.load_number,
            aph.shipment_number,
            aph.appointment_from_time     AS originalappointment,
            aph.appointment_change_time   AS originalappointmentadded
        FROM
            nai2padm.abpp_otc_appointmenthistory aph
            INNER JOIN (
                SELECT
                    aph.load_number,
                    aph.shipment_number,
                    MIN(aph.appointment_change_time) AS origappointmentadded
                FROM
                    nai2padm.abpp_otc_appointmenthistory aph
                WHERE
                    appointment_change_time >= SYSDATE - 180
                    AND reason_code = 'APC_'
                    AND stop_number > 1
                GROUP BY
                    aph.load_number,
                    aph.shipment_number
            ) origappt ON origappt.load_number = aph.load_number
                          AND origappt.shipment_number = aph.shipment_number
                          AND origappt.origappointmentadded = aph.appointment_change_time
        WHERE
            appointment_change_time >= SYSDATE - 180
            AND reason_code = 'APC_'
            AND stop_number > 1
        GROUP BY
            aph.load_number,
            aph.shipment_number,
            aph.appointment_from_time,
            aph.appointment_change_time
    ) first ON first.load_number = aph.load_number
               AND first.shipment_number = aph.shipment_number
    INNER JOIN (
        SELECT
            aph.load_number,
            aph.shipment_number,
            aph.appointment_from_time     AS mostrecentappointment,
            aph.appointment_change_time   AS mostrecentchangetime
        FROM
            nai2padm.abpp_otc_appointmenthistory aph
            INNER JOIN (
                SELECT
                    aph.load_number,
                    aph.shipment_number,
                    MAX(aph.appointment_change_time) AS mostrecentappointment
                FROM
                    nai2padm.abpp_otc_appointmenthistory aph
                WHERE
                    appointment_change_time >= SYSDATE - 180
                    AND reason_code <> 'APC_'
                    AND stop_number > 1
                GROUP BY
                    aph.load_number,
                    aph.shipment_number
            ) newappt ON newappt.load_number = aph.load_number
                         AND newappt.shipment_number = aph.shipment_number
                         AND newappt.mostrecentappointment = aph.appointment_change_time
        WHERE
            appointment_change_time >= SYSDATE - 180
            AND reason_code <> 'APC_'
            AND stop_number > 1
        GROUP BY
            aph.load_number,
            aph.shipment_number,
            aph.appointment_from_time,
            aph.appointment_change_time
    ) last ON last.load_number = aph.load_number
              AND last.shipment_number = aph.shipment_number
              AND last.mostrecentchangetime = aph.appointment_change_time
WHERE
    aph.appointment_change_time >= SYSDATE - 1
    AND aph.reason_code <> 'APC_'
    AND aph.stop_number > 1
    AND loc.team_id = 'IB'
ORDER BY
    aph.load_number,
    aph.shipment_number,
    aph.appointment_change_time DESC,
    aph.stop_number ASC