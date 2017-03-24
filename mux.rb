require 'socket'
require 'time'
require 'filesize'

data_port = 8223
console_port = 8222

BUFFER_SIZE = 24 * 10

data_server = TCPServer.open('0.0.0.0', data_port)
console_server = TCPServer.open('0.0.0.0', console_port)

fds = [
    {name: :data, type: :server, io: data_server},
    {name: :console, type: :server, io: console_server}
]

def get_fds(fds)
  fds.map { |item| item[:io] }
end
def get_item_from_io(fds, io)
  fds.find { |item| item[:io] == io }
end

def destroy_socket(fds, io)
  io.close
  ret = fds.find { |a| a[:io] == io }
  fds.delete_if { |a| a[:io] ==io }
  ret
end

def generate_id
  if @id.nil?
    @id = 0
  end
  @id += 1
end

def enable_endpoint(fds, type, id)
  item = get_by_id(fds, id)
  item[:status][type] = true if item
  item
end

def disable_endpoint(fds, type, id)
  item = get_by_id(fds, id)
  item[:status][type] = false if item
  item
end

def get_by_id(fds, id)
  fds.find { |item| item[:id] == id }
end

def create_client(name, io)
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

CommandError = Class.new(Exception)

def all_info(fds)
  r = fds.select do |item|
    [:data_client, :console_client].include?(item[:name])
  end.map do |item, i|
    if item[:name] == :data_client
      if item[:status][:in] && item[:status][:out]
        a = '      +<----->'
      elsif item[:status][:in]
        a = '      +------>'
      elsif item[:status][:out]
        a = '      +<------'
      else
        a = '      +-------'
      end
    else # item[:name] == :console_client
      a = '      +CONSOLE'
    end
    "%-12s %02d %-12s %-16s %-19s %-10s %-10s" % [
        a,
        item[:id],
        item[:device_name],
        item[:address]&.join(':'),
        item[:connected_at].strftime('%Y-%m-%d %H:%M:%S'),
        Filesize.new(item[:read_bytes]).pretty,
        Filesize.new(item[:write_bytes]).pretty,
    ]
  end.join("\n")

  ("mux --+        id %-12s %-16s %-19s %-10s %-10s\n" % %w'name ip:port connected_at in_bytes out_bytes') + r
end

def console_exec(fds, command_line)
  begin
    command, *args = command_line.strip.split(/\s+/)
    case command
      when 'inputs'
        fds.select { |fd| fd[:status][:in] }.map { |item| "#{item[:id]} #{item[:address].join(':')}" }.join("\n")
      when 'outputs'
        fds.select { |fd| fd[:status][:out] }.map { |item| "#{item[:id]} #{item[:address].join(':')}" }.join("\n")
      when 'ls'
        all_info(fds)
      when 'en'
        raise CommandError.new('USAGE: en [in|out] ID') unless args.size == 2
        id, type = args[0].to_sym, args[1].to_i
        enable_endpoint(fds, id, type)
      when 'dis'
        raise CommandError.new('USAGE: dis [in|out] ID') unless args.size == 2
        id, type = args[0].to_sym, args[1].to_i
        disable_endpoint(fds, id, type)
      when 'get'
        raise CommandError.new('USAGE: get ID') unless args.size == 1
        id = args[0].to_i
        get_by_id(fds, id)
      when 'name'
        raise CommandError.new('USAGE: name ID NAME') unless args.size == 2
        if args[0] == 'last'
          fds[-1][:device_name] = args[1] if fds.size > 1
        else
          id, device_name = args[0].to_i, args[1]
          item = get_by_id(fds, id)
          if item
            item[:device_name] = device_name
          end
        end
      when 'rm'
        raise CommandError.new('USAGE: rm ID') unless args.size == 1
        id = args[0].to_i
        item = get_by_id(fds, id)
        destroy_socket(fds, item[:io])
      when 'help'
        a = <<~EOF
          ls
          en [in|out] ID
          dis [in|out] ID
          get ID
          name ID NAME
          rm ID
        EOF
        a.strip
      else
        'Pardon?'
    end
  rescue CommandError => e
    e.to_s
  end
end

begin
  loop do
    if (ios = IO.select(get_fds(fds), [], []))
      reads, _, _ = ios
      reads.each do |read_io|
        item = get_item_from_io(fds, read_io)
        if item[:type] == :server
          io = item[:io].accept
          fds << create_client(item[:name], io)
        elsif item[:type] == :client
          if item[:io].eof?
            STDERR.puts 'close: %s:%d' % [item[:name], item[:id]]
            destroy_socket(fds, item[:io])
          elsif item[:name] == :console_client
            begin
              command_line = item[:io].gets.strip
              STDERR.puts 'cmd: %s' % command_line
              result = console_exec(fds, command_line)
              item[:io].puts result
            rescue IOError, Errno::EPIPE
              destroy_socket(fds, item[:io])
            end
          else
            begin
              data = item[:io].read_nonblock(BUFFER_SIZE)
              STDERR.puts 'read: (%s:%d), %d bytes' % [
                  item[:io].remote_address.ip_address,
                  item[:io].remote_address.ip_port,
                  data.size
              ]
              item[:read_bytes] += data.size
              if item[:status][:in]
                fds.each do |tgt|
                  if tgt && tgt[:name] == :data_client && tgt[:status][:out]
                    tgt[:write_bytes] += data.size
                    tgt[:io].write data
                  end
                end
              end
            rescue IO::WaitReadable
              next
            rescue IOError, EOFError, Errno::EPIPE
              destroy_socket(fds, item[:io])
            end
          end
        end
      end
    end
  end
ensure
  fds.each do |f|
    puts 'close: %s' % f[:name]
    f[:io].close
  end
end
