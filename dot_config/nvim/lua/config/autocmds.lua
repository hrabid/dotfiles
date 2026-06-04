-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

local function source_matugen()
  local matugen_path = os.getenv("HOME") .. "/.config/nvim/matugen.lua"
  local file, err = io.open(matugen_path, "r")
  if err ~= nil then
    vim.cmd("colorscheme base16-catppuccin-mocha")
    vim.print(
      "A matugen style file was not found, but that's okay! The colorscheme will dynamically change if matugen runs!"
    )
  else
    dofile(matugen_path)
    io.close(file)
  end
end

local function auxiliary_function()
  source_matugen()
  if package.loaded["lualine"] then
    require("lualine").setup({ options = { theme = "base16" } })
  end
  vim.api.nvim_set_hl(0, "Comment", { italic = true })
end

vim.api.nvim_create_autocmd("Signal", {
  pattern = "SIGUSR1",
  callback = auxiliary_function,
})
