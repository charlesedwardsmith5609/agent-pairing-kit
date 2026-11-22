# agent-pairing-kit

A lightweight, single-developer profile of `platform-agent-harness` for pairing with an AI coding
agent. It keeps the parts of the harness that matter when one engineer is directing one agent:
working agreements that keep design decisions with the human, a validation gate, and
competing-model review. It drops the GitHub issue flow and the coordinator/worker split.

## Quick start (WSL)

```bash
newproj my-service                    # Go service (default)
newproj my-tool python                # Python service
newproj my-site web                   # TypeScript + Vite frontend
newproj my-app fullstack              # Go API in api/ + frontend in web/
newproj my-app fullstack python       # Python API in api/ + frontend in web/
newproj my-phone-app expo             # Expo (React Native + TypeScript) mobile app
```

Then in Cursor's terminal: `claude`, `/ide`, `/mcp` (leave only the IDE server on), `/status`.

## Profiles

| Profile | Toolchain installed | Check stages | Skill |
|---|---|---|---|
| `go` | `go mod init` | gofmt, go vet, govulncheck, `go test -race` | `go-network-service.md` |
| `python` | `.venv` with pytest, ruff, mypy; stdlib-only app code | ruff check, ruff format, mypy, pytest | `python-service.md` |
| `web` | npm dev deps: typescript, vite, vitest, jsdom, prettier | prettier, unsafe DOM sinks, tsc, vitest | `web-frontend.md` |
| `fullstack` | backend in `api/` + web in `web/`; Vite proxies `/api` to `localhost:8080` | both, summarized per language | both |
| `expo` | Expo app with Expo Router, zustand, AsyncStorage, expo-audio, expo-speech and a few more Expo packages; dev deps vitest, prettier | prettier, hard-coded UI text, tsc, content validator (if present), vitest | `expo-mobile.md` |

Prerequisites are checked before anything is created: Go (plus gcc for `-race` and
`govulncheck`, installed with `go install golang.org/x/vuln/cmd/govulncheck@latest`), python3 with
`python3-venv`, or Node.js 20+ (web and expo).

## What a new project gets

| Path | Purpose |
|---|---|
| `CLAUDE.md` / `AGENTS.md` | Base working agreements plus one section per language in the project (identical copies) |
| `.cursor/rules/pairing-mode.mdc` | Makes Cursor apply the same agreements |
| `skills/*.md` | The skill for each language, plus `review-checklist.md` (code review) and `plan-review-checklist.md` (plan review), each combining base and language-specific review focus |
| `scripts/check.sh` | The validation gate. Stages, in order: a secret scan of staged additions (shown in the summary only when it fails), `misbehavior`, `assertions`, then each language in `.pairing-profiles` (its script is `scripts/checks/<profile>.sh`). The summary labels each stage PASS, WARN or FAIL; exit 0 if nothing failed, 1 otherwise, 2 if `.pairing-profiles` is missing. `PAIRING_STRICT=1` turns warnings from the secret scan, `misbehavior` and `assertions` (and a missing helper script) into failures. `REQUIRE_SECRET_SCAN=1` makes the gate fail when the staged-additions scan cannot run (no gitleaks, or the scanner or `git diff` failed) |
| `scripts/misbehavior-check.sh` | Deterministic checks over changed working-tree files (modified, untracked and staged), not diff text: skipped tests, edits to validation gate files, test-only changes, and (when the latest `plans/step-*.md` has a `## Files` list) paths outside the approved step. Warns; `PAIRING_STRICT=1` fails |
| `scripts/skill-lint.sh` | Kit-only (not copied into projects): checks `profiles/*/skills/*.md` for exactly one H1, a "Load before ..." style line near the top, a 6144-byte cap and no heading repeated across skills of one profile. Warns; `PAIRING_STRICT=1` fails. `check.sh` runs it as a `skills` stage only when `profiles/` exists; CI runs it strict. Installed copies in projects are not checked |
| `scripts/assertion-check.sh` | Scans test files on disk (skipping `.git`, virtualenvs, `node_modules`, `vendor` and build directories) and warns on tests with no assertion. `PAIRING_STRICT=1` fails, including on paths it could not scan. Exits 2 on an unusable root or bash older than 4.4 |
| `scripts/review-call.sh` | Shared by both reviews: sends the request to Cursor, OpenAI or Anthropic |
| `scripts/plan-review.sh` | Sends a plan in `plans/step-N.md`, plus `REQUIREMENTS.md`, the agreements and earlier plans, to a second AI provider before any code exists |
| `scripts/cross-review.sh` / `.ps1` | Sends the tracked diff (minus `go.sum`, `package-lock.json` and deny-listed files) to a second AI provider; saves to `.reviews/`. The `.ps1` supports only the openai and anthropic providers |
| `.claude/commands/` | `/check`, `/plan-review` and `/cross-review` |
| `.pairing-profiles` | One `profile dir` line per language; `scripts/check.sh` reads it |
| `.gitignore`, `.gitattributes` | Ignore rules for the profiles in the project (including `.reviews/` and `.claude/settings.local.json`), and line-ending rules |
| `.claude/settings.json` | Turns off claude.ai connectors and artifacts; asks before `WebFetch`; denies reads of `.env`, `//proc/**/environ`, k8s secrets, and cloud-metadata curl/wget |
| `.claude/settings.local.json` | Per-machine, gitignored: switches off every plugin installed on your account (and their MCP servers) for this project only |
| `.pairing-setup.log` | Tool output from setup (gitignored) |

