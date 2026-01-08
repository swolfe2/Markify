#!/usr/bin/env python3
"""
Bulk State Updater for Azure DevOps Work Items by Iteration Path (Standalone)

What this script does:
1) Runs two WIQL queries based on the iteration paths configured below.
2) Updates all work items in the "completed" iteration to "Done" state.
3) Updates all work items in the "in progress" iteration to "In Progress" state.

Auth:
- Prompts the user for a PAT using a GUI text box (masked input).
- No PowerShell required.

Requirements:
- Python 3.8+
- requests (pip install requests)

Security:
- PAT is not stored in the script.
- PAT is only held in memory for the duration of the run.
"""

from __future__ import annotations

import base64
import json
import sys
import time
from typing import Any, Dict, List

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

# =========================
# USER EDIT SECTION
# =========================
# Change values here and it cascades into the WIQL builder automatically.

# >>> RUN MODE - SET THIS FIRST! <<<
# True = Preview only (no changes made)
#   You should ALWAYS do a preview first to make sure the script is doing what you want!
# False = Actually update work items
DRY_RUN = True

ORG = "KC-DataAnalytics"
PROJECT = "Global DV CoE"
API_VERSION = "7.1"

# =========================
# ITERATION PATH CONFIGURATION
# =========================
# Define which iteration paths to update and to what state.
# The script will query for work items in each iteration and update their state.

# Iteration to mark as "Done" (completed work)
COMPLETED_ITERATION = {
    "iteration_path": r"Global DV CoE\Dec2025",  # Full iteration path
    "target_state": "Done",
}

# Iteration to mark as "In Progress" (current work)
IN_PROGRESS_ITERATION = {
    "iteration_path": r"Global DV CoE\Jan2026",  # Full iteration path
    "target_state": "In Progress",
}

# WIQL filter parameters (applies to both queries)
QUERY_PARAMS = {
    # Team project name as it appears in ADO
    "team_project": "Global DV CoE",
    # Work item types to target (comma-separated for multiple)
    "work_item_types": ["User Story", "Task", "Bug"],
    # Assigned To filter (set to None to skip filtering by assignment)
    # Use the literal form with angle brackets if that is what your org uses.
    # Example: "Wolfe, Steve <steve.wolfe@kcc.com>"
    "assigned_to": "Wolfe, Steve <steve.wolfe@kcc.com>",
    # Only return items under this Area Path (set to None to skip)
    # Example: "Global DV CoE\\Innovation"
    "area_path_under": None,
}

# Runtime behavior
RUN_SETTINGS = {
    # Delay between updates (seconds). Helps avoid throttling.
    "sleep_seconds": 0.15,
    # Timeout for each REST call (seconds)
    "timeout_seconds": 30,
    # Retry behavior for transient failures (429, 5xx, network hiccups)
    "retries_total": 5,
    "retries_backoff_factor": 0.5,
    # Safety modes
    "validate_only": False,  # If True, asks ADO to validate patches but not save
    # Optional limit for testing. 0 means no limit.
    "max_items": 0,
    # If True, show a confirmation dialog before applying updates
    "confirm_before_updates": True,
}


# =========================
# HELPERS: GUI prompts
# =========================


def get_pat_from_user() -> str:
    """
    Prompt user for PAT.

    Preferred method:
    - tkinter GUI masked input

    Fallback:
    - console masked input if tkinter is unavailable
    """
    try:
        import tkinter as tk
        from tkinter import messagebox, simpledialog
    except Exception:
        # Fallback to console prompt if tkinter is blocked
        import getpass

        pat = getpass.getpass("Enter Azure DevOps PAT (input hidden): ").strip()
        if not pat:
            raise SystemExit("No PAT provided. Exiting.")
        return pat

    root = tk.Tk()
    root.withdraw()
    root.attributes("-topmost", True)

    pat = simpledialog.askstring(
        title="Azure DevOps PAT Required",
        prompt="Paste your Azure DevOps Personal Access Token (input hidden):",
        show="*",
    )

    root.destroy()  # Clean up tkinter resources

    if not pat:
        messagebox.showerror("PAT Required", "No PAT was provided. Exiting.")
        raise SystemExit(2)

    return pat.strip()


