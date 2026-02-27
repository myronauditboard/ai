# Jira Twin

Lightweight mock of the Jira REST API for testing the [Jira monitor](../../shared/scripts/jira-monitor/) pipeline (`poll-jira.sh` / `check-jira.sh`) without hitting a real Jira instance.

## Endpoints

- **GET /rest/api/3/myself** — Returns a stub user. Validates Basic Auth.
- **GET /rest/api/3/search/jql** — Returns tickets from `fixtures.json`, filtered by simple JQL parsing (`key = "X"`, `status = "To Do"`, `assignee = currentUser()`).
- **GET /rest/api/3/issue/{key}** — Returns a single issue by key (e.g. for `?fields=summary`).
- **GET /rest/api/3/issue/{key}/transitions** — Returns available transitions from the issue’s current status (e.g. To Do → In Progress).
- **POST /rest/api/3/issue/{key}/transitions** — Applies a transition (body: `{"transition":{"id":"2"}}`). Updates the ticket’s `status` in `fixtures.json`.
- **PUT /rest/api/3/issue/{key}/assignee** — Sets the assignee (body: `{"accountId":"..."}`). Stores the current Basic Auth user’s email in `fixtures.json`.

Status and assignee changes are persisted to `fixtures.json`, so the next search reflects the new state (e.g. after moving a ticket to “In Progress”, it no longer appears in “To Do” JQL).

## Setup

```bash
cd ai/digital-twins/jira-twin
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

(Or use your system Python/pip if you prefer.)

## Running

```bash
.venv/bin/python server.py
```

Starts on **http://127.0.0.1:5111** (override with `PORT=8080 python server.py`).

## Testing the pipeline

In another terminal, from the **ai** repo root:

```bash
JIRA_URL=http://localhost:5111 JIRA_EMAIL=test@example.com JIRA_API_TOKEN=fake \
  ./shared/scripts/jira-monitor/poll-jira.sh --dry-run
```

Use the same `JIRA_EMAIL` as in your fixtures (e.g. `test@example.com`) so `assignee = currentUser()` matches. To process tickets end-to-end against the twin, run `poll-jira.sh` without `--dry-run` (and use a ticket key that exists in `fixtures.json` with status "To Do").

## Fixtures

Edit **fixtures.json** to add or change test tickets. Each entry needs:

- `key` — e.g. `SOX-99001`
- `status` — e.g. `To Do`, `In Progress`, `Done`. The mock supports transitions: **To Do** → In Progress (id `2`), **In Progress** → Done (id `21`), **Done** → To Do (id `3`). The start-jira-work skill uses the transitions API to move tickets to “In Progress”; those updates are written back to `fixtures.json`.
- `assignee` — email (must match `JIRA_EMAIL` when using `assignee = currentUser()`). Can be updated via PUT assignee.
- `summary` — ticket title
