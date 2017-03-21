#!/usr/bin/env ruby
input_dir = '/dev/input'
devs = []
Dir.entries(input_dir).each do |f|
  full_path = File.join(input_dir, f)
  if !(f =~ /^\./) && !File.directory?(full_path)
    st = File.stat(full_path)
    dev_id = "#{st.rdev_major}:#{st.rdev_minor}"
    sys_dev = "/sys/dev/char/#{dev_id}"
    if File.exist?(sys_dev)
      device_dir = File.join(sys_dev, 'device')
      if File.exist?(device_dir)
        name = File.read(File.join(device_dir, 'name'))
        STDERR.puts "#{f}\t\t#{name}"
        devs << f
      end
    else
      STDERR.puts "#{full_path}"
    end
  end
end

STDERR.print "Please select a device name(e.g. event0):"
name = STDIN.gets.strip
if devs.include?(name)
  STDOUT.puts "/dev/input/#{name}"
else
  STDERR.puts 'Wrong file name'
end
