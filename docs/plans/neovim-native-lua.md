# Neovim: Migrate from nvf to Native Lua + wrapper-modules

## Goal

Replace `nvf` (notashelf/nvf) with native Lua config deployed via `nix-wrapper-modules`. Nix manages neovim version, plugins, and runtime dependencies. Lua manages configuration. No lazy.nvim needed -- plugins are placed in Neovim's native package directories via `wrapper-modules.neovim`.

The module must remain standalone:

- `nix run .#nvim` should run the wrapped Neovim without importing any host configuration.
- `self.homeModules.nvim` should install the same wrapped package for Home Manager and Nix-on-Droid.
- `self.nixosModules.nvim` should stay a thin NixOS wrapper that imports the Home Manager module.

## Architecture Decision: wrapper-modules over programs.neovim.plugins

Chose `wrapper-modules.neovim` (already a flake input, already used by niri) over HM `programs.neovim.plugins` because:

1. **`config.specs` DSL** -- DAG-based plugin ordering with `lazy`, `before`, `after`; per-plugin `config` (lua/fnl/vim) and `info` (Nix→Lua values); opt-in `lazy = true` places plugins in `opt/` for explicit `vim.cmd.packadd()` loading
2. **`config.nvim-lib.mkPlugin`** -- builds plugins from fetchers (needed for neocodeium, codecompanion)
3. **`config.package`** -- pin neovim version exactly (e.g., `pkgs-unstable.neovim-unwrapped`)
4. **`config.settings.config_directory`** -- points to Lua config tree, pure-store at build time, impure via `mkLuaInline` for quick-edit mode
5. **`config.extraPackages`** -- ripgrep, fd, LSP servers, formatters, DAP adapters in the wrapper PATH
6. **`require('nix-info')`** -- exposes Nix values to Lua (which plugins installed, settings, etc.)
7. **Consistency with niri** -- same framework, same patterns

## File Changes

| File | Action |
|------|--------|
| `flake.nix` | Remove `nvf` input (L23-26), remove `nvim-nix` input (L30), add pinned non-flake input for `garbage-day.nvim` unless it has entered nixpkgs |
| `modules/features/applications/nvim.nix` | Rewrite: `mkNvimPackage` + `wrappers.neovimConfig` + `perSystem.packages.nvim` + `nixosModules.nvim` + `homeModules.nvim` |
| `modules/features/applications/nvim/config/init.lua` | New: bootstrap, require core modules |
| `modules/features/applications/nvim/config/lua/config/*.lua` | New: options, keymaps, autocmds, helpers (extracted from init.lua top half) |
| `modules/features/applications/nvim/config/lua/config/plugins/*.lua` | New: per-plugin config (extracted from nvf.nix luaConfigRC + extraPlugins setup blocks) |
| `modules/features/applications/nvf.nix` | Delete |
| `hosts/workstation/configuration.nix` | `self.nixosModules.nvf` → `self.nixosModules.nvim` |
| `hosts/hp-server/configuration.nix` | `self.nixosModules.nvf` → `self.nixosModules.nvim` |
| `hosts/lenovo-yoga-pro-7/configuration.nix` | `self.nixosModules.nvf` → `self.nixosModules.nvim` |
| `modules/nix-on-droid/default.nix` | `self.homeModules.nvf` → `self.homeModules.nvim` |
| `modules/nix-on-droid/*` | Remove nvf-specific overrides (if any) |
| `docs/FEATURES.md`, `docs/HOSTS.md`, `README.md` | Update `nvf` references to `nvim` and keep `nix run .#nvim` documented |

## nvim.nix Module Structure

