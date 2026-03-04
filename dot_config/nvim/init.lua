-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

vim.opt.wrap = true
vim.opt.linebreak = true

-- opening/following links or creating one
local VAULT = vim.fn.expand("~/notes")      -- 🔧 search existing notes here
local INBOX = vim.fn.expand("~/notes/inbox") -- 🔧 new notes land here

vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.keymap.set("n", "gf", function()
      local line = vim.api.nvim_get_current_line()
      local col = vim.api.nvim_win_get_cursor(0)[2] + 1
      local name
      for link in line:gmatch("%[%[([^%]]+)%]%]") do
        local s, e = line:find("%[%[" .. vim.pesc(link) .. "%]%]")
        if s and col >= s and col <= e then
          name = link:match("^([^|#]+)")
          break
        end
      end
      if not name then return end

      local found = vim.fn.globpath(VAULT, "**/" .. name .. ".md", false, true)
      local path = (found and found[1]) or (INBOX .. "/" .. name .. ".md")

      vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
      vim.cmd("edit " .. vim.fn.fnameescape(path))
    end, { buffer = true })
  end,
})



-- auto completion for linking
vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.bo.omnifunc = "v:lua.wiki_complete"

    -- Trigger completion after [[ (autopairs already inserts the ]])
    vim.keymap.set("i", "[", function()
      local before = vim.api.nvim_get_current_line():sub(1, vim.api.nvim_win_get_cursor(0)[2])
      if before:sub(-1) == "[" then
        return "[<C-x><C-o>"
      end
      return "["
    end, { buffer = true, expr = true })

    -- Enter to confirm completion
    vim.keymap.set("i", "<CR>", function()
      if vim.fn.pumvisible() == 1 then
        return "<C-y>"
      end
      return "<CR>"
    end, { buffer = true, expr = true })
  end,
})

function _G.wiki_complete(findstart, base)
  if findstart == 1 then
    local col = vim.api.nvim_win_get_cursor(0)[2]
    local before = vim.api.nvim_get_current_line():sub(1, col)
    local s = before:match(".*%[%[().*$")
    return s and s - 1 or -1
  end

  local files = vim.fn.globpath(VAULT, "**/*.md", false, true)
  local items = {}
  for _, f in ipairs(files) do
    local name = f:match(".+/(.-)%.md$")
    if name:lower():find(base:lower(), 1, true) then
      table.insert(items, name)
    end
  end
  return items
end

-- front matter injection 
vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.keymap.set("n", "<leader>mf", function()
      local date = os.date("%Y-%m-%d")
      local time = os.date("%H:%M")
      local frontmatter = {
        "---",
        "date: " .. date,
        "time: " .. time,
        "tags: []",
        "title: ",
        "---",
        "",
      }
      -- Only inject if no frontmatter exists
      local first_line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
      if first_line == "---" then
        vim.notify("Frontmatter already exists", vim.log.levels.WARN)
        return
      end
      vim.api.nvim_buf_set_lines(0, 0, 0, false, frontmatter)
      -- Place cursor at the end of title line
      vim.api.nvim_win_set_cursor(0, { 5, #"title: " })
      vim.cmd("startinsert!")
    end, { buffer = true, desc = "Inject frontmatter" })
  end,
})
