# Decisions

## 2026-11-13: Reuse cursor/agent-guardrails by cherry-pick

Context: `origin/cursor/agent-guardrails` (`cf9b5af`) is one commit that main does not contain. Main has later commits that the guardrails branch does not contain. The merge-base is `d916633`.

Options: branch the catch-up work from the old branch and miss later main commits; rebase the old branch; cherry-pick the one commit onto a branch cut from current main.

Choice: `improve/tldr-catchup-2026-11-13` is cut from `origin/main`. The guardrails commit is cherry-picked and conflict-resolved so both the newer secret-scan, test-first, and security-default text and the tool-call policy stay. The old branch is not rewritten.

Why: Reuse the unmerged work without dropping commits that are already on main.

## 2026-11-13: Assertion scan reads test files, not diffs

Context: The catch-up asks for a warn-only check that flags tests with no assertions, and to compare it with a "no diff grep" decision in DECISIONS.md. This repo had no DECISIONS.md before this branch. `scripts/misbehavior-check.sh` already greps added diff lines for skip markers.

Options: flag assertion-free tests by grepping the diff; scan test files on disk.

Choice: `scripts/assertion-check.sh` scans `*_test.go`, `test_*.py`, `*_test.py`, and `*.test.ts` / `*.spec.ts` (and `.tsx`) files on disk. Shell tests are not scanned. The stage warns, and it fails only when `PAIRING_STRICT=1`.

Why: A diff grep would miss a committed test and would pile onto the misbehavior diff scan. The request says that if a no-diff-grep decision conflicts, the check should scan test files only. There was no written decision, so the file scan is the conservative choice.

## 2026-11-13: Devcontainer guidance is a document, not a template

Context: The working agreements should say that tools and MCP servers cost context on every turn, and should point at a sandboxed devcontainer. The devcontainer part is docs only.

Options: add a `devcontainer.json` with guessed security fields; write a short doc and name no fields that were not checked.

Choice: `docs/sandboxed-devcontainer.md` states the operational rules in prose. Specific `devcontainer.json` fields are marked needs verification. `base/CLAUDE.md` points at that file. Generated projects copy `CLAUDE.md`, so the pointer names the kit path rather than a file inside the new project.

Why: Inventing spec fields would present an unverified template as a boundary.

## 2026-11-14: Misbehavior check reads changed working-tree files, not diff text (D2)

Context: The earlier misbehavior check grepped added lines of `git diff` for skip markers. That misses a marker already present in a changed file and ties the result to diff formatting. It also created a temp file in the repo root, which then counted as a change. This supersedes the diff-grep description of `scripts/misbehavior-check.sh`; the 2026-11-13 entry on the assertion scan is unchanged.

Options: keep the diff grep; read the content of changed files.

Choice: The changed set is `git ls-files -m -o --exclude-standard` plus `git diff --cached --name-only`. Paths that no longer exist are skipped for content checks. The skip-marker scan reads the content of changed test files and `*.json` / `*.config.*` files. A marker already present in a changed file is reported (restrictive reading). Temp files come from `mktemp`. `scripts/assertion-check.sh` and `scripts/review-call.sh` are validation gate files. Deleted gate files are still reported.

Why: Content of the files as they are on disk is what the tests run. Edits committed and unchanged in the working tree are not seen; that is accepted.

## 2026-11-14: Devcontainer pointer names the kit repository

Context: Generated projects copy `CLAUDE.md`, which pointed at `docs/sandboxed-devcontainer.md`, a file that does not exist in the generated project. This supersedes only the pointer wording in the 2026-11-13 devcontainer entry; the docs-only choice there is unchanged.

Options: copy the doc into each generated project; reword the pointer to say the file is in the pairing kit repository.

Choice: Reword. A smoke check fails when a backticked `docs/` path is neither present in the project nor preceded by "pairing kit repository".

Why: Rewording avoids copying a doc into every project and is checked by a test. Copying remains an option later.

## 2026-11-14: Review scripts fail closed and send tracked changes only

Context: `cross-review.sh`/`.ps1` ran `git add --intent-to-add --all`, so an untracked `.env` or key file went into the diff sent to a third-party model. A missing gitleaks only warned and sent anyway (`REQUIRE_SECRET_SCAN=1` was opt-in; the .ps1 had no opt-in). Found and fixed in toolcost (commit `33a7524`); this upstreams it. It supersedes the 2026-11-13 secret-scan behavior of "warn and send when gitleaks is missing" for the review scripts only.

Options: keep warn-and-send with an opt-in refusal; refuse by default but keep sending untracked files; refuse by default, send tracked changes only, and require `--include` for untracked files.

