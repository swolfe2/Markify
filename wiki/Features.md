# Features

Markify offers a comprehensive set of features for converting Word documents to Markdown.

---

## Core Conversion

| Feature | Description |
|---------|-------------|
| **Headers** | Title, Heading 1-6 with proper `#` syntax |
| **Tables** | Full table support with alignment |
| **Hyperlinks** | Word links → `[text](url)` syntax |
| **Images** | Optional extraction to subfolder |
| **Lists** | Bulleted and numbered lists |
| **Footnotes** | Word footnotes → `[^1]` syntax |

---

## Code Detection & Formatting

Automatically detects and formats code in your documents:

| Language | Detection Patterns |
|----------|-------------------|
| **Power Query (M)** | `let ... in`, `#"`, `Source =` |
| **DAX** | `CALCULATE`, `SUMX`, `:=`, measures |
| **Python** | `def`, `class`, `import`, `if __name__` |
| **SQL** | `SELECT`, `INSERT`, `JOIN`, `WHERE` |

### API Formatting (Optional)

- **DAX** → Formatted via [daxformatter.com](https://www.daxformatter.com)
- **Power Query** → Formatted via [powerqueryformatter.com](https://powerqueryformatter.com)

> Toggle in Options dialog

---

## Conversion Modes

| Mode | Description |
|------|-------------|
| 📄 **File Conversion** | Standard single/batch DOCX → MD |
| 📋 **Clipboard Mode** | Paste from Word → instant Markdown |
| 👁 **Watch Mode** | Auto-convert files in a watched folder |
| 🔄 **Reverse Conversion** | MD → DOCX |
| 🔍 **Diff View** | Compare two Markdown files |

See [[Conversion Modes]] for details.

---

## Export Options

| Format | Use Case |
|--------|----------|
| **Standard Markdown** | GitHub, VS Code, general use |
| **Confluence/Jira** | Atlassian wiki syntax |
| **Obsidian** | `[[wikilinks]]` and callout blocks |
| **YAML Front Matter** | Hugo, Jekyll static sites |
| **Templates** | Custom headers with variables |

See [[Export Formats]] for details.

---

## UI Features

### Themes
7 built-in color themes:
- Default Dark
- Dracula
- Nord
- Solarized Dark
- Solarized Light
- Monokai
- One Dark

### Preview Before Save
- Syntax highlighting for headers
- Line and character count
- Word count and reading time
- Header breakdown (H1:2, H2:5, etc.)

### Recent Files
- Last 5 conversions
- Clickable links to source and output
- Smart deduplication

### Keyboard Shortcuts
Press **F1** to view all available shortcuts.

---

## Comparison with Alternatives

| Feature | **Markify** | **MarkItDown (MS)** | **mammoth** | **pypandoc** |
|---------|:-----------:|:-------------------:|:-----------:|:------------:|
| Zero dependencies | ✅ | ❌ | ❌ | ❌ |
| Built-in GUI | ✅ | ❌ | ❌ | ❌ |
| DAX/M detection | ✅ | ❌ | ❌ | ❌ |
| Auto-format code | ✅ | ❌ | ❌ | ❌ |
| Image extraction | ✅ | ❌ | ❌ | ❌ |
| Multi-format (PDF, PPTX) | ❌ | ✅ | ❌ | ✅ |

### Choose Markify if:
- You work with **Power BI / Power Query** documentation
- You need a **GUI** for non-technical users
- You want **zero pip installs**
- You're in a **locked-down corporate environment**

### Choose alternatives if:
- You need **PDF/PowerPoint** conversion (MarkItDown)
- You need **maximum Word compatibility** (pypandoc)
