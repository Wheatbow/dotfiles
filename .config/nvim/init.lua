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
  "https://github.com/echasnovski/mini.pick",
  "https://github.com/echasnovski/mini.extra",
  "https://github.com/echasnovski/mini.diff",
})

local function pick_win()
  return function()
    return { width = vim.o.columns }
  end
end

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

require("mini.pick").setup({ window = { config = pick_win() } })
require("mini.extra").setup()

-- Compact one-line-per-item display: "a.md:5 Beta Header"
local function lsp_compact_show(buf_id, items, query)
  for _, it in ipairs(items) do
    if it._name == nil then
      -- item.text is "path│lnum│col│ [Key] stem#Heading": keep only the payload
      local name = it.text:match("([^│]*)$"):gsub("^%s*", "")
      if it.kind ~= nil then
        -- symbols: drop the "[Key] " kind label and the "file#" name prefix
        name = name:gsub("^%[[^%]]*%]%s*", "")
        local stem = vim.fn.fnamemodify(it.path or "", ":t:r")
        if stem ~= "" then name = name:gsub("^" .. vim.pesc(stem) .. "#", "") end
      end
      it._name = name
    end
    it.text = ("%s:%d %s"):format(vim.fn.fnamemodify(it.path or "", ":t"), it.lnum or 1, it._name)
  end
  MiniPick.default_show(buf_id, items, query)
end

-- Headings (what iwe calls "sections") of the current note, from iwes'
-- `textDocument/documentSymbol`. Measured behaviour of iwes 0.34:
--
--   * it lists the sections *below* the note's title heading -- the title itself
--     and any further top-level `#` section are omitted, so a note with only a
--     `#` line comes back empty (`##` is where sections start);
--   * it returns them bottom-up, so sort by line to get document order;
--   * nesting is encoded as two U+2003 em-spaces per level ("## Society" has
--     none, "### Mind's Eye" has two, "#### The Prison" has four).
local EM_SPACE = "\226\128\131"

local function section_show(buf_id, items, query)
  for _, it in ipairs(items) do
    it.text = ("%4d  %s%s"):format(it.lnum or 1, ("  "):rep(it.depth), it.title)
  end
  MiniPick.default_show(buf_id, items, query)
end

vim.keymap.set("n", "<leader>d", function()
  local bufnr = vim.api.nvim_get_current_buf()
  local method = "textDocument/documentSymbol"
  local client = vim.lsp.get_clients({ bufnr = bufnr, method = method })[1]
  if client == nil then
    return vim.notify("No LSP document symbols here (open a markdown file in an iwe project)", vim.log.levels.WARN)
  end

  -- Requested by hand rather than via `vim.lsp.buf.document_symbol()` so that
  -- the empty answer (notes with no `##` sections) gets an iwe-specific hint
  -- instead of nvim's generic "No document symbols found" notification.
  local params = { textDocument = vim.lsp.util.make_text_document_params(bufnr) }
  vim.lsp.buf_request(bufnr, method, params, function(err, result)
    if err then
      return vim.notify("documentSymbol failed: " .. tostring(err.message), vim.log.levels.ERROR)
    end

    local items = vim.lsp.util.symbols_to_items(result or {}, bufnr, client.offset_encoding)
    if #items == 0 then
      return vim.notify(
        "No sections below the title: iwe lists the `##` headings under the note's `#`",
        vim.log.levels.INFO
      )
    end

    for _, it in ipairs(items) do
      -- `symbols_to_items` text is "[Object] <name>"; the name itself carries the
      -- em-space indentation.
      local title = (it.text or ""):gsub("^%[[^%]]*%]%s*", "")
      local level = 0
      while title:sub(1, #EM_SPACE) == EM_SPACE do
        title, level = title:sub(#EM_SPACE + 1), level + 1
      end
      it.title = title
      it.depth = math.floor(level / 2) -- two em-spaces per nesting level
      it.bufnr = bufnr -- what MiniPick.default_choose needs to jump
    end
    table.sort(items, function(a, b) return (a.lnum or 0) < (b.lnum or 0) end)

    local name = vim.api.nvim_buf_get_name(bufnr)
    MiniPick.start({
      source = {
        name = "Sections: " .. vim.fn.fnamemodify(name == "" and "[No Name]" or name, ":t"),
        items = items,
        show = section_show,
      },
    })
  end)
end, { desc = "Sections (## headings) of current note, from iwes" })

-- Workspace symbols = the project's notes index: iwes reports one entry per
-- top-level `#` section, so a file with two `#` headings appears twice and a
-- file without any heading does not appear at all. Its query is only used for
-- ranking (never for filtering), so fetch everything once and let mini.pick do
-- the matching, on path and title both.
local function workspace_show(buf_id, items, query)
  for _, it in ipairs(items) do
    it.text = it.loc .. (" "):rep(it.pad) .. it.title
  end
  MiniPick.default_show(buf_id, items, query)
end

vim.keymap.set("n", "<leader>s", function()
  local method = "workspace/symbol"
  local client = vim.lsp.get_clients({ method = method })[1]
  if client == nil then
    return vim.notify("No LSP workspace symbols here (open a markdown file in an iwe project)", vim.log.levels.WARN)
  end

  client:request(method, { query = "" }, function(err, result)
    if err then
      return vim.notify("workspace/symbol failed: " .. tostring(err.message), vim.log.levels.ERROR)
    end

    local items = vim.lsp.util.symbols_to_items(result or {}, 0, client.offset_encoding)
    if #items == 0 then
      return vim.notify("No workspace symbols: no `#` headings in the project?", vim.log.levels.INFO)
    end

    local root = client.root_dir or vim.fn.getcwd()
    local width = 0
    for _, it in ipairs(items) do
      -- text is "[Function] <title>"; `filename` is absolute.
      local title = (it.text or ""):gsub("^%[[^%]]*%]%s*", "")
      local path = it.filename or ""
      if path:sub(1, #root + 1) == root .. "/" then
        path = path:sub(#root + 2)
      end
      it.title = title
      it.key = (path:gsub("%.[%w]+$", "")) -- key like iwe's: no extension
      it.loc = ("%s:%d"):format(it.key, it.lnum or 1)
      it.path = it.filename -- what MiniPick.default_choose needs to open the file
      width = math.max(width, vim.fn.strdisplaywidth(it.loc))
    end
    for _, it in ipairs(items) do
      it.pad = 2 + width - vim.fn.strdisplaywidth(it.loc) -- same title column for all
    end
    table.sort(items, function(a, b)
      if a.key ~= b.key then return a.key < b.key end
      return (a.lnum or 0) < (b.lnum or 0)
    end)

    MiniPick.start({
      source = { name = "Workspace symbols", items = items, show = workspace_show },
    })
  end)
end, { desc = "Workspace symbols (notes index) from iwes" })

vim.keymap.set("n", "<leader>r", function()
  if #vim.lsp.get_clients({ bufnr = 0 }) == 0 then
    return vim.notify("No LSP in this buffer (open a markdown file)", vim.log.levels.WARN)
  end
  MiniExtra.pickers.lsp({ scope = "references" }, {
    source = { show = lsp_compact_show },
  })
end, { desc = "References (backlinks) of link under cursor" })

local function project_root()
  return vim.fs.root(0, ".git") or vim.fn.getcwd()
end

vim.keymap.set("n", "<leader>f", function()
  MiniPick.builtin.files({}, { source = { cwd = project_root() } })
end, { desc = "Pick files" })

require("mini.diff").setup({
  view = {
    style = "sign",
    signs = { add = "┃", change = "┃", delete = "_" },
  },
})

