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
  req.sys_updated_on, 
  CAST(req.sys_updated_on AS DATE) AS "Updated Date",
  CASE WHEN task.closed_at IS NOT NULL THEN task.closed_at ELSE req.closed_at END AS closed_at,
  CAST(CASE WHEN task.closed_at IS NOT NULL THEN task.closed_at ELSE req.closed_at END AS DATE) AS "Closed Date",
  task.close_notes AS "Close Notes",
  req.requested_for,
  u.email,
  u.user_name,
  item.value,
  item.dv_item_option_new

FROM SNOWMIRROR.dbo.sc_req_item req
LEFT JOIN SNOWMIRROR.dbo.sys_user AS u ON u.sys_id = req.requested_for
INNER JOIN SNOWMIRROR.dbo.sc_item_option_mtom AS mtom ON mtom.request_item = req.sys_id
INNER JOIN sc_item_option AS item ON item.sys_id = mtom.sc_item_option
INNER JOIN item_option_new AS itemdef ON itemdef.sys_id = item.item_option_new
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
WHERE req.dv_assignment_group IN (
'DATAVIZ-SME-KC', 'TABLEAU-SME-KC'
) 
AND YEAR(req.opened_at) >= YEAR(
GETDATE()
) -1
AND req.dv_cat_item = 'Tableau License'
AND item.dv_item_option_new = 'Business Cost Center'

-- SELECT * 
-- FROM SNOWMIRROR.dbo.sc_req_item req 
-- INNER JOIN SNOWMIRROR.dbo.sys_user AS u ON u.sys_id = req.requested_for
-- WHERE req.dv_request = 'REQ0698157'
