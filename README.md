# ai

AI and automation for development workflows (Jira-driven branch naming, repo relevance, and agent orchestration).

- **[shared/](shared/)** – Shared skills and utilities (branch naming, determine-repos) and the [jira-monitor scripts](shared/scripts/jira-monitor/README.md) (poll-jira + check-jira).
- **backend/**, **frontend/** – Repo-specific `.claude/` instructions and skills (start-jira-work, indicators, audit workflows). Sync these into the actual backend/frontend repos so agents can run there.

Presentations: [myronauditboard.github.io/ai](https://myronauditboard.github.io/ai/)
