# Reborn Helper test harness - runs the helper's REAL route planner outside the game,
# on the game's own Data/*.rxdata files. Read-only: never writes into Data/ or Scripts/.
#
#   ruby harness.rb GAME_DIR HELPER_FILE SCENARIO_FILE
#
# A scenario file is Ruby that sets up the state, e.g.
#   map 490, 42, 5
#   vars 276 => 9, 259 => 2
#   switches 575
#   expect_map 471           # the route must eventually get there
require 'json'
require 'fiber'

GAME_DIR = File.expand_path(ARGV[0])
HELPER   = File.expand_path(ARGV[1])
SCEN     = File.expand_path(ARGV[2])
Dir.chdir(GAME_DIR)
$VERBOSE = nil

#------------------------------------------------------------------ Marshal stubs for the RPG Maker data
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
  def [](x, y = 0, z = 0)
    return nil if x < 0 || y < 0 || z < 0 || x >= @xsize || y >= @ysize || z >= @zsize
    @data[x + y * @xsize + z * @xsize * @ysize]
  end
end
class Color
  def initialize(*a) @a = a end
  def self._load(s) allocate end
end
class Tone
  def initialize(*a) end
  def self._load(s) allocate end
end
class GenericObj
  def method_missing(m, *a)
    return instance_variable_get("@#{m}") if a.empty? && m.to_s =~ /\A\w+\z/
    super
  end
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
def load_data(file)
  data = File.binread(file)
  80.times do
    begin
      return Marshal.load(data)
    rescue ArgumentError, TypeError => e
      raise unless e.message =~ /undefined class\/module (\S+)/
      define_path($1)
    end
  end
  raise "could not load #{file}"
end

#------------------------------------------------------------------ minimal game
class PBTerrain
  Ledge = 1; Grass = 2; Sand = 3; Rock = 4; DeepWater = 5; StillWater = 6; Water = 7; Waterfall = 8
  WaterfallCrest = 9; TallGrass = 10; UnderwaterGrass = 11; Ice = 12; Neutral = 13
end
def pbIsPassableWaterTag?(t) [5, 7, 6, 9].include?(t) end
def pbIsJustWaterTag?(t) [5, 7, 6].include?(t) end

class FakeCache
  def map_load(id) (@maps ||= {})[id] ||= load_data(sprintf("Data/Map%03d.rxdata", id)) end
  def mapinfos() @mi ||= load_data("Data/MapInfos.rxdata") end
  def RXtilesets() @ts ||= load_data("Data/Tilesets.rxdata") end
  def mapdata() nil end
  def items() {} end
end
$cache = FakeCache.new

class FakeSelfSwitches
  attr_reader :data
  def initialize; @data = {}; end
  def [](k) @data[k] ? true : false end
  def []=(k, v) @data[k] = v end
end
class FakeSwitches
  def initialize; @data = []; end
  def [](i) i.is_a?(Integer) ? (@data[i] ? true : false) : false end
  def []=(i, v) @data[i] = v end
end
class FakeVars
  def initialize; @data = []; end
  def [](i) i.is_a?(Integer) ? (@data[i] || 0) : 0 end
  def []=(i, v) @data[i] = v end
end

class Game_Event
  attr_reader :id, :x, :y, :name, :event, :through, :character_name, :tile_id, :list, :trigger
  def initialize(map_id, ev)
    @map_id = map_id
    @event = ev
    @id = ev.id
    @x = ev.x
    @y = ev.y
    @name = ev.name
    refresh
  end
  def refresh
    pg = nil
    @event.pages.reverse_each do |p|
      c = p.condition
      next if c.switch1_valid && !$game_switches[c.switch1_id]
      next if c.switch2_valid && !$game_switches[c.switch2_id]
      next if c.variable_valid && $game_variables[c.variable_id] < c.variable_value
      next if c.self_switch_valid && !$game_self_switches[[@map_id, @id, c.self_switch_ch]]
      pg = p
      break
    end
    @page = pg
    if pg
      @through = pg.through
      @character_name = pg.graphic.character_name.to_s
      @tile_id = pg.graphic.tile_id.to_i
      @list = pg.list
      @move_type = pg.move_type
      @trigger = pg.trigger
    else
      @through = true
      @character_name = ""
      @tile_id = 0
      @list = nil
      @move_type = 0
      @trigger = nil
    end
  end
  def moving?; false; end
