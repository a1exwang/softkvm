#!/usr/bin/env ruby
require 'json'
require 'socket'
require_relative './input_event_parser'

server_port = 8224
if ARGV.size > 0
  server_port = ARGV[0].to_i
end


client_sockets = []
Thread.new do
  tcp_server = TCPServer.new('0.0.0.0', server_port)
  loop do
    client_sockets << tcp_server.accept
  end
end

loop do
  current_server = 0
  while client_sockets.size == 0
    sleep 1
  end

  begin
    while STDIN.read_nonblock(24); end
  rescue IO::EAGAINWaitReadable
  end

  loop do
    raw = STDIN.read(24)
    if raw.nil?
      client_sockets.delete_at(current_server)
      current_server -= 1
      current_server = 0 if current_server < 0
      break if client_sockets.count == 0
    end
    op, out = parse_kb_code(raw)
    if op == :through
      begin
        client_sockets[current_server].write out
      rescue Errno::EPIPE
        client_sockets.delete_at(current_server)
        current_server -= 1
        current_server = 0 if current_server < 0
        break if client_sockets.count == 0
      end
    elsif op == :swallow
      if out == :previous
        # previous
        current_server -= 1
        current_server %= client_sockets.count
      elsif out == :next
        current_server += 1
        current_server %= client_sockets.count
        # next
      end
    end
  end
end
