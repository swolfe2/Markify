USE [USCTTDEV]
GO
/****** Object:  StoredProcedure [dbo].[sp_AAO]    Script Date: 11/5/2019 5:12:08 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Steve Wolfe, steve.wolfe@kcc.com, Central Transportation Team
-- Create date: 10/25/2019
-- Last modified: 
-- Description:	Update USCTTDEV.dbo.tblBidAppLanes and USCTTDEV.dbo.tblBidAppRates with AAO information
-- =============================================

ALTER PROCEDURE [dbo].[sp_AAO]

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

/*
What is this file doing?

1) Update LaneID of tblLaneAAO to match, where there's a match on tblBidAppLanes
2) Update tblBidAppRates to AAO + Description where there's a match to tblLaneAAO
3) Update tblBidAppRates to AAO + Description where there's a match to tblLaneAAO to the Origin
4) Update tblBidAppRates to AAO + Description where there's a match to tblLaneAAO to the Destination
5) Update tblBidAppLanes if there's a match to the lane ID from Bid App Rates
*/

/*
Update LaneID to match USCTTDEV.dbo.tblBidAppLanes where the Lane matches
*/
UPDATE USCTTDEV.dbo.tblLaneAAO
SET LANEID =
            CASE
              WHEN bal.lane IS NOT NULL THEN bal.laneID
              ELSE NULL
            END
FROM USCTTDEV.dbo.tblLaneAAO laao
LEFT JOIN USCTTDEV.dbo.tblBidAppLanes bal
  ON bal.lane = laao.lanedescription

/*
UPDATE AAO on USCTTDEV.dbo.tblBidAppRates where lane matches tblLaneAAO
*/
UPDATE USCTTDEV.dbo.tblBidAppRates
SET AAO =
            CASE
              WHEN laao.laneid is not null then laao.aao + ' - ' + laao.[aao description]
              ELSE NULL
            END
FROM USCTTDEV.dbo.tblBidAppRates bar
LEFT JOIN USCTTDEV.dbo.tblLaneAAO laao on laao.laneid = bar.laneid
AND laao.[Carrier Service] = bar.SCAC

/*
Update AAO on USCTTDEV.dbo.tblBidAppRates where origin matches tblLaneAAO

SELECT * FROM USCTTDEV.dbo.tblBIdAppRates bar
INNER JOIN USCTTDEV.dbo.tblLaneAAO laao on laao.string = LEFT(bar.LANE,CHARINDEX('-',bar.LANE)-1)
AND laao.[carrier service] = bar.SCAC
AND laao.OriginDestination = 'Origin'
WHERE bar.AAO IS NULL
AND laao.laneid is null

SELECT LEFT(LANE,CHARINDEX('-',LANE)-1) as lefttrim, RIGHT(LANE,CHARINDEX('-',LANE)-1) as righttrim
*/

UPDATE USCTTDEV.dbo.tblBidAppRates
SET AAO = laao.aao + ' - ' + laao.[aao description]
FROM USCTTDEV.dbo.tblBidAppRates bar
INNER JOIN USCTTDEV.dbo.tblLaneAAO laao on laao.string = LEFT(bar.LANE,CHARINDEX('-',bar.LANE)-1)
AND laao.[carrier service] = bar.SCAC
AND laao.OriginDestination = 'Origin'
WHERE bar.AAO IS NULL
AND laao.laneid is null

/*
Update AAO on USCTTDEV.dbo.tblBidAppRates where origin matches tblLaneAAO

SELECT * FROM USCTTDEV.dbo.tblBIdAppRates bar
INNER JOIN USCTTDEV.dbo.tblLaneAAO laao on laao.string = RIGHT(LANE,CHARINDEX('-',LANE)-1)
AND laao.[carrier service] = bar.SCAC
AND laao.OriginDestination = 'Destination'
WHERE bar.AAO IS NULL
AND laao.laneid is null

SELECT LEFT(LANE,CHARINDEX('-',LANE)-1) as lefttrim, RIGHT(LANE,CHARINDEX('-',LANE)-1) as righttrim
*/

UPDATE USCTTDEV.dbo.tblBidAppRates
SET AAO = laao.aao + ' - ' + laao.[aao description]
FROM USCTTDEV.dbo.tblBidAppRates bar
INNER JOIN USCTTDEV.dbo.tblLaneAAO laao on laao.string = RIGHT(LANE,CHARINDEX('-',LANE)-1)
AND laao.[carrier service] = bar.SCAC
AND laao.OriginDestination = 'Destination'
WHERE bar.AAO IS NULL
AND laao.laneid is null

/*
Update USCTTDEV.dbo.tblBidApplanes where AAO is not null
SELECT * FROM USCTTDEV.dbo.tblBidApplanes where AAO is not null
*/
UPDATE USCTTDEV.dbo.tblBidAppLanes
SET AAO = CASE WHEN bar.aao is null then NULL else 'Y' END
FROM USCTTDEV.dbo.tblBidAppLanes bal
LEFT JOIN USCTTDEV.dbo.tblBidAppRates bar on bal.laneid = bar.LaneID

END