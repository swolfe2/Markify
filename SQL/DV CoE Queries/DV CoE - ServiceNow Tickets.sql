SELECT 
  task.task_effective_number AS "Task Number",
  req.dv_request AS "REQ Number", 
  req.task_effective_number AS "RITM", 
  'https://kcc.service-now.com/nav_to.do?uri=sc_req_item.do?sysparm_query=number=' + req.task_effective_number AS RITM_url,
  'https://kcc.service-now.com/nav_to.do?uri=sc_task.do?sysparm_query=number=' + task.task_effective_number AS url,
  req.dv_stage AS "REQ Stage", 
  CASE WHEN task.closed_at IS NOT NULL 
  AND req.dv_stage IN ('Fulfillment', 'Completed') THEN 'Closed Successful' 
  ELSE task.dv_state END AS "REQ State", 
  /*
  Added 2/11/22 per Tonia
  Want to see overall Closed/Open status type
  */
  CASE WHEN 
    CASE WHEN task.closed_at IS NOT NULL 
    AND req.dv_stage IN ('Fulfillment', 'Completed') THEN 'Closed Successful' 
     ELSE task.dv_state END LIKE '%Closed%' THEN 'Closed' ELSE 'Open'
 END AS "REQ Status",
  req.dv_cat_item AS "REQ Type", 
  req.dv_configuration_item AS "Platform Type", 
  CASE WHEN req.short_description LIKE '%CITRIX%' THEN 'Citrix' ELSE 'Desktop' END AS "Computer Type", 
  req.short_description, 
  TRIM(
    CASE WHEN req.description LIKE '%Requested for: %' THEN REPLACE(
      REPLACE(
        REPLACE(
          req.description, 
          CHAR(13), 
          ''
        ), 
        CHAR(10), 
        ''
      ), 
      'Requested for: ', 
      ''
    ) ELSE req.dv_opened_by END
  ) AS "REQ For", 
  task.dv_assigned_to,   
  req.opened_at, 
  CAST(req.opened_at AS DATE) AS "Opened Date",  
  /*
  Added 3/7/2022 to get when ticket was first worked by someone in DV CoE
  */
  first_worked.claimed_on,
  first_worked.[Claimed Date],
  req.sys_updated_on, 
  CAST(req.sys_updated_on AS DATE) AS "Updated Date",
  CASE WHEN task.closed_at IS NOT NULL THEN task.closed_at ELSE req.closed_at END AS closed_at,
  CAST(CASE WHEN task.closed_at IS NOT NULL THEN task.closed_at ELSE req.closed_at END AS DATE) AS "Closed Date",
  task.close_notes AS "Close Notes"
  /*
  Commented out, will attempt text splitting in Power BI rather than T-SQL
  ,
  CASE WHEN task.close_notes LIKE '%{%' AND task.close_notes LIKE '%}%' THEN 
  UPPER(
    REPLACE(
        REPLACE(    
            REPLACE(
                SUBSTRING(
                    task.close_notes, 
                    CHARINDEX('{', task.close_notes) + 1, 
                    LEN(task.close_notes) - CHARINDEX('{', task.close_notes) - CHARINDEX('}', REVERSE(task.close_notes))
                ),
            '  ', ' '),
        '| ', '|'),
    ' |','|')
    )
    ELSE
        NULL
    END AS Categories*/



FROM 
  SNOWMIRROR.dbo.sc_req_item req 
  INNER JOIN (
    SELECT 
      * 
    FROM 
      (
        SELECT 
          task.*, 
          ROW_NUMBER() OVER (
            PARTITION BY task.dv_request_item 
            ORDER BY 
              task.sys_created_on ASC
          ) AS RowRank 
        FROM 
          SNOWMIRROR.dbo.sc_task task 
        WHERE 
          task.dv_assignment_group IN (
            'DATAVIZ-SME-KC', 'TABLEAU-SME-KC'
          )
          AND YEAR(task.sys_created_on) >= YEAR(
            GETDATE()
            ) -1
      ) task 
    WHERE 
      task.RowRank = 1
  ) task ON task.dv_request_item = req.task_effective_number 

