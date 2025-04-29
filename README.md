
# Neaterminal.nvim

A simple terminal management plugin for Neovim.

## Features

- Floating and split terminals
- Terminal toggling and management
- Support for TUI applications (lazygit, yazi, etc.)
- Resizing and maximizing
- Terminal process monitoring

## Requirements

- Neovim 0.11.0 or later

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "yourusername/neaterminal.nvim",
  config = function()
    require("neaterminal").setup({})
  end
}
```


## Usage

### Commands

- `Nea run [command] [options]` - Run a command in a terminal (toggle if already running)
- `Nea resize [+/-amount]` - Resize current terminal
- `Nea maximize` - Maximize/restore current terminal
- `Nea close` - Close current terminal
- `Nea list` - List all active terminals
- `Nea apps [app_name]` - Launch a predefined application

### Command Examples

```
:Nea run                    " Open a floating terminal with default shell
:Nea run float              " Same as above
:Nea run split              " Open a split terminal with default shell
:Nea run right              " Open a split terminal to the right

:Nea run lazygit            " Run lazygit in a floating terminal
:Nea run gitui split        " Run gitui in a split terminal

:Nea run bash title=My\ Shell border=rounded  " Run with custom title and border
:Nea run python width=100 height=30           " Run with custom dimensions

:Nea resize +10             " Increase terminal size by 10
:Nea resize -5              " Decrease terminal size by 5

:Nea apps lazygit           " Run lazygit from predefined apps
:Nea apps btop split        " Run btop in a split window
```

### Command Toggling

Commands work as toggles. Running the same command again will hide/show the terminal:

```
:Nea run lazygit    " First time: opens lazygit
:Nea run lazygit    " Second time: hides lazygit
:Nea run lazygit    " Third time: shows lazygit again
```

## Configuration

### Default Configuration

```lua
require("neaterminal").setup({
  -- Default terminal configurations
  float = {
    title = "Terminal",
    border = "rounded",
    width = math.floor(vim.o.columns * 0.8),
    height = math.floor(vim.o.lines * 0.8),
  },
  split = {
    split = "below",
    vertical = false,
  },
  autoclose = true,  -- Close window when process exits
  enter = true,      -- Enter terminal mode after opening
  persist = true,    -- Keep buffer when hiding window

  -- Pre-defined terminal configurations
  terminals = {
    my_lazygit = {
      cmd = "lazygit",
      type = "float",
      title = " LazyGit ",
      title_pos = "center",
      border = "rounded",
    },
    file_explorer = {
      cmd = "yazi",
      type = "split",
      vertical = true,
      width = 80,
    }
  }
})
```

## API

### Core Functions

```lua
local neaterminal = require("neaterminal")

-- Run a command in a terminal
neaterminal.run("lazygit")                   -- Simple command
neaterminal.run({ cmd = "gitui", type = "float" })  -- With options

-- Toggle a terminal by key
neaterminal.toggle("terminal_lazygit_float")

-- Resize a terminal
neaterminal.resize(nil, "+10")  -- Current terminal, increase by 10
neaterminal.resize("my_term", "-5")  -- Named terminal, decrease by 5

-- Maximize/restore a terminal
neaterminal.maximize()  -- Current terminal

-- Close a terminal
neaterminal.close("my_term")
```

## Creating Custom Commands or Keymaps

### Simple Keymaps

```lua
-- Open a floating terminal
vim.keymap.set("n", "<leader>tf", ":Nea run float<CR>", { noremap = true })

-- Open a split terminal
vim.keymap.set("n", "<leader>ts", ":Nea run split<CR>", { noremap = true })

-- Run lazygit
vim.keymap.set("n", "<leader>lg", ":Nea run lazygit<CR>", { noremap = true })

-- Maximize current terminal
vim.keymap.set("n", "<leader>tm", ":Nea maximize<CR>", { noremap = true })
```

### Create Custom Terminal Application

```lua
-- Create a custom function to run htop with specific settings
function _G.open_htop()
  require("neaterminal").run({
    cmd = "htop",
    type = "float",
    key = "my_htop",  -- Custom key
    title = " System Monitor ",
    title_pos = "center",
    border = "double",
    width = math.floor(vim.o.columns * 0.9),
    height = math.floor(vim.o.lines * 0.9),
    autoclose = true,
  })
end

-- Map a key to this function
vim.keymap.set("n", "<leader>ht", open_htop, { noremap = true })

-- Or create a custom user command
vim.api.nvim_create_user_command("Htop", open_htop, {})
```

### Extending with Your Own Applications

You can extend the plugin with your own applications in your config:

```lua
local neaterminal = require("neaterminal")
local apps = {}

-- Create custom app functions
function apps.ranger()
  return neaterminal.run({
    cmd = "ranger",
    key = "file_explorer",
    type = "float",
    title = " Ranger ",
    border = "rounded",
  })
end

function apps.ncmpcpp()
  return neaterminal.run({
    cmd = "ncmpcpp",
    key = "music_player",
    type = "split",
    height = 20,
    title = " Music Player ",
  })
end

-- Create command
vim.api.nvim_create_user_command("Ranger", apps.ranger, {})
vim.api.nvim_create_user_command("MusicPlayer", apps.ncmpcpp, {})

-- Create keymap
vim.keymap.set("n", "<leader>ra", apps.ranger, { noremap = true })
```

## Advanced: Terminal Event Handling

You can use Neovim's autocmd to handle terminal events:

```lua
-- Auto-enter insert mode when switching to a terminal
vim.api.nvim_create_autocmd("BufEnter", {
  pattern = "term://*",
  callback = function()
    if vim.bo.filetype == "neaterminal" then
      vim.cmd.startinsert()
    end
  end,
})

-- Hide line numbers in terminals
vim.api.nvim_create_autocmd("TermOpen", {
  pattern = "*",
  callback = function()
    if vim.bo.filetype == "neaterminal" then
      vim.opt_local.number = false
      vim.opt_local.relativenumber = false
    end
  end,
})
```

## Understanding the Implementation

The plugin uses Neovim's `jobstart()` with `term = true` to create terminal processes and manages window/buffer creation separately. Terminal state tracking allows for hiding/showing terminals and preserves running processes across window toggles.