end

class Game_Map
  attr_reader :map_id, :events
  def setup(id)
    @map_id = id
    @map = $cache.map_load(id)
    ts = $cache.RXtilesets[@map.tileset_id]
    @passages = ts.passages
    @priorities = ts.priorities
    @terrain_tags = ts.terrain_tags
    @events = {}
    @map.events.each { |i, e| @events[i] = Game_Event.new(id, e) }
  end
  def width; @map.width; end
  def height; @map.height; end
  def data; @map.data; end
  def display_x; 0; end
  def display_y; 0; end
  def valid?(x, y) x >= 0 && y >= 0 && x < width && y < height end
  def terrain_tag(x, y)
    [2, 1, 0].each do |i|
      t = data[x, y, i]
      next if !t
      tg = @terrain_tags[t]
      return tg if tg && tg > 0
    end
    0
  end
  def passable?(x, y, d, self_event = nil)
    return false if !valid?(x, y)
    bit = (1 << (d / 2 - 1)) & 0x0f
    events.each_value do |e|
      if e.tile_id >= 0 && e != self_event && e.x == x && e.y == y && !e.through
        return false if @passages[e.tile_id] & bit != 0
        return false if @passages[e.tile_id] & 0x0f == 0x0f
        return true if @priorities[e.tile_id] == 0
      end
    end
    [2, 1, 0].each do |i|
      tid = data[x, y, i]
      return false if tid.nil?
      return true if self_event == $game_player && $PokemonGlobal.surfing && pbIsPassableWaterTag?(@terrain_tags[tid])
      return false if @passages[tid] & bit != 0
      return false if @passages[tid] & 0x0f == 0x0f
      return true if @priorities[tid] == 0
    end
    true
  end
end

class Game_Player
  attr_accessor :x, :y, :through, :direction
  def initialize; @x = 0; @y = 0; @through = false; @direction = 2; end
  def moving?; false; end
  def character_name; "player"; end
  def passable?(x, y, d)
    nx = x + (d == 6 ? 1 : d == 4 ? -1 : 0)
    ny = y + (d == 2 ? 1 : d == 8 ? -1 : 0)
    return false if !$game_map.valid?(nx, ny)
    return false if !$game_map.passable?(x, y, d, self)
    return false if !$game_map.passable?(nx, ny, 10 - d, self)
    $game_map.events.each_value do |e|
      return false if e.x == nx && e.y == ny && !e.through && e.character_name != ""
    end
    true
  end
end

class FakeGlobal
  attr_accessor :bicycle, :surfing, :lavasurfing
end
class FakeTrainer
  attr_accessor :numbadges, :money, :party
  def initialize; @numbadges = 0; @money = 0; @party = []; end
end
class FakeBag
  def initialize; @items = {}; end
  def add(i) @items[i] = 1 end
  def pbQuantity(i) @items[i] || 0 end
  def pbHasItem?(i) (@items[i] || 0) > 0 end
end

module Graphics
  @fc = 0
  def self.frame_count; @fc; end
  def self.tick(n = 1); @fc += n; end
  def self.width; 512; end
  def self.height; 384; end
end
module Input
  def self.dir4; 0; end
  def self.trigger?(*) false end
  def self.press?(*) false end
  R = 1; L = 2
end
def pbMapInterpreterRunning?; false; end
def pbGetMapNameFromId(id) $cache.mapinfos[id].name.to_s end
$rh_moves_ok = {}
def pbCheckMove(m) $rh_moves_ok[m] end
module Kernel
  def self.pbCheckMove(m) $rh_moves_ok[m] end
  def self.ignoresBadgeRequirements; false; end
end

# stubs so the helper file loads (battle / scene / menu hooks)
class Scene_Map; def update; end; def disposeSpritesets; end; end
class PokeBattle_Battle; def pbSwitchInBetween(*a); end; def pbRecallAndReplace(*a); end; end
class PokeBattle_Scene
  %w[pbStartBattle pbEndBattle pbCommandMenu pbSwitch pbDisplayConfirmMessage pbFightMenu].each { |m| define_method(m) { |*a| } }
