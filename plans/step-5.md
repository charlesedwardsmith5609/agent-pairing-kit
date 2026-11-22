# Step 5: review evidence, server-side enforcement note, dependency cooldown (branch improve/tldr-2026-11-20)

Stacked on `improve/tldr-2026-11-17` (step 4, skill lint). Three items, one commit each, in this
order: 5a, 5b, 5c. Run unattended: design choices are recommendations, collected under Open
questions. Source claims in the brief (Google Sashiko blog, OpenAI Performance Factory, a single
blog post on merging, TLDR InfoSec items) are treated as claims, not facts; none of the changes
below depends on them being true.

## Repo state (verified on this branch)

- `base/review-checklist.md:21-23` output format asks for "severity (HIGH, MEDIUM, LOW), file and
  line or function, what goes wrong in one concrete scenario, and the smallest fix". No quote, no
  falsification sentence.
- The checklist is the system prompt for code review: `new-project.sh:113-117` writes
  `skills/review-checklist.md` = base checklist + each `profiles/<p>/review.md`;
  `scripts/cross-review.sh:89` and `scripts/cross-review.ps1:92` send it. `tests/test-cross-review.sh:60,157`
  copy the base checklist into scratch repos (tests do not assert its wording).
- The agent's assessment step: `base/CLAUDE.md:80-81` ("give your assessment of each one (agree or
  disagree, with a reason)") and `claude-commands/cross-review.md` ("for each finding, give a
  one-line assessment: AGREE or DISAGREE").
- No written "never self-merge" rule exists in `base/CLAUDE.md`. `claude-settings.json` denies only
  environ/env/secrets/metadata reads and curl/wget to metadata hosts; it asks for `WebFetch`. It
  does not deny `git push` or `gh pr merge`.
- The kit checks, from a local clone: edits to validation gate files including
  `.github/workflows/*` (`scripts/misbehavior-check.sh:64-71`); secret scan of staged additions
  (`scripts/check.sh:36-83`); fail-closed secret scan before review text leaves the machine
  (`scripts/review-call.sh`, DECISIONS.md 2026-11-14); tool and toolchain drift (`kit-audit.sh`).
  Nothing in `scripts/` or `kit-audit.sh` calls the GitHub API or reads branch protection
  (grep for `gh `/`protect` in `kit-audit.sh` finds only the gitleaks warning at line 78).
- The kit repo has no `.github/CODEOWNERS` (`.github/` holds `dependabot.yml` and `workflows/ci.yml`).
- `.github/dependabot.yml`: one entry, `package-ecosystem: github-actions`, `directory: /`,
  `schedule.interval: weekly`; no `cooldown`.

## Requirements for this step (implementer appends to REQUIREMENTS.md, section "TLDR 2026-11-20")

- E1. Each code-review finding carries the exact diff line(s) it is about, quoted, and one sentence
  naming the observation that would show the finding is wrong.
- E2. A finding with no quoted line is unverified, for the human and for the agent's assessment.
- E3. No `cross-review.sh --verify` second pass in this step (proposal only).
- D1. `docs/server-side-enforcement.md`: what the repository host must enforce, what the kit can and
  cannot check from a clone, each "kit checks X" claim citing a script; linked from README.
- C1. `.github/dependabot.yml` gets a 7-day cooldown (pending owner confirmation); DECISIONS.md
  records it.

## 5a. Evidence in review findings

Approach:
- `base/review-checklist.md` output format bullet becomes (wording may be tightened, content fixed):
  "For each: severity (HIGH, MEDIUM, LOW); file and line or function; **Quote:** the exact line(s)
  from the diff the finding is about, copied verbatim (prefix `+`/`-` kept); what goes wrong in one
  concrete scenario; the smallest fix; **Would be wrong if:** one sentence naming the observation
  (a test result, a caller, a guard elsewhere) that would show this finding is wrong. A finding
  with no quoted line will be treated as unverified." The "No meaningful issues found" bullet stays.
- Field labels are fixed strings, `Quote:` and `Would be wrong if:`, so the docs test and a human can
  find them.
