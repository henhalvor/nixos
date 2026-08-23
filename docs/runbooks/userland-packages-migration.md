# Userland migration record

The initial rollout enables the managers and facade without moving existing
packages. This keeps the current workstation usable while each mutable owner
passes its install, update, service, and rollback checks.

| Package or group | Current owner and path | Target owner | Why mutable | Service dependency | Rollback |
| --- | --- | --- | --- | --- | --- |
| Node.js, pnpm, Rust, Python, Go | Home Manager in `modules/features/dev-tools.nix` | Pending inventory | Do not assume the current `nixpkgs` versions are too old | Project shells and build tools consume them | Keep the existing Home Manager packages until a mise pilot passes |
| OpenCode | npm prefix under `~/.local/dev/npm/global`, plus `opencode-update.service` | mise via `userland` (`github:anomalyco/opencode`) | Releases faster than the current Nix package path | `opencode-web.service` and `opencode-vault-web.service` use `mise exec -- opencode` | `userland remove mise:github:anomalyco/opencode@<version>` and restore `npm install --global opencode-ai@<version>` if needed |
| Oh My Pi | Nix package in `modules/features/applications/oh-my-pi.nix` | Nix for now | Current pinned package remains usable | None | Keep the Nix package and its pinned release |
| Claude Code, Amazon Q, CodeCrafters | Existing Nix or Home Manager modules | Pending inventory | Only move if the current package is materially stale | No root-owned service | Re-enable the existing module |
| Hermes gateway | Root-owned system service under `modules/features/ai/hermes-runtime.nix` | NixOS service boundary | Mutable payload is separately maintained | `hermes-agent.service` | Use the existing reviewed maintenance path |
| Flatpak applications | None recorded before rollout | User-scoped Flatpak | Only for GUI applications that need newer upstream releases | Desktop portals and Flatpak user installation | `flatpak --user uninstall` or application-specific history |
| AppImages | None recorded before rollout | Gear Lever | Only when the upstream AppImage is the best maintained Linux build | No system service | `gearlever --remove` or restore the retained AppImage |

Before a migration, fill in the actual command paths, versions, service unit
references, and a tested rollback command. A package stays with its current
owner until that row is complete.
