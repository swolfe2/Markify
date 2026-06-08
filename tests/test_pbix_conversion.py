"""
Tests for Power BI Report Metadata parser (Feature #7).
"""
from __future__ import annotations

import json
import os
import tempfile
import unittest
import zipfile

from pbix_core import extract_metadata_from_pbix, get_pbix_metadata


class TestPbixMetadataParser(unittest.TestCase):
    def setUp(self):
        # Create a temporary directory for test files
        self.test_dir = tempfile.TemporaryDirectory()
        self.pbix_path = os.path.join(self.test_dir.name, "test_report.pbix")

    def tearDown(self):
        self.test_dir.cleanup()

    def create_mock_pbix(self, schema_data: dict | None, layout_data: dict | None):
        """Helper to create a temporary .pbix file containing the specified mock data."""
        with zipfile.ZipFile(self.pbix_path, "w") as z:
            if schema_data is not None:
                # UTF-16LE with BOM or simple UTF-16LE encoding
                content = json.dumps(schema_data).encode("utf-16-le")
                z.writestr("DataModelSchema", content)
            if layout_data is not None:
                content = json.dumps(layout_data).encode("utf-16-le")
                z.writestr("Report/Layout", content)

    def test_extract_metadata_full(self):
        """Test complete extraction of tables, columns, measures, relationships, and pages."""
        schema_data = {
            "model": {
                "tables": [
                    {
                        "name": "Sales",
                        "columns": [
                            {"name": "SalesID", "dataType": "Int64"},
                            {"name": "Amount", "dataType": "Double"}
                        ],
                        "measures": [
                            {
                                "name": "Total Sales",
                                "expression": "SUM(Sales[Amount])"
                            },
                            {
                                "name": "Sales YoY",
                                "expression": ["CALCULATE(", "  [Total Sales],", "  SAMEPERIODLASTYEAR('Calendar'[Date])", ")"]
                            }
                        ]
                    },
                    {
                        "name": "Calendar",
                        "columns": [
                            {"name": "Date", "dataType": "DateTime"}
                        ]
                    }
                ],
                "relationships": [
                    {
                        "fromTable": "Sales",
                        "fromColumn": "SalesID",
                        "toTable": "Calendar",
                        "toColumn": "Date"
                    }
                ]
            }
        }

        layout_data = {
            "sections": [
                {"displayName": "Dashboard"},
                {"displayName": "Detailed View"}
            ]
        }

        self.create_mock_pbix(schema_data, layout_data)

        # 1. Test raw metadata extraction
        metadata = extract_metadata_from_pbix(self.pbix_path)
        self.assertEqual(len(metadata["tables"]), 2)
        self.assertEqual(metadata["tables"][0]["name"], "Sales")
        self.assertEqual(len(metadata["tables"][0]["columns"]), 2)
        self.assertEqual(metadata["tables"][0]["columns"][0]["name"], "SalesID")
        self.assertEqual(metadata["tables"][0]["columns"][0]["dataType"], "Int64")
        self.assertEqual(len(metadata["tables"][0]["measures"]), 2)
        self.assertEqual(metadata["tables"][0]["measures"][0]["name"], "Total Sales")
        self.assertEqual(metadata["tables"][0]["measures"][0]["expression"], "SUM(Sales[Amount])")
        # Test expression list joining
        self.assertEqual(
            metadata["tables"][0]["measures"][1]["expression"],
            "CALCULATE(\n  [Total Sales],\n  SAMEPERIODLASTYEAR('Calendar'[Date])\n)"
        )

        self.assertEqual(len(metadata["relationships"]), 1)
        self.assertEqual(metadata["relationships"][0]["fromTable"], "Sales")
        self.assertEqual(metadata["relationships"][0]["toTable"], "Calendar")

        self.assertEqual(metadata["pages"], ["Dashboard", "Detailed View"])

        # 2. Test markdown rendering
        md = get_pbix_metadata(self.pbix_path)
        self.assertIn("Power BI Report Metadata: test_report.pbix", md)
        self.assertIn("- Dashboard", md)
        self.assertIn("- Detailed View", md)
        self.assertIn("### Table: Sales", md)
        self.assertIn("| SalesID | Int64 |", md)
        self.assertIn("| Amount | Double |", md)
        self.assertIn("### Measure: Sales[Total Sales]", md)
        self.assertIn("SUM(Sales[Amount])", md)
        self.assertIn("### Measure: Sales[Sales YoY]", md)
        self.assertIn("| Sales | SalesID | Calendar | Date |", md)

    def test_extract_metadata_missing_schema_or_layout(self):
        """Test parser robustness when DataModelSchema or Report/Layout is missing."""
        # Case A: Only layout is present (no tables, relationships, etc.)
        layout_data = {
            "sections": [{"displayName": "Page 1"}]
        }
        self.create_mock_pbix(None, layout_data)

        metadata = extract_metadata_from_pbix(self.pbix_path)
        self.assertEqual(metadata["tables"], [])
        self.assertEqual(metadata["relationships"], [])
        self.assertEqual(metadata["pages"], ["Page 1"])

        md = get_pbix_metadata(self.pbix_path)
        self.assertIn("## Report Pages", md)
        self.assertNotIn("## Model Tables & Columns", md)
        self.assertNotIn("## Model Measures", md)
        self.assertNotIn("## Model Relationships", md)

        # Case B: Only schema is present
        schema_data = {
            "model": {
                "tables": [{"name": "Dummy", "columns": [{"name": "Col1"}]}]
            }
        }
        self.create_mock_pbix(schema_data, None)

        metadata = extract_metadata_from_pbix(self.pbix_path)
        self.assertEqual(metadata["pages"], [])
        self.assertEqual(len(metadata["tables"]), 1)

        md = get_pbix_metadata(self.pbix_path)
        self.assertNotIn("## Report Pages", md)
        self.assertIn("## Model Tables & Columns", md)

    def test_corrupt_or_invalid_json(self):
        """Test that exception is caught and logged, returning empty structures rather than crashing."""
        with zipfile.ZipFile(self.pbix_path, "w") as z:
            # Write invalid bytes that cannot be decoded as utf-16-le JSON
            z.writestr("DataModelSchema", b"invalid-bytes")
            z.writestr("Report/Layout", b"invalid-bytes")

        metadata = extract_metadata_from_pbix(self.pbix_path)
        self.assertEqual(metadata["tables"], [])
        self.assertEqual(metadata["relationships"], [])
        self.assertEqual(metadata["pages"], [])
