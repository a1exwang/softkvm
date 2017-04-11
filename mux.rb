require 'socket'
require 'time'
require 'filesize'
require 'set'


DATA_PORT = 8223
CONSOLE_PORT = 8222
BUFFER_SIZE = 24 * 10


def generate_id
  if @id.nil?
    @id = 0
  end
  @id += 1
end


module Endpoint
  def self.enable_endpoint(meta, type, id)
    item = FDs.get_by_id(meta, id)
    item[:status][type] = true if item
    item
  end
  def self.disable_endpoint(meta, type, id)
    item = FDs.get_by_id(meta, id)
    item[:status][type] = false if item
    item
  end
end


module FDs
  def self.get_fds(meta)
    meta[:fds].map { |item| item[:io] }
  end
  def self.get_item_from_io(meta, io)
    meta[:fds].find { |item| item[:io] == io }
  end

  def self.get_by_id(meta, id)
    meta[:fds].find { |item| item[:id] == id }
  end
end


module SocketClient
  def self.create_client(name, io)
    puts 'accept (%s): %s:%d => %s:%d' % [
        name,
        io.remote_address.ip_address,
        io.remote_address.ip_port,
        io.local_address.ip_address,
        io.local_address.ip_port,
    ]

    {
        name: "#{name}_client".to_sym,
        type: :client,
        id: generate_id,
        io: io,
        address: [io.remote_address.ip_address, io.remote_address.ip_port],
        status: {},
        device_name: 'unknown',
        device_type: :unknown,
        connected_at: Time.now,
        read_bytes: 0,
        write_bytes: 0,
    }
  end
  def self.destroy_socket(meta, io)
    io.close
    fd = meta[:fds].find { |a| a[:io] == io }
    STDERR.puts 'close: %s:%d' % [fd[:name], fd[:id]]
    meta[:fds].delete_if { |a| a[:io] ==io }
    fd
  end
end


module Console
  def self.channel_info(meta, client_ids, channel_name)
    r = client_ids.map do |client_id|
      FDs.get_by_id(meta, client_id)
    end.map do |item|
      if item[:name] == :data_client
        if item[:status][:in] && item[:status][:out]
          a = '         +<----->'
        elsif item[:status][:in]
          a = '         +<------'
        elsif item[:status][:out]
          a = '         +------>'
        else
          a = '         +-------'
        end
      else # item[:name] == :console_client
        a = '         +CONSOLE'
      end
      '%-15s %02d %-12s %-16s %-21s %10s %10s' % [
          a,
          item[:id],
          item[:device_name],
          item[:address]&.join(':'),
          item[:connected_at].strftime('%Y-%m-%d %H:%M:%S'),
          Filesize.new(item[:read_bytes]).pretty,
          Filesize.new(item[:write_bytes]).pretty,
      ]
    end.join("\n")

    ("%-6s---+        %-2s %-12s %-16s %-21s %10s %10s\n" %
        ([channel_name] + %w'id name ip:port connected_at in_bytes out_bytes')) + r
  end
  def self.all_info(meta)
    client_ids = meta[:fds]
                     .select { |item| [:data_client, :console_client].include?(item[:name]) }
                     .map { |item| item[:id] }
    ret = channel_info(meta, client_ids, 'NULL')
    ret += "\n\n"

    meta[:channels].keys.each do |channel_name|
      ret += channel_info(meta, meta[:channels][channel_name][:client_ids], channel_name)
      ret += "\n\n"
    end
    ret
  end
  def self.parse_args(args, types, help = '', strict_arg = true)
    if strict_arg && args.size != types.size
      raise CommandError.new("USAGE: #{help}")
    end
    ret = []
    args.each_with_index do |arg, i|
      if types[i] == Symbol
        ret << arg.to_sym
      elsif types[i] == Integer
        ret << arg.to_i
      elsif types[i] == Float
        ret << arg.to_f
      else
        ret << arg
      end
    end
    ret.size > 1 ? ret : ret[0]
  end

  def self.console_exec(meta, command_line)
    STDERR.puts 'cmd: %s' % command_line
    begin
      command, *args = command_line.strip.split(/\s+/)
      case command
        when 'inputs'
          meta[:fds].select { |fd| fd[:status][:in] }.map { |item| "#{item[:id]} #{item[:address].join(':')}" }.join("\n")
        when 'outputs'
          meta[:fds].select { |fd| fd[:status][:out] }.map { |item| "#{item[:id]} #{item[:address].join(':')}" }.join("\n")
        when 'ls'
          all_info(meta)
        when 'en'
          id, type = parse_args(args, [Symbol, Integer], 'en [in|out] ID')
          Endpoint.enable_endpoint(meta, id, type)
        when 'dis'
          id, type = parse_args(args, [Symbol, Integer], 'dis [in|out] ID')
          Endpoint.disable_endpoint(meta, id, type)
        when 'get'
          id = parse_args(args, [Integer], 'USAGE: get ID')
          FDs.get_by_id(meta, id)
        when 'name'
          raise CommandError.new('USAGE: name [ID|last] NAME') unless args.size == 2
          if args[0] == 'last'
            meta[:fds][-1][:device_name] = args[1] if meta[:fds].size > 1
          else
            id, device_name = args[0].to_i, args[1]
            item = FDs.get_by_id(meta, id)
            if item
              item[:device_name] = device_name
            end
          end
        when 'rm'
          id = parse_args(args, [Integer], 'USAGE: rm ID')
          item = FDs.get_by_id(meta, id)
          SocketClient.destroy_socket(meta, item[:io])
        when 'mkdir'
          channel_name = parse_args(args, [String], 'USAGE: mkdir CHANNEL_NAME')
          meta[:channels][channel_name] = {name: channel_name, client_ids: Set.new}
          meta[:channels].keys.join(' ')
        when 'cp'
          id, channel_name = parse_args(args, [Integer, Symbol],
                                        'USAGE: cp ID CHANNEL_NAME')
          if (channel = meta[:channels][channel_name])
            channel[:client_ids] << id
            id
          else
            raise CommandError.new('Wrong CHANNEL_NAME')
          end
        when 'help'
          <<~EOF
            ls
            en [in|out] ID
            dis [in|out] ID
            get ID
            name ID NAME
            rm ID
            mkdir CHANNEL_NAME
            cp ID CHANNEL_NAME
          EOF
        else
          'Pardon?'
      end
    rescue CommandError => e
      e.to_s
    end
  end