## Kit layout

| Path | Purpose |
|---|---|
| `base/` | Language-neutral agreements, reviewer prompt, gitignore |
| `profiles/<lang>/` | `agreements.md`, `review.md`, `check.sh`, `init.sh`, `gitignore`, `skills/` |
| `scripts/` | Check runner and cross-review scripts copied into every project |
| `shell/functions.sh` | `newproj`, `setreviewer`, `setkey`, `keystatus`, `kitaudit`, `kitsync`. Source it from `~/.bashrc` |
| `kit-audit.sh` | What `kitaudit` runs: checks the tools and settings the kit depends on for drift. It is not copied into projects |
| `audits/` | Monthly audit reports from the scheduled research task (empty until the first one is saved) |
| `new-project.sh` | What `newproj` calls: `bash new-project.sh PATH [profile ...]` |
| `tests/test-*.sh` | Unit tests: `tests/test-assertion-check.sh`, `tests/test-check-summary.sh` (summary labels and `new-project.sh --backfill`), `tests/test-cross-review.sh` (cross-review fails closed, with a stub API and fake gitleaks; also parses and runs the refusal paths of the `.ps1` under `pwsh` when it is installed), `tests/test-docs.sh`, `tests/test-misbehavior-check.sh`, `tests/test-skill-lint.sh` (skill lint rules and the `skills` stage), `tests/test-secret-scan.sh`, `tests/test-staged-secret-scan.sh` |
| `tests/smoke-new-project.sh` | Creates a project in a temp dir, asserts the files it must get, runs its check, and checks that `--backfill` changes nothing. CI runs it for `go`, `python`, `web` and `fullstack` (not `expo`) |
| `.github/workflows/ci.yml` | Three jobs: shellcheck on every tracked `*.sh`, the unit tests above (every `tests/test-*.sh`), and the smoke run. Dependabot updates the GitHub Actions versions |
| `legacy-windows/` | The original Go-only PowerShell setup and check, kept for reference |

To add a language, create `profiles/<lang>/` with the same pieces (`agreements.md`, `review.md`, `check.sh`, `init.sh`, `gitignore`, `skills/`) and add it to the profile
list in `new-project.sh`.

## Reviewers and keys

Plan and code reviews go to a model from a different provider than your coding agent. Choose one:

- **Cursor (uses your Cursor plan, no API key).** Install Cursor's CLI and sign in once, then
  pick a model that isn't Claude:
  ```bash
  curl https://cursor.com/install -fsS | bash
  NO_OPEN_BROWSER=1 agent login
  setreviewer cursor            # lists your models and asks which one to use
  ```
  Reviews then run `agent -p --mode=ask`, which is read-only. Each review counts against your
  Cursor plan's usage.
- **OpenAI API key.** `setkey` prompts for the key without echoing it, verifies it against the
  review model, and saves it. `setreviewer openai` switches back to it.

If Cursor is the reviewer and a Cursor review fails (signed out, usage used up), the review falls
back to your OpenAI key when one is saved. `--provider` on either review script picks one for a
single run and skips the fallback.

