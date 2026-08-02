# Hermes upstream Nix update

Status: blocked by upstream Nix packaging as of 2026-08-02.

The HP profile currently uses the known-good source:

```text
github:NousResearch/hermes-agent/pull/19766/head
Hermes Agent 0.12.0
commit 758761b03df4ad63652f2a8c97e00f7a8edfc25c
```

The current upstream source was built and tested on HP:

```text
github:NousResearch/hermes-agent
Hermes Agent 0.19.1
commit cd6585abf88df4556cfdcfbc02a240a77ec7ee76
```

The build succeeded, but the Nix output omitted Hermes' own Telegram gateway
adapter. `python-telegram-bot` was installed and `hermes status` reported
Telegram configured, while the gateway logged:

```text
No adapter available for telegram
No adapter could be created for any of the 1 configured platform(s)
```

The profile and user gateway were rolled back to 0.12.0 after this test.

Before retrying:

- [ ] Confirm the new Nix output contains Hermes' Telegram platform adapter.
- [ ] Build the candidate without changing the active profile.
- [ ] Back up `/var/lib/hermes-agent/.hermes` or the pre-cutover equivalent.
- [ ] Replace the profile source and regenerate/restart the gateway service.
- [ ] Confirm the gateway logs show Telegram connecting without adapter errors.
- [ ] Send a Telegram message and verify a response.
- [ ] Confirm cron jobs, dashboard, Workspace API, and Firecrawl MCP still work.
- [ ] Roll back immediately if any required integration regresses.