end

CommandError = Class.new(Exception)

def main
  data_server = TCPServer.open('0.0.0.0', DATA_PORT)
  console_server = TCPServer.open('0.0.0.0', CONSOLE_PORT)
  meta = {
      fds: [
          {name: :data, type: :server, io: data_server},
          {name: :console, type: :server, io: console_server}
      ],
      channels: {
          kbs: {name: 'kbs', client_ids: Set.new},
          mice: {name: 'mice', client_ids: Set.new},
      }
  }

  begin
    loop do
      if (ios = IO.select(FDs.get_fds(meta), [], []))
        reads, _, _ = ios
        reads.each do |read_io|
          item = FDs.get_item_from_io(meta, read_io)
          if item[:type] == :server
            # New data/console connection
            io = item[:io].accept
            meta[:fds] << SocketClient.create_client(item[:name], io)
          elsif item[:type] == :client
            # Data arrived
            if item[:io].eof?
              # A client closed the connection
              SocketClient.destroy_socket(meta, item[:io])
            elsif item[:name] == :console_client
              # Read from a console client
              begin
                item[:io].puts Console.console_exec(meta, item[:io].gets.strip)
              rescue IOError, Errno::EPIPE
                SocketClient.destroy_socket(meta, item[:io])
              end
            else
              # Read from a data client
              begin
                data = item[:io].read_nonblock(BUFFER_SIZE)
              rescue IO::WaitReadable
                next
              rescue IOError, EOFError, Errno::EPIPE
                SocketClient.destroy_socket(meta, item[:io])
              end
              STDERR.puts 'read: (%s:%d), %d bytes' % [
                  item[:io].remote_address.ip_address,
                  item[:io].remote_address.ip_port,
                  data.size
              ]
              item[:read_bytes] += data.size
              if item[:status][:in]
                meta[:fds].each do |tgt|
                  if tgt && tgt[:name] == :data_client && tgt[:status][:out]
                    tgt[:write_bytes] += data.size
                    begin
                      tgt[:io].write data
                    rescue IOError, EOFError, Errno::EPIPE
                      SocketClient.destroy_socket(meta, tgt[:io])
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  ensure
    meta[:fds].each do |f|
      puts 'close: %s' % f[:name]
      f[:io].close
    end
  end
end

main
