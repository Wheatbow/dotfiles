vim.o.number = true
vim.o.tabstop = 2
vim.o.shiftwidth = 2

vim.pack.add({ "https://www.github.com/nvim-lua/plenary.nvim" })
vim.pack.add({ "https://github.com/nvim-treesitter/nvim-treesitter" })
vim.pack.add({ {
  src = "https://www.github.com/olimorris/codecompanion.nvim",
  version = vim.version.range("^19.0.0")
} })

require("codecompanion").setup({
  adapters = {
    acp = {
      pi_acp = function()
        return require("pi_acp")
      end,
    },
  },
  interactions = {
    chat = {
      adapter = "pi_acp",
    },
  },
})
