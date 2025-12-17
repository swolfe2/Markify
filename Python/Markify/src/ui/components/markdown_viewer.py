import tkinter as tk
from tkinter import ttk
import re

class MarkdownViewer:
    def __init__(self, parent, filepath, colors):
        self.colors = colors
        c = self.colors
        
        self.top = tk.Toplevel(parent)
        self.top.title("Documentation")
        
        # Center on parent window, but ensure it stays on screen
        w, h = 1000, 700
        parent.update_idletasks()
        
        # Get screen dimensions
        screen_w = parent.winfo_screenwidth()
        screen_h = parent.winfo_screenheight()
        
        # Calculate centered position
        px = parent.winfo_x()
        py = parent.winfo_y()
        pw = parent.winfo_width()
        ph = parent.winfo_height()
        x = px + (pw // 2) - (w // 2)
        y = py + (ph // 2) - (h // 2)
        
        # Ensure window stays on screen
        x = max(0, min(x, screen_w - w))
        y = max(0, min(y, screen_h - h - 40))  # -40 for taskbar
        
        self.top.geometry(f"{w}x{h}+{x}+{y}")
        
        self.top.configure(bg=c["bg"])
        
        # Text Widget
        self.text_area = tk.Text(
            self.top, 
            bg=c["bg"], 
            fg=c["fg"], 
            font=("Segoe UI", 11),
            relief=tk.FLAT,
            padx=20,
            pady=20,
            wrap=tk.WORD
        )
        self.text_area.pack(fill=tk.BOTH, expand=True, side=tk.LEFT)
        
        # Scrollbar
        scroll = ttk.Scrollbar(self.top, command=self.text_area.yview)
        scroll.pack(fill=tk.Y, side=tk.RIGHT)
        self.text_area.configure(yscrollcommand=scroll.set)
        
        # Configure Markdown Styles
        self.text_area.tag_configure("h1", font=("Segoe UI", 22, "bold"), foreground=c["accent_hover"], spacing3=10)
        self.text_area.tag_configure("h2", font=("Segoe UI", 16, "bold"), foreground=c["fg"], spacing3=5, spacing1=15)
        self.text_area.tag_configure("h3", font=("Segoe UI", 12, "bold"), foreground=c["muted"], spacing3=5)
        self.text_area.tag_configure("code", font=("Consolas", 10), background=c["secondary_bg"])
        self.text_area.tag_configure("block", font=("Consolas", 10), background=c["secondary_bg"], lmargin1=20, lmargin2=20)
        self.text_area.tag_configure("bold", font=("Segoe UI", 11, "bold"))
        self.text_area.tag_configure("italic", font=("Segoe UI", 11, "italic"))
        
        # Table style
        self.text_area.tag_configure("table", font=("Consolas", 9), background=c["secondary_bg"], lmargin1=10, lmargin2=10)

        
        # Configure Multi-level List Styles
        # Level 0 (Bullet)
        self.text_area.tag_configure("list-0", lmargin1=20, lmargin2=40)
        # Level 1 (Nested 1 deep)
        self.text_area.tag_configure("list-1", lmargin1=50, lmargin2=70)
        # Level 2 (Nested 2 deep)
        self.text_area.tag_configure("list-2", lmargin1=80, lmargin2=100)
        
        self.load_markdown(filepath)
        self.text_area.configure(state=tk.DISABLED) # Read-only

    def load_markdown(self, filepath):
        with open(filepath, 'r', encoding='utf-8') as f:
            lines = f.readlines()
            
        in_block = False
        in_table = False
        table_lines = []
        
        for line in lines:
            stripped = line.strip()
            
            # --- Skip Image Syntax (can't render in text widget) ---
            if stripped.startswith("!["):
                self.text_area.insert(tk.END, "(See README for demo animation)\n\n", "italic")
                continue
            
            # --- Code Blocks ---
            if stripped.startswith("```"):
                in_block = not in_block
                continue
            
            if in_block:
                self.text_area.insert(tk.END, line, "block")
                continue
                
            # --- Headers ---
            if stripped.startswith("# "):
                self.insert_formatted(stripped[2:] + "\n", ["h1"])
            elif stripped.startswith("## "):
                self.insert_formatted(stripped[3:] + "\n", ["h2"])
            elif stripped.startswith("### "):
                self.insert_formatted(stripped[4:] + "\n", ["h3"])
            
            # --- Lists ---
            elif re.match(r'^\s*[\-\*]\s+', line): # Check raw line for regex to support indent check, but strip for matching
                # specific list item match
                match = re.match(r'^(\s*)[\-\*]\s+(.*)', line)
                if match:
                    indent_str = match.group(1)
                    content = match.group(2)
                    
                    # Calculate indent level (assume 2 spaces or 4 spaces per level)
                    # Simple heuristic: len(indent) // 2
                    level = len(indent_str) // 2
                    if level > 2: 
                        level = 2 # Cap at level 2 for defined defined styles
                    
                    tag = f"list-{level}"
                    self.text_area.insert(tk.END, " • ", tag)
                    self.insert_formatted(content + "\n", [tag])
                else: 
                     # Fallback if regex logic mismatches (shouldnt happen)
                     self.insert_formatted(line, [])

            elif re.match(r'^\s*\d+\.\s+', line):
                 # Numbered lists (similar logic can be applied, or simplified)
                 self.insert_formatted(" " + stripped + "\n", ["list-0"])
                 
            # --- Regular Text ---
            else:
                # Check if this is a table line
                if stripped.startswith('|') and stripped.endswith('|'):
                    # Accumulate table lines
                    if not in_table:
                        in_table = True
                        table_lines = []
                    table_lines.append(stripped)
                else:
                    # If we were in a table, render it now
                    if in_table:
                        self.render_table(table_lines)
                        in_table = False
                        table_lines = []
                    self.insert_formatted(line, [])
        
        # Handle table at end of file
        if in_table and table_lines:
            self.render_table(table_lines)

    def render_table(self, lines):
        """Render a markdown table in a readable format."""
        if len(lines) < 2:
            # Not enough lines for a valid table
            for line in lines:
                self.text_area.insert(tk.END, line + "\n", "table")
            return
        
        # Parse table
        rows = []
        for i, line in enumerate(lines):
            # Skip separator line (contains only |, -, :, spaces)
            if i == 1 and all(c in '|-: ' for c in line):
                continue
            # Split cells
            cells = [cell.strip() for cell in line.split('|')[1:-1]]  # Remove empty first/last
            rows.append(cells)
        
        if not rows:
            return
        
        # Calculate column widths
        num_cols = max(len(row) for row in rows)
        col_widths = [0] * num_cols
        for row in rows:
            for i, cell in enumerate(row):
                if i < num_cols:
                    col_widths[i] = max(col_widths[i], len(cell))
        
        # Render header
        if rows:
            header = rows[0]
            header_text = " │ ".join(cell.ljust(col_widths[i]) for i, cell in enumerate(header))
            self.text_area.insert(tk.END, f"  {header_text}\n", ["table", "bold"])
            
            # Separator
            sep = "─┼─".join("─" * col_widths[i] for i in range(num_cols))
            self.text_area.insert(tk.END, f"  {sep}\n", "table")
            
            # Data rows
            for row in rows[1:]:
                # Pad row to have correct number of columns
                while len(row) < num_cols:
                    row.append("")
                row_text = " │ ".join(cell.ljust(col_widths[i]) for i, cell in enumerate(row))
                self.text_area.insert(tk.END, f"  {row_text}\n", "table")
        
        self.text_area.insert(tk.END, "\n")  # Spacing after table


    def insert_formatted(self, text, base_tags):
        """Parses inline bold (**), italic (*), and code (`) and inserts styled chunks."""
        # import re # Already imported at top
        
        # Regex to capture:
        # Group 1: Bold (**text**)
        # Group 2: Italic (*text* - careful not to match * in bold)
        # Group 3: Code (`text`)
        # Note: Order matters. Check Bold before Italic.
        pattern = r'(\*\*(.*?)\*\*)|(\*(.*?)\*)|(`(.*?)`)'
        
        last_idx = 0
        for match in re.finditer(pattern, text):
            # Insert preceding text
            pre_text = text[last_idx:match.start()]
            if pre_text:
                self.text_area.insert(tk.END, pre_text, base_tags)
            
            # Identify match type
            if match.group(2) is not None:
                # Bold match (Group 1 is outer, Group 2 is inner)
                content = match.group(2)
                self.text_area.insert(tk.END, content, base_tags + ["bold"])
            elif match.group(4) is not None:
                # Italic match (Group 3 is outer, Group 4 is inner)
                content = match.group(4)
                self.text_area.insert(tk.END, content, base_tags + ["italic"])
            elif match.group(6) is not None:
                # Code match (Group 5 is outer, Group 6 is inner)
                content = match.group(6)
                self.text_area.insert(tk.END, content, base_tags + ["code"])
                
            last_idx = match.end()
            
        # Insert remaining text
        if last_idx < len(text):
            self.text_area.insert(tk.END, text[last_idx:], base_tags)
