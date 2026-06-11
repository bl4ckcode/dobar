#!/usr/bin/env python3
"""
Validate that the Alembic migration chain resolves correctly.
Run this before pushing to CI to catch issues like:
- Missing revision files referenced from other migrations
- Broken down_revision chains
- Duplicate revision IDs

Usage:
    python scripts/validate_migrations.py
    alembic check  # if using Alembic 1.10+
"""

import os
import re
import subprocess
import sys


def check_revision_id_length(migrations_dir: str = "migrations/versions") -> bool:
    """
    Ensure all revision IDs fit in alembic_version.version_num (varchar(32)).
    """
    versions_dir = os.path.join(os.path.dirname(__file__), "..", migrations_dir)
    if not os.path.isdir(versions_dir):
        print(f"⚠️  Could not find {versions_dir}")
        return True  # skip if not found
    
    max_len = 32
    all_ok = True
    
    for filename in sorted(os.listdir(versions_dir)):
        if not filename.endswith(".py") or filename == "__init__.py":
            continue
        filepath = os.path.join(versions_dir, filename)
        with open(filepath) as f:
            content = f.read()
        
        # Extract revision ID from the file
        match = re.search(r'^revision\s*[=:]\s*["\']([^"\']+)["\']', content, re.MULTILINE)
        if not match:
            continue
        rev_id = match.group(1)
        if len(rev_id) > max_len:
            print(f"❌ {filename}: revision ID '{rev_id}' is {len(rev_id)} chars (max {max_len})")
            all_ok = False
    
    return all_ok


def main():
    print("🔍 Checking Alembic migration chain...")
    
    # 1. Check revision ID lengths
    print("📏 Checking revision ID lengths (max 32 chars)...")
    if not check_revision_id_length():
        print("\n💡 Fix: Use a shorter revision ID (e.g. 'add_user_fks' instead of a full sentence)")
        sys.exit(1)
    print("✅ All revision IDs fit within varchar(32)")
    
    # Try `alembic check` first (available in Alembic 1.10+)
    try:
        result = subprocess.run(
            ["alembic", "check"],
            capture_output=True, text=True, timeout=30
        )
        if result.returncode == 0:
            print("✅ alembic check passed — no pending migrations and chain is valid")
            return
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass
    
    # Fallback: validate the chain by running `alembic heads`
    result = subprocess.run(
        ["alembic", "heads"],
        capture_output=True, text=True, timeout=30
    )
    
    if result.returncode == 0:
        print(f"✅ Migration chain valid. Current head(s):\n{result.stdout.strip()}")
    else:
        print(f"❌ Migration chain ERROR:\n{result.stderr}")
        print("\nCommon causes:")
        print("  1. A migration's down_revision references a file that doesn't exist")
        print("  2. A migration file was deleted but another still references it")
        print("  3. Duplicate revision IDs")
        sys.exit(1)


if __name__ == "__main__":
    main()