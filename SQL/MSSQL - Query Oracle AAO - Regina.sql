SELECT
    DISTINCT
    ac.id,
    ac.laneid,
    ac.service,
    ac.equiptype,
    ac.rpm,
        Str(((SELECT
        Count(*)
    FROM
        [USCTTDEV].[dbo].tblAwardCarr AS ac2
    WHERE  
    ac.RPM > ac2.RPM 
        AND ac.EquipType = ac2.EquipType
        AND ac.laneid = ac2.laneid)+1)) AS Rank
FROM
    [USCTTDEV].[dbo].tblAwardCarr ac
WHERE (((ac.[LaneID])=149))

ORDER BY equiptype, rank ASC
;