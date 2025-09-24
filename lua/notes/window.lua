local M = {}

local state = require("notes.state")

--- Focus the given window and buffer, triggering relevant autocommands
--- @param win number The window handle
--- @param buf number The buffer handle
function M.focus(win, buf)
  vim.api.nvim_set_current_win(win)
  vim.api.nvim_exec_autocmds("WinEnter", { buffer = buf })
  vim.api.nvim_exec_autocmds("BufWinEnter", { buffer = buf })
  vim.api.nvim_exec_autocmds("BufEnter", { buffer = buf })
  vim.api.nvim_exec_autocmds("FileType", { buffer = buf })
end

--- Remember the current window size for the active display mode
--- Preserves user's preferred dimensions across session reopenings
function M.remember_size()
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
function M.get_floating_config()
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
function M.create_split(buf, display_mode)
  local utils = require("notes.utils")
  -- Determine size based on display mode and remembered sizes
  local cmd
  if display_mode == "hsplit" then
    cmd = state.window_sizes.hsplit_height .. "split"
  elseif display_mode == "vsplit" then
    cmd = state.window_sizes.vsplit_width .. "vsplit"
  else
    utils.notify("Invalid split mode: " .. display_mode, vim.log.levels.ERROR)
    return nil
  end

  -- Execute split command and set buffer
  local ok, err = pcall(function()
    vim.cmd(cmd)
  end)
  if not ok then
    utils.notify("Failed to create split: " .. tostring(err), vim.log.levels.ERROR)
    return nil
  end

  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)

  return win
end

--- Configure window options for better note-taking experience
--- @param win number The window handle
function M.set_options(win)
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

return M