end
class Interpreter; def command_102; end; end
module Kernel; def self.pbMessage(*a, **k); end; end
def pbTrainerBattle(*a, **k); end
class Viewport; def initialize(*a); end; attr_accessor :z; def disposed?; false; end; def dispose; end; end
class Sprite; def initialize(*a); end; attr_accessor :bitmap, :x, :y, :z, :visible, :opacity; def disposed?; false; end; def dispose; end; end
class Bitmap; def initialize(*a); end; def method_missing(*a); end; end

#------------------------------------------------------------------ load the helper
code = File.read(HELPER)
code = code.sub(/^RH\.boot_update.*$/, "")     # never run the self-updater here
eval(code, TOPLEVEL_BINDING, HELPER)

#------------------------------------------------------------------ scenario DSL
$game_switches = FakeSwitches.new
$game_variables = FakeVars.new
$game_self_switches = FakeSelfSwitches.new
$game_map = Game_Map.new
$game_player = Game_Player.new
$PokemonGlobal = FakeGlobal.new
$Trainer = FakeTrainer.new
$PokemonBag = FakeBag.new
$expect = []

def map(id, x, y) $start = [id, x, y] end
def vars(h) h.each { |k, v| $game_variables[k] = v } end
def switches(*l) l.flatten.each { |s| $game_switches[s] = true } end
def switches_off(*l) l.flatten.each { |s| $game_switches[s] = false } end
def self_switch(m, e, c) $game_self_switches[[m, e, c]] = true end
def badges(n) $Trainer.numbadges = n end
def moves(*l) l.each { |m| $rh_moves_ok[m] = true } end
def items(*l) l.each { |i| $PokemonBag.add(i) } end
def expect_map(*ids) $expect = ids end
def max_hops(n) $max_hops = n end
def target(m) $target = m end
def only(&b) $only = b end      # route to a map instead of the story step

def reset_rh
  %w[$rh_route_db $rh_nav_cache $rh_job $rh_live $rh_obj $rh_fail $rh_quick $rh_evpos $rh_clearpos $rh_jumppos
     $rh_region $rh_rejoin $rh_want $rh_near $rh_hm_memo $rh_still $rh_nav_time].each { |v| eval("#{v} = nil") }
end

def goto_map(id, x, y)
  $game_map.setup(id)
  $game_player.x = x
  $game_player.y = y
  $rh_hist = (($rh_hist || []) << id).last(6)
  reset_rh
  # autorun / parallel scenes that start on arrival and move you: follow the first one that really moves you
end

def nav_once
  d = RH.g
  d[:nav] = $target || :story
  key, r = RH.nav_want_now
  return [nil, nil, "no goal"] if !key
  fib = Fiber.new { RH.nav_compute(key, r, $game_map.map_id) }
  res = nil
  t0 = Time.now
  loop do
    $rh_slice = Time.now
    $rh_in_fiber = true
    res = fib.resume
    $rh_in_fiber = false
    Graphics.tick
    break if !fib.alive?
    break if Time.now - t0 > 120
  end
  [res, r, (Time.now - t0).round(2)]
end

eval(File.read(SCEN), TOPLEVEL_BINDING, SCEN)
$game_map.setup($start[0])
$game_player.x = $start[1]
$game_player.y = $start[2]
$PokemonGlobal.surfing = false
if $only
  $only.call
  exit
end
puts "start: #{RH.mapname($start[0])} (#{$start[0]}) #{$start[1]},#{$start[2]}"
res, r, secs = nav_once
if r
  puts "goal : #{RH.mapname(r[:map])} (#{r[:map]}) ev#{r[:id]} (#{r[:x]},#{r[:y]})  [#{(RH.objective rescue $!.message)}]"
end
if res
  path, label = res
  puts "route: #{label}  #{path.length} tiles  (#{secs}s)"
  puts "       path #{path.inspect}" if !path.empty?
  puts "chain: #{($rh_plan_chain || []).map { |m| "#{RH.mapname(m)}(#{m})" }.join(' > ')}"
  puts "search: #{$rh_search_info}"
  puts "plan error: #{$rh_plan_err}" if $rh_plan_err
  ok = !path.empty? && ($expect.empty? || ($rh_plan_chain || []).any? { |m| $expect.include?(m) } || $expect.include?($start[0]))
  puts(ok ? "RESULT: OK" : "RESULT: FAIL")
else
  puts "RESULT: FAIL (#{secs})"
end
