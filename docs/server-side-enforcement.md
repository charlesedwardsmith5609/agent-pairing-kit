# Server-side enforcement

Written rules are requests. `base/CLAUDE.md` tells the agent to wait for plan approval and to stop
after the approved step; nothing in a clone stops an agent that ignores it. A rule holds only when
the repository host refuses the action. One practitioner report (itsmeduncan.com, 2026-11-17, "Only
the human merges") describes an agent merging despite a written "never merge" rule, then the rule
being moved into a server-side permission. That is a single report, not evidence; this note does
not depend on it.

## What the repository host must enforce

Names below are GitHub's. Other hosts have equivalents (not verified here). Setting labels marked
(docs) were read on docs.github.com, "About protected branches"; the others are paraphrased and
the exact UI label was not verified.

- **Branch protection or a ruleset on the default branch (branch protection):**
  - a pull request with an approving review is required before merging (docs: "Require pull request
    reviews before merging");
  - "Dismiss stale pull request approvals when new commits are pushed" (docs);
  - "Require status checks to pass before merging" (docs), naming the jobs in
    `.github/workflows/ci.yml`;
  - force pushes and deletions stay off ("Allow force pushes", "Allow deletions", docs);
  - "Do not allow bypassing the above settings" (docs), so the agent's identity and admins are bound.
- **The agent's token** has no merge and no administration rights. Use a fine-grained token or
  app limited to pushing its own branches (or to a fork), and no permission to bypass rules.
  Whether a given token can push without being able to merge depends on the host; check it by
  trying the merge as the agent.
- **CODEOWNERS** for the files that define the rules, with code owner review required (docs:
  "require reviews from code owners"). For a generated project: `CLAUDE.md`, `AGENTS.md`,
  `skills/`, `scripts/`, `.claude/`, `.cursor/`, `.pairing-profiles`, `.github/`. For the kit
  itself: `base/`, `profiles/`, `scripts/`, `claude-settings.json`, `.github/`.

## What the kit can check from a local clone

Each item is a script that exists in the kit:

- Edits to validation gate files, including `.github/workflows/*`, are flagged: warns, fails under
  `PAIRING_STRICT=1` (`scripts/misbehavior-check.sh:64-71`).
- Staged additions are scanned for secrets (`scripts/check.sh:22-85`, `scan_staged_additions`).
- Review text is secret-scanned before it leaves the machine, and a missing or failing scanner
  refuses the review (`scripts/review-call.sh`, `review_gitleaks_scan`).
- The tools and settings the kit depends on are checked for drift, including that gitleaks is
  installed (`kit-audit.sh`).

## What it cannot check

The kit cannot see branch protection or rulesets, token scopes, whether code owner review is
required, whether CI is a required check, or who merged a pull request. Those live on the host, not
in a clone. No script in `scripts/` or `kit-audit.sh` calls the GitHub API. Reading them with
`gh api` would need an admin token, which the kit does not use.
The kit also cannot tell whether a `.github/CODEOWNERS` file is enforced; it does not even check
that the file exists (open question: a one-time reminder in `scripts/check.sh` when it is absent;
not built).

## Client-side complement

Claude Code `permissions.deny` can block commands such as `gh pr merge` for the local agent. That is
still client-side, so it is a convenience, not enforcement. `claude-settings.json` does not add
them yet (open question).
