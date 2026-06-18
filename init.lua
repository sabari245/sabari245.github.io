-- ============================================================================
-- Minimal Neovim Config with lazy.nvim
-- ============================================================================

-- Set leader key before anything else
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

-- Disable netrw (default file explorer)
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

-- ============================================================================
-- Basic Options
-- ============================================================================
vim.opt.number = true -- Show line numbers
vim.opt.mouse = "a" -- Enable mouse
vim.opt.ignorecase = true -- Ignore case in search
vim.opt.smartcase = true -- Unless uppercase is used
vim.opt.hlsearch = false -- Don't highlight searches
vim.opt.wrap = false -- No line wrap
vim.opt.breakindent = true -- Maintain indent when wrapping
vim.opt.tabstop = 4 -- Tabs are 4 spaces
vim.opt.shiftwidth = 4 -- Indent with 4 spaces
vim.opt.expandtab = true -- Use spaces instead of tabs
vim.opt.termguicolors = true -- True color support
vim.opt.signcolumn = "yes" -- Always show sign column
vim.opt.updatetime = 250 -- Faster completion
vim.opt.timeoutlen = 300 -- Faster key sequence completion
vim.opt.splitright = true -- Vertical splits go right
vim.opt.splitbelow = true -- Horizontal splits go below
vim.opt.undofile = true -- Persistent undo
vim.opt.clipboard = "unnamedplus" -- Use system clipboard

-- Clipboard provider selection:
-- - Local sessions use Neovim's native provider detection (wl-copy on Wayland,
--   xclip/xsel on X11, etc.), whether or not they are inside tmux.
-- - SSH sessions use OSC 52 so remote Neovim can reach the local terminal
--   clipboard. This also works through tmux when tmux clipboard passthrough is
--   enabled.
if vim.env.SSH_TTY then
	vim.g.clipboard = "osc52"
end

-- ============================================================================
-- Basic Keymaps (non-plugin)
-- ============================================================================
local keymap = vim.keymap.set

-- Better window navigation
keymap("n", "<C-h>", "<C-w>h", { desc = "Go to left window" })
keymap("n", "<C-j>", "<C-w>j", { desc = "Go to lower window" })
keymap("n", "<C-k>", "<C-w>k", { desc = "Go to upper window" })
keymap("n", "<C-l>", "<C-w>l", { desc = "Go to right window" })

-- Split management
keymap("n", "<leader>|", ":vsplit<CR>", { desc = "Vertical split", silent = true })
keymap("n", "<leader>-", ":split<CR>", { desc = "Horizontal split", silent = true })
keymap("n", "<leader>q", ":close<CR>", { desc = "Close split", silent = true })

-- Resize splits with Ctrl + Arrow keys
keymap("n", "<C-Up>", ":resize +2<CR>", { desc = "Increase height", silent = true })
keymap("n", "<C-Down>", ":resize -2<CR>", { desc = "Decrease height", silent = true })
keymap("n", "<C-Left>", ":vertical resize -2<CR>", { desc = "Decrease width", silent = true })
keymap("n", "<C-Right>", ":vertical resize +2<CR>", { desc = "Increase width", silent = true })

-- Buffer navigation
keymap("n", "<S-l>", ":bnext<CR>", { desc = "Next buffer", silent = true })
keymap("n", "<S-h>", ":bprevious<CR>", { desc = "Previous buffer", silent = true })
keymap("n", "<leader>bd", ":bdelete<CR>", { desc = "Delete buffer", silent = true })

-- Better indenting
keymap("v", "<", "<gv")
keymap("v", ">", ">gv")

-- Move text up and down
keymap("v", "J", ":m '>+1<CR>gv=gv", { silent = true })
keymap("v", "K", ":m '<-2<CR>gv=gv", { silent = true })

-- Keep cursor centered when scrolling
keymap("n", "<C-d>", "<C-d>zz")
keymap("n", "<C-u>", "<C-u>zz")
keymap("n", "n", "nzzzv")
keymap("n", "N", "Nzzzv")

