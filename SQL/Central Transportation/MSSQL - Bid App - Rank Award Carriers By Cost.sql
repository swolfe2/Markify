--Drop the table out if it already exists in the tempdb
DROP TABLE IF EXISTS #tblCarrierRankings

--Create the temp table, with only the fields needed for updating
CREATE TABLE #tblCarrierRankings(
	ID INT,
	LaneID INT,
	Service NVARCHAR(255),
	EquipType NVARCHAR(255),
	RPM DECIMAL(18, 9),
	AwardPCT DECIMAL(18,9),
	Rank NVARCHAR(255)
)

--Insert values into Temp Table
INSERT INTO #tblCarrierRankings
SELECT
    DISTINCT
    ac.ID,
    ac.LaneID,
    ac.Service,
    ac.EquipType,
    ac.RPM,
	ac.AwardPCT,
RANK() OVER(PARTITION BY LaneID, EquipType ORDER BY AwardPCT DESC, AwardRPM Asc, MinCharge ASC) AS Rank
FROM
    [USCTTDEV].[dbo].tblAwardCarr ac
--WHERE (((ac.[LaneID])=149))

ORDER BY EquipType, AwardPCT Asc, Rank ASC;

--View results from temp table
Select * from #tblCarrierRankings order by LaneID ASC 

--Set carrier rankings
UPDATE t1
set t1.Rank = t2.Rank
FROM [USCTTDEV].[dbo].[tblAwardCarr] t1
INNER JOIN #tblCarrierRankings as t2
ON t1.id = t2.id;

--Set carrier rankings
--View results from temp table
Select * from [USCTTDEV].[dbo].[tblAwardCarr]