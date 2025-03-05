return {
    "nvimtools/none-ls.nvim",
    config = function()
        local null_ls = require("null-ls")

        null_ls.setup({
            -- debug = true,
            sources = {
                -- Formatters
                null_ls.builtins.formatting.stylua,
                null_ls.builtins.formatting.prettier.with({
                    filetypes = { "javascript", "typescript", "javascriptreact", "typescriptreact", "jsx", "tsx" },
                }),

                -- Linters
                null_ls.builtins.diagnostics.rubocop,
                null_ls.builtins.formatting.rubocop,
                null_ls.builtins.diagnostics.haml_lint.with({
                    filetypes = { "haml" },
                }),
            },
        })

    -- local logger = require("null-ls.logger")
    -- logger.warn = function() end -- suppress warnings
    end,
}
