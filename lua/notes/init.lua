local M = {}

-- Plugin metadata
M._VERSION = "1.0.0"
M._NAME = "notes.nvim"

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

-- Default configuration
--- @type NotesConfig
local default_config = {
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

--- Utility function for notifications
--- @param msg string The message to display
--- @param level number|nil The log level (defaults to INFO)
local function notify(msg, level)
  vim.notify("[" .. M._NAME .. "] " .. msg, level or vim.log.levels.INFO)
end

--- Get the full path to the notes file
--- @return string The absolute path to the notes file
local function get_notes_path()
  return vim.fn.expand(state.current_notes_file_path)
end

--- Validate display mode configuration and fall back to default if invalid
--- @param mode string|nil The display mode to validate
--- @param fallback DisplayMode Fallback mode if validation fails
--- @return DisplayMode Valid display mode
local function validate_display_mode(mode, fallback)
  local valid_modes = { "floating", "hsplit", "vsplit" }

  mode = mode or fallback

  if not vim.tbl_contains(valid_modes, mode) then
    notify("Invalid display_mode: " .. mode .. ". Using fallback (" .. fallback .. ").", vim.log.levels.WARN)
    return fallback
  end

  -- If we reach here, mode is valid
  --- @cast mode DisplayMode
  return mode
end

--- Validate and sanitize user configuration
--- @param config table User configuration
--- @return NotesConfig Validated configuration
local function validate_config(config)
  config.display_mode = validate_display_mode(config.display_mode, default_config.display_mode)

  -- Ensure numeric values are valid
  config.floating.width = math.max(20, config.floating.width)
  config.floating.height = math.max(10, config.floating.height)
  config.split.hsplit_height = math.max(10, config.split.hsplit_height)
  config.split.vsplit_width = math.max(20, config.split.vsplit_width)

  return config
end

--- Remember the current window size for the active display mode
--- Preserves user's preferred dimensions across session reopenings
local function remember_window_size()
  if not state.win or not vim.api.nvim_win_is_valid(state.win) then
    return
  end

  local mode = state.current_display_mode
  if mode == "floating" then
    local config = vim.api.nvim_win_get_config(state.win)
    state.window_sizes.floating.width = config.width
    state.window_sizes.floating.height = config.height
  elseif mode == "hsplit" then
    local height = vim.api.nvim_win_get_height(state.win)
    state.window_sizes.hsplit_height = height
  elseif mode == "vsplit" then
    local width = vim.api.nvim_win_get_width(state.win)
    state.window_sizes.vsplit_width = width
  end
end

--- Calculate floating window configuration using remembered or default sizes
--- @return table|nil Window configuration or nil if UI not available
local function get_floating_config()
  local ui = vim.api.nvim_list_uis()[1]
  if not ui then
    return nil
  end

  -- Use remembered size if available, otherwise fall back to config
  local remembered = state.window_sizes.floating
  local cfg = state.config.floating
  local width = math.min(remembered.width, ui.width - 4)
  local height = math.min(remembered.height, ui.height - 4)

  local win_config = {
    relative = cfg.relative,
    width = width,
    height = height,
    col = math.floor((ui.width - width) / 2),
    row = math.floor((ui.height - height) / 2),
    style = cfg.style,
    focusable = cfg.focusable,
    zindex = cfg.zindex,
    border = cfg.border,
  }

  if cfg.title then
    win_config.title = cfg.title
    win_config.title_pos = cfg.title_pos
  end

  return win_config
end

--- Create a split window for the notes buffer using remembered or default sizes
--- @param buf number The buffer handle
--- @param display_mode string The display mode to use
--- @return number|nil The window handle or nil on failure
local function create_split_window(buf, display_mode)
  -- Determine size based on display mode and remembered sizes
  local cmd
  if display_mode == "hsplit" then
    cmd = state.window_sizes.hsplit_height .. "split"
  elseif display_mode == "vsplit" then
    cmd = state.window_sizes.vsplit_width .. "vsplit"
  else
    notify("Invalid split mode: " .. display_mode, vim.log.levels.ERROR)
    return nil
  end

  -- Execute split command and set buffer
  local ok, err = pcall(function()
    vim.cmd(cmd)
  end)
  if not ok then
    notify("Failed to create split: " .. tostring(err), vim.log.levels.ERROR)
    return nil
  end

  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)

  return win
end

