# SSH Authorized-Key Audit

Status: Deferred

All currently configured SSH public keys are intentionally retained until each
key can be associated with a physical device and tested. Do not remove a key
only because its comment is generic or outdated.

## Current keys

| Fingerprint | Current comment | Evidence / identification |
| --- | --- | --- |
| `SHA256:/5MqASVM/pYxFzSbYQjI55ZM2vd+XkhtOfwKAw74c94` | `u0_a514@localhost` | Unidentified Android/Termux key |
| `SHA256:7YgvBgQ71dsa0l1hQpYZ0eWN5+jxkrg88WDlS1OGhsE` | `henhal@henhal-Yoga-Pro-7-14APH8-Ubuntu` | Older Yoga installation; current need unverified |
| `SHA256:OqrlvH1++1ZpsAVQDfnG4ry2OjAfSE+G03WEOuupylU` | `henhalvor@gmail.com` | Used by the Yoga over Tailscale during the 2026 audit |
| `SHA256:2fN3+Fjyq0oix3uxt1zjT1dFLkJY9Yut2bNHyLYv1/E` | `henhalvor@gmail.com` | Device unidentified |
| `SHA256:g0cRIleGku/FGSIiADDmtpqvbRSDhTPeJYPEeL9RfPI` | `henhal@workstation` | Current workstation key; used to administer HP |
| `SHA256:yISGhVc2U0WkStositFLb1lvu86Ng5A2SBg+ZGW5Vhs` | `henhal@yoga-pro-7` | Yoga key; current need unverified while laptop is offline |
| `SHA256:s2hJG4lv5WnBQRxdIi9Gb4/xjz/nbnIsarkbkFO59wk` | `tablet@android` | Android tablet key; verify on the tablet |
| `SHA256:nqOROoRDo37auUUOT7tfjPc2JGSY6R4jBEwMMn4y414` | `henhalvor@gmail.com` | Used from LAN address `10.0.0.7` during the 2026 audit; identify the device |

## Future work

- [ ] Bring the Yoga, Android phone, and Android tablet online one at a time.
- [ ] On each device, fingerprint every public key with
      `ssh-keygen -lf ~/.ssh/<key>.pub` and match it to the table above.
- [ ] Record the device name, key-file name, creation/rotation date, and intended
      access scope for every retained key.
- [ ] Replace generic email and legacy installation comments in
      `modules/users/henhal.nix` with stable device-and-purpose comments.
- [ ] Verify each retained key against workstation, Yoga, and HP through the
      paths that device is expected to use.
- [ ] Confirm at least two independent administrative devices work before any
      revocation.
- [ ] Remove keys that are positively identified as obsolete, lost, duplicated,
      or no longer required.
- [ ] Rebuild and deploy one host at a time after removal, preserving local
      console or LAN recovery access.
- [ ] Confirm each removed key fails and each retained key still succeeds.
- [ ] Update `docs/TAILSCALE-ACCESS.md` if a device's SSH scope or tailnet role
      changes.

## Rotation rule

If a device is lost or suspected compromised, do not wait for this audit:
remove it from Tailscale, remove its SSH key, revoke its application sessions,
rotate exposed credentials, and verify that both node and key access fail.
