# Decisions

## 2026-11-13: Reuse cursor/agent-guardrails by cherry-pick

Context: `origin/cursor/agent-guardrails` (`cf9b5af`) is one commit that main does not contain. Main has later commits that the guardrails branch does not contain. The merge-base is `d916633`.

Options: branch the catch-up work from the old branch and miss later main commits; rebase the old branch; cherry-pick the one commit onto a branch cut from current main.

Choice: `improve/tldr-catchup-2026-11-13` is cut from `origin/main`. The guardrails commit is cherry-picked and conflict-resolved so both the newer secret-scan, test-first, and security-default text and the tool-call policy stay. The old branch is not rewritten.

Why: Reuse the unmerged work without dropping commits that are already on main.
