SELECT L.LD_LEG_ID, 
	CONVERT(NVARCHAR(10), A.AUDT_SYS_DTT, 101) AS REJECT_DATE_TIME,
	CONVERT(NVARCHAR(10), A.LD_STRD_DTT, 101) AS TENDERED_READY_DATE,
	CONVERT(NVARCHAR(10), A.LD_END_DTT, 101) AS TENDERED_END_DATE,
           CASE 
                      WHEN L.FRST_SHPG_LOC_CD IN ( '2292-NB01', 
                                                  '2358-NC04', 
                                                  '2358-NC05' ) THEN L.FRST_CTY_NAME + '-NOF-' + L.FRST_STA_CD 
                      WHEN L.FRST_SHPG_LOC_CD IN ( '2323-KR01' ) THEN L.FRST_CTY_NAME + '-KCP-' + L.FRST_STA_CD 
                      WHEN L.FRST_SHPG_LOC_CD IN ( '2474-RV01' ) THEN L.FRST_CTY_NAME + '-SKINCARE-' + L.FRST_STA_CD 
                      WHEN L.FRST_CTY_NAME = 'FLETCHER' THEN 'HENDERSONVILLE-NC' 
                                 /*combining Hendersonville and Fletcher*/ 
                      ELSE FRST_CTY_NAME + '-' + FRST_STA_CD 
           END AS ORIGINCITYSTATE, 
           CASE 
                      WHEN LAST_CTRY_CD = 'CAN' THEN Substring(LAST_PSTL_CD, 1, 6) 
                      ELSE Substring(LAST_PSTL_CD, 1, 5) 
           END                               AS DEST5ZIP, 
           LAST_CTY_NAME + '-' + LAST_STA_CD AS DESTCITYSTATE, 
           LAST_STA_CD                       AS DESTSTATE, 
           LAST_SHPG_LOC_NAME, 
           L.EQMT_TYP, 
           A.LD_SRVC_CD, 
           A.AUDT_CNFG_CD 
FROM       [NAJDAPRD]..[NAJDAADM].AUDIT_LOAD_LEG_R A 
INNER JOIN [NAJDAPRD]..[NAJDAADM].LOAD_LEG_R L 
ON         L.LD_LEG_ID = A.LD_LEG_ID 
WHERE      ( 
                      L.CUR_OPTLSTAT_ID IN ( 320, 
                                            325, 
                                            335, 
                                            345 ) ) 
AND        A.AUDT_SYS_DTT BETWEEN Getdate()-7 AND Getdate()-1 
AND        A.LD_SRVC_CD = 'NFIL' 
AND        A.AUDT_CNFG_CD IN ( 'TENDREJ' ) 
AND        L.EQMT_TYP     IN ( '53FT', 
                              '53IM' ) 
AND        L.LAST_CTRY_CD IN ( 'USA', 
                              'MEX', 
                              'CAN' ) 
AND        LAST_SHPG_LOC_CD <> '99999999'