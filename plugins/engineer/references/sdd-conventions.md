# Agentic SDD conventions

Single source of truth for every `engineer:*` skill and agent. When a skill says
"per the conventions", it means this file. Do not restate these rules
differently elsewhere — link here.

## Plugin paths

`${CLAUDE_PLUGIN_ROOT}` is the plugin directory. If it is not expanded in your
context, derive it: it is two directories above the loaded skill's base
directory (`<skill dir>/../..`). Shared scripts live in
`${CLAUDE_PLUGIN_ROOT}/scripts/`, shared references in
`${CLAUDE_PLUGIN_ROOT}/references/`.

## Environments and branches

| Branch | Role |
|---|---|
| `main` | STAG environment. Receives code through `port/vX` PRs. |
| `release` | PROD environment. Receives code through `build/vX` PRs. |
| `build/vX.Y.Z.T` | Integration branch for one version. Created from `origin/release` when the requirement is approved. Every artifact of the version (docs, code, tests) is committed here. Its existence on the remote **reserves** the version number. |
| `port/vX.Y.Z.T` | Created from `origin/main`; receives `git cherry-pick -x` of the build branch commits. |

Promotion order is always **STAG first, PROD second**: merge PR #2
(`port/vX → main`), tag `-rc.N`, UAT on STAG, then merge PR #1
(`build/vX → release`) and tag `vX`.

The remote is `origin` unless the repo says otherwise.

## Versions and tags

- Format `X.Y.Z.T`. Bump kinds:

  | Kind | Digit | Meaning |
  |---|---|---|
  | `major` | X | Change that is not compatible with the previous version |
  | `feature` | Y | New feature |
  | `improvement` | Z | Improvement of an existing feature |
  | `fix` | T | Bug fix |

- Bumping a digit resets the lower digits to 0 (`1.2.3.4` + feature → `1.3.0.0`).
- A requirement mixing kinds takes the highest one.
- Base = latest PROD tag reachable from `origin/release`; `0.0.0.0` if none.
- If the bumped number is already reserved by an `origin/build/v*` branch, bump
  the same digit again until free. `scripts/next-version.sh` implements this —
  never compute versions by hand.
- Tags: PROD `vX.Y.Z.T` on `release`; STAG `vX.Y.Z.T-rc.N` on `main`. Annotated
  tags only. Tags are created only by `/engineer:release`, after the user
  confirms.
- The version lives only in git tags, docs paths and branch names. Do not write
  it into package manifests.
- A PROD tag must be greater than every existing PROD tag. If a version reaches
  PROD after a higher one (parallel work), it must be renumbered first (see
  `/engineer:release`).

## Drift between main and release

Commits that reach `main` without going through a build branch (direct
commits, shared tooling) never reach `release` on their own, and build branches
created from `release` lack them. `scripts/drift.sh` lists them (ports and
`fix(port): …` commits excluded). `requirement` checks it before sign-off,
`start-build.sh` warns, `status` reports the count.

## Scope change during a version

When the requirement changes after approval (the PO adds, removes or changes
behaviour), revise in place instead of improvising — IDs stay stable so the
history remains traceable:

1. `/engineer:requirement revise` — pauses the build (a `WIP` goal goes back to
   `To Do`), records **Revision N** in `requirement.md` (what changed, who asked,
   date; removed REQs are struck through, new REQs take the next numbers),
   re-checks the bump (a higher bump kind means renumbering the version), and
   sets `status: approved` after the user re-approves.
2. `/engineer:plan` (revise mode) — goals of removed REQs become `Dropped`
   (a `Done` one gets a new goal that removes its code); `Done` goals whose
   outcome changed go back to `To Do` with a note; new goals are appended;
   FTs introduced in this unreleased version are edited or deleted, older ones
   updated or deprecated.
3. `/engineer:architect` (revise mode) — ADRs accepted in this same unreleased
   version may be amended in place with a "Revision N" note; ADRs from earlier
   versions are superseded by a new ADR. `architecture.md` gets a "Revision N"
   section.
4. `/engineer:build` resumes with the goals that are not `Done`/`Dropped`. Open
   PRs are updated by `ship`; a version already on STAG gets a new rc.

## Selecting the version a skill works on

Skills after `requirement` operate on one version:

1. If the current branch is `build/vX.Y.Z.T`, that is the version.
2. Else, if the user named a version, use it.
3. Else run `scripts/status.sh` and ask which version.

