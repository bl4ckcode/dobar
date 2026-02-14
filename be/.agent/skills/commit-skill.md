# FE_BE_COMMUNICATION.md, BE_DPE_COMMUNICATION.md and API_ERROR_CONTRACT.MD

Always keep FE_BE_COMMUNICATION.MD clean, with the last update only and respecting our principles of clean code.
Always refer to API_ERROR_CONTRACT.MD when creating new error handling in the backend.
Always refer to BE_DPE_COMMUNICATION.MD when creating/changing/deleting/requesting any payment contract or

# Git 
If the user tells you to stage and commit, you may do so. 

You are NEVER allowed to stage and commit files automatically, YOU DO NOT NEED TO WORRY ABOUT UNSTAING OR STAING FILES, OR COMMITING FILES, it is my responsibility to do that.

You are not allowed to deploy to Fly IO as well, we have automations and crendentials for this.

.github/workflows/deploy.yml always run tests and deploy, so we must ensure our unit tests are covering new codes always too otherwise it's gonna fail.

# When to Use [migrate] in Commit Messages

## ✅ USE [migrate] when:
- You created a NEW migration file in `migrations/versions/`
- The migration adds/removes tables, columns, indexes, or constraints
- The Alembic chain has been updated (new revision ID at head)

## ❌ DO NOT use [migrate] when:
- Only code changes (routes, services, schemas, tests)
- Database changes were applied manually via psql
- Fixing bugs in existing code
- No new files in `migrations/versions/`

## Quick Check:
```bash
git status | grep migrations/versions