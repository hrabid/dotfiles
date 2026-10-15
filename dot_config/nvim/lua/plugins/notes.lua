return {
  "hrabid/notes.nvim",
  -- dir = "~/notes.nvim/",
  lazy = false,
  dependencies = { "nvim-telescope/telescope.nvim" }, -- optional
  opts = {
    -- vault_path = "~/vaults/main", -- omit to auto-detect via .obsidian/
    default_template = "fleeting",
    new_note_dir = "fleetings",
  },
}
