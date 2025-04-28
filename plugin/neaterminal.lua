if vim.g.loaded_neaterminal then
  return
end
vim.g.loaded_neaterminal = true

local neaterminal = require("neaterminal")
local apps = require("neaterminal.apps")

-- Function to parse command arguments
---@param args string Raw command arguments
---@return table Structured command options
local function parse_command_args(args)
  local parsed = {}
  local parts = vim.split(args, "%s+")

  -- Check for window type specifier (float or split variants)
  for i, part in ipairs(parts) do
    if part == "float" then
      parsed.type = "float"
      parts[i] = nil
    elseif part == "split" then
      parsed.type = "split"
      -- Normal horizontal split
      parsed.vertical = false
      parts[i] = nil
    elseif part == "vsplit" or part == "vertical" then
      parsed.type = "split"
      parsed.vertical = true
      parsed.split = "right" -- Default to right for vsplit
      parts[i] = nil
    -- Add support for directional splits
    elseif part == "left" then
      parsed.type = "split"
      parsed.vertical = true
      parsed.split_direction = "left"
      parts[i] = nil
    elseif part == "right" then
      parsed.type = "split"
      parsed.vertical = true
      parsed.split_direction = "right"
      parts[i] = nil
    elseif part == "top" or part == "above" then
      parsed.type = "split"
      parsed.vertical = false
      parsed.split_direction = "above"
      parts[i] = nil
    elseif part == "bottom" or part == "below" then
      parsed.type = "split"
      parsed.vertical = false
      parsed.split_direction = "below"
      parts[i] = nil
    end
  end

  -- Parse key=value options
  for i, part in ipairs(parts) do
    if part and part:match("^%w+=%S+$") then
      local key, value = part:match("^(%w+)=(%S+)$")

      -- Convert numeric values
      if tonumber(value) then
        parsed[key] = tonumber(value)
      else
        parsed[key] = value
      end

      parts[i] = nil
    end
  end

  -- Remaining parts are the command if any
  local cmd_parts = {}
  for _, part in ipairs(parts) do
    if part and part ~= "" then
      table.insert(cmd_parts, part)
    end
  end

  if #cmd_parts > 0 then
    parsed.cmd = table.concat(cmd_parts, " ")
  end

  return parsed
end

-- Generate a consistent key for a command
local function generate_terminal_key(cmd, type)
  if not cmd then
    -- Default shell
    if type == "split" then
      return "default_split_shell"
    else
      return "default_float_shell"
    end
  end

  -- For commands, create a consistent key
  return "terminal_" .. cmd:gsub("%s+", "_") .. "_" .. (type or "float")
end

-- Command implementations
local commands = {
  -- Run a command in a terminal (or toggle if already running)
  run = function(args)
    local opts = parse_command_args(args)

    -- If only "float" or "split" was specified with no command, use default shell
    if not opts.cmd and (opts.type == "float" or opts.type == "split") then
      opts.cmd = vim.o.shell
    end

    if not opts.cmd then
      vim.notify("No command specified", vim.log.levels.ERROR)
      return
    end

    -- Generate a consistent key for this command/type combination
    local key = generate_terminal_key(opts.cmd, opts.type)
    opts.key = key

    -- Check if this terminal already exists
    if neaterminal.terminals[key] then
      -- If window is visible, hide it
      if vim.api.nvim_win_is_valid(neaterminal.terminals[key].win) then
        vim.api.nvim_win_hide(neaterminal.terminals[key].win)
        return
      end

      -- If window exists but is hidden, restore it
      if vim.api.nvim_buf_is_valid(neaterminal.terminals[key].buf) then
        -- Check if the job is still running
        local job_status = vim.fn.jobwait({ neaterminal.terminals[key].job_id }, 0)[1]
        if job_status == -1 then
          -- Job is still running, reuse the terminal
          local win_type = neaterminal.terminals[key].type
          if win_type == "split" then
            neaterminal.create_split_window(key)
          else
            neaterminal.create_float_window(key)
          end
          return
        end
      end
    end

    -- Create new terminal
    neaterminal.run(opts)
  end,

  -- Toggle a terminal (for backward compatibility)
  toggle = function(args)
    local key = args ~= "" and args or nil
    neaterminal.toggle(key)
  end,

  -- Resize a terminal
  resize = function(args)
    local key, amount

    -- If args contains a space, first part is key, second is amount
    if args:find(" ") then
      key, amount = args:match("([^ ]+)%s+(.+)")
    else
      -- Otherwise it's just the amount for the current terminal
      amount = args
    end

    neaterminal.resize(key, amount)
  end,

  -- Maximize or restore a terminal
  maximize = function(args)
    local key = args ~= "" and args or nil
    neaterminal.maximize(key)
  end,

  -- Close a terminal
  close = function(args)
    local key = args ~= "" and args or nil
    neaterminal.close(key)
  end,

  -- List all terminals
  list = function(_)
    local terminals = neaterminal.terminals

    if vim.tbl_isempty(terminals) then
      vim.notify("No active terminals", vim.log.levels.INFO)
      return
    end

    local lines = { "Active terminals:" }
    for key, term in pairs(terminals) do
      local win_status = vim.api.nvim_win_is_valid(term.win) and "open" or "closed"
      local proc_status = vim.fn.jobwait({ term.job_id }, 0)[1] == -1 and "running" or "exited"
      local cmd_display = term.cmd or "shell"
      table.insert(lines, string.format("- %s (%s, process %s): %s", key, win_status, proc_status, cmd_display))
    end

    vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
  end,

  -- Run common applications
  apps = function(args)
    local app_name = args:match("^([^ ]+)")
    local app_args = args:match("^[^ ]+%s+(.+)$") or ""

    if not app_name then
      vim.notify("No application specified", vim.log.levels.ERROR)
      return
    end

    -- For apps, we want them to be togglable too
    local parsed_args = parse_command_args(app_args)
    local key

    if app_name == "lazygit" then
      key = "app_lazygit_" .. (parsed_args.type or "float")
      parsed_args.key = key

      -- Check if it's already open
      if neaterminal.terminals[key] and vim.api.nvim_win_is_valid(neaterminal.terminals[key].win) then
        vim.api.nvim_win_hide(neaterminal.terminals[key].win)
        return
      end

      apps.lazygit(parsed_args)
    elseif app_name == "yazi" then
      key = "app_yazi_" .. (parsed_args.type or "float")
      parsed_args.key = key

      -- Check if it's already open
      if neaterminal.terminals[key] and vim.api.nvim_win_is_valid(neaterminal.terminals[key].win) then
        vim.api.nvim_win_hide(neaterminal.terminals[key].win)
        return
      end

      apps.yazi(parsed_args)
    elseif app_name == "btop" then
      key = "app_btop_" .. (parsed_args.type or "float")
      parsed_args.key = key

      -- Check if it's already open
      if neaterminal.terminals[key] and vim.api.nvim_win_is_valid(neaterminal.terminals[key].win) then
        vim.api.nvim_win_hide(neaterminal.terminals[key].win)
        return
      end

      apps.btop(parsed_args)
    elseif app_name == "shell" then
      key = "app_shell_" .. (parsed_args.type or "float")
      parsed_args.key = key

      -- Check if it's already open
      if neaterminal.terminals[key] and vim.api.nvim_win_is_valid(neaterminal.terminals[key].win) then
        vim.api.nvim_win_hide(neaterminal.terminals[key].win)
        return
      end

      apps.shell(parsed_args)
    else
      vim.notify("Unknown application: " .. app_name, vim.log.levels.ERROR)
    end
  end,
}

