/* 
This is how to do a simple select statement, but also apply
some logic to apply specific strings based on other values.
Also, get the Name / Email of who entered the change on the table
*/

-- This is how to do a simple select statement, but also apply some logic to apply specific strings based on other values. Also, get the Name / Email of who entered the change on the table
SELECT fuel_surcharge_price_r.fuel_schg_prce_id, 
       fuel_surcharge_price_r.efct_dt, 
       fuel_surcharge_price_r.expd_dt, 
       fuel_surcharge_price_r.fuel_schg_prce_dlr, 
       fuel_surcharge_price_r.crtd_dtt, 
       fuel_surcharge_price_r.updt_dtt, 
       fuel_surcharge_price_r.fuel_schg_typ_cd, 
       fuel_surcharge_type_r.fuel_schg_typ_desc, 
       fuel_surcharge_type_r.cncy_typ, 
       fuel_surcharge_price_r.crtd_usr_cd, 
       fuel_surcharge_price_r.updt_usr_cd,
/* USE LOGIC TO DETERMINE SHIPMODE */
        (CASE WHEN  fuel_surcharge_price_r.fuel_schg_typ_cd LIKE '%LTL%'  THEN 'LTL'
             WHEN  fuel_surcharge_price_r.fuel_schg_typ_cd LIKE '%DED%' THEN 'DEDICATED'
             ELSE 'TRUCK'
        END) AS SHIPMODE,
/* Get the Name / Email of the related UserID who entered the change */
usr_t.NAME,
usr_T.EMAL

FROM   (fuel_surcharge_price_r 
       INNER JOIN fuel_surcharge_type_r 
               ON fuel_surcharge_price_r.fuel_schg_typ_cd = 
                  fuel_surcharge_type_r.fuel_schg_typ_cd) 
       LEFT JOIN usr_t 
              ON fuel_surcharge_type_r.updt_usr_cd = usr_t.usr_cd
WHERE  (
( ( fuel_surcharge_price_r.efct_dt ) <= CURRENT_DATE ) and 
( EXTRACT(YEAR FROM fuel_surcharge_price_r.efct_dt ) = EXTRACT(YEAR FROM CURRENT_DATE ) )
) 
ORDER  BY fuel_surcharge_price_r.efct_dt, 
          fuel_surcharge_type_r.fuel_schg_typ_desc;