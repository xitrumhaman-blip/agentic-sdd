---
version: __VERSION__
bump: __BUMP__              # major | feature | improvement | fix
status: approved            # approved → planned → architected → building → in-review | abandoned
revision: 0                 # incremented by /engineer:requirement revise
title: "__TITLE__"
created_at: __DATE__
approved_at: __DATE__
approved_by: "__APPROVER__"
---

# __TITLE__ (__VERSION__)

## Background
Why this comes up now: the situation, who raised it, links to tickets or
conversations.

## Problem
The problem to solve, in terms of users and outcomes, not solutions.

## Goals
- What must be true when this version ships.

## Non-goals
- What this version deliberately does NOT do. Agents read this to avoid scope
  creep.

## Users & scenarios
Who is affected and the main scenarios, in plain language.

## Requirements

| ID | Requirement | Kind | Priority |
|----|-------------|------|----------|
| REQ-01 | … | feature | Must |

Kind: `breaking` / `feature` / `improvement` / `fix`. Priority: MoSCoW
(`Must` / `Should` / `Could`; `Won't` belongs in Non-goals).

## Acceptance criteria
One or more per requirement, in EARS form so they translate directly into
feature tests:

- **REQ-01**
  - WHEN <trigger> THE SYSTEM SHALL <response>.
  - IF <unwanted condition> THEN THE SYSTEM SHALL <response>.

## Constraints & assumptions
Business, legal, timing or technical constraints known at this stage, and the
assumptions the requirement relies on.

## Version bump rationale
Which requirement drives the bump and why it is `__BUMP__`.

## Open questions
None — every question was resolved before approval.

## Sign-off
Approved by __APPROVER__ on __DATE__.

## Revisions
None.
