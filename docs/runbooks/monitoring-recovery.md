# Monitoring Recovery Runbook

## Recovery principle

Monitoring data is disposable operational history. Configuration is recovered
from Git and SOPS. Do not delay restoration of OpenCloud or backups merely to
recover old Prometheus metrics or Loki logs.

## Rebuild after HP system loss

1. Reinstall NixOS and restore the dotfiles repository.
2. Restore an authorized personal or HP SOPS age identity.
3. Restore Tailscale membership and confirm the expected MagicDNS identity.
4. Restore the existing Cloudflare Tunnel credential from SOPS.
5. Build and switch HP:

   ```bash
   sudo nixos-rebuild switch --flake .#hp-server
   ```

6. Confirm local readiness:

   ```bash
   curl -fsS http://127.0.0.1:9090/-/ready
   curl -fsS http://127.0.0.1:9093/-/ready
   curl -fsS http://127.0.0.1:3100/ready
   curl -fsS http://127.0.0.1:3000/api/health
   ```

7. Confirm Grafana recreated its data sources and dashboards from provisioning.
8. Confirm workstation and Lenovo targets when those machines are online.
9. Confirm the `monitoring` Keycloak realm/client exists in the restored identity
   database. If it does not, recreate it from the implementation plan and
   rotate the client secret.
10. Confirm `monitor.henhal.net` still routes to the existing tunnel.
11. Test an alert and resolved notification.
12. Resume external heartbeat checks only after all local checks succeed.

## Recreate only monitoring state

If Prometheus, Loki, or Grafana state is corrupt but HP is otherwise healthy:

1. Save service logs and identify which state directory is affected.
2. Stop only the affected service.
3. Move the affected state aside to a dated quarantine directory on the same
   filesystem; do not immediately delete it.
4. Start the service with an empty state directory created by its NixOS unit.
5. Confirm rules, data sources, and dashboards reprovision correctly.
6. Confirm fresh metrics/logs arrive and alert evaluation resumes.

Prometheus and Loki history will begin again. Grafana users and sessions may be
lost, but Keycloak-authenticated users can be recreated at next login. The Git
versions of provisioned dashboards remain authoritative.

## Lost Grafana/Keycloak access

- First confirm Keycloak itself is healthy and the issuer is reachable.
- Verify the Grafana callback and root URL are exactly
  `https://monitor.henhal.net/login/generic_oauth` and
  `https://monitor.henhal.net/`.
- Verify the user's Keycloak realm role and MFA state.
- Use the SOPS-managed local Grafana break-glass administrator only for recovery.
- Rotate the break-glass password after use.

Do not enable anonymous access as a recovery shortcut while Grafana is public.

## Validation after recovery

- all backend listeners remain loopback/Tailscale-only
- Grafana public access requires Keycloak authentication and MFA
- Viewer cannot administer Grafana
- online targets are `UP`
- one controlled alert arrives and resolves
- external stack and backup heartbeat checks are current
- OpenCloud, Auth, Restic, Syncthing, and GitHub mirror workflows remain healthy

