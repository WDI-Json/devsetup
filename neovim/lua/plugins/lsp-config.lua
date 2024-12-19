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
    config = function()
      require("mason-lspconfig").setup({
        ensure_installed = { "lua_ls", "ruby_lsp" },
      })
    end,
  },

  {
    "neovim/nvim-lspconfig",
    lazy = false,
    config = function()
      local capabilities = require('cmp_nvim_lsp').default_capabilities()
      local lspconfig = require("lspconfig")

      -- Lua Language Server (lua_ls) Configuration
      lspconfig.lua_ls.setup({
        capabilities = capabilities,
        settings = {
          Lua = {
            runtime = { version = "LuaJIT" }, 
            diagnostics = { globals = { "vim" } },
            workspace = {
              library = vim.api.nvim_get_runtime_file("", true),
              checkThirdParty = false,
            },
            telemetry = { enable = false },
          },
        },
      })

      lspconfig.ruby_lsp.setup({
        capabilities = capabilities,
        init_options = {
          enabledFeatures = {
            "codeActions",
            "diagnostics",
            "documentHighlights",
            "documentSymbols",
            "formatting",
            "inlayHint",
            "onSave",
          },
        },
        settings = {
          ruby_lsp = {
            diagnostics = {
              enabled = true, 
              formatter = "rubocop",
            },
          },
        },
      })

      -- Global LSP Keymaps
      local keymap_opts = { noremap = true, silent = true }
      vim.keymap.set("n", "K", vim.lsp.buf.hover, keymap_opts)
      vim.keymap.set("n", "<leader>gd", vim.lsp.buf.definition, keymap_opts)
      vim.keymap.set("n", "<leader>gr", vim.lsp.buf.references, keymap_opts)
      vim.keymap.set("n", "<leader>gf", vim.lsp.buf.format, keymap_opts)
      vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, keymap_opts)
      vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, keymap_opts)
    end,
  },
}

