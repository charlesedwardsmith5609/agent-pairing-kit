# Review log

## 2026-11-02

Checked: README, review scripts, rules, settings; open `needs-approval` issues (none); current model strings
(`gpt-6.1-sol` OpenAI default, `claude-sonnet-5-5` Anthropic fallback); Claude pricing (claude.com/pricing,
primary: Opus 5.5 $4/$20, Sonnet 5.5 $2/$10, Haiku 5.5 $0.10/$0.50 per MTok, batch -50%, Pro $20/mo);
OpenAI pricing and Cursor plans (secondary sources only).

Applied: nothing. Model strings are current; no drop-in successor verified.

Proposed: nothing opened. Findings were not verifiable against primary sources:
- cursor.com and openai.com are not reachable from the routine sandbox (network allowlist), so claims
  from third-party pages could not be confirmed. Those pages report that Cursor restructured plans around
  2026-10-12 (the $20 Pro plan closed to new buyers, Claude/GPT billed at API rates on top) and that OpenAI
  may wind down its Cursor model contract from 2026-11-12. The owner should check cursor.com/pricing.
- Secondary sources list a cheaper GPT-6.1 Terra ($1/$5 per MTok vs Sol $2/$10) as a possible review model.
  Worth a category B proposal once confirmed on OpenAI's pricing page.
- `audits/` is mentioned in the README but does not exist in the repo.

Next run: allow cursor.com and openai.com in the routine's network settings so these can be verified.
