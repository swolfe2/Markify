"""
Script to create a proper sample DOCX with correct formatting for Markify demo.
Includes styles.xml for proper header and code formatting in Word.
"""
import zipfile
from xml.etree.ElementTree import (  # nosec B405 - Safe: only used for creating demo files, not parsing untrusted XML
    Element,
    SubElement,
    register_namespace,
    tostring,
)

# Word namespaces
WORD_NS = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
register_namespace('w', WORD_NS)

# Styles XML with Heading1, Heading2, and Code styles
STYLES_XML = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:style w:type="paragraph" w:styleId="Heading1">
    <w:name w:val="heading 1"/>
    <w:basedOn w:val="Normal"/>
    <w:next w:val="Normal"/>
    <w:pPr>
      <w:spacing w:before="240" w:after="120"/>
      <w:outlineLvl w:val="0"/>
    </w:pPr>
    <w:rPr>
      <w:b/>
      <w:sz w:val="32"/>
      <w:szCs w:val="32"/>
      <w:color w:val="2F5496"/>
    </w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Heading2">
    <w:name w:val="heading 2"/>
    <w:basedOn w:val="Normal"/>
    <w:next w:val="Normal"/>
    <w:pPr>
      <w:spacing w:before="200" w:after="80"/>
      <w:outlineLvl w:val="1"/>
    </w:pPr>
    <w:rPr>
      <w:b/>
      <w:sz w:val="26"/>
      <w:szCs w:val="26"/>
      <w:color w:val="2F5496"/>
    </w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Normal">
    <w:name w:val="Normal"/>
    <w:rPr>
      <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/>
      <w:sz w:val="22"/>
      <w:szCs w:val="22"/>
    </w:rPr>
  </w:style>
  <w:style w:type="paragraph" w:styleId="Code">
    <w:name w:val="Code"/>
    <w:basedOn w:val="Normal"/>
    <w:pPr>
      <w:shd w:val="clear" w:color="auto" w:fill="F0F0F0"/>
      <w:spacing w:before="60" w:after="60"/>
    </w:pPr>
    <w:rPr>
      <w:rFonts w:ascii="Consolas" w:hAnsi="Consolas"/>
      <w:sz w:val="20"/>
      <w:szCs w:val="20"/>
    </w:rPr>
  </w:style>
</w:styles>'''

# Content Types XML
CONTENT_TYPES_XML = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>'''

# Root relationships
ROOT_RELS_XML = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>'''

# Document relationships (includes styles)
DOC_RELS_XML = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>'''


def create_paragraph(text, style=None, bold=False, italic=False, font=None, size=None):
    """Create a Word paragraph element."""
    p = Element(f'{{{WORD_NS}}}p')

    pPr = SubElement(p, f'{{{WORD_NS}}}pPr')
    if style:
        pStyle = SubElement(pPr, f'{{{WORD_NS}}}pStyle')
        pStyle.set(f'{{{WORD_NS}}}val', style)

    r = SubElement(p, f'{{{WORD_NS}}}r')

    rPr = SubElement(r, f'{{{WORD_NS}}}rPr')
    if bold:
        SubElement(rPr, f'{{{WORD_NS}}}b')
    if italic:
        SubElement(rPr, f'{{{WORD_NS}}}i')
    if font:
        rFonts = SubElement(rPr, f'{{{WORD_NS}}}rFonts')
        rFonts.set(f'{{{WORD_NS}}}ascii', font)
        rFonts.set(f'{{{WORD_NS}}}hAnsi', font)
    if size:
        sz = SubElement(rPr, f'{{{WORD_NS}}}sz')
        sz.set(f'{{{WORD_NS}}}val', str(size))

    t = SubElement(r, f'{{{WORD_NS}}}t')
    t.set('{http://www.w3.org/XML/1998/namespace}space', 'preserve')
    t.text = text

    return p


def create_table(rows):
    """Create a Word table with the given rows (list of lists)."""
    tbl = Element(f'{{{WORD_NS}}}tbl')

    # Table properties with borders
    tblPr = SubElement(tbl, f'{{{WORD_NS}}}tblPr')
    tblStyle = SubElement(tblPr, f'{{{WORD_NS}}}tblStyle')
    tblStyle.set(f'{{{WORD_NS}}}val', 'TableGrid')
    tblW = SubElement(tblPr, f'{{{WORD_NS}}}tblW')
    tblW.set(f'{{{WORD_NS}}}w', '5000')
    tblW.set(f'{{{WORD_NS}}}type', 'pct')
    tblBorders = SubElement(tblPr, f'{{{WORD_NS}}}tblBorders')
    for border in ['top', 'left', 'bottom', 'right', 'insideH', 'insideV']:
        b = SubElement(tblBorders, f'{{{WORD_NS}}}{border}')
        b.set(f'{{{WORD_NS}}}val', 'single')
        b.set(f'{{{WORD_NS}}}sz', '4')
        b.set(f'{{{WORD_NS}}}space', '0')
        b.set(f'{{{WORD_NS}}}color', '000000')

    # Table grid
    tblGrid = SubElement(tbl, f'{{{WORD_NS}}}tblGrid')
    if rows:
        for _ in rows[0]:
            gc = SubElement(tblGrid, f'{{{WORD_NS}}}gridCol')
            gc.set(f'{{{WORD_NS}}}w', '2000')

    # Rows
    for i, row_data in enumerate(rows):
        tr = SubElement(tbl, f'{{{WORD_NS}}}tr')
        for cell_text in row_data:
            tc = SubElement(tr, f'{{{WORD_NS}}}tc')
            # Cell properties
            tcPr = SubElement(tc, f'{{{WORD_NS}}}tcPr')
            tcW = SubElement(tcPr, f'{{{WORD_NS}}}tcW')
            tcW.set(f'{{{WORD_NS}}}w', '2000')
            tcW.set(f'{{{WORD_NS}}}type', 'dxa')
            # Header row shading
            if i == 0:
                shd = SubElement(tcPr, f'{{{WORD_NS}}}shd')
                shd.set(f'{{{WORD_NS}}}val', 'clear')
                shd.set(f'{{{WORD_NS}}}color', 'auto')
                shd.set(f'{{{WORD_NS}}}fill', 'D9E2F3')
            # Cell paragraph
            p = SubElement(tc, f'{{{WORD_NS}}}p')
            r = SubElement(p, f'{{{WORD_NS}}}r')
            if i == 0:
                rPr = SubElement(r, f'{{{WORD_NS}}}rPr')
                SubElement(rPr, f'{{{WORD_NS}}}b')
            t = SubElement(r, f'{{{WORD_NS}}}t')
            t.text = cell_text

    return tbl


