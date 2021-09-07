local loop = vim.loop
local api = vim.api

local buf, win

local function tscwatch()
  buf = api.nvim_create_buf(false, true) -- create new emtpy buffer

  api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')

  -- get dimensions
  local width = api.nvim_get_option("columns")
  local height = api.nvim_get_option("lines")

  -- calculate our floating window size
  local win_height = math.ceil(height * 0.8 - 4)
  local win_width = math.ceil(width * 0.8)

  -- and its starting position
  local row = math.ceil((height - win_height) / 2 - 1)
  local col = math.ceil((width - win_width) / 2)

  -- set some options
  local opts = {
    style = "minimal",
    relative = "editor",
    width = win_width,
    height = win_height,
    row = row,
    col = col
  }

  -- and finally create it with buffer attached
  win = api.nvim_open_win(buf, true, opts)

  local stdout = loop.new_pipe(false)
  local stderr = loop.new_pipe(false)

  print("stdout", stdout)
  print("stderr", stderr)

  handle, pid = loop.spawn("npx", {
    args = {"tsc"},
    stdio = {nil, stdout, stderr}
  }, function(code, signal) -- on exit
    print("exit code", code)
    print("exit signal", signal)

    stdout:read_stop()
    stderr:read_stop()

    stdout:close()
    stderr:close()

    handle:close()
  end)

  print("process opened", handle, pid)

  loop.read_start(stdout, vim.schedule_wrap(function(err, data)
    assert(not err, err)
    if data then
      print("stdout chunk", stdout, data)
      local lines = {}
      for line in vim.gsplit(data, "\n", false) do
        lines[#lines + 1] = line
      end

      api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    else
      print("stdout end", stdout)
    end
  end))

  loop.read_start(stderr, function(err, data)
    assert(not err, err)
    if data then
      print("stderr chunk", stderr, data)
    else
      print("stderr end", stderr)
    end
  end)
end

return {
  tscwatch = tscwatch
}
