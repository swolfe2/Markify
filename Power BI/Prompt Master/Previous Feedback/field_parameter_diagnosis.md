# Field Parameter Issue - Root Cause and Solution

Hey,

I took a look at the field parameter issue and found the root cause.

## The Problem

When the `Show as Columns` field parameter table is pulled via DirectQuery from the shared semantic model, the data comes through correctly but the critical metadata is lost. Specifically, the `ParameterMetadata` extended property (which tells Power BI to resolve the text strings as dynamic column references) does not transfer across the DirectQuery boundary.

You can verify this by looking at the `Show as Columns Fields` column properties. In the shared model, it has `extendedProperty ParameterMetadata = {"version":3,"kind":2}`. In your composite model, that property is missing.

Without this metadata, Power BI treats `'Dim - Region Logic'[Region Name]` as a plain text string rather than as a column reference to evaluate dynamically. That's why you're seeing field names instead of field values.

## The Solution

Field parameters must be defined locally in each composite model. You need to recreate the field parameter as a local calculated table.

Here is what the original field parameter references:

```dax
Show as Columns Local = 
{
    ("Parent Vendor", NAMEOF('Dim - Vendors'[Parent Vendor ID Name]), 0),
    ("SAP Vendor", NAMEOF('Dim - Vendors'[Vendor ID Name]), 1),
    ("Segment", NAMEOF('GSA_ACC_DOC_FACT'[Segment]), 2),
    ("On/ Off PO Spend", NAMEOF('GSA_ACC_DOC_FACT'[On/ Off PO Spend]), 3),
    ("Materialized", NAMEOF('GSA_ACC_DOC_FACT'[Materialized?]), 3),
    ("Category Type Description", NAMEOF('Dim - Material Group'[Category Type Description]), 4),
    ("Category Level 1 Description", NAMEOF('Dim - Material Group'[Category Level 1 Description]), 5),
    ("Category Level 2 Description", NAMEOF('Dim - Material Group'[Category Level 2 Description]), 6),
    ("Category Level 3 Description", NAMEOF('Dim - Material Group'[Category Level 3 Description]), 7),
    ("Region Name", NAMEOF('Dim - Region Logic'[Region Name]), 8),
    ("Subregion Name", NAMEOF('Dim - Region Logic'[Subregion Name]), 9),
    ("Country Name", NAMEOF('Dim - Region Logic'[Country Name]), 10),
    ("Plant Name", NAMEOF('Dim - Plant'[Plant Name]), 11),
    ("Normalized Plant Name", NAMEOF('Dim - Plant'[Normalized Plant Name]), 12),
    ("Description Of Purchasing Organization", NAMEOF('Dim - Purchasing Org'[Description Of Purchasing Organization]), 13),
    ("General Ledger", NAMEOF('GSA_ACC_DOC_FACT'[AD General Ledger Account]), 14)
}
```

**Important:** This code replicates what the shared field parameter references, but many of these tables do not exist in your local composite model with these exact names (for example, `'Dim - Vendors'` may exist as `'1. AP Invoiced Dim - Vendors'` locally). The field parameter will fail unless every table and column referenced exists with a 1:1 match in your local model.

You will need to:
1. Review the tables available in your composite model
2. Update the NAMEOF() references to point to the actual local table names
3. Remove any rows that reference tables/columns that do not exist locally

Alternatively, you can use the "New Parameter > Fields" option in the Modeling ribbon to create a new field parameter from scratch by selecting the columns directly from your local model's field list.

## Summary

This is a known limitation of composite models. Field parameters rely on metadata that does not transfer via DirectQuery, so they must always be defined locally in the report's model. Additionally, the columns referenced must match the local table names exactly.

---

Let me know if you need help mapping the shared model table names to the local composite model table names.
