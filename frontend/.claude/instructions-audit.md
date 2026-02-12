---
name: instructions-audit
description: Implementation workflow for the AuditBoard frontend. Covers coding standards, Ember/Glimmer patterns, Luna design system, WarpDrive data patterns, linting, testing, and the mandatory pre-completion audit. Referenced by start-jira-work after branch creation.
---

# AuditBoard Frontend - Implementation Workflow

**Usage**: This file is referenced by `.claude/skills/start-jira-work/SKILL.md` after branch creation to guide the complete implementation workflow.

## Implementation Process

When starting work on a ticket (after branch is created), follow these steps:

### 1. Create Plan File

Create a plan file at `.claude/plans/plan-{TICKET-ID}-frontend.md` (e.g., `.claude/plans/plan-SOX-XXXXX-frontend.md`). Create the `.claude/plans` folder if it does not exist.

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

Run linting and formatting on all changed files. Multiple linters are available:

```bash
pnpm lint:js        # ESLint for JS/TS files
pnpm lint:hbs       # Ember Template Lint for templates
pnpm lint:css       # Stylelint for CSS files
pnpm lint:prettier  # Prettier formatting check
pnpm lint:types     # TypeScript type checking
```

To auto-fix issues, append `:fix` to the command (e.g., `pnpm lint:js:fix`).

For formatting individual files:

```bash
pnpm exec prettier <path-to-file> --write
```

Fix any linter errors that are introduced.

### 5. Verify Changes

**Do NOT run tests locally** -- CI handles all test execution. The test suite takes too long to run locally.

Verify your changes by:

- Reviewing linter output (step 4)
- Checking TypeScript types pass (`pnpm lint:types`)
- Manually inspecting your changes for correctness

### 6. Update Plan

Update the plan file (`.claude/plans/plan-{TICKET-ID}-frontend.md`) to reflect what was actually implemented. This creates a record of what changed vs. what was originally planned.

Save the updated plan but do NOT commit it.

### 7. Run Pre-Completion Audit

Before returning to the start-jira-work skill, run the mandatory design system audit (see the Pre-Completion Audit section below).

### 8. Return to start-jira-work

Once all lint checks pass and the audit is complete, return to `.claude/skills/start-jira-work/SKILL.md` Step 4 to create the commit and PR.

---

## Documentation References

Coding guidelines and standards are maintained within the repository:

- **`.github/instructions/`** - All coding guidelines (Ember, TypeScript, general coding standards)
- **`.github/copilot-skills/`** - Workflow guides (PR review, component audits, modernization)
- **`apps/client-docs/`** - AuditBoard-specific patterns and documentation
- **`libraries/data/docs/`** - WarpDrive/Data layer patterns

External references:

