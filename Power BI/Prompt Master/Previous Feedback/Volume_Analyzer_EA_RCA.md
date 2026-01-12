# Volume Analyzer EA - Refresh Failure Root Cause Analysis

## Executive Summary

The Power BI Service refresh for **Volume Analyzer EA** is failing due to **data quality issues and a type mismatch error** within the SAP HANA Calculation View `CV_SPFIC_VOLUME_ANALYZER_IP`. The root cause is in the underlying HANA view logic, not in Power BI.

---

## Error Messages Captured

### Primary Error (Power BI Service)
```
ODBC ERROR [S1000] [SAP AG] [LIBODBCHDB DLL] [HDBODBC] 
General error;303 invalid DATE, TIME or TIMESTAMP value: 
Cannot convert string '-01' to daydate
```

### Secondary Error (Diagnostic Query)
```
ODBC ERROR [S1000] General error;266 inconsistent datatype: 
[6970] Evaluator: type error in expression evaluator;
leftstr(string("CALWEEK"), 4) [here]<= int(leftstr(string(now()), 4)) + 1,
RGN::NA_CUSTOM:NA_TMV_IBP_FORECAST_SNAP (t 10068793),
object=RGN::NA_CUSTOM:NA_TMV_IBP_FORECAST_SNAP
```

---

## Root Cause Analysis

### Finding 1: Invalid CALWEEK Data in Source Table

The error message reveals that table `NA_TMV_IBP_FORECAST_SNAP` contains invalid `CALWEEK` values. The value `-01` (or similar malformed data) is causing date conversion failures.

**Expected CALWEEK format:** `YYYYWW` (e.g., `202601` for Week 1 of 2026)  
**Actual problematic value:** `-01` (missing year, invalid format)

### Finding 2: Type Mismatch in Calculation View Filter

The Calculation View contains a filter expression with a **type mismatch**:

```sql
-- Current problematic expression (as revealed by HANA error):
leftstr(string("CALWEEK"), 4) <= int(leftstr(string(now()), 4)) + 1
```

**Issue:** 
- Left side: `leftstr(string("CALWEEK"), 4)` returns **STRING**
- Right side: `int(leftstr(string(now()), 4)) + 1` returns **INT**
- Comparison between STRING and INT causes Error 266

### Finding 3: Cascade Effect

```
┌─────────────────────────────────────────┐
│  NA_TMV_IBP_FORECAST_SNAP               │
│  (Contains invalid CALWEEK: "-01")      │
└─────────────────┬───────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│  CV_SPFIC_VOLUME_ANALYZER_IP            │
│  Filter: leftstr(CALWEEK,4) <= year+1   │
│  → Type mismatch (Error 266)            │
│  → Date conversion failure (Error 303)  │
└─────────────────┬───────────────────────┘
                  ↓
┌─────────────────────────────────────────┐
│  Power BI Refresh                       │
│  → DM_GWPipeline_Gateway_MashupDataAccess│
│     Error                               │
└─────────────────────────────────────────┘
```

---

## Power BI Model Details

| Property | Value |
|----------|-------|
| Model Name | Volume Analyzer EA |
| Primary Table | CV_SPFIC_VOLUME_ANALYZER |
| Row Count (last successful refresh) | 9,225,226 |
| HANA Server | hana.kcc.com:32015 |
| HANA Schema | KCC.NA.CUSTOMER.TMV |
| Calculation View | CV_SPFIC_VOLUME_ANALYZER_IP |
| Input Parameters | IP_UOM='EA', IP_CURR='GC' |

### Date-Related Columns in Model

| Column | Data Type | Source |
|--------|-----------|--------|
| DATE | DateTime | HANA view |
| MONTH | String (YYYYMM) | HANA view |
| MONTH_DATE | DateTime | HANA view |
| WEEK_START_MON | DateTime | HANA view |

---

## Requested Actions for SAP/HANA Team

### 1. Identify Invalid CALWEEK Values

Run this query against `NA_TMV_IBP_FORECAST_SNAP`:

```sql
-- Find all invalid CALWEEK values
SELECT DISTINCT "CALWEEK", COUNT(*) AS row_count
FROM "RGN"."NA_CUSTOM"."NA_TMV_IBP_FORECAST_SNAP"
WHERE 
    "CALWEEK" IS NULL
    OR "CALWEEK" = ''
    OR LENGTH(CAST("CALWEEK" AS NVARCHAR)) < 6
    OR LEFT(CAST("CALWEEK" AS NVARCHAR), 2) NOT IN ('20', '19')
    OR "CALWEEK" LIKE '%-%'
GROUP BY "CALWEEK"
ORDER BY "CALWEEK";
```

### 2. Fix the Type Mismatch in Calculation View

Locate and update the filter expression in `CV_SPFIC_VOLUME_ANALYZER_IP`:

**Current (buggy):**
```sql
leftstr(string("CALWEEK"), 4) <= int(leftstr(string(now()), 4)) + 1
```

**Recommended fix:**
```sql
-- Option A: Cast both sides to INT
int(leftstr(string("CALWEEK"), 4)) <= int(leftstr(string(now()), 4)) + 1

-- Option B: Cast both sides to STRING
leftstr(string("CALWEEK"), 4) <= string(int(leftstr(string(now()), 4)) + 1)

-- Option C: Add null/validation check
CASE 
    WHEN "CALWEEK" IS NOT NULL 
        AND LENGTH(string("CALWEEK")) >= 4 
        AND LEFT(string("CALWEEK"), 2) = '20'
    THEN int(leftstr(string("CALWEEK"), 4)) 
    ELSE 0 
END <= int(leftstr(string(now()), 4)) + 1
```

### 3. Add Data Validation

Consider adding input validation to prevent invalid CALWEEK values from loading:

```sql
-- Add to data load process or as a view filter
WHERE "CALWEEK" IS NOT NULL
  AND LENGTH(CAST("CALWEEK" AS NVARCHAR)) = 6
  AND CAST("CALWEEK" AS NVARCHAR) LIKE '20____'
```

### 4. Check Recent Data Loads

Identify when the bad data was introduced:

```sql
-- If there's a load timestamp column
SELECT 
    MIN(load_timestamp) as first_occurrence,
    MAX(load_timestamp) as last_occurrence,
    COUNT(*) as row_count
FROM "NA_TMV_IBP_FORECAST_SNAP"
WHERE "CALWEEK" LIKE '%-%' 
   OR LENGTH(CAST("CALWEEK" AS NVARCHAR)) < 6;
```

---

## Timeline

| Date | Event |
|------|-------|
| 2026-01-03 20:11:59Z | First recorded failure in Power BI Service |
| 2026-01-12 | Root cause analysis completed |

---

## Resolution Status

| Item | Status |
|------|--------|
| Root cause identified | ✅ Complete |
| Power BI model analysis | ✅ Complete |
| HANA team notification | ⏳ Pending |
| Source data cleanup | ⏳ Pending |
| Calculation view fix | ⏳ Pending |
| Refresh validation | ⏳ Pending |

---

## Contact

For questions about this analysis, contact the DV CoE Team (steve.wolfe@kcc.com).