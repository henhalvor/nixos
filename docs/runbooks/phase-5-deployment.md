# Phase 5 deployment gate

The repository contains the HP OpenCloud, Keycloak, Cloudflare Tunnel, GitHub
mirror, and Restic implementation, but none of these services are enabled yet.
This is intentional: the selected public hostnames, Cloudflare Tunnel UUID,
S3 repository, backup identity, GitHub owners, and Hermes export command are
not present in this repository. Do not substitute example values or plaintext
credentials merely to make a build pass.

## Provider and secret setup

1. Create the Cloudflare DNS zone, a locally managed tunnel, `cloud.<domain>`
   and `auth.<domain>` routes, and cache-bypass rules for both hosts. Do not
   enable Cloudflare Access on either hostname. Save only that tunnel's
   credentials JSON, not `cert.pem` or an account-wide token.
2. Create the versioned, private S3 bucket/prefix and its restricted HP backup
   identity. Its policy needs ordinary object/list operations plus transient
   `DeleteObject` for Restic locks; it must not have IAM, bucket-policy, ACL,
   public-access, or non-current-version deletion rights. Configure provider
   encryption and a budget alert. Do not add lifecycle, retention, `forget`,
   `prune`, or Object Lock automation.
3. Create the two encrypted profiles using a personal age key:

   ```bash
   sops secrets/opencloud.yaml
   sops secrets/hp-backup.yaml
   ```

   `opencloud.yaml` must contain `OPENCLOUD_ADMIN_PASSWORD`,
   `KEYCLOAK_DB_PASSWORD`, `KEYCLOAK_ADMIN_PASSWORD`, and
   `CLOUDFLARED_TUNNEL_CREDENTIALS`. `hp-backup.yaml` must contain
   `GITHUB_MIRROR_TOKEN`, `RESTIC_REPOSITORY_PASSWORD`,
   `RESTIC_AWS_ACCESS_KEY_ID`, `RESTIC_AWS_SECRET_ACCESS_KEY`,
   `RESTIC_AWS_DEFAULT_REGION`, and `RESTIC_REPOSITORY`. The repository value
   is the full Restic S3 URL. All
   values stay encrypted; neither profile belongs in the interactive shell
   loader.
4. Add the personal GitHub login and every in-scope organisation to
   `modules/features/backup/github-owners.txt`. Use a read-only token that can
   list and clone the required private repositories. It must have no write
   permission.
5. Confirm the T7 UUID is still
   `e4577487-f1c0-4aee-bea3-daac8df1633d`, is mounted as ext4 at
   `/srv/opencloud`, has working user xattrs, and has at least 20 GiB free in
   addition to the reviewed capacity budget. Record the physical port, cable,
   serial `S6XDNS0WA22565Z`, clean-unmount procedure, and disk-replacement
   procedure.

## Enable and validate

Set these in `hosts/hp-server/configuration.nix` only after the preceding
steps are complete:

```nix
my.opencloud = {
  enable = true;
  cloudHost = "cloud.<domain>";
  authHost = "auth.<domain>";
};
my.opencloudTunnel.tunnelId = "<Cloudflare tunnel UUID>";
my.opencloudConsistentSource.enable = true;
my.githubMirror.enable = true;
my.hpBackup = {
  enable = true;
  # Use only a Hermes-native, reviewed export command that writes to
  # $HERMES_EXPORT_DEST. Leave this unset until one exists; the backup will
  # run with the source explicitly recorded as degraded.
  hermesExportCommand = null;
};
```

Build before switching, then deploy only HP:

```bash
nix build .#nixosConfigurations.hp-server.config.system.build.toplevel
sudo nixos-rebuild switch --flake .#hp-server
```

Before migrating files, configure Keycloak's `opencloud` realm and the exact
OpenCloud-supported external-directory/OIDC client setup. Enforce MFA for
routine and administrator identities, configure recovery codes and a separate
break-glass identity, and test browser, desktop, Android, WebDAV app-token,
and non-tailnet login flows. Do not make the built-in OpenCloud IDP a fallback
login path.

Validate the local boundary with `ss -lntp`: OpenCloud must bind only
`127.0.0.1:9200`, Keycloak only `127.0.0.1:8080`, and neither backend nor
Keycloak management may be firewall-exposed. Validate the tunnel ingress rules
and test the 50 MB, 150 MB, and representative-largest-file upload matrix.

Initialize the Restic repository manually once, then run the job twice:

```bash
sudo systemctl start github-mirror.service
sudo systemctl start restic-backups-hp-offsite.service
sudo restic-hp-offsite snapshots
sudo systemctl start restic-backups-hp-offsite.service
```

Review `/var/lib/restic-status/last-success`,
`/var/lib/restic-status/last-source-status`, the per-source JSON files, and
the journal weekly until monitoring is separately implemented. A successful
Restic snapshot with a degraded Hermes or auxiliary source is not a fully
healthy recovery set.

The OpenCloud source uses Mode B: it stops OpenCloud for the whole Restic read
and its systemd post-stop cleanup restarts it. Never change this to a live
Restic read. Test a restore into an xattr-capable isolated filesystem and
isolated loopback-only OpenCloud/Keycloak instance before moving irreplaceable
files into OpenCloud.
