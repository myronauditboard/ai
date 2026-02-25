# Shared .claude

Shared skills used by the jira-monitor scripts and by backend/frontend workflows. See [shared/README.md](../README.md) for full documentation.

The jira-monitor uses two scripts: **poll-jira.sh** (discovers To Do tickets, invokes check-jira.sh per ticket) and **check-jira.sh** (single-ticket orchestrator; uses this skill to determine which repos need work).

## Skills

| Skill | Purpose |
|-------|--------|
| **determine-repos** | Decides which repos (backend-only, frontend-only, or both) need changes for a Jira ticket. Used by `check-jira.sh`. |
| **generate-branch-name** | Produces a standardized branch name from a Jira ticket ID (max 40 chars). Used by `check-jira.sh` and by start-jira-work when `BRANCH_NAME` is not set. |

Each skill lives in `skills/<name>/SKILL.md`.
