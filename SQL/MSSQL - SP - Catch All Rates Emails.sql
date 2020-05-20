USE [USCTTDEV]
GO
/****** Object:  StoredProcedure [dbo].[sp_CatchAllRatedLoads_Emails]    Script Date: 3/10/2020 8:00:35 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Thomas Fraser
-- Create date: March 4th, 2020
-- Description:	This program pulls current operational loads in tendered status or greater that has a catch all rate "rated", and sends an email to that exection analyst
-- =============================================
ALTER PROCEDURE [dbo].[sp_CatchAllRatedLoads_Emails]
	-- Add the parameters for the stored procedure here

AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

--set variables
DECLARE @xml NVARCHAR(MAX)
DECLARE @body NVARCHAR(MAX)
declare @counter int
declare @endCount int
declare @sendEmail nvarchar(100)


drop table if exists #tempDistinctEmail
drop table if exists #tempCatchAll

-- after dropping table, create new table in temp folder
create table #tempCatchAll
(
    carr_cd				nvarchar(100),
    srvc_cd				nvarchar(100),
    strd_dtt			datetime,
	status				nvarchar(100),
    ld_leg_id			int,
    frst_cty_name		nvarchar(100),
    frst_sta_cd			nvarchar(8),
    mile_dist			decimal(8,2),
    last_cty_name		nvarchar(100),
    last_sta_cd			nvarchar(8),
    last_pstl_cd		nvarchar(16),
	freightAuction		nvarchar(100),
    rate_cd				nvarchar(48),
    analyst_id			nvarchar(48),
    analyst_name		nvarchar(48),
    email				nvarchar(100),
    chrg_amt_dlr		decimal(10,2),
    chrg_cd				nvarchar(48)
)

--------------------------------------------------------------------------------------------------------------------------------
-- insert data from Oracle query. This query pulls:
-----------load leg detail that are currently rated on a catch all rate code (begins with "C")
-----------analyst information and email associated with shipping origin based on the caps table
--------------------------------------------------------------------------------------------------------------------------------
insert into #tempCatchAll
select * from openquery(najdaprd, '
SELECT
    carr_cd,
    srvc_cd,
    strd_dtt,
    stat_shrt_desc   AS status,
    l.ld_leg_id,
    frst_cty_name,
    frst_sta_cd,
    mile_dist,
    last_cty_name,
    last_sta_cd,
    last_pstl_cd,
    rfrc_num16       AS freightauction,
    rate_cd,
    ca.analyst_id,
    ca.analyst_name,
    CASE
        WHEN ca.team_group BETWEEN 1 AND 1.5 THEN
            ''West.CTT@kcc.com''
        WHEN ca.team_group = 1.5 THEN
            ''Inbound.Trans.Knoxville@kcc.com''
        WHEN ca.team_group BETWEEN 2 AND 2.5 THEN
            ''Northeast.CTT@kcc.com''
        WHEN ca.team_group BETWEEN 3 AND 3.5 THEN
            ''Southeast.CTT@kcc.com''
        ELSE
            ''Trans.Systems.Knox@kcc.com''
    END AS email,
    c.chrg_amt_dlr,
    c.chrg_cd
FROM
    najdaadm.load_leg_r                                                                                                         l
    INNER JOIN najdaadm.status_r                                                                                                           s ON l.cur_optlstat_id = s.stat_id
    LEFT JOIN (
        SELECT
            ld_leg_id,
            chrg_cd,
            chrg_amt_dlr,
            pymnt_amt_dlr
        FROM
            najdaadm.charge_detail_r
        WHERE
            crtd_dtt > sysdate - 60
            AND chrg_cd = ''ZSPT''
    ) c ON l.ld_leg_id = c.ld_leg_id
    LEFT JOIN najdaadm.abpp_otc_caps_analyst                                                                                              ca ON l.frst_shpg_loc_cd = ca.location_id
    LEFT JOIN najdaadm.usr_t                                                                                                              u ON lower(ca.analyst_id) = lower(u.usr_cd)
WHERE
    cur_optlstat_id IN (
        310,
        315,
        320,
        325,
        330
    )
    AND strd_dtt >= sysdate - 180
    AND eqmt_typ IN (
        ''53FT'',
        ''53IM'',
        ''53RT'',
        ''53HC'',
        ''53CT'',
        ''48FT'',
        ''48CT'',
        ''48HC''
    )
    AND frst_ctry_cd IN (
        ''USA'',
        ''CAN'',
        ''MEX''
    )
    AND last_ctry_cd IN (
        ''USA'',
        ''CAN'',
        ''MEX''
    )
    AND substr(rate_cd, 1, 1) = ''C''
    AND to_date > sysdate
    AND rfrc_num16 IS NULL
')
where
	chrg_cd is null


-- create a temporary table of distinct analysts and emails from the query above
create table #tempDistinctEmail
(
id				int	identity(1,1) primary key,
analyst_name	nvarchar(100),
email			nvarchar(100)
)

-- insert values from the query above into the newly created temp table
insert into #tempDistinctEmail
select distinct
	analyst_name,
	email
from
	#tempCatchAll

-- set the count to max of the auto increment id in the temp table, so that the while loop will know when to stop
select @endCount = max(id)
from #tempDistinctEmail;

-- gotta start somewhere
set @counter = 1

-- loop that pulls the data based on every single id associated with a unique analyst id and email, and sends an email to that analyst
while @counter <= @endCount --this starts at one, and while less than or equal to the max id in the distinct email table, loop will continue
begin
	-- creating an xml table to be used in html formatted email- this joins the data table and distinct analyst table where the id matches the @counter
	SET @xml = CAST(( SELECT carr_cd AS 'td','',srvc_cd AS 'td','', strd_dtt AS 'td','', status AS 'td','', ld_leg_id as 'td','', frst_cty_name as 'td','',
		frst_sta_cd as 'td','',mile_dist as 'td','',last_cty_name as 'td','', last_sta_cd as 'td','', last_pstl_cd as 'td','', rate_cd as 'td','',
		analyst_id as 'td','', #tempCatchAll.analyst_name as 'td','', #tempCatchAll.email as 'td','', chrg_amt_dlr as 'td','', chrg_cd as 'td','', freightAuction as 'td',''
	FROM #tempCatchAll
	INNER JOIN
		#tempDistinctEmail
	ON
		#tempCatchAll.analyst_name = #tempDistinctEmail.analyst_name
	WHERE
		#tempDistinctEmail.id = @counter
	ORDER BY ld_leg_id 
	FOR XML PATH('tr'), ELEMENTS ) AS NVARCHAR(MAX))

	-- pull the email associated with that specific id
	select @sendEmail = email from #tempDistinctEmail where id = @counter

	-- create a body variable that houses the HTML code used to make a table of the data
	SET @body ='<html><body><H3>Catch All Loads Pending</H3>
	<table border = 1> 
	<tr>
	<th> Carrier </th> <th> SCAC </th> <th> Start Date </th> <th> TM Status </th> <th> Load ID </th> <th> Origin City </th> <th> Origin State </th>
	<th> Miles </th> <th> Final City </th> <th> Final State </th> <th> Final Zip </th> <th> Rate Code </th> <th> Analyst ID </th> <th> Analyst </th> <th> Email </th>
	<th> Charge Amount </th> <th> Charge Code </th> <th> Freight Auction </th></tr>'    

	-- add the xml data into the body variable table template, and use closing html tags
	SET @body = @body + @xml +'</table></body></html>'

	-- send the email based on the email stored procedure
	EXEC msdb.dbo.sp_send_dbmail
	@profile_name = 'Transportation Analytics and Reporting - KCNA', -- replace with your SQL Database Mail Profile 
	@reply_to = 'Trans.Systems.Knox@kcc.com',
	@copy_recipients = 'Trans.Systems.Knox@kcc.com',
	@body = @body,
	@body_format ='HTML',
	@recipients = @sendEmail, -- replace with your email address
	@subject = 'Loads Currently on Catch All Rates'

	set @counter = @counter + 1 --add one to the counter, so it will restart the loop until it reaches the max(id)
end


-- drop the tables like it's yo job
drop table if exists #tempDistinctEmail
drop table if exists #tempCatchAll


END