/*
Added 3/7/2022 to get when ticket was first worked by someone in DV CoE
*/
LEFT JOIN (
SELECT first_worked.task_effective_number,
first_worked.sys_created_on AS claimed_on,
CAST(first_worked.sys_created_on AS DATE) AS [Claimed Date]
FROM (
SELECT 
task.task_effective_number,
mi.sys_updated_on,
mi.sys_created_on,
mi.value,
mi.field,
ROW_NUMBER() OVER (PARTITION BY task.task_effective_number ORDER BY mi.sys_created_on ASC) AS RowRank
FROM SNOWMIRROR.dbo.metric_instance AS mi
INNER JOIN SNOWMIRROR.dbo.sc_task task ON mi.id = task.sys_id
WHERE mi.[table] = 'sc_task'
AND mi.field = 'state'
AND mi.value <> 'open'
/*AND task.task_effective_number = 'TASK0545566'*/
AND
          task.dv_assignment_group IN (
            'DATAVIZ-SME-KC', 'TABLEAU-SME-KC'
          )
          AND YEAR(task.sys_created_on) >= YEAR(
            GETDATE()
            ) -1
) first_worked
WHERE first_worked.RowRank = 1
)first_worked ON first_worked.task_effective_number =  task.task_effective_number

WHERE 
  req.dv_assignment_group IN (
    'DATAVIZ-SME-KC', 'TABLEAU-SME-KC'
  ) 
  AND YEAR(req.opened_at) >= YEAR(
    GETDATE()
  ) -1
  /*AND task.task_effective_number = 'TASK0545566'*/
  /*AND task.close_notes LIKE '%{%'*/
  /*ORDER BY task.sys_updated_on DESC*/

/*
New 6/1/2023
Lih Shan discovered that there was an Service Request that was assigned to our team, rather than the default SC_TASK.
This will union any SRs that are assigned in the same ordinal position as the above query
*/
UNION ALL 

SELECT 
    sr.number AS "SR Number",
    sr.number AS "SR Number 2",
    sr.number AS "SR Number 3",
    'https://kcc.service-now.com/nav_to.do?uri=u_service_request.do?sysparm_query=number=' + sr.number AS RITM_url,
    'https://kcc.service-now.com/nav_to.do?uri=u_service_request.do?sysparm_query=number=' + sr.number AS url,
    CASE WHEN sr.dv_state LIKE '%Closed%' THEN 'Completed' 
        WHEN first_worked.claimed_on IS NULL then 'Open'
        ELSE 'Pending' END AS "SR Stage",
    sr.dv_state AS "SR State",
    CASE WHEN sr.dv_state LIKE '%Closed%' THEN 'Closed' else 'Open' END AS "SR Status",
    sr.dv_cmdb_ci + ' Service Request' AS "SR Type",
    sr.dv_cmdb_ci AS "Platform Type",
    'Service Request' AS "Computer Type",
    CASE WHEN sr.dv_u_category IS NULL THEN sr.dv_cmdb_ci + ' Service Request' 
    ELSE sr.dv_cmdb_ci + ' ' + sr.dv_u_category END AS "Short Description",
    sr.dv_u_requested_for AS "SR For",
    sr.dv_assigned_to,
    sr.opened_at,
    CAST(sr.opened_at AS DATE) AS "Opened Date",
    first_worked.claimed_on,
    first_worked.[Claimed Date],
    sr.sys_updated_on, 
    CAST(sr.sys_updated_on AS DATE) AS "Updated Date",
    sr.closed_at,
    CAST(sr.closed_at AS DATE) AS "Closed Date",
    sr.close_notes AS "Close Notes"

FROM 
    (
    SELECT 
        sr.*, 
        ROW_NUMBER() OVER (
        PARTITION BY sr.number
        ORDER BY 
            sr.sys_created_on ASC
        ) AS RowRank 
    FROM 
        SNOWMIRROR.dbo.u_service_request sr 
    
    WHERE 
        sr.dv_assignment_group IN (
        'DATAVIZ-SME-KC', 'TABLEAU-SME-KC'
        )
        AND YEAR(sr.sys_created_on) >= YEAR(
        GETDATE()
        ) -1
    ) sr 

    LEFT JOIN (
        SELECT first_worked.number,
        first_worked.sys_created_on AS claimed_on,
        CAST(first_worked.sys_created_on AS DATE) AS [Claimed Date]
        FROM (
        SELECT 
        sr.number,
        mi.sys_updated_on,
        mi.sys_created_on,
        mi.value,
        mi.field,
        ROW_NUMBER() OVER (PARTITION BY sr.number ORDER BY mi.sys_created_on ASC) AS RowRank
        FROM SNOWMIRROR.dbo.metric_instance AS mi
        INNER JOIN SNOWMIRROR.dbo.u_service_request sr ON mi.id = sr.sys_id
        WHERE mi.[table] = 'u_service_request'
        AND mi.field = 'state'
        AND mi.value <> 'open'
        /*AND task.task_effective_number = 'TASK0545566'*/
        AND
                sr.dv_assignment_group IN (
                    'DATAVIZ-SME-KC', 'TABLEAU-SME-KC'
                )
                AND YEAR(sr.sys_created_on) >= YEAR(
                    GETDATE()
                    ) -1
        ) first_worked
        WHERE first_worked.RowRank = 1
    )first_worked ON first_worked.number = sr.number

