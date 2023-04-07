SELECT
inc.number AS INC_NUMBER,
'https://kcc.service-now.com/nav_to.do?uri=incident.do?sysparm_query=number=' + inc.number AS url,
inc.u_impacted_region,
inc.dv_state,
inc.dv_priority,
inc.category,
inc.subcategory,
inc.dv_opened_by,
inc.dv_u_opened_for,
inc.dv_u_origin,
inc.contact_type,
inc.opened_at,
CAST(inc.opened_at AS DATE) AS "Opened Date",
first_worked.claimed_on,
first_worked.[Claimed Date],
inc.sys_updated_on, 
CAST(inc.sys_updated_on AS DATE) AS "Updated Date",
inc.closed_at,
CAST(inc.closed_at AS DATE) AS "Closed Date",
inc.dv_resolved_by,
inc.close_code,
inc.close_notes AS "Close Notes",
inc.dv_cmdb_ci,
inc.dv_short_description

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
        INNER JOIN  SNOWMIRROR.dbo.incident inc ON mi.id = inc.sys_id
        WHERE mi.[table] = 'incident'
        AND mi.field = 'incident_state'
        AND mi.value in ('Active', 'Resolved', 'Closed')
        /*AND inc.number = 'INC7443598'*/
        AND inc.dv_assignment_group IN (
        'BI-SUPPORT-TML'
        )
        AND YEAR(inc.sys_created_on) >= YEAR(
            GETDATE()
            ) -1
        ) first_worked
    WHERE first_worked.RowRank = 1
)first_worked ON first_worked.task_effective_number =  inc.number

WHERE inc.dv_assignment_group = 'BI-SUPPORT-TML'
AND YEAR(inc.sys_created_on) >= YEAR(
            GETDATE()
            ) -1
/*AND SELECT * FROM SNOWMIRROR.dbo.incident inc WHERE inc.number = 'INC7443598'*/