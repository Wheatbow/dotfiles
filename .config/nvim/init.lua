vim.o.number = true
vim.o.tabstop = 2
vim.o.shiftwidth = 2
vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.breakindent = true
vim.o.complete = "o"
vim.o.completeopt = "fuzzy,menuone,noselect"
vim.o.autocomplete = true

vim.keymap.set('i', '<Up>', '<C-o>gk', { silent = true })
vim.keymap.set('i', '<Down>', '<C-o>gj', { silent = true })

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
		cli = {
			adapter = "pi_acp",
		},
  },
  display = {
    chat = {
      window = {
        layout = "horizontal",
        position = "bottom",
        height = 0.4,
      },
    },
  },
})
