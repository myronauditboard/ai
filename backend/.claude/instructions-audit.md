---
name: instructions-audit
description: Main implementation workflow for AuditBoard backend. Referenced by start-jira-work after branch creation. Covers plan creation, implementation, tests, lint, and plan updates.
---

# AuditBoard Backend - Implementation Workflow

**Usage**: This file is referenced by `.claude/skills/start-jira-work/SKILL.md` after branch creation to guide the complete implementation workflow.

## Implementation Process

When starting work on a ticket (after branch is created), follow these steps:

### 1. Create Plan File

Create the plan in `.claude/plans/plan-{TICKET-ID}-backend.md` (e.g., `.claude/plans/plan-SOX-12345-backend.md`). If the folder `.claude/plans` does not exist, create it first (e.g., `mkdir -p .claude/plans`).

The plan should include:

- Summary of the ticket requirements
- High-level approach
- List of files to create/modify
- Testing strategy
- Any technical considerations or decisions

**Important**: This file is for development tracking only. Save it but do NOT commit it.

### 2. Implement Changes

Implement the changes following the coding standards below.

### 3. Create Tests

Write tests following the testing standards below.

### 4. Lint and Prettify

Run linting and formatting on all changed files:

```bash
pnpm lint <path-to-file>
pnpm exec prettier <path-to-file> --write
```

Fix any linter errors that are introduced.

### 5. Run Tests

Verify all tests pass:

```bash
pnpm tester <path-to-test-file>
```

If tests fail, fix issues and re-run until all pass.

### 6. Update Plan

Update the plan file (`.claude/plans/plan-{TICKET-ID}-backend.md`) to reflect what was actually implemented. This creates a record of what changed vs. what was originally planned.

Save the updated plan but do NOT commit it.

### 7. Return to start-jira-work

Once all lint, prettify, and tests pass successfully, return to `.claude/skills/start-jira-work/SKILL.md` Step 4 to create the commit and PR.

---

## External Documentation

The main repository README points to comprehensive engineering guides on Coda:

- [AuditBoard Engineering Docs](https://coda.io/d/Engineering-Guides_dPCW4QV21AE/Engineering-Processes_suO7zRcL)
- [API Testing Guide](https://coda.io/d/Engineering-Guides_dPCW4QV21AE/API-Tests_suNDnVed#_luaRFc4Z)
- [Debugging Guide](https://coda.io/d/Engineering-Guides_dPCW4QV21AE/Debugging_suoXBhWa)
- [Database Migrations](https://coda.io/d/Engineering-Guides_dPCW4QV21AE/Schema-Migrations_su4tYVmY)

## General Guidelines

- Write clear and concise commit messages
- Ensure code is well-documented and follows the project's coding standards
- Review changes for any potential performance or security issues
- No hallucinations - when in doubt, ask for clarification
- Do not include sensitive information in commit messages or code

## Architecture Standards

The repository follows a **monorepo structure** with clear separation:

- **`common/`** - Foundational architectural components and cross-cutting concerns
- **`contexts/`** - Business domain modules (e.g., `compliance-assessments`)
- **`data-access-layer/`** - Data access abstractions
- **`integrations/`** - Third-party service interfaces
- **`tools/`** - Internal developer utilities
- **`utils/`** - General-purpose, domain-agnostic utilities

## TypeScript Configuration

The repository uses a centralized TypeScript configuration:

- Uses `@auditboard/shared-config/tsconfig-base.json`
- Experimental decorators enabled
- Source maps enabled
- Path aliases for all major modules (see `tsconfig.json`)

## Code Formatting Standards

The repository uses Prettier (`.prettierrc.cjs`) and EditorConfig (`.editorconfig`) for consistent code formatting:

- **Single quotes** for strings
- **Tabs** for indentation (except JSON/YAML which use spaces)
- **120 character** line width
- **Trailing commas** everywhere
- **Arrow parens** always included
- **Bracket spacing** enabled
- **Insert final newline** in all files
- **Trim trailing whitespace**

## Linting Rules

The repository uses custom ESLint plugins (`eslint.config.mjs`) with specific rules:

- `@auditboard/eslint-plugin` - Custom AuditBoard rules
- `@soxhub/lint/eslint` - SoxHub linting configuration

**Custom rules include:**

- No bare string messages in notifications/growl
- No direct manager imports
- Restricted Bluebird functions
- Vitest describe source requirements
- One eslint-disable per line

## Testing Standards

- Write unit tests for all new functionality
- Ensure existing tests pass after making changes
- Use mocks and stubs where appropriate to isolate the code under test
- Run tests frequently during development to catch issues early
- Tests are partitioned in `test-runner/manifest.json`
- **New tests must be assigned to a partition**
- If there is a database error, run `pnpm db:migrate:test`
- Run `pnpm lint <path-to-file>` on individual files (not `pnpm lint` on entire codebase)
