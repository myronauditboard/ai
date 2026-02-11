# Jira Workflow

Streamlining Development with AI

---

## Overview

- Goals
- 
---

## Goals

- Create rules and skills that can be leveraged across thet team
- Stretch: Hands-off Automated workflows

--

## Automation

Leveraging scripts and integrations

--

### Monitoring Script

The repo includes a Jira monitoring script:

```bash
scripts/jira-monitor/check-jira.sh
```

--

### Ticket Management

- Keep descriptions clear and actionable
- Break large tasks into subtasks
- Use labels and components consistently
- Link related tickets

--

## Tips

Practical advice for AI-assisted development

--

### AI Model Selection

- Use **Plan mode** with sophisticated models like Opus for complex planning
- Switch to economical **Agent mode** like Sonnet or Composer (Elya's fav) for implementation

--

### Environment Setup

- Grant your IDE/terminal **full disk access** in system preferences
- Keep **GPG signing** up-to-date for autonomous git operations
- Properly configured permissions enable seamless automation

--

### Managing Context Windows

- **Create new chat windows often** - don't overload context
- Use compaction to continue work in another window or different LLM
- General rule: **Don't engage the AI more than 8 times** in one chat

--

### Cursor Shortcuts

Slash commands in the Agent chat window:

- `/<skill name>` - Invoke custom skills
- `@<file name>` - Autocomplete and reference files

--

### Multi-Project Workflows

It is possible to have one agent work on `auditboard-backend` and `auditboard-frontend` simultaneously:

- Open the parent folder in Cursor
- Engage AI

---

## TODOs

Work items and improvements

--

### Cross-Platform AI Tooling

- Port skills and instructions to VSCode Copilot
- Russell Jones will be releasing SATL (Shared AI Tooling Layer) to automate migration between platforms

--

### Quality & Documentation

- Add E2E tests when necessary and test thoroughly
- Find and link to more documentation on coding conventions and standards

--

### Monitoring & Logging

- Make cron job more verbose about what it's doing
- Surface `start-jira-work` messages into the console for better visibility

--

### GitHub Integration

- Set label in GitHub to `pr-deploy`
- Add Copilot as a reviewer automatically

--

### Code Organization

- `start-jira-work` task is getting large - break it up further
- Better organization: should instructions be in their own folder?

--

### Infrastructure

- Wire up env to receive Slack messages (waiting on admin authorization)
- More sample CLI commands
- Offload tasks to shell scripts or direct API calls where possible

---

## Questions?

Thank you for attending!

Notes:
- For more information, check the repo documentation
- Reach out to the team for specific questions
