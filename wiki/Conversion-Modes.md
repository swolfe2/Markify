# Conversion Modes

Markify supports multiple ways to convert your documents.

---

## 📄 File Conversion (Default)

The standard method for converting Word documents.

### Single File
1. Click **SELECT FILE TO CONVERT**
2. Choose a `.docx` file
3. Preview appears with conversion result
4. Save or copy to clipboard

### Batch Processing
1. Click **SELECT FILE TO CONVERT**
2. Hold `Ctrl` or `Shift` to select multiple files
3. All files process sequentially
4. Summary window shows results

### Drag & Drop
- Drop `.docx` files directly onto the application window
- Drop **folders** to batch-convert all documents inside

---

## 📋 Clipboard Mode

Convert formatted text without saving a Word document.

### How to Use
1. In Word: Select and copy text (`Ctrl+C`)
2. In Markify: Click **Clipboard Mode** (or press `Ctrl+V`)
3. Markdown appears instantly in preview
4. Save or copy as needed

### What Gets Converted
- Headers and formatting
- Tables
- Hyperlinks
- Code (auto-detected languages)
- Word Online content (lists, code blocks, shell scripts)
- Directory trees (auto-formatted as code blocks)

### Diagnostics Mode
Troubleshooting formatting issues? check **Enable Diagnostics** at the bottom of the window to capture the raw HTML input.

> 💡 Great for quick snippets without creating a file!

---

## 👁 Watch Mode

Automatically convert new documents dropped into a folder.

### Setup
1. Click **Watch Mode** in the menu
2. Select a folder to monitor
3. Markify runs in the background

### Behavior
- New `.docx` files → automatically converted
- New `.xlsx` files → tables extracted to Markdown
- Converted files saved alongside originals

### Stop Watching
Click the **Stop Watch** button or close the application.

---

## 🔄 Reverse Conversion (MD → DOCX)

Convert Markdown back to Word format.

### How to Use
1. Go to **File → Convert MD to DOCX**
2. Select a `.md` file
3. Word document is generated

### What's Preserved
- Headers and paragraphs
- Tables (full support)
- Code blocks
- Hyperlinks
- Bold, italic, inline code

> ⚠️ Some complex Markdown features may not translate perfectly.

---

## 🔍 Diff View

Compare two Markdown files side-by-side.

### How to Use
1. Go to **Tools → Diff View**
2. Select the **original** file
3. Select the **modified** file
4. View highlighted differences

### Highlighting
- **Green**: Added lines
- **Red**: Removed lines
- **Yellow**: Modified lines

### Use Cases
- Review changes after editing
- Compare before/after conversion
- Verify round-trip fidelity

---

## CLI Mode

For automation and scripting.

### Single File
```powershell
python src/markify_core.py "C:\Path\To\Document.docx"
```

### Batch Processing
```powershell
Get-ChildItem *.docx | ForEach-Object { python src/markify_core.py $_.FullName }
```

Output `.md` files are saved alongside source documents.
