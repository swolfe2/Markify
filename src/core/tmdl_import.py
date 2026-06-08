"""
Tabular Model Definition Language (.tmdl) and BIM (.bim) importer for Markify.
Zero dependencies - uses only Python built-ins.
"""
from __future__ import annotations

import json
import os
import re

from logging_config import get_logger

logger = get_logger("tmdl_import")

# Standard TMDL properties to exclude from DAX expressions
TMDL_PROPERTY_RE = re.compile(
    r'^\s*(formatString|lineageTag|displayFolder|description|isHidden|dataType|sourceColumn|'
    r'summarizeBy|dataCategory|sortByColumn|changeRelationBehavior|joinOnDateBehavior|'
    r'isAvailableInMdx|mode|source|state)\s*[:=]'
)


def parse_bim_content(content: str) -> dict:
    """Parse .bim JSON content and return model metadata."""
    metadata = {
        "tables": [],
        "relationships": []
    }

    try:
        data = json.loads(content)
        model = data.get("model", {})

        # Parse tables
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

            hierarchies = []
            for h in t.get("hierarchies", []):
                levels = []
                for lvl in sorted(h.get("levels", []), key=lambda x: x.get("ordinal", 0)):
                    if lvl.get("column"):
                        levels.append(lvl.get("column"))
                hierarchies.append({
                    "name": h.get("name", ""),
                    "levels": levels
                })

            metadata["tables"].append({
                "name": table_name,
                "columns": columns,
                "measures": measures,
                "hierarchies": hierarchies
            })

        # Parse relationships
        for r in model.get("relationships", []):
            metadata["relationships"].append({
                "fromTable": r.get("fromTable", "Unknown"),
                "fromColumn": r.get("fromColumn", "Unknown"),
                "toTable": r.get("toTable", "Unknown"),
                "toColumn": r.get("toColumn", "Unknown")
            })

    except Exception as e:
        logger.error(f"Failed to parse BIM content: {e}")
        raise ValueError(f"Invalid BIM JSON structure: {e}") from e

    return metadata


def parse_tmdl_content(content: str) -> dict:
    """Parse TMDL text content and return model metadata."""
    metadata = {
        "tables": [],
        "relationships": []
    }

    current_table = None
    current_column = None
    current_measure = None
    current_hierarchy = None
    current_relationship = None

    measure_indent = 0
    dax_base_indent_prefix = None
    measure_lines = []

    lines = content.splitlines()

    def strip_quotes(name: str) -> str:
        name = name.strip()
        if (name.startswith("'") and name.endswith("'")) or (name.startswith('"') and name.endswith('"')):
            return name[1:-1]
        return name

    for line in lines:
        line_stripped = line.strip()
        if not line_stripped or line_stripped.startswith("//") or line_stripped.startswith("#"):
            continue

        # Calculate indentation level (using spaces/tabs)
        indent_len = len(line) - len(line.lstrip())

        # If we are parsing a multi-line measure, check if the expression ended
        if current_measure is not None:
            # Check if indentation is back to measure declaration level or shallower
            # or if it's a property line or a new declaration block
            is_property = TMDL_PROPERTY_RE.match(line)
            is_new_block = (
                line_stripped.startswith("measure ") or
                line_stripped.startswith("column ") or
                line_stripped.startswith("hierarchy ") or
                line_stripped.startswith("table ") or
                line_stripped.startswith("level ") or
                line_stripped.startswith("partition ")
            )

            if indent_len <= measure_indent or is_property or is_new_block:
                # Finish current measure
                expr = "\n".join(measure_lines).strip()
                current_measure["expression"] = expr
                if current_table:
                    current_table["measures"].append(current_measure)
                current_measure = None
                measure_lines = []
                dax_base_indent_prefix = None
            else:
                # Still inside the measure expression
                if dax_base_indent_prefix is None:
                    dax_base_indent_prefix = line[:len(line) - len(line.lstrip())]

                # Strip the common base indent prefix
                if line.startswith(dax_base_indent_prefix):
                    measure_lines.append(line[len(dax_base_indent_prefix):])
                else:
                    measure_lines.append(line_stripped)
                continue

        # 1. Table declaration
        if line_stripped.startswith("table "):
            table_name = strip_quotes(line_stripped[6:].strip())
            current_table = {
                "name": table_name,
                "columns": [],
                "measures": [],
                "hierarchies": []
            }
            metadata["tables"].append(current_table)
            current_column = None
            current_hierarchy = None
            current_relationship = None
            continue

        # 2. Column declaration
        if line_stripped.startswith("column "):
            col_name = strip_quotes(line_stripped[7:].strip())
            current_column = {
                "name": col_name,
                "dataType": "Unknown"
            }
            if current_table:
                current_table["columns"].append(current_column)
            current_hierarchy = None
            current_relationship = None
            continue

        # Column Properties (dataType)
        if current_column and line_stripped.startswith("dataType:"):
            current_column["dataType"] = line_stripped[9:].strip()
            continue

        # 3. Measure declaration
        if line_stripped.startswith("measure "):
            measure_part = line_stripped[8:].strip()
            # Split by first '=' to get name and expression
            if "=" in measure_part:
                m_name, m_expr = measure_part.split("=", 1)
                m_name = strip_quotes(m_name.strip())
                current_measure = {
                    "name": m_name,
                    "expression": ""
                }
                measure_indent = indent_len
                dax_base_indent_prefix = None
                # If there's expression content on the same line
                if m_expr.strip():
                    measure_lines.append(m_expr.strip())
            continue

        # 4. Hierarchy declaration
        if line_stripped.startswith("hierarchy "):
            h_name = strip_quotes(line_stripped[10:].strip())
            current_hierarchy = {
                "name": h_name,
                "levels": []
            }
            if current_table:
                current_table["hierarchies"].append(current_hierarchy)
            current_column = None
            current_relationship = None
            continue

        # Hierarchy Levels
        if current_hierarchy and line_stripped.startswith("level "):
            continue

        if current_hierarchy and line_stripped.startswith("column:"):
            col_val = strip_quotes(line_stripped[7:].strip())
            current_hierarchy["levels"].append(col_val)
            continue

        # 5. Relationship declaration (often in database/model files)
        if line_stripped.startswith("relationship "):
            current_relationship = {
                "fromTable": "Unknown",
                "fromColumn": "Unknown",
                "toTable": "Unknown",
                "toColumn": "Unknown"
            }
            metadata["relationships"].append(current_relationship)
            current_table = None
            current_column = None
            current_hierarchy = None
            continue

        if current_relationship:
            if line_stripped.startswith("fromTable:"):
                current_relationship["fromTable"] = strip_quotes(line_stripped[10:].strip())
            elif line_stripped.startswith("fromColumn:"):
                current_relationship["fromColumn"] = strip_quotes(line_stripped[11:].strip())
            elif line_stripped.startswith("toTable:"):
                current_relationship["toTable"] = strip_quotes(line_stripped[8:].strip())
            elif line_stripped.startswith("toColumn:"):
                current_relationship["toColumn"] = strip_quotes(line_stripped[9:].strip())
            continue

    # Finalize any pending measure at EOF
    if current_measure is not None:
        expr = "\n".join(measure_lines).strip()
        current_measure["expression"] = expr
        if current_table:
            current_table["measures"].append(current_measure)

    return metadata


