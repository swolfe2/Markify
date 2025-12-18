#!/usr/bin/env python
"""
Round-Trip Fidelity Test CLI

Test conversion fidelity for Word <-> Markdown conversions.

Usage:
    python -m cli.round_trip_test --source file.docx --mode docx
    python -m cli.round_trip_test --source file.md --mode md
    python -m cli.round_trip_test --all --output-dir ./test_output
"""
import argparse
import os
import sys
import tempfile
import zipfile
import re

# Add src to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from markify_core import get_docx_content
from core.md_to_docx import create_docx


def extract_document_xml(docx_path: str) -> str:
    """Extract document.xml content from a DOCX file."""
    with zipfile.ZipFile(docx_path, 'r') as zf:
        return zf.read('word/document.xml').decode('utf-8')


def count_xml_elements(xml_content: str) -> dict:
    """Count key XML elements in document.xml."""
    return {
        'paragraphs': xml_content.count('<w:p>') + xml_content.count('<w:p '),
        'text_runs': xml_content.count('<w:t>') + xml_content.count('<w:t '),
        'tables': xml_content.count('<w:tbl>') + xml_content.count('<w:tbl '),
        'table_rows': xml_content.count('<w:tr>') + xml_content.count('<w:tr '),
    }


def count_md_elements(md_content: str) -> dict:
    """Count key Markdown elements."""
    lines = md_content.split('\n')
    return {
        'h1': sum(1 for l in lines if l.startswith('# ') and not l.startswith('## ')),
        'h2': sum(1 for l in lines if l.startswith('## ') and not l.startswith('### ')),
        'h3': sum(1 for l in lines if l.startswith('### ')),
        'table_rows': sum(1 for l in lines if '|' in l and not l.strip().startswith('|---')),
        'code_blocks': md_content.count('```') // 2,
        'links': len(re.findall(r'\[.*?\]\(.*?\)', md_content)),
        'total_lines': len([l for l in lines if l.strip()]),
    }


def test_docx_round_trip(source_path: str, output_dir: str) -> dict:
    """Test Word -> Markdown -> Word round-trip."""
    print("\n" + "=" * 60)
    print("TEST: Word -> Markdown -> Word")
    print("=" * 60)
    print(f"Source: {source_path}")
    
    results = {'passed': True, 'errors': []}
    
    # Step 1: DOCX -> MD
    print("\n[1/3] Converting DOCX -> Markdown...")
    md_lines = get_docx_content(source_path)
    md_content = '\n\n'.join(md_lines)
    
    step1_path = os.path.join(output_dir, 'step1_md_from_docx.md')
    with open(step1_path, 'w', encoding='utf-8') as f:
        f.write(md_content)
    print(f"      Output: {step1_path}")
    
    source_md_elements = count_md_elements(md_content)
    print(f"      Elements: H1={source_md_elements['h1']}, H2={source_md_elements['h2']}, Tables={source_md_elements['table_rows']} rows")
    
    # Step 2: MD -> DOCX
    print("\n[2/3] Converting Markdown -> DOCX...")
    step2_path = os.path.join(output_dir, 'step2_docx_from_md.docx')
    create_docx(md_content, step2_path)
    print(f"      Output: {step2_path}")
    
    # Step 3: DOCX -> MD
    print("\n[3/3] Converting round-trip DOCX -> Markdown...")
    md_lines2 = get_docx_content(step2_path)
    md_content2 = '\n\n'.join(md_lines2)
    
    step3_path = os.path.join(output_dir, 'step3_md_round_trip.md')
    with open(step3_path, 'w', encoding='utf-8') as f:
        f.write(md_content2)
    print(f"      Output: {step3_path}")
    
    roundtrip_md_elements = count_md_elements(md_content2)
    
    # Compare
    print("\n--- Comparison ---")
    
    if source_md_elements['h1'] == roundtrip_md_elements['h1']:
        print(f"[PASS] H1 headers: {source_md_elements['h1']} == {roundtrip_md_elements['h1']}")
    else:
        print(f"[FAIL] H1 headers: {source_md_elements['h1']} != {roundtrip_md_elements['h1']}")
        results['passed'] = False
        results['errors'].append('H1 count mismatch')
    
    if source_md_elements['h2'] == roundtrip_md_elements['h2']:
        print(f"[PASS] H2 headers: {source_md_elements['h2']} == {roundtrip_md_elements['h2']}")
    else:
        print(f"[FAIL] H2 headers: {source_md_elements['h2']} != {roundtrip_md_elements['h2']}")
        results['passed'] = False
        results['errors'].append('H2 count mismatch')
    
    # XML comparison
    source_xml = extract_document_xml(source_path)
    roundtrip_xml = extract_document_xml(step2_path)
    
    source_counts = count_xml_elements(source_xml)
    roundtrip_counts = count_xml_elements(roundtrip_xml)
    
    print("\nXML Elements:")
    print(f"  Source paragraphs:    {source_counts['paragraphs']}")
    print(f"  Round-trip paragraphs: {roundtrip_counts['paragraphs']}")
    print(f"  Source tables:        {source_counts['tables']}")
    print(f"  Round-trip tables:    {roundtrip_counts['tables']}")
    
    return results


