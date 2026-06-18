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


-- indentation defaults
vim.opt.expandtab = true
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2

