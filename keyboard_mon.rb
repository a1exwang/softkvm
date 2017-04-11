#!/usr/bin/env ruby

require 'uri'
require_relative 'input_event_parser'
require_relative 'current_window_title'

def start_mon(io, out_io)
  loop do
    raw = io.read(24)
    break if raw.nil?
    _, data, info = parse_kb_code(raw)
    raw = URI.encode(data)
    window_id, pid, cmdline = current_window_info
    out_io.puts("#{info} #{raw} #{window_id} #{pid} \"#{cmdline}\"")
  end
end


start_mon(STDIN, STDOUT)

