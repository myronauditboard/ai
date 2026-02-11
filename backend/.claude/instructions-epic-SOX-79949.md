---
name: instructions-epic-SOX-79949
description: Epic-specific instructions for LaunchDarkly flag cleanup (SOX-79949). Used in addition to instructions-audit when a ticket belongs to this epic. Guides flag removal via the remove-dev-flag skill.
epic: SOX-79949
---

# LaunchDarkly Flag Cleanup - SOX-79949

**Usage**: This file provides epic-specific instructions for tickets belonging to SOX-79949. It is automatically referenced by `start-jira-work` when a ticket belongs to this epic.

**Epic**: https://auditboard.atlassian.net/browse/SOX-79949  
**Flags List**: https://coda.io/d/Audit-Team-Hub_dXXykCrvx2t/LaunchDarkly-Feature-Flags_suEkhWP1#_tuInrDNW  
**Best Practices**: https://coda.io/d/Guide-to-Release-Management-Process-LaunchDarkly-Best-Practices_dYr3XN9mQzD/Cleaning-Up-Development-Flags_su1zSqOa#_luIHcV9S

## Overview

Remove LaunchDarkly feature flags that have been fully rolled out from code, tests, and configuration.

This epic includes 14 flags ready for cleanup across backend and frontend codebases.

## Integration with Main Workflow

This file is used **in addition to** `.claude/instructions-audit.md`. When working on a ticket from this epic:

1. Follow the main implementation workflow in `.claude/instructions-audit.md`
2. Apply the epic-specific guidance below
3. For flag removal tickets, use the `@remove-dev-flag` skill as described below

## Epic-Specific Implementation Steps

### When to Use remove-dev-flag Skill

**If the ticket is about removing a LaunchDarkly flag** (check ticket title/description), use the `@remove-dev-flag` skill as part of the standard implementation workflow.

The ticket title will typically contain the flag name (e.g., "Remove ai-assisted-annotate flag").

### Modified Workflow for Flag Removal

Follow the main workflow in `.claude/instructions-audit.md` with this modification:

**Step 1: Create Plan File** (from instructions-audit.md)
- Create `.claude/plans/plan-{TICKET-ID}-backend.md` (create `.claude/plans` folder if it does not exist)
- Include the flag name and approach

**Step 2-5: Use remove-dev-flag Skill**

Instead of manually implementing, use the skill:

```
@remove-dev-flag {flag-name}
```

Example:
```
@remove-dev-flag ai-assisted-annotate
```

The skill automatically handles:
1. Removes flag from `DevelopmentFlagName` type in `app/lib/development-flag-service.ts`
2. Finds all usages of `developmentFlagService.getFlag`
3. Removes conditionals, keeping enabled-branch code
4. Cleans up `devFlag` in controller options
5. Removes/updates test setup with `setDevelopmentFlags`
6. Runs prettier and linting on changed files
7. Runs tests to verify changes

**The skill follows all code standards, testing requirements, and formatting rules from instructions-audit.md.**

**Step 6: Update Plan** (from instructions-audit.md)
- Update `.claude/plans/plan-{TICKET-ID}-backend.md` to reflect what was actually changed
- Save but do NOT commit

**Step 7: Return to start-jira-work** (from instructions-audit.md)
- Continue to commit and PR creation

### Backend Flags from Epic

These flags exist in `app/lib/development-flag-service.ts`:

- ✅ `ai-assisted-annotate` (line 17)
- ✅ `annotate-files-in-controls` (line 26)
- ✅ `annotate-markup-preconversion` (line 27)

**Note**: Most flags from the epic (11 of 14) are frontend-only and not in this backend repo.

### Manual Verification Steps

After using `@remove-dev-flag`:

1. **Code verification**: `grep -rn "flag-name" .` (should find no references)
2. **LaunchDarkly console**: Archive or delete the flag
3. **Run tests**: Ensure all affected tests pass
4. **Update tracker**: Mark flag as complete in Coda

## Frontend Flags

The following flags are frontend-only (not in this backend repo):

- `annotate-annotation-labels`
- `annotate-attribute-bulk-upload`
- `annotate-evidence-tab-updates`
- `annotate-keyword-search`
- `annotate-multiple-annotations`
- `annotate-results-without-annotations`
- `annotate-samples-table-columns-rows`
- `control-get-request-for-control-provider`
- `resource-planner-other-projects`
- `resource-planner-sox`
- `soxhub-control-self-assessments`

These require removal in the frontend repository using frontend-specific tools.

## Important Context

### Backend Flag Architecture

In this codebase:

- **LaunchDarkly flags === "dev flags"**
- All managed through `developmentFlagService` using LaunchDarkly SDK
- Centralized in `app/lib/development-flag-service.ts`
- Backend uses same patterns as internal dev flags

### Removal Principles

When removing flags (enabled state assumed):

- ✅ Keep: Enabled-branch code
- ❌ Remove: Disabled-branch code
- ❌ Remove: Conditional checks
- ❌ Remove: Test cases for disabled state
- ✅ Keep: Test cases for enabled state (update descriptions as needed)

### Common Patterns

**Service/Handler Code:**

```typescript
// BEFORE
const isEnabled = await developmentFlagService.getFlag('flagName', user, false);
if (isEnabled) {
	doNewBehavior();
} else {
	doOldBehavior();
}

// AFTER
doNewBehavior();
```

**Controller Code:**

```typescript
// BEFORE
super(server, {
	resourceName: 'MyResource',
	devFlag: 'flagName',
});

// AFTER
super(server, {
	resourceName: 'MyResource',
});
```

**Test Code:**

```typescript
// BEFORE
beforeEach(function () {
	setDevelopmentFlags({
		flagName: true,
		otherFlag: false,
	});
});

// AFTER (if other flags remain)
beforeEach(function () {
	setDevelopmentFlags({
		otherFlag: false,
	});
});

// AFTER (if no flags remain)
beforeEach(function () {
	// setDevelopmentFlags call removed entirely
});
```

## Tips for Claude/Cursor

When working with this epic:

1. **Always use the skill first**: Don't manually search/replace - use `@remove-dev-flag` for consistency
2. **Verify the flag exists**: Check `development-flag-service.ts` before starting work
3. **Check both repos**: Some flags might exist in both backend and frontend
4. **Read the skill output**: The skill reports what it changed - review carefully
5. **Test after removal**: Run tests to catch any issues immediately

## References

- **Skill documentation**: `.claude/skills/remove-dev-flag/SKILL.md`
- **Cursor rule**: `.cursor/rules/launchdarkly-flag-cleanup-epic.mdc`
- **Epic in Jira**: SOX-79949
- **Flag tracker**: [Coda - SoxHub Flags](https://coda.io/d/Audit-Team-Hub_dXXykCrvx2t/LaunchDarkly-Feature-Flags_suEkhWP1#_tuInrDNW)