def test_md_round_trip(source_path: str, output_dir: str) -> dict:
    """Test Markdown -> Word -> Markdown round-trip."""
    print("\n" + "=" * 60)
    print("TEST: Markdown -> Word -> Markdown")
    print("=" * 60)
    print(f"Source: {source_path}")
    
    results = {'passed': True, 'errors': []}
    
    # Read source
    with open(source_path, 'r', encoding='utf-8') as f:
        source_md = f.read()
    
    source_elements = count_md_elements(source_md)
    print(f"\nSource elements: H1={source_elements['h1']}, H2={source_elements['h2']}, Code={source_elements['code_blocks']}")
    
    # Step 1: MD -> DOCX
    print("\n[1/2] Converting Markdown -> DOCX...")
    step1_path = os.path.join(output_dir, 'step1_docx_from_md.docx')
    create_docx(source_md, step1_path)
    print(f"      Output: {step1_path}")
    
    # Step 2: DOCX -> MD
    print("\n[2/2] Converting DOCX -> Markdown...")
    md_lines = get_docx_content(step1_path)
    roundtrip_md = '\n\n'.join(md_lines)
    
    step2_path = os.path.join(output_dir, 'step2_md_round_trip.md')
    with open(step2_path, 'w', encoding='utf-8') as f:
        f.write(roundtrip_md)
    print(f"      Output: {step2_path}")
    
    roundtrip_elements = count_md_elements(roundtrip_md)
    
    # Compare
    print("\n--- Comparison ---")
    
    if source_elements['h1'] == roundtrip_elements['h1']:
        print(f"[PASS] H1 headers: {source_elements['h1']} == {roundtrip_elements['h1']}")
    else:
        print(f"[FAIL] H1 headers: {source_elements['h1']} != {roundtrip_elements['h1']}")
        results['passed'] = False
    
    if source_elements['h2'] == roundtrip_elements['h2']:
        print(f"[PASS] H2 headers: {source_elements['h2']} == {roundtrip_elements['h2']}")
    else:
        print(f"[FAIL] H2 headers: {source_elements['h2']} != {roundtrip_elements['h2']}")
        results['passed'] = False
    
    return results


def run_all_tests(output_dir: str) -> bool:
    """Run all round-trip tests using sample files."""
    samples_dir = os.path.join(os.path.dirname(__file__), '..', '..', 'samples')
    
    docx_path = os.path.join(samples_dir, 'Markify_Demo.docx')
    md_path = os.path.join(samples_dir, 'Markify_Demo.md')
    
    all_passed = True
    
    if os.path.exists(docx_path):
        docx_output = os.path.join(output_dir, 'docx_test')
        os.makedirs(docx_output, exist_ok=True)
        result = test_docx_round_trip(docx_path, docx_output)
        if not result['passed']:
            all_passed = False
    else:
        print(f"Warning: Sample DOCX not found: {docx_path}")
    
    if os.path.exists(md_path):
        md_output = os.path.join(output_dir, 'md_test')
        os.makedirs(md_output, exist_ok=True)
        result = test_md_round_trip(md_path, md_output)
        if not result['passed']:
            all_passed = False
    else:
        print(f"Warning: Sample MD not found: {md_path}")
    
    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    print(f"Result: {'PASSED' if all_passed else 'FAILED'}")
    print(f"Output directory: {output_dir}")
    
    return all_passed


def main():
    parser = argparse.ArgumentParser(
        description='Round-trip fidelity test for Word <-> Markdown conversions'
    )
    parser.add_argument('--source', help='Source file to test')
    parser.add_argument('--mode', choices=['docx', 'md'], help='Source file type')
    parser.add_argument('--all', action='store_true', help='Run all tests with sample files')
    parser.add_argument('--output-dir', help='Output directory for test files')
    
    args = parser.parse_args()
    
    # Determine output directory
    if args.output_dir:
        output_dir = args.output_dir
    else:
        output_dir = tempfile.mkdtemp(prefix='markify_round_trip_')
    
    os.makedirs(output_dir, exist_ok=True)
    
    if args.all:
        success = run_all_tests(output_dir)
        sys.exit(0 if success else 1)
    elif args.source and args.mode:
        if not os.path.exists(args.source):
            print(f"Error: Source file not found: {args.source}")
            sys.exit(1)
        
        if args.mode == 'docx':
            result = test_docx_round_trip(args.source, output_dir)
        else:
            result = test_md_round_trip(args.source, output_dir)
        
        sys.exit(0 if result['passed'] else 1)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == '__main__':
    main()
