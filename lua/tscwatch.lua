local loop = vim.loop
local api = vim.api

local buf = nil
local win = nil
local handle = nil
local lines = {}

local function set_mappings(buf)
  local mappings = {
    q = 'toggle()',
    ['<cr>'] = 'goto()',
  }

  local opts = {
    nowait = true,
    noremap = true,
    silent = true
  }
  for k,v in pairs(mappings) do
    vim.api.nvim_buf_set_keymap(buf, 'n', k, ':lua require"tscwatch".'..v..'<cr>', opts)
  end
end

local function toggle()
  if win ~= nil and api.nvim_win_is_valid(win) then
    api.nvim_win_close(win, true)
    win = nil
    buf = nil
    return
  end

  buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')
  api.nvim_buf_set_option(buf, 'buftype', 'nofile')
  api.nvim_buf_set_option(buf, 'swapfile', false)
  api.nvim_buf_set_option(buf, 'filetype', 'tscwatch.nvim')
  set_mappings(buf)

  local width = api.nvim_get_option("columns")
  local height = api.nvim_get_option("lines")

  local win_height = math.ceil(height * 0.8 - 4)
  local win_width = math.ceil(width * 0.8)

  local row = math.ceil((height - win_height) / 2 - 1)
  local col = math.ceil((width - win_width) / 2)

  local opts = {
    style = "minimal",
    relative = "editor",
    width = win_width,
    height = win_height,
    row = row,
    col = col
  }

  win = api.nvim_open_win(buf, true, opts)
  api.nvim_win_set_option(win, 'cursorline', true)
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  if handle ~= nil then
    return
  end

  local stdout = loop.new_pipe(false)

  handle = loop.spawn("npx", {
    args = {"tsc", "--watch"},
    stdio = {nil, stdout}
  }, function(code, signal)
    stdout:read_stop()
    stdout:close()
    handle:close()
  end)

  loop.read_start(stdout, vim.schedule_wrap(function(err, data)
    assert(not err, err)
    if data then
      if string.find(data, "Starting") then
        for k in pairs(lines) do
          lines[k] = nil
        end
      end

      for line in vim.gsplit(data, "\n", true) do
        lines[#lines + 1] = line
      end

      if buf ~= nil and api.nvim_buf_is_valid(buf) and api.nvim_buf_is_loaded(buf) then
        api.nvim_set_current_win(win)
        api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      end
    end
  end))
end

local function goto()
  if buf == nil or not api.nvim_buf_is_valid(buf) or not api.nvim_buf_is_loaded(buf) then
    return
  end

  if win == nil or not api.nvim_win_is_valid(win) then
    return
  end

  local row, col = unpack(api.nvim_win_get_cursor(win))
  local height = api.nvim_win_get_height(win) 

  local line = api.nvim_buf_get_lines(buf, row - 1, -1, false)[1]

  local parts = vim.split(line, "):", true)
  if #parts < 2 then
    return
  end
  local fname_and_pos = parts[1]

  local parts = vim.split(fname_and_pos, "(", true)
  if #parts < 2 then
    return
  end
  local fname = parts[1]
  local pos = parts[2]

  local parts = vim.split(pos, ",")
  if #parts < 2 then
    return
  end
  local row = tonumber(parts[1])
  local col = tonumber(parts[2]) - 1

  local cwd = vim.fn.getcwd()
  local uri = "file:/"..cwd.."/"..fname
  local bufnr = vim.uri_to_bufnr(uri)

  for _, win in ipairs(api.nvim_list_wins()) do
    if api.nvim_win_get_buf(win) == bufnr then
      toggle()
      api.nvim_set_current_win(win)
      api.nvim_win_set_cursor(win, {row, col})
      return
    end
  end

  api.nvim_command("tabedit "..fname)
  api.nvim_win_set_cursor(api.nvim_get_current_win(), {row, col})
end

return {
  toggle = toggle,
  goto = goto
}
