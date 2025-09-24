local M = {}

local state = require("notes.state")
local utils = require("notes.utils")
local note = require("notes.note")

--- Configure buffer options for the notes buffer
--- @param buf number The buffer handle
function M.set_options(buf)
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

--- Setup buffer-specific keymaps (only active when in notes buffer)
--- @param buf number The buffer handle
function M.set_keymaps(buf)
  local opts = { noremap = true, silent = true, buffer = buf }
  local keymaps = state.config.buffer_keymaps
  local commands = require("notes.commands")

  -- Quit keymaps
  if keymaps.quit then
    vim.keymap.set("n", keymaps.quit, commands.hide, vim.tbl_extend("force", opts, { desc = "Close notes window" }))
  end

  if keymaps.quit_alt then
    vim.keymap.set("n", keymaps.quit_alt, commands.hide, vim.tbl_extend("force", opts, { desc = "Close notes window" }))
  end

  -- Save keymap
  if keymaps.save then
    vim.keymap.set({ "n", "i" }, keymaps.save, commands.save, vim.tbl_extend("force", opts, { desc = "Save notes" }))
  end
end

--- Setup autocommands for auto-saving behavior and window size tracking
--- @param buf number The buffer handle
function M.set_autocommands(buf)
  local window = require("notes.window")

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
        window.remember_size()
        -- Small delay to handle rapid window switching
        vim.defer_fn(note.save, 50)
      end,
      desc = "Auto-save notes and remember window size when buffer is hidden",
    })
  end

  -- Track window resize events to remember user preferences
  vim.api.nvim_create_autocmd("VimResized", {
    group = state.augroup,
    callback = window.remember_size,
    desc = "Remember window size when Vim is resized",
  })

  -- Handle floating window close events
  vim.api.nvim_create_autocmd("WinClosed", {
    group = state.augroup,
    callback = function(args)
      local closed_win = tonumber(args.match)
      if closed_win == state.win then
        window.remember_size()
        state.win = nil
      end
    end,
    desc = "Clean up window reference and remember size on close",
  })

  -- Auto-save on Neovim exit
  if state.config.auto_save_on_exit then
    vim.api.nvim_create_autocmd("VimLeavePre", {
      group = state.augroup,
      callback = note.save,
      desc = "Auto-save notes on Neovim exit",
    })
  end
end

--- Check if buffer content is in sync with file system
--- @param buf number Buffer handle
--- @param filepath string File path
--- @return boolean True if buffer is valid and in sync
function M.is_valid_and_synced(buf, filepath)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return false
  end

  -- Check if buffer name matches the expected path
  local buf_name = vim.api.nvim_buf_get_name(buf)
  if buf_name ~= filepath then
    return false
  end

  -- If file doesn't exist, buffer is stale (unless it's a new unsaved buffer)
  if not utils.file_exists(filepath) then
    -- Check if buffer has been modified - if so, it might be intentionally new
    local is_modified = vim.api.nvim_get_option_value("modified", { buf = buf })
    if not is_modified then
      -- File was deleted and buffer hasn't been modified - it's stale
      return false
    end
  end

  return true
end

--- Clean up stale buffer reference
--- @param filepath string File path
function M.cleanup_stale(filepath)
  local buf = state.buffers[filepath]
  if buf and vim.api.nvim_buf_is_valid(buf) then
    -- Wipe out the stale buffer to fully clean it up
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end
  state.buffers[filepath] = nil
end

--- Get or create the notes buffer
--- @return number|nil The buffer handle or nil on failure
function M.get_or_create()
  local path = note.get_path()

  -- If we already have a buffer for this file, return it
  local buf = state.buffers[path]
  if M.is_valid_and_synced(buf, path) then
    return buf
  end

  -- If buffer is stale or invalid - clean it up
  if buf then
    M.cleanup_stale(path)
  end

  -- Create new buffer
  buf = vim.api.nvim_create_buf(false, true)
  if buf == 0 then
    utils.notify("Failed to create notes buffer", vim.log.levels.ERROR)
    return nil
  end

  -- Set buffer name to the notes file path
  local ok, err = pcall(vim.api.nvim_buf_set_name, buf, path)
  if not ok then
    utils.notify("Failed to set buffer name: " .. tostring(err), vim.log.levels.WARN)
  end

  -- Load content
  local notes_exist = utils.file_exists(note.get_path())
  local content
  if notes_exist then
    vim.api.nvim_exec_autocmds("BufReadPre", { buffer = buf })
    content = note.load()
  else
    vim.api.nvim_exec_autocmds("BufNewFile", { buffer = buf })
    content = note.create()
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)

  if notes_exist then
    vim.api.nvim_exec_autocmds("BufReadPost", { buffer = buf })
    vim.api.nvim_set_option_value("modified", false, { buf = buf })
  else
    vim.api.nvim_set_option_value("modified", true, { buf = buf })
  end

  -- Setup buffer-specific features
  M.set_options(buf)
  M.set_keymaps(buf)
  M.set_autocommands(buf)

  state.buffers[path] = buf
  return buf
end

return M
