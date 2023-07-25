SELECT DISTINCT
    lldr.ld_leg_id,
    lldr.dlvy_stop_seq_num,
    llr.frst_shpg_loc_cd,
    llr.frst_shpg_loc_name,
    llr.frst_cty_name,
    llr.frst_sta_cd,
    llr.frst_ctry_cd,
    llr.frst_pstl_cd,
    lldr.to_shpg_loc_cd,
    lldr.to_shpg_loc_name,
    lldr.to_cty_name,
    lldr.to_sta_cd,
    lldr.to_ctry_cd,
    lldr.to_pstl_cd,
    llr.srvc_cd,
    llr.eqmt_typ,
    cm.base_appointment_datetime,
    cm.base_appt_reason,
    cm.final_appointment_datetime,
    trunc(cm.final_appointment_datetime, 'IW') AS final_appt_week,
    TO_CHAR(trunc(cm.final_appointment_datetime, 'MM'), 'Month') AS final_appt_month,
    cm.final_appt_reason,
    cm.arrived_at_datetime,
    cm.departed_datetime,
    llr.fixd_itnr_dist,
    cm.carr_rdy_dtt,
    cm.caps_late,
    cm.caps_reason,
    cm.adv_notif,
    cm.adv_reason_code,
    rc.tm_desc,
    cm.confirm_delivery_datetime,
    cm.entry_date,
    cm.space_maker,
    cm.review_required,
    cm.reviewed_by,
    cm.reviewed_date,
    cm.scored_by,
    cm.updates_num,
    cm.corporate_id,
    CASE
        WHEN substr(llr.frst_shpg_loc_cd, 5, 1) = '-'
             AND substr(llr.last_shpg_loc_cd, 5, 1) = '-' THEN
            'STO'
        WHEN substr(llr.frst_shpg_loc_cd, 5, 1) = '-'
             AND substr(llr.last_shpg_loc_cd, 1, 1) = '5' THEN
            'CUSTOMER'
        WHEN substr(llr.frst_shpg_loc_cd, 5, 1) = '-'
             AND llr.last_shpg_loc_cd = '99999999' THEN
            'CUSTOMER'
        WHEN substr(llr.frst_shpg_loc_cd, 1, 1) = 'V'
             AND substr(lar.corp1_id, 1, 2) = 'RM' THEN
            'MATERIALS'
        WHEN substr(llr.frst_shpg_loc_cd, 1, 1) = 'V'
             AND substr(lar.corp1_id, 1, 2) = 'RF' THEN
            'RECFIBER'
        ELSE
            'UNKNOWN'
    END AS "SHIP_TYPE",
    
    -- Ship Mode logic from Thomas Fraser's 2019 Freight Spend Detail SAS program
    CASE
        WHEN llr.eqmt_typ = '53IM' THEN
            'INTERMODAL'
        ELSE
            'TRUCK'
    END AS ship_mode,    
    
 -- Order Type logic from Thomas Fraser's 2019 Freight Spend Detail SAS program   
    CASE
        WHEN lar.corp1_id = 'RM'                    THEN
            'RM-INBOUND'
        WHEN lar.corp1_id = 'RF'                    THEN
            'RF-INBOUND'
        WHEN substr(llr.last_shpg_loc_cd, 1, 1) = 'R' THEN
            'RETURNS'
        WHEN substr(llr.last_shpg_loc_cd, 1, 1) = '1'
             OR substr(llr.last_shpg_loc_cd, 1, 1) = '2' THEN
            'INTERMILL'
        ELSE
            'CUSTOMER'
    END AS order_type,
    
-- Inbound/Outbound logic from Thomas Fraser's 2019 Freight Spend Detail SAS program
    CASE
        WHEN lar.corp1_id = 'RM'
             OR lar.corp1_id = 'RF'
             OR substr(llr.last_shpg_loc_cd, 1, 1) = 'R' THEN
            'INBOUND'
        ELSE
            'OUTBOUND'
    END AS inbound_outbound,
    
-- Business Unit logic from Thomas Fraser's 2019 Freight Spend Detail SAS Program
    CASE 
        WHEN SH.RFRC_NUM10 IN ('2810','2820','Z01') THEN 'CONSUMER'
        WHEN SH.RFRC_NUM10 IN ('2811','2821','Z02','Z04','Z06','Z07') THEN 'KCP'
        WHEN SH.RFRC_NUM10 = 'Z05' THEN 'NON WOVENS' 
        WHEN SUBSTR(lldr.TO_SHPG_LOC_CD,1,4) IN ('2000','2019','2022','2023','2024','2026','2027','2028','2029','2031','2032','2035','2036','2038','2041','2049','2050','2054','2063','2075','2094','2100','2137','2138','2142','2170','2171','2172','2183','2187','2191','2197','2210','2213','2240','2275','2283','2291','2292','2300','2303','2307','2314','2320','2331','2336','2347','2353','2358','2359','2360','2369','2370','2385','2399','2408','2412','2414','2419','2422','2443','2463','2483','2487','2489','2496','2500','2510','2511','2822','2839') THEN 'CONSUMER'
        WHEN SUBSTR(lldr.TO_SHPG_LOC_CD,1,4) IN ('2034','2039','2040','2042','2043','2044','2048','2051','2079','2080','2091','2096','2099','2104','2106','2111','2112','2113','2124','2126','2161','2177','2200','2234','2299','2301','2302','2304','2310','2323','2325','2334','2348','2349','2350','2356','2362','2363','2375','2386','2415','2416','2425','2429','2446','2449','2459','2460','2467','2474','2476','2477','2485','2495','2505','2827','2833','2834','2837') THEN 'KCP' 
        ELSE ''                                
    END BUSINESS_UNIT,

