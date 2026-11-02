- Web: XSS through `innerHTML` or unescaped user content, secrets shipped in the bundle, `fetch`
  calls that ignore non-2xx responses or network failure, stale responses overwriting newer state
  when requests race, validation done only on the client.
