---@brief [[
--- NeatTerminal - A simple, elegant terminal management plugin for Neovim
--- Provides floating and split terminals with comprehensive controls
---@brief ]]

local M = {}

---@class NeaterminalOptions
---@field cmd string? Command to run in terminal
---@field type "float"|"split" Terminal window type
---@field enter boolean? Whether to enter terminal mode after opening
---@field width number? Window width (for float)
---@field height number? Window height (for float)
---@field split_direction "left"|"right"|"above"|"below" Direction for split windows
---@field border "none"|"single"|"double"|"rounded"|"solid"|"shadow"|string[] Border style
---@field title string? Optional window title
---@field title_pos "left"|"center"|"right" Position of the title
---@field autoclose boolean? Whether to close window when terminal process exits
---@field persist boolean? Whether to keep buffer when hiding window
---@field env table<string,string>? Environment variables for the command
---@field key string? Unique identifier for this terminal instance

---@type table<string, {buf: integer, win: integer, cmd: string|string[], type: string, job_id: integer, config: table, original_size: table?}>
M.terminals = {}

-- Keep track of the last used terminal for smart operations
M._last_terminal_key = nil

-- Default configuration
local default_config = {
  float = {
    title = "Terminal",
    relative = "editor",
    width = math.floor(vim.o.columns * 0.8),
    height = math.floor(vim.o.lines * 0.8),
    row = math.floor(vim.o.lines * 0.1),
    col = math.floor(vim.o.columns * 0.1),
    style = "minimal",
    border = "rounded",
  },
  split = {
    split = "below",
    vertical = false,
  },
  autoclose = true,
  enter = true,
  persist = true,
}

-- Calculate window position accounting for UI elements
---@return table
local function calculate_window_dimensions()
  local win_width = vim.o.columns
  local win_height = vim.o.lines
  local height = math.ceil(win_height * 0.8)
  local width = math.ceil(win_width * 0.8)

  local tabline_height = vim.o.showtabline > 0 and 1 or 0
  local has_statusline = vim.o.laststatus > 0
  local cmd_height = vim.o.cmdheight
  local has_border = true -- Assuming we're using borders by default

  -- Adjust for UI elements
  local row_offset = tabline_height + (has_border and 1 or 0)
  local bottom_offset = (has_statusline and 1 or 0) + cmd_height + (has_border and 1 or 0)

  -- Center the window
  local row = row_offset + math.floor((win_height - height - row_offset - bottom_offset) / 2)
  local col = math.floor((win_width - width) / 2)

  return {
    width = width,
    height = height,
    row = row,
    col = col,
  }
end

---Create a floating terminal window
---@param opts NeaterminalOptions
---@return {buf: integer, win: integer, job_id: integer}|nil Window, buffer and job handles
local function create_floating_terminal(opts)
  opts = vim.tbl_deep_extend("force", default_config, opts or {})

  -- Create a buffer for the terminal
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })

  -- Calculate window dimensions
  local dimensions = calculate_window_dimensions()
  local width = opts.width or dimensions.width
  local height = opts.height or dimensions.height

  -- Create the window
  local win = vim.api.nvim_open_win(buf, true, {
    style = "minimal",
    relative = "editor",
    width = width,
    height = height,
    row = dimensions.row,
    col = dimensions.col,
    border = opts.border or default_config.float.border,
    title = opts.title,
    title_pos = opts.title and (opts.title_pos or "left") or nil,
  })

  -- Configure window
  vim.wo[win].scrolloff = 0
  vim.wo[win].sidescrolloff = 0

  -- Prepare environment
  local env = {
    COLORTERM = "truecolor",
    TERM = "xterm-256color",
  }

  -- Add custom environment variables
  if opts.env then
    for k, v in pairs(opts.env) do
      env[k] = v
    end
  end

  -- Set buffer options for a terminal
  vim.api.nvim_set_option_value("filetype", "neaterminal", { buf = buf })

  -- Start the process
  local cmd = opts.cmd or vim.o.shell
  local job_id = vim.fn.jobstart(cmd, {
    term = true, -- This makes it a terminal job
    pty = true, -- Use a PTY for terminal emulation
    env = env,
    on_exit = function(_, exit_code, _)
      if opts.autoclose ~= false then
        if vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_win_close(win, true)
        end
      end

      -- Customize exit code notification
      if exit_code == 0 then
      -- Success, no need for notification
      elseif
        exit_code == 1
        and type(opts.cmd) == "string"
        and (opts.cmd:match("gitui") or opts.cmd:match("lazygit") or opts.cmd:match("yazi"))
      then
      -- Common exit code for TUIs, skip notification
      else
        vim.notify("Process exited with code " .. exit_code, vim.log.levels.WARN)
      end
    end,
  })

  if job_id <= 0 then
    vim.notify("Failed to start terminal job: " .. tostring(cmd), vim.log.levels.ERROR)
    vim.api.nvim_win_close(win, true)
    vim.api.nvim_buf_delete(buf, { force = true })
    return nil
  end

  if opts.enter ~= false then
    vim.cmd.startinsert()
  end

  return { buf = buf, win = win, job_id = job_id }
