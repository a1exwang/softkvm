#!/usr/bin/env ruby

def current_window_info
  root_window_id = `xprop -root _NET_ACTIVE_WINDOW 2> /dev/null`.split[-1].to_i(16)
  pid = `xprop -id #{root_window_id} _NET_WM_PID`.split[-1].to_i
  cmd_line = File.read("/proc/#{pid}/cmdline")
  [root_window_id, pid, cmd_line]
end

