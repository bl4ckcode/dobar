# FE_BE_COMMUNICATION.md, BE_DPE_COMMUNICATION.md and API_ERROR_CONTRACT.MD

Always keep FE_BE_COMMUNICATION.MD clean, with the last update only and respecting our principles of clean code.
Always refer to API_ERROR_CONTRACT.MD when creating new error handling in the backend.
Always refer to BE_DPE_COMMUNICATION.MD when creating/changing/deleting/requesting any payment contract or

# Git 
If the user tells you to stage and commit, you may do so. 

You are NEVER allowed to stage and commit files automatically, YOU DO NOT NEED TO WORRY ABOUT UNSTAING OR STAING FILES, OR COMMITING FILES, it is my responsibility to do that.

You are not allowed to deploy to Fly IO as well, we have automations and crendentials for this.

.github/workflows/deploy.yml always run tests and deploy, so we must ensure our unit tests are covering new codes always too otherwise it's gonna fail.

# Database Migrations

The CI pipeline automatically detects changes in `migrations/versions/`. 
- If you add or modify a migration file, the deploy workflow will automatically run `alembic upgrade head`.
- You do **NOT** need to add any special tags like `[migrate]` to your commit messages anymore.