/*
Segment & ABU
*/
WITH Segment AS (
    SELECT *
    FROM (VALUES
        ('Enterprise Data'),
        ('North America'),
        ('International Personal Care (IPC)'),
        ('Enterprise Markets'),
        ('International Family Care & Professional (IFP)')
    ) AS v(SegmentName)
), 
AccountableABU AS (
    SELECT *
    FROM (VALUES
        ('Anz'),
        ('Asia'),
        ('Brazil'),
        ('Common'),
        ('Consumer'),
        ('Customer'),
        ('EMEA'),
        ('Greater China'),
        ('Indonesia'),
        ('Korea'),
        ('LATAM'),
        ('Material'),
        ('Product'),
        ('Professional'),
        ('SEA'),
        ('Supplier'),
        ('UKI')
    ) AS v(AccountableABUName)
)
SELECT 
    ROW_NUMBER() OVER (ORDER BY SegmentName, AccountableABUName) AS ID,
    SegmentName, 
    AccountableABUName
FROM Segment
FULL OUTER JOIN AccountableABU ON 1=1
ORDER BY SegmentName, AccountableABUName

/*
Segment, ABU, and Function
*/
WITH Segment AS (
    SELECT *
    FROM (VALUES
        ('Enterprise Data'),
        ('North America'),
        ('International Personal Care (IPC)'),
        ('Enterprise Markets'),
        ('International Family Care & Professional (IFP)')
    ) AS v(SegmentName)
), 
AccountableABU AS (
    SELECT *
    FROM (VALUES
        ('Anz'),
        ('Asia'),
        ('Brazil'),
        ('Common'),
        ('Consumer'),
        ('Customer'),
        ('EMEA'),
        ('Greater China'),
        ('Indonesia'),
        ('Korea'),
        ('LATAM'),
        ('Material'),
        ('Product'),
        ('Professional'),
        ('SEA'),
        ('Supplier'),
        ('UKI')
    ) AS v(AccountableABUName)
),
GlobalFunction AS (
    SELECT *
    FROM (VALUES
        ('Growth - Commercial'),
        ('Growth - Marketing'),
        ('Research & Development'),
        ('Supply Chain'),
        ('Finance'),
        ('Human Resources'),
        ('Legal'),
        ('Digital Technology Solutions'),
        ('Not Applicable')
    ) AS v(GlobalFunctionName)
)
SELECT 
    ROW_NUMBER() OVER (ORDER BY SegmentName, AccountableABUName, GlobalFunctionName) AS ID,
    SegmentName, 
    AccountableABUName, 
    GlobalFunctionName
FROM Segment
FULL OUTER JOIN AccountableABU ON 1=1
FULL OUTER JOIN GlobalFunction ON 1=1
ORDER BY SegmentName, AccountableABUName, GlobalFunctionName;