```
modules/features/applications/nvim.nix
modules/features/applications/nvim/config/
├── init.lua                     # Bootstrap: require('config.options') etc.
└── lua/
    └── config/
        ├── options.lua          # vim.opt settings (from nvf options block)
        ├── keymaps.lua          # All keymaps (from nvf keymaps + init.lua)
        ├── autocmds.lua         # All autocommands (from nvf luaConfigRC + init.lua)
        ├── helpers.lua          # toggle_quickfix, ToggleDevTerminal, window resize, etc.
        ├── lazy.lua             # pack/opt loader helper for lazy keymaps
        └── plugins/
            ├── blink.lua        # blink.cmp config
            ├── conform.lua      # conform.nvim config
            ├── snacks.lua       # snacks.nvim config + picker
            ├── treesitter.lua   # treesitter + context
            ├── mini.lua         # surround, comment, ai, statusline, pairs, diff
            ├── fidget.lua       # fidget.nvim LSP progress
            ├── flash.lua        # flash.nvim motion
            ├── harpoon.lua      # harpoon2 config
            ├── neocodeium.lua   # AI completion (startup-loaded)
            ├── codecompanion.lua # LLM chat (lazy keymaps)
            ├── dap.lua          # Debug adapter protocol
            ├── yazi.lua         # File manager integration
            ├── tmux.lua         # Vim-tmux-navigator
            ├── persistence.lua  # Session restore
            ├── grug-far.lua     # Search and replace
            ├── barbecue.lua     # Winbar
            ├── tabout.lua       # Tab out of brackets
            ├── rustaceanvim.lua # Rust language integration
            ├── garbage-day.lua  # Cleanup unused LSP clients (custom pinned source)
            ├── ts-autotag.lua   # Auto close tags (startup-loaded)
            └── colorschemes.lua # All themes + persistence + picker
```

## Plugin Specification (in nvim.nix)