-- Get Regional/Carrier Manager Countries
    CASE
        WHEN lar.corp1_id = 'RM'
             OR lar.corp1_id = 'RF'
             OR substr(llr.last_shpg_loc_cd, 1, 1) = 'R' THEN
            lldr.to_ctry_cd
        ELSE
            llr.frst_ctry_cd
    END AS regional_assignment_country,
    
-- Get Regional/Carrier Manager States
    CASE
        WHEN lar.corp1_id = 'RM'
             OR lar.corp1_id = 'RF'
             OR substr(llr.last_shpg_loc_cd, 1, 1) = 'R' THEN
            lldr.to_sta_cd
        ELSE
            llr.frst_sta_cd
    END AS regional_assignment_state,
    ra.statename,
    ra.region,
    ra.carriermanager,
    cust.hierarchy,
    cust.hierarchynum,
    cust.customer_group,
    case when cust.hierarchy is null then
        CASE 
            WHEN SH.RFRC_NUM10 IN ('2810','2820','Z01') THEN 'CONSUMER'
            WHEN SH.RFRC_NUM10 IN ('2811','2821','Z02','Z04','Z06','Z07') THEN 'KCP'
            WHEN SH.RFRC_NUM10 = 'Z05' THEN 'NON WOVENS' 
            WHEN SUBSTR(lldr.TO_SHPG_LOC_CD,1,4) IN ('2000','2019','2022','2023','2024','2026','2027','2028','2029','2031','2032','2035','2036','2038','2041','2049','2050','2054','2063','2075','2094','2100','2137','2138','2142','2170','2171','2172','2183','2187','2191','2197','2210','2213','2240','2275','2283','2291','2292','2300','2303','2307','2314','2320','2331','2336','2347','2353','2358','2359','2360','2369','2370','2385','2399','2408','2412','2414','2419','2422','2443','2463','2483','2487','2489','2496','2500','2510','2511','2822','2839') THEN 'CONSUMER'
            WHEN SUBSTR(lldr.TO_SHPG_LOC_CD,1,4) IN ('2034','2039','2040','2042','2043','2044','2048','2051','2079','2080','2091','2096','2099','2104','2106','2111','2112','2113','2124','2126','2161','2177','2200','2234','2299','2301','2302','2304','2310','2323','2325','2334','2348','2349','2350','2356','2362','2363','2375','2386','2415','2416','2425','2429','2446','2449','2459','2460','2467','2474','2476','2477','2485','2495','2505','2827','2833','2834','2837') THEN 'KCP' 
            ELSE 'UNKNOWN' 
        end       
        ELSE cust.hierarchy 
        END AS CUSTOMER

FROM
    nai2padm.load_leg_r      llr
    JOIN load_leg_detail_r        lldr ON lldr.ld_leg_id = llr.ld_leg_id
    JOIN abpp_otc_caps_master     cm ON cm.load_id = llr.ld_leg_id
                                    AND lldr.dlvy_stop_seq_num = cm.stop_num
    JOIN load_at_r                lar ON llr.frst_shpg_loc_cd = lar.shpg_loc_cd
    LEFT JOIN abpp_reason_code_score   rc ON rc.tm_reason_code = cm.adv_reason_code
    LEFT JOIN shipment_r                sh  ON sh.shpm_num = lldr.shpm_num
    LEFT JOIN tblregionalassignments    ra ON ra.stateabbv =
        CASE
            WHEN lar.corp1_id = 'RM'
                 OR lar.corp1_id = 'RF'
                 OR substr(llr.last_shpg_loc_cd, 1, 1) = 'R' THEN
                lldr.to_sta_cd
            ELSE
                llr.frst_sta_cd
        END
                                           AND ra.country =
        CASE
            WHEN lar.corp1_id = 'RM'
                 OR lar.corp1_id = 'RF'
                 OR substr(llr.last_shpg_loc_cd, 1, 1) = 'R' THEN
                lldr.to_ctry_cd
            ELSE
                llr.frst_ctry_cd
        END
    LEFT JOIN tblcustomers cust on cust.hierarchynum = substr(llr.last_shpg_loc_cd, 1, 8)
    
WHERE
      -- Only bring in lines that have the right amount of stops, and are after the pickup
    ( ( lldr.dlvy_stop_seq_num > 1 )
      AND ( substr(frst_shpg_loc_cd, 1, 1) IN (
        '2',
        'V'
    ) )
      -- Only bring in lines that are the right equipment type
      AND ( llr.eqmt_typ IN (
        '48FT',
        '48TC',
        '53FT',
        '53TC',
        '53IM',
        '53HC',
        '53RT'
    ) )
      -- Only bring in lines that don't need to be reviewed
      AND ( cm.review_required = 'N' ) 
      -- Only bring in lines that have been scored
      AND ( cm.scored_by is not null))
ORDER BY
    lldr.ld_leg_id,
    lldr.dlvy_stop_seq_num,
    cm.final_appointment_datetime