- [Ember.js AI Docs](https://nullvoxpopuli.github.io/ember-ai-information-aggregator/llms-full.txt)
- [WarpDrive Docs](https://docs.warp-drive.io/llms-full.txt)
- [WAI-ARIA Authoring Practices](https://www.w3.org/WAI/standards-guidelines/)

## General Guidelines

- Write clear and concise commit messages
- Ensure code is well-documented and follows the project's coding standards
- Review changes for any potential performance or security issues
- No hallucinations - when in doubt, ask for clarification
- Do not include sensitive information in commit messages or code
- Prefer clarity over cleverness
- Always prefer instructions in `.github/instructions/` over patterns in existing code
- Avoid inferring patterns from files with top-of-file eslint-disable comments

## Architecture Standards

The repository follows a **pnpm monorepo structure** managed with Turborepo:

- **`apps/client/`** - Main AuditBoard Ember.js application
- **`apps/login/`** - Login application
- **`apps/support-dashboard/`** - Support/admin dashboard
- **`apps/documentation/`** - Documentation site
- **`libraries/`** - Shared packages (design system, utilities, feature modules)
- **`tests/`** - Test utilities and E2E suites (Playwright)
- **`tools/`** - Build and development tooling

**Library naming conventions:**

- `@auditboard/luna-*` - Design system and UI Kit
- `@auditboard/sol-*` - AuditBoard-data enriched design system components
- `@auditboard/*` - General shared libraries
- `@auditboard-tooling/*` - Build and tooling libraries
- `@auditboard/legacy-*` - **Deprecated code (never use)**

**Client app structure (`apps/client/app/`):**

- `components/` - Glimmer components (`.gts`/`.gjs`)
- `models/` - Ember Data / WarpDrive models
- `routes/` - Route definitions
- `services/` - Ember services (organized by domain)
- `helpers/` - Template helpers
- `modifiers/` - Element modifiers
- `utils/` - Utility functions
- `adapters/` / `serializers/` - Data layer adapters/serializers

## Ember.js / Glimmer Component Standards

**Mandatory patterns:**

- Always use `@glimmer/component` as base class (never `Ember.Component`)
- Use single-file components (`.gts` preferred, `.gjs` acceptable) for all new code
- Use angle bracket syntax: `<MyComponent />`
- Prefer arrow functions over `@action` decorator
- Use `@tracked` for reactive state (not `@computed`)
- Explicitly import all components, helpers, and modifiers in `.gts`/`.gjs` files
- Use `declare` keyword for decorated model attributes

**Component signature pattern:**

```typescript
interface Signature {
  Element: HTMLElement;
  Args: {
    name: string;
  };
  Blocks?: {
    [blockName: string]: Array<unknown>;
  };
}
```

**Service injection:**

```typescript
@service declare router: RouterService;
```

Avoid accessing nested service injections (e.g., `this.cService.bService.foo`). Inject the service you need directly.

**Forbidden patterns (never use these):**

- `Ember.Component`, `EmberObject`, mixins
- `@action` decorator (use arrow functions)
- `@computed` (use `@tracked`)
- Lifecycle hooks: `did-insert`, `will-destroy`, etc.
- Global-style helpers/modifiers without explicit imports
- Separate `.hbs` and `.js`/`.ts` files for components (use single-file `.gts`)
- `app.import`, `vendor/`
- Anything from `legacy-design-system` or paths containing "legacy" or "deprecated"

## TypeScript Configuration

The repository uses TypeScript with Glint for template type-checking:

- TypeScript 5.9.3
- Glint for type-safe templates in `.gts`/`.gjs` files
- Experimental decorators enabled
- ES modules

**Decorated attribute types:**

- `@attr('string')` -> `string | null`
- `@attr('string', { defaultValue: 'foo' })` -> `string`
- `@attr('boolean')` -> `boolean`
- `@attr('boolean', { allowNull: true })` -> `boolean | null`
- `@belongsTo('foo', { async: false })` -> `Foo | null`
- `@belongsTo('foo', { async: true })` -> `AsyncBelongsTo<Foo>`
- `@hasMany('foo', { async: false })` -> `HasMany<Foo>`
- `@hasMany('foo', { async: true })` -> `AsyncHasMany<Foo>`

Always use `declare` for decorated attributes:

```typescript
@attr('string') declare foo: string | null;
```

## Code Formatting Standards

The repository uses Prettier (`.prettierrc.cjs`), Stylelint, and EditorConfig (`.editorconfig`) for consistent code formatting:

- **Single quotes** for strings
- **Tabs** for indentation (except JSON/YAML which use spaces)
- **120 character** line width (90 for markdown docs)
- **Trailing commas** everywhere
- **Arrow parens** always included
- **Bracket spacing** enabled
- **Template single quotes**: `false` (for `.gts`/`.gjs` files)
- **Insert final newline** in all files
- **Trim trailing whitespace**

## Linting Rules

The repository uses multiple linters with a flat ESLint config (`eslint.config.cjs`):

**ESLint (JS/TS):**

- ESLint 9.x with flat config format
- TypeScript-aware linting rules
- Custom plugin: `@soxhub/eslint-plugin`
- Must build dependencies before linting (type-aware rules require built declarations)

**Ember Template Lint:**

- Ember Template Lint 7.x
- Custom config via `@auditboard-tooling/template-lint`
- Checks for accessibility and best practices

**Stylelint (CSS):**

- `stylelint-config-standard`
- Ember scoped CSS plugin for component styles

**Lint commands:**

```bash
pnpm lint          # Run all linters
pnpm lint:js       # ESLint
pnpm lint:hbs      # Template lint
pnpm lint:css      # Stylelint
pnpm lint:prettier # Prettier check
pnpm lint:types    # TypeScript type checking
```

Run on individual files where possible (not `pnpm lint` on the entire codebase).

## Luna Design System

All UI work must use the Luna design system from `libraries/luna-core`:

- **Use Luna components** instead of raw HTML elements (e.g., use Luna's button component instead of `<button>`)
- **Use design tokens** instead of hardcoded values: `var(--luna-color-text)`, `var(--luna-space-md)`, etc.
- **Never use** components from `legacy-design-system` or anything with "legacy" or "deprecated" in the path
- Check for existing utilities before writing new ones

**Available MCP tools for design system work:**

- `audit_pr` - Audit PR changes for component/token issues
- `audit_code` - Audit a single file for issues
- `get_component_docs` - Get Luna component documentation
- `get_utils_catalog` - Search for existing utilities
- `reverse_lookup_token` - Find the design token for a hardcoded value

## WarpDrive / Data Patterns

For data management, use the AuditBoard wrapper packages:

- Use `@auditboard/warp-drive` and `@auditboard/data` (do NOT import directly from `ember-data` or `warp-drive`)
- Prefer the `Request` component pattern from WarpDrive over `ember-concurrency`
- Use `getPromiseState` and `getRequestState` from `@auditboard/warp-drive/v2/ember`
- Documentation is in `libraries/data/docs/` and `libraries/warp-drive/`

## Testing Standards

- **Do NOT run tests locally** - CI handles all test execution (the test suite takes too long to run locally)
- Write unit and integration tests for new functionality using QUnit and `@ember/test-helpers`
- Use Mirage.js for API mocking in tests
- E2E tests use Playwright and live in `tests/client-e2E/`
- Test file naming: `*-test.ts` (unit/integration), `*.spec.ts` (E2E)
- Acceptance tests are in `apps/client/tests/acceptance/`
- Ensure existing tests are not broken by your changes (CI will verify)
- Use mocks and stubs where appropriate to isolate the code under test

## Pre-Completion Audit (MANDATORY)

**Every implementation MUST run the design system audit before marking work as complete.**

1. Follow the full audit workflow in `.github/copilot-skills/review-pr-changes.md` to check all changed files for:
   - **Component-usage issues** - raw HTML elements that should use Luna components
   - **Hardcoded-token issues** - hardcoded values that should use design tokens
   - **Utility duplication** - new code that duplicates existing utilities
2. Fix all **high-severity** issues before finishing.
3. If audit tools (MCP) are unavailable, add a note to the PR description: "Manual Luna audit needed -- MCP tools were not available."
