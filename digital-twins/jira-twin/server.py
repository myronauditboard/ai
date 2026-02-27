#!/usr/bin/env python3
"""
Jira Twin: lightweight mock of Jira REST API for testing poll-jira / check-jira.
Serves search, myself, issue by key, transitions, and assignee updates using fixtures.json.
Status and assignee changes are persisted to fixtures.json.
"""

import base64
import json
import os
import re
from pathlib import Path

from flask import Flask, request, jsonify, Response

APP = Flask(__name__)
FIXTURES_PATH = Path(__file__).resolve().parent / "fixtures.json"
PORT = int(os.environ.get("PORT", 5111))

# Available transitions from each status (id and name match what start-jira-work expects).
TRANSITIONS_BY_STATUS = {
    "To Do": [{"id": "2", "name": "In Progress"}],
    "In Progress": [{"id": "21", "name": "Done"}],
    "Done": [{"id": "3", "name": "To Do"}],
}


def load_fixtures():
    with open(FIXTURES_PATH, encoding="utf-8") as f:
        return json.load(f)


def save_fixtures(tickets):
    with open(FIXTURES_PATH, "w", encoding="utf-8") as f:
        json.dump(tickets, f, indent=2)
        f.write("\n")


def require_basic_auth(f):
    def wrapped(*args, **kwargs):
        auth = request.headers.get("Authorization")
        if not auth or not auth.startswith("Basic "):
            return Response("Unauthorized", status=401, headers={"WWW-Authenticate": "Basic"})
        try:
            decoded = base64.b64decode(auth[6:]).decode("utf-8")
            email = decoded.split(":", 1)[0] if ":" in decoded else ""
        except Exception:
            return Response("Unauthorized", status=401, headers={"WWW-Authenticate": "Basic"})
        return f(current_user_email=email, *args, **kwargs)
    wrapped.__name__ = f.__name__
    return wrapped


def parse_jql(jql):
    """Extract key, status, and assignee=currentUser() from JQL. Returns dict of constraints."""
    constraints = {}
    key_match = re.search(r'key\s*=\s*["\']([^"\']+)["\']', jql, re.IGNORECASE)
    if key_match:
        constraints["key"] = key_match.group(1).strip()
    status_match = re.search(r'status\s*=\s*["\']([^"\']+)["\']', jql, re.IGNORECASE)
    if status_match:
        constraints["status"] = status_match.group(1).strip()
    if "currentUser()" in jql and "assignee" in jql.lower():
        constraints["assignee_current_user"] = True
    return constraints


@APP.route("/rest/api/3/myself", methods=["GET"])
@require_basic_auth
def myself(current_user_email):
    return jsonify({
        "accountId": "mock-account-id",
        "emailAddress": current_user_email,
        "displayName": "Test User",
    })


@APP.route("/rest/api/3/search/jql", methods=["GET"])
@require_basic_auth
def search_jql(current_user_email):
    jql = request.args.get("jql", "")
    max_results = request.args.get("maxResults", "50")
    try:
        max_results = int(max_results)
    except ValueError:
        max_results = 50

    tickets = load_fixtures()
    constraints = parse_jql(jql)

    filtered = []
    for t in tickets:
        if constraints.get("key") and t.get("key") != constraints["key"]:
            continue
        if constraints.get("status") and t.get("status") != constraints["status"]:
            continue
        if constraints.get("assignee_current_user"):
            if t.get("assignee") != current_user_email:
                continue
        filtered.append(t)

    issues = [
        {"key": t["key"], "fields": {"summary": t.get("summary", "")}}
        for t in filtered[:max_results]
    ]
    return jsonify({"issues": issues})


def _ticket_by_key(key):
    tickets = load_fixtures()
    for t in tickets:
        if t.get("key") == key:
            return t, tickets
    return None, tickets


@APP.route("/rest/api/3/issue/<key>", methods=["GET"])
@require_basic_auth
def get_issue(key, current_user_email):
    ticket, _ = _ticket_by_key(key)
    if not ticket:
        return jsonify({"errorMessages": ["Issue does not exist or you don't have permission to see it."]}), 404
    return jsonify({
        "key": ticket["key"],
        "fields": {"summary": ticket.get("summary", "")},
    })


@APP.route("/rest/api/3/issue/<key>/transitions", methods=["GET"])
@require_basic_auth
def get_transitions(key, current_user_email):
    ticket, _ = _ticket_by_key(key)
    if not ticket:
        return jsonify({"errorMessages": ["Issue not found."]}), 404
    current_status = ticket.get("status", "To Do")
    transitions = TRANSITIONS_BY_STATUS.get(current_status, [])
    return jsonify({"transitions": transitions})


@APP.route("/rest/api/3/issue/<key>/transitions", methods=["POST"])
@require_basic_auth
def post_transition(key, current_user_email):
    ticket, tickets = _ticket_by_key(key)
    if not ticket:
        return jsonify({"errorMessages": ["Issue not found."]}), 404
    data = request.get_json(force=True, silent=True) or {}
    trans = data.get("transition", {})
    trans_id = trans.get("id")
    trans_name = trans.get("name")
    current_status = ticket.get("status", "To Do")
    available = TRANSITIONS_BY_STATUS.get(current_status, [])
    new_status = None
    for t in available:
        if t["id"] == trans_id or (trans_name and t["name"] == trans_name):
            new_status = t["name"]
            break
    if not new_status:
        return jsonify({"errorMessages": [f"No transition '{trans_id or trans_name}' from status '{current_status}'."]}), 400
    for t in tickets:
        if t.get("key") == key:
            t["status"] = new_status
            break
    save_fixtures(tickets)
    return "", 204


@APP.route("/rest/api/3/issue/<key>/assignee", methods=["PUT"])
@require_basic_auth
def put_assignee(key, current_user_email):
    ticket, tickets = _ticket_by_key(key)
    if not ticket:
        return jsonify({"errorMessages": ["Issue not found."]}), 404
    for t in tickets:
        if t.get("key") == key:
            t["assignee"] = current_user_email
            break
    save_fixtures(tickets)
    return "", 204


def main():
    if not FIXTURES_PATH.exists():
        raise SystemExit(f"Fixtures file not found: {FIXTURES_PATH}")
    APP.run(host="127.0.0.1", port=PORT, debug=False, use_reloader=False)


if __name__ == "__main__":
    main()
