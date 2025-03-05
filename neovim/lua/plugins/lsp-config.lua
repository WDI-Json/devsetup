return {
  {
    "williamboman/mason.nvim",
    lazy = false,
    config = function()
      require("mason").setup()
    end,
  },
  {
    "williamboman/mason-lspconfig.nvim",
    lazy = false,
    opts = {
      auto_install = true,
    },
  },
  {
    "neovim/nvim-lspconfig",
    lazy = false,
    config = function()
      local capabilities = require('cmp_nvim_lsp').default_capabilities()

      local lspconfig = require("lspconfig")

      -- Ruby LSP
      lspconfig.ruby_lsp.setup({
        capabilities = capabilities,
      })

      -- Bash Language Server
      lspconfig.bashls.setup({
        capabilities = capabilities,
      })

      -- Groovy Language Server
      lspconfig.groovyls.setup({
        capabilities = capabilities,
      })

      -- Lua Language Server (LuaLS)
      lspconfig.lua_ls.setup({
        capabilities = capabilities,
        settings = {
          Lua = {
            diagnostics = {
              globals = { 'vim' },
            },
            workspace = {
              library = vim.api.nvim_get_runtime_file("", true),
            },
            telemetry = {
              enable = false,
            },
          },
        },
      })

      -- YAML Language Server
      lspconfig.yamlls.setup({
        capabilities = capabilities,
        settings = {
          yaml = {
            keyOrdering = false,
            schemas = {},
            validate = true,
          },
        },
      })

      -- Keymaps for LSP
      vim.keymap.set("n", "K", vim.lsp.buf.hover, {})
      vim.keymap.set("n", "<leader>gd", vim.lsp.buf.definition, {})
      vim.keymap.set("n", "<leader>gr", vim.lsp.buf.references, {})
      vim.keymap.set("n", "<leader>gf", vim.lsp.buf.format, {})
      vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, {})
      vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, {})
    end,
  },
}

