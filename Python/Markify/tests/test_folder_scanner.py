"""
Unit tests for the folder scanning utilities.
"""
import unittest
import sys
import os
import tempfile
import shutil

# Add src to path for imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from core.folder_scanner import (
    is_convertible_file,
    scan_folder,
    expand_paths,
    get_folder_stats,
    DEFAULT_EXTENSIONS
)


class TestIsConvertibleFile(unittest.TestCase):
    """Tests for the is_convertible_file() function."""
    
    def test_docx_file(self):
        """Test that .docx files are convertible."""
        self.assertTrue(is_convertible_file("document.docx"))
        self.assertTrue(is_convertible_file("path/to/file.DOCX"))  # case insensitive
    
    def test_xlsx_file(self):
        """Test that .xlsx files are convertible."""
        self.assertTrue(is_convertible_file("spreadsheet.xlsx"))
        self.assertTrue(is_convertible_file("path/to/file.XLSX"))
    
    def test_non_convertible_files(self):
        """Test that other file types are not convertible."""
        self.assertFalse(is_convertible_file("document.pdf"))
        self.assertFalse(is_convertible_file("image.png"))
        self.assertFalse(is_convertible_file("script.py"))
        self.assertFalse(is_convertible_file("readme.md"))
        self.assertFalse(is_convertible_file("archive.zip"))
    
    def test_custom_extensions(self):
        """Test custom extension filtering."""
        custom_exts = {'.txt', '.md'}
        self.assertTrue(is_convertible_file("notes.txt", custom_exts))
        self.assertTrue(is_convertible_file("readme.md", custom_exts))
        self.assertFalse(is_convertible_file("doc.docx", custom_exts))


class TestScanFolder(unittest.TestCase):
    """Tests for the scan_folder() function."""
    
    def setUp(self):
        """Create a temporary directory structure for testing."""
        self.test_dir = tempfile.mkdtemp()
        
        # Create test file structure:
        # test_dir/
        #   ├── doc1.docx
        #   ├── sheet1.xlsx
        #   ├── readme.md
        #   ├── subdir/
        #   │   ├── doc2.docx
        #   │   └── notes.txt
        #   └── empty_subdir/
        
        # Create files in root
        open(os.path.join(self.test_dir, "doc1.docx"), 'w').close()
        open(os.path.join(self.test_dir, "sheet1.xlsx"), 'w').close()
        open(os.path.join(self.test_dir, "readme.md"), 'w').close()
        
        # Create subdir with files
        subdir = os.path.join(self.test_dir, "subdir")
        os.makedirs(subdir)
        open(os.path.join(subdir, "doc2.docx"), 'w').close()
        open(os.path.join(subdir, "notes.txt"), 'w').close()
        
        # Create empty subdir
        os.makedirs(os.path.join(self.test_dir, "empty_subdir"))
    
    def tearDown(self):
        """Clean up temporary directory."""
        shutil.rmtree(self.test_dir)
    
    def test_recursive_scan(self):
        """Test recursive folder scanning."""
        results = scan_folder(self.test_dir, recursive=True)
        self.assertEqual(len(results), 3)  # doc1.docx, sheet1.xlsx, subdir/doc2.docx
        
        # Check that all results are absolute paths
        for path in results:
            self.assertTrue(os.path.isabs(path) or os.path.exists(path))
    
    def test_non_recursive_scan(self):
        """Test non-recursive folder scanning."""
        results = scan_folder(self.test_dir, recursive=False)
        self.assertEqual(len(results), 2)  # Only doc1.docx and sheet1.xlsx
    
    def test_scan_nonexistent_folder(self):
        """Test scanning a folder that doesn't exist."""
        results = scan_folder("/nonexistent/path")
        self.assertEqual(results, [])
    
    def test_scan_empty_folder(self):
        """Test scanning an empty folder."""
        empty_dir = os.path.join(self.test_dir, "empty_subdir")
        results = scan_folder(empty_dir)
        self.assertEqual(results, [])
    
    def test_results_sorted(self):
        """Test that results are sorted alphabetically."""
        results = scan_folder(self.test_dir, recursive=True)
        self.assertEqual(results, sorted(results))


class TestExpandPaths(unittest.TestCase):
    """Tests for the expand_paths() function."""
    
    def setUp(self):
        """Create temporary test files and directories."""
        self.test_dir = tempfile.mkdtemp()
        
        # Create test files
        self.docx_file = os.path.join(self.test_dir, "test.docx")
        self.xlsx_file = os.path.join(self.test_dir, "test.xlsx")
        self.txt_file = os.path.join(self.test_dir, "test.txt")
        
        open(self.docx_file, 'w').close()
        open(self.xlsx_file, 'w').close()
        open(self.txt_file, 'w').close()
        
        # Create subfolder with files
        self.subdir = os.path.join(self.test_dir, "subfolder")
        os.makedirs(self.subdir)
        open(os.path.join(self.subdir, "nested.docx"), 'w').close()
    
    def tearDown(self):
        """Clean up temporary directory."""
        shutil.rmtree(self.test_dir)
    
    def test_expand_single_file(self):
        """Test expanding a single file path."""
        results = expand_paths([self.docx_file])
        self.assertEqual(len(results), 1)
        self.assertIn(os.path.abspath(self.docx_file), results)
    
    def test_expand_folder(self):
        """Test expanding a folder to its files."""
        results = expand_paths([self.test_dir])
        self.assertEqual(len(results), 3)  # test.docx, test.xlsx, subfolder/nested.docx
    
    def test_expand_mixed_paths(self):
        """Test expanding a mix of files and folders."""
        results = expand_paths([self.docx_file, self.subdir])
        # Should include docx_file and nested.docx (no duplicates)
        self.assertEqual(len(results), 2)
    
    def test_no_duplicates(self):
        """Test that duplicate paths are eliminated."""
        results = expand_paths([self.docx_file, self.docx_file, self.test_dir])
        # Should not have duplicates
        self.assertEqual(len(results), len(set(results)))
    
    def test_filter_invalid_extensions(self):
        """Test that non-convertible files are filtered."""
        results = expand_paths([self.txt_file])
        self.assertEqual(results, [])


class TestGetFolderStats(unittest.TestCase):
    """Tests for the get_folder_stats() function."""
    
    def setUp(self):
        """Create temporary test directory."""
        self.test_dir = tempfile.mkdtemp()
        
        # Create files
        open(os.path.join(self.test_dir, "doc1.docx"), 'w').close()
        open(os.path.join(self.test_dir, "doc2.docx"), 'w').close()
        
        # Create subfolder with one file
        subdir = os.path.join(self.test_dir, "sub")
        os.makedirs(subdir)
        open(os.path.join(subdir, "sheet.xlsx"), 'w').close()
    
    def tearDown(self):
        """Clean up temporary directory."""
        shutil.rmtree(self.test_dir)
    
    def test_folder_stats(self):
        """Test getting folder statistics."""
        file_count, folder_count = get_folder_stats(self.test_dir)
        self.assertEqual(file_count, 3)  # doc1, doc2, sheet
        self.assertEqual(folder_count, 2)  # root and sub
    
    def test_nonexistent_folder_stats(self):
        """Test stats for nonexistent folder."""
        file_count, folder_count = get_folder_stats("/nonexistent")
        self.assertEqual(file_count, 0)
        self.assertEqual(folder_count, 0)


if __name__ == '__main__':
    unittest.main()
