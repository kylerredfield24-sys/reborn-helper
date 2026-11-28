# Loads Reborn's real battle engine in plain Ruby (no graphics) so the helper's battle advice can be tested
# against real battles. Usage: ruby boot.rb <game dir> <test.rb>
GAME = File.expand_path(ARGV[0]); TEST = File.expand_path(ARGV[1])
Dir.chdir(GAME)
class BH
  def initialize(*a) end
  def method_missing(*a, &b) self end
  def respond_to_missing?(*a) true end
  def self.method_missing(*a, &b) BH.new end
  def to_i; 0 end; def to_s; "" end; def to_a; [] end; def nil?; false end
  def width; 32 end; def height; 32 end; def disposed?; false end; def dispose; end
  def coerce(o) [o, 0] end
end
%w[Sprite Viewport Bitmap Plane Window Font Tilemap Win32API WindowLayer TilemapLayer Mouse Discord MKXP].each { |n| Object.const_set(n, Class.new(BH)) }
def fileExists?(f) File.exist?(f) || File.exist?("patch/" + f) end
def gem(name) require name rescue nil end
module RPG; def self.const_missing(n) const_set(n, Class.new(BH)) end; end
module System; def self.platform; "Linux" end; def self.file_exist?(f) File.exist?(f) end; def self.method_missing(*a) nil end; end
module Graphics; def self.update; end; def self.const_missing(n) 0 end; def self.method_missing(*a) 0 end; def self.frame_rate; 40 end; def self.frame_count; 0 end; def self.width; 512 end; def self.height; 384 end; end
module Input; def self.update; end; def self.trigger?(*a) false end; def self.press?(*a) false end; def self.repeat?(*a) false end; def self.const_missing(n) const_set(n, n.to_s.hash % 1000) end; def self.method_missing(*a) false end; end
module Audio; def self.method_missing(*a) nil end; end
class Color; attr_accessor :red, :green, :blue, :alpha; def initialize(r = 0, g = 0, b = 0, a = 255) @red, @green, @blue, @alpha = r, g, b, a end; def set(*a) end; end
class Rect; attr_accessor :x, :y, :width, :height; def initialize(x = 0, y = 0, w = 0, h = 0) @x, @y, @width, @height = x, y, w, h end; def set(*a) end; end
class Tone < Color; end
class Table
  attr_reader :xsize, :ysize, :zsize
  def initialize(x = 1, y = 1, z = 1) @xsize, @ysize, @zsize = x, y, z; @data = Array.new(x * y * z, 0) end
  def self._load(s) t = allocate; t.instance_eval { _, @xsize, @ysize, @zsize, _n = s[0, 20].unpack('l5'); @data = s[20..-1].unpack('s*') }; t end
  def [](x, y = 0, z = 0) return nil if x < 0 || y < 0 || z < 0 || x >= @xsize || y >= @ysize || z >= @zsize; @data[x + y * @xsize + z * @xsize * @ysize] end
  def []=(*a) v = a.pop; x, y, z = a; @data[x + (y || 0) * @xsize + (z || 0) * @xsize * @ysize] = v end
end
class Color; def self._load(s) allocate end; end
class Tone; def self._load(s) allocate end; end
def define_path(path)
  mod = Object
  path.split('::').each_with_index do |p, i|
    if mod.const_defined?(p, false) then mod = mod.const_get(p, false)
    else nc = (i == path.split('::').size - 1) ? Class.new(BH) : Module.new; mod.const_set(p, nc); mod = nc end
  end
end
$joiplay = false
class Array; def intersect?(o) !(self & o).empty? end unless method_defined?(:intersect?); end
def print(*a) STDERR.puts a.inspect end
def p(*a) STDERR.puts a.inspect end
def load_data(f)
  data = File.binread(File.exist?(f) ? f : "patch/" + f)
  20.times do
    begin
      return Marshal.load(data)
    rescue ArgumentError => e
      raise if e.message !~ /undefined class\/module (\S+)/
      define_path($1)
    end
  end
end
def save_data(*a) end
SKIP = %w[Updater Load]
loadfails = []
eval(File.read("Scripts/Reborn/Bootstrap.rb"))
SCRIPTS.compact.each do |path|
  next if SKIP.include?(path)
  begin
    eval(File.read("Scripts/#{path}.rb"), TOPLEVEL_BINDING, "Scripts/#{path}.rb")
  rescue Exception => e
    loadfails << "#{path}: #{e.class} #{e.message[0, 120]}"
  end
end
STDERR.puts "LOAD FAILS:\n" + loadfails.join("\n") if !loadfails.empty?
eval(File.read(TEST), TOPLEVEL_BINDING, TEST)
