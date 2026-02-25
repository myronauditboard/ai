# Backend .claude

Claude instructions and skills for the **backend** repo (e.g. auditboard-backend). Copy or sync this directory into that repo’s `.claude/` so the agent can run the Jira workflow and implementation guidance there.

## Contents

| File / directory | Purpose |
|------------------|--------|
| **indicators.md** | Criteria for “does this Jira ticket need backend work?” Referenced by the shared `determine-repos` skill and by `start-jira-work` when run standalone. |
| **instructions-audit.md** | Main implementation workflow (plan, implement, test, lint). Used by `start-jira-work` after branch creation. |
| **instructions-epic-*.md** | Epic-specific overrides (e.g. SOX-79949). Consulted when the ticket belongs to that epic. |
| **skills/start-jira-work/** | End-to-end Jira workflow: lookup ticket, check relevance (or skip if `REPO_NEEDED=true`), create branch, hand off to instructions-audit, commit, move ticket, create PR. |

## Deployment

Ensure the **actual** backend repo (e.g. `auditboard-backend`) has a `.claude/` tree that matches this one (including `indicators.md`), so that:

- **From check-jira.sh:** The script passes `REPO_NEEDED=true` and the agent skips the relevance check.
- **Manual runs:** The agent can read `.claude/indicators.md` to decide if backend work is needed.