Choice: The third. A missing or failing gitleaks refuses the review (exit 1, nothing sent). The index is not touched. `--include PATH` (`-Include` in the .ps1) names an untracked file; a deny list (`.env*`, key and certificate files, `*credential*`, `.netrc`, `.npmrc`, `.pypirc`, `.aws/`, `.ssh/`, `.gnupg/`, terraform state and vars) is excluded from the diff and refused for `--include` with exit 2, as are symlinks, directories and paths outside the repo. `REQUIRE_SECRET_SCAN` no longer matters for the review scripts; `scripts/check.sh` still uses it for its staged-additions scan, which keeps warn-by-default. `tests/test-cross-review.sh` (stub loopback API, fake gitleaks) replaces toolcost's Go test and compares the .sh and .ps1 deny lists as text.

Why: A secret leak cannot be undone and the cost of installing gitleaks is small. The .ps1 was first checked only by the deny-list text comparison; running it under pwsh then showed it did not parse (a `$f:` scope error in a refusal message), which was fixed. `tests/test-cross-review.sh` now parses it and runs the `-Include .env` and no-gitleaks refusals under pwsh when pwsh is installed (skipped otherwise). Nothing else in the .ps1 is exercised.

## 2026-11-14: Python assertion scan ends a test by indentation, not by any def

Context: `scripts/assertion-check.sh` reset the current test at any indented `def`, so a helper defined inside a test body (`def gh(...)`) flushed the test as unasserted before its later assertions. Two real repos got false warnings.

Options: keep the reset and special-case known helper names; track test-level indentation; parse Python properly.

Choice: A test starts at `def test_` and ends at the next non-blank line indented the same or less. Nested defs and classes do not end it. Triple-quoted strings, comment-only lines and lines starting with a closing bracket are not dedents. An assert inside a nested helper counts toward the enclosing test, even if the helper is never called (accepted gap; the check stays a cheap heuristic). Go (`func` at column 0 only) and TS/JS (whole-file check) were already unaffected.

Why: Indentation is what Python itself uses, it needs no new dependency, and it removes the false positive without hiding tests that have no assertion.

## 2026-11-17: Skill lint checks kit skills only, 6 KiB cap

Context: the kit ships four skills (`profiles/*/skills/*.md`) that agents load whole into context. Nothing checked their shape. NVIDIA SkillEvaluator evaluates skills in tiers; the kit takes only the cheap structural tier (a claim from TLDR IT 2026-11-17, not something this decision depends on).

Options: no lint; structural lint in bash; lint plus model or live-agent checks.

Choice: `scripts/skill-lint.sh`, bash and standard tools only. Rules: exactly one H1 outside code fences, a "Load before ..." / "Read when ..." / "Use this when" line within the first 10 non-blank lines after the H1, at most 6144 bytes, no heading text repeated across two skills of one profile, and a `scan-error` for anything it could not read. Warn by default, fail under `PAIRING_STRICT=1`. `check.sh` runs it as a `skills` stage only when `profiles/` exists; CI runs it strict. Installed copies in generated projects are not checked and the script is not copied into projects.

Why: The largest skill is 4537 bytes (`profiles/go/skills/go-network-service.md`); 6144 leaves about 35% headroom and still catches a skill that doubles. Bytes track context cost better than lines. Implemented on the stated default (warn, strict fails) pending owner confirmation of the cap and of checking installed copies. The kit's own `scripts/check.sh` still exits 2 (no `.pairing-profiles` at the kit root); that is a separate owner question.

## 2026-11-20: 7-day Dependabot cooldown

Context: TLDR InfoSec 2026-11-18/19 reported a compromised release from an official publisher and a trusted-publishing compromise (opensourcemalware, stepsecurity); Chainguard advertises a cooldown. Those are the sources' claims; the decision does not depend on them. Provenance is not safety: a new release from a trusted source can still be malicious.

Options: no cooldown (Dependabot already applies a 3-day default to version updates, per the GitHub Dependabot options reference); 7 days; longer for major versions.

Choice: Dependabot cooldown of `default-days: 7` on the `github-actions` entry in `.github/dependabot.yml`. Implemented on the stated 7-day default, pending owner confirmation. Only `default-days` is set: the options reference shows the `github-actions` row supports default days but not the semver-bump keys, so no `semver-*-days`. The cooldown applies to version updates only; security updates are not delayed (same page). Read on docs.github.com on 2026-11-21; the last 86k characters of that page were not read, and nothing local proves Dependabot accepts the file (GitHub validates it on push).

Why: A week lets the community catch a bad release before a pull request is opened, at the cost of updates arriving about a week later. The only ecosystem here is GitHub Actions, which are pinned by version tag, not by commit SHA.
