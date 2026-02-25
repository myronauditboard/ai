---
name: indicators
description: Criteria for whether a Jira ticket requires frontend changes. Lists indicators that frontend work IS needed (UI, routes, state, Storybook, analytics, etc.) and is NOT needed (pure API, DB, backend services, etc.). Referenced by the shared determine-repos skill and by start-jira-work when running standalone.
---

# Frontend Work Indicators

Use this file to determine whether a Jira ticket requires changes in the **frontend** repository. Referenced by the shared `check-jira` skill and by `start-jira-work` when running standalone.

## Indicators that frontend work IS needed

- UI changes, component updates, styling, or layout changes
- Frontend route or page changes
- Client-side logic, state management, hooks, or context changes
- Frontend tests, Storybook stories
- Changes to user-facing behavior, interactions, or copy
- Amplitude/analytics tracking added or modified on the frontend
- Frontend configuration or environment variable changes

## Indicators that frontend work is NOT needed

- Pure API/endpoint changes, database migrations, model changes
- Backend-only business logic, services, or workers
- Server-side configuration or infrastructure changes
- Backend-only test changes
