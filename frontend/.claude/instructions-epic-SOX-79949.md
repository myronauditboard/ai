---
name: instructions-epic-SOX-79949
description: Epic-specific instructions for SOX-79949 (LaunchDarkly Flag Cleanup). Guides removal of fully-rolled-out feature flags from frontend code, tests, and configuration using the remove-dev-flag skill. Automatically referenced by start-jira-work when a ticket belongs to this epic.
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

The ticket title will typically contain the flag name (e.g., "Remove annotate-keyword-search flag").

### Modified Workflow for Flag Removal

Follow the main workflow in `.claude/instructions-audit.md` with this modification:

**Step 1: Create Plan File** (from instructions-audit.md)
- Create `.claude/plans/plan-{TICKET-ID}-frontend.md` (create `.claude/plans` folder if it does not exist)
- Include the flag name and approach

**Step 2-4: Use remove-dev-flag Skill**

Instead of manually implementing, use the skill:

```
@remove-dev-flag {flag-name}
```

Example:
```
@remove-dev-flag annotate-keyword-search
```

The skill automatically handles:
1. Finds all usages of `devFlag('flagName')` in templates and components
2. Finds all usages of `developmentFlags.getFlag('flagName')` in services/utils
3. Removes conditionals, keeping enabled-branch code
4. Removes `withFlag` and `withFlags` calls in tests
5. Removes entire tests that only test disabled state
6. Cleans up imports (`devFlag`, `developmentFlags`, `withFlag`, `withFlags`) if no longer used
7. Runs prettier on changed files

**The skill follows all code standards and formatting rules from instructions-audit.md.**

**Step 5: Update Plan** (from instructions-audit.md)
- Update `.claude/plans/plan-{TICKET-ID}-frontend.md` to reflect what was actually changed
- Save but do NOT commit

**Step 6: Return to start-jira-work** (from instructions-audit.md)
- Continue to commit and PR creation

### Frontend Flags from Epic

These flags exist in this frontend repository:

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

**Note**: 3 flags from the epic (`ai-assisted-annotate`, `annotate-files-in-controls`, `annotate-markup-preconversion`) are backend-only and not in this frontend repo.

### Manual Verification Steps

After using `@remove-dev-flag`:

1. **Code verification**: Search for the flag name across the repo (should find no references)
2. **LaunchDarkly console**: Archive or delete the flag
3. **Update tracker**: Mark flag as complete in Coda

## Important Context

### Frontend Flag Architecture

In this codebase:

- **LaunchDarkly flags === "dev flags"**
- The `devFlag` helper (`soxhub-client/helpers/dev-flag`) wraps `developmentFlags.getFlag` for use in templates and components
- The underlying flag service lives at `@auditboard/client-core/utils/development-flags`
- In tests, flags are managed via `withFlag` and `withFlags` from `soxhub-client/tests/helpers/setup-auditboard-tests`

### Removal Principles

When removing flags (enabled state assumed):

- ✅ Keep: Enabled-branch code
- ❌ Remove: Disabled-branch code
- ❌ Remove: Conditional checks
- ❌ Remove: Test cases for disabled state
- ✅ Keep: Test cases for enabled state (update descriptions as needed)

### Common Patterns

**Template Code (`.gts`/`.gjs`/`.hbs`):**

```handlebars
{{! BEFORE }}
{{#if (devFlag 'flagName')}}
  <EnabledContent />
{{else}}
  <DisabledContent />
{{/if}}

{{! AFTER }}
<EnabledContent />
```

**Component/Service Code (`.ts`/`.js`):**

```typescript
// BEFORE
import { devFlag } from 'soxhub-client/helpers/dev-flag';

if (devFlag('flagName')) {
	enabledBehavior();
} else {
	disabledBehavior();
}

// AFTER
enabledBehavior();
```

**Using developmentFlags.getFlag directly:**

```typescript
// BEFORE
import developmentFlags from '@auditboard/client-core/utils/development-flags';

if (developmentFlags.getFlag('flagName')) {
	enabledBehavior();
} else {
	disabledBehavior();
}

// AFTER
enabledBehavior();
```

**Test Code (withFlag):**

```typescript
// BEFORE
test('it works with flag enabled', function (assert) {
	withFlag('flagName', true);
	// test code
});

// AFTER (remove withFlag call, keep the test)
test('it works', function (assert) {
	// test code
});
```

**Test Code (withFlags array):**

```typescript
// BEFORE
withFlags([
	['flagName', true],
	['otherFlag', false],
]);

// AFTER (remove the flagName entry, keep others)
withFlags([['otherFlag', false]]);

// Or if the array becomes empty, remove the entire withFlags call
```

**Test for disabled state (remove entirely):**

```typescript
// BEFORE - remove this entire test
test('it works with flag disabled', function (assert) {
	withFlag('flagName', false);
	// test code
});
```

## Tips for Claude/Cursor

When working with this epic:

1. **Always use the skill first**: Don't manually search/replace - use `@remove-dev-flag` for consistency
2. **Verify the flag exists**: Search for the flag name in the codebase before starting work
3. **Read the skill output**: The skill reports what it changed - review carefully
4. **Clean up imports**: After removal, check that unused imports of `devFlag`, `developmentFlags`, `withFlag`, and `withFlags` are also removed

## References

- **Skill documentation**: `.claude/skills/remove-dev-flag/SKILL.md`
- **Epic in Jira**: SOX-79949
- **Flag tracker**: [Coda - SoxHub Flags](https://coda.io/d/Audit-Team-Hub_dXXykCrvx2t/LaunchDarkly-Feature-Flags_suEkhWP1#_tuInrDNW)