-- Clear search highlighting
keymap("n", "<Esc>", ":noh<CR>", { silent = true })

-- ============================================================================
-- Terminal Management
-- ============================================================================
local Terminal = {
	terminals = {}, -- Store terminal buffers: { bufnr, name }
	current_win = nil, -- Current terminal window
	last_terminal_idx = 0, -- Last active terminal index
}

-- Check if a buffer is a terminal
local function is_terminal_buffer(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	return vim.bo[bufnr].buftype == "terminal"
end

-- Get next terminal number (checks all buffers to avoid name collisions)
local function get_next_terminal_number()
	local num = 1
	while true do
		local name_taken = false
		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			local ok, buf_name = pcall(vim.api.nvim_buf_get_name, buf)
			if ok and buf_name:match("Terminal " .. num .. "$") then
				name_taken = true
				break
			end
		end
		if not name_taken then
			return num
		end
		num = num + 1
	end
end

-- Clean up closed terminals from the list
local function cleanup_terminals()
	local valid_terminals = {}
	for _, term in ipairs(Terminal.terminals) do
		if vim.api.nvim_buf_is_valid(term.bufnr) then
			table.insert(valid_terminals, term)
		end
	end
	Terminal.terminals = valid_terminals
end

-- Create a new terminal
local function create_terminal()
	cleanup_terminals()
	local num = get_next_terminal_number()

	-- Create split at bottom
	vim.cmd("botright 15split")
	vim.cmd("terminal")

	local bufnr = vim.api.nvim_get_current_buf()
	local name = "Terminal " .. num

	-- Set buffer name
	vim.api.nvim_buf_set_name(bufnr, name)

	-- Store terminal info
	table.insert(Terminal.terminals, { bufnr = bufnr, num = num, name = name })
	Terminal.last_terminal_idx = #Terminal.terminals
	Terminal.current_win = vim.api.nvim_get_current_win()

	-- Enter insert mode
	vim.cmd("startinsert")

	return bufnr
end

-- Toggle terminal visibility
local function toggle_terminal()
	cleanup_terminals()

	-- Check if we're in a terminal window
	if is_terminal_buffer() then
		-- Hide the terminal window
		vim.cmd("hide")
		Terminal.current_win = nil
		return
	end

	-- Check if terminal window is visible
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local bufnr = vim.api.nvim_win_get_buf(win)
		if is_terminal_buffer(bufnr) then
			-- Terminal is visible, focus it
			vim.api.nvim_set_current_win(win)
			Terminal.current_win = win
			vim.cmd("startinsert")
			return
		end
	end

	-- No terminal visible, show last used or create new
	if #Terminal.terminals > 0 then
		local idx = Terminal.last_terminal_idx
		if idx < 1 or idx > #Terminal.terminals then
			idx = #Terminal.terminals
		end
		local term = Terminal.terminals[idx]

		if vim.api.nvim_buf_is_valid(term.bufnr) then
			vim.cmd("botright 15split")
			vim.api.nvim_win_set_buf(0, term.bufnr)
			Terminal.current_win = vim.api.nvim_get_current_win()
			vim.cmd("startinsert")
			return
		end
	end

	-- No valid terminal, create new one
	create_terminal()
end

-- Open a new terminal (always creates a new one)
local function new_terminal()
	cleanup_terminals()

	-- If currently in a terminal window, just create in place
	if is_terminal_buffer() then
		local current_win = vim.api.nvim_get_current_win()
		create_terminal()
		-- Close the split that create_terminal made and use the existing window
		vim.cmd("close")
		vim.api.nvim_set_current_win(current_win)
		vim.cmd("terminal")
		local bufnr = vim.api.nvim_get_current_buf()
		local num = get_next_terminal_number()
		local name = "Terminal " .. num
		vim.api.nvim_buf_set_name(bufnr, name)
		-- Update the last entry
		Terminal.terminals[#Terminal.terminals] = { bufnr = bufnr, num = num, name = name }
		vim.cmd("startinsert")
	else
		create_terminal()
	end
end

-- Kill current terminal
local function kill_terminal()
	if not is_terminal_buffer() then
		vim.notify("Not in a terminal buffer", vim.log.levels.WARN)
		return
	end

	local bufnr = vim.api.nvim_get_current_buf()

	-- Find and remove from list
	for i, term in ipairs(Terminal.terminals) do
		if term.bufnr == bufnr then
			table.remove(Terminal.terminals, i)
			break
		end
	end

	-- Force close the buffer
	vim.cmd("bdelete!")

	-- Update last terminal index
	if Terminal.last_terminal_idx > #Terminal.terminals then
		Terminal.last_terminal_idx = #Terminal.terminals
	end

	cleanup_terminals()
end

-- Terminal keymaps
-- Ctrl + t to toggle terminal
keymap({ "n", "t" }, "<C-t>", function()
	toggle_terminal()
end, { desc = "Toggle terminal", silent = true })

-- <leader>tn to open new terminal
keymap({ "n", "t" }, "<leader>tn", function()
	new_terminal()
end, { desc = "New terminal", silent = true })

-- <leader>tk to kill terminal
keymap({ "n", "t" }, "<leader>tk", function()
	kill_terminal()
end, { desc = "Kill terminal", silent = true })

-- Easy escape from terminal mode
keymap("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

-- Make Terminal available globally for telescope
_G.TerminalManager = Terminal
_G.is_terminal_buffer = is_terminal_buffer

-- ============================================================================
-- Install lazy.nvim
-- ============================================================================
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable",
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)

-- ============================================================================
-- Plugin Specifications
-- ============================================================================
local plugins = {
	-- Colorscheme
	{
		"EdenEast/nightfox.nvim",
		lazy = false,
		priority = 1000,
		config = function()
			vim.cmd([[colorscheme carbonfox]])
		end,
	},

	-- Telescope for fuzzy finding
	{
		"nvim-telescope/telescope.nvim",
		cmd = "Telescope",
		keys = {
			{ "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "Find files" },
			{ "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "Live grep" },
			{
				"<leader>fb",
				function()
					local pickers = require("telescope.pickers")
					local finders = require("telescope.finders")
					local conf = require("telescope.config").values
					local actions = require("telescope.actions")
					local action_state = require("telescope.actions.state")

					-- Check if current buffer is a terminal
					local in_terminal = _G.is_terminal_buffer()

					-- Get all buffers
					local buffers = {}
					for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
						if vim.api.nvim_buf_is_loaded(bufnr) then
							local is_term = vim.bo[bufnr].buftype == "terminal"
							local filetype = vim.bo[bufnr].filetype
							local name = vim.api.nvim_buf_get_name(bufnr)

							-- Skip NvimTree buffers
							if filetype == "NvimTree" then
								goto continue
							end

							-- Filter based on context
							if in_terminal and is_term then
								-- In terminal: show only terminals
								local display_name = name:match("term://.*//.*:(.*)") or name
								if display_name == "" then
									display_name = "Terminal " .. bufnr
								end
								-- Try to get our custom name
								for _, term in ipairs(_G.TerminalManager.terminals) do
									if term.bufnr == bufnr then
										display_name = term.name
										break
									end
								end
								table.insert(buffers, { bufnr = bufnr, name = display_name })
							elseif not in_terminal and not is_term and name ~= "" then
								-- In file: show only file buffers (non-terminal, with name)
								local display_name = vim.fn.fnamemodify(name, ":~:.")
								table.insert(buffers, { bufnr = bufnr, name = display_name })
							end

							::continue::
						end
					end

					if #buffers == 0 then
						vim.notify(
							in_terminal and "No terminal buffers open" or "No file buffers open",
							vim.log.levels.INFO
						)
						return
					end

					pickers
						.new({}, {
							prompt_title = in_terminal and "Terminal Buffers" or "File Buffers",
							finder = finders.new_table({
								results = buffers,
								entry_maker = function(entry)
									return {
										value = entry,
										display = entry.name,
										ordinal = entry.name,
										bufnr = entry.bufnr,
									}
								end,
							}),
							sorter = conf.generic_sorter({}),
							attach_mappings = function(prompt_bufnr, map)
								actions.select_default:replace(function()
									actions.close(prompt_bufnr)
									local selection = action_state.get_selected_entry()
									if selection then
										vim.api.nvim_set_current_buf(selection.bufnr)
										if vim.bo[selection.bufnr].buftype == "terminal" then
											vim.cmd("startinsert")
										end
									end
								end)
								return true
							end,
						})
						:find()
				end,
				desc = "Find buffers (smart)",
			},
			{ "<leader>fG", "<cmd>Telescope git_files<cr>", desc = "Git files" },
			{ "<leader>fh", "<cmd>Telescope help_tags<cr>", desc = "Help tags" },
			{ "<leader>fr", "<cmd>Telescope oldfiles<cr>", desc = "Recent files" },
		},
		config = function()
			require("telescope").setup({
				defaults = {
					layout_strategy = "horizontal",
					layout_config = {
						prompt_position = "top",
					},
					sorting_strategy = "ascending",
				},
			})
		end,
		dependencies = { "nvim-lua/plenary.nvim" },
	},

	-- Treesitter for better syntax highlighting
	{
		"nvim-treesitter/nvim-treesitter",
		event = { "BufReadPost", "BufNewFile" },
		build = ":TSUpdate",
		config = function()
			local ok, configs = pcall(require, "nvim-treesitter.configs")
			if ok then
				configs.setup({
					ensure_installed = { "lua", "python", "rust", "toml", "vim", "vimdoc", "markdown" },
					highlight = { enable = true },
					indent = { enable = true },
				})
			end
		end,
	},

	-- Mason for LSP installation
	{
		"williamboman/mason.nvim",
		cmd = { "Mason", "MasonInstall", "MasonUninstall", "MasonUninstallAll", "MasonLog" },
		config = function()
			require("mason").setup({
				ui = {
					border = "rounded",
				},
			})
		end,
	},

	-- Mason LSP config
	{
		"williamboman/mason-lspconfig.nvim",
		event = { "BufReadPre", "BufNewFile" },
		dependencies = { "williamboman/mason.nvim" },
		config = function()
			require("mason-lspconfig").setup({
				ensure_installed = { "pyright", "rust_analyzer" },
				automatic_installation = true,
			})
		end,
	},

	-- LSP Config (Neovim 0.11+ native API)
	{
		"neovim/nvim-lspconfig",
		event = { "BufReadPre", "BufNewFile" },
		dependencies = { "williamboman/mason-lspconfig.nvim" },
		config = function()
			-- LSP keymaps via LspAttach autocmd
			vim.api.nvim_create_autocmd("LspAttach", {
				callback = function(args)
					local opts = { buffer = args.buf }
					keymap("n", "gd", vim.lsp.buf.definition, vim.tbl_extend("force", opts, { desc = "Go to definition" }))
					keymap("n", "gD", vim.lsp.buf.declaration, vim.tbl_extend("force", opts, { desc = "Go to declaration" }))
					keymap("n", "gr", vim.lsp.buf.references, vim.tbl_extend("force", opts, { desc = "Go to references" }))
					keymap("n", "gi", vim.lsp.buf.implementation, vim.tbl_extend("force", opts, { desc = "Go to implementation" }))
					keymap("n", "K", vim.lsp.buf.hover, vim.tbl_extend("force", opts, { desc = "Hover documentation" }))
					keymap("n", "<leader>rn", vim.lsp.buf.rename, vim.tbl_extend("force", opts, { desc = "Rename" }))
					keymap("n", "<leader>ca", vim.lsp.buf.code_action, vim.tbl_extend("force", opts, { desc = "Code action" }))
					keymap("n", "[d", vim.diagnostic.goto_prev, vim.tbl_extend("force", opts, { desc = "Previous diagnostic" }))
					keymap("n", "]d", vim.diagnostic.goto_next, vim.tbl_extend("force", opts, { desc = "Next diagnostic" }))
				end,
			})

			-- Python LSP
			vim.lsp.config("pyright", {
				settings = {
					python = {
						analysis = {
							typeCheckingMode = "basic",
							autoSearchPaths = true,
							useLibraryCodeForTypes = true,
						},
					},
				},
			})

			-- Rust LSP
			vim.lsp.config("rust_analyzer", {
				settings = {
					["rust-analyzer"] = {
						checkOnSave = {
							command = "clippy",
						},
						cargo = {
							allFeatures = true,
						},
						procMacro = {
							enable = true,
						},
					},
				},
			})

			-- Enable the LSPs
			vim.lsp.enable({ "pyright", "rust_analyzer" })
		end,
	},

	-- Python venv selector
	{
		"linux-cultist/venv-selector.nvim",
		cmd = { "VenvSelect", "VenvSelectCached" },
		keys = {
			{ "<leader>vs", "<cmd>VenvSelect<cr>", desc = "Select VirtualEnv" },
		},
		config = function()
			require("venv-selector").setup({
				auto_refresh = true,
			})
		end,
	},

	-- Completion
	{
		"hrsh7th/nvim-cmp",
		event = "InsertEnter",
		dependencies = {
			"hrsh7th/cmp-nvim-lsp",
			"hrsh7th/cmp-buffer",
			"hrsh7th/cmp-path",
		},
		config = function()
			local cmp = require("cmp")

			cmp.setup({
				mapping = cmp.mapping.preset.insert({
					["<C-b>"] = cmp.mapping.scroll_docs(-4),
					["<C-f>"] = cmp.mapping.scroll_docs(4),
					["<C-Space>"] = cmp.mapping.complete(),
					["<C-e>"] = cmp.mapping.abort(),
					["<CR>"] = cmp.mapping.confirm({ select = true }),
					["<Tab>"] = cmp.mapping.select_next_item(),
					["<S-Tab>"] = cmp.mapping.select_prev_item(),
				}),
				sources = cmp.config.sources({
					{ name = "nvim_lsp" },
					{ name = "path" },
				}, {
					{ name = "buffer" },
				}),
			})
		end,
	},

	-- File explorer (opens as full buffer, not sidebar)
	{
		"nvim-tree/nvim-tree.lua",
		lazy = false,
		priority = 999,
		keys = {
			{
				"<leader>e",
				function()
					local api = require("nvim-tree.api")
					-- Check if nvim-tree is open
					local nvim_tree_open = false
					for _, win in ipairs(vim.api.nvim_list_wins()) do
						local buf = vim.api.nvim_win_get_buf(win)
						if vim.bo[buf].filetype == "NvimTree" then
							nvim_tree_open = true
							-- Close it
							api.tree.close()
							break
						end
					end
					if not nvim_tree_open then
						-- Open in current window (full buffer)
						api.tree.open({ current_window = true })
					end
				end,
				desc = "Toggle file explorer",
			},
		},
		dependencies = { "nvim-tree/nvim-web-devicons" },
		config = function()
			require("nvim-tree").setup({
				hijack_cursor = true,
				view = {
					width = 30,
				},
				renderer = {
					group_empty = true,
				},
				filters = {
					dotfiles = false,
				},
				actions = {
					open_file = {
						quit_on_open = true, -- Close tree when opening a file
					},
				},
			})
		end,
	},

	-- Comment
	{
		"numToStr/Comment.nvim",
		keys = {
			{ "gcc", mode = "n", desc = "Comment line" },
			{ "gc", mode = "v", desc = "Comment selection" },
		},
		config = function()
			require("Comment").setup()
		end,
	},

	-- Enhanced text objects
	{
		"echasnovski/mini.ai",
		event = { "BufReadPost", "BufNewFile" },
		config = function()
			require("mini.ai").setup()
		end,
	},

	-- Auto pairs
	{
		"windwp/nvim-autopairs",
		event = "InsertEnter",
		config = function()
			require("nvim-autopairs").setup({})

			-- Integration with cmp
			local cmp_autopairs = require("nvim-autopairs.completion.cmp")
			local cmp = require("cmp")
			cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
		end,
	},

	-- Statusline
	{
		"nvim-lualine/lualine.nvim",
		event = "VeryLazy",
		dependencies = { "nvim-tree/nvim-web-devicons" },
		config = function()
			require("lualine").setup({
				options = {
					theme = "carbonfox",
					component_separators = "|",
					section_separators = "",
				},
			})
		end,
	},
}

-- ============================================================================
-- Load lazy.nvim
-- ============================================================================
require("lazy").setup(plugins)

-- ============================================================================
-- Python-specific settings
-- ============================================================================
vim.api.nvim_create_autocmd("FileType", {
	pattern = "python",
	callback = function()
		vim.opt_local.tabstop = 4
		vim.opt_local.shiftwidth = 4
		vim.opt_local.expandtab = true
	end,
})

-- ============================================================================
-- Markdown and text file settings
-- ============================================================================
vim.api.nvim_create_autocmd("FileType", {
	pattern = { "markdown", "text" },
	callback = function()
		vim.opt_local.wrap = true
		vim.opt_local.linebreak = true -- Wrap at word boundaries
	end,
})

-- ============================================================================
-- :Keybindings command
-- ============================================================================
vim.api.nvim_create_user_command("Keybindings", function()
	local bindings = {
		"── Navigation ──────────────────────────────",
		"C-h/j/k/l          Window navigation",
		"S-h / S-l           Previous / Next buffer",
		"C-d / C-u           Scroll down / up (centered)",
		"n / N               Next / prev search (centered)",
		"",
		"── Splits ──────────────────────────────────",
		"<leader>|           Vertical split",
		"<leader>-           Horizontal split",
		"<leader>q           Close split",
		"C-Up/Down           Resize height",
		"C-Left/Right        Resize width",
		"",
		"── Buffers ─────────────────────────────────",
		"<leader>bd          Delete buffer",
		"",
		"── Editing ─────────────────────────────────",
		"< / > (visual)      Indent and reselect",
		"J / K (visual)      Move lines up / down",
		"gcc / gc            Comment line / selection",
		"Esc                 Clear search highlight",
		"C-x C-e             Edit command in $EDITOR",
		"",
		"── Terminal ────────────────────────────────",
		"C-t                 Toggle terminal",
		"<leader>tn          New terminal",
		"<leader>tk          Kill terminal",
		"Esc Esc             Exit terminal mode",
		"",
		"── Telescope ───────────────────────────────",
		"<leader>ff          Find files",
		"<leader>fg          Live grep",
		"<leader>fG          Git files",
		"<leader>fb          Smart buffer picker",
		"<leader>fh          Help tags",
		"<leader>fr          Recent files",
		"",
		"── File Explorer ───────────────────────────",
		"<leader>e           Toggle nvim-tree",
		"",
		"── LSP ─────────────────────────────────────",
		"gd / gD             Definition / Declaration",
		"gr / gi             References / Implementation",
		"K                   Hover docs",
		"<leader>rn          Rename",
		"<leader>ca          Code action",
		"[d / ]d             Prev / Next diagnostic",
		"",
		"── Python ──────────────────────────────────",
		"<leader>vs          Select virtualenv",
	}

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, bindings)
	vim.bo[buf].modifiable = false
	vim.bo[buf].bufhidden = "wipe"

	local width = 50
	local height = #bindings
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		col = math.floor((vim.o.columns - width) / 2),
		row = math.floor((vim.o.lines - height) / 2),
		style = "minimal",
		border = "rounded",
		title = " Keybindings ",
		title_pos = "center",
	})

	-- Press q or Esc to close
	vim.keymap.set("n", "q", ":close<CR>", { buffer = buf, silent = true })
	vim.keymap.set("n", "<Esc>", ":close<CR>", { buffer = buf, silent = true })
end, {})

print("✓ Minimal config loaded!")
