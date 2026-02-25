---
name: start-jira-work
description: Orchestrates the complete workflow for working on a Jira ticket from start to finish. Use when the user provides a Jira ticket ID or asks to start work on a ticket. This skill looks up the ticket details, creates a properly-named branch from develop, hands off to the implementation workflow (with epic-specific instructions if applicable), creates the first commit with the ticket ID, moves the ticket to "In Progress" and sets assignee to the current user, and creates a pull request when work is complete.
---

# Start Jira Work

**Usage**: When the user provides a Jira ticket ID or asks to start work on a ticket, use this skill to orchestrate the complete workflow from ticket lookup to PR creation.

## Overview

This skill orchestrates the complete workflow for a Jira ticket:

1. Look up ticket details via Unblocked
2. **Check if this ticket requires backend work** -- if not, notify and stop
3. Create appropriately-named branch from `develop`
4. Hand off to `.claude/instructions-audit.md` for implementation
5. Create first commit with correct format
6. Move ticket to "In Progress" and set assignee to the person running this workflow (the current user)
7. Create PR when work is complete
8. Append PR URL to the end of the plan file (`.claude/plans/plan-{TICKET-ID}-backend.md`)
9. Open PR URL in browser
10. Send Slack notification when PR is ready (if configured)

**Slack notifications (optional)**
To receive Slack messages, set `SLACK_WEBHOOK_URL` (e.g. in `.env` or your shell) to a [Slack Incoming Webhook](https://api.slack.com/messaging/webhooks) URL. The agent will:

- Post an **info** message when the ticket does not require backend work (and stop the workflow)
- Post a **warning** when the branch already exists (and stop the workflow)
- Post **PR ready** with the PR URL when the pull request is created

Posting is done via: `curl -X POST -H 'Content-type: application/json' --data '{"text":"<message>"}' "$SLACK_WEBHOOK_URL"` (skip if `SLACK_WEBHOOK_URL` is unset).

## Step 1: Look Up Jira Ticket

When given a Jira ticket ID (e.g., "SOX-XXXXX"):

**If `TICKET_TITLE` and `TICKET_DESCRIPTION` are set** (e.g. when launched from check-jira.sh with `REPO_NEEDED=true`), use those values and skip the Unblocked lookup. You may still need to fetch **Status**, **Assignee**, and **Epic** via Unblocked if the workflow requires them later.

**Otherwise**, use the Unblocked data retrieval tool:

```
Call: user-unblocked-data_retrieval
Parameters: { query: "Show me Jira issue SOX-XXXXX" }
```

Extract from response:

- **Title/Summary**: Ticket's summary line
- **Description**: Full description
- **Status**: Current status
- **Assignee**: Who it's assigned to
- **Epic**: The epic ID this ticket belongs to (if any)

**Check for Epic-Specific Instructions:**

If the ticket belongs to an epic, check if `.claude/instructions-epic-{EPIC-ID}.md` exists (e.g., `.claude/instructions-epic-SOX-79949.md`).

If it exists, you must consult BOTH:

1. `.claude/instructions-audit.md` (main workflow)
2. `.claude/instructions-epic-{EPIC-ID}.md` (epic-specific additions/overrides)

Epic-specific instructions may:

- Add additional steps or skills to use
- Override parts of the main workflow
- Provide context specific to that epic

## Step 1.5: Check if Backend Work is Needed

**If `REPO_NEEDED` is set to `true`** (e.g. when launched from check-jira.sh after the shared check-jira skill already determined this repo needs work), skip this step and proceed to Step 2.

**If `REPO_NEEDED` is not set** (manual or standalone run), determine whether this ticket requires backend changes:

1. Read the indicator file: **`.claude/indicators.md`** in this repository. It lists what constitutes backend work vs. not.
2. Analyze the ticket **title**, **description**, and any **epic context** against those indicators.

**If the ticket clearly does NOT require backend work:**

1. If a branch was already created in this repo, delete it:
   ```bash
   git checkout develop
   git branch -D {BRANCH_NAME}
   ```
2. Send a Slack notification (if `SLACK_WEBHOOK_URL` is set):
   ```bash
   curl -X POST -H 'Content-type: application/json' --data '{"text":"ℹ️ SOX-XXXXX: No backend work needed — skipping backend repo."}' "$SLACK_WEBHOOK_URL"
   ```
3. Inform the user in chat: "This ticket does not appear to require backend changes. Skipping this repo. Work will continue in the frontend repo only."
4. **Stop the workflow.** Do not proceed to Step 2 or beyond.

**If the ticket DOES require backend work** (or if you are unsure), proceed to Step 2.

## Step 2: Create Branch

**Branch Name**:

**Option 1** (Preferred when launched from check-jira.sh): If the environment variable `BRANCH_NAME` is set, use it directly. This ensures consistent naming across backend and frontend repos.

**Option 2** (Manual runs): If `BRANCH_NAME` is not set, call the `generate-branch-name` skill to get the standardized branch name.

Search for and use the skill named **"generate-branch-name"** which should be available in the workspace or a related shared repository (typically in an `ai/general` directory structure). This skill is the single source of truth for branch naming logic.

The skill will:
- Look up the ticket details from Jira
- Apply the standardized naming convention
- Return a branch name in the format: `{TICKET-ID}-{sanitized-title}`

Example output: `SOX-XXXXX-add-compliance-checks-for-au`

Example: `SOX-XXXXX-add-new-compliance-checks`

**Check if branch already exists (required before creating branch):**

Run:

```bash
git fetch origin 2>/dev/null; git branch -a
```

If the branch name appears in the output (e.g. `SOX-XXXXX-add-new-compliance-checks` or `remotes/origin/SOX-XXXXX-add-new-compliance-checks`):

1. **Stop the workflow.** Do not create the branch or continue to Step 3.
2. **Alert the user** clearly in chat: e.g. "Branch `SOX-XXXXX-add-new-compliance-checks` already exists (locally or on origin). Workflow stopped. Check out the branch to continue existing work, or delete/rename it if you intended to start fresh."
3. **Send a Slack warning** if `SLACK_WEBHOOK_URL` is set:

```bash
curl -X POST -H 'Content-type: application/json' --data '{"text":"⚠️ start-jira-work: Branch already exists for SOX-XXXXX – workflow stopped. Branch: SOX-XXXXX-add-new-compliance-checks"}' "$SLACK_WEBHOOK_URL"
```

Then stop; do not run the branch-creation commands below.

**If the branch does not exist**, proceed with:

Commands:

```bash
git checkout develop
git pull origin develop
# Use $BRANCH_NAME if set (from check-jira.sh), otherwise use the name from generate-branch-name skill
git checkout -b "${BRANCH_NAME:-SOX-XXXXX-add-new-compliance-checks}"
```

Replace `SOX-XXXXX-add-new-compliance-checks` with the actual branch name obtained from Step 2.

**When launched from check-jira.sh (`REPO_NEEDED` set):** Right after creating the branch, perform **Step 5 (Move Ticket to In Progress)** now—transition the ticket and set assignee via Jira REST API. Doing this early ensures the ticket status is updated even if the run is interrupted later. Then continue to Step 3.

## Step 3: Hand Off to Implementation Workflow

**Consult the appropriate instructions files:**

**Primary**: `.claude/instructions-audit.md` - Complete implementation workflow

**If ticket has an epic**: Also consult `.claude/instructions-epic-{EPIC-ID}.md` for epic-specific guidance

The main instructions file will guide you through:

1. Creating a plan file for the implementation (in `.claude/plans/plan-{TICKET-ID}-backend.md`; create the `.claude/plans` folder if it does not exist)
2. Implementing the changes following coding standards
3. Creating tests following testing standards
4. Linting and prettifying code
5. Running tests to ensure everything passes
6. Updating the plan to reflect what was actually done

**Epic-specific instructions may add additional steps, such as:**

- Using specific skills (e.g., `remove-dev-flag` for SOX-79949)
- Following epic-specific patterns or conventions
- Additional verification or documentation steps

**Important**: The plan file should be saved but NOT committed. It's for tracking work during development only.

Once the workflow is complete and all tests pass, return here to Step 4.

## Step 4: Create First Commit (mandatory)

**Do not skip this step.** When there are implementation changes, you must commit them before creating the PR. Run `git status`; if there are changes to commit, run `git add .` and `git commit` with the format below. If there are no changes, report that and continue to Step 6 (push/PR if branch was already committed).

All commits must include a subject line followed by a bullet list of what was done in that commit.

**First commit format**:

```
{TICKET-ID}: {Full Jira ticket title}

- Bullet point describing one change
- Another change
- Optional third bullet
```

Example:

```
SOX-XXXXX: Add new compliance checks for quarterly audit

- Add validation for quarterly scope in compliance service
- Extend API response to include check results
- Add unit tests for new validation logic
```

**Subsequent commits** (same branch): Use the same bullet format but do NOT include the ticket ID in the subject line.

Commands (use multiple `-m` arguments for subject + body lines, or a commit message file):

First commit:

```bash
git add .
git commit -m "SOX-XXXXX: Add new compliance checks for quarterly audit" -m "- Add validation for quarterly scope in compliance service" -m "- Extend API response to include check results" -m "- Add unit tests for new validation logic"
```

Subsequent commit (no ticket ID in subject):

```bash
git add .
git commit -m "Fix lint errors in compliance validation" -m "- Apply prettier to compliance service" -m "- Correct type for scope parameter"
```

**Important**:

- Every commit must have a bullet list of what was done
- First commit: subject starts with `{TICKET-ID}: `
- Subsequent commits: subject has no ticket ID

## Step 5: Move Ticket to "In Progress" and Set Assignee

**If you already performed this step right after Step 2** (when `REPO_NEEDED` was set), skip and go to Step 6.

Otherwise: after starting work, update the Jira ticket to move it to "In Progress" and assign it to the current user.

**When to use which method:**

- **When `REPO_NEEDED` is set** (launched from check-jira.sh / launchd) or when **`JIRA_BASE_URL`, `JIRA_EMAIL`, and `JIRA_API_TOKEN` are set**: You **must** use the Jira REST API (Method 2). Unblocked is not available in headless/CLI mode and will not work. Do not attempt Unblocked in this context.
- **When running interactively** and Jira env vars are not set: Prefer Unblocked (Method 1); fall back to Method 2 if Unblocked is unavailable.

**Method 1 — Unblocked (interactive only):**

Use Unblocked tools to:

1. Set status to "In Progress"
2. Set the **assignee** to the person who is actually running this workflow (the current user)

**Method 2 — Jira REST API (use when headless or when JIRA_* env vars are set):**

Use the Jira REST API. The environment variables `JIRA_BASE_URL`, `JIRA_EMAIL`, and `JIRA_API_TOKEN` must be set (they are set by check-jira.sh).

```bash
# 1. Get available transitions
TRANSITIONS=$(curl -s -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  "$JIRA_BASE_URL/rest/api/3/issue/{TICKET-ID}/transitions")

# 2. Find the "In Progress" transition ID
TRANSITION_ID=$(echo "$TRANSITIONS" | jq -r '.transitions[] | select(.name == "In Progress") | .id' | head -1)

# 3. Perform the transition
curl -s -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  -X POST "$JIRA_BASE_URL/rest/api/3/issue/{TICKET-ID}/transitions" \
  -H "Content-Type: application/json" \
  -d "{\"transition\":{\"id\":\"$TRANSITION_ID\"}}"

# 4. Assign to current user
curl -s -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
  -X PUT "$JIRA_BASE_URL/rest/api/3/issue/{TICKET-ID}/assignee" \
  -H "Content-Type: application/json" \
  -d "{\"accountId\":\"$(curl -s -u "$JIRA_EMAIL:$JIRA_API_TOKEN" "$JIRA_BASE_URL/rest/api/3/myself" | jq -r '.accountId')\"}"
```

Replace `{TICKET-ID}` with the actual ticket key (e.g., `SOX-XXXXX`). If the environment variables are not set, skip this step and inform the user that the ticket needs to be manually transitioned.

## Step 6: Create Pull Request (mandatory)

**Do not skip this step.** When implementation is complete and changes are committed, you must push the branch and create the PR. Do not end the workflow without pushing and running `gh pr create` (or reporting the PR URL if the PR already exists). If `gh pr create` fails, report the error and retry once (e.g. network or rate limit); if it still fails, report and stop.

When implementation is complete (after completing `.claude/instructions-audit.md` workflow):

```bash
git push -u origin HEAD
gh pr create --title "SOX-XXXXX: Add new compliance checks" --body "$(cat <<'EOF'
## Summary
- Brief description of changes

## Jira Ticket
SOX-XXXXX

## Test Plan
- How to test these changes

EOF
)"
```

**PR format**:

- Title: `{TICKET-ID}: {Title}`
- Body must include: Summary (bullets), Jira ticket ID, Test Plan

**After creating the PR**: Append the PR URL to the plan file so the plan records the link. The `gh pr create` output includes the PR URL. Add a section at the end of `.claude/plans/plan-{TICKET-ID}-backend.md`:

```markdown
## Pull Request

https://github.com/owner/repo/pull/123
```

(Use the actual URL from the `gh pr create` output, or run `gh pr view --json url -q .url` to get it.)

**Send Slack notification when PR is ready:** If `SLACK_WEBHOOK_URL` is set, post the PR URL to Slack so the user is notified:

```bash
PR_URL=$(gh pr view --json url -q .url)
curl -X POST -H 'Content-type: application/json' --data "{\"text\":\"✅ PR ready: $PR_URL\"}" "$SLACK_WEBHOOK_URL"
```

Always report the PR URL to the user in chat as well.

## Step 7: Open PR URL in Browser

After creating the PR and appending the URL to the plan file, open the PR URL in the browser:

```bash
open "$(gh pr view --json url -q .url)"
```

On Linux systems, use `xdg-open` instead of `open`.

## Complete Example

**Input**: "SOX-XXXXX"

**Step 1 - Look up**:

```
user-unblocked-data_retrieval query: "Show me Jira issue SOX-XXXXX"
```

Response shows:

- Title: "Add control assessment role tracking to owner dashboard"
- Status: "To Do"
- Assignee: "John Doe"
- Epic: "SOX-79949" (check for `.claude/instructions-epic-SOX-79949.md`)

**Step 1.5 - Check relevance**: The ticket title mentions "owner dashboard" UI tracking. Analyzing the description: this involves adding an Amplitude tracking property derived from compliance assessment item assignments. The role derivation may require a backend change if the data isn't already exposed via the API. If the API already returns the needed data, this is frontend-only -- skip backend and notify. Otherwise, proceed.

**Step 2 - Create branch**: Check `git branch -a` for `SOX-XXXXX-add-control-assessment-role`. If it exists, stop, alert the user, and optionally post to Slack; do not create the branch. If it does not exist:

```bash
git checkout develop
git pull origin develop
git checkout -b SOX-XXXXX-add-control-assessment-role
```

**Step 3 - Implement** (follow `.claude/instructions-audit.md` workflow)

**Step 4 - First commit**:

```bash
git add .
git commit -m "SOX-XXXXX: Add control assessment role tracking to owner dashboard" -m "- Add controlAssessmentRole to Amplitude tracking for owner dashboard task clicks" -m "- Derive user role from compliance assessment item assignments"
```

**Step 5 - Move ticket** to "In Progress" and set assignee to the current user via Unblocked or Jira

**Step 6 - Create PR**:

```bash
git push -u origin HEAD
gh pr create --title "SOX-XXXXX: Add control assessment role tracking to owner dashboard" --body "$(cat <<'EOF'
## Summary
- Add controlAssessmentRole to Amplitude tracking for owner dashboard task clicks
- Derive user role from compliance assessment item assignments

## Jira Ticket
SOX-XXXXX

## Test Plan
- Run unit tests: `pnpm test`
- Verify Amplitude events include controlAssessmentRole property

EOF
)"
```

Then append the PR URL to the end of `.claude/plans/plan-SOX-XXXXX-backend.md` (from `gh pr create` output or `gh pr view --json url -q .url`). If `SLACK_WEBHOOK_URL` is set, post "✅ PR ready: {url}" to Slack.

**Step 7 - Open PR in browser**:

```bash
open "$(gh pr view --json url -q .url)"
```

## Key Rules

1. **Jira updates when headless**: When `REPO_NEEDED` is set or `JIRA_BASE_URL`/`JIRA_EMAIL`/`JIRA_API_TOKEN` are set, always use the Jira REST API (Method 2) for Step 5; do not use Unblocked.
2. **Base branch**: Always `develop`, never `main`
3. **All commits**: Subject line + bullet list of what was done in that commit
4. **First commit**: Subject starts with full ticket ID and title
5. **Subsequent commits**: Do NOT include ticket ID in subject
6. **No agent attribution**: Never add Co-authored-by tags
7. **Branch naming**: Ticket ID + first 30 chars of title
8. **PR body**: Must have Summary, Jira link, Test Plan
9. **Ticket status and assignee**: Move to "In Progress" when starting; set assignee to the person running the workflow (current user); do not skip; use REST API when headless.
10. **Commit and PR**: Do not end the workflow without committing changes and creating the PR when there are code changes.

## Troubleshooting

**Cannot find ticket**: Verify ticket ID format and access permissions.

**Branch already exists**: The workflow now checks for this before creating the branch. If the branch exists (locally or on origin), the agent stops, alerts you in chat, and optionally posts a warning to Slack. Check out the existing branch to continue work, or delete/rename it to start fresh.

**PR creation fails**: Ensure branch is pushed first with `git push -u origin HEAD`. If the agent skipped the commit or PR step, re-run the workflow or manually commit, push, and run `gh pr create`; the skill requires committing and creating the PR and should not be skipped.
