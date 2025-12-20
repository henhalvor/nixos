# Nix-on-Droid Configuration

Declarative Android tablet development environment using nix-on-droid.

## Features

- **CLI Development Tools**: nodejs, rust, python, go, gcc, cmake, lazygit
- **Neovim (nvf)**: Full IDE setup with LSP, treesitter, blink-cmp autocomplete
- **Shell**: Zsh with powerlevel10k, fzf, zoxide
- **Multiplexer**: Tmux with vim navigation and session persistence
- **File Manager**: Yazi
- **Git**: Configured with GitHub CLI (gh)
- **Direnv**: Per-directory development environments
- **Clipboard**: OSC52 integration (copy from nvim/tmux, paste anywhere)
- **SSH/Mosh**: Pre-configured workstation connections (local + Tailscale) with port forwarding

## Prerequisites

1. Android device (aarch64)
2. Install [Nix-on-Droid app from F-Droid](https://f-droid.org/packages/com.termux.nix)

## Installation

### First-time Setup

1. **Install Nix-on-Droid app** from F-Droid and launch it
2. **Wait for initial installation** (downloads ~500MB)
3. **Clone this repository**:
   ```bash
   cd ~
   git clone https://github.com/yourusername/dotfiles .dotfiles
   cd .dotfiles
   ```

4. **Build and activate configuration**:
   ```bash
   nix-on-droid switch --flake .#default
   ```

   This will:
   - Install all CLI development tools
   - Configure neovim with full IDE features
   - Setup zsh with powerlevel10k theme
   - Configure tmux with session persistence
   - Install and configure git + gh CLI
   - Setup yazi file manager
   - Install Hack Nerd Font for proper icon/glyph rendering

5. **Post-installation**:
   
   **Setup Git SSH Key** (for GitHub):
   ```bash
   ssh-keygen -t ed25519 -C "henhalvor@gmail.com"
   cat ~/.ssh/id_ed25519.pub
   # Add the public key to GitHub: https://github.com/settings/keys
   ```

   **Authenticate GitHub CLI**:
   ```bash
   gh auth login
   ```

   **Test neovim**:
   ```bash
   nvim
   # LSP should work, clipboard (yank/paste) should work via OSC52
   ```

   **Connect to workstation** (optional):
   ```bash
   # SSH with tmux auto-attach
   ws              # Local network
   wst             # Tailscale
   
   # Mosh (better mobile connectivity)
   wsm             # Local network
   wstm            # Tailscale
   ```
   
   Note: Your tablet's SSH key is already authorized on the workstation:
   `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEs49ICQp01DqPO/Mwxl13fEsYjM+ghwZWp/orbTZrV3 tablet@android`

## Updates

After making changes to the configuration:

```bash
cd ~/.dotfiles
git pull
nix-on-droid switch --flake .#default
```

## Rollback

If something breaks:

```bash
nix-on-droid rollback
```

## Configuration Files

- **Main config**: `nix-on-droid/default.nix`
- **Home-manager**: `users/henhal-android/home.nix`
- **Reused modules**: `home/modules/*` (shared with NixOS configs)

## Included Modules

### CLI Tools
- `home/modules/environment/dev-tools.nix` - Development toolchains
- `home/modules/environment/direnv.nix` - Directory environments
- `home/modules/environment/session-variables.nix` - Environment variables

### Applications
- `home/modules/applications/nvf.nix` - Neovim IDE
- `home/modules/applications/zsh.nix` - Zsh shell
- `home/modules/applications/tmux.nix` - Terminal multiplexer
- `home/modules/applications/yazi.nix` - File manager

### Settings
- `home/modules/settings/git.nix` - Git configuration
- `home/modules/settings/nerd-fonts.nix` - Patched fonts
- `nix-on-droid/modules/ssh-client.nix` - SSH/Mosh workstation connections

### Scripts
- `home/modules/scripts/search-with-zoxide.nix` - Directory jumper

## What Doesn't Work

These are intentionally excluded (require GUI/systemd):
- Window managers (Hyprland, Sway)
- GUI applications (browsers, kitty, etc.)
- Stylix themes
- systemd services
- Power management scripts

## Tips

### Clipboard
- Yank in nvim → automatically copied to system clipboard (OSC52)
- Works in tmux too
- Paste with Android long-press or keyboard

### Tmux
- Sessions auto-save every 15 minutes
- Auto-restore on tmux start
- Vim navigation between panes (C-h/j/k/l)

### Zsh
- `z <dir>` - Jump to directory (zoxide)
- `Ctrl-F` - Fuzzy search recent nvim files
- `nlof` - Open recent nvim files

### Neovim
- Full LSP support for TS/JS/Rust/Python/Go/Nix
- `<leader>` = Space
- `<leader>sg` - Live grep
- `<leader>sc` - Find files
- `-` - Open yazi file manager

### SSH/Mosh Connections
- `ws` - SSH to workstation (local network) with tmux auto-attach
- `wsm` - Mosh to workstation (local network)
- `wst` - SSH to workstation (Tailscale) with tmux auto-attach
- `wstm` - Mosh to workstation (Tailscale)

**Port Forwarding** (all connections):
- Next.js/React: 3000, 8081 (Metro)
- Sveltekit: 5173
- Supabase: 54320-54324, 54327, 54329, 8083
- Expo: 19000-19003
- ADB: 5037
- AWS SSO: 38215
- SOCKS proxy: 8888 (dynamic)

## Troubleshooting

### Zsh not starting automatically
If you land in bash instead of zsh, the config sets `user.shell` to zsh. After running `nix-on-droid switch`, close and reopen the app. Zsh should now be the default shell.

### Shell prompt shows "localhost" instead of hostname
The hostname is configured via `home.sessionVariables.HOSTNAME`. After `nix-on-droid switch`:
1. Close and reopen the app
2. Check hostname: `echo $HOSTNAME` (should show "galaxy-tab-s10-ultra")
3. If still showing "localhost", run: `source ~/.zshrc`

### Fonts don't render correctly / Missing symbols
The configuration automatically sets the terminal font to Hack Nerd Font. After `nix-on-droid switch`, **close and reopen the app** for the font to take effect.

If glyphs/symbols still don't render (git branch symbol, powerline arrows, etc.):
1. Verify font is installed: `ls ~/.nix-profile/share/fonts/truetype/NerdFonts/`
2. Check terminal font is set: `nix eval ".#nixOnDroidConfigurations.default.config.terminal.font" --impure`
3. Verify fontconfig is enabled: Check that `~/.config/fontconfig/` directory exists
4. Restart the app completely (force close from Android settings)

**Note:** Some symbols require the app to fully restart. Simply closing and reopening may not be enough.

### Build fails with proot error
This is expected on x86_64. The config can only be fully built on Android (aarch64). Evaluation works fine:
```bash
nix eval ".#nixOnDroidConfigurations.default.config.system.stateVersion"
```



### LSP not working
First activation may take time to download LSP servers. Wait for completion.

## Development

Test configuration evaluation (on any system):
```bash
nix eval ".#nixOnDroidConfigurations.default.config.system.stateVersion" --impure
```

Check what packages are included:
```bash
nix eval ".#nixOnDroidConfigurations.default.config.environment.packages" --apply 'builtins.length' --impure
```
