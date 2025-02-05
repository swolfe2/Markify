/*
This replicates the data from the flat file (or at least as close as possible),
gets data from Snowflake for Active Directory data
*/
SELECT DISTINCT GETDATE() AS AddedOn,
	GETDATE() AS UpdatedOn,
	CASE 
		WHEN w.STATUS = 'Active'
			THEN 'True'
		ELSE 'False'
		END AS Enabled,
	CONCAT (
		w.PREFERRED_LAST_NAME,
		', ',
		w.PREFERRED_FIRST_NAME
		) AS DisplayName,
	CONCAT (
		w.PREFERRED_FIRST_NAME,
		' ',
		w.PREFERRED_LAST_NAME
		) AS DisplayNameProper,
	w.PREFERRED_FIRST_NAME AS FirstName,
	w.PREFERRED_LAST_NAME AS LastName,
	w.LOCATION_MUNICIPALITY AS City,
	w.LOCATION_NAME AS OfficeLocation,
	w.LOCATION_COUNTRY_TWODIGIT_ISO AS CountryCode,
	w.REGION_HIERARCHY_COUNTRY AS CountryName,
	w.NTID AS UserID,
	LOWER(w.WORK_EMAIL) AS UserPrincipalName,
	LOWER(w.WORK_EMAIL) AS Email,
	w.EMPLOYEE_ID AS EmployeeNumber,
	w.POSITION_TITLE AS Title,
	w.JOB_CATEGORY AS JobCategory,
	w.REGION_HIERARCHY_REGION AS Region,
	w.LOCATION_COUNTRY_NAME AS PayRollCountry,
	w.BUSINESS_SECTOR AS Division,
	w.SUPERVISORY_ORGANIZATION AS Department,
	w.COST_CENTER AS CostCenter,
	w.WORKER_TYPE AS EmployeeType,
	w.MANAGER_NTID AS Manager,
	w.MANAGER_EMAIL AS ManagerMail,
	NULL AS HomeDirectory,
	w.MANAGEMENT_LEVEL AS ManagementLevel,
	w.MANAGER_NTID_LEVEL_1 AS Level1UserID,
	w.MANAGER_NTID_LEVEL_2 AS Level2UserID,
	w.MANAGER_NTID_LEVEL_3 AS Level3UserID,
	w.MANAGER_NTID_LEVEL_4 AS Level4UserID,
	w.MANAGER_NTID_LEVEL_5 AS Level5UserID,
	w.MANAGER_NTID_LEVEL_6 AS Level6UserID,
	w.MANAGER_NTID_LEVEL_7 AS Level7UserID,
	w.MANAGER_NTID_LEVEL_8 AS Level8UserID,
	w.MANAGER_NTID_LEVEL_9 AS Level9UserID,
	w.MANAGER_NTID_LEVEL_10 AS Level10UserID,
	w.MANAGER_LEVEL_1 AS Level1Displayname,
	w.MANAGER_LEVEL_2 AS Level2Displayname,
	w.MANAGER_LEVEL_3 AS Level3Displayname,
	w.MANAGER_LEVEL_4 AS Level4Displayname,
	w.MANAGER_LEVEL_5 AS Level5Displayname,
	w.MANAGER_LEVEL_6 AS Level6Displayname,
	w.MANAGER_LEVEL_7 AS Level7Displayname,
	w.MANAGER_LEVEL_8 AS Level8Displayname,
	w.MANAGER_LEVEL_9 AS Level9Displayname,
	w.MANAGER_LEVEL_10 AS Level10Displayname
FROM WORKDAY.STAGING.WORKER w
WHERE w.STATUS = 'Active'
	AND w.NTID IN (
		'J13595',
		'U15405'
		)