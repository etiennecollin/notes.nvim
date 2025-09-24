--- @alias DisplayMode "floating"|"hsplit"|"vsplit"

--- @class FloatingConfig
--- @field width number Window width in columns
--- @field height number Window height in rows
--- @field border string Border style
--- @field title string Window title
--- @field title_pos string Title position
--- @field relative string Relative positioning
--- @field style string Window style
--- @field focusable boolean Whether window can be focused
--- @field zindex number Window z-index

--- @class SplitConfig
--- @field hsplit_height number Height for horizontal splits
--- @field vsplit_width number Width for vertical splits

--- @class BufferKeymaps
--- @field save string Keymap for saving notes
--- @field quit string Keymap for quitting notes window
--- @field quit_alt string Alternative keymap for quitting notes window

--- @class NotesConfig
--- @field display_mode DisplayMode Default display mode
--- @field floating FloatingConfig Floating window configuration
--- @field split SplitConfig Split window configuration
--- @field notes_file_path string Path to notes file
--- @field filetype string Buffer filetype
--- @field auto_save boolean Auto-save when buffer is hidden/left
--- @field auto_save_on_exit boolean Auto-save when nvim exits
--- @field buffer_keymaps BufferKeymaps Buffer-specific keymaps

--- @class WindowSizes
--- @field floating {width: number, height: number} Remembered floating window size
--- @field hsplit_height number Remembered horizontal split height
--- @field vsplit_width number Remembered vertical split width

--- @class PluginState
--- @field buffers {} Maps absolute file path to buffer handle
--- @field win number|nil Window handle (when visible)
--- @field current_display_mode DisplayMode Currently active display mode
--- @field current_notes_file_path string Current notes file path
--- @field config NotesConfig Merged configuration
--- @field window_sizes WindowSizes Remembered window sizes per mode
--- @field augroup number|nil Autocommand group ID
--- @field is_setup boolean Setup completion flag
