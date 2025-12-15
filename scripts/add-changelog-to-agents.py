#!/usr/bin/env python3
"""
Add changelog section to all agent files
Part of WAVE 5 Agent Optimization Plan 2025
"""

import os
import re
from pathlib import Path
from datetime import datetime

# Paths
AGENTS_DIR = Path("/Users/roberdan/GitHub/MyConvergio/.claude/agents")
EXCLUDE_FILES = ["CONSTITUTION.md", "MICROSOFT_VALUES.md", "CommonValuesAndPrinciples.md", "SECURITY_FRAMEWORK_TEMPLATE.md"]

# Changelog template
CHANGELOG_TEMPLATE = """
## Changelog

- **1.0.0** (2025-12-15): Initial security framework and model optimization
"""

def add_changelog_to_agent(file_path):
    """Add changelog section to agent file if not present"""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Check if changelog already exists
    if re.search(r'^## Changelog', content, re.MULTILINE):
        print(f"  ⏭️  Skipping {file_path.name} (changelog already exists)")
        return False

    # Add changelog at the end of the file
    new_content = content.rstrip() + "\n" + CHANGELOG_TEMPLATE

    # Write back
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(new_content)

    print(f"  ✅ Added changelog to {file_path.name}")
    return True

def main():
    print("🔄 Adding changelog sections to all agents...")
    print(f"📂 Scanning: {AGENTS_DIR}")
    print()

    updated = 0
    skipped = 0

    # Find all .md files
    for md_file in AGENTS_DIR.rglob("*.md"):
        if md_file.name in EXCLUDE_FILES:
            continue

        if add_changelog_to_agent(md_file):
            updated += 1
        else:
            skipped += 1

    print()
    print(f"✨ Complete!")
    print(f"   Updated: {updated} agents")
    print(f"   Skipped: {skipped} agents")

if __name__ == "__main__":
    main()
