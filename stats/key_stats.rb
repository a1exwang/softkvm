#!/usr/bin/env ruby

require_relative '../input_event_parser'

@isolated_keys = Hash.new { Array.new }
@combined_keys = Hash.new { Array.new }
@key_status = Hash.new { :up }


def get_key_name(code, key_status = {})
  name, realname, shift_name = KEY_CODES[code]

  desc = ''
  if key_status[:ctrl] == :down
    desc += 'C-'
  end
  if key_status[:shift] == :down
    if shift_name
      realname = shift_name
    else
      desc += 'Shift-'
    end
  end
  if key_status[:alt] == :down
    desc += 'Alt-'
  end

  desc + (realname || code.to_s)
end

def stats_keys(io)
  loop do
    s, ms, type, code, val = io.gets&.split(' ')
    break if s.nil?
    t = DateTime.strptime('%d.%06s' % [s, ms], '%s')
    type = type.to_sym
    code = code.to_i
    val = val.to_i(16)
    if type == :key
      if val == KEYVAL_DOWN
        if [get_keycode(:lctrl), get_keycode(:rctrl)].include?(code)
          @key_status[:ctrl] = :down
        elsif [get_keycode(:lshift), get_keycode(:rshift)].include?(code)
          @key_status[:shift] = :down
        elsif [get_keycode(:lalt), get_keycode(:ralt)].include?(code)
          @key_status[:alt] = :down
        else
          @combined_keys[get_key_name(code, @key_status)] += [t]
        end
        @isolated_keys[code] += [t]
      elsif val == KEYVAL_UP
        if [get_keycode(:lctrl), get_keycode(:rctrl)].include?(code)
          @key_status[:ctrl] = :up
        elsif [get_keycode(:lshift), get_keycode(:rshift)].include?(code)
          @key_status[:shift] = :up
        elsif [get_keycode(:lalt), get_keycode(:ralt)].include?(code)
          @key_status[:alt] = :up
        end
      end
    end
  end
end

stats_keys(STDIN)

puts(@isolated_keys.sort_by { |_, v| v.size }.map { |k, v| "%-20s\t%d" % [get_key_name(k), v.size] }.join("\n"))
puts
puts(@combined_keys.sort_by { |_, v| v.size }.map { |k, v| "%-20s\t%d" % [k, v.size] }.join("\n"))
