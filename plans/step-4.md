# Step 4: skill lint (branch improve/tldr-2026-11-17)

Source: owner brief "improve/tldr-2026-11-17: skill lint". Run unattended: no human answers
questions during this pass, so every design choice below is a recommendation, listed again under
Open questions. Reason given in the brief: NVIDIA SkillEvaluator does multi-tier skill
evaluation (https://github.com/NVIDIA/SkillEvaluator, TLDR IT 2026-11-17); the kit takes only
the cheap structural tier. That is the brief's claim; this plan does not depend on it.

## Repo state this plan was written against

- Branch cut from `origin/main` at `8b66c80`. `cursor/add-ci-secret-scan-license` (`d47bfe9`) is
  patch-equivalent to a commit already on `origin/main` (`git cherry origin/main` prints
  `- d47bfe9`), so nothing from it is carried. `improve/tldr-2026-11-17` did not exist locally or
  on `origin`.
- Skills, measured with `wc -c` / `wc -l`:
  - `profiles/go/skills/go-network-service.md`: 4537 bytes, 87 lines (largest)
  - `profiles/expo/skills/expo-mobile.md`: 3064 bytes, 56 lines
  - `profiles/python/skills/python-service.md`: 2925 bytes, 58 lines
  - `profiles/web/skills/web-frontend.md`: 2411 bytes, 53 lines
- Each has one H1 on line 1 and a "Load before ..." sentence on line 3 (for example
  `profiles/go/skills/go-network-service.md:3`). None contains a code fence. Each profile has
  exactly one skill file, so the cross-skill duplicate-heading rule cannot fire on the current tree
  (it guards future second skills); only a fixture exercises it.
- `scripts/check.sh:10-11` exits 2 when `.pairing-profiles` is missing. The kit root has no
  `.pairing-profiles`, so `bash scripts/check.sh` in the kit itself prints
  `check: .../.pairing-profiles not found` and exits 2 (run on this branch). `check.sh` is a
  template copied into generated projects (`new-project.sh:128`). The kit's real gate is the
  command list in `CONTRIBUTING.md` (shellcheck plus `tests/test-*.sh`), which CI runs
  (`.github/workflows/ci.yml`).
- Generated projects get skills flattened into `skills/` next to `review-checklist.md` and
  `plan-review-checklist.md` (`new-project.sh:113-123`); there is no `profiles/` dir there.

## Requirements for this step (implementer appends them to REQUIREMENTS.md, section "Skill lint 2026-11-17")

- S1. `scripts/skill-lint.sh [ROOT]` checks every `ROOT/profiles/*/skills/*.md`:
  exactly one H1; a when-to-read line; a byte-size cap; no heading text repeated across two skill
  files of the same profile.
- S2. Findings warn (exit 0); under `PAIRING_STRICT=1` the same findings fail (exit 1).
  An unusable ROOT exits 2.
- S3. `scripts/check.sh` runs it as a stage named `skills` and reports it in the summary.
- S4. No semantic or model checks, no live agent test, no new dependencies (bash, grep, awk, wc).
- S5. Installed copies in generated projects (`skills/*.md`) are NOT checked in this step.

## Design

### scripts/skill-lint.sh (new)

- `set -uo pipefail`; `root="${1:-.}"`; `cd "$root" || exit 2`. Same strict/label pattern as
  `scripts/misbehavior-check.sh:17-26`: label `WARN`, or `FAIL` when `PAIRING_STRICT=1`.
- Output lines: `skill-lint: WARN: <relative path>: <rule>: <detail>`. At the end either
  `skill-lint: OK (N skill files)` or `skill-lint: N finding(s)`.
  `check.sh`'s `helper_stage` labels a stage WARN when exit is 0 and output contains `WARN`
  (`scripts/check.sh:110`), so this format gives WARN / FAIL / PASS with no change to
  `helper_stage`.
- No skill files found: print `skill-lint: no profiles/*/skills/*.md under ROOT; nothing checked`
  and exit 0 (not a finding; generated projects have no `profiles/`).
- File list: `shopt -s nullglob`; `profiles/*/skills/*.md`, sorted. Paths are relative to ROOT.
- Parsing per file (one awk pass): track fenced code blocks the CommonMark way: an opening fence
  is 3+ backticks or 3+ tildes (up to 3 leading spaces); it closes only on a line of the same
  character with at least the opening length and nothing else after it. A tilde line inside a
  backtick fence (or a shorter fence) does not close it. Lines inside a fence are not headings. ATX headings only
  (`^#{1,6} `). Setext headings are not recognized (none exist; noted as an accepted gap).
- Rules:
  1. `title`: count of H1 lines (`^# `) outside fences must be exactly 1. Zero: "no H1 title".
     Two or more: "N H1 titles (lines a, b)".
  2. `when-to-read`: within the first 10 non-blank lines after the H1, one line that matches
     (case-insensitive, extended regex) `^(load|read)( this| it)? (before|when|first)` or
     `^use (this|it) when`. All four current skills match through "Load before". Missing:
     "no when-to-read line (start a line near the top with 'Load before ...' or 'Read when ...')".
     If there is no H1, the window is the first 10 non-blank lines of the file.
  3. `size`: `wc -c < file` greater than the cap. Cap: 6144 bytes (6 KiB). Why: the largest skill
     is 4537 bytes; 6144 leaves about 35% room (one more section of the current kind, the go
     skill's sections are 400-900 bytes) while still catching a skill that doubles. Bytes, not
     lines, because a skill is loaded into context whole and bytes track tokens better than
     line counts with variable wrap. The cap is a named constant at the top of the script
     (`max_bytes=6144`), not an environment knob (none was asked for; fixtures exceed it).
  4. `duplicate-heading`: per profile directory, normalize each heading's text (drop the leading
     `#`s, a leading section number like `3.` or `3)`, trailing `#`s, collapse whitespace,
     lowercase) and report each normalized text that appears in two or more different skill
     files of that profile, naming every file and line. Repeats inside one file are not reported
     (not asked). Headings of all levels H1-H6 are compared. Example caught: `## 6. Testing` in one
     skill and `## 5. Testing` in another.
- Scan errors (from plan review): a `profiles/*/skills/` directory that exists but cannot be
  listed or read, a skill file that is not readable, or a non-zero exit from `awk`/`wc` on a file
  is a named finding `scan-error: <path>: <reason>` (WARN by default, FAIL under strict), so
  strict CI cannot pass without having read every skill. Each command's status is checked
  explicitly (no reliance on `set -e`).
- Exit: 2 on bad root; 1 when findings and strict; else 0. Temp files, if any, come from
  `mktemp` with an EXIT trap (prefer none: awk reads files directly).

### scripts/check.sh

- Add after `helper_stage assertions assertion-check.sh` (`scripts/check.sh:120`):
  `if [ -d "$root/profiles" ]; then helper_stage skills skill-lint.sh; fi`.
  The guard keeps generated projects (no `profiles/`, no copied `skill-lint.sh`) exactly as now:
  no new stage and no "missing helper" warning from `helper_stage` (`scripts/check.sh:94-101`).
  A directory with `profiles/` but no `scripts/skill-lint.sh` gets the existing named
  missing-helper WARN, which is correct.
- Update the header comment (lines 1-7) to name the stage. No other behavior change; the
  `.pairing-profiles` exit 2 stays (see open question Q2).
- `skill-lint.sh` is NOT added to the copy list in `new-project.sh:25` or `:128` (S5).

### CI and docs

- `.github/workflows/ci.yml` unit job: add steps `bash tests/test-skill-lint.sh` and
  `bash scripts/skill-lint.sh .` with `PAIRING_STRICT=1` (so a skill that breaks a rule fails CI
  in the kit; the kit has no runnable `check.sh`, so CI is where the lint actually guards the kit).
  Recommendation, see Q3.
- `CONTRIBUTING.md` and `README.md`: list `tests/test-skill-lint.sh` (enforced by
  `tests/test-docs.sh:19-23`) and `bash scripts/skill-lint.sh .`; README kit-layout `scripts/` row
  says `skill-lint.sh` is kit-only, not copied into projects; README `check.sh` row names the
  `skills` stage (only when `profiles/` exists).
- `CHANGELOG.md` `### Added` entry. `DECISIONS.md` dated entry "2026-11-17: Skill lint checks
  kit skills only, 6 KiB cap" with the cap measurement and the S5 deferral.

## Ownership

No shared state. Each run reads files under ROOT and writes only stdout. The owner owns the cap
value and the scope question (Q1, Q2).

## Test list (natural language; written failing first)

`tests/test-skill-lint.sh`, same style as `tests/test-check-summary.sh` (`mktemp -d` work dir,
EXIT trap, `ok`/`FAIL` lines, final exit = fail flag). Each fixture is a scratch ROOT with
`profiles/<p>/skills/*.md` written by `printf` in the test (no committed fixture files, nothing
secret-shaped).

1. Clean fixture (one H1, "Load before ..." line, small, two skills in one profile with distinct
   headings): exit 0, output has `skill-lint: OK`, no `WARN`.
2. Missing title (no `# ` line): exit 0, output names the file and `title`.
3. Two titles: exit 0, output names `title` and both line numbers.
4. A `# comment` line inside a fenced block does not count as a second title (guards the fence
   rule; fails if fences are ignored).
4b. Mixed fences: a `~~~` line inside a backtick fence does not close it (a following `# x`
   inside the block is not a title); a four-backtick fence containing a three-backtick line stays
   open until the four-backtick close.
4c. Scan error: a skill file with mode 000 (skipped with a note when the test runs as root,
    because root can read it) is reported `scan-error`; under strict exit 1.
5. No when-to-read line: output names `when-to-read`.
6. Oversize: a file of 6145 bytes (H1 + when line + padding) is reported `size`; a file of
   exactly 6144 bytes is not (boundary).
7. Duplicate heading: `## 2. Testing` in skill A and `## 5. testing` in skill B of one profile:
   `duplicate-heading` naming both files. The same heading in two different profiles: not
   reported.
8. Strict: `PAIRING_STRICT=1` on each failing fixture above gives exit 1 and `FAIL`; on the clean
   fixture exit 0.
9. Bad root (nonexistent dir): exit 2.
10. No skills under ROOT: exit 0 with "nothing checked".
11. Real kit skills: `bash scripts/skill-lint.sh "$kit"` with `PAIRING_STRICT=1` exits 0
    (the four existing skills pass; measured above).
12. check.sh reports the stage: scratch project as in `tests/test-check-summary.sh:14-21` plus
    `scripts/skill-lint.sh` and a `profiles/x/skills/a.md`; clean gives `^  skills: PASS$`; a
    skill with no H1 gives `^  skills: WARN$` and CHECK PASSED; with `PAIRING_STRICT=1`
    `^  skills: FAIL$`, CHECK FAILED, exit 1.
13. A scratch project without `profiles/` shows no `skills:` line in the summary (generated
    projects unchanged).

Tests 1-13 (with 4b, 4c) are written first and must fail (script absent) before `skill-lint.sh` exists.
`tests/test-docs.sh` then fails until README and CONTRIBUTING list the new test.

## Gate (what "done" means)

- `git ls-files -z '*.sh' | xargs -0 shellcheck -x` clean (includes the new script and test).
- Every `tests/test-*.sh` passes, including `tests/test-skill-lint.sh` and
  `tests/test-docs.sh`; `bash tests/smoke-new-project.sh python` passes (proves generated
  projects unchanged).
- `PAIRING_STRICT=1 bash scripts/skill-lint.sh .` exits 0 on the kit.
- `bash scripts/check.sh` in the kit: NOT RUNNABLE (exits 2, no `.pairing-profiles`); report it as
  NOT RUN with that reason unless the owner accepts Q2. Test 12 covers the stage through a
  scratch project.
- `bash scripts/cross-review.sh` on the item commit, findings assessed.

## Build vs note-only (unattended policy)

- Build (stated default "warn by default; fail under PAIRING_STRICT=1"; flag as "implemented on
  the stated default, pending owner confirmation"): `scripts/skill-lint.sh`, the `check.sh` stage,
  tests, CI steps, docs, CHANGELOG, DECISIONS, REQUIREMENTS section. One commit.
- Note only: checking installed copies in generated projects (Q1); adding a kit-root
  `.pairing-profiles` (Q2).

## Open questions for the owner (with recommendation)

- Q1. Size cap value. Recommend 6144 bytes (largest today 4537). Alternative: 5000 bytes (tighter,
  about 10% headroom, will fire on the next go-skill addition).
- Q2. The kit's own `bash scripts/check.sh` exits 2 (no `.pairing-profiles` at the kit root), so
  the brief's gate cannot run here. Recommend committing an empty `.pairing-profiles` at the kit
  root in a separate, approved step so `check.sh` runs the secret-scan, misbehavior, assertions
  and skills stages on the kit. Not built in this step.
- Q3. Should CI run the lint strict (`PAIRING_STRICT=1`)? Recommend yes: the kit's skills pass
  today and CI is the only place the lint runs on the kit. If not, CI runs it warn-only.
- Q4. Should profile-installed copies in target projects (`skills/*.md`) be checked too? Recommend
  not yet: they sit next to `review-checklist.md` and `plan-review-checklist.md`, which have no
  "Load before" line and would need an exclusion list; and `skill-lint.sh` would have to be
  copied and backfilled. Not built.
- Q5. When-to-read pattern: recommend the regex above (Load/Read ... before/when/first, Use this
  when). A stricter rule ("line 3 must start with 'Load before'") is simpler but brittle.

## Plan review (cross-model, OpenAI gpt-6.1-sol, 2026-11-21)

Run through `scripts/plan-review.sh` in a scratch copy laid out like a generated project (the kit
root has no `CLAUDE.md` or `skills/plan-review-checklist.md`, which `plan-review.sh:54,73` need;
`base/CLAUDE.md` and `base/plan-review-checklist.md` were used, and the S1-S5 requirements were
appended to the scratch `REQUIREMENTS.md`). Findings:
- MEDIUM MISSING: unreadable skills dir/file or awk/wc failure could pass silently, so strict CI
  might pass without checking. AGREE: added the `scan-error` rule and test 4c.
- MEDIUM WRONG: toggling fences on any triple backtick/tilde line mishandles mixed or longer
  fences. AGREE: fence tracking now matches character and length; test 4b added.
No disagreements.

## Suggestions (not in this step)

- Make `scripts/skill-lint.sh` a validation gate file in `misbehavior-check.sh` once it is
  copied into projects (only relevant if Q4 is accepted).

## Files

- scripts/skill-lint.sh
- scripts/check.sh
- tests/test-skill-lint.sh
- .github/workflows/ci.yml
- README.md
- CONTRIBUTING.md
- CHANGELOG.md
- DECISIONS.md
- REQUIREMENTS.md
- plans/step-4.md
