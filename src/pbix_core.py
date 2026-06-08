"""
Power BI Report Metadata Extractor for Markify.
Extracts tables, columns, measures, and relationships from .pbix files.
Zero dependencies - uses only Python built-ins.
"""
from __future__ import annotations

import json
import os
import zipfile

from logging_config import get_logger

logger = get_logger("pbix_core")


def extract_metadata_from_pbix(filepath: str) -> dict:
    """Extract model schema and pages metadata from a .pbix zip archive."""
    metadata = {
        "tables": [],
        "relationships": [],
        "pages": []
    }

    try:
        with zipfile.ZipFile(filepath, "r") as z:
            # 1. Parse DataModelSchema
            if "DataModelSchema" in z.namelist():
                try:
                    with z.open("DataModelSchema") as f:
                        schema_content = f.read().decode("utf-16-le")
                        schema = json.loads(schema_content)
                        model = schema.get("model", {})

                        # Tables and Columns / Measures
                        for t in model.get("tables", []):
                            table_name = t.get("name", "")

                            columns = []
                            for c in t.get("columns", []):
                                if c.get("name"):
                                    columns.append({
                                        "name": c.get("name"),
                                        "dataType": c.get("dataType", "Unknown")
                                    })

                            measures = []
                            for m in t.get("measures", []):
                                if m.get("name"):
                                    expr = m.get("expression", "")
                                    if isinstance(expr, list):
                                        expr = "\n".join(expr)
                                    measures.append({
                                        "name": m.get("name"),
                                        "expression": expr
                                    })

                            metadata["tables"].append({
                                "name": table_name,
                                "columns": columns,
                                "measures": measures
                            })

                        # Relationships
                        for r in model.get("relationships", []):
                            metadata["relationships"].append({
                                "fromTable": r.get("fromTable", "Unknown"),
                                "fromColumn": r.get("fromColumn", "Unknown"),
                                "toTable": r.get("toTable", "Unknown"),
                                "toColumn": r.get("toColumn", "Unknown")
                            })
                except Exception as e:
                    logger.warning(f"Failed to parse DataModelSchema in {filepath}: {e}")

            # 2. Parse Layout (Report Pages)
            if "Report/Layout" in z.namelist():
                try:
                    with z.open("Report/Layout") as f:
                        layout_content = f.read().decode("utf-16-le")
                        layout = json.loads(layout_content)
                        for section in layout.get("sections", []):
                            page_name = section.get("displayName")
                            if page_name:
                                metadata["pages"].append(page_name)
                except Exception as e:
                    logger.warning(f"Failed to parse Report/Layout in {filepath}: {e}")

    except Exception as e:
        logger.error(f"Error opening .pbix file {filepath}: {e}")
        raise

    return metadata


def get_pbix_metadata(filepath: str) -> str:
    """Generate structured Markdown documentation from extracted PBIX metadata."""
    metadata = extract_metadata_from_pbix(filepath)
    filename = os.path.basename(filepath)

    md_lines = []
    md_lines.append(f"# Power BI Report Metadata: {filename}\n")

    # 1. Report Pages
    if metadata["pages"]:
        md_lines.append("## Report Pages\n")
        for page in metadata["pages"]:
            md_lines.append(f"- {page}")
        md_lines.append("")

    # 2. Model Tables & Columns
    if metadata["tables"]:
        md_lines.append("## Model Tables & Columns\n")
        for table in metadata["tables"]:
            md_lines.append(f"### Table: {table['name']}\n")
            if table["columns"]:
                md_lines.append("| Column Name | Data Type |")
                md_lines.append("|---|---|")
                for col in table["columns"]:
                    md_lines.append(f"| {col['name']} | {col['dataType']} |")
                md_lines.append("")
            else:
                md_lines.append("*No columns found.*\n")

    # 3. Model Measures
    has_measures = any(len(table["measures"]) > 0 for table in metadata["tables"])
    if has_measures:
        md_lines.append("## Model Measures\n")
        for table in metadata["tables"]:
            if table["measures"]:
                for m in table["measures"]:
                    md_lines.append(f"### Measure: {table['name']}[{m['name']}]\n")
                    md_lines.append("```dax")
                    md_lines.append(m["expression"])
                    md_lines.append("```\n")

    # 4. Model Relationships
    if metadata["relationships"]:
        md_lines.append("## Model Relationships\n")
        md_lines.append("| From Table | From Column | To Table | To Column |")
        md_lines.append("|---|---|---|---|")
        for rel in metadata["relationships"]:
            md_lines.append(
                f"| {rel['fromTable']} | {rel['fromColumn']} | {rel['toTable']} | {rel['toColumn']} |"
            )
        md_lines.append("")

    return "\n".join(md_lines)
