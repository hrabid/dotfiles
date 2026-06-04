return {
  "LazyVim/LazyVim",
  opts = {
    colorscheme = function()
      local matugen_path = os.getenv("HOME") .. "/.config/nvim/matugen.lua"
      if vim.fn.filereadable(matugen_path) == 1 then
        dofile(matugen_path)
      else
        vim.cmd("colorscheme base16-catppuccin-mocha")
      end
    end,
  },
}
