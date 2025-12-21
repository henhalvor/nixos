{
  config,
  pkgs,
  system,
  nvf,
  lib,
  inputs,
  unstable,
  pkgs24-11,
  ...
}: let
  # Use nixpkgs 24.11 to build the plugin to avoid the require check issues
  neocodeium-nvim-plugin = pkgs24-11.vimUtils.buildVimPlugin {
    name = "neocodeium-nvim-from-source";
    src = pkgs24-11.fetchFromGitHub {
      owner = "monkoose";
      repo = "neocodeium";
      rev = "v1.16.3";
      sha256 = "sha256-UemmcgQbdTDYYh8BCCjHgr/wQ8M7OH0ef6MBMHfOJv8=";
    };
  };

  agentic-nvim-plugin = pkgs24-11.vimUtils.buildVimPlugin {
    name = "agentic-nvim-from-source";
    src = pkgs24-11.fetchFromGitHub {
      owner = "carlos-algms";
      repo = "agentic.nvim";
      rev = "7267e166abd3db6a087a337df8cda4765d87e7aa";
      sha256 = "sha256-4gH+098OhzSDy9UQFvkfr/G/Tyt0tXnMxE+/lNgTQl4=";
    };
  };
in {
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
          cursorline = true;
          scrolloff = 10;
          hlsearch = true;
        };

        # Theme Configuration - Catppuccin Macchiato with transparency
        theme = {
          enable = true;
          name = lib.mkForce "gruvbox";
          style = "dark"; # This is the "macchiato" you mentioned
          transparent = lib.mkForce true; # Enable transparent background
        };

        # Statusline using mini.statusline
        statusline = {
          lualine.enable = false; # Disable lualine since we're using mini.statusline
        };

        # Enable web dev icons for better file icons
        visuals = {
          nvim-web-devicons.enable = true;
          nvim-cursorline.setupOpts.cursorword.hl.underline = lib.mkForce false;
        };

        treesitter = {
          enable = true;
          highlight.enable = true;
          indent.enable = true;
          context = {
            enable = false;
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
            format.type = ["prettierd"];
            # format.package = pkgs.prettierd;
          };
          tailwind = {
            enable = true;
            lsp.enable = true;
          };
          html = {
            enable = true;
            treesitter.enable = true;
          };
          css = {
            enable = true;
            treesitter.enable = true;
            # format.package = pkgs.prettierd;
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
          svelte = {
            enable = true;
            treesitter.enable = true;
            # format.package = pkgs.prettierd;
            format.enable = true;
            lsp.enable = true;
            extraDiagnostics.enable = true;
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
                package = pkgs.prettierd;
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
              menu = {
                border = "rounded"; # Match diagnostics/LSP windows
              };
              documentation = {
                window = {
                  border = "rounded"; # Match diagnostics/LSP windows
                };
              };
            };
            sources = {
              default = ["lsp" "buffer" "path" "snippets"]; # LSP first
              providers = {
                lsp = {
                  score_offset = 100; # Prioritize LSP
                };
                buffer = {
                  score_offset = 50;
                };
                path = {
                  score_offset = 3;
                };
                snippets = {
                  score_offset = -3;
                };
              };
              per_filetype = {
                codecompanion = ["codecompanion" "buffer"];
              };
            };
          };
        };

        # # GitHub Copilot Configuration
        # assistant.copilot = {
        #   enable = true;
        #   cmp.enable = false; # Keep this false since you're using blink-cmp
        #
        #   # Explicitly enable suggestions in setupOpts
        #   setupOpts = {
        #     suggestion = {
        #       enabled = true;
        #       auto_trigger = true;
        #       debounce = 75;
        #       keymap = {
        #         accept = false; # Let nvf handle keymaps
        #         accept_word = false;
        #         accept_line = false;
        #         next = false;
        #         prev = false;
        #         dismiss = false;
        #       };
        #     };
        #     panel = {
        #       enabled = true;
        #       auto_refresh = false;
        #       keymap = {
        #         jump_prev = false;
        #         jump_next = false;
        #         accept = false;
        #         refresh = false;
        #         open = false;
        #       };
        #     };
        #   };
        #
        #   mappings = {
        #     suggestion = {
        #       accept = "<A-y>";
        #       next = "<A-n>";
        #       prev = "<A-p>";
        #
        #       dismiss = "<A-d>";
        #       acceptWord = "<A-w>";
        #       acceptLine = "<A-l>";
        #     };
        #     panel = {
        #       open = "<A-CR>";
        #       accept = "<CR>";
        #       jumpNext = "]]";
        #       jumpPrev = "[[";
        #       refresh = "gr";
        #     };
        #   };
        # };
        #
        # # CodeCompanion Configuration
        # assistant."codecompanion-nvim" = {
        #   enable = true;
        #   setupOpts = {
        #     adapters = {
        #       _type = "lua-inline";
        #
        #       # Model list https://codecompanion.olimorris.dev/usage/chat-buffer/agents#compatibility
        #       expr = ''
        #         {
        #           copilot = function()
        #             return require('codecompanion.adapters').extend('copilot', {
        #               schema = {
        #                 model = {
        #                   default = 'claude-sonnet-4',
        #                 },
        #               },
        #             })
        #           end,
        #         }
        #       '';
        #     };
        #
        #     display = {
        #       chat = {
        #         # Basic UI improvements
        #         intro_message = "Welcome to CodeCompanion ✨! Press ? for options";
        #         show_header_separator = true; # Show separators between messages
        #         auto_scroll = true; # Auto-scroll as responses come in
        #
        #         # Show LLM model and settings at the top
        #         show_settings = true; # This displays the model being used
        #         show_token_count = true; # Show token usage
        #         show_references = true; # Show references from slash commands
        #
        #         # Custom token count display function
        #         token_count = {
        #           _type = "lua-inline";
        #           expr = ''
        #             function(tokens, adapter)
        #               return string.format(" 🤖 %s (%d tokens)", adapter.formatted_name, tokens)
        #             end
        #           '';
        #         };
        #
        #         # Window styling
        #         separator = "─"; # Visual separator between messages
        #         window = {
        #           layout = "vertical";
        #           border = "rounded"; # Better looking border
        #           height = 0.8;
        #           width = 0.45;
        #         };
        #       };
        #     };
        #
        #     strategies = {
        #       chat = {
        #         adapter = "copilot";
        #         roles = {
        #           _type = "lua-inline";
        #           expr = ''
        #             {
        #               llm = function(adapter)
        #                 return string.format("🤖 %s (%s)", adapter.formatted_name, adapter.schema.model.default)
        #               end,
        #               user = "👤 Me"
        #             }
        #           '';
        #         };
        #         keymaps = {
        #           close = {
        #             modes = {n = "q";};
        #             index = 3;
        #             callback = "keymaps.close";
        #             description = "Close Chat";
        #           };
        #           stop = {
        #             modes = {n = "<C-c>";};
        #             index = 4;
        #             callback = "keymaps.stop";
        #             description = "Stop Request";
        #           };
        #         };
        #       };
        #       inline = {
        #         adapter = "copilot";
        #       };
        #     };
        #
        #     # Extensions (mcphub)
        #     extensions = {
        #       mcphub = {
        #         callback = "mcphub.extensions.codecompanion";
        #         opts = {
        #           show_result_in_chat = true;
        #           make_vars = true;
        #           make_slash_commands = true;
        #           # FIX: Enable MCP server integration
        #           auto_register_servers = true;
        #         };
        #       };
        #     };
        #   };
        # };

        # Telescope Configuration (disabled - using snacks.picker)
        # telescope = {
        #   enable = true;
        #   setupOpts = {
        #     extensions = {
        #       ui-select = {
        #         # Note: nvf might prefer keys without dashes, but "ui-select" is standard for Telescope. If issues, try "ui_select".
        #         # Configure the ui-select extension to use the dropdown theme
        #         _type = "lua-inline";
        #         expr = ''
        #           require("telescope.themes").get_dropdown {
        #             -- You can add more theme options here if needed, e.g.:
        #             -- previewer = false,
        #             -- winblend = 10,
        #           }
        #         '';
        #       };
        #       live_grep_args = {
        #         auto_quoting = true;
        #       };
        #     };
        #   };
        # };

        utility = {
          motion = {
            flash-nvim = {
              enable = true;
              mappings = {
                jump = "<CR>";
                treesitter = "<leader><CR>";
                remote = null;
                toggle = null;
                treesitter_search = null;
              };
            };
          };

          yazi-nvim = {
            enable = true;
            mappings.openYazi = "-";
            setupOpts.open_for_directories = true;
          };
        };
        # Mini.nvim plugins configuration
        mini = {
          # Mini.files - File explorer
          # files = {
          #   enable = true;
          #   setupOpts = {
          #     options = {
          #       permanent_delete = true;
          #       use_as_default_explorer = true;
          #     };
          #   };
          # };

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
            picker = {
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
          # {
          #   key = "-";
          #   mode = "n";
          #   action = "<CMD>lua MiniFiles.open(vim.api.nvim_buf_get_name(0))<CR>";
          #   desc = "Open parent directory";
          #   silent = true;
          # }
          # {
          #   key = "<Esc>";
          #   mode = "n";
          #   action = "<CMD>lua MiniFiles.close()<CR>";
          #   desc = "Close MiniFiles";
          #   silent = true;
          # }

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
          # {
          #   key = "<leader>ac";
          #   action = "<cmd>CodeCompanionActions<CR>";
          #   mode = ["n" "v"];
          #   silent = true;
          #   desc = "CodeCompanion actions";
          # }
          # {
          #   key = "<leader>aa";
          #   action = "<cmd>CodeCompanionChat Toggle<CR>";
          #   mode = ["n" "v"];
          #   silent = true;
          #   desc = "CodeCompanion chat";
          # }
          # {
          #   key = "<leader>ad";
          #   action = "<cmd>CodeCompanionChat Add<CR>";
          #   mode = ["v"];
          #   silent = true;
          #   desc = "CodeCompanion add to chat";
          # }

          # Snacks Picker keybindings
          {
            key = "<leader>sh";
            mode = "n";
            action = "<cmd>lua Snacks.picker.help()<CR>";
            desc = "[S]earch [H]elp";
            silent = true;
          }
          {
            key = "<leader>sk";
            mode = "n";
            action = "<cmd>lua Snacks.picker.keymaps()<CR>";
            desc = "[S]earch [K]eymaps";
            silent = true;
          }
          {
            key = "<leader>sc";
            mode = "n";
            action = "<cmd>lua Snacks.picker.files()<CR>";
            desc = "[S]earch [Current] Files";
            silent = true;
          }
          {
            key = "<leader>ss";
            mode = "n";
            action = "<cmd>lua Snacks.picker.pickers()<CR>";
            desc = "[S]earch [S]elect Picker";
            silent = true;
          }
          {
            key = "<leader>sw";
            mode = "n";
            action = "<cmd>lua Snacks.picker.grep_word()<CR>";
            desc = "[S]earch current [W]ord";
            silent = true;
          }
          {
            key = "<leader>sg";
            mode = "n";
            action = "<cmd>lua Snacks.picker.grep()<CR>";
            desc = "[S]earch by [G]rep";
            silent = true;
          }
          {
            key = "<leader>sd";
            mode = "n";
            action = "<cmd>lua Snacks.picker.diagnostics()<CR>";
            desc = "[S]earch [D]iagnostics";
            silent = true;
          }
          # {
          #   key = "<leader>sr";
          #   mode = "n";
          #   action = "<cmd>lua Snacks.picker.resume()<CR>";
          #   desc = "[S]earch [R]esume";
          #   silent = true;
          # }
          {
            key = "<leader><leader>";
            mode = "n";
            action = "<cmd>lua Snacks.picker.buffers()<CR>";
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
          lsp-and-diagnostics-borders = ''
            -- LSP hover with rounded borders
            		local hover = vim.lsp.buf.hover
            		---@diagnostic disable-next-line: duplicate-set-field
            		vim.lsp.buf.hover = function()
            			---@diagnostic disable-next-line: redundant-parameter
            			return hover({
            				-- max_width = 100,
            				-- max_height = 14,
            				border = "rounded",
            				title = "LSP",
            				title_pos = "left",
            			})
            		end

            		-- Diagnostic config
            		vim.diagnostic.config({
            			severity_sort = true,
            			float = { border = "rounded", source = true },
            			underline = { severity = vim.diagnostic.severity.ERROR },
            			signs = vim.g.have_nerd_font and {
            				text = {
            					[vim.diagnostic.severity.ERROR] = "󰅚 ",
            					[vim.diagnostic.severity.WARN] = "󰀪 ",
            					[vim.diagnostic.severity.INFO] = "󰋽 ",
            					[vim.diagnostic.severity.HINT] = "󰌶 ",
            				},
            			} or {},
            			virtual_text = {
            				source = "if_many",
            				spacing = 2,
            				format = function(diagnostic)
            					return diagnostic.message
            				end,
            			},
            		})
          '';

          # Base neovim config
          correct-rendering-of-tabs = ''
            vim.opt.listchars = { tab = "  ", trail = "·", nbsp = "␣" } -- Tab is two spaces, trailing spaces are shown as dots, non-breaking spaces as a special character
          '';

          restore-cursor-position-in-previous-editing-session-autocmd = ''
            vim.api.nvim_create_autocmd("BufReadPost", {
              callback = function(args)
                local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
                local line_count = vim.api.nvim_buf_line_count(args.buf)
                if mark[1] > 0 and mark[1] <= line_count then
                  vim.api.nvim_win_set_cursor(0, mark)
                  -- defer centering slightly so it's applied after render
                  vim.schedule(function()
                    vim.cmd("normal! zz")
                  end)
                end
              end,
            })
          '';

          open-help-in-vertical-split-autocmd = ''
            vim.api.nvim_create_autocmd("FileType", {
              pattern = "help",
              command = "wincmd L",
            })
          '';

          auto-rezise-splits-when-terminal-window-is-rezised-autocmd = ''
            vim.api.nvim_create_autocmd("VimResized", {
              command = "wincmd =",
            })
          '';

          no-auto-continue-comments-on-new-line-autocmd = ''
            vim.api.nvim_create_autocmd("FileType", {
              group = vim.api.nvim_create_augroup("no_auto_comment", {}),
              callback = function()
                vim.opt_local.formatoptions:remove({ "c", "r", "o" })
              end,
            })
          '';

          dotenv-files-syntax-highlighting-autocmd = ''
            vim.api.nvim_create_autocmd("BufRead", {
              group = vim.api.nvim_create_augroup("dotenv_ft", { clear = true }),
              pattern = { ".env", ".env.*" },
              callback = function()
                vim.bo.filetype = "dosini"
              end,
            })
          '';

          show-cursorline-only-in-active-window-autocmd = ''
            -- show cursorline only in active window enable
            vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter" }, {
              group = vim.api.nvim_create_augroup("active_cursorline", { clear = true }),
              callback = function()
                vim.opt_local.cursorline = true
              end,
            })
            -- show cursorline only in active window disable
            vim.api.nvim_create_autocmd({ "WinLeave", "BufLeave" }, {
             group = "active_cursorline",
              callback = function()
               vim.opt_local.cursorline = false
              end,
            })
          '';

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

                map('gd', function() Snacks.picker.lsp_definitions() end, '[G]oto [D]efinition')
                map('gr', function() Snacks.picker.lsp_references() end, '[G]oto [R]eferences')
                map('gI', function() Snacks.picker.lsp_implementations() end, '[G]oto [I]mplementation')
                map('<leader>D', function() Snacks.picker.lsp_type_definitions() end, 'Type [D]efinition')
                map('<leader>ds', function() Snacks.picker.lsp_symbols() end, '[D]ocument [S]ymbols')
                map('<leader>ws', function() Snacks.picker.lsp_workspace_symbols() end, '[W]orkspace [S]ymbols')
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

          # Snacks picker
          snacks-picker-layout = ''
            -- Configure snacks picker layout
              Snacks.config.picker = {
                layout = "custom",
                layouts = {
                  custom = {
                    layout = {
                       box = "vertical",
                       backdrop = false,
                       row = -1,
                       width = 0,
                       height = 0.4,
                       border = "none",
                       title = " {title} {live} {flags}",
                       title_pos = "left",
                       {
                         box = "horizontal",
                         { win = "list", border = "rounded" },
                         { win = "preview", title = "{preview}", width = 0.6, border = "rounded" },
                       },
                       { win = "input", height = 1, border = "none" },
                          }
                        }
                      }
                    }

          '';

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
            local statusline = require("mini.statusline")
            -- set use_icons to true if you have a Nerd Font
            statusline.setup({ use_icons = vim.g.have_nerd_font })
            -- You can configure sections in the statusline by overriding their
            -- default behavior. For example, here we set the section for
            -- cursor location to LINE:COLUMN
            ---@diagnostic disable-next-line: duplicate-set-field
            -- statusline.section_location = function()
            -- 	return "%2l:%-2v"
            -- end
            --
            -- Minimal sections
            statusline.section_location = function()
              return "%2l:%-2v"
            end

            -- Hide or simplify other sections
            statusline.section_filename = function()
              return "%f" -- Just filename without path/flags
            end

            statusline.section_fileinfo = function()
              return "" -- Hide file info (encoding, type)
            end

            statusline.section_searchcount = function()
              return "" -- Hide search count
            end

            statusline.section_git = function()
              return "" -- Hide git info
            end

            statusline.section_diagnostics = function()
              return "" -- Hide diagnostics
            end

            vim.api.nvim_create_autocmd("ColorScheme", {
              callback = function()
                vim.api.nvim_set_hl(0, "MiniStatuslineFilename", { fg = "#ebdbb2", bold = true })
                vim.api.nvim_set_hl(0, "MiniStatuslineDevinfo", { fg = "#ebdbb2" })
                vim.api.nvim_set_hl(0, "StatusLine", { bg = "NONE" })
                vim.api.nvim_set_hl(0, "StatusLineNC", { bg = "NONE" })
              end,
            })

            vim.defer_fn(function()
              vim.api.nvim_set_hl(0, "MiniStatuslineFilename", { fg = "#ebdbb2", bold = true })
              vim.api.nvim_set_hl(0, "MiniStatuslineDevinfo", { fg = "#ebdbb2" })
              vim.api.nvim_set_hl(0, "StatusLine", { bg = "NONE" })
              vim.api.nvim_set_hl(0, "StatusLineNC", { bg = "NONE" })
            end, 100)

          '';

          # Snacks Picker custom configuration
          snacks-picker-setup = ''
            -- Custom snacks.picker functions
            vim.keymap.set('n', '<leader>/', function()
              Snacks.picker.lines()
            end, { desc = '[/] Fuzzily search in current buffer' })

            vim.keymap.set('n', '<leader>s/', function()
              Snacks.picker.grep_buffers()
            end, { desc = '[S]earch [/] in Open Files' })

            vim.keymap.set('n', '<leader>s.', function()
              Snacks.picker.files({
                cwd = vim.fn.expand '~/.dotfiles/',
                hidden = true,
              })
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

          # Colorscheme persistence and dynamic switching
          colorscheme-persistence = ''
            local function save_colorscheme(name)
              local path = vim.fn.stdpath("data") .. "/colorscheme.tmp.lua"
              local file = io.open(path, "w")
              if file then
                file:write("vim.cmd([[colorscheme " .. name .. "]])\n")
                file:close()
              end
            end

            vim.api.nvim_create_autocmd("ColorScheme", {
              callback = function(args)
                save_colorscheme(args.match)
              end,
            })

            vim.api.nvim_create_autocmd("VimEnter", {
              callback = function()
                vim.defer_fn(function()
                  local colorscheme_config = vim.fn.stdpath("data") .. "/colorscheme.tmp.lua"
                  if vim.fn.filereadable(colorscheme_config) == 1 then
                    dofile(colorscheme_config)
                  end
                end, 100)
              end,
            })
          '';

          snacks-colorscheme-picker = ''
            vim.keymap.set("n", "<leader>cs", function()
              Snacks.picker.pick({
                prompt = "Select Colorscheme",
                format = "text",
                items = {
                  { text = "catppuccin" },
                  { text = "gruvbox-baby" },
                  { text = "gruvbox-material" },
                  { text = "rose-pine" },
                  { text = "tokyonight" },
                  { text = "kanagawa" },
                  { text = "nord" },
                  { text = "nightfox" },
                  { text = "dawnfox" },
                  { text = "duskfox" },
                  { text = "nordfox" },
                  { text = "terafox" },
                  { text = "carbonfox" },
                  { text = "onedark" },
                  { text = "dracula" },
                  { text = "everforest" },
                  { text = "sonokai" },
                  { text = "oxocarbon" },
                  { text = "melange" },
                  { text = "cyberdream" },
                  { text = "vscode" },
                  { text = "github_dark" },
                  { text = "github_dark_dimmed" },
                  { text = "github_light" },
                },
                preview = function(picker, item)
                  if item then
                    pcall(vim.cmd.colorscheme, item.text)
                  end
                end,
                actions = {
                  confirm = function(picker, item)
                    if item then
                      vim.cmd.colorscheme(item.text)
                      picker:close()
                    end
                  end,
                },
              })
            end, { desc = "[S]earch [T]heme" })
          '';
        };

        extraPlugins = {
          # Telescope extensions (disabled - using snacks.picker)
          # telescope-ui-select = {
          #   package = pkgs.vimPlugins.telescope-ui-select-nvim;
          #   # No setup needed - loaded via luaConfigRC
          # };
          # telescope-live-grep-args = {
          #   package = pkgs.vimPlugins.telescope-live-grep-args-nvim;
          #   # No setup needed - loaded via luaConfigRC
          # };
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

          barbecue-nvim = {
            package = pkgs.vimPlugins.barbecue-nvim;
            setup = "require('barbecue').setup {}";
          };

          nvim-osc52 = {
            package = pkgs.vimPlugins.nvim-osc52;
            setup = ''
              local osc52 = require("osc52")

              -- Auto-copy any yanked text to clipboard
              vim.api.nvim_create_autocmd("TextYankPost", {
                callback = function()
                  if vim.v.event.operator == "y" and vim.v.event.regname == "" then
                   osc52.copy_register("")
                  end
                end,
              })
            '';
          };

          persistence-nvim = {
            package = pkgs.vimPlugins.persistence-nvim;
            setup = ''
                -- Auto-load session on startup
                vim.api.nvim_create_autocmd("VimEnter", {
                  group = vim.api.nvim_create_augroup("restore_session", { clear = true }),
                  callback = function()
                    -- Check if we should auto-load session
                    local should_load = false

                    if vim.fn.argc() == 0 then
                    -- No arguments passed (nvim)
                    should_load = true
                  elseif vim.fn.argc() == 1 then
                    -- Check if the single argument is current directory
                    local arg = vim.fn.argv(0)
                    if arg == "." or arg == vim.fn.getcwd() then
                      should_load = true
                    end
                  end

                  if should_load and vim.fn.getcwd() ~= vim.env.HOME then
                    require("persistence").load()
                  end
                end,
                nested = true,
              })

              require("persistence").setup(opts)
              -- load the session for the current directory
              vim.keymap.set("n", "<leader>qs", function()
                require("persistence").load()
              end, { desc = "Persistence load session for current directory" })

              -- select a session to load
              vim.keymap.set("n", "<leader>qS", function()
                require("persistence").select()
              end, { desc = "Persistence [S]elect" })

              -- load the last session
              vim.keymap.set("n", "<leader>ql", function()
                require("persistence").load({ last = true })
              end, { desc = "Persistence [L]oad last session" })

              -- stop Persistence => session won't be saved on exit
              vim.keymap.set("n", "<leader>qd", function()
                require("persistence").stop()
              end, { desc = "Persistence Stop" })
            '';
          };

          grug-far-nvim = {
            package = pkgs.vimPlugins.grug-far-nvim;
            setup = ''
              require("grug-far").setup(opts)
                  vim.api.nvim_create_autocmd("FileType", {
                    pattern = "grug-far",
                    callback = function()
                        -- Map <Esc> to quit after ensuring we're in normal mode
                        vim.keymap.set({ "n" }, "<Esc>", "<Cmd>stopinsert | bd!<CR>", { buffer = true })
                      end,
                    })

                vim.keymap.set("n", "<leader>sr", function()
                  local grug = require("grug-far")
                  local ext = vim.bo.buftype == "" and vim.fn.expand("%:e")
                  grug.open({
                    transient = true,
                    prefills = {
                      filesFilter = ext and ext ~= "" and "*." .. ext or nil,
                    },
                  })
                end, { desc = "Grug Far Search and Replace" })
            '';
          };

          # gruvbox-baby = {
          #   package = pkgs.vimPlugins.gruvbox-baby;
          #   setup = ''
          #     vim.g.gruvbox_baby_transparent_mode = true
          #   '';
          # };

          # gruvbox-material = {
          #   package = pkgs.vimPlugins.gruvbox-material;
          #   setup = ''
          #     vim.g.gruvbox_material_transparent_background = 2
          #   '';
          # };

          neocodeium = {
            package = neocodeium-nvim-plugin;
            # The `build` step for npm install is ignored here; user handles CLI install.
            # The `config` function from Lua spec is translated to `setup` string:
            setup = ''
              local neocodeium = require 'neocodeium'
              neocodeium.setup {
                manual = false,
              }
              vim.keymap.set('i', '<A-y>', function()
                require('neocodeium').accept()
              end)
              vim.keymap.set('i', '<A-w>', function()
                require('neocodeium').accept_word()
              end)
              vim.keymap.set('i', '<A-a>', function()
                require('neocodeium').accept_line()
              end)
              vim.keymap.set('i', '<A-n>', function()
                require('neocodeium').cycle_or_complete()
              end)
              vim.keymap.set('i', '<A-p>', function()
                require('neocodeium').cycle_or_complete(-1)
              end)
              vim.keymap.set('i', '<A-c>', function()
                require('neocodeium').clear()
              end)
            '';
          };

          agentic-nvim = {
            package = agentic-nvim-plugin;
            setup = ''
              opts = {
                provider = "opencode-acp"
              }

              require("agentic").setup(opts)

              vim.keymap.set({ "n", "i"}, '<leader>aa', function()
                require('agentic').toggle()
              end)

              vim.keymap.set({ "n", "v"}, '<leader>a+', function()
                require('agentic').add_selection_or_file_to_context()
              end)

              vim.keymap.set({ "n", "i"}, '<leader>an', function()
                require('agentic').new_session()
              end)
            '';
          };

          # Theme plugins for dynamic switching
          catppuccin-nvim = {
            package = pkgs.vimPlugins.catppuccin-nvim;
            setup = ''
              require("catppuccin").setup({
                flavour = "macchiato",
                background = {
                  light = "macchiato",
                  dark = "macchiato",
                },
                transparent_background = true,
                integrations = {
                  cmp = true,
                  treesitter = true,
                  noice = false,
                  notify = true,
                  which_key = false,
                  fidget = true,
                },
              })
            '';
          };

          rose-pine = {
            package = pkgs.vimPlugins.rose-pine;
            setup = ''
              require("rose-pine").setup({
                styles = {
                  transparency = true,
                },
                disable_background = true,
              })
            '';
          };

          gruvbox-baby = {
            package = pkgs.vimPlugins.gruvbox-baby;
            setup = ''
              -- vim.g.gruvbox_baby_transparent_mode = true
            '';
          };

          gruvbox-material = {
            package = pkgs.vimPlugins.gruvbox-material;
            setup = ''
              vim.g.gruvbox_material_transparent_background = 2
            '';
          };

          tokyonight-nvim = {
            package = pkgs.vimPlugins.tokyonight-nvim;
            setup = ''
              require("tokyonight").setup({
                style = "night",
                transparent = true,
                styles = {
                  sidebars = "transparent",
                  floats = "transparent",
                },
              })
            '';
          };

          kanagawa-nvim = {
            package = pkgs.vimPlugins.kanagawa-nvim;
            setup = ''
              require("kanagawa").setup({
                transparent = true,
                theme = "wave",
              })
            '';
          };

          nord-nvim = {
            package = pkgs.vimPlugins.nord-nvim;
            setup = ''
              vim.g.nord_disable_background = true
            '';
          };

          nightfox-nvim = {
            package = pkgs.vimPlugins.nightfox-nvim;
            setup = ''
              require("nightfox").setup({
                options = {
                  transparent = true,
                },
              })
            '';
          };

          onedark-nvim = {
            package = pkgs.vimPlugins.onedark-nvim;
            setup = ''
              require("onedark").setup({
                style = "dark",
                transparent = true,
              })
            '';
          };

          dracula-nvim = {
            package = pkgs.vimPlugins.dracula-nvim;
            setup = ''
              require("dracula").setup({
                transparent_bg = true,
              })
            '';
          };

          everforest = {
            package = pkgs.vimPlugins.everforest;
            setup = ''
              vim.g.everforest_background = "hard"
              vim.g.everforest_transparent_background = 2
            '';
          };

          sonokai = {
            package = pkgs.vimPlugins.sonokai;
            setup = ''
              vim.g.sonokai_style = "atlantis"
              vim.g.sonokai_transparent_background = 2
            '';
          };

          oxocarbon-nvim = {
            package = pkgs.vimPlugins.oxocarbon-nvim;
            setup = ''
              vim.opt.background = "dark"
            '';
          };

          melange-nvim = {
            package = pkgs.vimPlugins.melange-nvim;
            setup = "";
          };

          cyberdream-nvim = {
            package = pkgs.vimPlugins.cyberdream-nvim;
            setup = ''
              require("cyberdream").setup({
                transparent = true,
                italic_comments = true,
              })
            '';
          };

          vscode-nvim = {
            package = pkgs.vimPlugins.vscode-nvim;
            setup = ''
              require("vscode").setup({
                transparent = true,
              })
            '';
          };

          github-nvim-theme = {
            package = pkgs.vimPlugins.github-nvim-theme;
            setup = ''
              require("github-theme").setup({
                options = {
                  transparent = true,
                },
              })
            '';
          };
        };

        # Extra packages needed
        extraPackages = with pkgs; [
          prettierd
          ripgrep # Required for snacks.picker grep
          fd # Better find command for snacks.picker
          unstable.vimPlugins.blink-compat
          # Telescope extensions (disabled - using snacks.picker)
          # vimPlugins.telescope-ui-select-nvim
          # vimPlugins.telescope-live-grep-args-nvim
          vimPlugins.vim-tmux-navigator
          vimPlugins.barbecue-nvim
          vimPlugins.nvim-osc52
          vimPlugins.grug-far-nvim
          vimPlugins.persistence-nvim

          # Use this if "built in" persistence is not working
          # vimPlugins.persistence-nvim
          # Add any additional packages you might need
        ];
      };
    };
  };
}
