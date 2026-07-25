local capabilities = require("blink.cmp").get_lsp_capabilities()

vim.api.nvim_create_user_command("LspInfo", function()
	vim.cmd("checkhealth vim.lsp")
end, { desc = "Show LSP server status", force = true })

local hover = vim.lsp.buf.hover
---@diagnostic disable-next-line: duplicate-set-field
vim.lsp.buf.hover = function()
	return hover({ border = "rounded", title = "LSP", title_pos = "left" })
end

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

vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("kickstart-lsp-attach", { clear = true }),
	callback = function(event)
		local map = function(keys, func, desc)
			vim.keymap.set("n", keys, func, { buffer = event.buf, desc = "LSP: " .. desc })
		end

		map("gd", function()
			Snacks.picker.lsp_definitions()
		end, "[G]oto [D]efinition")
		map("gr", function()
			Snacks.picker.lsp_references()
		end, "[G]oto [R]eferences")
		map("gI", function()
			Snacks.picker.lsp_implementations()
		end, "[G]oto [I]mplementation")
		map("<leader>D", function()
			Snacks.picker.lsp_type_definitions()
		end, "Type [D]efinition")
		map("<leader>ds", function()
			Snacks.picker.lsp_symbols()
		end, "[D]ocument [S]ymbols")
		map("<leader>ws", function()
			Snacks.picker.lsp_workspace_symbols()
		end, "[W]orkspace [S]ymbols")
		map("<leader>rn", vim.lsp.buf.rename, "[R]e[n]ame")
		map("<leader>ca", vim.lsp.buf.code_action, "[C]ode [A]ction")
		map("gD", vim.lsp.buf.declaration, "[G]oto [D]eclaration")

		local client = vim.lsp.get_client_by_id(event.data.client_id)
		if client and client.server_capabilities.inlayHintProvider then
			vim.lsp.inlay_hint.enable(false, { bufnr = event.buf })
			map("<leader>th", function()
				vim.lsp.inlay_hint.enable(
					not vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf }),
					{ bufnr = event.buf }
				)
			end, "[T]oggle Inlay [H]ints")
		end

		map("K", function()
			local orig_notify = vim.notify
			vim.notify = function(msg, level, opts)
				if msg ~= "No information available" then
					orig_notify(msg, level, opts)
				end
			end
			vim.lsp.buf.hover()
			vim.defer_fn(function()
				vim.notify = orig_notify
			end, 100)
		end, "Hover Documentation")
	end,
})

local function configure(server, opts)
	opts = vim.tbl_deep_extend("force", { capabilities = capabilities }, opts or {})
	vim.lsp.config(server, opts)
end

configure("gopls")
configure("pyright")
configure("rust_analyzer")
configure("tailwindcss")
configure("nil_ls")
configure("clangd")
configure("html")
configure("cssls")
configure("jsonls")
configure("yamlls")

configure("lua_ls", {
	settings = {
		Lua = {
			runtime = { version = "LuaJIT", path = vim.split(package.path, ";") },
			diagnostics = { globals = { "vim", "Snacks" } },
			workspace = { library = vim.api.nvim_get_runtime_file("", true), checkThirdParty = false },
			telemetry = { enable = false },
		},
	},
})

configure("eslint", {
	settings = { workingDirectory = { mode = "auto" } },
})

-- Add this file at a project root to use typescript-language-server instead of tsgo.

-- Switch to legacy ts_ls:
--
-- touch .ts-lsp-legacy
--
-- Switch back to TypeScript Go:
--
-- rm .ts-lsp-legacy
local legacy_ts_marker = ".ts-lsp-legacy"
local tsgo_root_dir = vim.lsp.config.tsgo.root_dir

configure("tsgo", {
	root_dir = function(bufnr, on_dir)
		if vim.fs.root(bufnr, { legacy_ts_marker }) then
			return
		end

		tsgo_root_dir(bufnr, on_dir)
	end,
})

configure("ts_ls", {
	filetypes = {
		"javascript",
		"javascriptreact",
		"javascript.jsx",
		"typescript",
		"typescriptreact",
		"typescript.tsx",
	},
	root_dir = function(bufnr, on_dir)
		local root = vim.fs.root(bufnr, { legacy_ts_marker })
		if root then
			on_dir(root)
		end
	end,
})

configure("svelte", {
	filetypes = { "svelte" },
	root_markers = { "svelte.config.js", "svelte.config.ts", "package.json", ".git" },
	settings = {
		svelte = {
			plugin = {
				svelte = { enable = true },
				typescript = { enable = true },
				css = { enable = true },
			},
		},
	},
})

vim.lsp.enable({
	"gopls",
	"pyright",
	"rust_analyzer",
	"tailwindcss",
	"lua_ls",
	"nil_ls",
	"eslint",
	"tsgo",
	"ts_ls",
	"svelte",
	"clangd",
	"html",
	"cssls",
	"jsonls",
	"yamlls",
})
