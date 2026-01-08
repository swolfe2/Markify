# Getting Started

This guide will help you install and run Markify for the first time.

---

## Installation Options

### Option A: Run from Source (Recommended)

This method requires Python 3.10+ installed on your system.

1. **Clone or download** the repository
2. **Run** `Markify.bat` in the root folder

> **Note**: This uses only Python standard libraries—no `pip install` required!

### Option B: Portable Executable

1. Navigate to `dist/Markify/`
2. Run **`Markify.exe`**

> ⚠️ **Corporate Security**: Some security tools (like BeyondInsight) may block the EXE. Use Option A if you encounter issues.

### Option C: Developer Setup

```bash
# Clone the repository
git clone https://github.com/swolfe2/Markify.git
cd Markify

# Install dev dependencies (optional, for testing/linting)
pip install pytest ruff bandit pyinstaller

# Run the application
python src/markify_app.py
```

---

## Your First Conversion

### Step 1: Launch Markify

Run `Markify.bat` or `Markify.exe`. You'll see the main window:

![Main Window](../samples/demos/Markify_Demo.gif)

### Step 2: Select a File

Click **SELECT FILE TO CONVERT** and choose a `.docx` file.

> 💡 **Tip**: Hold `Ctrl` or `Shift` to select multiple files for batch processing.

### Step 3: View Results

- **Single file**: Opens preview with options to save, copy, or open in VS Code
- **Multiple files**: Shows summary with link to output folder

---

## Try the Demo File

A sample document is included to test all features:

📁 `samples/Markify_Demo.docx`

This file contains:
- Headers (H1-H6)
- Tables
- Code blocks (DAX, Power Query)
- Hyperlinks
- Emoji headers

---

## Common First-Time Issues

| Issue | Solution |
|-------|----------|
| "File is locked" error | Close the Word document before converting |
| EXE blocked by security | Use `Markify.bat` instead |
| No Python found | Install Python 3.10+ and add to PATH |

---

## Next Steps

- [[Features]] – Explore all capabilities
- [[Conversion Modes]] – Learn about Clipboard, Watch mode, etc.
- [[Configuration]] – Customize themes and options
