return {
	{
		"nvim-telescope/telescope-ui-select.nvim",
		"dawsers/telescope-floaterm.nvim",
	},
	{
		"nvim-telescope/telescope.nvim",
		tag = "0.1.5",
		dependencies = { "nvim-lua/plenary.nvim" },
		config = function()
			require("telescope").setup({
				defaults = {
					file_ignore_patterns = {},
					hidden = true,
				},
				pickers = {
					find_files = {
						hidden = true,
						follow = true,
					},
					live_grep = {
						additional_args = function()
							return { "--hidden", "--no-ignore" }
						end,
					},
				},
				extensions = {
					["ui-select"] = {
						require("telescope.themes").get_dropdown({}),
					},
				},
			})

			local builtin = require("telescope.builtin")
			vim.keymap.set("n", "<C-p>", function()
				builtin.find_files({ hidden = true })
			end, {})
			vim.keymap.set("n", "<leader>fg", function()
				builtin.live_grep({ additional_args = { "--hidden", "--no-ignore" } })
			end, {})
			vim.keymap.set("n", "<leader><leader>", builtin.oldfiles, {})
			
      local floaterm = function(cmd)
				return function()
					vim.cmd(cmd)
				end
			end

			vim.keymap.set("n", "<leader>tf", floaterm("FloatermNew"), { silent = true })
			vim.keymap.set("t", "<leader>tf", "<C-\\><C-n>:FloatermNew<CR>", { silent = true })

			vim.keymap.set("n", "<leader>tp", floaterm("FloatermPrev"), { silent = true })
			vim.keymap.set("t", "<leader>tp", "<C-\\><C-n>:FloatermPrev<CR>", { silent = true })

			vim.keymap.set("n", "<leader>tn", floaterm("FloatermNext"), { silent = true })
			vim.keymap.set("t", "<leader>tn", "<C-\\><C-n>:FloatermNext<CR>", { silent = true })

			vim.keymap.set("n", "<leader>tt", floaterm("FloatermToggle"), { silent = true })
			vim.keymap.set("t", "<leader>tt", "<C-\\><C-n>:FloatermToggle<CR>", { silent = true })

			vim.keymap.set("n", "<leader>tk", floaterm("FloatermKill"), { silent = true })
			vim.keymap.set("t", "<leader>tk", "<C-\\><C-n>:FloatermKill<CR>", { silent = true })

			vim.keymap.set("n", "<leader>tl", floaterm("Telescope floaterm"), { silent = true })
			vim.keymap.set("t", "<leader>tl", "<C-\\><C-n>:Telescope floaterm<CR>", { silent = true })

			vim.keymap.set("x", "<leader>ts", floaterm("FloatermSend"), { silent = true })
			require("telescope").load_extension("ui-select")
		end,
	},
}
