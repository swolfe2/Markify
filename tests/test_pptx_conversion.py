"""
Tests for PowerPoint to Markdown conversion (Feature #9).
"""
from __future__ import annotations

import os
import tempfile
import unittest
import zipfile

from pptx_core import convert_pptx_to_markdown


class TestPptxConversion(unittest.TestCase):
    def setUp(self):
        self.test_dir = tempfile.TemporaryDirectory()
        self.pptx_path = os.path.join(self.test_dir.name, "test_presentation.pptx")

    def tearDown(self):
        self.test_dir.cleanup()

    def create_mock_pptx(
        self,
        presentation_xml: str,
        presentation_rels: str,
        slides_dict: dict[str, str],
        notes_dict: dict[str, str] | None = None,
        slide_rels_dict: dict[str, str] | None = None
    ):
        """Helper to construct a valid minimum mock zip PPTX file."""
        with zipfile.ZipFile(self.pptx_path, "w") as z:
            z.writestr("ppt/presentation.xml", presentation_xml.strip())
            z.writestr("ppt/_rels/presentation.xml.rels", presentation_rels.strip())

            for path, xml_content in slides_dict.items():
                z.writestr(path, xml_content.strip())

            if notes_dict:
                for path, xml_content in notes_dict.items():
                    z.writestr(path, xml_content.strip())

            if slide_rels_dict:
                for path, xml_content in slide_rels_dict.items():
                    z.writestr(path, xml_content.strip())

    def test_pptx_basic_conversion(self):
        """Test PPTX parsing with headings, lists, bold/italic, and speaker notes."""
        presentation_xml = """
<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
    <p:sldIdLst>
        <p:sldId id="256" r:id="rId1"/>
    </p:sldIdLst>
</p:presentation>
"""
        presentation_rels = """
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide1.xml"/>
</Relationships>
"""
        slide1_xml = """
<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
    <p:cSld>
        <p:spTree>
            <p:sp>
                <p:nvSpPr>
                    <p:nvPr><p:ph type="title"/></p:nvPr>
                </p:nvSpPr>
                <p:txBody>
                    <a:p>
                        <a:r>
                            <a:t>Introduction to Markify</a:t>
                        </a:r>
                    </a:p>
                </p:txBody>
            </p:sp>
            <p:sp>
                <p:txBody>
                    <a:p>
                        <a:pPr lvl="0"/>
                        <a:r>
                            <a:rPr b="1"/>
                            <a:t>Key Feature:</a:t>
                        </a:r>
                    </a:p>
                    <a:p>
                        <a:pPr lvl="1"/>
                        <a:r>
                            <a:rPr i="1"/>
                            <a:t>Zero Dependencies</a:t>
                        </a:r>
                    </a:p>
                </p:txBody>
            </p:sp>
        </p:spTree>
    </p:cSld>
</p:sld>
"""
        notes1_xml = """
<p:notes xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
    <p:cSld>
        <p:spTree>
            <p:sp>
                <p:txBody>
                    <a:p>
                        <a:r><a:t>Remember to mention PyPI packaging.</a:t></a:r>
                    </a:p>
                </p:txBody>
            </p:sp>
        </p:spTree>
    </p:cSld>
</p:notes>
"""
        slide1_rels = """
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/notesSlide" Target="../notesSlides/notesSlide1.xml"/>
</Relationships>
"""

        self.create_mock_pptx(
            presentation_xml,
            presentation_rels,
            {"ppt/slides/slide1.xml": slide1_xml},
            {"ppt/notesSlides/notesSlide1.xml": notes1_xml},
            {"ppt/slides/_rels/slide1.xml.rels": slide1_rels}
        )

        md = convert_pptx_to_markdown(self.pptx_path)

        self.assertIn("# Presentation: test_presentation.pptx", md)
        self.assertIn("## Introduction to Markify", md)
        self.assertIn("**Key Feature:**", md)
        self.assertIn("  - *Zero Dependencies*", md)
        self.assertIn("> **Speaker Notes:**", md)
        self.assertIn("> Remember to mention PyPI packaging.", md)

    def test_pptx_table_conversion(self):
        """Test PPTX parser extracts and renders slides containing table graphic frames."""
        presentation_xml = """
<p:presentation xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
    <p:sldIdLst>
        <p:sldId id="256" r:id="rId1"/>
    </p:sldIdLst>
</p:presentation>
"""
        presentation_rels = """
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide1.xml"/>
</Relationships>
"""
        slide1_xml = """
<p:sld xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
    <p:cSld>
        <p:spTree>
            <p:sp>
                <p:nvSpPr>
                    <p:nvPr><p:ph type="title"/></p:nvPr>
                </p:nvSpPr>
                <p:txBody>
                    <a:p><a:r><a:t>Data Slide</a:t></a:r></a:p>
                </p:txBody>
            </p:sp>
            <p:graphicFrame>
                <a:graphic>
                    <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/table">
                        <a:tbl>
                            <a:tr>
                                <a:tc><a:txBody><a:p><a:r><a:t>Metric</a:t></a:r></a:p></a:txBody></a:tc>
                                <a:tc><a:txBody><a:p><a:r><a:t>Value</a:t></a:r></a:p></a:txBody></a:tc>
                            </a:tr>
                            <a:tr>
                                <a:tc><a:txBody><a:p><a:r><a:t>Conversion Rate</a:t></a:r></a:p></a:txBody></a:tc>
                                <a:tc><a:txBody><a:p><a:r><a:t>98%</a:t></a:r></a:p></a:txBody></a:tc>
                            </a:tr>
                        </a:tbl>
                    </a:graphicData>
                </a:graphic>
            </p:graphicFrame>
        </p:spTree>
    </p:cSld>
</p:sld>
"""
        self.create_mock_pptx(
            presentation_xml,
            presentation_rels,
            {"ppt/slides/slide1.xml": slide1_xml}
        )

        md = convert_pptx_to_markdown(self.pptx_path)

        self.assertIn("## Data Slide", md)
        self.assertIn("| Metric | Value |", md)
        self.assertIn("| --- | --- |", md)
        self.assertIn("| Conversion Rate | 98% |", md)
