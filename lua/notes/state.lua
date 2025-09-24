local default_config = require("notes.config").defaults

-- Plugin state
--- @type PluginState
local state = {
  buffers = {}, -- Buffer handle for notes
  win = nil, -- Window handle (when visible)
  current_display_mode = default_config.display_mode, -- Track current display mode
  current_notes_file_path = default_config.notes_file_path, -- Track current notes file
  config = default_config, -- Merged configuration
  window_sizes = { -- Remember window sizes per mode during session
    floating = { width = default_config.floating.width, height = default_config.floating.height },
    hsplit_height = default_config.split.hsplit_height,
    vsplit_width = default_config.split.vsplit_width,
  },
  augroup = nil, -- Autocommand group ID
  is_setup = false, -- Setup completion flag
}

return state
