# RebornDump.rb - read-only unpacker for Pokemon Reborn map data
#
# Usage (from a terminal, plain Ruby - no gems needed):
#   ruby RebornDump.rb "/path/to/Pokemon Reborn/Game"
#
# Reads  Game/Data/MapInfos.rxdata and every Game/Data/MapXXX.rxdata
# Writes Game/Dump/maps.json             every map: id, name, parent, size, warps, events
#        Game/Dump/warps.txt             one line per transfer: from map (x,y) -> to map (x,y) + page condition
#        Game/Dump/maps/MapXXX.txt       readable event listing for one map (pages, conditions, commands)
# It never writes to Data/ or Scripts/.

require 'json'
require 'fileutils'

# ---------------------------------------------------------------- minimal RGSS classes so Marshal can load the files
class Table
  attr_reader :xsize, :ysize, :zsize
  def self._load(s)
    t = allocate
    t.instance_eval do
      _, @xsize, @ysize, @zsize, _n = s[0, 20].unpack('l5')
      @data = s[20..-1].unpack('s*')
    end
    t
  end
end
class Color; def self._load(s) allocate end; end
class Tone;  def self._load(s) allocate end; end

class GenericObj
  def method_missing(m, *a) instance_variable_get("@#{m}") end
  def respond_to_missing?(*) true end
end

def define_path(path)
  mod = Object
  parts = path.split('::')
  parts.each_with_index do |p, i|
    if mod.const_defined?(p, false)
      mod = mod.const_get(p, false)
    else
      nc = (i == parts.size - 1) ? Class.new(GenericObj) : Module.new
      mod.const_set(p, nc)
      mod = nc
    end
  end
end

def rxload(file)
  data = File.binread(file)
  50.times do
    begin
      return Marshal.load(data)
    rescue ArgumentError => e
      raise unless e.message =~ /undefined class\/module (\S+)/
      define_path($1)
    end
  end
  raise "could not load #{file}"
end

# ---------------------------------------------------------------- helpers
MOVE_NAMES = { 1 => 'down', 2 => 'left', 3 => 'right', 4 => 'up', 5 => 'down-left', 6 => 'down-right',
               7 => 'up-left', 8 => 'up-right', 9 => 'random', 10 => 'toward player', 11 => 'away from player',
               12 => 'forward', 13 => 'backward', 14 => 'jump', 15 => 'wait', 37 => 'through on', 38 => 'through off' }

def page_condition(pg)
  c = pg.condition
  out = {}
  out['switch1'] = c.switch1_id if c.switch1_valid
  out['switch2'] = c.switch2_id if c.switch2_valid
  out['variable'] = [c.variable_id, c.variable_value] if c.variable_valid   # variable >= value
  out['self_switch'] = c.self_switch_ch if c.self_switch_valid
  out
end

def condition_text(cond)
  return 'always' if cond.empty?
  t = []
  t << "switch #{cond['switch1']} ON" if cond['switch1']
  t << "switch #{cond['switch2']} ON" if cond['switch2']
  t << "var #{cond['variable'][0]} >= #{cond['variable'][1]}" if cond['variable']
  t << "self switch #{cond['self_switch']}" if cond['self_switch']
  t.join(' & ')
end

# the commands that matter for routing / puzzles, in readable form
def command_info(q)
  p = q.parameters
  case q.code
  when 201 then { 'transfer' => p[0] == 0 ? { 'map' => p[1], 'x' => p[2], 'y' => p[3] } : 'by variables' }
  when 121 then { 'set_switch' => [p[0], p[1], p[2] == 0 ? 'ON' : 'OFF'] }
  when 122 then { 'set_variable' => [p[0], p[1], %w[= += -= *= /= %=][p[2]] || p[2], p[3] == 0 ? p[4] : "source #{p[3]} #{p[4]}"] }
  when 123 then { 'set_self_switch' => [p[0], p[1] == 0 ? 'ON' : 'OFF'] }
  when 111 then { 'if' => p }
  when 411 then { 'else' => true }
  when 412 then { 'end_if' => true }
  when 102 then { 'choices' => p[0] }
  when 402 then { 'when_choice' => p[1] }
  when 101 then { 'text' => p[0].to_s }
  when 355, 655 then { 'script' => p[0].to_s }
  when 209
    route = (p[1].list rescue []).map { |mc| [MOVE_NAMES[mc.code] || mc.code, mc.parameters].flatten }.reject { |a| a[0] == 0 }
    { 'move_route' => { 'who' => p[0] == -1 ? 'player' : (p[0] == 0 ? 'this event' : "event #{p[0]}"), 'moves' => route } }
  when 117 then { 'common_event' => p[0] }
  when 116 then { 'erase_event' => true }
  when 115 then { 'exit' => true }
  end
