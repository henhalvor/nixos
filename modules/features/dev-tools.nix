# Dev Tools — development toolchains + lazygit config
# Source: home/modules/environment/dev-tools.nix
{self, ...}: {
  flake.nixosModules.devTools = {...}: {
    home-manager.sharedModules = [self.homeModules.devTools];
  };

  flake.homeModules.devTools = {
    config,
    pkgs,
    ...
  }: {
    home.packages = with pkgs; [
      lazygit
      lazydocker
      jq
      unzip
      neofetch

      # Node.js
      nodejs_20

      # Rust
      rustc
      cargo
      clippy

      # Python
      python311
      python311Packages.pip

      # Go
      go

      # Build tools
      gcc
      gnumake
      cmake
    ];

    # Lazygit config (lazycommit: go install github.com/m7medvision/lazycommit@latest)
    home.file.".config/lazygit/config.yml".text = ''
      customCommands:
        - key: "<c-a>" # ctrl + a
          description: "pick AI commit"
          command: |
            if [ "{{.Form.Action}}" = "edit" ]; then
              echo "{{.Form.Msg}}" > .git/COMMIT_EDITMSG && nvim .git/COMMIT_EDITMSG && [ -s .git/COMMIT_EDITMSG ] && git commit -F .git/COMMIT_EDITMSG || echo "Commit message is empty, commit aborted."
            else
              git commit -m "{{.Form.Msg}}"
            fi
          context: "files"
          output: terminal
          prompts:
            - type: "menuFromCommand"
              title: "AI Commit Messages"
              key: "Msg"
              command: "lazycommit commit"
              filter: "^(?P<raw>.+)$"
              valueFormat: "{{ .raw }}"
              labelFormat: "{{ .raw | green }}"
            - type: "menu"
              title: "Choose Action"
              key: "Action"
              options:
                - name: "Commit directly"
                  description: "Use this message as-is"
                  value: "direct"
                - name: "Edit before commit"
                  description: "Open in editor first"
                  value: "edit"
        - key: "C"
          context: "files"
          description: "Generate commit message with OpenCode"
          command: |
            DIFF=$(git diff --staged)
            ${config.home.homeDirectory}/.local/dev/npm/global/bin/opencode run -m github-copilot/gpt-5-mini --format json "Generate a concise git commit message for these changes. Output ONLY the commit message text with no markdown, code blocks, or explanations. Use conventional commit format:\n\n$DIFF" | jq -r 'select(.type == "text") | .part.text' | paste -sd ' ' - > /tmp/commit_msg && GIT_EDITOR=vim git commit -e -F /tmp/commit_msg
          output: terminal
    '';

    # Dev directory structure
    home.activation = {
      createDevDirectories = ''
        mkdir -p ${config.home.homeDirectory}/.local/dev/{npm/{global,cache,config},cargo,rustup,python,go}
        mkdir -p ${config.home.homeDirectory}/.local/share/nvim/{lazy,mason}
      '';
    };

    # npm config
    home.file.".npmrc".text = ''
      prefix=${config.home.homeDirectory}/.local/dev/npm/global
      cache=${config.home.homeDirectory}/.local/dev/npm/cache
      init-module=${config.home.homeDirectory}/.local/dev/npm/config/npm-init.js
    '';

    # pip config
    home.file.".config/pip/pip.conf".text = ''
      [global]
      user = true
      prefix = ${config.home.homeDirectory}/.local/dev/python
    '';
  };
}
