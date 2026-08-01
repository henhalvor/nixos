# Phase 3 secret rotation

The profile split prevents future cross-host decryption, but it cannot revoke
values that were present in the former shared profile. Complete these tasks
after deploying the new configuration to all affected hosts.

- [ ] Rotate the Telegram bot token, update `secrets/hp-agent.yaml`, deploy the
  HP server, verify Hermes, and revoke the old token.
- [ ] Create a dedicated Hermes/Ollama credential, replace
  `HERMES_OLLAMA_API_KEY`, deploy, verify, and revoke the shared value.
- [ ] Create a dedicated Firecrawl provider credential, replace
  `FIRECRAWL_OPENAI_API_KEY`, deploy, verify, and revoke the shared value.
- [ ] Rotate `HERMES_WORKSPACE_PASSWORD` after the HP server uses the new
  profile.
- [ ] Rotate the OpenCode server username/password after the workstation uses
  `workstation-services.yaml`.
- [ ] Review provider dashboards for unexpected use before and after rotation.

Do one consumer at a time. Keep the old credential active only until the new
one has been tested; SOPS recipient changes alone do not invalidate it.
