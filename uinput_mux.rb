#!/usr/bin/env ruby
require 'json'
require 'socket'
require_relative './input_event_parser'

server_port = 8223
if ARGV.size > 0
  server_port = ARGV[0].to_i
end


@client_sockets = []
@current_server = 0

Thread.new do
  tcp_server = TCPServer.new('0.0.0.0', server_port)
  loop do
    @client_sockets << tcp_server.accept
  end
end

def get_current_server
  @current_server = 0 if @current_server < 0
  if @client_sockets.size == 0
    return nil
  end
  @client_sockets[@current_server]
end

def write_current_server(data)
  begin
    get_current_server&.write data
  rescue Errno::EPIPE
    pop_current_server
  end
end

def pop_current_server
  @client_sockets.delete_at(@current_server)
  @current_server -= 1
  @current_server = 0 if @current_server < 0
end

def switch_server(diff)
  @current_server += diff
  @current_server = 
    (@client_sockets.size == 0) ? 0 : (@current_server % @client_sockets.size)
end

loop do
  # Swallow useless bytes
  # begin
  #   while STDIN.read_nonblock(1); end
  # rescue IO::EAGAINWaitReadable
  # end

  loop do
    if (raw = STDIN.read(24)).nil?
      pop_current_server 
      next
    end
    op, data, info = parse_kb_code(raw)
    puts "%-8s %s" % [op, info]
    if op == :through
      write_current_server(data)
    elsif op == :swallow
      if data == :previous
        switch_server(-1)
      elsif data == :next
        switch_server(1)
      end
    end
  end
end
