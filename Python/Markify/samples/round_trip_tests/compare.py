"""
Round-trip conversion comparison script.
Compares XML content between DOCX files and Markdown content.
"""
import difflib
import os
import zipfile

TEST_DIR = os.path.dirname(os.path.abspath(__file__))

def extract_document_xml(docx_path):
    """Extract and return the document.xml content from a DOCX file."""
    with zipfile.ZipFile(docx_path, 'r') as zf:
        return zf.read('word/document.xml').decode('utf-8')

def normalize_markdown(text):
    """Normalize markdown for comparison."""
    lines = text.strip().split('\n')
    # Remove empty lines, strip whitespace
    return [line.strip() for line in lines if line.strip()]

def compare_files(file1, file2):
    """Compare two text files and return differences."""
    with open(file1, encoding='utf-8') as f1:
        content1 = f1.read()
    with open(file2, encoding='utf-8') as f2:
        content2 = f2.read()

    lines1 = normalize_markdown(content1)
    lines2 = normalize_markdown(content2)

    differ = difflib.unified_diff(lines1, lines2, fromfile=os.path.basename(file1), tofile=os.path.basename(file2), lineterm='')
    return list(differ)

def main():
    print("=" * 60)
    print("ROUND-TRIP CONVERSION FIDELITY TEST REPORT")
    print("=" * 60)
    print()

    # Test 1: Compare DOCX XML
    print("## Test 1: Word → Markdown → Word (XML Comparison)")
    print("-" * 40)

    source_docx = os.path.join(TEST_DIR, 'source.docx')
    roundtrip_docx = os.path.join(TEST_DIR, 'step2_docx_from_md.docx')

    xml1 = extract_document_xml(source_docx)
    xml2 = extract_document_xml(roundtrip_docx)

    # Simple size comparison
    print(f"Source DOCX XML size:     {len(xml1):,} bytes")
    print(f"Round-trip DOCX XML size: {len(xml2):,} bytes")
    print(f"Size difference:          {len(xml2) - len(xml1):+,} bytes")
    print()

    # Count key elements
    for element in ['<w:p>', '<w:t>', '<w:tbl>', '<w:tr>']:
        count1 = xml1.count(element)
        count2 = xml2.count(element)
        status = "✓" if count1 == count2 else "≠"
        print(f"  {element}: {count1} → {count2} {status}")
    print()

    # Test 2: Compare Markdown
    print("## Test 2: Markdown Comparison (step1 vs step3)")
    print("-" * 40)

    md1 = os.path.join(TEST_DIR, 'step1_md_from_docx.md')
    md3 = os.path.join(TEST_DIR, 'step3_md_from_round_trip.md')

    diff = compare_files(md1, md3)

    if diff:
        print("Differences found:")
        for line in diff[:30]:  # Limit output
            print(f"  {line}")
        if len(diff) > 30:
            print(f"  ... and {len(diff) - 30} more lines")
    else:
        print("✓ No differences! Markdown files are identical.")
    print()

    # Summary
    print("=" * 60)
    print("SUMMARY")
    print("=" * 60)
    print()

    # Check header counts
    with open(md1, encoding='utf-8') as f:
        md1_content = f.read()
    with open(md3, encoding='utf-8') as f:
        md3_content = f.read()

    h1_count1 = md1_content.count('\n# ') + (1 if md1_content.startswith('# ') else 0)
    h1_count3 = md3_content.count('\n# ') + (1 if md3_content.startswith('# ') else 0)

    print(f"Headers (H1): step1={h1_count1}, step3={h1_count3}")
    print(f"Tables: step1={'|' in md1_content}, step3={'|' in md3_content}")
    print()

    if not diff:
        print("✓ PASS: Round-trip conversion maintains fidelity!")
    else:
        print("⚠ ATTENTION: Some differences detected in round-trip")

if __name__ == '__main__':
    main()