```nix
# These specs live in flake.wrappers.neovimConfig.
# Avoid references to NixOS-only specialArgs here unless they are passed through
# mkNvimPackage, because packages.nvim must evaluate standalone.

# Core (always loaded, no lazy)
config.specs.treesitter       = pkgs.vimPlugins.nvim-treesitter.withAllGrammars;
config.specs.lspconfig        = pkgs.vimPlugins.nvim-lspconfig;
config.specs.blink-cmp        = pkgs.vimPlugins.blink-cmp;
config.specs.blink-compat     = pkgs-unstable.vimPlugins.blink-compat;
config.specs.snacks           = pkgs.vimPlugins.snacks-nvim;
config.specs.mini             = pkgs.vimPlugins.mini-nvim;
config.specs.conform          = pkgs.vimPlugins.conform-nvim;
config.specs.fidget           = pkgs.vimPlugins.fidget-nvim;
config.specs.flash            = pkgs.vimPlugins.flash-nvim;
config.specs.web-devicons     = pkgs.vimPlugins.nvim-web-devicons;
config.specs.tmux-navigator   = pkgs.vimPlugins.vim-tmux-navigator;
config.specs.barbecue         = pkgs.vimPlugins.barbecue-nvim;
config.specs.osc52            = pkgs.vimPlugins.nvim-osc52;
config.specs.tabout           = pkgs.vimPlugins.tabout-nvim;
config.specs.ts-commentstring = pkgs.vimPlugins.nvim-ts-context-commentstring;
config.specs.luasnip          = pkgs.vimPlugins.luasnip;
config.specs.friendly-snippets = pkgs.vimPlugins.friendly-snippets;
config.specs.treesitter-context = pkgs.vimPlugins.nvim-treesitter-context;
config.specs.ts-autotag       = pkgs.vimPlugins.nvim-ts-autotag;
config.specs.render-markdown  = pkgs.vimPlugins.render-markdown-nvim;
config.specs.nvim-lint        = pkgs.vimPlugins.nvim-lint;

# Custom builds (from fetcher, not in nixpkgs or need specific version)
config.specs.neocodeium = {
  pname = "neocodeium";
  data = config.nvim-lib.mkPlugin "neocodeium" (
    pkgs24-11.fetchFromGitHub {
      owner = "monkoose"; repo = "neocodeium"; rev = "v1.16.3";
      sha256 = "sha256-UemmcgQbdTDYYh8BCCjHgr/wQ8M7OH0ef6MBMHfOJv8=";
    }
  );
};

# Lazy custom builds. Configure these from Lua after packadd; do not also use
# specs.<name>.config for the same plugin.
config.specs.codecompanion = {
  pname = "codecompanion.nvim";
  lazy = true;
  data = config.nvim-lib.mkPlugin "codecompanion.nvim" (
    pkgs24-11.fetchFromGitHub {
      owner = "olimorris"; repo = "codecompanion.nvim"; rev = "v18.4.1";
      sha256 = "sha256-f3Fin46KtArc5XxA2whagloFxPev/bThCTK+52fzQoM=";
    }
  );
};

# Lazy-loaded
config.specs.harpoon = {
  pname = "harpoon";
  lazy = true;
  data = pkgs.vimPlugins.harpoon2;
};
config.specs.grug-far = {
  pname = "grug-far.nvim";
  lazy = true;
  data = pkgs.vimPlugins.grug-far-nvim;
};
config.specs.persistence = {
  pname = "persistence.nvim";
  lazy = true;
  data = pkgs.vimPlugins.persistence-nvim;
};
config.specs.yazi = {
  pname = "yazi.nvim";
  lazy = true;
  data = pkgs.vimPlugins.yazi-nvim;
};
config.specs.garbage-day = {
  pname = "garbage-day.nvim";
  lazy = true;
  data = config.nvim-lib.mkPlugin "garbage-day.nvim" inputs.garbage-day-nvim;
};

# Split lazy groups into individually named specs when Lua will call packadd.
# This keeps packadd names obvious and avoids relying on generated names for a
# parent spec containing a list.
config.specs.nvim-dap = {
  pname = "nvim-dap";
  lazy = true;
  data = pkgs.vimPlugins.nvim-dap;
};
config.specs.nvim-dap-ui = {
  pname = "nvim-dap-ui";
  lazy = true;
  data = pkgs.vimPlugins.nvim-dap-ui;
};
config.specs.nvim-dap-virtual-text = {
  pname = "nvim-dap-virtual-text";
  lazy = true;
  data = pkgs.vimPlugins.nvim-dap-virtual-text;
};
config.specs.nvim-dap-vscode-js = {
  pname = "nvim-dap-vscode-js";
  lazy = true;
  data = pkgs.vimPlugins.nvim-dap-vscode-js;
};

# Themes. Keep these startup-loaded unless the colorscheme loader is written to
# packadd the exact theme package before :colorscheme. If lazy-loading themes,
# split this list into named specs just like DAP.
config.specs.themes = with pkgs.vimPlugins; [
  catppuccin-nvim
  rose-pine
  gruvbox-baby
  gruvbox-material
  tokyonight-nvim
  kanagawa-nvim
  nord-nvim
  nightfox-nvim
  onedark-nvim
  dracula-nvim
  everforest
  sonokai
  oxocarbon-nvim
  melange-nvim
  cyberdream-nvim
  vscode-nvim
  github-nvim-theme
  # one-nvim is currently broken in nixpkgs; do not include it unless fixed.
];

# Optional advanced variant if startup cost matters:
# config.specs.theme-catppuccin = {
#   pname = "catppuccin";
#   lazy = true;
#   data = pkgs.vimPlugins.catppuccin-nvim;
# };
# ...repeat per theme, then packadd the selected pname before vim.cmd.colorscheme.

config.extraPackages = with pkgs; [
  ripgrep
  fd
  git
  prettierd
  stylua
  black
  nixfmt-rfc-style
  rustfmt
  rust-analyzer
  lua-language-server
  nil
  nodePackages.typescript-language-server
  tailwindcss-language-server
  nodePackages.vscode-langservers-extracted
  nodePackages.yaml-language-server
  nodePackages.svelte-language-server
  gopls
  pyright
  clang-tools
  vscode-js-debug
];
```

If `garbage-day.nvim` is still not in the active nixpkgs input, add it as a pinned flake input:

```nix
garbage-day-nvim = {
  url = "github:Zeioth/garbage-day.nvim";
  flake = false;
};
```

Check exact package names against the current nixpkgs input during implementation. As of this plan review, the listed nixpkgs plugin and runtime package names evaluate on `x86_64-linux` except `garbage-day-nvim`, which must be supplied from a pinned source as shown above.

If you choose to lazy-load all themes, split them into one spec per plugin instead of a single lazy parent list:

```nix
config.specs.theme-catppuccin = {
  pname = "catppuccin";
  lazy = true;
  data = pkgs.vimPlugins.catppuccin-nvim;
};
```

