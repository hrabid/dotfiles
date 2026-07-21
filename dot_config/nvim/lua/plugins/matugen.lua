return {
  {
    "hrabid/matugen.nvim",
    lazy = false,
    priority = 1000,

    config = function()
      local palette_path = vim.fn.expand("~/.config/nvim/nvim-colors.json")

      if vim.fn.filereadable(palette_path) == 1 then
        require("matugen").setup({
          palette_path = palette_path,
        })
      else
        vim.cmd.colorscheme("tokyonight")
      end
    end,
  },
}
