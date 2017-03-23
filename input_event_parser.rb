#!/usr/bin/env ruby
EV_SYN = 0x00
EV_KEY = 0x01
EV_REL = 0x02
EV_ABS = 0x03
EV_MSC = 0x04
TYPES = [
  'syn',
  'key',
  'rel',
  'abs',
  'msc',
]

KEYVAL_DOWN = 1
KEYVAL_UP = 0

KEY_Q = 16
KEY_W = 17
KEY_LCTRL = 29
KEY_C = 46
KEY_LALT = 56

@keys = Hash.new(0)

def parse_kb_code(raw)
  s, us, type, code, val = raw.unpack('QQSSl')
  if TYPES[type] == 'key' && [KEYVAL_UP, KEYVAL_DOWN].include?(val)
    if @keys[KEY_LCTRL] == KEYVAL_DOWN && @keys[KEY_LALT] == KEYVAL_DOWN
      if code == KEY_Q && val == KEYVAL_DOWN
        return [:swallow, :previous]
      elsif code == KEY_W && val == KEYVAL_DOWN
        return [:swallow, :next]
      end
    end

    @keys[code] = val
    # STDERR.puts "%d %06d %s %03d %08x" % [s, us, TYPES[type], code, val]
  elsif TYPES[type] == 'rel'
    # STDERR.puts "%d %06d %s %03d %08x" % [s, us, TYPES[type], code, val]
  end
  info = "%d %06d %s %03d %08x" % [s, us, TYPES[type], code, val]
  [:through, raw, info]
end

def main
  loop do
    raw = STDIN.read(24)
    op, data, info = parse_kb_code(raw)
    if op == :through
      STDERR.puts(info)
      STDOUT.write(data)
    end
  end
end
