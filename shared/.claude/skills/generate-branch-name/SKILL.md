---
name: generate-branch-name
description: Gets a standardized Git branch name for a Jira ticket. Prefer running the script shared/scripts/jira-monitor/generate-branch-name.sh (single implementation); fallback to same logic if script unavailable. Format {TICKET-ID}-{sanitized-title}, max 40 chars, no trailing hyphen.
---

# Generate Branch Name

**Purpose**: Return a standardized branch name for a Jira ticket so all repos use the same name. The **single implementation** is the script `shared/scripts/jira-monitor/generate-branch-name.sh`. This skill tells the agent how to call it (or replicate it when unavailable).

**Usage**:
- **Monitor** (`check-jira.sh`): Uses the script only; no agent.
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

### Step 2: Run the script (preferred)

If the script is available (e.g. workspace root is or contains the ai repo, so `shared/scripts/jira-monitor/generate-branch-name.sh` or `ai/shared/scripts/jira-monitor/generate-branch-name.sh` exists and is executable):

```bash
/path/to/generate-branch-name.sh "{TICKET-ID}" "{SUMMARY}"
```

Use the script’s output as the branch name. **Do not** modify or re-sanitize it.

### Step 3: Fallback when the script is not available

If you cannot run the script (path not found or not executable), implement the same logic as the script. The authoritative behavior is in `shared/scripts/jira-monitor/generate-branch-name.sh`:

- Sanitize summary: lowercase, non-alphanumeric → hyphen, collapse hyphens, strip leading/trailing hyphens.
- If suffix is empty, branch name = `{TICKET-ID}` only.
- Else: `{TICKET-ID}-{suffix}`, truncate to 40 characters, then strip a trailing hyphen if present (so the name never ends with `-`).

Output that branch name.

## Key Rules

1. **Prefer the script** — Run `generate-branch-name.sh` with ticket key and summary whenever the script path is available.
2. **Summary from Jira** — Use Jira REST API when env vars are set; otherwise Unblocked. Use only the issue Summary/Title field.
3. **Max 40 chars, no trailing hyphen** — The script enforces this; if you implement the fallback, do the same.

## Edge Cases

- **Empty summary:** Branch name = `{TICKET-ID}` only.
- **Lookup fails:** Do not invent a name; return an error. Do not output a meta-sentence as the branch name.

## Troubleshooting

**Wrong branch name:** Ensure you use the Jira API for the summary when credentials are set; Unblocked may return description or an old title.

**Script not found:** Resolve the path from the workspace (e.g. `ai/shared/scripts/jira-monitor/` or `shared/scripts/jira-monitor/`). If truly unavailable, use the fallback logic above and match the script’s behavior.
