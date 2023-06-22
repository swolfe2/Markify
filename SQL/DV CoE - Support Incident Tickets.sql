SELECT 
inc.number AS "Incident Number",
'https://kcc.service-now.com/nav_to.do?uri=incident.do?sysparm_query=number=' + inc.number AS "Incident URL",
inc.u_impacted_region AS "Incident Region",
inc.dv_state AS "Incident State",
inc.dv_priority AS "Incident Priority",
inc.category AS "Incident Category",
inc.subcategory AS "Incident Subcategory",
inc.dv_opened_by AS "Incident Opened By",
inc.dv_u_opened_for AS "Incident Opened For",
inc.dv_u_origin AS "Incident Origin",
inc.contact_type AS "Incident Contact Type",
inc.opened_at AS "Incident Opened At",
CAST(inc.opened_at AS DATE) AS "Incident Opened Date",
first_worked.claimed_on AS "Incident Claimed On",
first_worked.[Claimed Date] "Incident Claimed On Date",
inc.sys_updated_on AS "Incident Updated On", 
CAST(inc.sys_updated_on AS DATE) AS "Incident Updated Date",
inc.closed_at AS "Incident Closed At",
CAST(inc.closed_at AS DATE) AS "Incident Closed Date",
inc.dv_resolved_by AS "Incident Resolved By",
inc.close_code AS "Incident Close Code",
inc.close_notes AS "Incident Close Notes",
inc.dv_cmdb_ci AS "Incident Configuration Item",
inc.dv_short_description AS "Incident Short Description"

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