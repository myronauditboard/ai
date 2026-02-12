# General - Shared Skills and Utilities

This directory contains shared skills and utilities that are used across multiple repositories (backend, frontend, etc.).

## Purpose

When you need logic or workflows that should be consistent across all repositories, place them here as skills. This ensures a single source of truth and prevents divergence.

## Skills

### `generate-branch-name`

**Location**: `.claude/skills/generate-branch-name/SKILL.md`

**Purpose**: Generates standardized Git branch names from Jira ticket IDs.

**Usage**: Called by `start-jira-work` skills in backend and frontend repos to ensure consistent branch naming across all repositories working on the same ticket.

**Format**: `{TICKET-ID}-{first-30-chars-of-sanitized-title}`

**Example**: `SOX-XXXXX-add-compliance-checks`

## How to Add New Shared Skills

1. Create a new skill directory under `.claude/skills/`
2. Add the `SKILL.md` file with the skill logic
3. Reference the skill from other repositories using the full path:
   ```
   /Users/myeung/Development/ai/general/.claude/skills/{skill-name}/SKILL.md
   ```
4. Update this README with documentation about the new skill

## Benefits

- **Single Source of Truth**: Logic defined once, used everywhere
- **Consistency**: All repos follow the same patterns and rules
- **Maintainability**: Update one place, all repos benefit
- **Discoverability**: Clear location for shared utilities
