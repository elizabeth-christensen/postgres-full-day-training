#!/usr/bin/env python3
"""Extract SQL blocks from each hour-*.md file into sql/hour-*.sql files."""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent
OUTPUT_DIR = ROOT / "sql"

def extract_sql_from_hour(md_path: Path) -> str:
    """Return a .sql file string with slide-separated SQL blocks."""
    text = md_path.read_text(encoding="utf-8")

    # Split on slide separators (--- on its own line)
    raw_slides = re.split(r"\n---\n", text)

    sections = []

    for slide in raw_slides:
        # Pull slide number from [.footer: Slide X / Y]
        footer_match = re.search(r"\[\.footer:\s*Slide\s+(\d+)", slide)
        if not footer_match:
            continue
        slide_num = footer_match.group(1)

        # First ## heading as the title
        title_match = re.search(r"^##\s+(.+)$", slide, re.MULTILINE)
        title = title_match.group(1).strip() if title_match else "Untitled"

        # Extract all ```sql ... ``` blocks
        sql_blocks = re.findall(r"```sql\n(.*?)```", slide, re.DOTALL)
        if not sql_blocks:
            continue

        header = f"-- Slide {slide_num}: {title}"
        separator = "-" * len(header)
        block_text = "\n\n".join(block.rstrip() for block in sql_blocks)
        sections.append(f"-- {separator}\n{header}\n-- {separator}\n\n{block_text}")

    if not sections:
        return ""

    hour_title = md_path.stem  # e.g. hour-1-beginner
    file_header = (
        f"-- {'=' * 60}\n"
        f"-- SQL examples from: {hour_title}\n"
        f"-- {'=' * 60}\n"
    )
    return file_header + "\n\n\n".join(sections) + "\n"


def main():
    OUTPUT_DIR.mkdir(exist_ok=True)
    md_files = sorted(ROOT.glob("hour-*.md"))

    if not md_files:
        print("No hour-*.md files found.", file=sys.stderr)
        sys.exit(1)

    for md_path in md_files:
        content = extract_sql_from_hour(md_path)
        if not content:
            print(f"  (no SQL blocks found in {md_path.name})")
            continue
        out_path = OUTPUT_DIR / (md_path.stem + ".sql")
        out_path.write_text(content, encoding="utf-8")
        print(f"  wrote {out_path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
