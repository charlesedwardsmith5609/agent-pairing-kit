### Go (`{{DIR}}`)

- Standard library only. `go.mod` must not gain requirements without approval.
- Skill: read `skills/go-network-service.md` before writing server code.
- Shared state has one owner goroutine or one mutex, never both. Name it in every plan.
- Network tests use a real listener on `127.0.0.1:0` and `net.Dial`, with a deadline on every read.
- Check stages: gofmt, go vet, govulncheck (known vulnerabilities), `go test -race -count=1`.
- If govulncheck reports a vulnerability, stop and report it with the affected call path; do not
  upgrade or replace modules without approval.
