#!/usr/bin/env python3
"""
MyConvergio Agent Translation Script

This script helps translate agent files from English to Italian.
"""

import os
import re
import shutil
from pathlib import Path

# Configuration
SRC_DIR = Path("../claude-agents")
TARGET_DIR = Path("../claude-agenti")

# Common translations
TRANSLATIONS = [
    (r'You are (\w+), the (.+)', r'Sei \1, il/la \2'),
    (r'description: "(.+)"', r'description: "[IT] \1"'),
    (r'# (.+)', r'# \1'),  # Keep headers in English for now
    (r'## (.+)', r'## \1'),
    (r'### (.+)', r'### \1'),
]

def add_translation_notice(content):
    """Add translation notice to the content."""
    notice = """\
<!-- 
  TRADUZIONE IN ITALIANO - ITALIAN TRANSLATION
  Questo file è una traduzione automatica. Per favore verifica e adatta la traduzione secondo necessità.
  This is an automatic translation. Please verify and adapt the translation as needed.
-->
"""
    return notice + content

def translate_content(content):
    """Apply basic translations to content."""
    for pattern, replacement in TRANSLATIONS:
        content = re.sub(pattern, replacement, content, flags=re.IGNORECASE)
    return content

def process_file(src_path, target_path):
    """Process a single file."""
    print(f"Translating: {src_path.relative_to(SRC_DIR)}")
    
    # Read source file
    with open(src_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Add translation notice
    content = add_translation_notice(content)
    
    # Apply translations
    content = translate_content(content)
    
    # Write to target file
    target_path.parent.mkdir(parents=True, exist_ok=True)
    with open(target_path, 'w', encoding='utf-8') as f:
        f.write(content)

def main():
    print("Starting translation from English to Italian...")
    
    # Process all markdown files
    for src_path in SRC_DIR.glob('**/*.md'):
        rel_path = src_path.relative_to(SRC_DIR)
        target_path = TARGET_DIR / rel_path
        process_file(src_path, target_path)
    
    print("\nTranslation complete!")
    print(f"Files have been translated to: {TARGET_DIR}")
    print("Please review the translations and make any necessary adjustments.")

if __name__ == "__main__":
    main()
