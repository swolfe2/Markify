from playwright.sync_api import sync_playwright


def main(search):
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=False)
        context = browser.new_context()
        # Open new page
        page = context.new_page()
        # Go to https://www.w3schools.com/howto/howto_js_filter_table.asp
        page.goto("https://www.w3schools.com/howto/howto_js_filter_table.asp")
        page.locator('[placeholder="Search for names\\.\\."]').fill(f"{search}")
        page.locator('[placeholder="Search for names\\.\\."]').press("Enter")

        # Locate elements, this locator points to a list.
        rows = page.locator('table[id="myTable"]')

        # Pattern 3: resolve locator to elements on page and map them to their text content.
        # Note: the code inside evaluateAll runs in page, you can call any DOM apis there.
        texts = rows.evaluate_all("list => list.map(element => element.textContent)")
        row_count = texts.__len__()
        # ---------------------
        context.close()
        browser.close()


if __name__ == "__main__":
    # search = input("What name do you want to look for?")
    search = "Test"
    main(search)
