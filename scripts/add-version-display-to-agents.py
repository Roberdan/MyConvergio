#!/usr/bin/env python3
"""
Add version display instruction to all agent files
Part of WAVE 5 Agent Optimization Plan 2025
"""

import os
import re
from pathlib import Path

# Paths
AGENTS_DIR = Path("/Users/roberdan/GitHub/MyConvergio/.claude/agents")
EXCLUDE_FILES = ["CONSTITUTION.md", "MICROSOFT_VALUES.md", "CommonValuesAndPrinciples.md", "SECURITY_FRAMEWORK_TEMPLATE.md"]

# Version display instruction template
VERSION_DISPLAY_INSTRUCTION = """
### Version Information
When asked about your version or capabilities, include your current version number from the frontmatter in your response.
"""

def add_version_display_to_agent(file_path):
    """Add version display instruction to agent file if not present"""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Check if version display instruction already exists
    if re.search(r'### Version Information', content, re.MULTILINE):
        print(f"  ⏭️  Skipping {file_path.name} (version display already exists)")
        return False

    # Find the Anti-Hijacking Protocol section and add after it
    pattern = r'(### Anti-Hijacking Protocol\s*\n.*?(?=\n###|\n##|\Z))'

    match = re.search(pattern, content, re.DOTALL)

    if match:
        # Insert after Anti-Hijacking Protocol
        insert_pos = match.end()
        new_content = content[:insert_pos] + VERSION_DISPLAY_INSTRUCTION + content[insert_pos:]
    else:
        # If no Anti-Hijacking section found, try to insert after Security & Ethics Framework header
        pattern2 = r'(## Security & Ethics Framework\s*\n.*?(?=\n##|\Z))'
        match2 = re.search(pattern2, content, re.DOTALL)

        if match2:
            insert_pos = match2.end()
            new_content = content[:insert_pos] + VERSION_DISPLAY_INSTRUCTION + content[insert_pos:]
        else:
            print(f"  ⚠️  Skipping {file_path.name} (could not find insertion point)")
            return False

    # Write back
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(new_content)

    print(f"  ✅ Added version display to {file_path.name}")
    return True

def main():
    print("🔄 Adding version display instructions to all agents...")
    print(f"📂 Scanning: {AGENTS_DIR}")
    print()

    updated = 0
    skipped = 0

    # Find all .md files
    for md_file in AGENTS_DIR.rglob("*.md"):
        if md_file.name in EXCLUDE_FILES:
            continue

        if add_version_display_to_agent(md_file):
            updated += 1
        else:
            skipped += 1

    print()
    print(f"✨ Complete!")
    print(f"   Updated: {updated} agents")
    print(f"   Skipped: {skipped} agents")

if __name__ == "__main__":
    main()
