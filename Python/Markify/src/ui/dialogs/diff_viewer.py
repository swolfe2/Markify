"""
Diff View dialog for Markify.
Compares two text files side-by-side with diff highlighting.
Zero dependencies - uses Python's built-in difflib.
"""
from __future__ import annotations

import os
import tkinter as tk
from tkinter import ttk, filedialog
import difflib
from typing import Optional, List, Tuple


class DiffViewerDialog:
    """Side-by-side diff viewer dialog."""
    
    def __init__(
        self, 
        parent: tk.Tk,
        colors: dict,
        file1_path: Optional[str] = None,
        file2_path: Optional[str] = None,
        icon_path: str = None
    ):
        """
        Create a diff viewer dialog.
        
        Args:
            parent: Parent window
            colors: Theme color dictionary
            file1_path: Optional path to first file
            file2_path: Optional path to second file
            icon_path: Path to application icon
        """
        self.parent = parent
        self.colors = colors
        self.file1_path = file1_path
        self.file2_path = file2_path
        
        # Create dialog window
        self.dialog = tk.Toplevel(parent)
        self.dialog.title("Diff View")
        self.dialog.geometry("1000x700")
        self.dialog.configure(bg=colors["bg"])
        self.dialog.transient(parent)
        
        # Set icon if provided
        if icon_path:
            try:
                self.dialog.iconbitmap(icon_path)
            except Exception:
                pass
        
        self._create_widgets()
        
        # Load files if provided
        if file1_path and file2_path:
            self._load_and_compare()
    
    def _create_widgets(self):
        """Create dialog widgets."""
        c = self.colors
        
        # Top bar with file selectors
        top_frame = tk.Frame(self.dialog, bg=c["bg"])
        top_frame.pack(fill=tk.X, padx=10, pady=10)
        
        # Left file selector
        left_frame = tk.Frame(top_frame, bg=c["bg"])
        left_frame.pack(side=tk.LEFT, expand=True, fill=tk.X)
        
        tk.Label(
            left_frame, text="File 1:", bg=c["bg"], fg=c["fg"],
            font=("Segoe UI", 10, "bold")
        ).pack(side=tk.LEFT, padx=(0, 5))
        
        self.file1_var = tk.StringVar(value=self.file1_path or "")
        self.file1_entry = tk.Entry(
            left_frame, textvariable=self.file1_var,
            bg=c["secondary_bg"], fg=c["fg"],
            insertbackground=c["fg"], width=40
        )
        self.file1_entry.pack(side=tk.LEFT, expand=True, fill=tk.X)
        
        tk.Button(
            left_frame, text="Browse", command=self._browse_file1,
            bg=c["secondary_bg"], fg=c["fg"]
        ).pack(side=tk.LEFT, padx=5)
        
        # Right file selector
        right_frame = tk.Frame(top_frame, bg=c["bg"])
        right_frame.pack(side=tk.RIGHT, expand=True, fill=tk.X, padx=(20, 0))
        
        tk.Label(
            right_frame, text="File 2:", bg=c["bg"], fg=c["fg"],
            font=("Segoe UI", 10, "bold")
        ).pack(side=tk.LEFT, padx=(0, 5))
        
        self.file2_var = tk.StringVar(value=self.file2_path or "")
        self.file2_entry = tk.Entry(
            right_frame, textvariable=self.file2_var,
            bg=c["secondary_bg"], fg=c["fg"],
            insertbackground=c["fg"], width=40
        )
        self.file2_entry.pack(side=tk.LEFT, expand=True, fill=tk.X)
        
        tk.Button(
            right_frame, text="Browse", command=self._browse_file2,
            bg=c["secondary_bg"], fg=c["fg"]
        ).pack(side=tk.LEFT, padx=5)
        
        # Compare button
        btn_frame = tk.Frame(self.dialog, bg=c["bg"])
        btn_frame.pack(fill=tk.X, padx=10, pady=(0, 10))
        
        self.compare_btn = tk.Button(
            btn_frame, text="Compare Files",
            command=self._load_and_compare,
            bg=c["accent"], fg=c.get("accent_fg", "#ffffff"),
            font=("Segoe UI", 10, "bold"),
            cursor="hand2"
        )
        self.compare_btn.pack()
        
        # Split view for diff
        paned = tk.PanedWindow(
            self.dialog, orient=tk.HORIZONTAL,
            bg=c["border"], sashwidth=4
        )
        paned.pack(fill=tk.BOTH, expand=True, padx=10, pady=(0, 10))
        
        # Left text area (File 1)
        left_text_frame = tk.Frame(paned, bg=c["secondary_bg"])
        paned.add(left_text_frame, stretch="always")
        
        tk.Label(
            left_text_frame, text="Original",
            bg=c["secondary_bg"], fg=c["fg"],
            font=("Segoe UI", 9, "bold")
        ).pack(anchor=tk.W, padx=5, pady=2)
        
        # Scrollbar first, then text widget
        self.left_scroll = ttk.Scrollbar(left_text_frame)
        self.left_scroll.pack(side=tk.RIGHT, fill=tk.Y)
        
        self.left_text = tk.Text(
            left_text_frame, wrap=tk.WORD,
            bg=c["secondary_bg"], fg=c["fg"],
            font=("Consolas", 10),
            insertbackground=c["fg"],
            yscrollcommand=self.left_scroll.set
        )
        self.left_text.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        self.left_scroll.config(command=self.left_text.yview)
        
        # Right text area (File 2)
        right_text_frame = tk.Frame(paned, bg=c["secondary_bg"])
        paned.add(right_text_frame, stretch="always")
        
        tk.Label(
            right_text_frame, text="Modified",
            bg=c["secondary_bg"], fg=c["fg"],
            font=("Segoe UI", 9, "bold")
        ).pack(anchor=tk.W, padx=5, pady=2)
        
        # Scrollbar first, then text widget
        self.right_scroll = ttk.Scrollbar(right_text_frame)
        self.right_scroll.pack(side=tk.RIGHT, fill=tk.Y)
        
        self.right_text = tk.Text(
            right_text_frame, wrap=tk.WORD,
            bg=c["secondary_bg"], fg=c["fg"],
            font=("Consolas", 10),
            insertbackground=c["fg"],
            yscrollcommand=self.right_scroll.set
        )
        self.right_text.pack(side=tk.LEFT, fill=tk.BOTH, expand=True)
        self.right_scroll.config(command=self.right_text.yview)
        
        # Configure tags for diff highlighting
        self._configure_tags()
        
        # Sync scrolling
        self._setup_scroll_sync()
        
        # Status bar
        self.status_var = tk.StringVar(value="Select two files to compare")
        tk.Label(
            self.dialog, textvariable=self.status_var,
            bg=c["bg"], fg=c.get("fg_secondary", c["fg"]),
            font=("Segoe UI", 9)
        ).pack(pady=5)
    
    def _configure_tags(self):
        """Configure text tags for diff highlighting."""
        # Addition (green)
        self.left_text.tag_configure("add", background="#2d5a2d", foreground="#90ee90")
        self.right_text.tag_configure("add", background="#2d5a2d", foreground="#90ee90")
        
        # Deletion (red)
        self.left_text.tag_configure("del", background="#5a2d2d", foreground="#ff9090")
        self.right_text.tag_configure("del", background="#5a2d2d", foreground="#ff9090")
        
        # Changed (yellow)
        self.left_text.tag_configure("change", background="#5a5a2d", foreground="#eeee90")
        self.right_text.tag_configure("change", background="#5a5a2d", foreground="#eeee90")
    
    def _setup_scroll_sync(self):
        """Setup synchronized scrolling between the two text widgets."""
        def sync_scroll_left(*args):
            """Sync left scroll to right."""
            self.left_scroll.set(*args)
            self.right_text.yview_moveto(args[0])
        
        def sync_scroll_right(*args):
            """Sync right scroll to left."""
            self.right_scroll.set(*args)
            self.left_text.yview_moveto(args[0])
        
        # Update yscrollcommand to sync both sides
        self.left_text.config(yscrollcommand=sync_scroll_left)
        self.right_text.config(yscrollcommand=sync_scroll_right)
    
    def _browse_file1(self):
        """Browse for first file."""
        path = filedialog.askopenfilename(
            title="Select First File",
            filetypes=[("Text/Markdown", "*.md *.txt"), ("All Files", "*.*")]
        )
        if path:
            self.file1_var.set(path)
            self.file1_path = path
    
    def _browse_file2(self):
        """Browse for second file."""
        path = filedialog.askopenfilename(
            title="Select Second File",
            filetypes=[("Text/Markdown", "*.md *.txt"), ("All Files", "*.*")]
        )
        if path:
            self.file2_var.set(path)
            self.file2_path = path
    
    def _load_and_compare(self):
        """Load files and perform comparison."""
        file1 = self.file1_var.get()
        file2 = self.file2_var.get()
        
        if not file1 or not file2:
            self.status_var.set("Please select both files")
            return
        
        if not os.path.exists(file1):
            self.status_var.set(f"File not found: {file1}")
            return
        
        if not os.path.exists(file2):
            self.status_var.set(f"File not found: {file2}")
            return
        
        try:
            with open(file1, 'r', encoding='utf-8') as f:
                lines1 = f.readlines()
            with open(file2, 'r', encoding='utf-8') as f:
                lines2 = f.readlines()
        except Exception as e:
            self.status_var.set(f"Error reading files: {e}")
            return
        
        self._display_diff(lines1, lines2)
    
    def _display_diff(self, lines1: List[str], lines2: List[str]):
        """Display diff between two sets of lines."""
        # Clear existing content
        self.left_text.delete("1.0", tk.END)
        self.right_text.delete("1.0", tk.END)
        
        # Get diff
        differ = difflib.Differ()
        diff = list(differ.compare(lines1, lines2))
        
        additions = 0
        deletions = 0
        
        left_line = 1
        right_line = 1
        
        for item in diff:
            code = item[0]
            line = item[2:]
            
            if code == ' ':
                # Unchanged line
                self.left_text.insert(tk.END, line)
                self.right_text.insert(tk.END, line)
                left_line += 1
                right_line += 1
            elif code == '-':
                # Deleted from file1
                self.left_text.insert(tk.END, line, "del")
                deletions += 1
                left_line += 1
            elif code == '+':
                # Added in file2
                self.right_text.insert(tk.END, line, "add")
                additions += 1
                right_line += 1
        
        self.status_var.set(
            f"Comparison complete: {additions} additions, {deletions} deletions"
        )


