#!/usr/bin/env ruby
#
input_port = 8224
if ARGV.size > 0
  input_port = ARGV[0].to_i
end

input_dir = '/dev/input'
devs = {}
Dir.entries(input_dir).each do |f|
  full_path = File.join(input_dir, f)
  if !(f =~ /^\./) && !File.directory?(full_path)
    st = File.stat(full_path)
    dev_id = "#{st.rdev_major}:#{st.rdev_minor}"
    sys_dev = "/sys/dev/char/#{dev_id}"
    if File.exist?(sys_dev)
      device_dir = File.join(sys_dev, 'device')
      if File.exist?(device_dir)
        name = File.read(File.join(device_dir, 'name')).strip
        STDERR.puts "#{f}\t\t#{name}"
        devs[f] = {name: name}
      end
    else
      STDERR.puts "#{full_path}"
    end
  end
end

STDERR.print "Please select a device name(e.g. event0): "
ev = STDIN.gets.strip
if devs.include?(ev)
  dev_name = devs[ev][:name]
  xinput = `xinput --list | grep '#{dev_name}'`
  ids = xinput.scan(/id=(\d)+/)

  STDERR.puts
  STDERR.puts "Disabling #{dev_name}"
  ids.each do |id, _|
    `xinput float #{id} &> /dev/null` 
  end
  STDOUT.print "/dev/input/#{ev}"
else
  STDERR.puts 'Wrong file name'
end
