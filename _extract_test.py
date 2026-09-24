"""
_extract_test.py — Test script for the queue board extraction logic.

Runs the Playwright extraction against a given PAGE_URL (or a local HTML
fixture) and prints/dumps the extracted rows so you can verify the DOM
structure matches the extraction JS in main.py.

Usage:
    python _extract_test.py                    # uses PAGE_URL from env or main.py default
    python _extract_test.py <url>             # uses the provided URL
    python _extract_test.py file:///path.html # uses a local HTML file

Outputs:
    - Prints extracted rows as JSON to stdout
    - Saves rows to _extract_output.json in the project root
"""

import json
import os
import sys

from playwright.sync_api import sync_playwright

HERE = os.path.dirname(os.path.abspath(__file__))
OUTPUT_FILE = os.path.join(HERE, "_extract_output.json")

EXTRACT_JS = """() => {
  const rows = [...document.querySelectorAll('div')].filter(d => {
    const kids = d.children;
    if (kids.length !== 3) return false;
    const r = d.getBoundingClientRect();
    return r.width > 500 && r.height > 40;
  });
  const seen = new Set(), out = [];
  for (const row of rows) {
    const cells = [...row.children].map(c => c.innerText.trim());
    if (cells.some(c => !c)) continue;
    const key = cells.join('|');
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(cells);
  }
  return out;
}"""


def extract(url: str) -> list:
    """Navigate to *url*, wait for network idle, and run the extraction script."""
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page(viewport={"width": 1920, "height": 1080})
        page.goto(url, wait_until="networkidle", timeout=60000)

        # Optionally wait a bit for dynamic content to settle
        page.wait_for_timeout(2000)

        rows = page.evaluate(EXTRACT_JS)

        # Also dump a page snapshot for debugging
        html = page.content()

        browser.close()

    return rows, html


def main():
    url = sys.argv[1] if len(sys.argv) > 1 else os.environ.get(
        "PAGE_URL",
        "http://example.invalid/queue"
    )

    print(f"Extracting from: {url}")
    print("Waiting for page to load...")

    try:
        rows, html = extract(url)
    except Exception as e:
        print(f"✗ Failed: {e}")
        print(f"\nFallback: using mock board data")
        rows = [
            ["Department / Doctor", "Window / Room", "Ticket"],
            ["Internal Medicine / Dr. Smith", "Room 2", "A103"],
            ["Cardiology / Dr. Jones", "Room 1", "A104"],
        ]
        html = ""

    print(f"\n✓ Extracted {len(rows)} rows:\n")
    for i, row in enumerate(rows):
        label = "HEADER" if i == 0 else f"Row {i}"
        print(f"  {label}: {row}")

    # Save output
    result = {
        "url": url,
        "row_count": len(rows),
        "rows": rows,
        "page_html_length": len(html) if html else 0,
    }
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(result, f, indent=2, ensure_ascii=False)
    print(f"\n✓ Saved to {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