Then make sure the working tree is on `build/vX` (switch if clean; if the build
branch is checked out in another worktree, tell the user to continue there). Pull
the latest `origin/build/vX` (`git pull --ff-only`) before writing anything.

## Lifecycle status

Stored in `docs/plans/vX/requirement.md` frontmatter (`status:`):

`approved → planned → architected → building → in-review`, or `abandoned`.

WBS goal `State`: `To Do` → `WIP` → `Done`, or `Dropped` (removed by a scope
change, kept for traceability). Only `/engineer:build` and the revise modes of
`requirement` and `plan` change `State`, and they commit every change (`docs(vX.Y.Z.T): start G-NN`, `… complete G-NN`), so
the tree is clean whenever a subagent works.

After `in-review`, status is derived from tags: an `vX-rc.N` tag means
`staging`, the `vX` tag means `released`. Exception: a scope revision after
STAG (see "Scope change during a version") sets the frontmatter back to an
earlier phase (`approved` … `building`); that frontmatter status wins over the
rc tag until the version is shipped again (`status.sh` shows
`approved (rc.N on STAG)`). Skills check the expected status before
running and refuse to skip a gate unless the user explicitly says so.

## Artifact layout (product repo)

```
docs/plans/vX.Y.Z.T/requirement.md     # engineer:requirement
docs/plans/vX.Y.Z.T/plan.md            # engineer:plan
docs/plans/vX.Y.Z.T/architecture.md    # engineer:architect
docs/plans/vX.Y.Z.T/code-review.md     # engineer:code-review
docs/plans/vX.Y.Z.T/test-report.md     # engineer:run-tests
docs/test-cases/feature-tests/<domain>/FT-vX.Y.Z.T-NN-<slug>.md
docs/test-cases/unit-tests/vX.Y.Z.T.md
CHANGELOG.md                           # Keep a Changelog, entry written by engineer:ship
```

Artifact headings are fixed in English (skills parse them). Body text follows
the language the user is speaking.

## Docs layout

Every path of the default layout mentioned in the skills and agents — with or
without the `docs/` prefix (`docs/02-constraints/invariants.md`,
`02-constraints/invariants.md`, `06-agent-guide/…`) — is the **default**
location of a document, as created by `/engineer:init-docs`. Repos with their own docs tree
override locations in `.claude/engineer.yml` (written by `init-docs` in adopt
mode). Always resolve before reading or writing:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/docs-layout.sh"            # all keys: key, path, ok|missing
bash "${CLAUDE_PLUGIN_ROOT}/scripts/docs-layout.sh" --get invariants
```

| Key | Default | Key | Default |
|---|---|---|---|
| `readme` | `docs/README.md` | `conventions` | `docs/04-conventions` |
| `context` | `docs/00-context` | `testing` | `docs/04-conventions/testing.md` |
| `architecture` | `docs/01-architecture/overview.md` | `git_workflow` | `docs/04-conventions/git-workflow.md` |
| `components` | `docs/01-architecture/components` | `agent_workflow` | `docs/06-agent-guide/workflow.md` |
| `data_model` | `docs/01-architecture/data-model.md` | `pitfalls` | `docs/06-agent-guide/known-pitfalls.md` |
| `invariants` | `docs/02-constraints/invariants.md` | `plans` | `docs/plans` |
| `non_functional` | `docs/02-constraints/non-functional.md` | `feature_tests` | `docs/test-cases/feature-tests` |
| `dependencies` | `docs/02-constraints/dependencies.md` | `unit_tests` | `docs/test-cases/unit-tests` |
| `decisions` | `docs/03-decisions` | `adr_template` | `docs/03-decisions/_template.md` |

Rules:
- Read a document at its resolved path. A `missing` document is simply absent
  — do not invent its content; for core ones (`invariants`, `decisions`,
  `testing`) tell the user once and suggest `/engineer:init-docs` (adopt mode).
- When you must create a missing document, create it at its resolved path and
  mention it.
- Cite invariants in the repo's own format, given by `invariant_id`
  (default `INV-{nnn}` → `INV-007`; e.g. `#{n}` → `#7`). Never renumber an
  existing invariants file.
