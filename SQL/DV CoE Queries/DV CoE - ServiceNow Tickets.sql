/*
Updated by Antonio on 10/29/2025
*/
-- RITM/SC_TASK Section
    SELECT 
      task.task_effective_number AS [Task Number],
      req.dv_request AS [REQ Number], 
      req.task_effective_number AS [RITM], 
      'https://kcc.service-now.com/nav_to.do?uri=sc_req_item.do?sysparm_query=number=' + req.task_effective_number AS RITM_url,
      'https://kcc.service-now.com/nav_to.do?uri=sc_task.do?sysparm_query=number=' + task.task_effective_number AS url,
      req.dv_stage AS [REQ Stage], 
      CASE WHEN task.closed_at IS NOT NULL 
        AND req.dv_stage IN ('Fulfillment', 'Completed') THEN 'Closed Successful' 
        ELSE task.dv_state END AS [REQ State], 
      CASE WHEN 
        CASE WHEN task.closed_at IS NOT NULL 
          AND req.dv_stage IN ('Fulfillment', 'Completed') THEN 'Closed Successful' 
          ELSE task.dv_state END LIKE '%Closed%' THEN 'Closed' ELSE 'Open'
      END AS [REQ Status],
      req.dv_cat_item AS [REQ Type], 
      req.dv_configuration_item AS [Platform Type], 
      CASE WHEN req.short_description LIKE '%CITRIX%' THEN 'Citrix' ELSE 'Desktop' END AS [Computer Type], 
      req.short_description, 
