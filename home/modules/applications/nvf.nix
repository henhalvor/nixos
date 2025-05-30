{
  config,
  pkgs,
  system,
  nvf,
  inputs,
  unstable,
  pkgs24-11,
  ...
}: let
  # Use nixpkgs 24.11 to build the plugin to avoid the require check issues
  mcphub-nvim-plugin = pkgs24-11.vimUtils.buildVimPlugin {
    name = "mcphub-nvim-from-source";
    src = pkgs24-11.fetchFromGitHub {
      owner = "ravitemer";
      repo = "mcphub.nvim";
      rev = "v5.4.0";
      sha256 = "sha256-XOnlLgK67mOzAdm+Y+8oR6TY9q7EvUT7MQfk3fLKAqM=";
    };
  };
in
  # This 'in' assumes the let block is outside but scoped for the config below
  {
    # Import the nvf home-manager module directly
    imports = [
      inputs.nvf.homeManagerModules.default
      # your other imports...
    ];

    programs.nvf = {
      enable = true;
      enableManpages = true;
      settings = {
        vim = {
          # Package configuration
          package = unstable.neovim-unwrapped;

          # Alias
          viAlias = false;
          vimAlias = true;

          ui.borders = {
            enable = true;
            globalStyle = "rounded"; # This sets rounded borders globally
          };

          # Base neovim options
          options = {
            number = true;
            relativenumber = true;
            signcolumn = "yes";
            tabstop = 2;
            shiftwidth = 2;
            expandtab = true;
            smartindent = true;
            termguicolors = true;
            autoread = true;
            formatoptions = "2";
            showmode = true;
            clipboard = "unnamedplus";
            wrap = true;
            linebreak = true;
            breakindent = true;
            showbreak = "↪ ";
            breakat = " ^!@*-+;:,./?";
            undofile = true;
            ignorecase = true;
            smartcase = true;
            splitright = true;
            splitbelow = true;
            list = true;
            listchars = "tab:» ,trail:·,nbsp:␣";
            cursorline = true;
            scrolloff = 10;
            hlsearch = true;
          };

          # Theme Configuration - Catppuccin Macchiato with transparency
          theme = {
            enable = true;
            name = "catppuccin";
            style = "macchiato"; # This is the "machiato" you mentioned
            transparent = true; # Enable transparent background
          };

          # Statusline using mini.statusline
          statusline = {
            lualine.enable = false; # Disable lualine since we're using mini.statusline
          };

          # Enable web dev icons for better file icons
          visuals = {
            nvim-web-devicons.enable = true;
          };

          treesitter = {
            enable = true;
            highlight.enable = true;
            indent.enable = true;
            context = {
              enable = true;
              setupOpts = {
                max_lines = 3;
                multiline_threshold = 1;
                separator = null;
                line_numbers = true;
              };
            };
          };

          lsp = {
            enable = true;
            formatOnSave = true;
          };

          languages = {
            # Enable formatting for enabled languages
            enableFormat = true;

            # Enabled languages
            rust = {
              enable = true;
              treesitter.enable = true;
            };
            nix = {
              enable = true;
              treesitter.enable = true;
            };
            ts = {
              enable = true;
              treesitter.enable = true;
            };
            html = {
              enable = true;
              treesitter.enable = true;
            };
            css = {
              enable = true;
              treesitter.enable = true;
            };
            lua = {
              enable = true;
              treesitter.enable = true;
            };
            go = {
              enable = true;
              treesitter.enable = true;
            };
            python = {
              enable = true;
              treesitter.enable = true;
            };
            clang = {
              enable = true;
              treesitter.enable = true;
            };
            markdown = {
              extensions.render-markdown-nvim.enable = true;
              enable = true;
            };
            yaml = {
              enable = true;
              treesitter.enable = true;
            };
          };

          # Formatting
          formatter."conform-nvim" = {
            enable = true;
            setupOpts = {
              notify_on_error = false;
              format_on_save = {
                _type = "lua-inline";
                expr = ''
                  function(bufnr)
                    local disable_filetypes = { c = true, cpp = true }
                    return {
                      timeout_ms = 2000,
                      lsp_fallback = not disable_filetypes[vim.bo[bufnr].filetype],
                    }
                  end
                '';
              };
              formatters = {
                prettier = {
                  timeout_ms = 3000;
                  ignore_errors = true;
                };
              };

              formatters_by_ft = {
                javascript = ["prettier"];
                typescript = ["prettier"];
                javascriptreact = ["prettier"];
                typescriptreact = ["prettier"];
                svelte = ["prettier"];
                css = ["prettier"];
                html = ["prettier"];
                json = ["prettier"];
                yaml = ["prettier"];
                markdown = ["prettier"];
                graphql = ["prettier"];
                lua = ["stylua"];
                python = ["black"];
                rust = ["rustfmt"];
                nix = ["nixfmt"];
              };
            };
          };

          # Autocomplete with blink-cmp
          autocomplete."blink-cmp" = {
            enable = true;
            friendly-snippets.enable = true; # Enable for snippet suggestions

            mappings = {
              confirm = "<C-y>";
              next = "<C-n>";
              previous = "<C-p>";
              scrollDocsDown = "<C-d>";
              scrollDocsUp = "<C-u>";
              # close = "<C-e>"; # Default
              # complete = "<C-Space>"; # Default
            };

            sourcePlugins = {
              ripgrep = {enable = true;};
            };

            setupOpts = {
              enabled = {
                _type = "lua-inline";
                expr = ''
                  function()
                    return vim.bo.buftype ~= 'prompt' and vim.b.completion ~= false
                  end
                '';
              };
              completion = {
                accept = {
                  auto_brackets = {
                    kind_resolution = {
                      blocked_filetypes = ["typescriptreact" "javascriptreact" "vue" "codecompanion"];
                    };
                  };
                };
              };
              sources = {
                per_filetype = {
                  codecompanion = ["codecompanion" "buffer"]; # Include all desired sources
                };
              };
            };
          };

          # GitHub Copilot Configuration
          assistant.copilot = {
            enable = true;
            cmp.enable = false; # Keep this false since you're using blink-cmp

            # Explicitly enable suggestions in setupOpts
            setupOpts = {
              suggestion = {
                enabled = true;
                auto_trigger = true;
                debounce = 75;
                keymap = {
                  accept = false; # Let nvf handle keymaps
                  accept_word = false;
                  accept_line = false;
                  next = false;
                  prev = false;
                  dismiss = false;
                };
              };
              panel = {
                enabled = true;
                auto_refresh = false;
                keymap = {
                  jump_prev = false;
                  jump_next = false;
                  accept = false;
                  refresh = false;
                  open = false;
                };
              };
            };

            mappings = {
              suggestion = {
                accept = "<A-y>";
                next = "<A-n>";
                prev = "<A-p>";

                dismiss = "<A-d>";
                acceptWord = "<A-w>";
                acceptLine = "<A-l>";
              };
              panel = {
                open = "<A-CR>";
                accept = "<CR>";
                jumpNext = "]]";
                jumpPrev = "[[";
                refresh = "gr";
              };
            };
          };

          # CodeCompanion Configuration
          assistant."codecompanion-nvim" = {
            enable = true;
            setupOpts = {
              adapters = {
                _type = "lua-inline";

                # Model list https://codecompanion.olimorris.dev/usage/chat-buffer/agents#compatibility
                expr = ''
                  {
                    copilot = function()
                      return require('codecompanion.adapters').extend('copilot', {
                        schema = {
                          model = {
                            default = 'claude-sonnet-4',
                          },
                        },
                      })
                    end,
                  }
                '';
              };

              display = {
                chat = {
                  # Basic UI improvements
                  intro_message = "Welcome to CodeCompanion ✨! Press ? for options";
                  show_header_separator = true; # Show separators between messages
                  auto_scroll = true; # Auto-scroll as responses come in

                  # Show LLM model and settings at the top
                  show_settings = true; # This displays the model being used
                  show_token_count = true; # Show token usage
                  show_references = true; # Show references from slash commands

                  # Custom token count display function
                  token_count = {
                    _type = "lua-inline";
                    expr = ''
                      function(tokens, adapter)
                        return string.format(" 🤖 %s (%d tokens)", adapter.formatted_name, tokens)
                      end
                    '';
                  };

                  # Window styling
                  separator = "─"; # Visual separator between messages
                  window = {
                    layout = "vertical";
                    border = "rounded"; # Better looking border
                    height = 0.8;
                    width = 0.45;
                  };
                };
              };

              strategies = {
                chat = {
                  adapter = "copilot";
                  roles = {
                    _type = "lua-inline";
                    expr = ''
                      {
                        llm = function(adapter)
                          return string.format("🤖 %s (%s)", adapter.formatted_name, adapter.schema.model.default)
                        end,
                        user = "👤 Me"
                      }
                    '';
                  };
                  keymaps = {
                    close = {
                      modes = {n = "q";};
                      index = 3;
                      callback = "keymaps.close";
                      description = "Close Chat";
                    };
                    stop = {
                      modes = {n = "<C-c>";};
                      index = 4;
                      callback = "keymaps.stop";
                      description = "Stop Request";
                    };
                  };
                };
                inline = {
                  adapter = "copilot";
                };
              };

              # Extensions (mcphub)
              extensions = {
                mcphub = {
                  callback = "mcphub.extensions.codecompanion";
                  opts = {
                    show_result_in_chat = true;
                    make_vars = true;
                    make_slash_commands = true;
                    # FIX: Enable MCP server integration
                    auto_register_servers = true;
                  };
                };
              };
            };
          };

          # Telescope Configuration
          telescope = {
            enable = true;
            setupOpts = {
              extensions = {
                ui-select = {
                  # Note: nvf might prefer keys without dashes, but "ui-select" is standard for Telescope. If issues, try "ui_select".
                  # Configure the ui-select extension to use the dropdown theme
                  _type = "lua-inline";
                  expr = ''
                    require("telescope.themes").get_dropdown {
                      -- You can add more theme options here if needed, e.g.:
                      -- previewer = false,
                      -- winblend = 10,
                    }
                  '';
                };
                live_grep_args = {
                  auto_quoting = true;
                };
              };
            };
          };

          # Mini.nvim plugins configuration
          mini = {
            # Mini.files - File explorer
            files = {
              enable = true;
              setupOpts = {
                options = {
                  permanent_delete = true;
                  use_as_default_explorer = true;
                };
              };
            };

            colors.enable = true; # Enable mini.colors

            # Mini.surround - Surround text objects
            surround = {
              enable = true;
            };

            # Mini.comment - Smart commenting
            comment = {
              enable = true;
              setupOpts = {
                mappings = {
                  comment = "gb";
                  comment_line = "gbb";
                  comment_visual = "gb";
                  textobject = "gb";
                };
              };
            };

            # Mini.ai - Better around/inside textobjects
            ai = {
              enable = true;
              setupOpts = {
                n_lines = 500;
              };
            };

            # Mini.statusline - Simple statusline
            statusline = {
              enable = true;
              setupOpts = {
                use_icons = true; # Use icons if available
              };
            };

            # Mini.pairs - Auto pairs
            pairs = {
              enable = true;
              setupOpts = {};
            };

            # Mini.diff - Git diff visualization
            diff = {
              enable = true;
              setupOpts = {
                view = {
                  style = "sign";
                  signs = {
                    add = "▒";
                    change = "▒";
                    delete = "▒";
                  };
                  priority = 199;
                };
              };
            };
          };

          # Snacks.nvim configuration
          utility."snacks-nvim" = {
            enable = true;
            setupOpts = {
              bigfile = {enabled = true;};
              dashboard = {
                sections = [
                  {section = "header";}
                  # {
                  #   pane = 2;
                  #   section = "terminal";
                  #   cmd = "colorscript -e square";
                  #   height = 5;
                  #   padding = 1;
                  # }
                  {
                    section = "keys";
                    gap = 1;
                    padding = 1;
                  }
                  {
                    pane = 2;
                    icon = " ";
                    title = "Recent Files";
                    section = "recent_files";
                    indent = 2;
                    padding = 1;
                  }
                  {
                    pane = 2;
                    icon = " ";
                    title = "Projects";
                    section = "projects";
                    indent = 2;
                    padding = 1;
                  }
                  {
                    pane = 2;
                    icon = " ";
                    title = "Git Status";
                    section = "terminal";
                    enabled = {
                      _type = "lua-inline";
                      expr = "function() return Snacks.git.get_root() ~= nil end";
                    };
                    cmd = "git status --short --branch --renames";
                    height = 5;
                    padding = 1;
                    ttl = 300; # 5 * 60
                    indent = 3;
                  }
                  {section = "startup";}
                ];
                enabled = true;
              };
              indent = {enabled = false;};
              input = {enabled = true;};
              notifier = {
                enabled = true;
                timeout = 3000;
              };
              quickfile = {enabled = true;};
              scroll = {enabled = false;};
              statuscolumn = {enabled = true;};
              words = {enabled = true;};
              styles = {}; # Empty as in your Lua config
              terminal = {
                enabled = true;
              };
            };
          };

          # Harpoon Configuration
          navigation.harpoon = {
            enable = true;
            mappings = {
              markFile = "<leader>a";
              listMarks = "<leader>e";
              file1 = "<leader>1";
              file2 = "<leader>2";
              file3 = "<leader>3";
              file4 = "<leader>4";
            };
            setupOpts = {
              # If you had specific setupOpts in your Lua, they would go here.
              defaults = {
                save_on_toggle = true; # Example from your commented Lua
                sync_on_ui_close = true; # Example from your commented Lua
              };
            };
          };

          # Add this to your main configuration
          visuals.fidget-nvim = {
            enable = true;
            setupOpts = {
              progress = {
                poll_rate = 100; # Poll every 100ms for updates
                suppress_on_insert = true; # Don't show during insert mode
                ignore_done_already = false;
                ignore_empty_message = false;
                notification_group = {
                  _type = "lua-inline";
                  expr = ''
                    function(msg)
                      return msg.lsp_client.name
                    end
                  '';
                };
                # ignore = ["copilot"]; # Hide copilot LSP progress
                display = {
                  render_limit = 16;
                  done_ttl = 3; # How long completed messages persist
                  done_icon = "✓";
                  done_style = "Constant";
                  progress_ttl = 99999; # Keep progress messages visible
                  progress_icon = {
                    pattern = "dots";
                    period = 1;
                  };
                  progress_style = "WarningMsg";
                  group_style = "Title";
                  icon_style = "Question";
                  priority = 30;
                  skip_history = true;
                  format_message = {
                    _type = "lua-inline";
                    expr = ''
                      function(msg)
                        local title = msg.title or ""
                        local message = msg.message or ""
                        local percentage = msg.percentage and string.format(" (%s%%)", msg.percentage) or ""
                        return string.format("%s%s%s", title, message and (#message > 0 and ": " .. message or ""), percentage)
                      end
                    '';
                  };
                };
              };
              notification = {
                window = {
                  normal_hl = "Comment";
                  winblend = 100;
                  border = "none";
                  zindex = 45;
                  max_width = 0;
                  max_height = 0;
                  x_padding = 1;
                  y_padding = 0;
                  align = "bottom";
                  relative = "editor";
                };
              };
            };
          };

          # Custom keybindings and Lua configuration
          keymaps = [
            # Base neovim keymaps
            {
              key = "J";
              mode = "v";
              action = ":m '>+1<CR>gv=gv";
              desc = "Move line down";
            }
            {
              key = "K";
              mode = "v";
              action = ":m '<-2<CR>gv=gv";
              desc = "Move line up";
            }
            {
              key = "<leader>di";
              mode = "n";
              action = "<cmd>lua vim.diagnostic.open_float()<CR>";
              desc = "Show diagnostic Error messages";
            }
            {
              key = "<C-h>";
              mode = "n";
              action = "<cmd>TmuxNavigateLeft<cr>";
              desc = "Move focus to the left window";
            }
            {
              key = "<C-l>";
              mode = "n";
              action = "<cmd>TmuxNavigateRight<cr>";
              desc = "Move focus to the right window";
            }
            {
              key = "<C-j>";
              mode = "n";
              action = "<cmd>TmuxNavigateDown<cr>";
              desc = "Move focus to the lower window";
            }
            {
              key = "<C-k>";
              mode = "n";
              action = "<cmd>TmuxNavigateUp<cr>";
              desc = "Move focus to the upper window";
            }
            {
              key = "<leader>q";
              mode = "n";
              action = "<CMD>lua _G.toggle_quickfix()<CR>";
              desc = "Toggle quickfix list";
            }
            {
              key = "]q";
              mode = "n";
              action = ":cnext<CR>";
              desc = "Next quickfix item";
            }
            {
              key = "[q";
              mode = "n";
              action = ":cprev<CR>";
              desc = "Prev quickfix item";
            }
            {
              key = "<leader>qc";
              mode = "n";
              action = "<CMD>lua vim.fn.setqflist({}, 'f')<CR>";
              desc = "[Q]uickfix [C]lear";
            }
            # { key = "<Esc>"; mode = "n"; action = "<cmd>nohlsearch<CR>"; desc = "Clear search highlight"; silent = true; } # Overrides previous global <Esc> mapping if any

            # Window resizing keymaps
            {
              mode = "n";
              key = "<A-k>";
              action = ":resize +5<CR>";
              desc = "Increase window height";
            }
            {
              mode = "n";
              key = "<A-j";
              action = ":resize -5<CR>";
              desc = "Decrease window height";
            }
            {
              mode = "n";
              key = "<A-h";
              action = ":vertical resize -5<CR>";
              desc = "Decrease window width";
            }
            {
              mode = "n";
              key = "<A-l>";
              action = ":vertical resize +5<CR>";
              desc = "Increase window width";
            }

            #
            # Plugin keymaps
            #

            # Format code
            {
              key = "<leader>f";
              action = "<cmd>lua require('conform').format({ async = true, lsp_fallback = true })<CR>";
              mode = ["n" "v" "x" "o"];
              desc = "Format buffer";
              silent = true;
            }

            # Mini.files keybindings
            {
              key = "-";
              mode = "n";
              action = "<CMD>lua MiniFiles.open(vim.api.nvim_buf_get_name(0))<CR>";
              desc = "Open parent directory";
              silent = true;
            }
            {
              key = "<Esc>";
              mode = "n";
              action = "<CMD>lua MiniFiles.close()<CR>";
              desc = "Close MiniFiles";
              silent = true;
            }

            # Mini.map keybinding
            {
              key = "<leader>m";
              mode = "n";
              action = "<CMD>lua MiniMap.toggle()<CR>";
              desc = "Toggle minimap";
              silent = true;
            }

            # Mini.diff keybinding
            {
              key = "<leader>dt";
              mode = "n";
              action = "<CMD>lua MiniDiff.toggle_overlay()<CR>";
              desc = "MINI [D]iff [T]oggle";
              silent = true;
            }

            # CodeCompanion Global Keymaps
            {
              key = "<leader>ac";
              action = "<cmd>CodeCompanionActions<CR>";
              mode = ["n" "v"];
              silent = true;
              desc = "CodeCompanion actions";
            }
            {
              key = "<leader>aa";
              action = "<cmd>CodeCompanionChat Toggle<CR>";
              mode = ["n" "v"];
              silent = true;
              desc = "CodeCompanion chat";
            }
            {
              key = "<leader>ad";
              action = "<cmd>CodeCompanionChat Add<CR>";
              mode = ["v"];
              silent = true;
              desc = "CodeCompanion add to chat";
            }

            # Telescope keybindings
            {
              key = "<leader>sh";
              mode = "n";
              action = "<CMD>Telescope help_tags<CR>";
              desc = "[S]earch [H]elp";
              silent = true;
            }
            {
              key = "<leader>sk";
              mode = "n";
              action = "<CMD>Telescope keymaps<CR>";
              desc = "[S]earch [K]eymaps";
              silent = true;
            }
            {
              key = "<leader>sc";
              mode = "n";
              action = "<CMD>Telescope find_files<CR>";
              desc = "[S]earch [Current] Files";
              silent = true;
            }
            {
              key = "<leader>ss";
              mode = "n";
              action = "<CMD>Telescope builtin<CR>";
              desc = "[S]earch [S]elect Telescope";
              silent = true;
            }
            {
              key = "<leader>sw";
              mode = "n";
              action = "<CMD>Telescope grep_string<CR>";
              desc = "[S]earch current [W]ord";
              silent = true;
            }
            {
              key = "<leader>sg";
              mode = "n";
              action = "<CMD>lua require('telescope').extensions.live_grep_args.live_grep_args()<CR>";
              desc = "[S]earch by [G]rep";
              silent = true;
            }
            {
              key = "<leader>sd";
              mode = "n";
              action = "<CMD>Telescope diagnostics<CR>";
              desc = "[S]earch [D]iagnostics";
              silent = true;
            }
            {
              key = "<leader>sr";
              mode = "n";
              action = "<CMD>Telescope resume<CR>";
              desc = "[S]earch [R]esume";
              silent = true;
            }
            {
              key = "<leader><leader>";
              mode = "n";
              action = "<CMD>Telescope buffers<CR>";
              desc = "Find existing buffers";
              silent = true;
            }

            # Snacks.nvim Keymaps
            {
              key = "<leader>z";
              mode = "n";
              action = "<cmd>lua Snacks.zen()<CR>";
              desc = "Toggle Zen Mode";
              silent = true;
            }
            {
              key = "<leader>Z";
              mode = "n";
              action = "<cmd>lua Snacks.zen.zoom()<CR>";
              desc = "Toggle Zoom";
              silent = true;
            }
            {
              key = "<leader>.";
              mode = ["n" "v"];
              action = "<cmd>lua Snacks.scratch()<CR>";
              desc = "Toggle Scratch Buffer";
              silent = true;
            }
            {
              key = "<leader>S";
              mode = ["n" "v"];
              action = "<cmd>lua Snacks.scratch.select()<CR>";
              desc = "Select Scratch Buffer";
              silent = true;
            }
            {
              key = "<leader>n";
              mode = ["n" "v"];
              action = "<cmd>lua Snacks.notifier.show_history()<CR>";
              desc = "Notification History";
              silent = true;
            }
            {
              key = "<leader>bd";
              mode = "n";
              action = "<cmd>lua Snacks.bufdelete()<CR>";
              desc = "Delete Buffer";
              silent = true;
            }
            {
              key = "<leader>cR";
              mode = ["n" "v"];
              action = "<cmd>lua Snacks.rename.rename_file()<CR>";
              desc = "Rename File";
              silent = true;
            }
            {
              key = "<leader>gB";
              action = "<cmd>lua Snacks.gitbrowse()<CR>";
              desc = "Git Browse";
              mode = ["n" "v"];
              silent = true;
            }
            {
              key = "<leader>gg";
              mode = ["n" "v"];
              action = "<cmd>lua Snacks.lazygit()<CR>";
              desc = "Lazygit";
              silent = true;
            }
            {
              key = "<leader>gl";
              mode = ["n" "v"];
              action = "<cmd>lua Snacks.lazygit.log()<CR>";
              desc = "Lazygit Log (cwd)";
              silent = true;
            }
            {
              key = "<leader>un";
              mode = ["n" "v"];
              action = "<cmd>lua Snacks.notifier.hide()<CR>";
              desc = "Dismiss All Notifications";
              silent = true;
            }
            {
              key = "<leader>tt";
              action = "<cmd>lua _G.ToggleDevTerminal()<CR>";
              desc = "Toggle Dev Server Terminal";
              silent = true;
              mode = ["n" "v"];
            }
            # {
            #   key = "<leader>ai";
            #   action = ''
            #     <cmd>lua
            #     local width = vim.o.columns
            #     local height = vim.o.lines
            #     local win_height = math.floor(height * 0.9)
            #     local win_width = math.floor(width * 0.9)
            #     local row = math.floor((height - win_height) / 2)
            #     local col = math.floor((width - win_width) / 2)
            #     Snacks.terminal.toggle('aider --no-auto-commits --read CONVENTIONS.md --dark-mode --architect --yes-always', {
            #       win = {
            #         border = 'rounded',
            #         relative = 'editor',
            #         width = win_width,
            #         height = win_height,
            #         row = row,
            #         col = col,
            #         position = 'float',
            #       },
            #       env = { TERM_ID = '1' },
            #     })
            #     <CR>
            #   '';
            #   desc = "Toggle Aider Ai";
            #   mode = ["n" "v"];
            #   silent = true;
            # }
            {
              key = "]]";
              action = "<cmd>lua Snacks.words.jump(vim.v.count1)<CR>";
              desc = "Next Reference";
              mode = ["n" "t"];
              silent = true;
            } # mode 't' might need special handling if nvf keymaps don't directly support terminal mode.
            {
              key = "[[";
              action = "<cmd>lua Snacks.words.jump(-vim.v.count1)<CR>";
              desc = "Prev Reference";
              mode = ["n" "t"];
              silent = true;
            } # mode 't' might need special handling.
          ];

          # Additional Lua configuration for advanced setups
          luaConfigRC = {
            # Base neovim config

            highlight-yank-autocmd = ''
              vim.api.nvim_create_autocmd('TextYankPost', {
                desc = 'Highlight when yanking (copying) text',
                group = vim.api.nvim_create_augroup('highlight-yank', { clear = true }), -- Use group name from original Lua
                callback = function()
                  vim.highlight.on_yank()
                end,
              })
            '';
            quickfix-delete-item-autocmd = ''
              local function del_qf_item()
                local items = vim.fn.getqflist()
                if #items == 0 then return end
                local cursor_pos = vim.api.nvim_win_get_cursor(0)
                local line = cursor_pos[1]

                -- qf list is 1-indexed, ensure line is valid
                if line == 0 or line > #items then return end

                table.remove(items, line)
                vim.fn.setqflist({}, 'r', { items = items })

                local new_line = math.min(line, #items)
                -- Only set cursor if list not empty and new_line is valid (greater than 0)
                if new_line > 0 and #items > 0 then
                   vim.api.nvim_win_set_cursor(0, { new_line, 0 }) -- Set to column 0 as in original Lua
                end
              end

              vim.api.nvim_create_autocmd('FileType', {
                pattern = 'qf',
                callback = function()
                  vim.keymap.set('n', 'dd', del_qf_item, { buffer = true, desc = 'Remove QF item' })
                end,
              })
            '';
            toggle-quickfix-function = ''
              -- Make the function global to be callable from keymap
              _G.toggle_quickfix = function()
                local is_open = false
                for _, win in ipairs(vim.fn.getwininfo()) do
                  if win.quickfix == 1 then
                    is_open = true
                    break
                  end
                end
                if is_open then
                  vim.cmd 'cclose'
                else
                  vim.cmd 'copen'
                end
              end
            '';
            checktime-autocmd = ''
              vim.api.nvim_create_autocmd({ 'FocusGained', 'BufEnter', 'CursorHold' }, {
                pattern = '*',
                command = 'silent! checktime',
              })
            '';

            # LSP Attach Keymaps and Custom Hover
            lsp-attach-keymaps = ''
              vim.api.nvim_create_autocmd('LspAttach', {
                group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
                callback = function(event)
                  local map = function(keys, func, desc)
                    vim.keymap.set('n', keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
                  end

                  map('gd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')
                  map('gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')
                  map('gI', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')
                  map('<leader>D', require('telescope.builtin').lsp_type_definitions, 'Type [D]efinition')
                  map('<leader>ds', require('telescope.builtin').lsp_document_symbols, '[D]ocument [S]ymbols')
                  map('<leader>ws', require('telescope.builtin').lsp_dynamic_workspace_symbols, '[W]orkspace [S]ymbols')
                  map('<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')
                  map('<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction')
                  map('gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

                  map('<leader>th', function()
                    vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf }, { bufnr = event.buf })
                  end, '[T]oggle Inlay [H]ints')

                  local function hover_without_notification()
                    local orig_notify = vim.notify
                    vim.notify = function(msg, level, opts)
                      if msg ~= 'No information available' then
                        orig_notify(msg, level, opts)
                      end
                    end
                    vim.lsp.buf.hover()
                    vim.defer_fn(function()
                      vim.notify = orig_notify
                    end, 100) -- Reduced delay slightly, 1000ms is quite long for this.
                  end

                  map('K', hover_without_notification, 'Hover Documentation')
                end,
              })
            '';

            #
            # Plugin config
            #

            # Setup ts-context-commentstring for better JSX/TSX comments
            mini-comment-setup = ''
              -- Comment setup "ts-context-commentstring" is needed for jsx comments
              vim.g.skip_ts_context_commentstring_module = true

              -- Override mini.comment setup for custom commentstring
              local mini_comment = require('mini.comment')
              mini_comment.setup({
                options = {
                  custom_commentstring = function()
                    -- Try to use ts-context-commentstring if available
                    local ok, ts_context = pcall(require, 'ts_context_commentstring.internal')
                    if ok then
                      return ts_context.calculate_commentstring() or vim.bo.commentstring
                    end
                    return vim.bo.commentstring
                  end,
                  ignore_blank_line = false,
                  start_of_line = false,
                  pad_comment_parts = true,
                },
                mappings = {
                  comment = 'gb',
                  comment_line = 'gbb',
                  comment_visual = 'gb',
                  textobject = 'gb',
                },
              })
            '';

            # Setup mini.statusline with custom location format
            mini-statusline-setup = ''
              local statusline = require('mini.statusline')
              statusline.setup({ use_icons = vim.g.have_nerd_font or true })

              -- Custom location format: LINE:COLUMN
              statusline.section_location = function()
                return '%2l:%-2v'
              end
            '';

            # Telescope custom configuration
            telescope-setup = ''
              local telescope = require('telescope')
              local builtin = require('telescope.builtin')


              -- Load extensions
              pcall(telescope.load_extension, 'fzf')
              pcall(telescope.load_extension, 'ui-select')
              pcall(telescope.load_extension, 'live_grep_args')

              -- Custom telescope functions
              vim.keymap.set('n', '<leader>/', function()
                builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
                  winblend = 10,
                  previewer = false,
                })
              end, { desc = '[/] Fuzzily search in current buffer' })

              vim.keymap.set('n', '<leader>s/', function()
                builtin.live_grep {
                  grep_open_files = true,
                  prompt_title = 'Live Grep in Open Files',
                }
              end, { desc = '[S]earch [/] in Open Files' })

              vim.keymap.set('n', '<leader>s.', function()
                builtin.find_files {
                  cwd = vim.fn.expand '~/.dotfiles/',
                  hidden = true, -- to show hidden files
                  follow = true, -- to follow symlinks
                  no_ignore = false, -- respect gitignore
                  search_dirs = { vim.fn.expand '~/.dotfiles/' },
                }
              end, { desc = '[S]earch [.]dotfiles' })
            '';

            # Snacks.nvim init function content
            snacks-init = ''
              vim.api.nvim_create_autocmd('User', {
                pattern = 'VeryLazy',
                callback = function()
                  -- Setup some globals for debugging (lazy-loaded)
                  _G.dd = function(...)
                    Snacks.debug.inspect(...)
                  end
                  _G.bt = function()
                    Snacks.debug.backtrace()
                  end
                  vim.print = _G.dd -- Override print to use snacks for `:=` command
                  -- Create some toggle mappings
                  Snacks.toggle.option('wrap', { name = 'Wrap' }):map '<leader>uw'
                  Snacks.toggle.option('conceallevel', { off = 0, on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2 }):map '<leader>uc'
                  Snacks.toggle.option('background', { off = 'light', on = 'dark', name = 'Dark Background' }):map '<leader>ub'
                  Snacks.toggle.inlay_hints():map '<leader>uh'
                  Snacks.toggle.indent():map '<leader>ug'
                end,
              })
            '';

            toggle-dev-terminal-function = ''
              _G.ToggleDevTerminal = function()
                Snacks.terminal.toggle(nil, {
                  win = {
                    border = 'rounded',
                    relative = 'editor',
                    width = math.floor(vim.o.columns * 0.9),
                    height = math.floor(vim.o.lines * 0.9),
                    row = math.floor((vim.o.lines - math.floor(vim.o.lines * 0.9)) / 2),
                    col = math.floor((vim.o.columns - math.floor(vim.o.columns * 0.9)) / 2),
                    position = 'float',
                  },
                  env = { TERM_ID = '9999' },
                })
              end
            '';
          };

          extraPlugins = {
            mcphub = {
              package = mcphub-nvim-plugin;
              # The `build` step for npm install is ignored here; user handles CLI install.
              # The `config` function from Lua spec is translated to `setup` string:
              setup = ''
                local status_ok, mcphub = pcall(require, "mcphub")
                if not status_ok then
                  vim.notify("mcphub.nvim plugin could not be required. Ensure mcp-hub CLI is installed globally and in PATH.", vim.log.levels.ERROR)
                  return
                end
                mcphub.setup({}) -- Pass options if needed, e.g. { config = { auto_approve = true } }
              '';
            };
            # Add telescope extensions here instead of extraPackages
            telescope-ui-select = {
              package = pkgs.vimPlugins.telescope-ui-select-nvim;
              # No setup needed - loaded via luaConfigRC
            };
            telescope-live-grep-args = {
              package = pkgs.vimPlugins.telescope-live-grep-args-nvim;
              # No setup needed - loaded via luaConfigRC
            };
            blink-compat = {
              package = unstable.vimPlugins.blink-compat;
            };
            vim-tmux-navigator = {
              package = pkgs.vimPlugins.vim-tmux-navigator;
              setup = ''
                -- Plugin setup handled in luaConfigRC or keymaps
              '';
              # No setup needed - loaded via luaConfigRC
            };
          };

          # Extra packages needed
          extraPackages = with pkgs; [
            ripgrep # Required for telescope live grep
            fd # Better find command for telescope
            unstable.vimPlugins.blink-compat
            vimPlugins.telescope-ui-select-nvim
            vimPlugins.telescope-live-grep-args-nvim # ADD THIS - it was missing
            vimPlugins.vim-tmux-navigator
            # Add any additional packages you might need
          ];
        };
      };
    };
  }
