# ✅ How to Re-Index a SharePoint Document Library

Reindexing a SharePoint library ensures its contents are refreshed in the search index so tools like Copilot can find them.

---

## Steps to Re-Index a Library

1. **Navigate to the Library**
   - Go to the SharePoint site where the library resides (e.g., *How-To Documents*).
   - Open the library.

2. **Open Library Settings**
   - Click the **Settings gear** (top right) → **Library settings**.
   - Alternatively: **Site Contents** → select the library → **Settings**.

3. **Access Advanced Settings**
   - On the Library Settings page, under **General Settings**, click **Advanced settings**.

4. **Trigger Reindex**
   - Scroll down to **Reindex Document Library**.
   - Click **Reindex Document Library** and confirm.
   - This flags the library for re-crawling during the next search crawl.

5. **Wait for Search Crawl**
   - SharePoint’s search service will pick up the reindex request during its next scheduled crawl.
   - If urgent, contact your **SharePoint Admin** to trigger a manual crawl.

6. **Verify Permissions**
   - Ensure the library and documents have correct permissions so they can be indexed.

---

### ✅ Notes
- Reindexing does **not** delete or move content.
- It may take several hours depending on crawl schedules and library size.

---

**Tip:** After reindexing completes, tools like Copilot Studio will be able to retrieve the updated content.