- ADRs follow the repo's template at `adr_template` when it exists.
- When spawning a subagent, pass the resolved layout (the script's output)
  in the prompt; agents use it instead of the defaults.

## IDs and traceability

- `REQ-NN` — a requirement item, scoped to its version (`vX/REQ-01` when cited
  from outside).
- `G-NN` — a WBS goal in `plan.md`, scoped to its version.
- `FT-vX.Y.Z.T-NN` — a feature test. Globally unique without coordination
  because it embeds the version that introduced it. The ID never changes, even
  when later versions edit the test.
- `INV-NNN` invariants and `ADR-NNNN` decisions, as defined by `init-docs`.

Chain: `REQ` → `G` (via `Covers:`) → `FT` (via `covers:`) → automated test name
contains the FT-ID → unit tests mapped in `unit-tests/vX.md`.

## Design decisions (D-NN)

`/engineer:architect` delivers the **complete design** of a version: every
decision the build needs is taken before the build starts, so `build` executes
and only decides what truly could not be foreseen.

Each decision is a row in the "Design decisions" table of
`docs/plans/vX/architecture.md`:

| Field | Content |
|---|---|
| `ID` | `D-NN`, numbered per version |
| `Question` | what had to be decided, in one line |
| `Decision` | the chosen option (and the main alternative rejected) |
| `Rationale` | why, in one or two lines |
| `Authority` | `approved: <role> <name>, <date>` — or `builder: <bounds>` when the builder may settle it within stated bounds (e.g. a parameter fixed by measurement: target + rule) |
| `Goals` | goals it binds; an architectural decision also links its ADR |

- Decisions needing approval are approved **together** at the architect gate.
- `goal-builder` treats `D-NN` as binding and decides only inside
  `builder:` bounds (reporting the value chosen). Anything else unforeseen →
  `blocked` with a proposed decision in the same format; after the user
  approves, `build` records it under "Build-time decisions" (`D-NN` continues
  the numbering) and the silent retro records *"could architect have decided
  this?"* (skill `architect`) so the design guidance improves.
- `goal-verifier` checks the goal's code against the decisions that bind it.
- **Exceptions to enforced conventions are decisions.** An enforced convention
  is any rule the repo checks or states as mandatory: the convention docs,
  linter / formatter / type-checker configuration, CI checks. A value or
  mechanism that needs an exception to one (a suppression or disable comment,
  an allow-list entry, a rule turned off) is a `D-NN` naming the rule and the
  scope of the exception, and the convention doc is updated in the same
  commit to list it. It is never settled silently as a builder "deviation".
  - Authority is always `approved: …` — never `builder:`.
  - "The convention doc" is the one covering that area; if none does (the
    rule lives only in linter or CI config), use `<conventions>/exceptions.md`
    (create it; `conventions` per "Docs layout").
  - Only **new** exceptions count: a rule or scope not suppressed before the
    goal started. Suppressions that already existed and were only moved or
    reformatted need nothing. Generated or vendored code and the ignore
    globs/headers for it are exceptions too, unless an existing convention
    already covers them.
  - Invariants and `Accepted` ADRs are not conventions: they change only
    through an ADR (architectural decision, `architect` mid-build mode).

## Spike goals

A feasibility question the design cannot answer by reasoning becomes a spike
goal, appended to `plan.md` by `/engineer:architect`:

- ID `G-NN` like any goal; "(spike)" appears only in the title
  (`### G-07 — (spike) Can the payment sandbox replay webhooks?`).
- `Covers: —`; `Depends on` of the goals that need the answer point to it.
- Outcome: the answer, with evidence. DoD: the evidence item, plus
  `Feature tests: N/A — spike` and `Unit tests: N/A — spike`; no production code
  is kept unless the DoD says so.
- The decision it feeds is **pre-registered** at the architect gate as a
  `D-NN` row whose `Decision` reads `pending spike G-NN` and whose `Authority`
  names who settles it (`approved: …` or `builder: <bounds>`). When the spike
  is Done, `build` fills that row in (asking the approver if needed) — this is
  not a build-time decision and records no retro entry.

## Definition of Done items

Plain DoD items are checked by `goal-verifier` with evidence. Two markers:

- **`N/A — <reason>`** — an item that does not apply to this goal, e.g.
  `Unit tests: N/A — the goal changes no code (docs only)`. The verifier
  accepts it only if the reason holds against the goal's diff.
- **`[approval: <role>]`** — a human sign-off, e.g.
  `[approval: PO] marketing copy of the landing page`. `build` pauses after the
  builder, shows the review summary, and records the answer in the goal's Notes
  as `Approved: <role> <name>, <YYYY-MM-DD> — <item>`. The verifier checks the
  record exists and that no later commit of the goal changed the approved
  content (otherwise a new approval is needed).

## Feature tests spanning several goals

When one FT's scenarios become testable at different goals, tag every scenario
with the goal that makes it pass, using Gherkin tags (`@G-02`). "Makes it pass"
means: once that goal and its `Depends on` chain are Done, every screen,
operation and piece of data the scenario touches exists. The same rule applies
to each DoD item — it must be checkable when its goal is Done; otherwise it
belongs to the first goal that delivers what it needs. The goal's
`Feature tests:` line names the tags (`FT-v1.3.0.0-10 (@G-02)`). An FT that
covers a single goal needs no tags. While later goals are pending, their
scenarios are **pending**, not failures: the verifier of `G-02` checks the
`@G-02` scenarios and that scenarios of goals already Done still pass;
`run-tests` reports such an FT as `partial (k/n)` until every tagged goal is
Done, and requires all scenarios green before `ship`.

## Tests

- Commands come from the `commands:` frontmatter of
  the `testing` document (`preflight`, `setup`, `lint`, `unit`, `feature`).
  Never guess a command when that file defines one; if a command is missing,
  ask the user and write it back to the file.
- A test report stays valid until something that can affect the tests
  changes: `scripts/report-fresh.sh --since <report commit>` ignores the docs
  (every docs-layout path), `CHANGELOG.md`, `.claude/` (agent and editor
  tooling) and the `test_report_ignore` patterns of `.claude/engineer.yml` —
  but the feature-test documents, the `testing` document and
  `.claude/engineer.yml` itself always count, and the layout and ignore list
  are read as of the report commit. Patterns: `dir/` covers everything below
  it, a pattern without `/` matches at any depth (`*.local.json`), a leading
  `/` anchors at the repo root. Anything but `fresh` (exit 0) means rerun.
- A failed `preflight` is an environment problem: stop, do not run suites.
  Skipped tests are counted and compared with the previous run; a new skip is
  never silently green.
- Unit test code lives next to the source, per the stack's convention.
- Feature test `.md` files are the source of truth (Gherkin). `automation:
  automated` ones are implemented in the stack's e2e/integration framework with
  the FT-ID in the test name; `manual` ones are executed by the agent and the
  evidence is recorded in `test-report.md`.

## Commits and PRs (Conventional Commits, mandatory)

Subject: `<type>(<optional scope>)<optional !>: <description>`

Allowed types: `feat`, `fix`, `perf`, `refactor`, `improve`, `docs`, `test`,
`build`, `ci`, `chore`, `style`, `revert`. `improve` is this workflow's extension
for user-visible improvements of existing behaviour.

Mapping to the bump kind: `!` or a `BREAKING CHANGE:` footer → major; `feat` →
feature; `perf` / `refactor` / `improve` → improvement; `fix` → fix.

Commits made for a WBS goal carry a trailer `Refs: vX.Y.Z.T/G-NN`. It must be
a **real git trailer**: in the last paragraph of the message, in the same block
as every other trailer (`Co-Authored-By:`, `Signed-off-by:`), with no blank
line between them — otherwise `git interpret-trailers` and
`%(trailers)` do not see it. Exact shape:

```
feat(cart): apply coupon codes at checkout

Short why/what, wrapped at 72 columns.

Refs: v1.3.0.0/G-02
Co-Authored-By: <name> <email>
```

Repos using commitlint must allow `improve` in `type-enum`
(`scripts/commitlint-check.sh`, snippets in `references/commitlint.md`);
`init-docs` and `ship` check it.

`scripts/check-commits.sh` rejects a `Refs:` line that git does not parse as a
trailer, and `--require-refs vX.Y.Z.T/G-NN` checks every commit of a goal.
Artifact commits use `docs(vX.Y.Z.T): …`.

PR titles: `<type>: <summary> (vX.Y.Z.T)`, where the type matches the version's
bump kind (`feat!` for major, `feat`, `improve`, `fix`). PR #1 and PR #2 share
the same title; their base branch (`release` / `main`) tells them apart. Merge
both with a **merge commit, never squash**: the `(cherry picked from commit …)`
trailers on `main` are how `scripts/port.sh` knows which build commits already
reached STAG during UAT fix rounds. This is also why every individual commit
must follow Conventional Commits.

`scripts/check-commits.sh` validates a commit range; `engineer:ship` blocks on
failure.

## GitHub CLI

Call GitHub only as `bash "${CLAUDE_PLUGIN_ROOT}/scripts/gh.sh" <gh args>`
(skills shorten the directory to `$S` or `$G`). Never store the command in a
variable and call `$VAR args`: zsh, the default shell on macOS, does not
word-split parameters, so the whole string becomes one command name. Quote
every script path (`bash "$S/port.sh"`). Agent apps often export an app-scoped `GH_TOKEN`
that cannot see every organisation; the wrapper retries once with the env
tokens unset (the user's own `gh auth login`) on access errors only, and prints
a note explaining it. Relay that note to the user the first time it appears.

## Human gates

Ask before: pushing a branch, opening a PR, merging, creating or pushing a tag,
filing a GitHub issue. Approving a gate (e.g. "requirement approved") covers the
actions that gate announces, nothing more. A skill may ask once for a recurring
action it announces up front (e.g. `build`: "push `build/vX` periodically").
Any changed number, branch or target after approval needs a new confirmation.

### Approved runs (`--approved`)

`/engineer:build --approved` (and `/engineer:code-review --approved`) mean the
user pre-approves every proposal that comes up **during the build**, so the
run does not stop to ask. Pre-approved:

- pushing `build/vX` periodically;
- build-time decisions (`D-NN`) the builder proposes, and new ADRs written
  for this version by `/engineer:architect` in mid-build mode;
- `[approval: <role>]` DoD items, on the builder's review summary;
- moving plan defects to the goal that delivers their capability;
- the fixes `/engineer:code-review` proposes;
- the hand-over to `ship`: pushing `build/vX` and `port/vX`, opening or
  updating PR #1 and PR #2 (`ship` receives `--approved`).

Every auto-approval is recorded where a human approval would be:
- `D-NN` `Authority` and ADR status line:
  `approved: auto (--approved by <git user.name>), <YYYY-MM-DD>`;
- goal Notes, for an `[approval: <role>]` item:
  `Approved: <role> auto (--approved by <git user.name>), <YYYY-MM-DD> — <item>`
  (`goal-verifier` accepts this form like a personal sign-off).

It counts as `approved:` authority (not `builder:`), so it also covers
convention exceptions. All of them are listed in the run's final report and in
a section **Auto-approved during build** of PR #1, grouped by the role that
would normally approve (PO, architect, …), so those people review them before
the PRs are merged.

Also pre-approved in an approved run: filling a spike's pre-registered `D-NN`,
confirming detected test commands, and — inside `ship` — the
`--force-with-lease` push that restarts `port/vX` after its previous PR #2 was
merged (that branch is derived and its old content is already on `main`).

Never pre-approved — the run stops and asks even with `--approved`:
- a scope change (that is `/engineer:requirement revise`), including a review
  or build proposal that changes behaviour users see or what an approved
  acceptance criterion / feature test says;
- resolving a merge conflict whose intent is unclear;
- changing an invariant, or superseding an `Accepted` ADR of an earlier
  version;
- accepting a failing test or a new skipped test, or skipping a suite
  (only the user can skip tests, with `/engineer:ship --skip-test`);
- a goal still failing after the retries, or anything the builder cannot do;
- any other rewrite of published history (force-push), merging PRs,
  creating tags — those belong to `/engineer:release`.

### Skipping tests at ship

Tests may be skipped at ship only by the user, explicitly:
`/engineer:ship --skip-test ["<reason>"]` (e.g. the suites need an
environment this machine lacks, or they already ran in CI). An agent never
chooses it, and `--approved` never implies it. It skips running or requiring
tests inside `ship` (test-report and code-review freshness become warnings,
the port is not tested); every other gate stays. Both PRs then start with a
**Tests skipped** warning (reason, who, date, state of the last test report
and code review), and `/engineer:release` repeats it in its confirmations.

UAT on STAG is a gate too. It can be skipped only with
`/engineer:release prod --uat-waived "<reason>"` (e.g. the team has no STAG
environment yet): a separate confirmation naming who waives it, and the
waiver recorded in the PROD tag message (`UAT waived: …`, `Waived by: …`) and
at the top of the GitHub Release notes.

## Ending every user-facing skill

1. Print **"Bước tiếp theo / Next step:"** with the exact command to run next.
2. Run the silent retro in `references/retro.md`.