def confirm_dialog(title: str, message: str) -> bool:
    """
    Show an OK/Cancel confirmation dialog.
    Returns True if OK pressed, False if canceled.

    Falls back to console prompt if tkinter is unavailable.
    """
    try:
        import tkinter as tk
        from tkinter import messagebox
    except Exception:
        resp = input(f"{title}: {message} (y/n): ").strip().lower()
        return resp in ("y", "yes")

    root = tk.Tk()
    root.withdraw()
    root.attributes("-topmost", True)
    result = messagebox.askokcancel(title, message)
    root.destroy()  # Clean up tkinter resources
    return result


# =========================
# HELPERS: HTTP session
# =========================


def build_session(pat: str) -> requests.Session:
    """
    Build a requests Session with:
    - Basic auth header derived from PAT
    - retries for transient failures
    """
    sess = requests.Session()

    auth = base64.b64encode(f":{pat}".encode("utf-8")).decode("utf-8")
    sess.headers.update(
        {
            "Authorization": f"Basic {auth}",
            "Accept": "application/json",
        }
    )

    retry_cfg = Retry(
        total=RUN_SETTINGS["retries_total"],
        read=RUN_SETTINGS["retries_total"],
        connect=RUN_SETTINGS["retries_total"],
        status=RUN_SETTINGS["retries_total"],
        backoff_factor=RUN_SETTINGS["retries_backoff_factor"],
        status_forcelist=(429, 500, 502, 503, 504),
        allowed_methods=frozenset(["GET", "POST", "PATCH"]),
        raise_on_status=False,
    )

    adapter = HTTPAdapter(max_retries=retry_cfg)
    sess.mount("https://", adapter)
    sess.mount("http://", adapter)

    return sess


# =========================
# WIQL builder
# =========================


def escape_wiql_value(value: str) -> str:
    """
    Escape single quotes for WIQL literals by doubling them.
    """
    return value.replace("'", "''")


def build_wiql_for_iteration(
    params: Dict[str, Any], iteration_path: str, exclude_state: str
) -> str:
    """
    Build WIQL to find work items in a specific iteration.
    Excludes items already in the target state.
    """
    team_project = params.get("team_project")
    work_item_types = params.get("work_item_types", [])
    assigned_to = params.get("assigned_to")
    area_path_under = params.get("area_path_under")

    where_clauses = [
        f"[System.TeamProject] = '{escape_wiql_value(team_project)}'",
        f"[System.IterationPath] = '{escape_wiql_value(iteration_path)}'",
        f"[System.State] <> '{escape_wiql_value(exclude_state)}'",
    ]

    # Work item type filter
    if work_item_types:
        if len(work_item_types) == 1:
            where_clauses.append(
                f"[System.WorkItemType] = '{escape_wiql_value(work_item_types[0])}'"
            )
        else:
            type_conditions = " OR ".join(
                f"[System.WorkItemType] = '{escape_wiql_value(t)}'"
                for t in work_item_types
            )
            where_clauses.append(f"({type_conditions})")

    if assigned_to:
        where_clauses.append(
            f"[System.AssignedTo] = '{escape_wiql_value(assigned_to)}'"
        )

    if area_path_under:
        where_clauses.append(
            f"[System.AreaPath] UNDER '{escape_wiql_value(area_path_under)}'"
        )

    wiql = (
        "SELECT\n"
        "    [System.Id],\n"
        "    [System.WorkItemType],\n"
        "    [System.Title],\n"
        "    [System.AssignedTo],\n"
        "    [System.State]\n"
        "FROM WorkItems\n"
        "WHERE\n    " + "\n    AND ".join(where_clauses)
    )
    return wiql


# =========================
# Azure DevOps REST calls
# =========================


def org_url() -> str:
    return f"https://dev.azure.com/{ORG}"


def validate_pat(sess: requests.Session) -> bool:
    """
    Validate the PAT by making a simple API call.
    Returns True if authentication succeeds, False otherwise.
    """
    url = f"{org_url()}/_apis/projects?api-version={API_VERSION}&$top=1"
    try:
        r = sess.get(url, timeout=RUN_SETTINGS["timeout_seconds"])
        if r.status_code == 401:
            return False
        if r.status_code == 203:  # Non-authoritative (often means auth failed)
            return False
        r.raise_for_status()
        # Try to parse JSON to ensure we got a valid response
        r.json()
        return True
    except Exception:
        return False


