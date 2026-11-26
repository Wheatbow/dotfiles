vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.o.number = true
vim.o.numberwidth = 2
vim.o.signcolumn = "auto:1"
vim.o.tabstop = 2
vim.o.shiftwidth = 2
vim.o.wrap = true
vim.o.linebreak = true
vim.o.breakindent = true
vim.o.complete = "o"
vim.o.completeopt = "fuzzy,menuone,noselect"
vim.o.autocomplete = true
vim.o.termguicolors = true
vim.o.hlsearch = false
vim.o.ignorecase = true
vim.o.smartcase = false

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

vim.pack.add({
  "https://github.com/nvim-treesitter/nvim-treesitter",
  "https://github.com/echasnovski/mini.diff",
  "https://github.com/folke/snacks.nvim",
})

require("mini.diff").setup({
  view = {
    style = "sign",
    signs = { add = "┃", change = "┃", delete = "_" },
  },
})

require("snacks").setup()

vim.keymap.set("n", "<leader>fb", function()
  Snacks.picker.buffers()
end, { desc = "Buffers" })

vim.keymap.set("n", "<leader>ff", function()
  Snacks.picker.files()
end, { desc = "Find Files (Root Dir)" })

vim.keymap.set("n", "<leader>fg", function()
  Snacks.picker.git_files()
end, { desc = "Find Files (git-files)" })

vim.keymap.set("n", "<leader>ss", function()
  Snacks.picker.grep()
end, { desc = "Grep (Root Dir)" })

vim.keymap.set("n", "<leader>ld", function()
  Snacks.picker.lsp_symbols()
end, { desc = "Document symbols" })

vim.keymap.set("n", "<leader>ll", function()
  Snacks.picker.lsp_definitions()
end, { desc = "Follow link" })

vim.keymap.set("n", "<leader>lw", function()
  Snacks.picker.lsp_workspace_symbols()
end, { desc = "Workspace symbols" })

vim.keymap.set({ "n", "v" }, "<leader>ca", function()
  vim.lsp.buf.code_action()
end, { desc = "Code actions" })

vim.keymap.set("n", "<leader>ce", function()
  vim.lsp.buf.code_action({
    apply = true,
    filter = function(a)
      return a.kind == "custom.extract" or a.title == "Extract"
    end,
  })
end, { desc = "Extract section" })

vim.keymap.set("n", "<leader>ci", function()
  vim.lsp.buf.code_action({
    apply = true,
    filter = function(a)
      return a.kind == "custom.inline_section" or a.title == "Inline section"
    end,
  })
end, { desc = "Inline section" })

vim.keymap.set({ "n", "v" }, "<leader>cl", function()
  vim.lsp.buf.code_action({
    apply = true,
    filter = function(a)
      return a.kind == "custom.link_slug" or a.title == "Link word"
    end,
  })
end, { desc = "Link word" })

vim.keymap.set("n", "<leader>gs", function()
  Snacks.picker.git_status()
end, { desc = "Git Status" })

vim.keymap.set("n", "<leader>gd", function()
  Snacks.picker.git_diff()
end, { desc = "Git Diff (hunks)" })

vim.keymap.set("n", "<leader>gl", function()
  Snacks.picker.git_log()
end, { desc = "Git Log" })

vim.keymap.set("n", "<leader>gf", function()
  Snacks.picker.git_log_file()
end, { desc = "Git Current File History" })

vim.keymap.set("n", "<leader>gb", function()
  Snacks.picker.git_log_line()
end, { desc = "Git Blame Line" })

vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("iwe_lsp", { clear = true }),
  pattern = "markdown",
  callback = function(ev)
    local root = vim.fs.root(ev.buf, { ".iwe", ".git" })
    if not root then
      return
    end
    vim.lsp.start({
      name = "iwes",
      cmd = { vim.fn.exepath("iwes") },
      cmd_cwd = root,
      root_dir = root,
    }, { bufnr = ev.buf })
  end,
})