WHERE 
    sr.RowRank = 1

/*
New 6/1/2023
Lih Shan discovered that there was an Incident that was assigned to our team, rather than the default SC_TASK.
This will union any INCs that are assigned in the same ordinal position as the above query

Update 11/8/2023
If the state contains 'Resolved', then it is truly 'Closed Successful'
*/

UNION ALL

SELECT 
inc.number AS "INC Number",
inc.number AS "INC Number2",
inc.number AS "INC Number3",
'https://kcc.service-now.com/nav_to.do?uri=incident.do?sysparm_query=number=' + inc.number AS "Incident URL",
'https://kcc.service-now.com/nav_to.do?uri=incident.do?sysparm_query=number=' + inc.number AS "Incident URL2",
CASE WHEN inc.dv_state LIKE '%Closed%' THEN 'Completed' 
    WHEN inc.dv_state LIKE '%Resolved%' THEN 'Completed'
    WHEN first_worked.claimed_on IS NULL then 'Open'
    ELSE 'Pending' END AS "SR Stage",
CASE WHEN inc.dv_state LIKE '%Closed%' THEN 'Closed Successful' 
    WHEN inc.dv_state LIKE '%Resolved%' THEN 'Closed Successful' 
    ELSE inc.dv_state END AS "SR State",
CASE WHEN inc.dv_state LIKE '%Closed%' THEN 'Closed' 
    WHEN inc.dv_state LIKE '%Resolved%' THEN 'Closed'
    ELSE 'Open' END AS "SR Status",
inc.dv_cmdb_ci + ' Service Request' AS "SR Type",
inc.dv_cmdb_ci AS "Platform Type",
'Incident' AS "Computer Type",
inc.dv_short_description AS "Short Description",
inc.dv_u_opened_for AS "INC For",
inc.dv_assigned_to,
inc.opened_at,
CAST(inc.opened_at AS DATE) AS "Opened Date",
first_worked.claimed_on,
first_worked.[Claimed Date],
inc.sys_updated_on, 
CAST(inc.sys_updated_on AS DATE) AS "Updated Date",
inc.closed_at,
CAST(inc.closed_at AS DATE) AS "Closed Date",
inc.close_notes AS "Close Notes"

--SELECT TOP 10 inc.*
FROM SNOWMIRROR.dbo.incident inc
LEFT JOIN (
    SELECT first_worked.task_effective_number,
    first_worked.sys_created_on AS claimed_on,
    CAST(first_worked.sys_created_on AS DATE) AS [Claimed Date]
    FROM (
        SELECT 
        inc.task_effective_number,
        mi.sys_updated_on,
        mi.sys_created_on,
        mi.value,
        mi.field,
        ROW_NUMBER() OVER (PARTITION BY inc.task_effective_number ORDER BY mi.sys_created_on ASC) AS RowRank
        FROM SNOWMIRROR.dbo.metric_instance AS mi
        INNER JOIN  SNOWMIRROR.dbo.incident inc ON mi.id = inc.sys_id AND mi.value IS NOT NULL
        WHERE mi.[table] = 'incident'
        AND mi.field = 'incident_state'
        AND mi.value NOT IN ('New', 'Open')
        /*AND inc.number = 'INC7443598'*/
        AND inc.dv_assignment_group IN (
        'TABLEAU-SME-KC', 'DATAVIZ-SME-KC'
        )
        AND YEAR(inc.sys_created_on) >= YEAR(
            GETDATE()
            ) -1
        ) first_worked
    WHERE first_worked.RowRank = 1
)first_worked ON first_worked.task_effective_number =  inc.number

WHERE inc.dv_assignment_group IN (
        'TABLEAU-SME-KC', 'DATAVIZ-SME-KC'
        )
AND YEAR(inc.sys_created_on) >= YEAR(
            GETDATE()
            ) -1
/*AND SELECT * FROM SNOWMIRROR.dbo.incident inc WHERE inc.number = 'INC7443598'*/