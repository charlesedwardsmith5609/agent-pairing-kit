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
| `expo` | Expo app with Expo Router, zustand, AsyncStorage, expo-audio, expo-speech; dev deps vitest, prettier | prettier, hard-coded UI text, tsc, content validator (if present), vitest | `expo-mobile.md` |

Prerequisites are checked before anything is created: Go (plus gcc for `-race` and
`govulncheck`, installed with `go install golang.org/x/vuln/cmd/govulncheck@latest`), python3 with
`python3-venv`, or Node.js 20+ (web and expo).

## What a new project gets

| Path | Purpose |
|---|---|
| `CLAUDE.md` / `AGENTS.md` | Base working agreements plus one section per language in the project |
| `.cursor/rules/pairing-mode.mdc` | Makes Cursor apply the same agreements |
| `skills/*.md` | The skill for each language, plus `review-checklist.md` combining base and language-specific review focus |
| `scripts/check.sh` | Runs every language's checks (from `scripts/checks/`) per `.pairing-profiles`, with a summary |
| `scripts/review-call.sh` | Shared by both reviews: sends the request to Cursor, OpenAI or Anthropic |
| `scripts/plan-review.sh` | Sends a plan in `plans/step-N.md`, plus `REQUIREMENTS.md` and the agreements, to a second AI provider before any code exists |
| `scripts/cross-review.sh` / `.ps1` | Sends the current diff (minus lockfiles) to a second AI provider; saves to `.reviews/` |
| `.claude/commands/` | `/check`, `/plan-review` and `/cross-review` |
| `.claude/settings.json` | Turns off claude.ai connectors and the artifacts tool for the project |
| `.claude/settings.local.json` | Per-machine, gitignored: switches off every plugin installed on your account (and their MCP servers) for this project only |
| `.pairing-setup.log` | Tool output from setup (gitignored) |

## Kit layout

| Path | Purpose |
|---|---|
| `base/` | Language-neutral agreements, reviewer prompt, gitignore |
| `profiles/<lang>/` | `agreements.md`, `review.md`, `check.sh`, `init.sh`, `gitignore`, `skills/` |
| `scripts/` | Check runner and cross-review scripts copied into every project |
| `shell/functions.sh` | `newproj`, `setreviewer`, `setkey`, `keystatus`, `kitaudit`, `kitsync`. Source it from `~/.bashrc` |
| `kit-audit.sh` | What `kitaudit` runs: checks the tools and settings the kit depends on for drift |
| `audits/` | Monthly audit reports from the scheduled research task |
| `new-project.sh` | What `newproj` calls: `bash new-project.sh PATH [profile ...]` |
| `legacy-windows/` | The original Go-only PowerShell setup and check, kept for reference |

To add a language, create `profiles/<lang>/` with the same six pieces and add it to the profile
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

The kit lives in a private GitHub repo, and `E:\Code\agent-pairing-kit` is a clone of it.
`kitsync` (and so `newproj`) pulls before copying, so changes pushed to GitHub arrive on their own.

## Workflow

1. **Clarify** requirements and write down your defaults.
2. **Scaffold** boilerplate in one ask.
3. Claude writes the agreed requirements to `REQUIREMENTS.md`, then a **plan** for each step to
   `plans/step-N.md`, **runs the plan review**, and presents the plan with the reviewer's findings.
   Approve or change it.
4. **Review the diff** before keeping it. Reject anything from the skill's "reject on sight" list
   and record why.
5. **Run the check.** Green means commit, so you can roll back cleanly.
6. At milestones, **run the cross-model review** and decide which findings to act on. A
   reasoned rejection of a finding is as valuable as accepting one.

## Notes

- `cross-review` runs `git add --intent-to-add` so new files appear in the diff. This stages no
  content; new files just show as added in `git status`.
- Every profile is tested end to end: project creation, a passing check on the empty project,
  and seeded failures caught (Go race, mypy and pytest errors, TypeScript error, formatting,
  `innerHTML`).
