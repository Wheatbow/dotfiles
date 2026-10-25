vim.o.number = true
vim.o.tabstop = 2
vim.o.shiftwidth = 2
vim.opt.wrap = true
vim.opt.linebreak = true
vim.opt.breakindent = true
vim.o.complete = "o"
vim.o.completeopt = "fuzzy,menuone,noselect"
vim.o.autocomplete = true
vim.o.termguicolors = true

vim.keymap.set('i', '<Up>', '<C-o>gk', { silent = true })
vim.keymap.set('i', '<Down>', '<C-o>gj', { silent = true })

local heading_colors = {
  "#ff007b", -- H1 red
  "#ffcc00", -- H2 yellow
  "#ff00ff", -- H3 magenta
  "#007bff", -- H4 blue
  "#00ccff", -- H5 cyan
  "#fefffe", -- H6 white
}

local function markdown_headings()
  for level, fg in ipairs(heading_colors) do
    vim.api.nvim_set_hl(0, "@markup.heading." .. level, { fg = fg, bold = true })
  end
end

markdown_headings()
vim.api.nvim_create_autocmd("ColorScheme", { callback = markdown_headings })

vim.pack.add({ "https://github.com/nvim-treesitter/nvim-treesitter" })
