# Web frontend: safety and structure

Load before writing or reviewing frontend code. General guidance, not a solution to any specific
problem.

## 1. Rendering untrusted data (XSS)

- Anything that came from a user or the server is untrusted. Render it with `textContent`,
  `setAttribute` on safe attributes, or by building elements with `document.createElement`.
- Never pass untrusted strings to `innerHTML`, `outerHTML`, `insertAdjacentHTML`, `document.write`,
  `eval`, `new Function`, or `href`/`src` without checking the URL scheme (`https:` only, never
  `javascript:`).
- If a framework is approved later, its escape hatches (`dangerouslySetInnerHTML`, `v-html`) follow
  the same rule.

## 2. Talking to the server

- One API module owns every `fetch`. It checks `response.ok`, handles network errors, applies a
  timeout with `AbortController`, and validates the JSON shape before the rest of the app sees it.
- Show users a clear error state; never fail silently.
- When requests can overlap (typing, polling, rapid clicks), ignore stale responses: track a request
  id or abort the previous request.
- Validation in the browser is for convenience only. The server validates again.

## 3. Secrets and configuration

- Nothing secret ships to the browser: no API keys, tokens or internal URLs in source or in
  `import.meta.env` values prefixed for client exposure.
- Auth tokens, if any, live in `HttpOnly` cookies set by the server, not in `localStorage`.

## 4. State

- Keep application state in one place and render from it. Event handlers update state, then call
  one render function. This avoids the DOM and the data disagreeing.

## 5. Accessibility basics

- Real `<button>` and `<label>` elements, visible focus, text alternatives for images, and
  sufficient contrast. These are cheap now and expensive later.

## 6. Testing

- vitest with jsdom: render into a container, simulate events, assert on DOM text.
- Mock `fetch` at the API module boundary, and test error and slow-response paths, not just success.
- Include an XSS test: a name like `<img src=x onerror=alert(1)>` must appear as text.

## 7. Agent suggestions to reject on sight

- Adding a UI framework or component library without approval.
- `innerHTML` with any interpolated value.
- Storing tokens in `localStorage`.
- `fetch` without checking `response.ok`.
- Copying server-side validation rules only into the client.