def main():
    output_path = r'c:\Users\U15405\OneDrive - Kimberly-Clark\Desktop\Code\Python\Markify\samples\Markify_Demo.docx'

    # Create document content
    doc = Element(f'{{{WORD_NS}}}document')
    body = SubElement(doc, f'{{{WORD_NS}}}body')

    # Title
    body.append(create_paragraph('Markify Demo Document', 'Heading1'))
    body.append(create_paragraph(''))
    body.append(create_paragraph('This document showcases Markify\'s conversion capabilities.'))
    body.append(create_paragraph(''))

    # Section 1: Headers
    body.append(create_paragraph('1. Header Support', 'Heading1'))
    body.append(create_paragraph('1.1 Sub-header (Level 2)', 'Heading2'))
    body.append(create_paragraph('Markify detects Word heading styles and converts them to Markdown headers.'))
    body.append(create_paragraph(''))

    # Section 2: Formatting
    body.append(create_paragraph('2. Formatting & Links', 'Heading1'))
    body.append(create_paragraph('Text can be bold or italic. Visit https://github.com for more info.'))
    body.append(create_paragraph(''))

    # Section 3: Table
    body.append(create_paragraph('3. Sample Table', 'Heading1'))
    body.append(create_paragraph(''))
    body.append(create_table([
        ['ID', 'Name', 'Role'],
        ['001', 'Alice', 'Developer'],
        ['002', 'Bob', 'PM'],
        ['003', 'Carol', 'Designer']
    ]))
    body.append(create_paragraph(''))

    # Section 4: Power Query
    body.append(create_paragraph('4. Power Query (M)', 'Heading1'))
    body.append(create_paragraph(''))
    body.append(create_paragraph('let', 'Code', font='Consolas'))
    body.append(create_paragraph('    Source = Excel.Workbook(File.Contents("data.xlsx")),', 'Code', font='Consolas'))
    body.append(create_paragraph('    Output = Source{0}[Data]', 'Code', font='Consolas'))
    body.append(create_paragraph('in', 'Code', font='Consolas'))
    body.append(create_paragraph('    Output', 'Code', font='Consolas'))
    body.append(create_paragraph(''))

    # Section 5: DAX
    body.append(create_paragraph('5. DAX Example', 'Heading1'))
    body.append(create_paragraph(''))
    body.append(create_paragraph('Revenue := SUMX(Sales, Sales[Qty] * Sales[Price])', 'Code', font='Consolas'))
    body.append(create_paragraph(''))

    # Section 6: Python
    body.append(create_paragraph('6. Python Example', 'Heading1'))
    body.append(create_paragraph(''))
    body.append(create_paragraph('import pandas as pd', 'Code', font='Consolas'))
    body.append(create_paragraph('', 'Code', font='Consolas'))
    body.append(create_paragraph('def load_data(path):', 'Code', font='Consolas'))
    body.append(create_paragraph('    return pd.read_csv(path)', 'Code', font='Consolas'))

    # Section properties
    sectPr = SubElement(body, f'{{{WORD_NS}}}sectPr')
    pgSz = SubElement(sectPr, f'{{{WORD_NS}}}pgSz')
    pgSz.set(f'{{{WORD_NS}}}w', '12240')
    pgSz.set(f'{{{WORD_NS}}}h', '15840')
    pgMar = SubElement(sectPr, f'{{{WORD_NS}}}pgMar')
    pgMar.set(f'{{{WORD_NS}}}top', '1440')
    pgMar.set(f'{{{WORD_NS}}}right', '1440')
    pgMar.set(f'{{{WORD_NS}}}bottom', '1440')
    pgMar.set(f'{{{WORD_NS}}}left', '1440')

    # Build document XML
    xml_content = tostring(doc, encoding='unicode')
    doc_xml = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' + xml_content

    # Create the DOCX file
    with zipfile.ZipFile(output_path, 'w', zipfile.ZIP_DEFLATED) as docx:
        docx.writestr('[Content_Types].xml', CONTENT_TYPES_XML)
        docx.writestr('_rels/.rels', ROOT_RELS_XML)
        docx.writestr('word/_rels/document.xml.rels', DOC_RELS_XML)
        docx.writestr('word/styles.xml', STYLES_XML)
        docx.writestr('word/document.xml', doc_xml.encode('utf-8'))

    print('Created Markify_Demo.docx with proper formatting at:')
    print(f'  {output_path}')
    print()
    print('Contents:')
    print('  - Heading1 and Heading2 styles (blue, bold)')
    print('  - Proper Word table with header row shading')
    print('  - Code paragraphs with Consolas font')


if __name__ == '__main__':
    main()