--- Load notes content from file or return default content
--- @return table Lines of content
local function load_notes()
  local path = get_notes_path()
  local file = io.open(path, "r")

  if file then
    local content = file:read("*all")
    file:close()
    -- Handle empty files
    if content == "" then
      return { "" }
    end
    return vim.split(content, "\n")
  else
    -- Create default content for new users
    return {
      "# My Notes",
      "",
      "Welcome to notes.nvim!",
      "",
      "## Quick Start",
      "- This file auto-saves when you hide it or quit Neovim",
      "- Use :w to save manually anytime",
      "- Press `"
        .. state.config.buffer_keymaps.quit
        .. "` or `"
        .. state.config.buffer_keymaps.quit_alt
        .. "` to close this window",
      "",
      "## Todo",
      "- [ ] Example task",
      "- [x] Completed task",
      "",
      "## Ideas",
      "- Add your ideas here...",
      "",
      "---",
      "",
      "*Happy note-taking!*",
    }
  end
end

--- Save notes to file
--- @return boolean Success status
local function save_notes()
  local path = get_notes_path()
  local buf = state.buffers[path]

  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return false
  end

  -- Check if buffer is actually modified
  if not vim.api.nvim_get_option_value("modified", { buf = buf }) then
    return true -- Nothing to save
  end

  -- Ensure directory exists
  local dir = vim.fn.fnamemodify(path, ":h")
  if vim.fn.isdirectory(dir) == 0 then
    local ok, err = pcall(vim.fn.mkdir, dir, "p")
    if not ok then
      notify("Failed to create directory: " .. tostring(err), vim.log.levels.ERROR)
      return false
    end
  end

  -- Get buffer content
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local content = table.concat(lines, "\n")

  -- Write to file
  local file, err = io.open(path, "w")
  if not file then
    notify("Failed to open file for writing: " .. tostring(err), vim.log.levels.ERROR)
    return false
  end

  local write_ok, write_err = file:write(content)
  file:close()

  if not write_ok then
    notify("Failed to write to file: " .. tostring(write_err), vim.log.levels.ERROR)
    return false
  end

  -- Mark buffer as unmodified
  vim.api.nvim_set_option_value("modified", false, { buf = buf })

  notify("Notes saved!")
  return true
end

--- Configure buffer options for the notes buffer
--- @param buf number The buffer handle
local function setup_buffer_options(buf)
  local options = {
    { "buftype", "" }, -- Normal buffer
    { "swapfile", false }, -- Don't create swap files
    { "filetype", state.config.filetype }, -- Set filetype for syntax highlighting
    { "bufhidden", "hide" }, -- Hide buffer when not displayed
    { "buflisted", false }, -- Don't show in buffer list
    { "undolevels", -1 }, -- Disable undo initially
  }

  for _, opt in ipairs(options) do
    vim.api.nvim_set_option_value(opt[1], opt[2], { buf = buf })
  end

  -- Re-enable undo after initial content load
  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_set_option_value("undolevels", 1000, { buf = buf })
    end
  end)
end

--- Configure window options for better note-taking experience
--- @param win number The window handle
local function setup_window_options(win)
  local options = {
    { "wrap", true }, -- Wrap long lines
    { "linebreak", true }, -- Break lines at word boundaries
    { "number", false }, -- No line numbers for cleaner look
    { "relativenumber", false }, -- No relative numbers
    { "cursorline", true }, -- Highlight current line
    { "signcolumn", "no" }, -- No sign column
    { "foldcolumn", "0" }, -- No fold column
    { "colorcolumn", "" }, -- No color column
  }

  for _, opt in ipairs(options) do
    vim.api.nvim_set_option_value(opt[1], opt[2], { win = win })
  end
end

--- Setup buffer-specific keymaps (only active when in notes buffer)
--- @param buf number The buffer handle
local function setup_buffer_keymaps(buf)
  local opts = { noremap = true, silent = true, buffer = buf }
  local keymaps = state.config.buffer_keymaps

  -- Quit keymaps
  if keymaps.quit then
    vim.keymap.set("n", keymaps.quit, M.hide, vim.tbl_extend("force", opts, { desc = "Close notes window" }))
  end

  if keymaps.quit_alt then
    vim.keymap.set("n", keymaps.quit_alt, M.hide, vim.tbl_extend("force", opts, { desc = "Close notes window" }))
  end

  -- Save keymap
  if keymaps.save then
    vim.keymap.set({ "n", "i" }, keymaps.save, M.save, vim.tbl_extend("force", opts, { desc = "Save notes" }))
  end
end

