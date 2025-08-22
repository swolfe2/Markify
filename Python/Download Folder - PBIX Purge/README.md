```
╔══════════════════════════════════════════════════════════════════════════════╗
║                      ✨ Sorcery: COMET AZUR — PBIX PURGE ✨                  ║
║   "Concentrate glintstone energy into a beam that obliterates stray .pbix."  ║
╚══════════════════════════════════════════════════════════════════════════════╝
```

# 🧹 Download Folder — PBIX Purge (Safe Delete by Default)

Your OneDrive–KC **Downloads** stays clean by removing leftover **Power BI** (`.pbix`) files and writing a clear run log. Now, by default, deletes are **SAFE** (sent to the **Recycle Bin**) when the optional dependency is available.

> ⚠️ If `send2trash` is **not** installed, the tool falls back to **permanent** delete and records that fact in the log.

---

## 🧙‍♂️ Features
- **Default (safe):** Send `.pbix` to **Recycle Bin** (`--mode safe`).
- **Permanent deletion:** Opt in with `--mode permanent`.
- **Dry‑run:** `--dry-run` previews targets without deleting.
- **Flexible paths:** `--downloads-path`, `--log-dir`.
- **Log modes:** `overwrite` (single rotating `PBIX_Purge_Log.txt`, default) or `timestamp` (per‑run files).

---

## ⚡ Installation
To enable **safe-delete** (Recycle Bin support), install the optional dependency:

```bash
pip install send2trash
```

If `send2trash` is not installed, the script will still run but will **fall back to permanent delete** and note this in the log.

---

## 🧩 What the script’s functions do (no code shown)
- **`default_downloads_path()` / `default_log_dir()`** — Build sensible OneDrive–KC paths from your Windows username.
- **`find_target_files(folder)`** — Enumerate `.pbix` files (case‑insensitive) in the target folder.
- **`delete_files(folder, names, dry_run, mode)`** — Perform deletions per mode:
  - `safe`: Recycle Bin via `send2trash`; if missing, falls back to permanent deletion.
  - `permanent`: `os.remove`.
- **`write_log(log_dir, log_mode, ...)`** — Output mode, target, totals, and file list; supports overwrite or timestamped file naming.
- **`main()`** — Parses CLI flags, orchestrates the run, prints the log location, and returns an exit code.

---

## ⚙️ Arguments
```
--dry-run                 List files without deleting
--mode {safe,permanent}   Deletion mode (default: safe)
--downloads-path PATH     Downloads folder to scan
--log-dir PATH            Directory to write logs
--log-mode MODE           overwrite | timestamp (default: overwrite)
```

---

## 🚀 Usage examples
```powershell
# Default: SAFE delete (Recycle Bin), overwrite single log
python pbix_purge.py

# Permanent delete (explicit)
python pbix_purge.py --mode permanent

# Preview only
python pbix_purge.py --dry-run

# Recycle Bin with timestamped logs + custom paths
pip install send2trash
python pbix_purge.py --log-mode timestamp ^
  --downloads-path "C:\Users\<YOU>\OneDrive - Kimberly-Clark\Downloads" ^
  --log-dir "C:\Users\<YOU>\OneDrive - Kimberly-Clark\Desktop\Code\Python\Download Folder - PBIX Purge"
```

---

## 🧰 Batch launcher (for Task Scheduler)
```bat
@echo off
setlocal
set PYTHON_PATH="C:\\Python 3.10\\Python.exe"
set SCRIPT_PATH="C:\\Users\\<YOU>\\...\\Download Folder - PBIX Purge\\pbix_purge.py"
%PYTHON_PATH% %SCRIPT_PATH%
endlocal
```

In **Task Scheduler**, ensure **Actions → Start in** points to your project folder (or use absolute paths) and pick your desired **Triggers**.

---

## 📝 Log behavior
- **Overwrite mode**: rewrites `PBIX_Purge_Log.txt` each run (matches your original workflow).
- **Timestamp mode**: creates `PBIX_Purge_Log_YYYYMMDD_HHMM.txt` per run.
- When `send2trash` is unavailable and mode is `safe`, the log clearly states that it performed a **permanent** delete instead.

---

## 🛠️ Troubleshooting
- **Permission denied / file in use** → Close the `.pbix` in Power BI Desktop.
- **Different OneDrive root** → Adjust the `OneDrive - <Company>` segment in your paths.
- **Task doesn’t run** → In Task Scheduler, set **Start in** to the project directory or use absolute paths in the `.bat`.

---

## 🖊️ Author
Steve Wolfe — Lead Analytics Visualization Engineer