**Secret scan.** Both reviews send text to a third-party model, so before sending, the request
(the diff, or the plan plus `REQUIREMENTS.md`, the agreements and earlier plans) is scanned with
[gitleaks](https://github.com/gitleaks/gitleaks). A finding refuses the review, prints the
redacted match, and sends nothing. The review scripts fail closed: if gitleaks is missing or
fails, nothing is sent, and `kitaudit` warns about it. `REQUIRE_SECRET_SCAN` no longer affects the
review scripts; it only makes `scripts/check.sh` fail when its staged-additions scan can't run.
Install it once (for example
`brew install gitleaks`, or a release binary from its GitHub page). The scan covers only the text
the scripts build. With Cursor as the reviewer, the agent may also read other files in the
repository, which the scan doesn't see.

Settings live in `~/.config/pairing-kit.env`, and every change keeps the previous file as `.prev`.
`keystatus` shows the active reviewer and checks it, showing only the last four characters of a
key. Leave `ANTHROPIC_API_KEY` unset so Claude Code uses your subscription login.

## Keeping the kit current

AI tools change quickly, so the kit checks itself in two layers:

- **`kitaudit`** (seconds, no AI). It compares installed versions with the latest releases of
  Claude Code, Go, govulncheck, Node and the Expo SDK. It also checks that your saved review
  models still exist and that the Cursor CLI flags the reviews use are still in its help text.
  `newproj` runs it quietly once a week and prints only warnings.
- **Monthly audit** (a scheduled task). It reads this repo, researches what changed in Claude
  Code, Cursor, the review models and the toolchains, and writes a ranked report to
  `audits/YYYY-MM.md`: fix now, worth adopting, watch. It never changes the kit itself; you decide
  what to act on.

The kit lives in a public GitHub repo (MIT licensed, see `LICENSE`), and
`E:\Code\agent-pairing-kit` is a clone of it. Don't commit anything private to it.
`kitsync` (and so `newproj`) pulls before copying, so changes pushed to GitHub arrive on their own.

## Workflow

1. **Clarify** requirements and write down your defaults.
2. **Scaffold** boilerplate in one ask.
3. Claude writes the agreed requirements to `REQUIREMENTS.md`, then a **plan** for each step to
   `plans/step-N.md`, **runs the plan review**, and presents the plan with the reviewer's findings.
   Approve or change it. The plan's test list is natural language you agree before any code.
4. **Tests first.** Write those tests so they fail, then implement until they pass. Scaffold
   (step 2) skips this.
5. **Review the diff** before keeping it. Reject anything from the skill's "reject on sight" list
   and record why.
6. **Run the check.** Green means commit, so you can roll back cleanly.
7. At milestones, **run the cross-model review** and decide which findings to act on. A
   reasoned rejection of a finding is as valuable as accepting one.

## Notes

- Needs bash 4.4+ (the assertion scan exits 2 on older bash, which fails `scripts/check.sh`; this applies to generated projects too). On macOS install a newer bash.
- **Refreshing helpers in an existing project.** `bash <kit>/new-project.sh --backfill PATH` copies
  only the helper scripts the project lacks (`check.sh`, `misbehavior-check.sh`,
  `assertion-check.sh`, `plan-review.sh`, `cross-review.sh`, `review-call.sh`, `cross-review.ps1`)
  and never overwrites a file; it exits 2 if PATH has no `.pairing-profiles`. `scripts/check.sh`
  warns about a missing helper until then. It does not update helpers that already exist. To pick
  up a newer version of one, copy it over from the kit yourself (for example
  `cp <kit>/scripts/review-call.sh PATH/scripts/`), then review the diff. The check scripts in
  `scripts/checks/`, `skills/`, `CLAUDE.md` and `.claude/` are not refreshed by either route.
  Copying over a validation gate file shows up in the project's `misbehavior` stage as an edit.
- Validation gate files (editing one is reported by `misbehavior-check.sh`): `scripts/check.sh`,
  `scripts/misbehavior-check.sh`, `scripts/assertion-check.sh`, `scripts/review-call.sh`,
  `.pairing-profiles`, `scripts/checks/*` and `.github/workflows/*`.
- `cross-review` sends tracked changes only and does not touch the index. An untracked file is
  sent only when named with `--include PATH` (`-Include` in the .ps1). These paths are excluded
  from the diff and refused for `--include` (exit 2): `.env*`; `*.pem`, `*.key`, `*.p12`, `*.pfx`,
  `*.jks`, `*.keystore`, `*.kdbx`; `id_rsa*`, `id_dsa*`, `id_ecdsa*`, `id_ed25519*`; `*credential*`;
  `.netrc`, `.npmrc`, `.pypirc`, `.git-credentials`; `*.tfstate`, `*.tfvars`; and anything under
  `.aws/`, `.ssh/` or `.gnupg/`. `--include` also refuses symlinks, directories and paths outside
  the repository. The `.sh` and `.ps1` deny lists must match (a test compares them). 
  `plan-review.sh` uses the same fail-closed scan through `review-call.sh`. A refused review
  (finding, no gitleaks, scanner failure) exits 1 and sends nothing.
- `cross-review.ps1` is exercised only for parsing and its two refusal paths (`-Include .env`
  and no gitleaks), under `pwsh` when it is installed; no other `.ps1` behavior is tested.
- CI (`.github/workflows/ci.yml`) has three jobs: shellcheck on every tracked `*.sh`; the unit
  tests (`tests/test-secret-scan.sh`, `tests/test-staged-secret-scan.sh`,
  `tests/test-cross-review.sh`, `tests/test-misbehavior-check.sh`, `tests/test-assertion-check.sh`,
  `tests/test-check-summary.sh`, `tests/test-skill-lint.sh`, `tests/test-docs.sh`); and a smoke run of `new-project.sh` for
  `go`, `python`, `web` and `fullstack`. Run the same locally with
  `git ls-files '*.sh' | xargs shellcheck -x` and `bash tests/smoke-new-project.sh go`.
- `expo` is not in the CI smoke matrix; run `bash tests/smoke-new-project.sh expo` yourself
  (needs Node 20+ and network). Which seeded failures each profile's check catches (Go race,
  mypy and pytest errors, TypeScript error, formatting, `innerHTML`) was not re-verified for this
  documentation pass.