--- Setup autocommands for auto-saving behavior and window size tracking
--- @param buf number The buffer handle
local function setup_autocommands(buf)
  -- Clean up existing autocommands
  if state.augroup then
    vim.api.nvim_del_augroup_by_id(state.augroup)
  end

  state.augroup = vim.api.nvim_create_augroup("NotesNvim", { clear = true })

  -- Auto-save when buffer becomes hidden or when leaving it
  if state.config.auto_save then
    vim.api.nvim_create_autocmd({ "BufLeave", "BufHidden", "WinLeave" }, {
      group = state.augroup,
      buffer = buf,
      callback = function()
        -- Remember window size before hiding/leaving
        remember_window_size()
        -- Small delay to handle rapid window switching
        vim.defer_fn(save_notes, 50)
      end,
      desc = "Auto-save notes and remember window size when buffer is hidden",
    })
  end

  -- Track window resize events to remember user preferences
  vim.api.nvim_create_autocmd("VimResized", {
    group = state.augroup,
    callback = remember_window_size,
    desc = "Remember window size when Vim is resized",
  })

  -- Handle floating window close events
  vim.api.nvim_create_autocmd("WinClosed", {
    group = state.augroup,
    callback = function(args)
      local closed_win = tonumber(args.match)
      if closed_win == state.win then
        remember_window_size()
        state.win = nil
      end
    end,
    desc = "Clean up window reference and remember size on close",
  })

  -- Auto-save on Neovim exit
  if state.config.auto_save_on_exit then
    vim.api.nvim_create_autocmd("VimLeavePre", {
      group = state.augroup,
      callback = save_notes,
      desc = "Auto-save notes on Neovim exit",
    })
  end
end

--- Get or create the notes buffer
--- @return number|nil The buffer handle or nil on failure
local function get_or_create_buffer()
  local path = get_notes_path()

  -- If we already have a buffer for this file, return it
  local buf = state.buffers[path]
  if buf and vim.api.nvim_buf_is_valid(buf) then
    return buf
  end

  -- Create new buffer
  buf = vim.api.nvim_create_buf(false, true)
  if buf == 0 then
    notify("Failed to create notes buffer", vim.log.levels.ERROR)
    return nil
  end

  -- Configure the buffer
  setup_buffer_options(buf)

  -- Set buffer name to the notes file path
  local ok, err = pcall(vim.api.nvim_buf_set_name, buf, path)
  if not ok then
    notify("Failed to set buffer name: " .. tostring(err), vim.log.levels.WARN)
  end

  -- Load content
  local content = load_notes()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)

  -- Mark as unmodified initially
  vim.api.nvim_set_option_value("modified", false, { buf = buf })

  -- Setup buffer-specific features
  setup_buffer_keymaps(buf)
  setup_autocommands(buf)

  state.buffers[path] = buf
  return buf
end

--- Show the notes window with optional display mode override
--- @param display_mode DisplayMode|nil Override display mode
--- @param notes_file_path string|nil Override notes file path
--- @return boolean Success status
function M.show(display_mode, notes_file_path)
  if not state.is_setup then
    notify('Plugin not setup. Call require("notes").setup() first.', vim.log.levels.ERROR)
    return false
  end

  -- Use provided display mode or fall back to current/default
  local mode = validate_display_mode(display_mode, state.current_display_mode)

  -- Update current notes file if a new path is provided
  state.current_notes_file_path = notes_file_path or state.config.notes_file_path

  -- If window is already open with same mode, just focus it
  if state.win and vim.api.nvim_win_is_valid(state.win) and state.current_display_mode == mode then
    vim.api.nvim_set_current_win(state.win)
    return true
  end

  -- If window is open but with different mode, close it first
  if state.win and vim.api.nvim_win_is_valid(state.win) and state.current_display_mode ~= mode then
    M.hide() -- This will remember the current window size
  end

  -- Update current display mode
  state.current_display_mode = mode

  -- Get or create buffer
  local buf = get_or_create_buffer()
  if not buf then
    return false
  end

  -- Create window based on display mode
  local win
  if mode == "floating" then
    local win_config = get_floating_config()
    if not win_config then
      notify("Failed to get floating window configuration", vim.log.levels.ERROR)
      return false
    end

    win = vim.api.nvim_open_win(buf, true, win_config)
    if win == 0 then
      notify("Failed to create floating window", vim.log.levels.ERROR)
      return false
    end
  else
    win = create_split_window(buf, mode)
    if not win then
      return false
    end
  end

  state.win = win
  setup_window_options(win)

  -- Focus the window
  vim.api.nvim_set_current_win(win)

  return true
end

--- Hide the notes window and remember its size
--- @return boolean Success status
function M.hide()
  if not state.win or not vim.api.nvim_win_is_valid(state.win) then
    return true -- Already hidden
  end

  -- Remember window size before hiding
  remember_window_size()

  -- Auto-save if enabled and buffer is modified
  if state.config.auto_save then
    save_notes()
  end

  -- Close window
  local ok, err = pcall(vim.api.nvim_win_close, state.win, false)
  if not ok then
    notify("Failed to close window: " .. tostring(err), vim.log.levels.WARN)
  end

  state.win = nil
  return true
end

