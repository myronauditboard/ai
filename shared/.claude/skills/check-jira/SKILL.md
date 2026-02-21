---
name: check-jira
description: Determines which repositories (backend, frontend, or both) need changes for a Jira ticket. Use when check-jira.sh or a user asks to decide which repos to work on for a ticket. Looks up the ticket, reads backend and frontend indicator files, and outputs backend-only, frontend-only, or both.
---

# Check Jira — Repo Relevance

**Purpose**: Single place to decide whether a Jira ticket requires backend work, frontend work, or both. Used by `check-jira.sh` so only the relevant repo agents are launched.

**Usage**:
- Called by `check-jira.sh` after generating the branch name, before launching backend/frontend agents
- Can be called manually when you need to know which repos need changes for a ticket

## Input

- **Jira Ticket ID**: e.g., "SOX-XXXXX"

## Output

One of:
- `backend-only` — only the backend repo needs changes
- `frontend-only` — only the frontend repo needs changes
- `both` — both repos need changes

**If uncertain, default to `both`.** It is safer to launch an agent that discovers no work than to skip a repo that needs changes.

## Process

### Step 1: Look Up Jira Ticket

Use Unblocked to get the ticket details:

```
Call: mcp_unblocked_data_retrieval (or user-unblocked-data_retrieval)
Parameters: { query: "Show me Jira issue {TICKET-ID}" }
```

Extract from the response: **title/summary**, **description**, and any **epic context**.

### Step 2: Read Indicator Files

Read the indicator files from the ai repository (workspace root when running from check-jira.sh):

- **Backend indicators**: `backend/.claude/indicators.md`
- **Frontend indicators**: `frontend/.claude/indicators.md`

These files list what constitutes work in each repo. Use them as the single source of truth.

### Step 3: Analyze and Decide

Analyze the ticket's title, description, and epic context against **both** indicator sets:

- If the ticket matches **only** backend indicators (and clearly not frontend) → `backend-only`
- If the ticket matches **only** frontend indicators (and clearly not backend) → `frontend-only`
- If the ticket matches **both**, or could touch both, or you are **unsure** → `both`

### Step 4: Emit the Decision

**When called from check-jira.sh (scripted mode):** Emit exactly one word on the **last line** of your response. No preamble, no explanation, no markdown on that line. Valid values only: `backend-only`, `frontend-only`, or `both`.

**When called interactively:** You may provide brief reasoning, but ensure the decision word appears clearly (e.g. as the final line or in a clear "Decision: both" line).

Example output for scripted mode:

```
both
```

## Key Rules

1. **Always read the indicator files** — do not rely on memory; the indicators are the source of truth.
2. **Default to `both`** when the ticket is ambiguous or could reasonably touch both repos.
3. **Scripted output**: last line must be exactly one of `backend-only`, `frontend-only`, `both`.