TRIM(
  CASE 
    WHEN req.description LIKE '%Requested for:%' THEN
      /* Normalize line breaks once per expression */
      CASE 
        /* Detect the new format: at least two '-' after 'Requested for: ' */
        WHEN 
          CHARINDEX(
            '-', 
            REPLACE(REPLACE(req.description, CHAR(13), ''), CHAR(10), ''), 
            CHARINDEX('Requested for: ', REPLACE(REPLACE(req.description, CHAR(13), ''), CHAR(10), '')) 
            + LEN('Requested for: ')
          ) > 0
          AND
          CHARINDEX(
            '-', 
            REPLACE(REPLACE(req.description, CHAR(13), ''), CHAR(10), ''), 
            CHARINDEX(
              '-', 
              REPLACE(REPLACE(req.description, CHAR(13), ''), CHAR(10), ''), 
              CHARINDEX('Requested for: ', REPLACE(REPLACE(req.description, CHAR(13), ''), CHAR(10), '')) 
              + LEN('Requested for: ')
            ) + 1
          ) > 0
        THEN
          /* Extract between first '-' and second '-' after 'Requested for: ' */
          LTRIM(RTRIM(
            SUBSTRING(
              REPLACE(REPLACE(req.description, CHAR(13), ''), CHAR(10), ''),
              /* start = pos after first '-' */
              CHARINDEX(
                '-', 
                REPLACE(REPLACE(req.description, CHAR(13), ''), CHAR(10), ''), 
                CHARINDEX('Requested for: ', REPLACE(REPLACE(req.description, CHAR(13), ''), CHAR(10), '')) 
                + LEN('Requested for: ')
              ) + 1,
              /* len = (second '-' pos) - (start) */
              CHARINDEX(
                '-', 
                REPLACE(REPLACE(req.description, CHAR(13), ''), CHAR(10), ''), 
                CHARINDEX(
                  '-', 
                  REPLACE(REPLACE(req.description, CHAR(13), ''), CHAR(10), ''), 
                  CHARINDEX('Requested for: ', REPLACE(REPLACE(req.description, CHAR(13), ''), CHAR(10), '')) 
                  + LEN('Requested for: ')
                ) + 1
              )
              - (
                CHARINDEX(
                  '-', 
                  REPLACE(REPLACE(req.description, CHAR(13), ''), CHAR(10), ''), 
                  CHARINDEX('Requested for: ', REPLACE(REPLACE(req.description, CHAR(13), ''), CHAR(10), '')) 
                  + LEN('Requested for: ')
                ) + 1
              )
            )
          ))
        ELSE
          /* Fallback to old format: take everything after 'Requested for: ' */
          LTRIM(RTRIM(
            SUBSTRING(
              REPLACE(REPLACE(req.description, CHAR(13), ''), CHAR(10), ''),
              CHARINDEX('Requested for: ', REPLACE(REPLACE(req.description, CHAR(13), ''), CHAR(10), '')) 
              + LEN('Requested for: '),
              4000
            )
          ))
      END
    ELSE 
      req.dv_opened_by
  END
) AS [REQ For],
      task.dv_assigned_to,   
      req.opened_at, 
      CAST(req.opened_at AS DATE) AS [Opened Date],  
      first_worked.claimed_on,
      first_worked.[Claimed Date],
      req.sys_updated_on, 
      CAST(req.sys_updated_on AS DATE) AS [Updated Date],
      CASE WHEN task.closed_at IS NOT NULL THEN task.closed_at ELSE req.closed_at END AS closed_at,
      CAST(CASE WHEN task.closed_at IS NOT NULL THEN task.closed_at ELSE req.closed_at END AS DATE) AS [Closed Date],
      NULL AS [Close Notes]
    FROM SNOWMIRROR.dbo.sc_req_item req 
    INNER JOIN (
      SELECT * FROM (
        SELECT 
          task.*, 
          ROW_NUMBER() OVER (
            PARTITION BY task.dv_request_item 
            ORDER BY task.sys_created_on ASC
          ) AS RowRank 
        FROM SNOWMIRROR.dbo.sc_task task 
        WHERE task.dv_assignment_group IN ('DATAVIZ-SME-KC', 'TABLEAU-SME-KC')
          AND YEAR(task.sys_created_on) >= YEAR(GETDATE()) - 1
      ) task 
      WHERE task.RowRank = 1
    ) task ON task.dv_request_item = req.task_effective_number 
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
          ROW_NUMBER() OVER (
            PARTITION BY task.task_effective_number 
            ORDER BY mi.sys_created_on ASC
          ) AS RowRank
        FROM SNOWMIRROR.dbo.metric_instance AS mi
        INNER JOIN SNOWMIRROR.dbo.sc_task task ON mi.id = task.sys_id
        WHERE mi.[table] = 'sc_task'
          AND mi.field = 'state'
          AND mi.value <> 'open'
          AND task.dv_assignment_group IN ('DATAVIZ-SME-KC', 'TABLEAU-SME-KC')
          AND YEAR(task.sys_created_on) >= YEAR(GETDATE()) - 1
      ) first_worked
      WHERE first_worked.RowRank = 1
    ) first_worked ON first_worked.task_effective_number = task.task_effective_number
    WHERE req.dv_assignment_group IN ('DATAVIZ-SME-KC', 'TABLEAU-SME-KC') 
      AND YEAR(req.opened_at) >= YEAR(GETDATE()) - 1

    UNION ALL

    -- INCIDENT Section
    SELECT 
      inc.number AS [Task Number],
      inc.number AS [REQ Number],
      inc.number AS [RITM],
      'https://kcc.service-now.com/nav_to.do?uri=incident.do?sysparm_query=number=' + inc.number AS RITM_url,
      'https://kcc.service-now.com/nav_to.do?uri=incident.do?sysparm_query=number=' + inc.number AS url,
      CASE WHEN inc.dv_state LIKE '%Closed%' THEN 'Completed' 
            WHEN inc.dv_state LIKE '%Resolved%' THEN 'Completed'
            WHEN first_worked.claimed_on IS NULL THEN 'Open'
            ELSE 'Pending' END AS [REQ Stage],
      CASE WHEN inc.dv_state LIKE '%Closed%' THEN 'Closed Successful' 
            WHEN inc.dv_state LIKE '%Resolved%' THEN 'Closed Successful' 
            ELSE inc.dv_state END AS [REQ State],
      CASE WHEN inc.dv_state LIKE '%Closed%' THEN 'Closed' 
            WHEN inc.dv_state LIKE '%Resolved%' THEN 'Closed'
            ELSE 'Open' END AS [REQ Status],
      inc.dv_cmdb_ci + ' Service Request' AS [REQ Type],
      inc.dv_cmdb_ci AS [Platform Type],
      'Incident' AS [Computer Type],
      inc.dv_short_description AS [short_description],
      inc.dv_u_opened_for AS [REQ For],
      inc.dv_assigned_to,
      inc.opened_at,
      CAST(inc.opened_at AS DATE) AS [Opened Date],
      first_worked.claimed_on,
      first_worked.[Claimed Date],
      inc.sys_updated_on,
      CAST(inc.sys_updated_on AS DATE) AS [Updated Date],
      inc.closed_at,
      CAST(inc.closed_at AS DATE) AS [Closed Date],
      inc.close_notes AS [Close Notes]
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
          ROW_NUMBER() OVER (
            PARTITION BY inc.task_effective_number 
            ORDER BY mi.sys_created_on ASC
          ) AS RowRank
        FROM SNOWMIRROR.dbo.metric_instance AS mi
        INNER JOIN SNOWMIRROR.dbo.incident inc ON mi.id = inc.sys_id AND mi.value IS NOT NULL
        WHERE mi.[table] = 'incident'
          AND mi.field = 'incident_state'
          AND mi.value NOT IN ('New', 'Open')
          AND inc.dv_assignment_group IN ('TABLEAU-SME-KC', 'DATAVIZ-SME-KC')
          AND YEAR(inc.sys_created_on) >= YEAR(GETDATE()) - 1
      ) first_worked
      WHERE first_worked.RowRank = 1
    ) first_worked ON first_worked.task_effective_number = inc.number
    WHERE inc.dv_assignment_group IN ('TABLEAU-SME-KC', 'DATAVIZ-SME-KC')
      AND YEAR(inc.sys_created_on) >= YEAR(GETDATE()) - 1