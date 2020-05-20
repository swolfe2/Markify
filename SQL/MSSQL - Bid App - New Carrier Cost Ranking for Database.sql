WITH RANK AS 
(
SELECT bal.orig_city_state,
bal.dest_city_state,
bar.mode,
bar.rank_num,
RANK() OVER(PARTITION BY bal.orig_city_state, bal.dest_city_state, bar.mode ORDER BY bar.award_pct DESC, bar.cur_rpm ASC, bar.service ASC, bar.confirmed ASC, bar.[min charge]) as Rank
FROM
    USCTTDEV.dbo.tblbidapplanes AS bal
    INNER JOIN USCTTDEV.dbo.tblbidapprates AS bar
    ON ( bal.equipment = bar.equipment )
        AND ( bal.dest_city_state = 
                      bar.dest_city_state )
        AND ( bal.orig_city_state = 
                      bar.orig_city_state )
)
UPDATE RANK 
SET RANK_NUM = Rank