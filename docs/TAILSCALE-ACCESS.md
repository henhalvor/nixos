# Tailscale Access Boundary

NixOS firewall rules and the tailnet policy are separate controls. The host
configuration does not trust `tailscale0`; it permits only SSH, Mosh, and
Syncthing directly. Services published with Tailscale Serve stay bound to
loopback and are reached through `tailscaled`.

## Tailnet policy requirements

- Only Henrik's explicitly enrolled personal devices may administer
  `workstation`, `lenovo-yoga-pro-7`, or `hp-server` over SSH.
- Ordinary tailnet devices must not reach host administration merely because
  they joined the tailnet.
- HP service access and SSH administration must be separate grants.
- Do not expose future monitoring ports until the monitoring phase defines its
  principals and access rules.
- Test the policy with a non-administrative device before considering it
  complete. A checked-in example must not be copied into the admin console
  without first resolving the actual users, groups, tags, and grants shown by
  the current tailnet policy.

## Lost-device response

1. From a separate trusted device, open the Tailscale admin console and expire
   or remove the lost device immediately.
2. Remove its SSH public key from `modules/users/henhal.nix`, rebuild the three
   hosts, and deploy through a still-trusted path.
3. Revoke application sessions and app passwords that were present on the
   device. Rotate credentials if local storage may have exposed them.
4. Confirm the removed node and SSH key can no longer connect.

## Key expiry and recovery

- Keep key expiry enabled for ordinary personal clients unless a documented
  operational need requires otherwise.
- Any non-expiring server node must be intentional, recorded, and protected by
  restrictive grants rather than broad user ownership.
- Preserve local-console or LAN SSH access before narrowing the tailnet policy.
- Keep at least two independently controlled administrative devices so losing
  one device does not eliminate recovery access.