end

---Create a split terminal window
---@param opts NeaterminalOptions
---@return {buf: integer, win: integer, job_id: integer}|nil Window, buffer and job handles
local function create_split_terminal(opts)
  opts = vim.tbl_deep_extend("force", default_config, opts or {})

  -- Create a buffer for the terminal
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufnr })

  -- Determine split configuration
  local split_config = {
    split = opts.split or (opts.vertical and "right" or "below"),
  }

  -- If split direction is specified, convert it to the format nvim_open_win expects
  if opts.split_direction then
    split_config.split = opts.split_direction
  end

  -- Add the target window if specified
  if opts.win then
    split_config.win = opts.win
  end

  -- Create the window
  local win = vim.api.nvim_open_win(bufnr, true, split_config)

  -- Set buffer options
  vim.api.nvim_set_option_value("filetype", "neaterminal", { buf = bufnr })

  -- Prepare environment
  local env = {
    COLORTERM = "truecolor",
    TERM = "xterm-256color",
  }

  -- Add custom environment variables
  if opts.env then
    for k, v in pairs(opts.env) do
      env[k] = v
    end
  end

  -- Start the process
  local cmd = opts.cmd or vim.o.shell
  local job_id = vim.fn.jobstart(cmd, {
    term = true,
    pty = true,
    env = env,
    on_exit = function(_, exit_code, _)
      if opts.autoclose ~= false then
        if vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_win_close(win, true)
        end
      end

      -- Customize exit code notification
      if exit_code == 0 then
      -- Success, no need for notification
      elseif
        exit_code == 1
        and type(opts.cmd) == "string"
        and (opts.cmd:match("gitui") or opts.cmd:match("lazygit") or opts.cmd:match("yazi"))
      then
      -- Common exit code for TUIs, skip notification
      else
        vim.notify("Process exited with code " .. exit_code, vim.log.levels.WARN)
      end
    end,
  })

  if job_id <= 0 then
    vim.notify("Failed to start terminal job: " .. tostring(cmd), vim.log.levels.ERROR)
    vim.api.nvim_win_close(win, true)
    vim.api.nvim_buf_delete(bufnr, { force = true })
    return nil
  end

  -- Set window size if specified
  if opts.height and not opts.vertical then
    vim.api.nvim_win_set_height(win, opts.height)
  elseif opts.width and opts.vertical then
    vim.api.nvim_win_set_width(win, opts.width)
  end

  if opts.enter ~= false then
    vim.cmd.startinsert()
  end

  return { buf = bufnr, win = win, job_id = job_id }
end

---Get the currently focused terminal key if any
---@return string|nil The key of the focused terminal or nil
function M._get_focused_terminal()
  local current_win = vim.api.nvim_get_current_win()

  for key, term in pairs(M.terminals) do
    if term.win == current_win then
      return key
    end
  end

  return nil
end

---Toggle a terminal window
---@param key string|nil Unique terminal identifier, uses last used or default if nil
---@param opts NeaterminalOptions|nil Optional settings
function M.toggle(key, opts)
  -- Use last terminal if no key provided
  key = key or M._last_terminal_key or "default"
  opts = opts or {}
  opts.key = key

  -- If terminal exists and window is valid, close it
  if M.terminals[key] and vim.api.nvim_win_is_valid(M.terminals[key].win) then
    vim.api.nvim_win_hide(M.terminals[key].win)
    return
  end

  -- Create new terminal or reuse existing one
  local terminal_data
  if opts.type == "split" then
    terminal_data = create_split_terminal(opts)
  else
    terminal_data = create_floating_terminal(opts)
  end

  if not terminal_data then
    return
  end

  -- Store terminal data
  M.terminals[key] = {
    buf = terminal_data.buf,
    win = terminal_data.win,
    cmd = opts.cmd,
    job_id = terminal_data.job_id,
    type = opts.type or "float",
    config = vim.deepcopy(opts),
  }

  -- Update last used terminal
  M._last_terminal_key = key
end

---Open a terminal
---@param opts NeaterminalOptions|nil Optional settings
---@return {buf: integer, win: integer, job_id: integer}|nil Window and buffer handles
function M.open(opts)
  opts = opts or {}
  ---@diagnostic disable-next-line: ambiguity-1
  local key = opts.key or "terminal_" .. (opts.cmd or "shell")

  local terminal_data
  if opts.type == "split" then
    terminal_data = create_split_terminal(opts)
  else
    terminal_data = create_floating_terminal(opts)
  end

  if not terminal_data then
    return nil
  end

  -- Store terminal data
  M.terminals[key] = {
    buf = terminal_data.buf,
    win = terminal_data.win,
    cmd = opts.cmd,
    job_id = terminal_data.job_id,
    type = opts.type or "float",
    config = vim.deepcopy(opts),
  }

  -- Update last used terminal
  M._last_terminal_key = key

  return terminal_data
