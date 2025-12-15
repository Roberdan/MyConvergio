#!/usr/bin/env python3
"""
Add version field to all agent frontmatter
Part of WAVE 5 Agent Optimization Plan 2025
"""

import os
import re
from pathlib import Path

# Paths
AGENTS_DIR = Path("/Users/roberdan/GitHub/MyConvergio/.claude/agents")
EXCLUDE_FILES = ["CONSTITUTION.md", "MICROSOFT_VALUES.md", "CommonValuesAndPrinciples.md", "SECURITY_FRAMEWORK_TEMPLATE.md"]

def add_version_to_agent(file_path):
    """Add version: 1.0.0 to agent frontmatter if not present"""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Check if version already exists
    if re.search(r'^version:', content, re.MULTILINE):
        print(f"  ⏭️  Skipping {file_path.name} (version already exists)")
        return False

    # Find the frontmatter section
    if not content.startswith('---'):
        print(f"  ⚠️  Skipping {file_path.name} (no frontmatter found)")
        return False

    # Split content into frontmatter and body
    parts = content.split('---', 2)
    if len(parts) < 3:
        print(f"  ⚠️  Skipping {file_path.name} (malformed frontmatter)")
        return False

    frontmatter = parts[1]
    body = parts[2]

    # Add version field after the last field in frontmatter
    # Find the last non-empty line
    frontmatter_lines = frontmatter.rstrip().split('\n')
    frontmatter_lines.append('version: "1.0.0"')

    # Reconstruct the file
    new_content = '---\n' + '\n'.join(frontmatter_lines) + '\n---' + body

    # Write back
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(new_content)

    print(f"  ✅ Added version to {file_path.name}")
    return True

def main():
    print("🔄 Adding version: 1.0.0 to all agent frontmatter...")
    print(f"📂 Scanning: {AGENTS_DIR}")
    print()

    updated = 0
    skipped = 0

    # Find all .md files
    for md_file in AGENTS_DIR.rglob("*.md"):
        if md_file.name in EXCLUDE_FILES:
            continue

        if add_version_to_agent(md_file):
            updated += 1
        else:
            skipped += 1

    print()
    print(f"✨ Complete!")
    print(f"   Updated: {updated} agents")
    print(f"   Skipped: {skipped} agents")

if __name__ == "__main__":
    main()