- `base/CLAUDE.md` (the paragraph at lines 75-81): add one sentence: a finding with no quoted diff
  line is unverified; say so in the assessment and do not act on it until the quote is found or the
  human decides. Also check that the quoted line actually appears in the diff; if not, mark it
  unverified.
- `claude-commands/cross-review.md`: same rule in the assessment paragraph (UNVERIFIED as a third
  label next to AGREE/DISAGREE).
- `base/plan-review-checklist.md`: unchanged (plans have no diff lines; not asked).
- Existing generated projects keep their old checklist (README Notes already says `skills/` and
  `CLAUDE.md` are not refreshed); CHANGELOG says so.
- Not built: `cross-review.sh --verify`. Proposal recorded in the plan and DECISIONS-free (it is a
  question, not a decision): a second provider call per finding that sends the finding, its quote,
  and the surrounding hunk, and asks the reviewer to try to falsify it; cost is one extra provider
  call per finding, so up to 8 extra calls per review (the checklist caps findings at 8,
  `base/review-checklist.md:21`), roughly 9x the calls of a review with 8 findings. Each call also
  goes through the fail-closed gitleaks scan.

Files: `base/review-checklist.md`, `base/CLAUDE.md`, `claude-commands/cross-review.md`,
`tests/test-docs.sh`, `CHANGELOG.md`, `REQUIREMENTS.md`.

Tests (written failing first):
1. `tests/test-docs.sh`: `base/review-checklist.md` contains `Quote:` and `Would be wrong if:`
   (fixed-string `has` checks, `tests/test-docs.sh:9`).
2. `tests/test-docs.sh`: `base/review-checklist.md` contains the word `unverified`;
   `base/CLAUDE.md` and `claude-commands/cross-review.md` each contain `unverified`
   (case-insensitive `grep -qi`).
3. `tests/test-docs.sh`: `base/review-checklist.md` contains no `--verify` (guards against building
   the deferred pass in the prompt).
4. Existing `tests/test-cross-review.sh` passes unchanged.
5. `bash tests/smoke-new-project.sh python` passes, and the generated `skills/review-checklist.md`
   contains `Quote:` (add one `grep -q` line to the smoke test, which already checks generated
   files, `tests/smoke-new-project.sh:25-27`).

Done: tests 1-5 pass; shellcheck clean; cross-review run on the commit.

## 5b. docs/server-side-enforcement.md (docs only, no code)

Content outline:
1. Written rules are requests. An agent can be told "never self-merge" or "the human approves the
   plan", and the kit's rules (`base/CLAUDE.md:9-23`) are of that kind. They are enforced only when
   the host refuses the action.
2. What the repository host must enforce (GitHub terms; other hosts have equivalents, not
   verified here):
   - Branch protection or a ruleset on the default branch: pull request required, at least one
     approving review, dismiss stale approvals on new commits, require status checks (the `ci`
     workflow jobs), no force-push, no deletion, and no bypass for the agent's identity.
   - The agent's token: a fine-grained token or app without merge or admin rights (contents write
     on its own branches at most; no administration, no bypass of rules). Where the host cannot
     separate push from merge for a token, keep the agent's credentials push-only to a fork.
   - CODEOWNERS covering the rules and scripts directories, with "require review from code owners"
     on: for a generated project `CLAUDE.md`, `AGENTS.md`, `skills/`, `scripts/`, `.claude/`,
     `.cursor/`, `.pairing-profiles`, `.github/`; for the kit `base/`, `profiles/`, `scripts/`,
     `claude-settings.json`, `.github/`.
   Each GitHub setting name is checked against docs.github.com before it is written, or marked
   "not verified" in the doc.
3. What the kit can check from a local clone, each with a citation: gate-file edits including
   `.github/workflows/*` (`scripts/misbehavior-check.sh:64-71`); staged secret scan
   (`scripts/check.sh:36-83`); fail-closed scan of review text (`scripts/review-call.sh`); tool drift
   (`kit-audit.sh`); whether a `.github/CODEOWNERS` file exists in the tree (possible, not
   implemented; see Q-B1).