end

---Run a command in a terminal window
---@param cmd string|table Command to run or options table
---@param opts? NeaterminalOptions Optional settings
---@return {buf: integer, win: integer, job_id: integer}|nil Window and buffer handles
function M.run(cmd, opts)
  -- Handle the case where cmd is actually an options table
  if type(cmd) == "table" then
    opts = cmd
    cmd = opts.cmd
  end

  opts = opts or {}
  opts.cmd = cmd

  -- Generate a key based on the command if not specified
  if not opts.key then
    if type(cmd) == "string" then
      opts.key = "terminal_" .. cmd:gsub("%s+", "_")
    else
      opts.key = "terminal_" .. tostring(math.random(1000000))
    end
  end

  return M.open(opts)
end

---Resize a terminal window
---@param key string|nil Terminal identifier, uses focused terminal if nil
---@param amount number|string Change amount (can be relative like "+5" or "-10")
function M.resize(key, amount)
  -- If no key provided, try to get the focused terminal
  key = key or M._get_focused_terminal() or M._last_terminal_key

  if not key or not M.terminals[key] or not vim.api.nvim_win_is_valid(M.terminals[key].win) then
    vim.notify("Terminal not found or window is invalid", vim.log.levels.ERROR)
    return
  end

  local win = M.terminals[key].win
  local config = vim.api.nvim_win_get_config(win)
  local is_floating = config.relative ~= ""

  -- Convert amount to number if it's a string
  local change = amount
  if type(amount) == "string" then
    if amount:match("^%+") then
      change = tonumber(amount:sub(2))
    elseif amount:match("^%-") then
      change = -tonumber(amount:sub(2))
    else
      change = tonumber(amount)
    end
  end

  if not change then
    vim.notify("Invalid resize amount", vim.log.levels.ERROR)
    return
  end

  if is_floating then
    -- Floating window
    local new_config = {}
    local is_horizontal = M.terminals[key].config.resize_direction == "horizontal"

    if is_horizontal then
      new_config.width = config.width + change
    else
      new_config.height = config.height + change
    end

    vim.api.nvim_win_set_config(win, new_config)
  else
    -- Split window
    local is_vertical = M.terminals[key].config.vertical

    if is_vertical then
      local current_width = vim.api.nvim_win_get_width(win)
      vim.api.nvim_win_set_width(win, current_width + change)
    else
      local current_height = vim.api.nvim_win_get_height(win)
      vim.api.nvim_win_set_height(win, current_height + change)
    end
  end
end

---Maximize a terminal window
---@param key string|nil Terminal identifier, uses focused terminal if nil
function M.maximize(key)
  -- If no key provided, try to get the focused terminal
  key = key or M._get_focused_terminal() or M._last_terminal_key

  if not key or not M.terminals[key] or not vim.api.nvim_win_is_valid(M.terminals[key].win) then
    vim.notify("Terminal not found or window is invalid", vim.log.levels.ERROR)
    return
  end

  local win = M.terminals[key].win
  local config = vim.api.nvim_win_get_config(win)
  local is_floating = config.relative ~= ""

  -- Store original dimensions for restore
  if not M.terminals[key].original_size then
    if is_floating then
      local row_val = type(config.row) == "table" and config.row[false] or config.row
      local col_val = type(config.col) == "table" and config.col[false] or config.col

      M.terminals[key].original_size = {
        width = config.width,
        height = config.height,
        row = row_val,
        col = col_val,
      }
    else
      if M.terminals[key].config.vertical then
        M.terminals[key].original_size = { width = vim.api.nvim_win_get_width(win) }
      else
        M.terminals[key].original_size = { height = vim.api.nvim_win_get_height(win) }
      end
    end
  end

  if M.terminals[key].maximized then
    -- Restore original size
    if is_floating then
      vim.api.nvim_win_set_config(win, {
        relative = "editor",
        width = M.terminals[key].original_size.width,
        height = M.terminals[key].original_size.height,
        row = M.terminals[key].original_size.row,
        col = M.terminals[key].original_size.col,
      })
    else
      if M.terminals[key].config.vertical then
        vim.api.nvim_win_set_width(win, M.terminals[key].original_size.width)
      else
        vim.api.nvim_win_set_height(win, M.terminals[key].original_size.height)
      end
    end
    M.terminals[key].maximized = false
  else
    -- Maximize window
    if is_floating then
      -- Get dimensions accounting for UI elements
      local max_config = {
        relative = "editor",
        width = vim.o.columns - 4,
        height = vim.o.lines - vim.o.cmdheight - 4,
        row = 2,
        col = 2,
      }
      vim.api.nvim_win_set_config(win, max_config)
    else
      if M.terminals[key].config.vertical then
        -- Maximum reasonable width (leaving some space)
        local max_width = math.floor(vim.o.columns * 0.9)
        vim.api.nvim_win_set_width(win, max_width)
      else
        -- Maximum reasonable height (leaving some space for cmdline)
        local max_height = vim.o.lines - vim.o.cmdheight - 3
        vim.api.nvim_win_set_height(win, max_height)
      end
    end
    M.terminals[key].maximized = true
  end
