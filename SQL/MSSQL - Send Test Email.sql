-- Send test email
EXEC msdb.dbo.sp_send_dbmail  
    @profile_name = 'Transportation Analytics and Reporting - KCNA',  
    @recipients = 'steve.wolfe@kcc.com',  
    @body = 'The stored procedure finished successfully.',  
    @subject = 'Automated Success Message' ;  
-- Get History of Failed Items
-- select * from msdb.dbo.sysmail_faileditems