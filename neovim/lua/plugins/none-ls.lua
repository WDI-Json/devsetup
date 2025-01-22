return {
	"nvimtools/none-ls.nvim",
	config = function()
		local null_ls = require("null-ls")

		null_ls.setup({
			--debug = true,
			sources = {
				null_ls.builtins.formatting.stylua,
				null_ls.builtins.diagnostics.rubocop,
				null_ls.builtins.formatting.rubocop,
			},
		})
		
    -- local logger = require("null-ls.logger")
    -- logger.warn = function() end -- Suppress warnings
	end,
}