## init.lua Design

```lua
-- Bootstrap: set globals needed by plugins before loading
vim.g.mapleader = " "
vim.g.maplocalleader = ","
vim.g.have_nerd_font = true

-- Load configuration modules
require("config.options")     -- All vim.opt/vim.g/vim.o settings
require("config.keymaps")     -- Base keymaps (move lines, navigation, etc.)
require("config.autocmds")    -- All autocommands (lsp-attach-keymaps, yank highlight, etc.)
require("config.helpers")     -- Global utility functions (_G.toggle_quickfix, etc.)

-- Load plugin configurations
require("config.plugins.treesitter")
require("config.plugins.lsp")
require("config.plugins.blink")
require("config.plugins.conform")
require("config.plugins.snacks")
require("config.plugins.mini")
require("config.plugins.fidget")
require("config.plugins.flash")
require("config.plugins.tmux")
require("config.plugins.osc52")
require("config.plugins.barbecue")
require("config.plugins.tabout")
require("config.plugins.neocodeium")
require("config.plugins.ts-autotag")
require("config.plugins.colorschemes")  -- Must be last (sets colorscheme)

-- Lazy-loaded plugins (loaded by vim.cmd.packadd when triggered)
require("config.plugins.harpoon")
require("config.plugins.grug-far")
require("config.plugins.persistence")
require("config.plugins.yazi")
require("config.plugins.codecompanion")
require("config.plugins.dap")
require("config.plugins.garbage-day")
```

Important: for lazy-loaded plugins, their config should be deferred. Native `pack/opt` plugins are not loaded by `require(...)`. Lazy keymaps must explicitly call `vim.cmd.packadd("<pname>")` before the first `require(...)`. Put the loader in `config/lazy.lua` so every plugin keymap file can share it.

```lua
-- config/lazy.lua
local loaded = {}

local M = {}

function M.load(pack_name, setup)
  if not loaded[pack_name] then
    vim.cmd.packadd(pack_name)
    if setup then setup() end
    loaded[pack_name] = true
  end
end

return M
```

```lua
-- Lazy-loaded plugins: define keymaps that explicitly packadd first.
require("config.plugins.harpoon")   -- Defines <leader>a, <leader>e, etc.
require("config.plugins.grug-far")  -- Defines <leader>sr
require("config.plugins.persistence")  -- Defines <leader>qs, etc.
require("config.plugins.yazi")      -- Defines - (open yazi)
require("config.plugins.codecompanion") -- Defines <leader>aa, etc.
require("config.plugins.dap") -- Defines debug keymaps and packadds DAP plugins together
require("config.plugins.garbage-day") -- Defines command/autocmd that packadds on first use
```

Each lazy plugin file should use the stable `pname` from the Nix spec:

```lua
local lazy = require("config.lazy")

vim.keymap.set("n", "<leader>sr", function()
  lazy.load("grug-far.nvim", function()
    require("grug-far").setup(require("config.plugins.grug-far").opts)
  end)
  require("grug-far").open()
end, { desc = "Search and replace" })
```

Alternative: do not mark a plugin lazy unless the startup cost is measurable. For plugins used during startup or in common autocommands, prefer `lazy = false`.

## Standalone Package Structure

`modules/features/applications/nvim.nix` should follow the same boundary as `niri.nix`: one wrapper module plus a reusable package builder.

```nix
{
  self,
  inputs,
  ...
}: let
  mkNvimPackage = {
    pkgs,
    pkgs-unstable ? pkgs,
    pkgs24-11 ? pkgs,
  }:
    inputs.wrapper-modules.wrappers.neovim.wrap {
      inherit pkgs pkgs-unstable pkgs24-11;
      imports = [ self.wrapperModules.neovimConfig ];
    };
in {
  flake.wrappers.neovimConfig = { config, lib, pkgs, ... }: {
    config.package = pkgs-unstable.neovim-unwrapped;
    config.settings.config_directory = ./nvim/config;
    # specs, info, extraPackages...
  };

  perSystem = { pkgs, system, ... }: {
    packages.nvim = mkNvimPackage {
      inherit pkgs;
      pkgs-unstable = import inputs.nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
      pkgs24-11 = import inputs.nixpkgs-24-11 {
        inherit system;
        config.allowUnfree = true;
      };
    };
  };

  flake.nixosModules.nvim = { ... }: {
    home-manager.sharedModules = [ self.homeModules.nvim ];
  };

  flake.homeModules.nvim = { pkgs, lib, ... }: {
    home.packages = [ self.packages.${pkgs.system}.nvim ];
    home.sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };
  };
}
```

