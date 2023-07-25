
/*
Drop the table if it exists
*/
DROP TABLE IF EXISTS ##tblLaneCustomerTemp

/*
Create the temp table, full of customer rankings by lane
*/
SELECT DISTINCT ald.Lane, 
ald.CustomerHierarchy, 
COUNT(DISTINCT LD_LEG_ID) AS LoadCount,
ROW_NUMBER() OVER (PARTITION BY ald.Lane ORDER BY COUNT(DISTINCT LD_LEG_ID) DESC) AS RankNum
INTO ##tblLaneCustomerTemp
FROM USCTTDEV.dbo.tblActualLoadDetail ald
WHERE ald.SHPD_DTT >= GETDATE() - 180
AND ald.EQMT_TYP <> 'LTL'
GROUP BY ald.Lane,
ald.CustomerHierarchy

SELECT * FROM ##tblLaneCustomerTemp
WHERE Lane = 'WADUPONT-ABEDMONT'
ORDER BY RankNum ASC

/*
Get rid of all lines where the rank number is higher than 5
*/
DELETE FROM ##tblLaneCustomerTemp
WHERE RankNum > 5

/*
Update USCTTDEV.dbo.tblActualLoadDetail
*/
/*SELECT
   t1.Lane,
   Item = stuff((SELECT ( '; ' + CustomerHierarchy )
                       FROM ##tblLaneCustomerTemp t2
                      WHERE t1.Lane = t2.Lane
                      ORDER BY t2.RankNum ASC
                        FOR XML PATH( '' )
                    ), 1, 1, '' )FROM ##tblLaneCustomerTemp t1
WHERE t1.Lane = 'WADUPONT-ABEDMONT'
GROUP BY t1.Lane
*/
 
 SELECT 
 bal.Lane,
 bal.PrimaryCustomer,
 custs.Item
 FROM USCTTDEV.dbo.tblBidAppLanes bal
 INNER JOIN (
 SELECT
  t1.Lane,
   Item = stuff((SELECT ( '; ' + CustomerHierarchy )
                       FROM ##tblLaneCustomerTemp t2
                      WHERE t1.Lane = t2.Lane
                      ORDER BY t2.RankNum ASC
                        FOR XML PATH( '' )
                    ), 1, 1, '' )FROM ##tblLaneCustomerTemp t1
WHERE t1.Lane = 'WADUPONT-ABEDMONT'
GROUP BY t1.Lane
 ) custs ON custs.Lane = bal.Lane


