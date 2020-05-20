SELECT
    bal.orig_city_state,
    bal.dest_city_state,
    bal.commodity,
    bal.equipment,
    bal.miles,
    bal.bid_loads,
    bal.updated_loads,
    bal.historical_loads,
    bal.fmic,
    bal.comment,
    bal.origin,
    SUBSTRING(bal.Origin, 1, CHARINDEX(', ', bal.Origin) - 1) OriginCity,
    SUBSTRING(bal.Origin, CHARINDEX(', ', bal.Origin) + 2, LEN(bal.Origin)) OriginState,
    bal.dest,
    SUBSTRING(bal.Dest, 1, CHARINDEX(', ', bal.Dest) - 1) DestCity,
    SUBSTRING(bal.Dest, CHARINDEX(', ', bal.Dest) + 2, LEN(bal.Dest)) DestState,
    bal.primarycustomer,
    bal.[order type],
    bal.laneid,
    bal.effectivedate LaneEff,
    bal.expirationdate LaneExp,
    bar.scac,
    bar.mode,
    bar.ly_vol,
    bar.ly_rpm,
    bar.bid_rpm,
    bar.award_pct,
    bar.award_lds,
    bar.active_flag,
    bar.comment,
    bar.confirmed,
    bar.service,
    bar.effectivedate CarrEff,
    bar.expirationdate CarrExp,
    bar.reason,
    bar.[rate per mile],
    bar.[min charge],
    bar.cur_rpm,
    bar.rank_num,
    ra.region,
    ra.carriermanager,
        CASE WHEN bal.[order type] = 'INBOUND' THEN
        SUBSTRING(bal.Dest, CHARINDEX(', ', bal.Dest) + 2, LEN(bal.Dest))
        ELSE
        SUBSTRING(bal.Origin, CHARINDEX(', ', bal.Origin) + 2, LEN(bal.Origin))
    END AS JoinState
FROM
    USCTTDEV.dbo.tblbidapplanes AS bal
    INNER JOIN USCTTDEV.dbo.tblbidapprates AS bar
    ON ( bal.equipment = bar.equipment )
        AND ( bal.dest_city_state = 
                      bar.dest_city_state )
        AND ( bal.orig_city_state = 
                      bar.orig_city_state )
    INNER JOIN USCTTDEV.dbo.tblRegionalAssignments AS ra
    ON ( ra.StateAbbv = 
    CASE WHEN bal.[order type] = 'INBOUND' THEN
        SUBSTRING(bal.Dest, CHARINDEX(', ', bal.Dest) + 2, LEN(bal.Dest))
        ELSE
        SUBSTRING(bal.Origin, CHARINDEX(', ', bal.Origin) + 2, LEN(bal.Origin))
    END)

ORDER  BY bal.orig_city_state, 
          bal.dest_city_state, 
          bar.rank_num; 