Implementation note: verify whether `inputs.wrapper-modules.wrappers.neovim.wrap` already imports the Neovim wrapper module, as `niri.nix` does for Niri. If using the raw module form from the docs instead, import the wrapper module through the wrapper library (`wlib.wrapperModules.neovim`). The important property is that `perSystem.packages.nvim` does not rely on NixOS `specialArgs`.

## Migration Steps (Ordered)

### Phase 1: Create the Nix module

1. Write `modules/features/applications/nvim.nix` with `mkNvimPackage`, `flake.wrappers.neovimConfig`, and `perSystem.packages.nvim` (following niri.nix pattern)
2. Create config directory structure under `modules/features/applications/nvim/config/`
3. Add `self.homeModules.nvim` that installs `self.packages.${pkgs.system}.nvim`
4. Add thin `self.nixosModules.nvim` that imports the Home Manager module

### Phase 2: Extract Lua config from nvf.nix

For each Lua snippet in nvf.nix's `luaConfigRC`, `extraPlugins.*.setup`, and `keymaps`:

1. **options**: `vim.options` → `config/options.lua`
2. **keymaps**: All `vim.keymaps` entries → `config/keymaps.lua`
3. **autocmds**: All `vim.api.nvim_create_autocmd` blocks from `luaConfigRC` → `config/autocmds.lua`
4. **helpers**: `_G.toggle_quickfix`, `_G.ToggleDevTerminal`, `save_colorscheme` → `config/helpers.lua`
5. **Plugin configs**: Each `luaConfigRC` block and `extraPlugins.*.setup` string → individual plugin files
6. **Generated nvf behavior**: Recreate LSP, diagnostics, formatters, language support, and theme defaults that nvf currently generated from Nix options

### Phase 3: Plugin Nix→Lua mapping

| nvf config location | Target file |
|---|---|
| `autocomplete."blink-cmp".setupOpts` | `plugins/blink.lua` |
| `formatter."conform-nvim".setupOpts` | `plugins/conform.lua` |
| `utility."snacks-nvim".setupOpts` + `luaConfigRC.snacks-*` | `plugins/snacks.lua` |
| `mini.*` blocks + `luaConfigRC.mini-*` | `plugins/mini.lua` |
| `visuals.fidget-nvim.setupOpts` | `plugins/fidget.lua` |
| `utility.motion.flash-nvim` | `plugins/flash.lua` |
| `extraPlugins.barbecue-nvim` | `plugins/barbecue.lua` |
| `extraPlugins.nvim-osc52` | `plugins/osc52.lua` |
| `extraPlugins.tabout-nvim` | `plugins/tabout.lua` |
| `extraPlugins.rustaceanvim` | `plugins/rustaceanvim.lua` |
| `extraPlugins.harpoon2` | `plugins/harpoon.lua` |
| `extraPlugins.persistence-nvim` | `plugins/persistence.lua` |
| `extraPlugins.grug-far-nvim` | `plugins/grug-far.lua` |
| `extraPlugins.neocodeium` | `plugins/neocodeium.lua` |
| `extraPlugins.codecompanion` | `plugins/codecompanion.lua` |
| Theme plugins + `luaConfigRC.colorscheme-*` | `plugins/colorschemes.lua` |
| `luaConfigRC.lsp-*` + `lsp.*` | `plugins/lsp.lua` |
| `luaConfigRC.treesitter.*` | `plugins/treesitter.lua` |
| `utility.yazi-nvim` | `plugins/yazi.lua` |
| `extraPlugins.vim-tmux-navigator` | `plugins/tmux.lua` |

### Phase 3b: Recreate nvf-generated language/tooling behavior

