# Jira Workflow

Streamlining Development with AI

---

## Overview

- Goals
- Instructions and skills walkthrough
- Jira-triggered workflow walkthrough
- Demo
- Tips
- Future improvements

---

## Goals

- Create rules and skills that can be leveraged across the team
- Hands-off automated workflow

---

## Instructions and skills walkthrough

---

### General Audit instructions

- Backend: [instructions-audit.md](https://github.com/myronauditboard/ai/blob/main/backend/.claude/instructions-audit.md)
- Frontend: [instructions-audit.md](https://github.com/myronauditboard/ai/blob/main/frontend/.claude/instructions-audit.md)

---

### LD Deprecation instructions

- Backend: [instructions-epic-SOX-79949.md](https://github.com/myronauditboard/ai/blob/main/backend/.claude/instructions-epic-SOX-79949.md)
- Frontend: [instructions-epic-SOX-79949.md](https://github.com/myronauditboard/ai/blob/main/frontend/.claude/instructions-epic-SOX-79949.md)

---

### Skills

- Backend: [start-jira-work/SKILL.md](https://github.com/myronauditboard/ai/blob/main/backend/.claude/skills/start-jira-work/SKILL.md)
- Frontend: [start-jira-work/SKILL.md](https://github.com/myronauditboard/ai/blob/main/frontend/.claude/skills/start-jira-work/SKILL.md)

---

## Jira-triggered workflow walkthrough

- Assign a Jira ticket to you with status: To Do
- Runs every 10 minutes (easy to customize)
- Automatically create a PR

---

### How to set up the workflow

- One time: `$ ai/scripts/jira-monitor/check-jira.sh`
- Set up cron job: `$ ai/scripts/jira-monitor/setup-cron.sh`

---

### Keeping tabs on the workflow

- Check that it is running: `$ crontab -l | grep check-jira`
- Realtime logging: `$ tail -f ai/scripts/jira-monitor/logs/cron.log`
- Logs: `$ ls -lt /Users/myeung/Development/ai/scripts/jira-monitor/logs/`
- Remove cron job: `$ crontab -l | grep -v 'check-jira.sh' | crontab -`

---

### Scripts

- [skills/jira-monitor/check-jira.sh](https://github.com/myronauditboard/ai/blob/main/scripts/jira-monitor/check-jira.sh)
- [skills/jira-monitor/setup-cron.sh](https://github.com/myronauditboard/ai/blob/main/scripts/jira-monitor/setup-cron.sh)

---

## Demo

---

### LD deprecation

- Prompt from `auditboard-frontend`: `start-jira-work SOX-81756`

---

### Jira-triggered workflow

- Check first Jira ticket mentioned earlier in the demo

---

## Tips

Practical advice for AI-assisted development

---

### Ticket Management

- Keep descriptions clear and actionable
- Break large tasks into subtasks
- Use labels and components consistently
- Link related tickets

---

### AI Model Selection

- Minimize token usage
- Use **Plan mode** with sophisticated models like Opus for complex planning
- Switch to economical **Agent mode** like Sonnet or Composer (Elya's fav) for implementation

---

### Environment Setup

- Grant your IDE/terminal **full disk access** in system preferences
- Keep **GPG signing** up-to-date for autonomous git operations
- Properly configured permissions enable seamless automation

---

### Context and token efficiency

---

#### Managing Context Windows

- **Create new chat windows often** - don't overload context
- Use compaction to continue work in another window or different LLM
- General rule: **Don't engage the AI more than 8 times** in one chat, otherwise the LLM starts getting forgetful

---

#### Don't include all the things

- Include references to other resources
- Add conditionals to determine which resources to load into the context

---

#### Leverage scripts

- Reduces context load too
- More deterministic behavior

---

### Cursor Shortcuts

Slash commands in the Agent chat window:

- `/<skill name>` - Invoke custom skills
- `@<file name>` - Autocomplete and reference files

---

### Multi-Project Workflows

It is possible to have one agent work on `auditboard-backend` and `auditboard-frontend` simultaneously:

- Open the parent folder in Cursor
- Engage AI

---

## Future improvements

Work items and improvements

---

### Cross-Platform AI Tooling

- Port skills and instructions to VSCode Copilot
- Russell Jones will be releasing SATL (Shared AI Tooling Layer) to automate migration between platforms

---

### Quality & Documentation

- Add E2E tests when necessary and test thoroughly
- Find and link to more documentation on coding conventions and standards

---

### Monitoring & Logging

- Make cron job more verbose about what it's doing
- Surface `start-jira-work` messages into the console for better visibility

---

### GitHub Integration

- Set label in GitHub to `pr-deploy`
- Add Copilot as a reviewer automatically

---

### Code Organization

- `start-jira-work` task is getting large - break it up further
- Better organization: should instructions be in their own folder?

---

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
