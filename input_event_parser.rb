#!/usr/bin/env ruby
require 'time'

EV_SYN = 0x00
EV_KEY = 0x01
EV_REL = 0x02
EV_ABS = 0x03
EV_MSC = 0x04
TYPES = [:syn, :key, :rel, :abs, :msc]

KEYVAL_DOWN = 1
KEYVAL_UP = 0

KEY_Q = 16
KEY_W = 17
KEY_LCTRL = 29
KEY_C = 46
KEY_LALT = 56

def get_keycode(name)
  KEY_CODES.find_index do |item|
    item && item.first == name
  end
end

KEY_CODES = [
    nil,
    [:esc,  'Esc',  nil],
    [:n1,   '1',    '!'],
    [:n2,   '2',    '@'],
    [:n3,   '3',    '#'],
    [:n4,   '4',    '$'],
    [:n5,   '5',    '%'],
    [:n6,   '6',    '^'],
    [:n7,   '7',    '&'],
    [:n8,   '8',    '*'],
    [:n9,   '9',    '('],

    # 11
    [:n0,   '0',    ')'],
    [:minus,'-',    '_'],
    [:eq,   '=',    '+'],
    [:bs,   'Backspace', nil],
    [:tab,  'Tab',  nil],
    [:q,    'q',    'Q'],
    [:w,    'w',    'W'],
    [:e,    'e',    'E'],
    [:r,    'r',    'R'],
    [:t,    't',    'T'],

    # 21
    [:y,    'y',    'Y'],
    [:u,    'u',    'U'],
    [:i,    'i',    'I'],
    [:o,    'o',    'O'],
    [:p,    'p',    'P'],
    [:lbrac,'[',    '{'],
    [:rbrac,']',    '}'],
    [:enter,'Enter',nil],
    [:lctrl,'Ctrl', nil],
    [:a,    'a',    'A'],

    # 31
    [:s,    's',    'S'],
    [:d,    'd',    'D'],
    [:f,    'f',    'F'],
    [:g,    'g',    'G'],
    [:h,    'h',    'H'],
    [:j,    'j',    'J'],
    [:k,    'k',    'K'],
    [:l,    'l',    'L'],
    [:semicolon,';',':'],
    [:squote,"'",   '"'],

    # 41
    [:backtick,'`','~'],
    [:lshift,'Shift',nil],
    [:backslash,'\\', '|'],
    [:z,    'z',    'Z'],
    [:x,    'x',    'X'],
    [:c,    'c',    'C'],
    [:v,    'v',    'V'],
    [:b,    'b',    'B'],
    [:n,    'n',    'N'],
    [:m,    'm',    'M'],

    # 51
    [:comma,',',    '<'],
    [:dot,  '.',    '>'],
    [:slash,'/',    '?'],
    [:rshift,'Shift',nil],
    [:star, 'Star', nil],
    [:lalt, 'Alt',  nil],
    [:space, 'Space',nil],
    [:caps,  'Caps Lock', nil],
    [:f1,   'F1',   nil],
    [:f2,   'F2',   nil],

    # 61
    [:f3,   'F3',   nil],
    [:f4,   'F4',   nil],
    [:f5,   'F5',   nil],
    [:f6,   'F6',   nil],
    [:f7,   'F7',   nil],
    [:f8,   'F8',   nil],
    [:f9,   'F9',   nil],
    [:f10,  'F10',  nil],
    [:numlock, 'Nums Lock', nil],
    [:scrolllock, 'Scroll Lock', nil],

    # 71
    [:home7, 'Home', nil],
    [:up8,   'Up'],
    [:pgup9, 'Page Up'],
    [:rminus, '-'],
    [:left4,  'Left'],
    [:right4, 'Right'],
    [:rplus,  '+'],
    [:end1,   'End'],
    [:down2,  'Down'],

    # 81
    [:pgdn3,  'Page Down'],
    [:ins,    'Insert'],
    [:del,    'Del'],
    nil,
    nil,
    nil,
    [:f11,    'F11'],
    [:f12,    'F12'],
    nil,
    nil,

    # 91
    nil,
    nil,
    nil,
    nil,
    nil,
    [:renter, 'Enter'],
    [:rctrl,  'Ctrl'],
    [:rbackslash, '/'],
    [:prtscr,   'Ptr Scr'],
    [:ralt,   'Alt'],

    # 101
    nil,
    [:home, 'Home'],
    [:up,   'Up'],
    [:pgup, 'Page Up'],
    [:left, 'Left'],
    [:right, 'Right'],
    [:end,  'End'],
    [:down, 'Down'],
    [:pgdn, 'Page Down'],
    [:insert, 'Insert'],

    # 111
    [:delete, 'Delete'],
]



def parse_kb_code_raw(raw)
  s, us, type, code, val = raw.unpack('QQSSl')
  yield(s, us, TYPES[type], code, val)
end

def parse_kb_code(raw)
  parse_kb_code_raw(raw) do |s, ms, type, code, val|
    info = '%d %d %s %03d %08x' % [s, ms, type.to_s, code, val]
    [:through, raw, info]
  end
end

def parse_stream(io)
  loop do
    raw = io.read(24)
    break if raw.nil?
    op, data, info = parse_kb_code(raw)
    if op == :through
      STDERR.puts(info)
      STDOUT.write(data)
    end
  end
end

def main
  parse_stream(STDIN)
end