end

# ---------------------------------------------------------------- main
game = ARGV[0] || Dir.pwd
data_dir = File.join(game, 'Data')
abort "Can't find #{data_dir}/MapInfos.rxdata - pass the Game folder as the argument" unless File.exist?(File.join(data_dir, 'MapInfos.rxdata'))
dump_dir = File.join(game, 'Dump')
FileUtils.mkdir_p(File.join(dump_dir, 'maps'))

infos = rxload(File.join(data_dir, 'MapInfos.rxdata'))
all = []
warp_lines = []

Dir[File.join(data_dir, 'Map[0-9][0-9][0-9].rxdata')].sort.each do |f|
  id = File.basename(f)[/\d+/].to_i
  begin
    m = rxload(f)
  rescue => e
    warn "skip #{f}: #{e.message}"
    next
  end
  info = infos[id]
  name = info ? info.name.to_s : "Map #{id}"
  entry = { 'id' => id, 'name' => name, 'parent' => (info ? info.parent_id : 0),
            'width' => m.width, 'height' => m.height, 'tileset' => m.tileset_id, 'events' => [] }
  txt = ["Map #{id}: #{name}  (#{m.width}x#{m.height}, parent #{entry['parent']})", '']
  (m.events || {}).keys.sort.each do |eid|
    ev = m.events[eid]
    e = { 'id' => eid, 'name' => ev.name.to_s, 'x' => ev.x, 'y' => ev.y, 'pages' => [] }
    txt << "Event #{eid} '#{ev.name}' at (#{ev.x},#{ev.y})"
    ev.pages.each_with_index do |pg, pi|
      cond = page_condition(pg)
      cmds = (pg.list || []).map { |q| (ci = command_info(q)) ? ci.merge('indent' => q.indent) : nil }.compact
      e['pages'] << { 'page' => pi, 'condition' => cond, 'trigger' => pg.trigger,
                      'graphic' => pg.graphic.character_name.to_s, 'tile_id' => pg.graphic.tile_id,
                      'through' => pg.through, 'move_type' => pg.move_type, 'commands' => cmds }
      trig = %w[action touch event-touch autorun parallel][pg.trigger] || pg.trigger
      txt << "  page #{pi}: when #{condition_text(cond)} | #{trig} | gfx '#{pg.graphic.character_name}' tile #{pg.graphic.tile_id}#{pg.through ? ' | through' : ''}"
      cmds.each do |c|
        ind = '    ' + '  ' * c['indent'].to_i
        txt << ind + c.reject { |k, _| k == 'indent' }.to_json
        if c['transfer'].is_a?(Hash)
          t = c['transfer']
          tname = infos[t['map']] ? infos[t['map']].name : "Map #{t['map']}"
          warp_lines << "#{id} #{name} (#{ev.x},#{ev.y}) ev#{eid} p#{pi} [#{condition_text(cond)}] -> #{t['map']} #{tname} (#{t['x']},#{t['y']})"
        end
      end
    end
    entry['events'] << e
    txt << ''
  end
  all << entry
  File.write(File.join(dump_dir, 'maps', format('Map%03d.txt', id)), txt.join("\n"))
end

File.write(File.join(dump_dir, 'maps.json'), JSON.generate(all))
File.write(File.join(dump_dir, 'warps.txt'), warp_lines.join("\n"))
puts "Dumped #{all.length} maps and #{warp_lines.length} transfers to #{dump_dir}"
