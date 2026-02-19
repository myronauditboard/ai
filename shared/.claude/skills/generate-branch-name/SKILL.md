---
name: generate-branch-name
description: Generates a standardized Git branch name from a Jira ticket ID. Single source of truth for branch naming. Format {TICKET-ID}-{sanitized-title}; entire branch name max 30 characters. Ticket ID unchanged; title lowercased, non-alphanumeric → hyphen, then truncate full string to 30 chars.
---

# Generate Branch Name

**Purpose**: Single source of truth for Git branch naming across all repositories (backend, frontend, etc.). Ensures consistent branch names when working on the same Jira ticket across multiple repos.

**Usage**: 
- Called by `check-jira.sh` script to generate branch names for automated workflows
- Called by `start-jira-work` skill when `BRANCH_NAME` environment variable is not set
- Can be called manually when you need to generate a branch name for a Jira ticket

This skill is the authoritative implementation of branch naming logic. All other tools reference this skill rather than implementing their own logic.

## Input

- **Jira Ticket ID**: e.g., "SOX-XXXXX"

## Output

Returns a standardized branch name in the format:

```
{TICKET-ID}-{sanitized-title}
```

Example: `SOX-81757-launchdarkly-flag-de` (30 characters total)

## Process

Follow this order exactly. Do not respond with a question or request for the ticket summary; always fetch the summary via the Jira/Unblocked lookup below and then apply the algorithm.

### Step 1: Look Up Jira Ticket

Use Unblocked to get the ticket summary. Query: "Jira issue {TICKET-ID}" (or "Show me Jira issue {TICKET-ID}"). Extract the **Summary/Title** from the response.

```
Call: user-unblocked-data_retrieval
Parameters: { query: "Show me Jira issue {TICKET-ID}" }
```

### Step 2: Generate Branch Name

Apply these steps in order:

- **A.** You have the ticket **summary/title** from Step 1.
- **B.** **Ticket ID is unchanged**: use it exactly as given (e.g. `SOX-81757`). Add a single dash after it.
- **C.** **Sanitize the full Jira title**: (1) lowercase everything, (2) replace any character that is not alphanumeric (`a-z`, `0-9`) with a hyphen, (3) collapse consecutive hyphens into one, (4) strip leading and trailing hyphens. This gives the suffix.
- **D.** Form the branch name as `{TICKET-ID}-{suffix}`. If the suffix is empty, use **only** `{TICKET-ID}` (no trailing hyphen).
- **E.** **Truncate the entire branch name** to **at most 30 characters**. The total length of the final branch name (including ticket ID and dash) must be ≤ 30. Truncation may cut the suffix mid-word; that's acceptable.

So: ID stays, one dash, then sanitized title suffix, then truncate the whole thing to 30 chars. Do not truncate the raw title first.

**Bash implementation** (reference): sanitize full title, then form full branch name, then truncate entire string to 30 chars.

```bash
BRANCH_SUFFIX=$(echo "$TICKET_SUMMARY" | 
  tr '[:upper:]' '[:lower:]' | 
  sed 's/[^a-z0-9]/-/g' | 
  sed 's/-\+/-/g' | 
  sed 's/^-//' | 
  sed 's/-$//')
BRANCH_NAME="${TICKET_KEY}-${BRANCH_SUFFIX}"
BRANCH_NAME="${BRANCH_NAME:0:30}"
```

### Step 3: Return Branch Name

**When called from a script or automation**: Emit **exactly one line**: the branch name. No preamble, no explanation, no "Here is the branch name:", no markdown, no quotes. No other lines before or after—the last line must be the branch name.

**When called interactively**: You may provide additional context, but ensure the branch name appears clearly.

Example output: `SOX-81757-launchdarkly-flag-de`

## Examples

### Example 1: SOX-81757 (LaunchDarkly flag)

**Ticket**: [SOX-81757](https://auditboard.atlassian.net/browse/SOX-81757)

**Title**: "LaunchDarkly Flag: Deprecate annotate-results-without-annotations"

**Steps**: Lowercase → non-alphanumeric becomes dash → "launchdarkly-flag-deprecate-annotate-results-without-annotations"; prefix "SOX-81757-"; full name exceeds 30 chars, so truncate to 30 total.

**Branch name**: `SOX-81757-launchdarkly-flag-de` (30 characters)

### Example 2: Basic Ticket

**Input**: `SOX-XXXXX`

**Ticket Summary**: "Update compliance report generation for Q1"

**Generated Branch Name**: `SOX-XXXXX-update-compliance-re` (30 chars total; suffix truncated)

### Example 3: Ticket with Special Characters

**Input**: `SOX-XXXXX`

**Ticket Summary**: "Add new compliance checks [URGENT] (Phase 2)"

**Generated Branch Name**: `SOX-XXXXX-add-new-compliance` (30 chars total; special characters become hyphens, then truncated)

### Example 4: Short Ticket

**Input**: `SOX-999`

**Ticket Summary**: "Fix bug"

**Generated Branch Name**: `SOX-999-fix-bug` (entire branch under 30 chars)

## Integration with Other Skills

Other skills (like `start-jira-work`) should call this skill to get the branch name:

```markdown
Before creating a branch, call the generate-branch-name skill to get the standardized name:

"Use the generate-branch-name skill to get the branch name for ticket {TICKET-ID}"

Then use the returned branch name when creating the branch.
```

## Key Rules

1. **Always use this skill** for branch naming to ensure consistency
2. **Entire branch name at most 30 characters** (including ticket ID and dash)
3. **Lowercase only** for the title/suffix part
4. **Hyphens as separators** (no spaces or special characters; non-alphanumeric → hyphen)
5. **Format**: `{TICKET-ID}-{sanitized-title}` then truncate to 30 chars

## Edge Cases

- **No summary / empty summary:** Branch name = `{TICKET-ID}` only.
- **Summary is only special characters after sanitization:** Branch name = `{TICKET-ID}` only.
- **Ticket lookup fails:** Do not invent a name; return an error or signal failure. Do not output a meta-sentence (e.g. "I need the ticket summary") as the last line.

## Troubleshooting

**Cannot find ticket**: Verify ticket ID format and ensure you have access to the Jira integration via Unblocked.

**Ticket has no summary**: Use just the ticket ID as the branch name: `{TICKET-ID}`