def show_diff_viewer(parent: tk.Tk, colors: dict, icon_path: str = None):
    """Show the diff viewer dialog."""
    DiffViewerDialog(parent, colors, icon_path=icon_path)


# Utility functions for programmatic comparison
def get_diff_lines(text1: str, text2: str) -> List[Tuple[str, str, str]]:
    """
    Get diff between two texts.
    
    Args:
        text1: First text content
        text2: Second text content
    
    Returns:
        List of tuples: (status, left_line, right_line)
        status: 'same', 'add', 'del', 'change'
    """
    lines1 = text1.splitlines(keepends=True)
    lines2 = text2.splitlines(keepends=True)
    
    matcher = difflib.SequenceMatcher(None, lines1, lines2)
    result = []
    
    for tag, i1, i2, j1, j2 in matcher.get_opcodes():
        if tag == 'equal':
            for line in lines1[i1:i2]:
                result.append(('same', line, line))
        elif tag == 'delete':
            for line in lines1[i1:i2]:
                result.append(('del', line, ''))
        elif tag == 'insert':
            for line in lines2[j1:j2]:
                result.append(('add', '', line))
        elif tag == 'replace':
            for line in lines1[i1:i2]:
                result.append(('del', line, ''))
            for line in lines2[j1:j2]:
                result.append(('add', '', line))
    
    return result


def get_unified_diff(text1: str, text2: str, file1: str = "file1", file2: str = "file2") -> str:
    """
    Get unified diff format string.
    
    Args:
        text1: First text content
        text2: Second text content
        file1: Label for first file
        file2: Label for second file
    
    Returns:
        Unified diff string
    """
    lines1 = text1.splitlines(keepends=True)
    lines2 = text2.splitlines(keepends=True)
    
    diff = difflib.unified_diff(lines1, lines2, fromfile=file1, tofile=file2)
    return ''.join(diff)
