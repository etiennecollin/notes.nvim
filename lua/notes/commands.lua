local M = {}

local state = require("notes.state")
local utils = require("notes.utils")
local note = require("notes.note")
local window = require("notes.window")

--- Show the notes window with optional display mode override
--- @param display_mode DisplayMode|nil Override display mode
--- @param notes_file_path string|nil Override notes file path
--- @return boolean Success status
function M.show(display_mode, notes_file_path)
  if not state.is_setup then
    utils.notify('Plugin not setup. Call require("notes").setup() first.', vim.log.levels.ERROR)
    return false
  end

  -- Use provided display mode or fall back to current/default
  local mode = require("notes.config").validate_display_mode(display_mode, state.current_display_mode)

  local old_notes_file_path = state.current_notes_file_path
  state.current_notes_file_path = notes_file_path or state.config.notes_file_path

  -- Get or create buffer
  local buf = require("notes.buffer").get_or_create()
  if not buf then
    return false
  end

  -- If window is already open
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    -- If we already have the desired mode, just focus it
    if state.current_display_mode == mode and old_notes_file_path == state.current_notes_file_path then
      window.focus(state.win, buf)
      return true
    else
      -- Close it first and continue
      M.hide() -- This will remember the current window size
    end
  end

  -- Update state
  state.current_display_mode = mode

  -- Create window based on display mode
  local win
  if mode == "floating" then
    local win_config = window.get_floating_config()
    if not win_config then
      utils.notify("Failed to get floating window configuration", vim.log.levels.ERROR)
      return false
    end

    win = vim.api.nvim_open_win(buf, true, win_config)
    if win == 0 then
      utils.notify("Failed to create floating window", vim.log.levels.ERROR)
      return false
    end
  else
    win = window.create_split(buf, mode)
    if not win then
      return false
    end
  end

  state.win = win
  window.set_options(win)
  window.focus(win, buf)
  return true
end

--- Hide the notes window and remember its size
--- @return boolean Success status
function M.hide()
  if not state.win or not vim.api.nvim_win_is_valid(state.win) then
    return true -- Already hidden
  end

  -- Remember window size before hiding
  window.remember_size()

  -- Auto-save if enabled and buffer is modified
  if state.config.auto_save then
    note.save()
  end

  local path = note.get_path()
  local buf = state.buffers[path]

  -- Trigger leave events before closing
  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_exec_autocmds("BufLeave", { buffer = buf })
    vim.api.nvim_exec_autocmds("BufWinLeave", { buffer = buf })
    vim.api.nvim_exec_autocmds("WinLeave", { buffer = buf })
  end

  -- Close window
  local ok, err = pcall(vim.api.nvim_win_close, state.win, false)
  if not ok then
    utils.notify("Failed to close window: " .. tostring(err), vim.log.levels.WARN)
  end

  -- Trigger BufHidden after window is closed
  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_exec_autocmds("BufHidden", { buffer = buf })
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
    utils.notify('Plugin not setup. Call require("notes").setup() first.', vim.log.levels.ERROR)
    return false
  end

  return note.save()
end

--- Edit notes in current buffer (not in floating window/split)
--- @param notes_file_path string|nil Override notes file path
--- @return boolean Success status
function M.edit(notes_file_path)
  if not state.is_setup then
    utils.notify('Plugin not setup. Call require("notes").setup() first.', vim.log.levels.ERROR)
    return false
  end

  -- Update current notes file if a new path is provided
  state.current_notes_file_path = notes_file_path or state.config.notes_file_path

  local path = note.get_path()
  local ok, err = pcall(vim.cmd.edit, path)
  if not ok then
    utils.notify("Failed to edit notes file: " .. tostring(err), vim.log.levels.ERROR)
    return false
  end

  return true
end

--- Get current plugin status including window size information
--- @return table Status information
function M.status()
  local path = note.get_path()
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

return M
