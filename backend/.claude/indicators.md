---
name: indicators
description: Criteria for whether a Jira ticket requires backend changes. Lists indicators that backend work IS needed (API, DB, services, serializers, etc.) and is NOT needed (pure UI, frontend routing, Storybook, etc.). Referenced by the shared determine-repos skill and by start-jira-work when running standalone.
---

# Backend Work Indicators

Use this file to determine whether a Jira ticket requires changes in the **backend** repository. Referenced by the shared `check-jira` skill and by `start-jira-work` when running standalone.

## Indicators that backend work IS needed

- API endpoint changes, new routes, or controller logic
- Database migrations, model or schema changes
- Backend services, workers, jobs, or business logic
- Server-side configuration or environment variable changes
- Backend tests (RSpec, unit tests for services/models)
- Changes to serializers, policies, or permissions
- Background job or queue changes

## Indicators that backend work is NOT needed

- Pure UI/component changes, styling, or layout
- Frontend-only routing, state management, hooks, or context
- Client-side analytics or tracking changes
- Storybook stories or frontend-only test updates
- Frontend copy or localization changes