def wiql_get_ids(sess: requests.Session, wiql_text: str) -> List[int]:
    """
    Execute WIQL and return matching work item IDs.
    """
    url = f"{org_url()}/{PROJECT}/_apis/wit/wiql?api-version={API_VERSION}"
    try:
        r = sess.post(
            url, json={"query": wiql_text}, timeout=RUN_SETTINGS["timeout_seconds"]
        )
        if r.status_code == 401:
            raise SystemExit(
                "[ERROR] Authentication failed. Your PAT may have expired or lacks permissions."
            )
        r.raise_for_status()
        data = r.json()
        return [x["id"] for x in data.get("workItems", [])]
    except requests.exceptions.JSONDecodeError:
        print(f"[ERROR] Failed to parse API response. Status code: {r.status_code}")
        print(
            f"Response text: {r.text[:500]}..."
            if len(r.text) > 500
            else f"Response text: {r.text}"
        )
        raise SystemExit(1)


def get_work_item_details(sess: requests.Session, work_item_id: int) -> Dict[str, Any]:
    """
    Fetch work item with fields.
    Returns the full work item JSON including fields.
    """
    url = (
        f"{org_url()}/{PROJECT}/_apis/wit/workitems/{work_item_id}"
        f"?api-version={API_VERSION}"
    )
    r = sess.get(url, timeout=RUN_SETTINGS["timeout_seconds"])
    r.raise_for_status()
    return r.json()


def update_work_item_state(
    sess: requests.Session, work_item_id: int, new_state: str
) -> str:
    """
    Update work item state using JSON Patch.
    Returns empty string on success, or error message on failure.
    """
    url = (
        f"{org_url()}/{PROJECT}/_apis/wit/workitems/{work_item_id}"
        f"?api-version={API_VERSION}"
        f"&validateOnly={'true' if RUN_SETTINGS['validate_only'] else 'false'}"
    )

    patch = [
        {
            "op": "add",
            "path": "/fields/System.State",
            "value": new_state,
        }
    ]

    headers = {"Content-Type": "application/json-patch+json"}
    r = sess.patch(
        url,
        headers=headers,
        data=json.dumps(patch),
        timeout=RUN_SETTINGS["timeout_seconds"],
    )

    if r.status_code >= 400:
        # Try to extract error message from response
        try:
            error_data = r.json()
            error_msg = error_data.get("message", r.text)
        except Exception:
            error_msg = r.text
        return f"HTTP {r.status_code}: {error_msg}"

    return ""  # Success


# =========================
# Processing functions
# =========================


def process_iteration(
    sess: requests.Session,
    iteration_config: Dict[str, str],
    params: Dict[str, Any],
) -> Dict[str, int]:
    """
    Process all work items in an iteration and update them to the target state.
    Returns a dict with counts: updated, skipped, failed.
    """
    iteration_path = iteration_config["iteration_path"]
    target_state = iteration_config["target_state"]

    print(f"\n{'='*60}")
    print(f"Processing: {iteration_path}")
    print(f"Target State: {target_state}")
    print("=" * 60)

    # Build and display WIQL
    wiql = build_wiql_for_iteration(params, iteration_path, target_state)
    print("\nWIQL that will run (validate in Boards > Queries):")
    print(wiql)
    print()

    # Fetch IDs
    ids = wiql_get_ids(sess, wiql)

    if RUN_SETTINGS["max_items"] and len(ids) > RUN_SETTINGS["max_items"]:
        ids = ids[: RUN_SETTINGS["max_items"]]

    print(f"Found {len(ids)} work items to update.")

    if not ids:
        print("[OK] Nothing to do for this iteration.")
        return {"updated": 0, "skipped": 0, "failed": 0}

    updated = 0
    skipped = 0
    failed = 0

    total = len(ids)
    for i, wid in enumerate(ids, 1):
        try:
            # Fetch work item details
            wi_data = get_work_item_details(sess, wid)
            fields = wi_data.get("fields", {})

            # Extract display info
            title = fields.get("System.Title", "(No Title)")
            current_state = fields.get("System.State", "(Unknown)")
            area_path = fields.get("System.AreaPath", "(No Area Path)")
            wi_iteration = fields.get("System.IterationPath", "(No Iteration Path)")

            # Print work item info
            print(f"\n[{i}/{total}] Work Item {wid}")
            print(f"         Title: {title}")
            print(f"     Area Path: {area_path}")
            print(f"Iteration Path: {wi_iteration}")
            print(f" Current State: {current_state}")

            # Skip if already in target state
            if current_state == target_state:
                print(f"        Status: [SKIP] Already in state '{target_state}'")
                skipped += 1
                continue

            if DRY_RUN:
                updated += 1
                print(
                    f"        Status: [DRY RUN] Would change '{current_state}' -> '{target_state}'"
                )
                continue

            update_work_item_state(sess, wid, target_state)
            updated += 1
            print(f"        Status: [OK] Changed '{current_state}' -> '{target_state}'")

            time.sleep(RUN_SETTINGS["sleep_seconds"])

        except Exception as ex:
            failed += 1
            print(f"        Status: [ERROR] FAILED: {ex}", file=sys.stderr)

    return {"updated": updated, "skipped": skipped, "failed": failed}


