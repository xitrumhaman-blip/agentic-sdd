---
id: FT-__VERSION__-NN
title: "<behaviour, in one line>"
domain: <domain folder name>
covers: [REQ-01, G-01]       # IDs of the version that introduced or last changed it
since: __VERSION__
updated_in: []               # versions that later changed this test
automation: automated        # automated | manual
automated_by: ""             # test file / test name, filled by /engineer:build
status: active               # active | deprecated
---

# FT-__VERSION__-NN — <title>

## Context
Why this behaviour matters, and any preconditions shared by all scenarios.

## Scenarios

<!-- An FT covering a single goal needs no tags. If its scenarios become
testable at different goals, tag EVERY scenario with its goal, e.g. a line
"  @G-02" right above "  Scenario: …". -->

```gherkin
Feature: <capability>

  Background:
    Given <shared precondition>

  Scenario: <happy path>
    Given <state>
    When <action>
    Then <observable outcome>

  Scenario: <edge or error case>
    Given <state>
    When <action>
    Then <observable outcome>
```

## Test data
Accounts, fixtures or inputs the scenarios rely on. No real customer data.

## Manual execution notes
Only for `automation: manual`: exact steps, environment, and what evidence to
capture (response body, screenshot path, log line).
