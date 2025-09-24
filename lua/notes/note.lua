local M = {}
local state = require("notes.state")
local utils = require("notes.utils")

--- Get the full path to the notes file
--- @return string The absolute path to the notes file
function M.get_path()
  return vim.fn.expand(state.current_notes_file_path)
end

--- Return default notes content
--- @return table Lines of content
function M.create()
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
    "",
  }
end

--- Load notes content from file or return default content
--- @return table Lines of content
function M.load()
  local path = M.get_path()
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
    return M.create()
  end
end

--- Save notes to file
--- @return boolean Success status
function M.save()
  local path = M.get_path()
  local buf = state.buffers[path]

  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    return false
  end

  -- Check if buffer is actually modified
  if not vim.api.nvim_get_option_value("modified", { buf = buf }) then
    return true -- Nothing to save
  end

  -- Trigger pre-write events
  vim.api.nvim_exec_autocmds("BufWritePre", { buffer = buf })
  vim.api.nvim_exec_autocmds("FileWritePre", { buffer = buf })

  -- Ensure directory exists
  local dir = vim.fn.fnamemodify(path, ":h")
  if vim.fn.isdirectory(dir) == 0 then
    local ok, err = pcall(vim.fn.mkdir, dir, "p")
    if not ok then
      utils.notify("Failed to create directory: " .. tostring(err), vim.log.levels.ERROR)
      return false
    end
  end

  -- Get buffer content
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local content = table.concat(lines, "\n")

  -- Write to file
  local file, err = io.open(path, "w")
  if not file then
    utils.notify("Failed to open file for writing: " .. tostring(err), vim.log.levels.ERROR)
    return false
  end

  local write_ok, write_err = file:write(content)
  file:close()

  if not write_ok then
    utils.notify("Failed to write to file: " .. tostring(write_err), vim.log.levels.ERROR)
    return false
  end

  -- Mark buffer as unmodified
  vim.api.nvim_set_option_value("modified", false, { buf = buf })

  -- Trigger post-write events
  vim.api.nvim_exec_autocmds("FileWritePost", { buffer = buf })
  vim.api.nvim_exec_autocmds("BufWritePost", { buffer = buf })

  utils.notify("Notes saved!")
  return true
end

return M
