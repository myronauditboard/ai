# Shared Skills and Utilities

Skills and scripts used across multiple repositories (backend, frontend, etc.). Single source of truth for shared logic.

## Skills (`.claude/skills/`)

### `generate-branch-name`

**Location**: `.claude/skills/generate-branch-name/SKILL.md`

**Purpose**: Generates standardized Git branch names from Jira ticket IDs.

**Usage**: Called by `check-jira.sh` and by `start-jira-work` in backend/frontend when `BRANCH_NAME` is not set.

**Format**: `{TICKET-ID}-{sanitized-title}` with the **entire** branch name truncated to **40 characters** (ticket ID unchanged; title lowercased, non-alphanumeric → hyphen, then truncate).

**Example**: `SOX-81757-launchdarkly-flag-deprecate-an`

### `determine-repos`

**Location**: `.claude/skills/determine-repos/SKILL.md`

**Purpose**: Decides which repos (backend-only, frontend-only, or both) need changes for a Jira ticket.

**Usage**: Called by `check-jira.sh` before launching backend/frontend agents. Reads `backend/.claude/indicators.md` and `frontend/.claude/indicators.md` from the ai repo.

**Output**: One of `backend-only`, `frontend-only`, `both`.

## Scripts

**[scripts/jira-monitor/](scripts/jira-monitor/README.md)** – Two-script flow: **poll-jira.sh** discovers your To Do tickets and invokes **check-jira.sh** per ticket; check-jira.sh validates the ticket, checks branches via GitHub CLI, runs the determine-repos skill, then backend then frontend agents. See that README for prerequisites, `--dry-run`, and launchd/cron setup.

## How to add a new shared skill

1. Create `.claude/skills/<skill-name>/SKILL.md` with the skill logic and frontmatter.
2. Reference it from scripts (e.g. `check-jira.sh` uses `AI_REPO_ROOT` so the agent can read `shared/.claude/skills/...`) or from other repos by path.
3. Document the skill in this README.
