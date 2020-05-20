SELECT data.*, 
    CASE WHEN TRY_CONVERT(NUMERIC, data.NewValue) IS NULL   
    THEN 'Cast failed'  
    ELSE 'Cast succeeded'  
END AS Result
/*,CASE WHEN data.NewValue = data.AWARD_PCT THEN 'MATCH' ELSE 'NO MATCH' END AS Test*/



/*, CASE WHEN data.NewValue = data.AWARD_PCT THEN 'MATCH' ELSE 'NO MATCH' END AS Test */FROM (
SELECT bacl.ID, 
bacl.LaneID, 
bacl.Lane, 
bacl.ChangeType, 
bacl.ChangeReason, 
bacl.SCAC, 
bacl.PreviousValue, 
bacl.NewValue,
/*awards.Award_PCT,*/
CASE WHEN CAST (awards.AWARD_PCT AS float) > 0 THEN CAST (awards.AWARD_PCT AS float) ELSE 0 END AS AWARD_PCT, 
bacl.UpdatedBy, 
bacl.UpdatedByName,
bacl.UpdatedOn
FROM USCTTDEV.dbo.tblBidAppChangelog bacl

INNER JOIN(
SELECT DISTINCT LaneID, Lane, SCAC, MAX(ID) AS MaxID
FROM USCTTDEV.dbo.tblBidAppChangelog
WHERE Field = 'AWARD_PCT'
GROUP BY LaneID, Lane, SCAC) maxID ON maxID.MaxID = bacl.ID

INNER JOIN (
SELECT DISTINCT bar.LaneID, bar.Lane, bar.SCAC, bar.AWARD_PCT, bal.UPDATED_LOADS
FROM USCTTDEV.dbo.tblBidAppRates bar
INNER JOIN USCTTDEV.dbo.tblBidAppLanes bal ON bal.laneID = bar.LaneID
/*WHERE lane = 'TXPARIS-5TN38118'*/
) awards ON awards.LaneID = bacl.LaneID
AND awards.SCAC = bacl.SCAC

WHERE awards.UPDATED_LOADS > 0

/*WHERE bacl.Lane = 'TXPARIS-5TN38118'*/
) data


WHERE CAST(data.AWARD_PCT AS NVARCHAR(MAX)) <> data.NewValue


ORDER BY data.NewValue, data.Lane ASC, data.ID DESC

SELECT * FROM USCTTDEV.dbo.tblBidAppLanes where UPDATED_LOADS = 0

SELECT * FROM USCTTDEV.dbo.tblBidAppChangelog
WHERE FIELD = 'UPDATED_LOADS'
AND NewValue = '0'
