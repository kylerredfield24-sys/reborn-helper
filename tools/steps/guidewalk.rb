# walks the helper's own dots (story mode) from START until standing on the step's target, crossing doors and map edges
eval(File.read(File.join(File.dirname(__FILE__), "real3.rb")))
badges 13
switches 479, 2020
(ENV["SW"] || "").split(",").each { |s| switches s.to_i }
vars 276=>40, 339=>ENV['V339'].to_i
(ENV['SS'] || "").split(";").each { |t| a = t.split(",").map(&:to_i); self_switch a[0], a[1], "A" if a.length == 2 }
moves :CUT, :ROCKSMASH, :STRENGTH, :SURF, :FLY, :DIVE, :WATERFALL, :FLASH
sm = ENV['START'].split(",").map(&:to_i)
map sm[0], sm[1], sm[2]
only {
  RH.parse_updates(File.read(File.join(File.dirname(__FILE__), ENV['UPD'] || "updates53.txt")))
  W = {}
  File.foreach("Dump/warps.txt") { |l| m = l.match(/^(\d+) .*?\((\d+),(\d+)\) ev\d+ p\d+ \[(.*?)\] -> (\d+) .*?\((\d+),(\d+)\)/); next if !m; k = [m[1].to_i, m[2].to_i, m[3].to_i]; c = m[4]; ok = c == "always" || c.split(" & ").all? { |p| (p =~ /\Aswitch (\d+) ON\z/ && $game_switches[$1.to_i]) || (p =~ /\Avar (\d+) >= (-?\d+)\z/ && $game_variables[$1.to_i].to_i >= $2.to_i) }; W[k] = [m[5].to_i, m[6].to_i, m[7].to_i] if ok }
  goto_map(*sm)
  $target = :story
  gs = RH.guide_step
  puts "STEP: #{gs ? "#{gs[:map]} (#{gs[:x]},#{gs[:y]}) #{gs[:text][0,80]}" : 'NO GUIDE STEP'}"
  ok = false
  20.times do |i|
    $rh_live = nil
    res, r, secs = nav_once
    path, label = res
    puts "  on #{$game_map.map_id} #{RH.mapname($game_map.map_id)} (#{$game_player.x},#{$game_player.y}) | #{label.to_s[0,60]} len=#{path ? path.length : nil}"
    if gs && $game_map.map_id == gs[:map] && [$game_player.x, $game_player.y] == [gs[:x], gs[:y]]
      ok = true; break
    end
    break if !path || path.empty?
    lx, ly = path.last
    $game_player.x, $game_player.y = lx, ly
    next if gs && $game_map.map_id == gs[:map] && [lx, ly] == [gs[:x], gs[:y]]
    w = W[[$game_map.map_id, lx, ly]] || [[0,1],[0,-1],[1,0],[-1,0]].map { |dx,dy| W[[$game_map.map_id, lx+dx, ly+dy]] }.compact.first
    if !w
      RH.connections($game_map.map_id).each do |to, ax, ay, bx, by|
        [[0,-1],[0,1],[-1,0],[1,0]].each do |dx,dy|
          nx, ny = lx + dx, ly + dy
          next if nx >= 0 && ny >= 0 && nx < $game_map.width && ny < $game_map.height
          ox = nx - ax + bx; oy = ny - ay + by
          sz = RH.map_size(to)
          next if ox < 0 || oy < 0 || ox >= sz[0] || oy >= sz[1]
          w = [to, ox, oy]; break
        end
        break if w
      end
    end
    if !w then puts "  no exit at #{lx},#{ly}"; break end
    goto_map(*w)
  end
  puts(ok ? "PASS" : "FAIL")
}
