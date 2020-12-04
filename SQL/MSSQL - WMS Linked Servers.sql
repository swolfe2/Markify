WITH SASTemp AS (
SELECT 'BEECH' as [SASDSN], 'UST2AS42' AS [Server], 'WMS_WFM_USBI_BEECH' AS [DefaultDatabase] UNION ALL
SELECT 'MODC' as [SASDSN], 'UST2AS42' AS [Server], 'WMS_WFM_CAMO_MIL' AS [DefaultDatabase] UNION ALL
SELECT 'NMC' as [SASDSN], 'UST2AS42' AS [Server], 'WMS_WFM_USNM_NMC' AS [DefaultDatabase] UNION ALL
/*SELECT 'TORONTO' as [SASDSN], 'UST2AS42' AS [Server], 'WMS_WFM_CL1' AS [DefaultDatabase] UNION ALL*/ /*Per Sarah H 9/10/2020, no longer needed*/
SELECT 'JENKS' as [SASDSN], 'UST2AS43' AS [Server], 'WMS_WFM_USOK_JNKS' AS [DefaultDatabase] UNION ALL
SELECT 'MIDSOURTH' as [SASDSN], 'UST2AS43' AS [Server], 'WMS_WFM_CL2' AS [DefaultDatabase] UNION ALL
SELECT 'MOBILE' as [SASDSN], 'UST2AS43' AS [Server], 'WMS_WFM_USMO_MOB' AS [DefaultDatabase] UNION ALL
SELECT 'FULLERTON' as [SASDSN], 'UST2AS44' AS [Server], 'WMS_WFM_USFU_FUL' AS [DefaultDatabase] UNION ALL
SELECT 'LADC' as [SASDSN], 'UST2AS44' AS [Server], 'WMS_WFM_USOL_LADC' AS [DefaultDatabase] UNION ALL
SELECT 'NWDC' as [SASDSN], 'UST2AS44' AS [Server], 'WMS_WFM_USWW_NWDC' AS [DefaultDatabase] UNION ALL
SELECT 'OGDEN' as [SASDSN], 'UST2AS44' AS [Server], 'WMS_WFM_USOG_OGD' AS [DefaultDatabase] UNION ALL
SELECT 'PNDC' as [SASDSN], 'UST2AS44' AS [Server], 'WMS_WFM_CL3' AS [DefaultDatabase] UNION ALL
SELECT 'SWDC' as [SASDSN], 'UST2AS44' AS [Server], 'WMS_WFM_USLA' AS [DefaultDatabase] UNION ALL
SELECT 'CHESTER' as [SASDSN], 'UST2AS45' AS [Server], 'WMS_WFM_USCE_CHE' AS [DefaultDatabase] UNION ALL
SELECT 'ERDC' as [SASDSN], 'UST2AS45' AS [Server], 'WMS_WFM_USPT' AS [DefaultDatabase] UNION ALL
SELECT 'MAUMELLE' as [SASDSN], 'UST2AS46' AS [Server], 'WMS_WFM_USMM_MAU' AS [DefaultDatabase] UNION ALL
SELECT 'SDDC' as [SASDSN], 'UST2AS46' AS [Server], 'WMS_WFM_USSD_SDDC' AS [DefaultDatabase] UNION ALL
SELECT 'SRDC' as [SASDSN], 'UST2AS46' AS [Server], 'WMS_WFM_USAG' AS [DefaultDatabase] UNION ALL
SELECT 'RBW' as [SASDSN], 'UST2AS86' AS [Server], 'WMS2019_CL1' AS [DefaultDatabase] UNION ALL
SELECT 'NCDC' as [SASDSN], 'USTWAS08' AS [Server], 'WMS_WFM_USCH_NCDC' AS [DefaultDatabase] UNION ALL
SELECT 'NCOF' as [SASDSN], 'USTWAS08' AS [Server], 'WMS_WFM_USCH_NCOF' AS [DefaultDatabase] UNION ALL
SELECT 'NCSF' as [SASDSN], 'USTWAS08' AS [Server], 'WMS_WFM_CL6' AS [DefaultDatabase] UNION ALL
SELECT 'PARIS' as [SASDSN], 'USTWAS08' AS [Server], 'WMS_WFM_USPA_PARIS' AS [DefaultDatabase] UNION ALL
SELECT 'NEDC' as [SASDSN], 'UST2AS45' AS [Server], 'WMS_WFM_USPW_SMDC' AS [DefaultDatabase])
SELECT * FROM SASTEmp

   /*NCDC	USTWAS08	 WMS_WFM_USCH_NCDC.*/

   DECLARE @server NVARCHAR(20),
   @database NVARCHAR(20)

   SET @server = 'USTWAS08'
   
   SELECT * FROM OPENQUERY(USTWAS08, 'select distinct car_move.car_move_id car_move_id,
        trlr.trlr_id,
        trlr.trlr_num,
        trlr.yard_loc,
		CONVERT(datetime, trlr.arrdte, 120) trlr_arrival_date,
		CONVERT(datetime, car_move.vc_sap_oub_cmpdte, 120) car_move_sap_complete_date,
		CONVERT(datetime, shipment.late_dlvdte, 120) target_ship_date,
        car_move.carcod,
        (select max(adrmst.adrnam)
           from WMS_WFM_USCH_NCDC.dbo.ord ord2,
                WMS_WFM_USCH_NCDC.dbo.shipment_line,
                WMS_WFM_USCH_NCDC.dbo.shipment,
                WMS_WFM_USCH_NCDC.dbo.stop,
                WMS_WFM_USCH_NCDC.dbo.adrmst
          where stop.car_move_id = car_move.car_move_id
            and shipment_line.ordnum = ord2.ordnum
            and shipment_line.client_id = ord2.client_id
            and shipment_line.wh_id = ord2.wh_id
            and shipment_line.ship_id = shipment.ship_id
            and shipment.stop_id = stop.stop_id
            and stop.stop_seq = 1
            and adrmst.adr_id = stop.adr_id) stcust_addr_name
   from WMS_WFM_USCH_NCDC.dbo.stop,
        WMS_WFM_USCH_NCDC.dbo.car_move
   left outer
   join WMS_WFM_USCH_NCDC.dbo.trlr
     on trlr.trlr_id = car_move.trlr_id
   left outer
   join WMS_WFM_USCH_NCDC.dbo.locmst
     on locmst.wh_id = trlr.yard_loc_wh_id
    and locmst.stoloc = trlr.yard_loc
   left outer
   join WMS_WFM_USCH_NCDC.dbo.wrkque
     on wrkque.refloc = trlr.trlr_num
    and wrkque.wrkref = trlr.carcod,
        WMS_WFM_USCH_NCDC.dbo.shipment_line,
        WMS_WFM_USCH_NCDC.dbo.shipment
   left outer
   join WMS_WFM_USCH_NCDC.dbo.shp_dst_loc
     on shp_dst_loc.ship_id = shipment.ship_id
    and shp_dst_loc.wh_id = shipment.wh_id,
        WMS_WFM_USCH_NCDC.dbo.ord
   left outer
   join WMS_WFM_USCH_NCDC.dbo.adrmst
     on ord.bt_adr_id = adrmst.adr_id,
        WMS_WFM_USCH_NCDC.dbo.ord_line,
        WMS_WFM_USCH_NCDC.dbo.prtmst_view,
        WMS_WFM_USCH_NCDC.dbo.prtftp
   left outer
   join WMS_WFM_USCH_NCDC.dbo.prtftp_dtl pfd_cse
     on pfd_cse.prtnum = prtftp.prtnum
    and pfd_cse.wh_id = prtftp.wh_id
    and pfd_cse.ftpcod = prtftp.ftpcod
    and pfd_cse.uomcod = ''CS''
   left outer
   join WMS_WFM_USCH_NCDC.dbo.prtftp_dtl pfd_lyr
     on pfd_lyr.prtnum = prtftp.prtnum
    and pfd_lyr.wh_id = prtftp.wh_id
    and pfd_lyr.ftpcod = prtftp.ftpcod
    and pfd_lyr.uomcod = ''LY''
   left outer
   join WMS_WFM_USCH_NCDC.dbo.prtftp_dtl pfd_tld
     on pfd_tld.prtnum = prtftp.prtnum
    and pfd_tld.wh_id = prtftp.wh_id
    and pfd_tld.ftpcod = prtftp.ftpcod
    and pfd_tld.pal_flg = 1
  where shipment_line.ordnum = ord_line.ordnum
    and shipment_line.ordlin = ord_line.ordlin
    and shipment_line.ordsln = ord_line.ordsln
    and shipment_line.client_id = ord_line.client_id
    and shipment_line.wh_id = ord_line.wh_id
    and ord_line.ordnum = ord.ordnum
    and ord_line.wh_id = ord.wh_id
    and ord_line.client_id = ord.client_id
    and prtmst_view.prtnum = ord_line.prtnum
    and prtmst_view.wh_id = ord_line.wh_id
    and prtftp.prtnum = prtmst_view.prtnum
    and prtftp.wh_id = prtmst_view.wh_id_tmpl
    and prtftp.defftp_flg = 1
    and shipment.ship_id = shipment_line.ship_id
    and shipment.stop_id = stop.stop_id
    and stop.car_move_id = car_move.car_move_id
	and car_move.trans_mode=''T''
	and car_move.vc_equip=''LIVE''
	and shipment.late_dlvdte >= GETDATE()-90') data 