4. What it cannot check: branch protection and rulesets, token scopes, whether CODEOWNERS review is
   required, who merged a PR, or whether CI is required. These live on the host and are not in a
   clone; `gh api` could read some of them with an admin token, which the kit does not use
   (no script calls the GitHub API; noted as a fact about `scripts/` and `kit-audit.sh`).
5. Client-side complement: Claude Code `permissions.deny` can block `gh pr merge` / `git push` to the
   default branch for the local agent, but it is still client-side. Not added to
   `claude-settings.json` (Q-B2).
- README: one line under Notes linking `docs/server-side-enforcement.md`.
- The brief's source (one blog post, itsmeduncan.com 2026-11-17) is cited as a single report, not
  evidence. If the URL cannot be read, the doc says so.

Files: `docs/server-side-enforcement.md`, `README.md`, `tests/test-docs.sh`, `CHANGELOG.md`.

Tests (written failing first), in `tests/test-docs.sh`:
1. `docs/server-side-enforcement.md` exists and contains `branch protection`, `CODEOWNERS`, and
   `cannot` (the cannot-check section).
2. README links `docs/server-side-enforcement.md`.
3. Every `scripts/<name>.sh` or `kit-audit.sh` path mentioned in the doc exists in the kit
   (loop over `grep -o` matches; catches a citation to a script that does not exist).
4. Existing smoke test (devcontainer pointer rule, `tests/smoke-new-project.sh`) unaffected: the
   new doc is kit-only and nothing generated points at it.

Done: tests pass; shellcheck clean; cross-review run.

## 5c. Dependency cooldown in .github/dependabot.yml

Verified on docs.github.com (Dependabot options reference,
https://docs.github.com/en/code-security/dependabot/working-with-dependabot/dependabot-options-reference,
read 2026-11-21):
- Keys under `cooldown`: `default-days`, `semver-major-days`, `semver-minor-days`,
  `semver-patch-days` ("applies only to package managers supporting SemVer"), `include` and
  `exclude` (up to 150 items, wildcards).
- "The `cooldown` option is only available for *version* updates, not *security* updates."
- The page also says Dependabot applies a default 3-day cooldown to version updates even when
  `cooldown` is not configured, and that default does not apply to security updates.
Could not confirm: whether `github-actions` supports `cooldown` (`default-days`) at all (the
"Default days supported" column of the per-ecosystem table was not read for that row);
whether `github-actions` supports the `semver-*-days` keys (the per-ecosystem
table row was not read); numeric limits on the `*-days` values; whether `exclude` wins over
`include` (only seen in a summary). The implementer re-fetches the page and the tutorial
https://docs.github.com/en/code-security/tutorials/secure-your-dependencies/optimizing-pr-creation-version-updates
and records what is still unconfirmed.

Precondition (from plan review): before writing the file, the implementer confirms on the
docs page that the `github-actions` row has "Default days supported". If confirmed, build as
below. If it cannot be confirmed, still add the block only if the docs do not say it is
unsupported, and word README/SECURITY/DECISIONS as "configured; GitHub support for
github-actions not confirmed locally" rather than claiming an effective delay; if the docs say
unsupported, do not add it and report 5c as blocked.

Approach (on the stated 7-day default, pending owner confirmation):
```yaml
  - package-ecosystem: github-actions
    directory: /
    schedule:
      interval: weekly
    cooldown:
      default-days: 7
```
Only `default-days`, because the semver keys are unconfirmed for github-actions. Security updates
are unaffected per the docs. DECISIONS.md entry "2026-11-20: 7-day Dependabot cooldown": provenance
is not safety (the brief cites a compromised official PyPI release and a trusted-publishing
compromise; Chainguard advertises 7 days), so new releases wait a week; security updates are not
delayed; what was not confirmed. README row for `.github/workflows/ci.yml` (Dependabot sentence)
and `SECURITY.md:9` mention the cooldown. CHANGELOG entry.

Files: `.github/dependabot.yml`, `DECISIONS.md`, `README.md`, `SECURITY.md`, `CHANGELOG.md`,
`tests/test-docs.sh`.

