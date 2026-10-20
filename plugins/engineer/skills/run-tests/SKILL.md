---
name: run-tests
description: >-
  Run the whole test suite of an Agentic SDD repo — lint, unit tests, automated
  feature tests, and the manual feature tests of the current version — using the
  commands in docs/04-conventions/testing.md, map results to FT IDs, and write
  docs/plans/vX/test-report.md. Called by engineer:build and engineer:ship; also
  usable directly when the user asks to run or check all tests for a version.
argument-hint: "[vX.Y.Z.T, optional] [--no-report]"
---

# engineer:run-tests

Read `${CLAUDE_PLUGIN_ROOT}/references/sdd-conventions.md` ("Tests") first.
The goal is a trustworthy green/red answer plus evidence.

## Step 1 — Commands

Resolve the docs layout ("Docs layout" in the conventions): `testing`, `plans`
and `feature_tests` may live elsewhere in this repo. Read the `commands:`
frontmatter of the `testing` document (default `docs/04-conventions/testing.md`)
(`preflight`, `setup`, `lint`, `unit`, `feature`). Never invent a command
when the file defines one. If one is missing but needed, detect it (manifests, Makefile, CI
config), confirm it with the user, write it back to `testing.md`, and record a
retro entry if the template should have caught it.

## Step 2 — Run

In the current working tree (the build branch, or the port worktree when called
by `ship`):

1. **Preflight.** Run `preflight` (e.g. `docker info >/dev/null` for
   Testcontainers, a database ping). If it fails, stop: report an
   **environment problem** with its output — never run the suites against a
   broken environment, because many frameworks then *skip* tests and still
   report success.
2. `setup` if dependencies are missing or the lockfile changed.
3. `lint`, `unit`, `feature`, in that order. Do not stop at the first red
   suite — collect all results. Capture the summary lines, not full logs.
4. **Counts per suite: passed, failed, skipped.** Prefer machine-readable
   results when the stack writes them (JUnit XML in `build/test-results/`,
   `target/surefire-reports/`, `--json` / `--junitxml` outputs); otherwise
   parse the runner's summary. List every skipped test by name.
5. **Skips are not green by default.** Compare with the reference run — the
   previous report of this version (`git show HEAD:<plans>/vX/test-report.md`),
   or for the port worktree the build branch's report. A skip that the
   reference did not have is **needs attention**: look for the cause (a
   service down, a disabled-without-X annotation, a missing env var), fix it
   and rerun, or ask the user to accept it with a reason. Skips already
   present in the reference and accepted there may stay.
6. Map automated feature-test results to FT IDs by searching the output for
   `FT-v` IDs. List every FT file with `status: active` and
   `automation: automated`; an FT with no matching result is **not run**, which
   counts as red. An FT whose scenarios are tagged `@G-NN` for goals not yet
   Done is `partial (k/n)` — fine during the build, red at ship time.
7. Manual FTs of **this version** (`since:` or `updated_in:` contains vX):
   execute the "Manual execution notes" yourself when you can (API calls, CLI,
   browser tool if available) and record the evidence. If you cannot (needs a
   device, a human judgment, a third-party sandbox), mark it **needs UAT**.
   Manual FTs of older versions are listed as "not run (regression, manual)".

## Step 3 — Report

Unless `--no-report` (used for the port worktree), write
`docs/plans/vX/test-report.md`, replacing the previous content:

```markdown
---
version: vX.Y.Z.T
commit: <git rev-parse HEAD>
run_at: <ISO timestamp>
result: green | red
totals:                     # per suite; the next run compares against these
  unit: { passed: 142, failed: 0, skipped: 0 }
  feature: { passed: 12, failed: 0, skipped: 0 }
---

# Test report — vX.Y.Z.T

| Suite | Command | Passed | Failed | Skipped |
|-------|---------|--------|--------|---------|
| unit | `…` | 142 | 0 | 0 |

## Skipped
| Test | Reason | New vs reference | Accepted by |
|------|--------|------------------|-------------|

## Feature tests
| FT ID | Automation | Result | Evidence |
|-------|------------|--------|----------|

## Needs UAT
- FT-… — why it could not be executed here

## Failures
- <test> — <first relevant error line> — likely goal G-NN
```

`result: green` only if preflight passed, every suite passed with no
unaccepted new skip, every active automated FT passed (no `partial` once all
goals are Done), and every manual FT of this version passed or is marked
needs UAT. Always commit
the report (`docs(vX.Y.Z.T): test report`) so the tree stays clean for `ship`;
with `--no-report` nothing is written or committed.

Return to the caller: green/red, the counts (passed/failed/skipped per suite),
new skips, failures, partial FTs, the needs-UAT list. With `--no-report`
(port worktree), also return the totals so `ship` can put them in PR #2.