def convert_tmdl_or_bim(filepath: str) -> str:
    """Read .bim or .tmdl file and return structured Markdown documentation."""
    _, ext = os.path.splitext(filepath.lower())

    try:
        with open(filepath, encoding="utf-8") as f:
            content = f.read()
    except UnicodeDecodeError:
        # Retry with utf-16
        with open(filepath, encoding="utf-16") as f:
            content = f.read()

    if ext == ".bim":
        metadata = parse_bim_content(content)
    else:
        metadata = parse_tmdl_content(content)

    filename = os.path.basename(filepath)
    md_lines = [f"# Tabular Model Metadata: {filename}\n"]

    # Tables & Columns / Measures / Hierarchies
    if metadata["tables"]:
        for table in metadata["tables"]:
            md_lines.append(f"## Table: {table['name']}\n")

            # Columns
            if table["columns"]:
                md_lines.append("### Columns\n")
                md_lines.append("| Column Name | Data Type |")
                md_lines.append("|---|---|")
                for col in table["columns"]:
                    md_lines.append(f"| {col['name']} | {col['dataType']} |")
                md_lines.append("")

            # Measures
            if table["measures"]:
                md_lines.append("### Measures\n")
                for m in table["measures"]:
                    md_lines.append(f"#### Measure: {table['name']}[{m['name']}]\n")
                    md_lines.append("```dax")
                    md_lines.append(m["expression"])
                    md_lines.append("```\n")

            # Hierarchies
            if table["hierarchies"]:
                md_lines.append("### Hierarchies\n")
                for h in table["hierarchies"]:
                    levels_str = " -> ".join(h["levels"])
                    md_lines.append(f"- **{h['name']}**: {levels_str}")
                md_lines.append("")

    # Relationships
    if metadata["relationships"]:
        md_lines.append("## Model Relationships\n")
        md_lines.append("| From Table | From Column | To Table | To Column |")
        md_lines.append("|---|---|---|---|")
        for rel in metadata["relationships"]:
            md_lines.append(
                f"| {rel['fromTable']} | {rel['fromColumn']} | {rel['toTable']} | {rel['toColumn']} |"
            )
        md_lines.append("")

    return "\n".join(md_lines).strip() + "\n"
