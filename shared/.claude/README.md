# Shared .claude

Shared skills used by the jira-monitor scripts and by backend/frontend workflows. See [shared/README.md](../README.md) for full documentation.

## Skills

| Skill | Purpose |
|-------|--------|
| **check-jira** | Decides which repos (backend-only, frontend-only, or both) need changes for a Jira ticket. Used by `check-jira.sh`. |
| **generate-branch-name** | Produces a standardized branch name from a Jira ticket ID (max 40 chars). Used by `check-jira.sh` and by start-jira-work when `BRANCH_NAME` is not set. |

Each skill lives in `skills/<name>/SKILL.md`.
