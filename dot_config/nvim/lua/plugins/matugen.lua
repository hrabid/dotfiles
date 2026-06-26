local jsonc = vim.fn.expand("~/.config/nvim/nvim-colors.jsonc")
local fallback = "tokyonight" -- Change this to your preferred colorscheme

-- Apply the fallback if the Matugen colors file doesn't exist.
if vim.fn.filereadable(jsonc) == 0 then
  vim.cmd.colorscheme(fallback)
end

return {
  {
    "Senal-D-A-Gunaratna/matugen.nvim",
    lazy = false,
    priority = 1000,

    cond = function()
      return vim.fn.filereadable(jsonc) == 1
    end,

    opts = {
      load_theme = true,
      jsonc_path = jsonc,
    },
  },
}
