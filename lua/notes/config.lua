local M = {}

-- Default configuration
--- @type NotesConfig
M.defaults = {
  -- Display mode
  display_mode = "floating",

  -- Floating window configuration
  floating = {
    width = 80,
    height = 24,
    border = "rounded",
    title = " Notes ",
    title_pos = "center",
    relative = "editor",
    style = "minimal",
    focusable = true,
    zindex = 50,
  },

  -- Split configuration
  split = {
    hsplit_height = 24,
    vsplit_width = 80,
  },

  -- File and behavior configuration
  notes_file_path = vim.fn.stdpath("data") .. "/notes.md",
  filetype = "markdown",
  auto_save = true, -- Auto-save when buffer is hidden/left
  auto_save_on_exit = true, -- Auto-save when nvim exits

  -- Buffer-specific keymaps (only active when in notes buffer)
  buffer_keymaps = {
    save = "<C-s>",
    quit = "q",
    quit_alt = "<Esc>",
  },
}

--- Validate display mode configuration and fall back to default if invalid
--- @param mode string|nil The display mode to validate
--- @param fallback DisplayMode Fallback mode if validation fails
--- @return DisplayMode Valid display mode
function M.validate_display_mode(mode, fallback)
  local valid_modes = { "floating", "hsplit", "vsplit" }

  mode = mode or fallback

  if not vim.tbl_contains(valid_modes, mode) then
    require("notes.utils").notify(
      "Invalid display_mode: " .. mode .. ". Using fallback (" .. fallback .. ").",
      vim.log.levels.WARN
    )
    return fallback
  end

  -- If we reach here, mode is valid
  --- @cast mode DisplayMode
  return mode
end

--- Validate and sanitize user configuration
--- @param config table User configuration
--- @return NotesConfig Validated configuration
function M.validate(config)
  config.display_mode = M.validate_display_mode(config.display_mode, M.defaults.display_mode)

  -- Ensure numeric values are valid
  config.floating.width = math.max(20, config.floating.width)
  config.floating.height = math.max(10, config.floating.height)
  config.split.hsplit_height = math.max(10, config.split.hsplit_height)
  config.split.vsplit_width = math.max(20, config.split.vsplit_width)

  return config
end

return M
