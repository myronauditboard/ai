---
name: generate-branch-name
description: Gets a standardized Git branch name for a Jira ticket by running generate-branch-name.sh. There is NO fallback — the script is the only valid source for branch names. Format {TICKET-ID}-{sanitized-title}, max 40 chars, no trailing hyphen.
---

# Generate Branch Name

**Purpose**: Return a standardized branch name for a Jira ticket so all repos use the same name. The **only valid source** is the script `shared/scripts/jira-monitor/generate-branch-name.sh`. There is no fallback logic.

**Usage**:
- **Monitor** (`check-jira.sh`): Uses the script directly; passes `BRANCH_NAME` to agents.
- **Agent** (e.g. manual "start work on SOX-123" when `BRANCH_NAME` is not set): Use this skill — get the ticket summary, then run the script with key and summary; use the script output as the branch name.

## Input

- **Jira Ticket ID**: e.g. `SOX-84649`

## Output

Exactly one line: the branch name (e.g. `SOX-84649-references-to-enabling-soxhub`). No preamble, no quotes. When called from automation, the last line of your response must be the branch name only.

## Process

### Step 1: Get the ticket summary

Use the **Jira issue Summary (title) field only**. Do not use description or other text.

- **If `JIRA_BASE_URL`, `JIRA_EMAIL`, `JIRA_API_TOKEN` are set:** Fetch via Jira REST API:
  ```bash
  curl -s -u "$JIRA_EMAIL:$JIRA_API_TOKEN" \
    "$JIRA_BASE_URL/rest/api/3/issue/{TICKET-ID}?fields=summary" | jq -r '.fields.summary // ""'
  ```
- **Otherwise:** Use Unblocked: "Show me Jira issue {TICKET-ID}" and extract **only** the issue Summary/Title. Do not use description or other sections.

### Step 2: Run the script (REQUIRED — no fallback)

Find and run `generate-branch-name.sh`. Try these paths in order:

1. `shared/scripts/jira-monitor/generate-branch-name.sh`
2. `ai/shared/scripts/jira-monitor/generate-branch-name.sh`
3. Resolve relative to the workspace root

```bash
/path/to/generate-branch-name.sh "{TICKET-ID}" "{SUMMARY}"
```

Use the script's output as the branch name. **Do not** modify or re-sanitize it.

**If the script cannot be found or is not executable, stop and report the error. Do NOT invent a branch name or implement your own naming logic.**

## Key Rules

1. **ALWAYS use the script** — Run `generate-branch-name.sh` with ticket key and summary. There is no fallback. If the script is unavailable, stop with an error.
2. **Summary from Jira** — Use Jira REST API when env vars are set; otherwise Unblocked. Use only the issue Summary/Title field.
3. **NEVER construct a branch name yourself** — No matter the circumstances, do not generate, guess, or build a branch name. Only the script output is valid.

## Edge Cases

- **Empty summary:** The script handles this (returns `{TICKET-ID}` only).
- **Lookup fails:** Do not invent a name; return an error. Do not output a meta-sentence as the branch name.
- **Script not found:** Stop and report the error. Do NOT implement a fallback.

## Troubleshooting

**Wrong branch name:** Ensure you use the Jira API for the summary when credentials are set; Unblocked may return description or an old title.

**Script not found:** Resolve the path from the workspace (e.g. `ai/shared/scripts/jira-monitor/` or `shared/scripts/jira-monitor/`). If truly unavailable, **stop with an error** — do not improvise.
