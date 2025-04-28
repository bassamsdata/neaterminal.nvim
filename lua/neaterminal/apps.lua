local neaterminal = require("neaterminal")

local M = {}

---Run lazygit in a floating window
---@param opts table? Optional configuration
---@return {buf: integer, win: integer, job_id: integer}|nil Terminal data
function M.lazygit(opts)
  opts = opts or {}
  opts = vim.tbl_deep_extend("force", {
    cmd = "lazygit",
    key = "lazygit",
    border = "rounded",
    title = " LazyGit ",
    title_pos = "center",
  }, opts)

  return neaterminal.run(opts)
end

---Run Yazi file manager in a floating window
---@param opts table? Optional configuration
---@return {buf: integer, win: integer, job_id: integer}|nil Terminal data
function M.yazi(opts)
  opts = opts or {}
  opts = vim.tbl_deep_extend("force", {
    cmd = "yazi",
    key = "yazi",
    border = "rounded",
    title = " Yazi ",
    title_pos = "center",
    env = {
      COLORTERM = "truecolor",
      TERM = "xterm-256color",
      YAZI_LEVEL = "1",
    },
  }, opts)

  return neaterminal.run(opts)
end

---Run btop system monitor in a floating window
---@param opts table? Optional configuration
---@return {buf: integer, win: integer, job_id: integer}|nil Terminal data
function M.btop(opts)
  opts = opts or {}
  opts = vim.tbl_deep_extend("force", {
    cmd = "btop",
    key = "btop",
    border = "rounded",
    title = " BTOP ",
    title_pos = "center",
  }, opts)

  return neaterminal.run(opts)
end

---Run a basic shell in a terminal
---@param opts table? Optional configuration
---@return {buf: integer, win: integer, job_id: integer}|nil Terminal data
function M.shell(opts)
  opts = opts or {}
  opts = vim.tbl_deep_extend("force", {
    cmd = vim.o.shell,
    key = "shell",
    border = "rounded",
    title = " Terminal ",
    title_pos = "center",
  }, opts)

  return neaterminal.run(opts)
end

return M
