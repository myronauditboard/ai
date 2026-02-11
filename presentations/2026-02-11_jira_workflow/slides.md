# Jira Workflow

Streamlining Development with Automation

---

## Overview

- Jira integration for tracking work
- Automated workflows
- Best practices for team collaboration

--

### Key Benefits

- Improved visibility into work progress
- Reduced manual tracking overhead
- Better alignment between code and tasks

---

## Getting Started

Setting up your Jira workflow

--

### Prerequisites

- Jira account with appropriate permissions
- Git repository configured
- Understanding of your team's workflow

--

### Configuration Steps

1. Connect Jira to your repository
2. Set up automation rules
3. Configure branch naming conventions
4. Enable smart commits

---

## Daily Workflow

How to use Jira effectively

--

### Starting Work

```bash
# Create feature branch from ticket
git checkout -b feature/PROJ-123-add-login
```

--

### Making Progress

- Update ticket status as you work
- Add comments with technical details
- Link PRs to tickets automatically

--

### Code Review Process

- Reference ticket numbers in PR descriptions
- Use smart commits for automatic updates
- Track review feedback in Jira comments

---

## Automation

Leveraging scripts and integrations

--

### Monitoring Script

The repo includes a Jira monitoring script:

```bash
scripts/jira-monitor/check-jira.sh
```

--

### Benefits of Automation

- Automatic status updates
- Notifications for blockers
- Time tracking integration
- Release notes generation

---

## Best Practices

Tips for effective Jira usage

--

### Ticket Management

- Keep descriptions clear and actionable
- Break large tasks into subtasks
- Use labels and components consistently
- Link related tickets

--

### Communication

- Add meaningful comments with context
- Tag team members when needed
- Document decisions in tickets
- Keep stakeholders informed

---

## Tips

Practical advice for AI-assisted development

--

### AI Model Selection

- Use **Plan mode** with sophisticated models like Opus for complex planning
- Switch to economical **Agent mode** with Sonnet or Composer for implementation
- Composer is Elya's favorite for routine tasks

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

Update `auditboard-backend` and `auditboard-frontend` simultaneously:

- Open the parent folder in Cursor
- Work across both repos in one session

---

## TODO

Work items and improvements

--

### Monitoring & Logging

- Make cron job more verbose about what it's doing
- Surface `start-jira-work` messages into the console for better visibility

--

### GitHub Integration

- Set label in GitHub to `pr-deploy`
- Add Copilot as a reviewer automatically

--

### Cross-Platform AI Tooling

- Port skills and instructions to VSCode Copilot
- Explore SATL (Shared AI Tooling Layer) from Russell Jones

--

### Code Organization

- `start-jira-work` task is getting large - break it up further
- Better organization: should instructions be in their own folder?

--

### Infrastructure

- Wire up env to receive Slack messages (waiting on admin authorization)
- More sample CLI commands
- Offload tasks to shell scripts or direct API calls where possible

--

### Quality & Documentation

- Add E2E tests when necessary and test thoroughly
- Find and link to more documentation on coding conventions and standards

---

## Questions?

Thank you for attending!

Notes:
- For more information, check the repo documentation
- Reach out to the team for specific questions
