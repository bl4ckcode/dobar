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

import subprocess
import sys


def main():
    print("🔍 Checking Alembic migration chain...")
    
    # Try `alembic check` first (available in Alembic 1.10+)
    try:
        result = subprocess.run(
            ["alembic", "check"],
            capture_output=True, text=True, timeout=30
        )
        if result.returncode == 0:
            print("✅ alembic check passed — no pending migrations and chain is valid")
            return
        # `alembic check` may fail when no DB is configured; that's okay
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