end

---Close a terminal and clean up its resources
---@param key string|nil Terminal identifier, uses focused terminal if nil
function M.close(key)
  -- If no key provided, try to get the focused terminal
  key = key or M._get_focused_terminal() or M._last_terminal_key

  if not key or not M.terminals[key] then
    vim.notify("Terminal not found", vim.log.levels.ERROR)
    return
  end

  if vim.api.nvim_win_is_valid(M.terminals[key].win) then
    vim.api.nvim_win_close(M.terminals[key].win, true)
  end

  if M.terminals[key].job_id and M.terminals[key].job_id > 0 then
    vim.fn.jobstop(M.terminals[key].job_id)
  end

  if not M.terminals[key].config.persist and vim.api.nvim_buf_is_valid(M.terminals[key].buf) then
    vim.api.nvim_buf_delete(M.terminals[key].buf, { force = true })
  end

  M.terminals[key] = nil

  -- If this was the last used terminal, clear that reference
  if M._last_terminal_key == key then
    M._last_terminal_key = nil
  end
end

---Create a new floating window for an existing terminal buffer
---@param key string Terminal key
---@return boolean success Whether window was created
function M.create_float_window(key)
  local term_data = M.terminals[key]
  if not term_data or not vim.api.nvim_buf_is_valid(term_data.buf) then
    return false
  end

  -- Calculate window dimensions
  local dimensions = calculate_window_dimensions()
  local width = term_data.config.width or dimensions.width
  local height = term_data.config.height or dimensions.height

  -- Create the window
  local win = vim.api.nvim_open_win(term_data.buf, true, {
    style = "minimal",
    relative = "editor",
    width = width,
    height = height,
    row = dimensions.row,
    col = dimensions.col,
    border = term_data.config.border or default_config.float.border,
    title = term_data.config.title,
    title_pos = term_data.config.title and (term_data.config.title_pos or "left") or nil,
  })

  -- Configure window
  vim.wo[win].scrolloff = 0
  vim.wo[win].sidescrolloff = 0

  -- Update terminal data
  term_data.win = win

  -- Enter terminal mode if requested
  if term_data.config.enter ~= false then
    vim.cmd.startinsert()
  end

  return true
end

---Create a new split window for an existing terminal buffer
---@param key string Terminal key
---@return boolean success Whether window was created
function M.create_split_window(key)
  local term_data = M.terminals[key]
  if not term_data or not vim.api.nvim_buf_is_valid(term_data.buf) then
    return false
  end

  -- Determine split configuration
  local split_config = {
    split = term_data.config.split or (term_data.config.vertical and "right" or "below"),
  }

  -- If split direction is specified, convert it to the format nvim_open_win expects
  if term_data.config.split_direction then
    if term_data.config.split_direction == "left" then
      split_config.split = "left"
    elseif term_data.config.split_direction == "right" then
      split_config.split = "right"
    elseif term_data.config.split_direction == "above" then
      split_config.split = "top"
    elseif term_data.config.split_direction == "below" then
      split_config.split = "bot"
    end
  end

  -- Create the window
  local win = vim.api.nvim_open_win(term_data.buf, true, split_config)

  -- Set window size if specified
  if term_data.config.height and not term_data.config.vertical then
    vim.api.nvim_win_set_height(win, term_data.config.height)
  elseif term_data.config.width and term_data.config.vertical then
    vim.api.nvim_win_set_width(win, term_data.config.width)
  end

  -- Update terminal data
  term_data.win = win

  -- Enter terminal mode if requested
  if term_data.config.enter ~= false then
    vim.cmd.startinsert()
  end

  return true
end

---Setup function for plugin configuration
---@param opts table? Plugin configuration table
function M.setup(opts)
  opts = opts or {}
  default_config = vim.tbl_deep_extend("force", default_config, opts)

  -- Set up terminal definitions if provided
  if opts.terminals then
    for key, term_opts in pairs(opts.terminals) do
      term_opts.key = key
      M.run(term_opts)
    end
  end
end

return M
