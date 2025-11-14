# PyChron

A modern, desktop time-tracking application built with Python and CustomTkinter. Track time spent on tasks with multiple sessions, add notes, and export your data in multiple formats.

**PyChron** combines "Python" with "Chronos," the Greek personification of time—a sharp and professional name for a time-tracking tool.

## ✨ Features

### Core Functionality

- **Task Management**
  - Create unlimited tasks with custom names
  - Edit task names after creation
  - Track multiple work sessions per task
  - Start, pause, and resume timers
  - Mark tasks as complete
  - Undo task completion to continue tracking
  - Delete individual tasks or clear all at once
  - Confirmation dialogs for destructive actions

- **Session Tracking**
  - Multiple sessions per task
  - Custom session names (default: "Session 1", "Session 2", etc.)
  - Edit session names with a simple click
  - Automatic time calculation for each session
  - Total duration tracking across all sessions

- **Notes & Documentation**
  - Add notes to individual sessions
  - Add notes to entire tasks
  - Visual indicators when notes are present
  - Edit notes anytime

- **Data Export**
  - Export completed tasks to **CSV** format
  - Export completed tasks to **JSON** format
  - Export completed tasks to **XLSX** (Excel) format
  - Copy individual task results to clipboard (Excel-friendly format)
  - Choose export directory and filename
  - Export multiple formats simultaneously
  - Includes all session data, notes, and timestamps
  - Session names, session notes, and task notes included in all exports

### User Interface

- **Modern Design**
  - Built with CustomTkinter for a modern look
  - Light and Dark theme support
  - Smooth theme switching
  - Responsive layout

- **User Experience**
  - Collapsible task details (expand/collapse session tables)
  - Auto-hiding scrollbar (only appears when content exceeds window)
  - Clear visual indicators for task status (color-coded borders)
  - Intuitive button layout with color-coded actions
  - Confirmation dialogs for destructive actions
  - Real-time duration updates for active timers
  - Tasks sorted by status (In Progress first, then Completed)

- **Data Display**
  - Tabular view of all sessions with headers
  - Formatted time displays (HH:MM:SS format)
  - Real-time timer updates (updates every second)
  - Color-coded task status (Yellow border = In Progress, Green border = Completed)
  - Running session indicator shows "(running)" status
  - Total duration displayed for each task

## 📋 Requirements

- Python 3.8 or higher
- CustomTkinter
- openpyxl (for XLSX export)

## 🚀 Installation

### Quick Start

1. **Download PyChron**:
   
   **Option A: Download as ZIP (Easiest)**
   - Go to the [repository root](https://github.com/swolfe2/code-examples)
   - Click the green **"Code"** button (top right)
   - Select **"Download ZIP"**
   - Extract the ZIP file
   - Navigate to `code-examples-main/PyChron/` folder
   
   **Option B: Clone with Git**
   ```bash
   git clone https://github.com/swolfe2/code-examples.git
   cd code-examples/PyChron
   ```
   
   **Option C: Download just the PyChron folder**
   - Use a browser extension like [GitZip](https://github.com/GitZip/github-plus-extension) or [Download Directory](https://github.com/Download-Directory/download-directory.github.io)
   - Navigate to the [PyChron folder](https://github.com/swolfe2/code-examples/tree/main/PyChron)
   - Use the extension to download just that folder

2. **Install dependencies**:

```bash
pip install customtkinter openpyxl
```

## 💻 Usage

### Running the Application

```bash
python main.py
```

### Basic Workflow

1. **Create a Task**: Enter a task name in the input field and click "Add Task" or press Enter
2. **Edit Task Name**: Click the "Edit" button next to the task name to rename it
3. **Start Tracking**: Click "Start/Resume" to begin timing a session
4. **Pause**: Click "Start/Resume" again (or "Pause") to pause and save the session
5. **Add Notes**: Click "Add Note" buttons to add context to sessions or tasks
6. **Edit Session Names**: Click the pencil icon (✏) next to a session to rename it
7. **Complete Task**: Click "Complete Task" when finished (can be undone)
8. **Copy Results**: Click "Copy Results" to copy a task's data to clipboard
9. **Export Data**: Click "Export Tasks" to save completed tasks in CSV, JSON, or XLSX format

### Keyboard Shortcuts

- **Enter**: Create a new task (when input field is focused)

## 📁 Project Structure

```
PyChron/
├── main.py              # Main application entry point
├── handlers.py          # Event handlers for user actions
├── constants.py         # Application constants
├── pyproject.toml       # Ruff configuration for linting
├── models/
│   └── task.py          # Task data model
├── storage/
│   └── storage.py       # Data persistence (JSON)
├── ui/
│   ├── dialogs.py       # Dialog windows (prompts, confirmations)
│   └── theme_toggle.py  # Theme switching widget
├── export/
│   └── exporter.py      # Export functionality (CSV, JSON, XLSX)
├── utils/
│   └── formatting.py    # Time formatting utilities
└── tasks.json           # Data storage file (auto-generated)
```

## 🔧 Configuration

The application stores data in `tasks.json` in the same directory as `main.py`. This file is automatically created and updated as you use the application.

### Data Persistence

- All task data is automatically saved when:
  - A task is created, edited, or deleted
  - A task is completed or uncompleted
  - A session is started or paused
  - Notes are added or edited
  - Session names are changed
- Data is stored in JSON format for easy inspection and backup
- The file is created automatically on first use

## 📊 Export Formats

### CSV Export
- Comma-separated values
- Includes: Task Name, Session, Start Time, End Time, Duration, Session Note, Task Note
- Excel-compatible

### JSON Export
- Structured JSON format
- Preserves all task data including notes and session details
- Easy to parse programmatically

### XLSX Export
- Native Excel format
- Same columns as CSV
- Requires `openpyxl` library

### Copy to Clipboard
- Tab-separated format
- Includes headers
- Paste directly into Excel or Google Sheets

## 🎨 Themes

Switch between Light and Dark themes using the toggle in the top-right corner. The theme preference is not currently persisted between sessions.

**Note**: Due to CustomTkinter's internal widget rebuilding mechanism, theme switching may cause a brief visual refresh. All custom widget colors are updated manually to minimize disruption.

## 🖼️ Custom Icons

The application supports custom window icons. To use a custom icon:

1. Place an `icon.ico` or `app.ico` file in the `PyChron` directory
2. The application will automatically detect and use it
3. The icon will appear in the taskbar and window title bar

If no custom icon is found, the default Python icon will be used.

## 🛠️ Development

### Code Structure

The application follows a modular architecture:

- **Models**: Data structures (`Task` class)
- **Handlers**: Business logic and event handling
- **UI**: User interface components and dialogs
- **Storage**: Data persistence layer
- **Export**: Data export functionality
- **Utils**: Helper functions

### Adding Features

The modular structure makes it easy to extend:

- Add new export formats in `export/exporter.py`
- Add new dialogs in `ui/dialogs.py`
- Extend the Task model in `models/task.py`
- Add new handlers in `handlers.py`

## 📝 License

This project is open source and available for personal and commercial use.

## 🤝 Contributing

Contributions are welcome! Feel free to submit issues or pull requests.

## 📧 Support

For issues, questions, or suggestions, please open an issue on the repository.

---

**Made with ❤️ using Python and CustomTkinter**