--- Toggle notes window visibility with optional display mode override
--- @param display_mode DisplayMode|nil Override display mode
--- @param notes_file_path string|nil Override notes file path
--- @return boolean Success status
function M.toggle(display_mode, notes_file_path)
  -- If window is open and no mode specified, hide it
  if state.win and vim.api.nvim_win_is_valid(state.win) and not display_mode then
    return M.hide()
  end

  -- If window is open with different mode, or no window is open, show with specified/current mode
  return M.show(display_mode, notes_file_path)
end

--- Save notes manually
--- @return boolean Success status
function M.save()
  if not state.is_setup then
    notify('Plugin not setup. Call require("notes").setup() first.', vim.log.levels.ERROR)
    return false
  end

  return save_notes()
end

--- Edit notes in current buffer (not in floating window/split)
--- @param notes_file_path string|nil Override notes file path
--- @return boolean Success status
function M.edit(notes_file_path)
  if not state.is_setup then
    notify('Plugin not setup. Call require("notes").setup() first.', vim.log.levels.ERROR)
    return false
  end

  -- Update current notes file if a new path is provided
  state.current_notes_file_path = notes_file_path or state.config.notes_file_path

  local path = get_notes_path()
  local ok, err = pcall(vim.cmd.edit, path)
  if not ok then
    notify("Failed to edit notes file: " .. tostring(err), vim.log.levels.ERROR)
    return false
  end

  return true
end

--- Get current plugin status including window size information
--- @return table Status information
function M.status()
  local path = get_notes_path()
  local buf = state.buffers and state.buffers[path] or nil

  return {
    is_setup = state.is_setup,
    buffer_valid = buf and vim.api.nvim_buf_is_valid(buf) or false,
    window_valid = state.win and vim.api.nvim_win_is_valid(state.win) or false,
    current_display_mode = state.current_display_mode,
    current_notes_file_path = path,
    window_sizes = state.window_sizes,
    display_mode = state.config.display_mode,
  }
end

--- Setup the plugin with user configuration
--- @param opts NotesConfig|nil User configuration options
function M.setup(opts)
  -- Merge configuration
  opts = opts or {}
  state.config = vim.tbl_deep_extend("force", default_config, opts)
  state.config = validate_config(state.config)

  -- Initialize current display mode and window sizes from config
  state.current_display_mode = state.config.display_mode
  state.window_sizes.floating.width = state.config.floating.width
  state.window_sizes.floating.height = state.config.floating.height
  state.window_sizes.hsplit_height = state.config.split.hsplit_height
  state.window_sizes.vsplit_width = state.config.split.vsplit_width

  -- Create user commands with display mode support
  local complete_toggle_show = function(_, line, pos)
    -- Get everything typed up to cursor
    local argline = line:sub(1, pos)

    -- Split on whitespace
    local parts = vim.split(argline, "%s+")

    -- parts[1] = ":NotesToggle" or ":NotesShow"
    -- parts[2] = first arg (display_mode)
    -- parts[3] = second arg (filepath)

    if #parts == 2 then
      -- Completing first arg → suggest display modes
      return { "floating", "hsplit", "vsplit" }
    elseif #parts == 3 then
      -- Completing second arg → suggest files
      return vim.fn.getcompletion(parts[3], "file")
    else
      return {}
    end
  end

  local commands = {
    {
      "NotesToggle",
      function(opts)
        local args = vim.split(opts.args, " ")
        local display_mode = args[1] ~= "" and args[1] or nil
        local notes_path = args[2] ~= nil and args[2] or nil
        M.toggle(display_mode, notes_path)
      end,
      {
        desc = "Toggle notes window visibility",
        nargs = "*",
        complete = complete_toggle_show,
      },
    },
    {
      "NotesShow",
      function(opts)
        local args = vim.split(opts.args, " ")
        local display_mode = args[1] ~= "" and args[1] or nil
        local notes_path = args[2] ~= nil and args[2] or nil
        M.show(display_mode, notes_path)
      end,
      {
        desc = "Show notes window",
        nargs = "*",
        complete = complete_toggle_show,
      },
    },
    {
      "NotesHide",
      M.hide,
      { desc = "Hide notes window" },
    },
    {
      "NotesSave",
      M.save,
      { desc = "Save notes to file" },
    },
    {
      "NotesEdit",
      function(opts)
        local notes_file_path = opts.args ~= "" and opts.args or nil
        M.edit(notes_file_path)
      end,
      {
        desc = "Edit notes in current window",
        nargs = "?",
        complete = function(ArgLead, _, _)
          -- Always suggest file paths
          return vim.fn.getcompletion(ArgLead, "file")
        end,
      },
    },
  }

  for _, cmd in ipairs(commands) do
    vim.api.nvim_create_user_command(cmd[1], cmd[2], cmd[3])
  end

  state.is_setup = true
end

return M
