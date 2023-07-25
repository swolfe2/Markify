select ld_leg_id,
-- Equipment Type
EQMT_TYP,
-- Date it came into TM
CRTD_DTT,
-- Original MAD Date
FRST_STOP_LTST_FRM_PKUP_DTT,
-- Updated Customer MAD Date
--UPDT_DTT,
-- Estimated Carrier Pickup Date
STRD_DTT,
-- Customer RDD
END_DTT,
-- First Shipping Location Name
FRST_SHPG_LOC_NAME,
-- First State Code
FRST_STA_CD,
-- First City Name
FRST_CTY_NAME,
-- First ZIP Code
FRST_PSTL_CD,
-- Last Shipping Location Name
LAST_SHPG_LOC_NAME,
-- Last State Code
LAST_STA_CD,
-- Last  City Name
LAST_CTY_NAME,
-- Last  ZIP Code
LAST_PSTL_CD,
-- Customer Name
--CUST_NAME


from load_leg_r


where load_leg_r.ld_leg_id = '517269571'