Tests (written failing first), in `tests/test-docs.sh`:
1. `.github/dependabot.yml` parses as YAML with `python3` only if PyYAML is importable; otherwise a
   structural awk check (no new deps): every `- package-ecosystem:` entry has a `cooldown:` block
   with `default-days: 7`. Recommend the awk check always (stdlib python has no YAML parser).
2. DECISIONS.md contains `Dependabot cooldown`.
Done: tests pass; shellcheck clean; cross-review run. GitHub validates the file only on push;
nothing local proves Dependabot accepts it (say so in the report).

## Gate for every item

- `git ls-files -z '*.sh' | xargs -0 shellcheck -x`
- every `tests/test-*.sh` (step 4 adds `tests/test-skill-lint.sh`), `bash tests/smoke-new-project.sh python`
- `PAIRING_STRICT=1 bash scripts/skill-lint.sh .` (from step 4)
- `bash scripts/check.sh` in the kit: NOT RUNNABLE (exits 2, no `.pairing-profiles`, see step 4 Q2);
  report NOT RUN.
- `bash scripts/cross-review.sh` per item commit (run from a scratch layout or with a temporary
  root `skills/review-checklist.md`, because the kit root has no `skills/`; see step 4 plan review
  note); findings assessed.

## Build vs note-only (unattended policy)

- 5a: build the two fields and the unverified rule (docs + tests). Note only: `--verify`.
- 5b: build the doc and link (docs). Note only: CODEOWNERS reminder in `check.sh`, deny rules.
- 5c: build on the stated 7-day default, flagged "implemented on the stated default, pending owner
  confirmation".

## Open questions for the owner (with recommendation)

- Q-A1. Build `cross-review.sh --verify` (one extra provider call per finding, up to 8 per review)?
  Recommend not by default; if built, opt-in flag, only for HIGH findings, so cost is usually 0-2
  extra calls.
- Q-A2. Should a finding with no quote be dropped or kept as unverified? Recommend kept and labelled
  (dropping hides real issues where the reviewer quoted badly).
- Q-B1. Should `check.sh` print a one-time reminder when `.github/CODEOWNERS` is absent? Recommend
  yes as a WARN-free info line, printed once per clone (marker under `.git/`), never a failure.
  Not built.
- Q-B2. Add `Bash(gh pr merge*)` and `Bash(git push*main*)` to `claude-settings.json` deny? Recommend
  yes in a later step; it is client-side only and outside this brief.
- Q-B3. Add a CODEOWNERS file to the kit repo itself? Recommend yes (owner-only `base/`, `scripts/`,
  `profiles/`, `.github/`); owner must also turn on the host setting. Not built.
- Q-C1. 7 days confirmed? Also use `semver-major-days` (for example 14) if github-actions supports
  it? Recommend 7 flat until the ecosystem table is confirmed.

## Plan review (cross-model, OpenAI gpt-6.1-sol, 2026-11-21)

Run through `scripts/plan-review.sh` in a scratch copy laid out like a generated project (kit root
lacks `CLAUDE.md` and `skills/plan-review-checklist.md`; the base files were used and E1-E3, D1,
C1 appended to the scratch `REQUIREMENTS.md`). Findings:
- MEDIUM MISSING (5c): confirm github-actions supports `cooldown.default-days` itself, else docs
  would claim a delay that does not exist. AGREE: added the precondition and fallback wording.
- MEDIUM WRONG (structure): three commits contradict "one local commit per plan step"
  (REQUIREMENTS.md). DISAGREE: that line belongs to the 2026-11-14 review-fix requirements; the
  owner's brief for this pass says "one commit per item", and the three items are independent
  (docs prompt, doc note, config). Kept 5a/5b/5c as one commit each; the owner can squash.

## Suggestions (not in this step)

- `kit-audit.sh` could read branch protection with `gh api` when the owner's token allows; outside
  "local clone" scope.

## Files

- base/review-checklist.md
- base/CLAUDE.md
- claude-commands/cross-review.md
- docs/server-side-enforcement.md
- .github/dependabot.yml
- tests/test-docs.sh
- tests/smoke-new-project.sh
- README.md
- SECURITY.md
- CHANGELOG.md
- DECISIONS.md
- REQUIREMENTS.md
- plans/step-5.md
