require("config.lazy")
require("config.colors").setup()

-- Helm chart files: detect *.yaml / *.tpl inside a templates/ dir as 'helm' filetype
-- so helm_ls attaches instead of yamlls
vim.filetype.add({
  pattern = {
    [".*/templates/.*%.yaml"] = "helm",
    [".*/templates/.*%.tpl"] = "helm",
    ["helmfile.*%.yaml"] = "helm",
  },
})


--overriding command
vim.cmd("set expandtab")
vim.cmd("set tabstop=2")
vim.cmd("set softtabstop=2")
vim.cmd("set shiftwidth=2")
vim.g.mapleader = " "