-- Main command
vim.api.nvim_create_user_command("Nea", function(opts)
  local args = vim.split(opts.args, "%s+", { trimempty = true })
  local subcmd = table.remove(args, 1) or ""
  local remaining_args = table.concat(args, " ")

  if commands[subcmd] then
    commands[subcmd](remaining_args)
  else
    vim.notify("Unknown Neaterminal command: " .. subcmd, vim.log.levels.ERROR)
  end
end, {
  nargs = "*",
  complete = function(arg_lead, cmd_line, cursor_pos)
    local parts = vim.split(cmd_line:sub(1, cursor_pos), "%s+")
    local argc = #parts - 1

    if argc == 1 then
      -- Complete subcommands
      local subcmds = { "run", "toggle", "resize", "maximize", "close", "list", "apps" }
      if arg_lead == "" then
        return subcmds
      end

      -- Filter by prefix
      local matches = {}
      for _, cmd in ipairs(subcmds) do
        if cmd:sub(1, #arg_lead) == arg_lead then
          table.insert(matches, cmd)
        end
      end
      return matches
    elseif argc == 2 then
      local subcmd = parts[2]

      -- For specific subcommands, provide relevant completions
      if subcmd == "toggle" or subcmd == "close" or subcmd == "maximize" then
        -- Complete with terminal names
        local terminals = {}
        for key, _ in pairs(neaterminal.terminals) do
          if key:sub(1, #arg_lead) == arg_lead then
            table.insert(terminals, key)
          end
        end
        return terminals
      elseif subcmd == "apps" then
        -- Complete with app names
        local app_names = { "lazygit", "yazi", "btop", "shell" }
        if arg_lead == "" then
          return app_names
        end

        local matches = {}
        for _, app in ipairs(app_names) do
          if app:sub(1, #arg_lead) == arg_lead then
            table.insert(matches, app)
          end
        end
        return matches
      elseif subcmd == "run" then
        -- Window types

        if arg_lead == "" then
          return { "float", "split", "vsplit", "vertical", "left", "right", "top", "bottom", "above", "below" }
        elseif ("float"):sub(1, #arg_lead) == arg_lead then
          return { "float" }
        elseif ("split"):sub(1, #arg_lead) == arg_lead then
          return { "split" }
        elseif ("vsplit"):sub(1, #arg_lead) == arg_lead then
          return { "vsplit" }
        elseif ("vertical"):sub(1, #arg_lead) == arg_lead then
          return { "vertical" }
        elseif ("left"):sub(1, #arg_lead) == arg_lead then
          return { "left" }
        elseif ("right"):sub(1, #arg_lead) == arg_lead then
          return { "right" }
        end
      end
    elseif argc >= 3 then
      local subcmd = parts[2]

      -- For specific subcommands, provide additional completions
      if subcmd == "run" or subcmd == "apps" then
        -- Window types

        if arg_lead == "" then
          return { "float", "split", "vsplit", "border=rounded", "title=", "width=", "height=" }
        elseif ("float"):sub(1, #arg_lead) == arg_lead then
          return { "float" }
        elseif ("split"):sub(1, #arg_lead) == arg_lead then
          return { "split" }
        elseif ("vsplit"):sub(1, #arg_lead) == arg_lead then
          return { "vsplit" }
        elseif ("border="):sub(1, #arg_lead) == arg_lead then
          return { "border=rounded", "border=single", "border=double", "border=none" }
        end
      end
    end

    return {}
  end,
})

-- Setup with minimal default configuration
neaterminal.setup({
  -- No default keymaps
})

-- Add escape mapping for terminal
vim.keymap.set("t", "<ESC><ESC>", "<C-\\><C-n>")
