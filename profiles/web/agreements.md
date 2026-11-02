### Web frontend (`{{DIR}}`)

- TypeScript with Vite and plain DOM APIs. No UI framework (React, Vue, etc.) without approval.
- Dev dependencies already installed: typescript, vite, vitest, jsdom, prettier. Add no runtime
  dependencies without approval.
- Never put untrusted data into `innerHTML`, `outerHTML` or `insertAdjacentHTML`; use `textContent`
  or build elements. No secrets or API keys in frontend code.
- All server calls go through one module that checks `response.ok`, handles network failure and
  validates the response shape.
- Skill: read `skills/web-frontend.md` before writing UI code.
- Check stages: prettier, unsafe DOM sinks (no innerHTML and friends in `src/`), tsc --noEmit, vitest.
