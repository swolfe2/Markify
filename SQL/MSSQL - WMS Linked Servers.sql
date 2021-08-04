import
/*NCDC	USTWAS08	 WMS_WFM_USCH_NCDC.*/

DECLARE @server NVARCHAR(20),
   @database NVARCHAR(20)

SET @server = 'USTWAS08'

SELECT
  *
FROM
  OPENQUERY(USTWAS08, 'select distinct car_move.car_move_id car_move_id,
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

