local M = {}

--- Utility function for notifications
--- @param msg string The message to display
--- @param level number|nil The log level (defaults to INFO)
function M.notify(msg, level)
  vim.notify("[" .. require("notes")._NAME .. "] " .. msg, level or vim.log.levels.INFO)
end

--- Check if a file exists at the given path
--- @param name string The absolute path to the file
--- @return boolean True if the file exists, false otherwise
function M.file_exists(name)
  local f = io.open(name, "r") -- try to open file for reading
  if f then
    f:close() -- close the file if it was opened
    return true
  else
    return false
  end
end

return M
