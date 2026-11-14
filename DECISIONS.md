# Decisions

## 2026-11-13: Reuse cursor/agent-guardrails by cherry-pick

Context: `origin/cursor/agent-guardrails` (`cf9b5af`) is one commit that main does not contain. Main has later commits that the guardrails branch does not contain. The merge-base is `d916633`.

Options: branch the catch-up work from the old branch and miss later main commits; rebase the old branch; cherry-pick the one commit onto a branch cut from current main.

Choice: `improve/tldr-catchup-2026-11-13` is cut from `origin/main`. The guardrails commit is cherry-picked and conflict-resolved so both the newer secret-scan, test-first, and security-default text and the tool-call policy stay. The old branch is not rewritten.

Why: Reuse the unmerged work without dropping commits that are already on main.

## 2026-11-13: Assertion scan reads test files, not diffs

Context: The catch-up asks for a warn-only check that flags tests with no assertions, and to compare it with a "no diff grep" decision in DECISIONS.md. This repo had no DECISIONS.md before this branch. `scripts/misbehavior-check.sh` already greps added diff lines for skip markers.

Options: flag assertion-free tests by grepping the diff; scan test files on disk.

Choice: `scripts/assertion-check.sh` scans `*_test.go`, `test_*.py`, `*_test.py`, and `*.test.ts` / `*.spec.ts` files on disk. Shell tests are not scanned. The stage warns, and it fails only when `PAIRING_STRICT=1`.

Why: A diff grep would miss a committed test and would pile onto the misbehavior diff scan. The request says that if a no-diff-grep decision conflicts, the check should scan test files only. There was no written decision, so the file scan is the conservative choice.

## 2026-11-13: Devcontainer guidance is a document, not a template

Context: The working agreements should say that tools and MCP servers cost context on every turn, and should point at a sandboxed devcontainer. The devcontainer part is docs only.

Options: add a `devcontainer.json` with guessed security fields; write a short doc and name no fields that were not checked.

Choice: `docs/sandboxed-devcontainer.md` states the operational rules in prose. Specific `devcontainer.json` fields are marked needs verification. `base/CLAUDE.md` points at that file. Generated projects copy `CLAUDE.md`, so the pointer names the kit path rather than a file inside the new project.

Why: Inventing spec fields would present an unverified template as a boundary.