nvf currently generates more than plugin setup. Replace that generated behavior explicitly:

| Area | Native Lua/Nix replacement |
|---|---|
| LSP core | Add `nvim-lspconfig`; configure `vim.lsp.config`/`lspconfig` with blink capabilities |
| Language servers | Add all server binaries to `config.extraPackages` |
| Diagnostics | Add `nvim-lint` if eslint-on-save behavior is still wanted |
| Formatting | Add formatter binaries and configure `conform.nvim` |
| Markdown rendering | Add `render-markdown.nvim` if current markdown behavior should remain |
| Treesitter | Install `nvim-treesitter.withAllGrammars` or a curated grammar set |
| Snippets | Add `luasnip`, `friendly-snippets`, and load snippets in Lua |
| CLI tools | Add `ripgrep`, `fd`, `git`, plus tools required by snacks/yazi/DAP |

### Phase 4: Merge with target nvim-nix config

The target config in `~/.nvim-nix/config/` has some additions not in nvf:

- **treesitter-context** -- add to specs
- **garbage-day** -- add to specs
- **ts-autotag** -- add to specs
- **dap** (debugger) -- add `nvim-dap`, `nvim-dap-ui`, `nvim-dap-virtual-text`, `nvim-dap-vscode-js`, and the `vscode-js-debug` adapter package/path
- Mini.diff has simpler config (no custom signs)

Porting notes:

- Remove lazy.nvim plugin spec tables from `~/.nvim-nix/config`; convert each to either a Nix spec plus Lua setup or a lazy keymap that calls `packadd`.
- Remove Mason assumptions. Any adapter/server/formatter path must come from Nix packages or project-local tools.
- Replace Telescope-only LSP keymaps with Snacks picker equivalents, or add Telescope back explicitly if those keymaps are still preferred.

### Phase 5: Wire up NixOS module

The `nixosModules.nvim` replaces `nvf` with identical pattern:

```nix
flake.nixosModules.nvim = { ... }: {
  home-manager.sharedModules = [ self.homeModules.nvim ];
};
```

### Phase 6: Update all consumers

1. Replace `self.nixosModules.nvf` → `self.nixosModules.nvim` in 3 host configuration.nix files
2. Replace `self.homeModules.nvf` → `self.homeModules.nvim` in nix-on-droid
3. Remove `nvf` and `nvim-nix` from `flake.nix` inputs
4. Update docs that list `nvf` as the editor module
5. Run `nix flake lock` after removing old inputs and adding any new pinned plugin inputs, then rebuild

## Key Decisions

1. **No lazy.nvim** -- wrapper-modules' native packpath + `lazy` specs replace it. Plugins in `pack/start/` auto-load. Plugins in `pack/opt/` require explicit `vim.cmd.packadd("<pname>")` before `require(...)`.

2. **Snacks.picker over Telescope** -- using Snacks picker from nvf config (already well configured, fewer dependencies).

3. **Keep pkgs24-11 for neocodeium/codecompanion** -- same as current nvf setup, avoids potential build issues.

4. **Neovim version**: `config.package = pkgs-unstable.neovim-unwrapped` (matches current nvf behavior).

5. **Config directory**: `config.settings.config_directory = ./nvim/config;` from `modules/features/applications/nvim.nix` (pure, baked into nix store). For quick edits, switch to `lib.generators.mkLuaInline "vim.fn.stdpath('config')"`. Provide both via a toggle pattern.

6. **Info plugin** -- `config.info.lazy_plugins` maps which specs are lazy, useful for Lua to check availability and to keep lazy `packadd` names in sync.

7. **Standalone first** -- build and test `nix run .#nvim -- --headless "+checkhealth" "+qa"` before wiring hosts, so the module does not accidentally depend on host-only arguments.

## Questions Unresolved

- Delete `nvf.nix` entirely or keep for reference? Recommend: delete after the new module is verified; git history preserves it.
- Whether all themes should be startup-installed for simple colorscheme switching, individually lazy-loaded, or reduced to the themes actually used.
- Whether to keep `nvim-lint` eslint behavior or rely on LSP diagnostics only.
- Whether DAP should be included in the default standalone package or split into a larger `nvim-full` variant later.
