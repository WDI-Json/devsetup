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

      -- Ruby LSP
      vim.lsp.config.ruby_lsp = {
        cmd = { 'ruby-lsp' },
        filetypes = { 'ruby' },
        root_markers = { 'Gemfile', '.git' },
        capabilities = capabilities,
      }

      -- Bash Language Server
      vim.lsp.config.bashls = {
        cmd = { 'bash-language-server', 'start' },
        filetypes = { 'sh' },
        root_markers = { '.git' },
        capabilities = capabilities,
      }

      -- Groovy Language Server
      vim.lsp.config.groovyls = {
        cmd = { 'groovy-language-server' },
        filetypes = { 'groovy' },
        root_markers = { '.git' },
        capabilities = capabilities,
      }

      -- Lua Language Server (LuaLS)
      vim.lsp.config.lua_ls = {
        cmd = { 'lua-language-server' },
        filetypes = { 'lua' },
        root_markers = { '.luarc.json', '.luarc.jsonc', '.luacheckrc', '.stylua.toml', 'stylua.toml', 'selene.toml', 'selene.yml', '.git' },
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
      }

      -- Enable language servers
      vim.lsp.enable({ 'ruby_lsp', 'bashls', 'groovyls', 'lua_ls' })

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

