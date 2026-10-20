# Changelog

All notable changes to the `engineer` plugin. Format:
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions: SemVer.

## [0.7.0]

### Added
- `/engineer:ship --skip-test ["<reason>"]`: open or update the PRs without
  running or requiring tests (test report and code review freshness become
  warnings, the port is not tested). User-invoked only — never chosen by an
  agent or implied by `--approved`. Both PRs start with a **Tests skipped**
  warning (reason, who, date, last report state) and `/engineer:release`
  repeats it in its confirmations.

### Changed
- `architect` Step 2b asks the design questions behind nine build-time
  decisions of one version: read paths of back-office screens, option lists,
  required variants per entity, records that must exist in fresh
  environments, user-chosen identifiers vs reserved names, producer/consumer
  format agreement, guards re-checked for new category members, and a new
  principle for changes to existing data (backfill, existing constraints).
- `build`: after the second FAIL on the same area the builder is asked to
  generalise; `goal-builder` handles "must agree with another implementation"
  goals with an allowlisted subset and a differential test.

### Fixed
- `code-review` uses the built-in `/code-review` only when the shell keeps its
  directory between commands and the result covers the version's files;
  otherwise review agents work on the review worktree by absolute path (split
  by area for large versions). The review worktree now lives inside the repo
  under `.engineer-review/` (git-excluded) and `review-worktree.sh` lists the
  changed files.

## [0.6.0]

### Added
- `/engineer:code-review`: runs Claude Code's `/code-review` over the whole
  version (`build/vX` against `release`), triages findings against the
  design (`D-NN`, ADRs, invariants, conventions), applies accepted fixes and
  optimisations through `goal-builder` + `goal-verifier`, reruns every test
  and records each round in `docs/plans/vX/code-review.md` (incremental
  rounds after UAT fixes). `scripts/review-worktree.sh` gives the reviewer a
  throwaway worktree whose diff is exactly the version's changes. `build`
  calls it before `ship`; `ship` checks the last round still covers the code.
- `/engineer:build --approved`: every proposal raised during the build
  (build-time decisions, new ADRs of this version, approval items, plan-defect
  moves, review fixes, opening the PRs) is auto-approved and recorded as
  `approved: auto (--approved by …)`, listed in the final report and in PR
  #1. Scope changes, invariants, earlier ADRs, failing or newly skipped
  tests, force-push, merges and tags still stop for a person.

## [0.5.0]
Third round of user feedback.

### Added
- `scripts/report-fresh.sh`: a green test report stays valid across changes
  to docs, `CHANGELOG.md`, `.claude/` and the new `test_report_ignore` list in
  `.claude/engineer.yml` (`docs-layout.sh --ignore`); `ship` uses it.

### Changed
- `plan` self-check: every tagged scenario and DoD item must be deliverable
  once its goal and its `Depends on` chain are Done.
- `architect`: user-visible defaults a new client inherits from accepted ADRs
  are confirmed with the product owner as `D-NN`; the abuse analysis
  decides privilege-level enforcement of "who may write X" invariants and
  guards against self-lockout.

### Fixed
- `ship`, `release`, `feedback` call `bash "$S/gh.sh"` directly; the
  `GH="bash …"` variable form failed under zsh.

## [0.4.1]

### Changed
- Exceptions to enforced conventions (convention docs, lint/format/type-check
  rules, CI checks) are design decisions: `architect` checks every decided
  value and mechanism against them and records needed exceptions as `D-NN`
  with the convention doc updated; `goal-builder` reports such a need as
  `blocked`, never as a deviation; `goal-verifier` fails suppressions not
  covered by a `D-NN`.

## [0.4.0]
Second round of user feedback.

### Added
- `architect` delivers the complete design: a **Design decisions** table
  (`D-NN`: question, decision, rationale, authority, goals) approved in one
  batch, design-completeness principles (input sources, end-to-end flows incl.
  failure/retry, abuse and shared-resource analysis, measured parameters as
  target + rule) and spike goals for feasibility unknowns. `build` only adds
  **Build-time decisions** for the unforeseen and flags each one for review;
  `goal-builder` treats `D-NN` as binding, `goal-verifier` checks them.
- `scripts/commitlint-check.sh` and `references/commitlint.md`: detect a
  commitlint config that rejects `improve` and offer the `type-enum` fix;
  run by `init-docs` and `ship`.

