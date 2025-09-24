local M = {}

-- Plugin metadata
M._VERSION = "1.0.0"
M._NAME = "notes.nvim"

--- Setup the plugin with user configuration
--- @param opts NotesConfig|nil User configuration options
function M.setup(opts)
  local state = require("notes.state")

  -- Merge configuration
  opts = opts or {}
  state.config = vim.tbl_deep_extend("force", require("notes.config").defaults, opts)
  state.config = require("notes.config").validate(state.config)

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

  local commands = require("notes.commands")
  local nvim_commands = {
    {
      "NotesToggle",
      function(opts)
        local args = vim.split(opts.args, " ")
        local display_mode = args[1] ~= "" and args[1] or nil
        local notes_path = args[2] ~= nil and args[2] or nil
        commands.toggle(display_mode, notes_path)
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
        commands.show(display_mode, notes_path)
      end,
      {
        desc = "Show notes window",
        nargs = "*",
        complete = complete_toggle_show,
      },
    },
    {
      "NotesHide",
      commands.hide,
      { desc = "Hide notes window" },
    },
    {
      "NotesSave",
      commands.save,
      { desc = "Save notes to file" },
    },
    {
      "NotesEdit",
      function(opts)
        local notes_file_path = opts.args ~= "" and opts.args or nil
        commands.edit(notes_file_path)
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

  for _, cmd in ipairs(nvim_commands) do
    vim.api.nvim_create_user_command(cmd[1], cmd[2], cmd[3])
  end

  state.is_setup = true
end

-- Expose commands directly for convenience
M = vim.tbl_deep_extend("force", M, require("notes.commands"))

return M