# =========================
# Main workflow
# =========================


def main() -> int:
    print("=== Bulk State Updater by Iteration Path ===\n")

    if DRY_RUN:
        print("[DRY RUN MODE] No changes will be made.\n")
    else:
        print("[LIVE MODE] Changes WILL be applied!\n")

    print("Configuration:")
    print(f"  Completed Iteration: {COMPLETED_ITERATION['iteration_path']}")
    print(f"    -> Will set state to: {COMPLETED_ITERATION['target_state']}")
    print(f"  In Progress Iteration: {IN_PROGRESS_ITERATION['iteration_path']}")
    print(f"    -> Will set state to: {IN_PROGRESS_ITERATION['target_state']}")
    print(f"  Assigned To: {QUERY_PARAMS.get('assigned_to', '(All users)')}")
    print(
        f"  Work Item Types: {', '.join(QUERY_PARAMS.get('work_item_types', ['All']))}"
    )
    print()

    # Prompt for PAT using GUI with validation and retry
    max_attempts = 3
    sess = None
    for attempt in range(1, max_attempts + 1):
        pat = get_pat_from_user()
        sess = build_session(pat)

        print("Validating PAT...")
        if validate_pat(sess):
            print("[OK] PAT validated successfully.\n")
            break
        else:
            print(f"[ERROR] PAT validation failed (attempt {attempt}/{max_attempts}).")
            if attempt < max_attempts:
                print("Please check your PAT and try again.\n")
            else:
                print("\n[ERROR] Maximum attempts reached. Exiting.")
                print("Troubleshooting tips:")
                print("  - Ensure your PAT has not expired")
                print("  - Verify the PAT has 'Work Items (Read & Write)' scope")
                print(f"  - Check that you have access to organization: {ORG}")
                return 1

    # Confirm before updates (non-dry-run only)
    if RUN_SETTINGS["confirm_before_updates"] and not DRY_RUN:
        ok = confirm_dialog(
            "Confirm Bulk Update",
            "This will update work item states for the configured iterations.\n\nProceed?",
        )
        if not ok:
            print("[CANCELLED] Cancelled by user.")
            return 0

    # Process both iterations
    totals = {"updated": 0, "skipped": 0, "failed": 0}

    # Process completed iteration (set to Done)
    result = process_iteration(sess, COMPLETED_ITERATION, QUERY_PARAMS)
    totals["updated"] += result["updated"]
    totals["skipped"] += result["skipped"]
    totals["failed"] += result["failed"]

    # Process in-progress iteration (set to In Progress)
    result = process_iteration(sess, IN_PROGRESS_ITERATION, QUERY_PARAMS)
    totals["updated"] += result["updated"]
    totals["skipped"] += result["skipped"]
    totals["failed"] += result["failed"]

    # Final summary
    print("\n" + "=" * 60)
    print("=== FINAL SUMMARY ===")
    print("=" * 60)
    print(f"Total Updated: {totals['updated']}")
    print(f"Total Skipped (already in target state): {totals['skipped']}")
    print(f"Total Failed: {totals['failed']}")

    if DRY_RUN:
        print("\n[DRY RUN] No changes were made. Set DRY_RUN = False to apply changes.")

    # Exit code 0 if all good, 1 if anything failed
    return 0 if totals["failed"] == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
