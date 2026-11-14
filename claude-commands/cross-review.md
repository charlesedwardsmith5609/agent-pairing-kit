---
description: Get an independent review of the current diff from a different AI provider
argument-hint: "[--provider cursor|openai|anthropic] [--base REF] [--include PATH]"
---
Run the cross-model review: `bash scripts/cross-review.sh $ARGUMENTS`, with a 10-minute timeout
(a review can take a few minutes). On Windows without WSL, use
`pwsh -NoProfile -File scripts/cross-review.ps1` with `-Provider`, `-Base` and `-Include` instead;
it supports the openai and anthropic providers only.

Only tracked changes are sent. An untracked file is sent only when named with `--include PATH`;
paths on the secret-file deny list (`.env*`, keys, credentials) are refused. If gitleaks is missing
or finds a secret, nothing is sent and the script exits non-zero: report that to the human and do
not work around it.

With no uncommitted changes and no base given, the script reviews the last commit and says so.
If the milestone spans more than one commit, rerun it with a base that covers all of them.

Then, for each finding, give a one-line assessment: AGREE or DISAGREE, with the reason, and the
fix you would make if the human accepts it. Do not change any code. The human decides which
findings to act on.

Judge findings in the context of the whole package, not just the files in the diff. Never infer
whether code builds or tests pass: run `go build ./...` or the check script and report what it
actually says. Label anything you could not verify as unverified.
