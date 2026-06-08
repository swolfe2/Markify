"""
Tests for Tabular Editor Integration (.bim/.tmdl) (Feature #8).
"""
from __future__ import annotations

import json
import os
import tempfile
import unittest

from core.tmdl_import import convert_tmdl_or_bim


class TestTmdlImport(unittest.TestCase):
    def setUp(self):
        self.test_dir = tempfile.TemporaryDirectory()

    def tearDown(self):
        self.test_dir.cleanup()

    def test_convert_bim_file(self):
        """Test parsing .bim JSON file."""
        bim_data = {
            "name": "TestModel",
            "model": {
                "tables": [
                    {
                        "name": "Sales",
                        "columns": [
                            {"name": "SalesID", "dataType": "int64"},
                            {"name": "Revenue", "dataType": "decimal"}
                        ],
                        "measures": [
                            {"name": "Total Revenue", "expression": "SUM(Sales[Revenue])"}
                        ],
                        "hierarchies": [
                            {
                                "name": "Date Hierarchy",
                                "levels": [
                                    {"name": "Year", "ordinal": 0, "column": "YearColumn"},
                                    {"name": "Month", "ordinal": 1, "column": "MonthColumn"}
                                ]
                            }
                        ]
                    }
                ],
                "relationships": [
                    {
                        "fromTable": "Sales",
                        "fromColumn": "DateID",
                        "toTable": "Date",
                        "toColumn": "DateID"
                    }
                ]
            }
        }
        
        filepath = os.path.join(self.test_dir.name, "model.bim")
        with open(filepath, "w", encoding="utf-8") as f:
            json.dump(bim_data, f)
            
        md = convert_tmdl_or_bim(filepath)
        
        self.assertIn("# Tabular Model Metadata: model.bim", md)
        self.assertIn("## Table: Sales", md)
        self.assertIn("| SalesID | int64 |", md)
        self.assertIn("| Revenue | decimal |", md)
        self.assertIn("#### Measure: Sales[Total Revenue]", md)
        self.assertIn("SUM(Sales[Revenue])", md)
        self.assertIn("- **Date Hierarchy**: YearColumn -> MonthColumn", md)
        self.assertIn("## Model Relationships", md)
        self.assertIn("| Sales | DateID | Date | DateID |", md)

    def test_convert_tmdl_file(self):
        """Test parsing .tmdl text file."""
        tmdl_content = """
table Sales
	lineageTag: f8a623bf-234b-4b11-a889-130f14d8721c

	column SalesID
		dataType: int64
		lineageTag: abc

	column Revenue
		dataType: double
		lineageTag: def

	measure 'Total Revenue' = SUM(Sales[Revenue])
		formatString: $#,##0
		lineageTag: ghi

	measure 'Complex Measure' = 
			CALCULATE(
				[Total Revenue],
				Sales[SalesID] > 100
			)
		displayFolder: KPIs
		lineageTag: jkl

	hierarchy 'Product Category'
		lineageTag: mno
		level Category
			column: CategoryColumn
		level Subcategory
			column: SubcategoryColumn

relationship Rel1
	fromTable: Sales
	fromColumn: CustomerID
	toTable: Customers
	toColumn: CustomerID
"""
        filepath = os.path.join(self.test_dir.name, "sales.tmdl")
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(tmdl_content)
            
        md = convert_tmdl_or_bim(filepath)
        
        self.assertIn("# Tabular Model Metadata: sales.tmdl", md)
        self.assertIn("## Table: Sales", md)
        self.assertIn("| SalesID | int64 |", md)
        self.assertIn("| Revenue | double |", md)
        self.assertIn("#### Measure: Sales[Total Revenue]", md)
        self.assertIn("SUM(Sales[Revenue])", md)
        self.assertIn("#### Measure: Sales[Complex Measure]", md)
        self.assertIn("CALCULATE(\n\t[Total Revenue],\n\tSales[SalesID] > 100\n)", md)
        self.assertIn("- **Product Category**: CategoryColumn -> SubcategoryColumn", md)
        self.assertIn("## Model Relationships", md)
        self.assertIn("| Sales | CustomerID | Customers | CustomerID |", md)
