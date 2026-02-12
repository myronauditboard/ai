---
name: generate-branch-name
description: Generates a standardized Git branch name from a Jira ticket ID. This is the single source of truth for branch naming across all repositories. Returns the branch name in the format {TICKET-ID}-{sanitized-title}.
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

Example: `SOX-XXXXX-add-compliance-checks`

## Process

### Step 1: Look Up Jira Ticket

Use Unblocked to get the ticket summary:

```
Call: user-unblocked-data_retrieval
Parameters: { query: "Show me Jira issue {TICKET-ID}" }
```

Extract the **Summary/Title** from the response.

### Step 2: Generate Branch Name

Apply the following standardization rules:

1. **Take first 30 characters** of the ticket summary
2. **Convert to lowercase**
3. **Replace spaces with hyphens**
4. **Remove special characters** except hyphens and alphanumeric characters
5. **Remove consecutive hyphens** (replace `--` with `-`)
6. **Remove trailing hyphens**

**Bash implementation** (reference):

```bash
BRANCH_SUFFIX=$(echo "$TICKET_SUMMARY" | 
  head -c 30 | 
  tr '[:upper:]' '[:lower:]' | 
  sed 's/[^a-z0-9 -]//g' | 
  sed 's/ \+/-/g' | 
  sed 's/-\+/-/g' | 
  sed 's/-$//')
BRANCH_NAME="${TICKET_KEY}-${BRANCH_SUFFIX}"
```

### Step 3: Return Branch Name

Output the final branch name clearly. 

**When called from a script or automation**: Return ONLY the branch name on the last line, with no additional text or formatting.

**When called interactively**: You may provide additional context, but ensure the branch name appears clearly.

Example output: `SOX-XXXXX-add-compliance-checks`

## Examples

### Example 1: Basic Ticket

**Input**: `SOX-XXXXX`

**Ticket Summary**: "Update compliance report generation for Q1"

**Generated Branch Name**: `SOX-XXXXX-update-compliance-report-ge`

(30 chars: "update compliance report ge")

### Example 2: Ticket with Special Characters

**Input**: `SOX-XXXXX`

**Ticket Summary**: "Add new compliance checks [URGENT] (Phase 2)"

**Generated Branch Name**: `SOX-XXXXX-add-new-compliance-checks-u`

(Special characters removed, first 30 chars taken)

### Example 3: Short Ticket

**Input**: `SOX-999`

**Ticket Summary**: "Fix bug"

**Generated Branch Name**: `SOX-999-fix-bug`

(Entire summary used since it's under 30 chars)

## Integration with Other Skills

Other skills (like `start-jira-work`) should call this skill to get the branch name:

```markdown
Before creating a branch, call the generate-branch-name skill to get the standardized name:

"Use the generate-branch-name skill to get the branch name for ticket {TICKET-ID}"

Then use the returned branch name when creating the branch.
```

## Key Rules

1. **Always use this skill** for branch naming to ensure consistency
2. **First 30 characters max** of the sanitized title
3. **Lowercase only** for branch names
4. **Hyphens as separators** (no spaces or special characters)
5. **Format**: `{TICKET-ID}-{sanitized-title}`

## Troubleshooting

**Cannot find ticket**: Verify ticket ID format and ensure you have access to the Jira integration via Unblocked.

**Ticket has no summary**: Use just the ticket ID as the branch name: `{TICKET-ID}`
