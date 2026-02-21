# Jira Monitor

Automation that polls Jira for **To Do** tickets assigned to you and kicks off Cursor Agent workflows in the backend and/or frontend repos. For each ticket it generates a branch name, decides which repos need changes, skips when the branch already exists, and launches only the relevant agents.

## Prerequisites

- **Shell:** zsh (scripts use `#!/bin/zsh`)
- **Tools:** `jq` (for Jira response parsing), Cursor Agent CLI (`agent` binary)
- **Environment variables** (e.g. in `~/.zshrc`):
  - `JIRA_URL` – Jira base URL (e.g. `https://your-domain.atlassian.net`)
  - `JIRA_EMAIL` – Your Jira user email
  - `JIRA_API_TOKEN` – Jira API token (create in Jira account settings)
- **Paths:** Edit the CONFIG section at the top of `check-jira.sh` if your backend/frontend repos or agent binary live elsewhere:
  - `BACKEND_REPO`, `FRONTEND_REPO`, `AGENT_BIN`

The script expects the **ai repo** layout: this directory lives under `ai/shared/scripts/jira-monitor/`, and the check-jira skill runs with the ai repo root so it can read `backend/.claude/indicators.md` and `frontend/.claude/indicators.md`.

## Scripts

| Script | Purpose |
|--------|--------|
| **check-jira.sh** | Query Jira for your To Do tickets, then for each ticket: generate branch name, run check-jira skill (backend/frontend/both), skip if branch exists, launch repo agents. |
| **setup-cron.sh** | Validate config with a dry-run, then install a cron job so `check-jira.sh` runs every 5 minutes. |

## Running check-jira.sh

**Full run (process tickets):**

```bash
cd /path/to/ai/shared/scripts/jira-monitor
./check-jira.sh
```

If you have no To Do tickets assigned, it exits after one Jira query. If you do, it processes each ticket (branch name → repo decision → agents). A lock file prevents overlapping runs.

**Dry-run (validate only):**

```bash
./check-jira.sh --dry-run
```

Checks Jira credentials, agent binary, repo paths, and ai repo layout. Does not query for tickets or launch any agents. Use this before setting up cron or when debugging.

## Setting up the cron job

```bash
./setup-cron.sh
```

This will:

1. Run `check-jira.sh --dry-run`; if it fails, setup exits.
2. Remove any existing cron entry for this script.
3. Add a job that runs every 5 minutes: `source ~/.zshrc` then `check-jira.sh`, with output appended to `logs/cron.log`.

**To remove the cron job later:**

```bash
crontab -l | grep -v 'check-jira.sh' | crontab -
```

## Logs

- **Cron output:** `logs/cron.log` (stdout/stderr from each cron run)
- **Per-ticket, per-repo:** `logs/<timestamp>_<TICKET-KEY>_backend.log`, `..._frontend.log` (agent output when a repo is run)

## How it fits with the rest of the repo

- **Shared skills** (ai repo): `shared/.claude/skills/generate-branch-name/`, `shared/.claude/skills/check-jira/` define branch naming and “which repos need work.”
- **Repo skills:** Backend and frontend each have `start-jira-work` and `.claude/indicators.md`; the script launches the agent in the corresponding repo so it runs that workflow.

For more detail, see the comments inside `check-jira.sh` and `setup-cron.sh`.