### Changed
- `init-docs`: when a `build/vX` is in flight, the docs commit made on `main`
  is also cherry-picked onto that build branch, so it reaches `release`
  through PR #1 instead of a direct push.
- `docs-layout.sh` prints `hint adopt-needed` for repos that used the SDD
  before `.claude/engineer.yml` existed; `requirement` and `status` explain the
  one-time adopt step instead of reporting missing docs.

- Spike goals have defined rules (title marker, `N/A — spike` test items, a
  pre-registered `D-NN` filled when the spike is done); `architect` has a
  mid-build mode for architectural decisions found during the build.
- `build` checks commitlint before the first `improve` commit; `goal-builder`
  never bypasses hooks. `docs-layout.sh` prints `hint layout-on-main`
  when the adopt commit is on `main` but not on the current build.

### Fixed
- `check-commits.sh` validates `Refs:` as a real git trailer and gains
  `--require-refs`; records are NUL-separated, so unusual characters in a
  message cannot split them; `goal-builder` gets an exact commit-message
  template, and the orchestrator's own goal commits carry `Refs:` too.

## [0.3.0]
Fixes from the first round of user feedback.

### Added
- `scripts/docs-layout.sh` and `.claude/engineer.yml`: repos with their own docs
  tree map each SDD document; all skills and agents resolve paths through it.
  `init-docs` adopt mode writes the map and adds only missing pieces.
- `scripts/drift.sh`: commits on `main` that `release` lacks; `requirement`
  asks how to handle them, `start-build` warns, `status` reports them.
- `scripts/gh.sh`: retries `gh` with the user's own login when an app-scoped
  `GH_TOKEN` cannot see the repository.
- Scope change flow: `/engineer:requirement revise`, revise modes in `plan`
  and `architect`, `Dropped` goal state.
- DoD markers `N/A — <reason>` and `[approval: <role>]` with a build
  pause and a recorded sign-off.
- `@G-NN` scenario tags for feature tests spanning goals; `partial` FTs.
- `run-tests`: `preflight` command, passed/failed/skipped per suite, new skips
  never silently green; `ship` compares port totals with the build.
- `release prod --uat-waived "<reason>"`: release without STAG/UAT, with a
  separate confirmation and the waiver recorded in the tag message and release
  notes; `release prod` reports a PR #1 merged before UAT finished.

### Changed
- `build` commits the WIP state before spawning `goal-builder`; the builder
  never stages `plan.md`/`requirement.md`.
- `ship` is user-invocable to resume an interrupted ship.

### Fixed
- `status.sh` stopped early on a local build branch without a requirement.

### Upgrade note
- Repos that ran the SDD with 0.2.0 and keep invariants, ADRs or testing
  conventions outside the default `docs/0x-…` paths need a one-time
  `/engineer:init-docs` in **adopt** mode to write `.claude/engineer.yml`.
  Without it those documents are reported as missing.

## [0.2.0]
### Added
- Agentic SDD process (design: `docs/design/agentic-sdd.md`).
- Skills: `requirement`, `plan`, `architect`, `build`, `release`, `status`,
  `guide`, `feedback`; helpers `next-version`, `start-build`, `run-tests`,
  `ship`, `sync-docs`.
- Agents: `codebase-analyzer`, `goal-builder`, `goal-verifier`.
- Scripts: `next-version.sh`, `start-build.sh`, `check-commits.sh`, `port.sh`,
  `status.sh`, `feedback-queue.sh`.
- Shared conventions (`references/sdd-conventions.md`) and the silent retro
  that queues plugin feedback (`references/retro.md`).
- Onboarding guide in Vietnamese (Diátaxis): `docs/guide/`.

### Changed
- `init-docs`: scaffolds `docs/plans/`, `docs/test-cases/`, `CHANGELOG.md`;
  `testing.md` gets machine-readable `commands:`; C4 diagrams in the
  architecture overview; `git-workflow.md` describes the SDD branches, tags and
  Conventional Commits; `--cmd-*` options; existing root files are never
  overwritten; values with `&`, `|` or `\` are substituted safely.

### Removed
- `init-docs`: `docs/05-specs/` (replaced by `docs/plans/` per version and the
  feature tests as living spec).

## [0.1.0]
### Added
- Plugin skeleton and the `init-docs` skill.
