
SELECT loads.*,
origins.ZN_CD AS OriginZone,
CASE WHEN loads.LAST_CTRY_CD = 'USA' THEN '5'+loads.LAST_STA_CD+LEFT(loads.LAST_PSTL_CD,5)
ELSE dests.ZN_CD END AS DestZone,
CASE WHEN awards.LaneID IS NOT NULL THEN 'Award Lane' ELSE 'Non-Award Lane' END AS AwardType,
awards.LaneID,
awards.Lane,
awards.BusinessUnit,
awards.[Order Type],
awards.Region,
awards.CarrierManager,
awards.UPDATED_LOADS AS AnnualLoads,
awards.AWARD_PCT,
awards.BaseLoads4,
awards.SurgeLoads4,
awards.BaseLoads,
awards.SurgeLoads

FROM OPENQUERY(NAJDAPRD, 'SELECT 
llr.LD_LEG_ID,
llr.CUR_OPTLSTAT_ID,
s.STAT_SHRT_DESC,
llr.CARR_CD,
llr.SRVC_CD,
llr.FRST_SHPG_LOC_CD,
llr.FRST_SHPG_LOC_NAME,
llr.FRST_CTRY_CD,
llr.FRST_STA_CD,
llr.FRST_CTY_NAME,
llr.FRST_PSTL_CD,
llr.LAST_SHPG_LOC_CD,
llr.LAST_SHPG_LOC_NAME,
llr.LAST_CTRY_CD,
llr.LAST_STA_CD,
llr.LAST_CTY_NAME,
llr.LAST_PSTL_CD,
llr.EQMT_TYP,
TRUNC(TO_DATE(
        CASE
            WHEN llr.shpd_dtt IS NULL THEN
                llr.strd_dtt
            ELSE
                llr.shpd_dtt
        END),''dd'') AS dateFormula,
TRUNC(llr.CRTD_DTT,''dd'') AS crtd_dtt,
TRUNC(llr.STRD_DTT,''dd'') AS strd_dtt,
TRUNC(llr.SHPD_DTT,''dd'') as shpd_dtt,
CASE WHEN TRUNC(TO_DATE(
        CASE
            WHEN llr.shpd_dtt IS NULL THEN
                llr.strd_dtt
            ELSE
                llr.shpd_dtt
        END),''dd'') BETWEEN NEXT_DAY(SYSDATE-8, ''Sunday'')  AND NEXT_DAY(SYSDATE-1, ''Saturday'')
        THEN ''Current Week''
        ELSE ''Next Week''
        END AS WeekType
        


FROM NAJDAADM.LOAD_LEG_R llr
INNER JOIN NAJDAADM.STATUS_R s ON s.stat_id = llr.cur_optlstat_id
WHERE
    TO_DATE(
        CASE
            WHEN llr.shpd_dtt IS NULL THEN
                llr.strd_dtt
            ELSE
                llr.shpd_dtt
        END) BETWEEN NEXT_DAY(SYSDATE-8, ''Sunday'')  AND NEXT_DAY(SYSDATE+7, ''Saturday'')  /* for current week BETWEEN NEXT_DAY(SYSDATE-8, ''Sunday'')  AND NEXT_DAY(SYSDATE-1, ''Saturday'')*/
    AND llr.cur_optlstat_id IN (
                        300,
                        305,
                        310,
                        320,
                        325,
                        335,
                        345
                    )
                    AND llr.eqmt_typ IN (
                        ''48FT'',
                        ''48TC'',
                        ''53FT'',
                        ''53TC'',
                        ''53IM'',
                        ''53RT'',
                        ''53HC'',
						''LTL''
                    )
                    AND llr.last_ctry_cd IN (
                        ''USA'',
                        ''CAN'',
                        ''MEX''
                    )
                    AND llr.frst_ctry_cd IN (
                        ''USA'',
                        ''CAN'',
                        ''MEX''
                    )
					AND llr.last_shpg_loc_cd NOT LIKE ''LCL%''
') loads

LEFT JOIN (SELECT tmz.* FROM USCTTDEV.dbo.tblTMSZones tmz
INNER JOIN(
SELECT DISTINCT tmz.ZN_DESC, CTY_CD, STA_CD, CTRY_CD, MIN(tmz.ID) AS MinID
FROM USCTTDEV.dbo.tblTMSZones tmz
GROUP BY ZN_DESC, CTY_CD, STA_CD, CTRY_CD) minRec ON minRec.MinID = tmz.ID) Origins
ON Origins.CTRY_CD = loads.FRST_CTRY_CD
AND Origins.STA_CD = loads.FRST_STA_CD
AND Origins.CTY_CD = loads.FRST_CTY_NAME

LEFT JOIN (SELECT tmz.* FROM USCTTDEV.dbo.tblTMSZones tmz
INNER JOIN(
SELECT DISTINCT tmz.ZN_DESC, CTY_CD, STA_CD, CTRY_CD, MIN(tmz.ID) AS MinID
FROM USCTTDEV.dbo.tblTMSZones tmz
GROUP BY ZN_DESC, CTY_CD, STA_CD, CTRY_CD) minRec ON minRec.MinID = tmz.ID) Dests
ON Dests.CTRY_CD = loads.LAST_CTRY_CD
AND Dests.STA_CD = loads.LAST_STA_CD
AND Dests.CTY_CD = loads.LAST_CTY_NAME

LEFT JOIN (
SELECT bal.LaneID,
bal.Lane,
bal.ORIG_CITY_STATE,
bal.DEST_CITY_STATE,
bal.BusinessUnit,
bal.[Order Type],
CASE
      WHEN
         bal.[order type] LIKE '%INBOUND%' 
      THEN
         Substring(bal.dest, Charindex(', ', bal.dest) + 2, Len(bal.dest)) 
      ELSE
         Substring(bal.origin, Charindex(', ', bal.origin) + 2, Len(bal.origin)) 
   END
   AS JoinState,
ra.Region,
ra.CarrierManager,
bar.SCAC,
bal.UPDATED_LOADS,
bar.AWARD_PCT,
ROUND((bal.UPDATED_LOADS * bar.AWARD_PCT) / 52, 4) AS BaseLoads4,
ROUND(((bal.UPDATED_LOADS * bar.AWARD_PCT) / 52) * 1.15, 4) AS SurgeLoads4,
ROUND((bal.UPDATED_LOADS * bar.AWARD_PCT) / 52, 0) AS BaseLoads,
ROUND(((bal.UPDATED_LOADS * bar.AWARD_PCT) / 52) * 1.15, 0) AS SurgeLoads
FROM USCTTDEV.dbo.tblBidAppLanes bal
INNER JOIN USCTTDEV.dbo.tblBidAppRates bar ON bar.LaneID = bal.LaneID
INNER JOIN USCTTDEV.dbo.tblRegionalAssignments ra ON (CASE
      WHEN
         bal.[order type] LIKE '%INBOUND%' 
      THEN
         Substring(bal.dest, Charindex(', ', bal.dest) + 2, Len(bal.dest)) 
      ELSE
         Substring(bal.origin, Charindex(', ', bal.origin) + 2, Len(bal.origin)) 
   END) = ra.StateAbbv
WHERE bar.AWARD_PCT IS NOT NULL) awards ON awards.ORIG_CITY_STATE = origins.ZN_CD
AND awards.DEST_CITY_STATE = CASE WHEN loads.LAST_CTRY_CD = 'USA' THEN '5'+loads.LAST_STA_CD+LEFT(loads.LAST_PSTL_CD,5) ELSE dests.ZN_CD END
AND awards.SCAC = loads.SRVC_CD
AND awards.Lane = origins.ZN_CD + '-' + CASE WHEN loads.LAST_CTRY_CD = 'USA' THEN '5'+loads.LAST_STA_CD+LEFT(loads.LAST_PSTL_CD,5) ELSE dests.ZN_CD END + CASE WHEN loads.EQMT_TYP = '53TC' THEN ' (TC)' ELSE '' END

