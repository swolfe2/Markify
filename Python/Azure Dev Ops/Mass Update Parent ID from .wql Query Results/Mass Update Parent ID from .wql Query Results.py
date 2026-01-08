#!/usr/bin/env python3
"""
Bulk Parent Linker for Azure DevOps Work Items (Standalone)

What this script does:
1) Builds a WIQL query from the configuration section below.
2) Executes WIQL to get matching work item IDs.
3) For each work item, checks if it already has the target Parent relationship.
4) If not, adds the Parent relationship using Azure DevOps REST API (JSON Patch).

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

# Parent to apply to ALL results returned by the WIQL query
PARENT_ID = 202966

# WIQL filter parameters
QUERY_PARAMS = {
    # Team project name as it appears in ADO
    "team_project": "Global DV CoE",
    # Work item type to target
    "work_item_type": "User Story",
    # Assigned To filter (set to None to skip filtering by assignment)
    # Use the literal form with angle brackets if that is what your org uses.
    # Example: "Wolfe, Steve <steve.wolfe@kcc.com>"
    "assigned_to": "PUT_YOUR_STRING_HERE",
    # Only return items under this Area Path (set to None to skip)
    # Example: "Global DV CoE\Innovation"
    "area_path_under": r"PUT_YOUR_STRING_HERE",
    # If True, includes a "no parent" condition in WIQL.
    # If your ADO instance ever rejects [System.Parent] = '', set this False.
    "require_no_parent": True,
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


def build_wiql(params: Dict[str, Any]) -> str:
    """
    Build WIQL from QUERY_PARAMS.

    Edit QUERY_PARAMS at the top and this query updates automatically.
    """
    team_project = params.get("team_project")
    work_item_type = params.get("work_item_type")
    assigned_to = params.get("assigned_to")
    area_path_under = params.get("area_path_under")
    require_no_parent = bool(params.get("require_no_parent"))

    where_clauses = [
        f"[System.TeamProject] = '{escape_wiql_value(team_project)}'",
        f"[System.WorkItemType] = '{escape_wiql_value(work_item_type)}'",
    ]

    if assigned_to:
        where_clauses.append(
            f"[System.AssignedTo] = '{escape_wiql_value(assigned_to)}'"
        )

    if require_no_parent:
        # If this ever fails in your org, set require_no_parent to False.
        where_clauses.append("[System.Parent] = ''")

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
    Fetch work item with fields and relations.
    Returns the full work item JSON including fields and relations.
    """
    url = (
        f"{org_url()}/{PROJECT}/_apis/wit/workitems/{work_item_id}"
        f"?$expand=relations&api-version={API_VERSION}"
    )
    r = sess.get(url, timeout=RUN_SETTINGS["timeout_seconds"])
    r.raise_for_status()
    return r.json()


def has_any_parent(relations: List[Dict[str, Any]]) -> bool:
    """
    True if the work item already has ANY parent link.
    """
    return any(
        rel.get("rel") == "System.LinkTypes.Hierarchy-Reverse" for rel in relations
    )


def has_parent_link(relations: List[Dict[str, Any]], parent_id: int) -> bool:
    """
    True if the work item already has Parent = parent_id.
    """
    suffix = f"/_apis/wit/workItems/{parent_id}"
    for rel in relations:
        if rel.get("rel") == "System.LinkTypes.Hierarchy-Reverse":
            if str(rel.get("url", "")).endswith(suffix):
                return True
    return False


def add_parent_link(sess: requests.Session, child_id: int, parent_id: int) -> None:
    """
    Add Parent relationship using JSON Patch.

    Relation type:
    - System.LinkTypes.Hierarchy-Reverse means "this item has Parent"
    """
    url = (
        f"{org_url()}/{PROJECT}/_apis/wit/workitems/{child_id}"
        f"?api-version={API_VERSION}"
        f"&validateOnly={'true' if RUN_SETTINGS['validate_only'] else 'false'}"
    )

    parent_url = f"{org_url()}/_apis/wit/workItems/{parent_id}"

    patch = [
        {
            "op": "add",
            "path": "/relations/-",
            "value": {
                "rel": "System.LinkTypes.Hierarchy-Reverse",
                "url": parent_url,
                "attributes": {"comment": f"Bulk parent set to {parent_id}"},
            },
        }
    ]

    headers = {"Content-Type": "application/json-patch+json"}
    r = sess.patch(
        url,
        headers=headers,
        data=json.dumps(patch),
        timeout=RUN_SETTINGS["timeout_seconds"],
    )
    r.raise_for_status()


# =========================
# Main workflow
# =========================


def main() -> int:
    print("=== Bulk Parent Linker starting... ===\n")

    # Build WIQL from the top-of-file parameters
    wiql = build_wiql(QUERY_PARAMS)

    print(
        "WIQL that will run (you will want to validate this manually in Boards > Queries):"
    )
    print(wiql)
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

    # Fetch IDs
    ids = wiql_get_ids(sess, wiql)

    if RUN_SETTINGS["max_items"] and len(ids) > RUN_SETTINGS["max_items"]:
        ids = ids[: RUN_SETTINGS["max_items"]]

    print(f"Found {len(ids)} work items matching query.")
    if not ids:
        print("[OK] Nothing to do.")
        return 0

    # Confirm before updates
    if RUN_SETTINGS["confirm_before_updates"] and not DRY_RUN:
        ok = confirm_dialog(
            "Confirm Bulk Update",
            f"This will link {len(ids)} work items to Parent {PARENT_ID}.\n\nProceed?",
        )
        if not ok:
            print("[CANCELLED] Cancelled by user.")
            return 0

    updated = 0
    skipped = 0
    failed = 0

    total = len(ids)
    for i, wid in enumerate(ids, 1):
        try:
            # Fetch work item details including fields and relations
            wi_data = get_work_item_details(sess, wid)
            fields = wi_data.get("fields", {})
            rels = wi_data.get("relations", []) or []

            # Extract display info
            title = fields.get("System.Title", "(No Title)")
            area_path = fields.get("System.AreaPath", "(No Area Path)")
            iteration_path = fields.get("System.IterationPath", "(No Iteration Path)")

            # Print work item info
            print(f"[{i}/{total}] Work Item {wid}")
            print(f"         Title: {title}")
            print(f"     Area Path: {area_path}")
            print(f"Iteration Path: {iteration_path}")

            # Check if already has the target parent
            if has_parent_link(rels, PARENT_ID):
                print(f"        Status: [SKIP] Already has parent {PARENT_ID}")
                skipped += 1
                continue

            # Check if has a different parent (safety check)
            if has_any_parent(rels):
                print(f"        Status: [SKIP] Already has a different parent")
                skipped += 1
                continue

            if DRY_RUN:
                updated += 1
                print(f"        Status: [DRY RUN] Would link -> parent {PARENT_ID}")
                continue

            add_parent_link(sess, wid, PARENT_ID)
            updated += 1
            print(f"        Status: [OK] Linked -> parent {PARENT_ID}")

            time.sleep(RUN_SETTINGS["sleep_seconds"])

        except Exception as ex:
            failed += 1
            print(f"  [ERROR] FAILED {wid}: {ex}", file=sys.stderr)

    print("\n=== Summary ===")
    print(f"Updated: {updated}")
    print(f"Skipped (already linked): {skipped}")
    print(f"Failed: {failed}")

    # Exit code 0 if all good, 1 if anything failed
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
