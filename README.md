# notes.nvim

[![GitHub License](https://img.shields.io/github/license/etiennecollin/notes.nvim?label=License&logo=github&color=red)](https://github.com/etiennecollin/notes.nvim)

A simple and fast notes plugin for Neovim that lets you quickly take markdown notes in floating windows or splits with intelligent auto-save functionality and session-persistent window sizing.

## ✨ Features

- **Multiple Display Modes**: Open notes in floating windows, horizontal splits, or vertical splits
- **Dynamic Mode Switching**: Change display modes on the fly with command arguments
- **Smart Window Sizing**: Remembers window sizes per display mode throughout your session
- **Auto-save**: Automatically saves when you hide the window, leave the buffer, or exit Neovim
- **Customizable Keymaps**: Buffer-specific keymaps that only work when in the notes window
- **File Persistence**: Notes are saved to a configurable markdown file
- **Zero Dependencies**: Works out of the box with just Neovim

## 📦 Installation

## Quick Start

### Install and setup the plugin

<details open>
<summary>Using lazy.nvim</summary>

```lua
{
  "etiennecollin/notes.nvim",
  cmd = { "NotesToggle", "NotesShow", "NotesHide", "NotesEdit" },
  keys = {
    { "<leader>n", "<cmd>NotesToggle<cr>", desc = "Toggle Notes" },
  },
  opts = {},
}
```

</details>

<details>
<summary>Using packer.nvim</summary>

```lua
use {
    "etiennecollin/notes.nvim",
    config = function()
    require("notes").setup()
    end
}
```

</details>

<details>
<summary>Using vim-plug</summary>

```vim
Plug "etiennecollin/notes.nvim"

lua << EOF
require("notes").setup()
EOF

```

</details>

### Add your preferred keymaps

```lua
vim.keymap.set("n", "<leader>n", require("notes").toggle, { desc = "Toggle notes" })
```

### Use the commands

- `:NotesToggle` - Toggle notes window
- `:NotesShow floating` - Show notes in floating window
- `:NotesShow hsplit` - Show notes in horizontal split
- `:NotesShow vsplit` - Show notes in vertical split
- `:NotesHide` - Hide notes
- `:NotesEdit` - Edit notes in current window
- `:NotesSave` - Manually save notes

## Configuration

See the [default configuration](./lua/notes/init.lua#L55).

### Configuration Examples

#### Minimal Setup

```lua
require("notes").setup({
  notes_file_path = "~/Documents/my-notes.md",
})
```

#### Custom Floating Window

```lua
require("notes").setup({
  display_mode = "floating",
  floating = {
    width = 100,
    height = 30,
    border = "double",
    title = " My Notes ",
  },
})
```

#### Split-Focused Setup

```lua
require("notes").setup({
  display_mode = "vsplit",
  split = {
    hsplit_height = 30,
    vsplit_width = 120,
  },
})
```

#### Disable Auto-save

```lua
require("notes").setup({
  auto_save = false,
  auto_save_on_exit = false,
  buffer_keymaps = {
    save = "<C-s>", -- Manual save only
    quit = "qq", -- Hit q twice to quit
  },
})
```

## 🎯 Usage

### Commands

| Command        | Arguments | Description                                           |
| -------------- | --------- | ----------------------------------------------------- |
| `:NotesToggle` | `[mode]`  | Toggle notes window (optionally specify display mode) |
| `:NotesShow`   | `[mode]`  | Show notes window (optionally specify display mode)   |
| `:NotesHide`   | -         | Hide notes window                                     |
| `:NotesSave`   | -         | Manually save notes                                   |
| `:NotesEdit`   | -         | Edit notes in current buffer (not in popup/split)     |

**Mode arguments**: `floating`, `hsplit`, `vsplit`

### Examples

```vim
" Toggle with default mode
:NotesToggle

" Show in floating window
:NotesShow floating

" Toggle to horizontal split
:NotesToggle hsplit

" Show in vertical split
:NotesShow vsplit
```

### Lua API

```lua
local notes = require("notes")

-- Toggle notes window
notes.toggle()
notes.toggle("hsplit")

-- Show with specific mode
notes.show("floating")
notes.show("vsplit")

-- Hide notes window
notes.hide()

-- Save notes manually
notes.save()

-- Edit notes in current buffer
notes.edit()

-- Get plugin status
local status = notes.status()
print(vim.inspect(status))
```

### Buffer Keymaps

When the notes buffer is active, these keymaps are available (configurable):

- `q` or `<Esc>` - Close notes window
- `<C-s>` - Save notes

## 🧠 Smart Features

### Window Size Memory

The plugin remembers window sizes per display mode throughout your Neovim session:

- **Floating**: Remembers width and height
- **Horizontal Split**: Remembers height
- **Vertical Split**: Remembers width

When you resize a window and reopen it, your preferred size is restored automatically.

### Auto-save Behavior

Notes are automatically saved:

- When you hide/close the notes window
- When you leave the notes buffer
- When you exit Neovim

### Mode Switching

You can seamlessly switch between display modes:

```lua
-- Switch from floating to split
vim.keymap.set("n", "<leader>nf", function() require("notes").show("floating") end)
vim.keymap.set("n", "<leader>nh", function() require("notes").show("hsplit") end)
vim.keymap.set("n", "<leader>nv", function() require("notes").show("vsplit") end)
```

## 🎨 Customization Ideas

### Custom Keymaps

```lua
-- Quick toggle
vim.keymap.set("n", "<leader>n", require("notes").toggle, { desc = "Toggle notes" })

-- Mode-specific toggles
vim.keymap.set("n", "<leader>nf", function() require("notes").toggle("floating") end, { desc = "Toggle floating notes" })
vim.keymap.set("n", "<leader>nh", function() require("notes").toggle("hsplit") end, { desc = "Toggle horizontal split notes" })
vim.keymap.set("n", "<leader>nv", function() require("notes").toggle("vsplit") end, { desc = "Toggle vertical split notes" })

-- Manually save
vim.keymap.set("n", "<leader>ns", require("notes").save, { desc = "Save notes" })

-- Edit in main buffer
vim.keymap.set("n", "<leader>ne", require("notes").edit, { desc = "Edit notes in buffer" })
```

### Multiple Notes Files

```lua
-- Setup function for different note types
local function setup_notes(name, file, keymap)
  local notes = require("notes")

  vim.keymap.set("n", keymap, function()
    notes.toggle(nil, file)
  end, { desc = "Toggle " .. name })
end

-- Different note files for different purposes
setup_notes("work notes", "~/work-notes.md", "<leader>nw")
setup_notes("personal notes", "~/personal-notes.md", "<leader>np")
setup_notes("ideas", "~/ideas.md", "<leader>ni")
```

## 🤝 Contributing

Contributions are welcome! Feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change. Make sure to format your code using StyLua.

---

If you find this plugin useful, please consider giving it a ⭐ on GitHub!
