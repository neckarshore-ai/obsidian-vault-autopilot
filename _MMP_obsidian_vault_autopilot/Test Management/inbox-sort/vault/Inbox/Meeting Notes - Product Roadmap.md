---
tags:
  - Meeting
  - Product
created: 2026-03-10T10:00
modified: 2026-03-10T11:30
---

# Meeting Notes — Product Roadmap Review

**Date:** 2026-03-10
**Attendees:** Sarah (PM), Marco (Engineering Lead), Lisa (Design), Tom (QA)

## Discussion Points

### Q2 Priorities

Sarah presented three options for Q2 focus. Team voted for Option B: double down on the self-service onboarding flow before adding new integrations.

Rationale: 40% of trial users drop off during setup. Fixing this has higher ROI than adding a Salesforce connector that only 15% of prospects asked for.

### Technical Debt

Marco raised the authentication module rewrite. It is currently blocking the SSO feature and adding 200ms latency to every request. Team agreed to allocate two sprints in April.

### Design System

Lisa proposed adopting a shared component library. Currently three different button styles across the app. Will draft a proposal with cost estimate by next Friday.

## Action Items

1. Sarah: update roadmap deck with Q2 decision, share by Wednesday
2. Marco: create auth-rewrite epic with task breakdown
3. Lisa: component library proposal by March 17
4. Tom: regression test plan for auth changes
