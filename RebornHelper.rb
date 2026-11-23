RH_VERSION = 22   # bumped with every release (used by the auto-updater)
#==============================================================================
# Reborn Helper - an in-game assistant overlay for Pokemon Reborn 19.5
#
# INSTALL: put RebornHelper.rb in  Game/patch/Mods/  and restart the game.
# REMOVE:  delete that one file. Nothing else on your computer is touched.
#          (The only file it ever writes is Claude_Context.txt in the game
#          folder, and only when you press "Copy context for Claude".)
#
# CONTROLS (keyboard key in brackets; controller = same game button)
#   On the map:
#     R  (W / PgDn)  open / close the Helper menu   (game is paused while open)
#     L  (Q / PgUp)  turn the walking path (yellow dots) on / off
#   In the Helper menu:
#     Left / Right   change tab        Up / Down   move
#     A / C          select            B / X       close
#   In battle: the panel shows by itself (top-right) when you pick a command.
#     Short summary on the Fight / Bag / Pokemon screen,
#     full move-by-move numbers when you open "Fight".
#==============================================================================

module RH
  W = 512
  H = 384
  BG      = Color.new(12, 14, 20, 165)
  BG2     = Color.new(255, 255, 255, 18)
  TXT     = Color.new(236, 238, 242)
  DIM     = Color.new(150, 156, 168)
  GOOD    = Color.new(120, 220, 140)
  WARN    = Color.new(240, 190, 90)
  BAD     = Color.new(240, 110, 100)
  ACCENT  = Color.new(130, 190, 255)
  SHADOW  = Color.new(0, 0, 0, 120)
  LH      = 12

  # line height for the chosen font
  def self.lh
    f = FONTS[(g && g[:font]) || 0] || FONTS[0]
    return f[5] || LH
  end
  FONTS   = [["Clean", ["Arial", "Helvetica", "Liberation Sans"], 11],
             ["Clean small", ["Arial", "Helvetica", "Liberation Sans"], 10],
             ["Clean large", ["Arial", "Helvetica", "Liberation Sans"], 13],
             ["Game pixel", ["Power Green Small", "Pokemon Emerald Small"], 25, false, true, 16],
             # same size as Clean large, but crisper: bold, no blurry drop shadow
             ["Sharp large", ["Verdana", "Tahoma", "Helvetica", "Arial"], 12, true, false],
             ["Bold large", ["Arial", "Helvetica", "Liberation Sans"], 13, true, true],
             # pixel-perfect: the game's own clean font at its native size (no blur when the window is scaled)
             ["Crisp HD", ["Power Clear", "Power Green", "Pokemon Emerald"], 25, false, false, 16]]

  HEAL_ITEMS = {
    :POTION => 20, :FRESHWATER => 30, :BERRYJUICE => 20, :SODAPOP => 50,
    :SUPERPOTION => 60, :LEMONADE => 70, :MOOMOOMILK => 100,
    :HYPERPOTION => 120, :ULTRAPOTION => 200, :MAXPOTION => 9999, :FULLRESTORE => 9999
  }

  # Hand-checked objectives for spots where the story variables alone are not enough.
  # Each rule: condition -> text + target (map id, event id or x/y). Checked before the auto story tracker.
  def self.sw?(n)
    return ($game_switches[n] rescue false) ? true : false
  end

  def self.var(n)
    return ($game_variables[n] rescue 0).to_i
  end

  def self.has_item?(i)
    return ($PokemonBag.pbQuantity(i) rescue 0) > 0
  end

  # Blake's apartment secret-passage puzzle (Ametrine City) - switch names from the game files
  def self.apt_puzzle?
    sw?(506) && var(193) >= 16 && var(193) < 18 && !sw?(508)
  end

  def self.rules
    [
      [proc { apt_puzzle? && !sw?(507) && var(193) == 16 }, "Go back outside the apartment building - a scene plays.", 439, 142],
      [proc { apt_puzzle? && !sw?(507) }, "Go back up to Blake's room and talk to Shelly - she starts the search.", 457, 9],
      [proc { apt_puzzle? && sw?(507) && sw?(2227) }, "Puzzle skip is on: step on the White Shard by the crate in Blake's room to skip this puzzle.", 457, 41],
      [proc { apt_puzzle? && sw?(507) && !sw?(512) }, "Puzzle 1/6: check the game console - you get the Program Disc.", 457, 37],
      [proc { apt_puzzle? && sw?(507) && !sw?(513) && !sw?(514) }, "Puzzle 2/6: check the trash can - head of a key.", 457, 40],
      [proc { apt_puzzle? && sw?(507) && !sw?(513) && !sw?(515) }, "Puzzle 3/6: check the drawer - shaft of a key (makes the full key).", 457, 39],
      [proc { apt_puzzle? && sw?(507) && sw?(513) && !sw?(511) }, "Puzzle 4/6: open the cabinet with the key - Power Cable.", 457, 38],
      [proc { apt_puzzle? && sw?(507) && sw?(511) && !(sw?(509) && sw?(510)) }, "Puzzle 5/6: use the computer tower (twice) to power it on and put in the Program Disc.", 457, 24],
      [proc { apt_puzzle? && sw?(507) }, "Puzzle 6/6: use the monitor and enter the code 5083164 - opens the secret door.", 457, 25],
      [proc { sw?(506) && sw?(508) && var(193) < 18 }, "Secret door is open: talk to Shelly, then go through the passage behind the bookshelf.", 457, 30],
      [proc { var(184) == 16 }, "Talk to Saphira by the fountain in Calcenon City (west side).", 413, 51],
      [proc { var(184) == 21 }, "Go to the Calcenon Checkpoint (east edge of Calcenon City) to meet Charlotte.", 418, 4],
      [proc { var(184) == 22 && !sw?(499) }, "Beat Charlotte at the Calcenon Gym (north side of Calcenon City).", 419, 237],
      [proc { sw?(499) && var(193) == 0 && !has_item?(:HM06) }, "Leave the gym - your friends meet you in Calcenon City and give you HM06 (Dive).", 417, 15],
      [proc { sw?(499) && var(193) == 0 && has_item?(:HM06) && sw?(486) && ($Trainer.money rescue 0) >= 40000 },
       "Shortcut is closed: talk to the attendant inside Calcenon Checkpoint and donate $40,000 to reopen the Route 3 stairs to Ametrine Mountain.", 418, 8],
      [proc { sw?(499) && var(193) == 0 && has_item?(:HM06) && !can_dive? }, "Teach Dive (TMX6) and Surf (TMX3) to Vaporeon - you need both to reach the PULSE Avalugg in Ametrine Mountain.", 0, 0],
      [proc { sw?(499) && var(193) == 0 && has_item?(:HM06) }, "Ametrine Mountain 2F: Surf, Dive in the dark water, follow the path underwater and surface by the small cave to fight the PULSE Avalugg (bring Fire/Fighting).", 432, 1]
    ]
  end

  def self.rule_step
    rules.each do |cond, txt, map, ev|
      ok = (cond.call rescue false)
      return { :text => txt, :map => map, :id => ev, :x => 0, :y => 0, :to => -1 } if ok
    end
    return nil
  end

  #------------------------------------------------------------------ state
  def self.g
    return nil if !$PokemonGlobal
    d = $PokemonGlobal.instance_variable_get(:@rh_data)
    if !d.is_a?(Hash)
      d = {}
      $PokemonGlobal.instance_variable_set(:@rh_data, d)
    end
    if !d[:rh_loaded]           # settings saved outside the save file (kept even if you don't save)
      d[:rh_loaded] = true
      load_settings(d)
    end
    d[:hud] = true if d[:hud].nil?
    d[:dots] = true if d[:dots].nil?
    d[:font] ||= 0
    d[:battle] = true if d[:battle].nil?
    d[:clues] ||= []
    d[:candy] ||= 0
    return d
  end

  def self.log
    $rh_battle_log ||= []
  end

  SETTINGS_FILE = "./patch/Mods/RebornHelper_settings.txt"
  SETTING_KEYS = [:hud, :dots, :font, :battle, :sync]

  def self.load_settings(d)
    return if !File.exist?(SETTINGS_FILE)
    File.read(SETTINGS_FILE).each_line do |l|
      k, v = l.strip.split("=", 2)
      next if !k || !v || !SETTING_KEYS.include?(k.to_sym)
      d[k.to_sym] = v == "true" ? true : v == "false" ? false : v.to_i
    end
  rescue
  end

  def self.save_settings
    d = g
    return if !d
    File.open(SETTINGS_FILE, "w") { |f| SETTING_KEYS.each { |k| f.puts("#{k}=#{d[k]}") unless d[k].nil? } }
  rescue
  end

  #------------------------------------------------------------------ text
  def self.font(bmp, size = nil)
    f = FONTS[(g && g[:font]) || 0] || FONTS[0]
    name = nil
    begin
      name = MessageConfig.pbTryFonts(*f[1])
    rescue
      name = f[1][0]
    end
    # always set the name (an empty lookup used to leave the old font on the bitmap)
    name = (Font.default_name rescue "Arial") if !name || name.empty? || (name.is_a?(Array) && name.empty?)
    name = name.first if name.is_a?(Array)
    bmp.font.name = name
    bmp.font.size = f[2]
    bmp.font.bold = f[3] ? true : false
  end

  def self.text(bmp, x, y, w, str, col = TXT, align = 0)
    str = str.to_s
    f = FONTS[(g && g[:font]) || 0] || FONTS[0]
    if f[4] != false               # "Sharp" style skips the shadow so letters stay crisp
      bmp.font.color = SHADOW
      bmp.draw_text(x + 1, y + 1, w, RH.lh + 2, str, align)
    end
    bmp.font.color = col
    bmp.draw_text(x, y, w, RH.lh + 2, str, align)
  end

  def self.wrap(bmp, str, w)
    words = str.to_s.split(" ")
    lines = []
    cur = ""
    words.each do |wd|
      t = cur.empty? ? wd : cur + " " + wd
      if bmp.text_size(t).width > w && !cur.empty?
        lines << cur
        cur = wd
      else
        cur = t
      end
    end
    lines << cur if !cur.empty?
    return lines
  end

  def self.cut(bmp, str, w)
    s = str.to_s
    return s if bmp.text_size(s).width <= w
    s = s[0...-1] while s.length > 1 && bmp.text_size(s + ".").width > w
    return s + "."
  end

  def self.pct(n, d)
    return 0 if !d || d <= 0
    return (n * 100.0 / d).round
  end

  def self.mname(sym)
    begin
      return getMoveName(sym)
    rescue
      return sym.to_s.capitalize
    end
  end

  def self.iname(sym)
    begin
      return getItemName(sym)
    rescue
      return sym.to_s.capitalize
    end
  end

  def self.mapname(id)
    begin
      return pbGetMapNameFromId(id)
    rescue
      return "Map #{id}"
    end
  end

  #------------------------------------------------------------------ level cap / candy
  def self.cap
    badges = $Trainer ? $Trainer.numbadges : 0
    c = LEVELCAPS[[badges, LEVELCAPS.length - 1].min] rescue 100
    ext = ($game_variables[:Extended_Max_Level] rescue 0).to_i
    return [c, 100 + ext].min
  end

  def self.old_candies_used
    n = 0
    [:@mc_maxcandy_used, :@mc2_maxcandy2_used, :@mc3_maxcandy3_used, :@mc4_maxcandy4_used].each do |v|
      n += 1 if $PokemonGlobal && $PokemonGlobal.instance_variable_get(v) == true
    end
    return n
  end

  class DummyScene
    def pbRefresh; end
  end

  def self.use_candy
    c = cap
    targets = $Trainer.party.find_all { |p| p && !p.isEgg? && p.level < c }
    if targets.empty?
      Kernel.pbMessage(_INTL("Everyone in your party is already at the level cap ({1}).", c))
      return
    end
    names = targets.map { |p| p.name }.join(", ")
    return if !Kernel.pbConfirmMessage(_INTL("Max Candy: raise {1} to Lv. {2}?", names, c))
    sc = DummyScene.new
    targets.each { |p| pbChangeLevel(p, c, sc) }
    g[:candy] += 1
  end

  #------------------------------------------------------------------ dialogue clues
  def self.map_names
    return $rh_mapnames if $rh_mapnames
    $rh_mapnames = {}
    begin
      infos = load_data("Data/MapInfos.rxdata")
      infos.each do |id, info|
        n = info.name.to_s
        next if n.length < 5
        next if n =~ /^(EV|MAP|Map|Copy|Intro|Debug|Test|Blank)/
        ($rh_mapnames[n] ||= []) << id
      end
    rescue
    end
    return $rh_mapnames
  end

  def self.clean(msg)
    s = msg.to_s.dup
    s = s.gsub(/\\[Pp][Nn]/, ($Trainer ? $Trainer.name : "you"))
    s = s.gsub(/\\[a-zA-Z]+\[[^\]]*\]/, "").gsub(/\\[a-zA-Z.!|^]/, "").gsub(/<[^>]*>/, "")
    s = s.gsub(/\s+/, " ").strip
    return s
  end

  def self.capture(msg)
    return if !$PokemonGlobal || $game_switches.nil?
    return if ($game_temp && $game_temp.in_battle rescue false)
    s = clean(msg)
    return if s.length < 8
    found = nil
    map_names.keys.sort_by { |n| -n.length }.each do |n|
      if s.include?(n)
        found = n
        break
      end
    end
    hint = s =~ /\b(go to|head to|headed to|meet (me|us)|come to|find (me|him|her)|wait(ing)? (for you )?at|on your way to)\b/i
    return if !found && !hint
    d = g
    return if d[:clues].any? { |c| c[:text] == s }
    d[:clues].unshift({ :text => s[0, 140], :map => found, :from => ($game_map.map_id rescue 0), :done => false })
    d[:clues] = d[:clues][0, 8]
  end

  def self.mark_visited
    d = g
    return if !d || !$game_map
    here = mapname($game_map.map_id)
    d[:clues].each { |c| c[:done] = true if c[:map] && here.include?(c[:map]) }
  end

  def self.objective
    key = [STORY_VARS.map { |v| ($game_variables[v] rescue 0) }, ($Trainer.numbadges rescue 0), sw?(499), has_item?(:HM06), ((rule_step || {})[:text] rescue nil), (g[:clues].first rescue nil), (updates[:obj].length rescue 0), ($game_map.map_id rescue 0),
           (pbMapInterpreterRunning? rescue false),
           ((lr = (live_step rescue nil)) ? [lr[:map], lr[:id], lr[:x], lr[:y]] : nil), ($game_player.x / 4 rescue 0), ($game_player.y / 4 rescue 0)]
    return $rh_obj[1] if $rh_obj && $rh_obj[0] == key
    res = objective_uncached
    $rh_obj = [key, res]
    return res
  end

  def self.objective_uncached
    u = (update_obj rescue nil)
    return u[:text] if u
    rs = (rule_step rescue nil)
    return rs[:text] if rs
    lr = (live_step rescue nil)
    return live_text(lr) if lr
    r = (story_step rescue nil)
    return step_text(r) if r
    c = g[:clues].find { |x| !x[:done] }
    return "Last told: " + c[:text] if c
    return nil
  end

  #------------------------------------------------------------------ world graph
  def self.warps
    return $rh_warps if $rh_warps
    $rh_warps = {}
    RH_WARP_DATA.split(";").each do |e|
      a = e.split(",").map(&:to_i)
      ($rh_warps[a[0]] ||= []) << [a[1], a[2], a[3], a[4], a[5], a[6]]
    end
    return $rh_warps
  end

  def self.connections(id)
    out = []
    return out if !defined?(MAPCONNECTIONSHASH)
    MAPCONNECTIONSHASH.each do |k, v|
      (v[:connections] || []).each do |c|
        if c[0] == id
          out << [c[3], c[1], c[2], c[4], c[5]]
        elsif c[3] == id
          out << [c[0], c[4], c[5], c[1], c[2]]
        end
      end
    end
    return out
  end

  # is this warp open right now? (checks the switch / story variable it needs)
  def self.warp_open?(w, from = nil)
    sw, vid, vval = w[3], w[4], w[5]
    tv, tsw = from ? transit_vars(from) : [{}, {}]
    return false if sw && sw > 0 && !($game_switches[sw] rescue true) && !tsw[sw]
    if vid && vid > 0 && ($game_variables[vid] rescue 0).to_i < vval
      # a value the way into this area sets for you (e.g. going down a waterfall) still counts
      return false if !(tv[vid] || []).any? { |x| x >= vval }
    end
    return true
  end

  def self.open_warps(id)
    (warps[id] || []).find_all { |w| warp_open?(w, id) }
  end

  def self.neighbors(id)
    n = open_warps(id).map { |w| w[2] }
    n += connections(id).map { |c| c[0] }
    return n.uniq
  end

  # Route search over (map, came-from map) states.
  # Learned facts: g[:reach][[from, map]] = exits you can actually walk to after entering "map" from "from".
  # On the current map we use a live flood-fill, so blocked paths (cliffs, rocks, closed areas) are avoided.
  def self.next_hop(from, targets)
    return nil if targets.include?(from)
    learned = (g[:reach] rescue nil) || {}
    here_ok = (reach_here rescue nil)
    came = $rh_came_from
    start = [from, came]
    prev = { start => nil }
    q = [start]
    until q.empty?
      cur = q.shift
      m, pm = cur
      nbs = neighbors(m)
      if cur.equal?(start) && here_ok
        nbs = nbs.find_all { |n| here_ok.include?(n) }
      elsif learned[[pm, m]]
        nbs = nbs.find_all { |n| learned[[pm, m]].include?(n) }
      end
      nbs.each do |nb|
        st = [nb, m]
        next if prev.key?(st)
        prev[st] = cur
        if targets.include?(nb)
          s = st
          s = prev[s] while prev[s] != start
          return s[0]
        end
        q << st
      end
      break if prev.size > 6000
    end
    return nil
  end

  # which neighbouring maps can you walk to from where you stand? (one flood-fill per area, cached)
  def self.reach_here
    return nil if !$game_map || !$game_player
    id = $game_map.map_id
    pos = [$game_player.x, $game_player.y]
    if $rh_region && $rh_region[0] == id && $rh_region[1][pos]
      return $rh_region[2]
    end
    seen = flood
    return nil if !seen
    ok = []
    neighbors(id).each do |nb|
      gt = goal_tiles(nb)
      hit = gt.any? do |x, y|
        seen[[x, y]] || seen[[x + 1, y]] || seen[[x - 1, y]] || seen[[x, y + 1]] || seen[[x, y - 1]]
      end
      ok << nb if hit
    end
    $rh_region = [id, seen, ok]
    d = g
    if d && $rh_came_from
      d[:reach] ||= {}
      if $rh_region_entry == [id, $rh_came_from]
        # doors usually land you next to the door back, so every map this area leads to
        # also drops you into this same area when you come from it
        ([$rh_came_from] + ok).uniq.each { |pm| d[:reach][[pm, id]] = ok }
      end
    end
    return ok
  end

  # search as if walking (you can always hop off the bike - tall grass blocks bikes)
  def self.flood
    bike = ($PokemonGlobal.bicycle rescue false)
    $PokemonGlobal.bicycle = false if bike
    return rh_flood
  ensure
    $PokemonGlobal.bicycle = true if bike
  end

  def self.rh_flood
    sx = $game_player.x
    sy = $game_player.y
    surf = can_surf?
    ev_cache
    mw = $game_map.width
    mh = $game_map.height
    seen = { [sx, sy] => true }
    q = [[sx, sy]]
    dirs = [[2, 0, 1], [4, -1, 0], [6, 1, 0], [8, 0, -1]]
    until q.empty?
      cx, cy = q.shift
      dirs.each do |d, dx, dy|
        n = step(cx, cy, d, dx, dy, mw, mh, surf)
        next if !n || seen[n]
        seen[n] = true
        q << n
      end
      break if seen.size > 20000
    end
    return seen
  end

  def self.ev_cache
    $rh_evpos = {}
    $rh_clearpos = {}
    $rh_jumppos = {}
    ($game_map.events || {}).each_value do |ev|
      next if ev.through
      js = (jump_spec(ev.list) rescue nil)
      $rh_jumppos[[ev.x, ev.y]] = js if js
    end
    ($game_map.events || {}).each_value do |ev|
      next if ev.through || ev.character_name.to_s == ""
      if clearable?(ev.list)
        $rh_clearpos[[ev.x, ev.y]] = true
        next
      end
      $rh_evpos[[ev.x, ev.y]] = true
    end
    ($game_map.events || {}).each_value do |ev|
      $rh_evpos[[ev.x, ev.y]] = true if climb_wall?((ev.name rescue ""), (ev.list rescue nil))
    end
    ($rh_blocked || {}).each_key { |(mid, t)| $rh_evpos[t] = true if mid == $game_map.map_id }
  rescue
    $rh_evpos = {}
  end

  def self.map_size(id)
    $rh_sizes ||= {}
    return $rh_sizes[id] if $rh_sizes[id]
    begin
      m = load_data(sprintf("Data/Map%03d.rxdata", id))
      $rh_sizes[id] = [m.width, m.height]
    rescue
      $rh_sizes[id] = [0, 0]
    end
    return $rh_sizes[id]
  end

  # goal tiles on the current map that lead into map "dest"
  def self.goal_tiles(dest)
    id = $game_map.map_id
    goals = []
    open_warps(id).each do |w|
      goals << [w[0], w[1]] if w[2] == dest
    end
    connections(id).each do |to, ax, ay, bx, by|
      next if to != dest
      w2, h2 = map_size(to)
      mw = $game_map.width
      mh = $game_map.height
      for x in 0...mw
        for y in [0, mh - 1]
          goals << [x, y] if inside?(x, y + (y == 0 ? -1 : 1), ax, ay, bx, by, w2, h2)
        end
      end
      for y in 0...mh
        for x in [0, mw - 1]
          goals << [x, y] if inside?(x + (x == 0 ? -1 : 1), y, ax, ay, bx, by, w2, h2)
        end
      end
    end
    return goals.uniq
  end

  def self.inside?(x, y, ax, ay, bx, by, w2, h2)
    ox = x - ax + bx
    oy = y - ay + by
    return ox >= 0 && oy >= 0 && ox < w2 && oy < h2
  end

  def self.exits_here
    id = $game_map.map_id
    list = {}
    open_warps(id).each { |w| list[w[2]] = true }
    connections(id).each { |c| list[c[0]] = true }
    return list.keys.map { |to| [to, mapname(to)] }.sort_by { |a| a[1] }
  end

  # can you use this field move right now? Uses the game's own check, so the Easy HMs
  # password (HM in bag = usable, no teaching) and Golden items count too.
  def self.hm_ok?(move, badge, golden = nil, hm = nil)
    t = (Graphics.frame_count / 40 rescue 0)   # re-check about once a second (the game's check is slow)
    $rh_hm_memo = [t, {}] if !$rh_hm_memo || $rh_hm_memo[0] != t
    m = $rh_hm_memo[1]
    return m[move] if m.key?(move)
    m[move] = hm_ok_now?(move, badge, golden, hm)
  end

  def self.hm_ok_now?(move, badge, golden, hm)
    return false if !$Trainer
    nobadge = (Kernel.ignoresBadgeRequirements rescue false)
    return false if !nobadge && $Trainer.numbadges < badge
    return true if (send(:pbCheckMove, move) rescue nil)
    return true if (Kernel.pbCheckMove(move) rescue nil)
    return true if golden && hm && ($PokemonBag.pbHasItem?(golden) rescue false) && ($PokemonBag.pbHasItem?(hm) rescue false)
    return $Trainer.party.any? { |p| p && !p.isEgg? && p.moves.any? { |m| m && m.move == move } }
  end

  def self.can_surf?
    hm_ok?(:SURF, (BADGEFORSURF rescue 10), :GOLDENSURFBOARD, :HM03)
  end

  def self.can_smash?
    hm_ok?(:ROCKSMASH, (BADGEFORROCKSMASH rescue 3))
  end

  def self.can_rockclimb?
    hm_ok?(:ROCKCLIMB, (BADGEFORROCKCLIMB rescue 16), :GOLDENCLAWS, :TM101)
  end

  def self.can_waterfall?
    hm_ok?(:WATERFALL, (BADGEFORWATERFALL rescue 12), :GOLDENJETPACK, :HM05)
  end

  # Rock Climb walls are marked by events named "RockClimb..." - a wall if you can't climb yet
  def self.climb_wall?(name, list)
    return false if !name.to_s.start_with?("RockClimb")   # every tile of a climbing wall (ends and middle)
    return !can_rockclimb?
  end

  def self.can_cut?
    hm_ok?(:CUT, (BADGEFORCUT rescue 1))
  end

  # rocks / trees you can clear with Rock Smash / Cut don't count as walls
  def self.clearable?(list)
    s = ""
    (list || []).each { |c| s << c.parameters.last.to_s << ";" if [355, 655, 111].include?(c.code) }
    return true if s =~ /pbRockSmash/ && can_smash?
    return true if s =~ /pbCut/ && can_cut?
    return false
  rescue
    return false
  end

  def self.ice?(x, y)
    return ($game_map.terrain_tag(x, y) rescue 0) == (PBTerrain::Ice rescue 12)
  end

  def self.water?(x, y)
    t = ($game_map.terrain_tag(x, y) rescue 0)
    return true if (pbIsPassableWaterTag?(t) rescue false)
    return t == (PBTerrain::Waterfall rescue 8) && can_waterfall?
  end

  def self.ledge?(x, y)
    return ($game_map.terrain_tag(x, y) rescue 0) == (PBTerrain::Ledge rescue 1)
  end

  # is there a Rock Smash rock / Cut tree here that you can clear?
  def self.clear_at?(x, y)
    ev_cache if !$rh_clearpos
    return $rh_clearpos[[x, y]] ? true : false
  end

  def self.blocked_by_event?(x, y)
    ev_cache if !$rh_evpos
    return $rh_evpos[[x, y]] ? true : false
  end

  # steps from (x,y) going d: returns landing tile or nil (handles ledges + Surf)
  def self.step(x, y, d, dx, dy, mw, mh, surf)
    nx = x + dx
    ny = y + dy
    return nil if nx < 0 || ny < 0 || nx >= mw || ny >= mh
    if $rh_jumppos && (js = $rh_jumppos[[nx, ny]]) && (jd = js[d] || js[:any])   # jump pad / gap
      lx = x + jd[0]
      ly = y + jd[1]
      return nil if lx < 0 || ly < 0 || lx >= mw || ly >= mh || blocked_by_event?(lx, ly)
      return [lx, ly] if ($game_map.passable?(lx, ly, 10 - d) rescue false) || ($game_map.passable?(lx, ly, d) rescue false)
      return nil
    end
    if ($game_player.passable?(x, y, d) rescue false) || (clear_at?(nx, ny) && ($game_map.passable?(nx, ny, 10 - d) rescue false))
      if ice?(nx, ny)   # slide until something stops you
        cx, cy = nx, ny
        loop do
          break if !ice?(cx, cy)
          break if !($game_player.passable?(cx, cy, d) rescue false)
          cx += dx
          cy += dy
        end
        return [cx, cy]
      end
      if ledge?(nx, ny)
        lx = nx + dx
        ly = ny + dy
        return nil if lx < 0 || ly < 0 || lx >= mw || ly >= mh
        return nil if blocked_by_event?(lx, ly)
        return ($game_map.passable?(lx, ly, 0) rescue false) ? [lx, ly] : nil
      end
      return [nx, ny]
    end
    if surf && water?(nx, ny) && !blocked_by_event?(nx, ny)
      return [nx, ny]
    end
    if surf && water?(x, y) && !water?(nx, ny) && ($game_map.passable?(nx, ny, 10 - d) rescue false) && !blocked_by_event?(nx, ny)
      return [nx, ny]
    end
    return nil
  end

  # search as if walking (you can always hop off the bike - tall grass blocks bikes)
  def self.tile_path(goals)
    bike = ($PokemonGlobal.bicycle rescue false)
    $PokemonGlobal.bicycle = false if bike
    $rh_tp_bike = bike
    return rh_tile_path(goals)
  ensure
    back = bike && $rh_tp_bike     # (if you got off the bike meanwhile, leave it that way)
    $rh_tp_bike = nil
    $PokemonGlobal.bicycle = true if back
  end

  def self.rh_tile_path(goals)
    return [] if goals.empty? || !$game_player
    gs = {}
    goals.each { |x, y| gs[[x, y]] = true }
    sx = $game_player.x
    sy = $game_player.y
    return [[sx, sy]] if gs[[sx, sy]]
    ev_cache
    if $rh_region && $rh_region[0] == $game_map.map_id && $rh_region[1][[sx, sy]]
      seen = $rh_region[1]
      reach = goals.any? { |x, y| seen[[x, y]] || seen[[x + 1, y]] || seen[[x - 1, y]] || seen[[x, y + 1]] || seen[[x, y - 1]] }
      return [] if !reach   # can't get there from this area - skip the slow search
    end
    surf = can_surf?
    prev = { [sx, sy] => nil }
    q = [[sx, sy]]
    dirs = [[2, 0, 1], [4, -1, 0], [6, 1, 0], [8, 0, -1]]
    mw = $game_map.width
    mh = $game_map.height
    found = nil
    until q.empty?
      cx, cy = q.shift
      slice! if (prev.size & 255) == 0
      dirs.each do |d, dx, dy|
        ax = cx + dx
        ay = cy + dy
        if gs[[ax, ay]] && !prev.key?([ax, ay])
          prev[[ax, ay]] = [cx, cy]
          found = [ax, ay]
          break
        end
        n = step(cx, cy, d, dx, dy, mw, mh, surf)
        next if !n || prev.key?(n)
        prev[n] = [cx, cy]
        if gs[n]
          found = n
          break
        end
        q << n
      end
      break if found
      break if prev.size > 20000
    end
    return [] if !found
    path = []
    c = found
    while c
      path.unshift(c)
      c = prev[c]
    end
    return fill_path(path)
  end

  # ice slides and ledge jumps skip tiles - fill them in so the dots form an unbroken line
  # (and so the helper still knows you are on the path while you slide)
  def self.fill_path(path)
    out = []
    path.each do |x, y|
      if (l = out.last)
        dx = x <=> l[0]
        dy = y <=> l[1]
        if (dx == 0 || dy == 0) && ((x - l[0]).abs + (y - l[1]).abs) > 1
          cx, cy = l
          loop do
            cx += dx
            cy += dy
            break if cx == x && cy == y
            out << [cx, cy]
          end
        end
      end
      out << [x, y]
    end
    return out
  end

  #------------------------------------------------------------------ whole-game story tracking
  STORY_VARS = [56, 77, 92, 104, 107, 118, 123, 149, 150, 159, 173, 184, 193, 276, 339, 381, 391, 475]

  def self.story_recs
    return $rh_story if $rh_story
    $rh_story = []
    RH_STORY_DATA.split(";").each do |e|
      a = e.split(",", 11)
      $rh_story << { :v => a[0].to_i, :to => a[1].to_i, :map => a[2].to_i, :id => a[3].to_i, :x => a[4].to_i, :y => a[5].to_i,
                     :trig => a[6].to_i, :cv => a[7].to_i, :cval => a[8].to_i, :sw => a[9].to_i, :sp => a[10].to_s }
    end
    return $rh_story
  end

  def self.next_step(var, v)
    recs = story_recs.find_all { |r| r[:v] == var && r[:to] > v }
    same = recs.find_all { |r| r[:cv] == var && r[:cval] <= v }
    if !same.empty?
      top = same.map { |r| r[:cval] }.max
      same = same.find_all { |r| r[:cval] == top }
      return pick(same)
    end
    other = recs.find_all { |r| r[:cv] != var }
    return nil if other.empty?
    low = other.map { |r| r[:to] }.min
    return pick(other.find_all { |r| r[:to] == low })
  end

  def self.pick(list)
    ok = list.find_all { |r| r[:sw] == 0 || ($game_switches[r[:sw]] rescue false) }
    list = ok if !ok.empty?
    here = ($game_map.map_id rescue 0)
    return list.find { |r| r[:map] == here } || list.first
  end

  def self.story_step
    vals = STORY_VARS.map { |v| ($game_variables[v] rescue 0).to_i }
    last = nil
    vals.each_with_index { |val, i| last = i if val > 0 }
    if last.nil?
      return next_step(STORY_VARS[0], 0)
    end
    r = next_step(STORY_VARS[last], vals[last])
    return r if r
    if last + 1 < STORY_VARS.length
      return next_step(STORY_VARS[last + 1], vals[last + 1])
    end
    return nil
  end

  def self.step_text(r)
    who = r[:sp].to_s.strip
    who = who.split(" ").map { |w| w.capitalize }.join(" ")
    place = mapname(r[:map])
    case r[:trig]
    when 0 then return who.empty? ? "Check the marked spot in #{place}." : "Talk to #{who} in #{place}."
    when 1, 2 then return "Walk to the marked spot in #{place}."
    else return "Go to #{place} - a scene starts" + (who.empty? ? "." : " (#{who}).")
    end
  end

  # live position of the story target on the current map
  def self.story_goal_tiles(r)
    x = r[:x]
    y = r[:y]
    ev = r[:id].to_i > 0 ? ($game_map.events[r[:id]] rescue nil) : nil
    if ev
      x = ev.x
      y = ev.y
    end
    return [[x, y]] if r[:trig].to_i == 1 || r[:trig].to_i == 2   # step-on spot: be exactly there
    return [[x, y], [x, y + 1], [x - 1, y], [x + 1, y], [x, y - 1], [x, y + 2], [x - 2, y], [x + 2, y], [x, y - 2]]   # y+2: talk across a counter
  end

  # same as story_goal_tiles but for any map (reads the map file)
  def self.spot_tiles(r)
    # scenes that start by themselves (autorun / background) fire as soon as you're anywhere in that place
    return nil if r[:trig].to_i == 3 || r[:trig].to_i == 4
    x = r[:x].to_i
    y = r[:y].to_i
    if r[:id].to_i > 0
      ev = (r[:map] == $game_map.map_id) ? ($game_map.events[r[:id]] rescue nil) : nil
      ev ||= (($cache.map_load(r[:map]).events[r[:id]]) rescue nil)
      return nil if !ev
      x = ev.x
      y = ev.y
    end
    return nil if x <= 0 && y <= 0
    return [[x, y]] if r[:trig].to_i == 1 || r[:trig].to_i == 2
    return [[x, y], [x, y + 1], [x - 1, y], [x + 1, y], [x, y - 1], [x, y + 2], [x - 2, y], [x + 2, y], [x, y - 2]]
  end

  # keep the old path while you are still standing on it (no re-search every step)
  def self.trim_cached(key)
    return nil if !$rh_nav_cache || $rh_nav_cache[0] != key
    path, label = $rh_nav_cache[1]
    return [path, label] if path.empty? && $rh_nav_cache[2] == [$game_player.x, $game_player.y]
    return follow(path, label)
  end

  # far from the line: small search back to the nearest point of it (cached per tile, so walking stays smooth)
  def self.rejoin(path, label, cap = 900)
    pos = [$game_player.x, $game_player.y]
    return $rh_rejoin[1] if $rh_rejoin && $rh_rejoin[0] == [pos, path.length, path.last] && ($rh_rejoin[1] || $rh_rejoin[2] >= cap)
    on = {}
    path.each_with_index { |t, j| on[t] = j }
    surf = can_surf?
    mw = $game_map.width
    mh = $game_map.height
    prev = { pos => nil }
    q = [pos]
    hit = nil
    dirs = [[2, 0, 1], [4, -1, 0], [6, 1, 0], [8, 0, -1]]
    until q.empty? || hit
      cx, cy = q.shift
      dirs.each do |d, dx, dy|
        n = step(cx, cy, d, dx, dy, mw, mh, surf)
        next if !n || prev.key?(n)
        prev[n] = [cx, cy]
        if on[n]
          hit = n
          break
        end
        q << n
      end
      break if prev.size > cap
    end
    res = nil
    if hit
      link = []
      c = prev[hit]
      while c
        link.unshift(c)
        c = prev[c]
      end
      res = [fill_path(link) + path[on[hit]..-1], label]
    end
    $rh_rejoin = [[pos, path.length, path.last], res, cap]
    return res
  end

  # show the line from where you are: on the line -> cut off what's behind you;
  # a few steps off it -> draw a short link back to the nearest point ahead; far off -> nil (re-plan)
  def self.follow(path, label)
    return [path, label] if path.empty?
    px = $game_player.x
    py = $game_player.y
    i = path.index([px, py])
    return [path[i..-1], label] if i
    best = nil
    path.each_with_index do |t, j|
      d = (t[0] - px).abs + (t[1] - py).abs
      best = [d, j] if !best || d < best[0] || (d == best[0] && j > best[1])
    end
    return nil if !best
    if best[0] > 1
      # off the line: find a real way back to it using the game's own walls (never draw through rocks)
      if $game_player.moving? && best[0] <= 3
        return [path[best[1]..-1], label]      # just a step or two off while walking: no search needed
      end
      rj = rejoin(path, label, $game_player.moving? ? 150 : 900)
      return rj if rj
      busy = $game_player.moving? || !$rh_still || $rh_still[0] != [px, py] || Graphics.frame_count - $rh_still[1] < 8
      return nil if !busy || best[0] > 60
      return [path[best[1]..-1], label]     # mid-step: keep the line, no fake shortcut
    end
    j = best[1]
    tx, ty = path[j]
    link = []
    cx, cy = px, py
    while cx != tx
      cx += (tx <=> cx)
      link << [cx, cy]
    end
    while cy != ty
      cy += (ty <=> cy)
      link << [cx, cy]
    end
    link.pop if link.last == [tx, ty]
    return [[[px, py]] + link + path[j..-1], label]
  end

  def self.nav_start(dest)
    g[:nav] = dest
    $rh_nav_cache = nil
  end

  def self.nav_stop
    g[:nav] = nil
    $rh_nav_cache = nil
  end

  # smart plan first (real map data), then the simple map graph as a backup
  def self.route_to(targets, spot = nil)
    sure_no = true     # every search finished and found no way at all
    [false, true, :people].each do |relax|
      pl = (plan(targets, spot, relax) rescue nil)
      sure_no = false if pl.nil?
      next if !pl
      path = tile_path(pl[1])
      path = model_path(pl[1]) if path.empty?   # someone's standing in the way right now - still show the line
      next if path.empty?
      lbl = { :dive => "dark water - Dive (A)", :surface => "surface here (A)",
              :lever => "#{mapname(pl[0])} - use the elevator panel / switch first" }[pl[2]] || mapname(pl[0])
      lbl += " (push the boulders)" if relax == true
      lbl += " (walk around / talk to people in the way)" if relax == :people
      return [path, lbl]
    end
    # the game often has several copies of one place (before / after a story event):
    # if this copy can't be reached, head for a copy of it that can
    if !targets.any? { |t| twin_of?(t) }
      names = targets.map { |t| mapname(t) }.uniq
      twins = all_map_ids.find_all { |i| !targets.include?(i) && names.include?(mapname(i)) }
      return [[], "you're in the right area"] if twins.include?($game_map.map_id)
      if !twins.empty?
        $rh_twin_try = true
        begin
          res = route_to(twins)
        ensure
          $rh_twin_try = false
        end
        return res if res && !res[0].empty? && res[1] !~ /\Atowards /
      end
    end
    # double-check once with everything rebuilt fresh before ever saying "no way"
    if sure_no && !$rh_retry
      $rh_retry = true
      begin
        $rh_route_db = nil
        $rh_fail = {}
        $rh_quick = {}
        $rh_evpos = nil
        again = route_to(targets, spot)
      ensure
        $rh_retry = false
      end
      return again
    end
    # the full search looked everywhere: don't send you wandering, say so (and the goal gets re-picked)
    return [[], "no way to #{mapname(targets.first)} from here yet - the story goes on somewhere else first"] if sure_no
    bounced = ($rh_hist || []).tally.select { |m, n| n >= 2 }.keys
    hop = next_hop($game_map.map_id, targets)
    hop = nil if hop && (bounced.include?(hop) || (($rh_hist || [])[-3] == hop && ($rh_hist || [])[-2] == $game_map.map_id))
    if hop
      path = tile_path(goal_tiles(hop))
      return [path, mapname(hop)] if !path.empty?
    end
    # never leave you without a line: walk to the exit of this area that leads closest to the goal
    begin
      md = model($game_map.map_id)
      f = m_flood(md, $game_player.x, $game_player.y)
      dist = static_dist(targets)
      exits = m_exits(md, f).reject { |e| (e[0] == $game_map.map_id && !targets.include?(e[0])) }
      recent = ($rh_hist || [])[0..-2]
      # never ping-pong: places you were just in go last, places you keep bouncing between are dropped
      exits = exits.reject { |e| bounced.include?(e[0]) && e[0] != $game_map.map_id }
      exits = exits.sort_by { |e| [recent.include?(e[0]) ? 1 : 0, dist[e[0]] || 99, e[0] == $rh_came_from ? 1 : 0] }
      exits.first(6).each do |e|
        path = tile_path(e[3])
        path = model_path(e[3]) if path.empty?
        return [path, "towards #{mapname(targets.first)} via #{mapname(e[0])}"] if !path.empty?
      end
    rescue
    end
    return [[], "no way to #{mapname(targets.first)} from here yet - the story goes on somewhere else first"]
  end

  def self.twin_of?(id)
    $rh_twin_try
  end

  def self.all_map_ids
    @all_maps ||= begin
      ($cache.mapinfos || load_data("Data/MapInfos.rxdata")).keys rescue warps.keys
    end
  end

  # what the line should lead to right now: [cache key, story record or nil]
  def self.nav_want
    fc = Graphics.frame_count
    k = [$game_map.map_id, g && g[:nav]]
    return $rh_want[2] if $rh_want && $rh_want[0] == k && fc - $rh_want[1] < 15
    $rh_want = [k, fc, nav_want_now]
    return $rh_want[2]
  end

  def self.nav_want_now
    d = g
    target = d[:nav]
    here = $game_map.map_id
    if target == :story
      r = (live_step rescue nil) || story_step
      rs = (rule_step rescue nil)
      r = rs if rs
      u = (update_obj rescue nil)
      r = { :map => u[:map], :id => 0, :x => u[:x], :y => u[:y], :to => u[:val] } if u && u[:map] > 0
      return [nil, nil] if !r
      # a person who walks around keeps the same goal (don't re-plan every time they take a step)
      spot = r[:id].to_i > 0 ? [r[:id]] : [r[:id], r[:x], r[:y]]
      return [[here, :story, r[:map], r[:to]] + spot, r]
    end
    tl = target.is_a?(Array) ? target : [target]
    return [[here, tl], nil]
  end

  # returns [path, label]
  def self.nav_path
    d = g
    return nil if !d || !d[:nav] || !$game_map
    target = d[:nav]
    here = $game_map.map_id
    if target != :story && (target.is_a?(Array) ? target.include?(here) : target == here)
      d[:nav] = nil
      return nil
    end
    key, r = nav_want
    return nil if !key
    return [[], "follow the goal above"] if r && r[:map].to_i <= 0
    pos = [$game_player.x, $game_player.y]
    $rh_still = [pos, Graphics.frame_count] if $rh_still.nil? || $rh_still[0] != pos
    if $rh_nav_cache && $rh_nav_cache[0] == key
      c = $rh_nav_cache[1]
      f = (c[0].empty? && $rh_nav_cache[2] == pos) ? c : follow(c[0], c[1])
      return f if f                                 # on (or near) the line: no search needed
      # lost the line: keep showing it until you stand still, then plan again
      return c if $game_player.moving? || (Graphics.frame_count - $rh_still[1]) < 8 || (Graphics.frame_count - ($rh_nav_time || -999)) < 20
    elsif $rh_nav_cache && $rh_nav_cache[0][0] == here && $game_player.moving? && (Graphics.frame_count - ($rh_nav_time || -999)) < 40
      # the goal just changed mid-step: finish the step on the old line, re-plan right after
      c = $rh_nav_cache[1]
      f = follow(c[0], c[1])
      return f if f
    end
    $rh_nav_time = Graphics.frame_count
    # the search runs a little each frame in the background, so the game never freezes
    job = $rh_job
    if !job || job[:key] != key || job[:map] != here
      job = $rh_job = { :key => key, :map => here, :fiber => Fiber.new { nav_compute(key, r, here) } }
    end
    $rh_slice = Time.now
    $rh_in_fiber = true
    begin
      res = job[:fiber].resume
    rescue => e
      $rh_job = nil
      raise e
    ensure
      $rh_in_fiber = false
    end
    if job[:fiber].alive?
      # still working it out: keep showing the old line (if it's for this place) meanwhile
      if $rh_nav_cache && $rh_nav_cache[0][0] == here
        c = $rh_nav_cache[1]
        return follow(c[0], c[1]) || c
      end
      return [[], "finding the way..."]
    end
    $rh_job = nil
    $rh_nav_cache = [key, res, pos]
    return res
  end

  def self.nav_compute(key, r, here)
    # another copy of this same place (the game swaps copies after story events): treat it as here
    twin = r && r[:map] != here && mapname(r[:map]) == mapname(here) && (model(r[:map]) rescue nil) &&
           model(r[:map])[:w] == $game_map.width && model(r[:map])[:h] == $game_map.height
    if twin
      # the game swaps copies of this place (e.g. water drained / filled): go to the real copy if you can,
      # otherwise the same spot here
      res = route_to([r[:map]], spot_tiles(r))
      return res if !res[0].empty? || !res[1].to_s.start_with?("no way")
      r = r.merge(:map => here)
    end
    if r
      if r[:map] == here && r[:id].to_i == 0 && r[:x].to_i == 0
        res = [[], "you're in the right area"]
      elsif r[:map] == here
        gt = story_goal_tiles(r)
        res = [tile_path(gt), "story spot"]
        res = [model_path(gt), "story spot"] if res[0].empty?
        if res[0].empty?   # can't walk there inside this map - go out and use another door
          res = route_to([here], spot_tiles(r))
          res = [res[0], res[1] + " (the way around)"]
        end
      else
        res = route_to([r[:map]], spot_tiles(r))
      end
      if res[0].empty? && res[1].to_s.start_with?("no way")
        # this story step can't be reached yet: remember that, so the next real step gets picked
        ($rh_unreach ||= {})[[r[:map], r[:x], r[:y], route_db[:sig]]] = true
        $rh_live = nil
        $rh_obj = nil
        $rh_want = nil
      end
    else
      res = route_to(key[1])
    end
    return res
  end

  # inside the background search: hand control back to the game every ~12ms
  def self.slice!
    return if !$rh_in_fiber
    return if Time.now - $rh_slice < 0.012
    rl = @rh_relax
    ro = @rh_ov
    @rh_ov = nil
    tb = $rh_tp_bike
    $PokemonGlobal.bicycle = true if tb      # never leave you off your bike while the search pauses
    $rh_in_fiber = false
    Fiber.yield(:pending)
    $rh_in_fiber = true
    if tb
      if ($PokemonGlobal.bicycle rescue false)
        $PokemonGlobal.bicycle = false
      else
        $rh_tp_bike = false
      end
    end
    $rh_slice = Time.now
    @rh_relax = rl
    @rh_ov = ro
  end
end

#==============================================================================
# Dialogue capture (for the mission log)
#==============================================================================
class << Kernel
  alias rh_pbMessage pbMessage unless method_defined?(:rh_pbMessage)
  def pbMessage(message, *args, **kw, &block)
    begin
      RH.capture(message)
    rescue
    end
    return rh_pbMessage(message, *args, **kw, &block)
  end
end

#==============================================================================
# Smart route planner: reads the real map files + your switches, so it knows
# which part of a map you land in and which exits you can actually walk to.
#==============================================================================
module RH
  MAX_FLOODS = 1500

  # cleared whenever the story moves on (switches change what is open)
  def self.route_db
    sig = [STORY_VARS.map { |v| ($game_variables[v] rescue 0) }, ($Trainer.numbadges rescue 0), can_surf?, can_dive?, can_smash?, can_cut?, can_strength?, can_rockclimb?, can_waterfall?, $rh_world_sig]
    if !$rh_route_db || $rh_route_db[:sig] != sig
      $rh_route_db = { :sig => sig, :models => {}, :plans => {} }
    end
    return $rh_route_db
  end

  # values the search is pretending are set (after flipping a switch / pressing a machine on the way)
  def self.gv(i)
    return @rh_ov[[:v, i]] if @rh_ov && @rh_ov.key?([:v, i])
    ($game_variables[i] rescue 0).to_i
  end

  def self.gs(i)
    return @rh_ov[[:s, i]] if @rh_ov && @rh_ov.key?([:s, i])
    ($game_switches[i] rescue false) ? true : false
  end

  # which values / switches the events of one map look at (so pictures are only redone when they matter)
  def self.map_refs(id)
    $rh_refs ||= {}
    return $rh_refs[id] if $rh_refs[id]
    refs = {}
    m = ($cache.map_load(id) rescue nil)
    (m ? m.events : {}).each_value do |ev|
      ev.pages.each do |pg|
        c = pg.condition
        refs[[:s, c.switch1_id]] = true if c.switch1_valid
        refs[[:s, c.switch2_id]] = true if c.switch2_valid
        refs[[:v, c.variable_id]] = true if c.variable_valid
        (pg.list || []).each do |q|
          next if q.code != 111
          refs[[:s, q.parameters[1]]] = true if q.parameters[0] == 0
          refs[[:v, q.parameters[1]]] = true if q.parameters[0] == 1
        end
      end
    end
    $rh_refs[id] = refs
  end

  def self.active_page(map_id, ev)
    ev.pages.reverse_each do |pg|
      c = pg.condition
      next if c.switch1_valid && !gs(c.switch1_id)
      next if c.switch2_valid && !gs(c.switch2_id)
      next if c.variable_valid && gv(c.variable_id) < c.variable_value
      next if c.self_switch_valid && !($game_self_switches[[map_id, ev.id, c.self_switch_ch]] rescue false)
      return pg
    end
    return nil
  end

  # static picture of one map: tiles, blocking events, warps (with landing spot)
  def self.can_strength?
    hm_ok?(:STRENGTH, (BADGEFORSTRENGTH rescue 5))
  end

  def self.boulder?(list)
    s = ""
    (list || []).each { |c| s << c.parameters.last.to_s << ";" if [355, 655, 111].include?(c.code) }
    return s =~ /pbPushThisBoulder|pbPushThisEvent/ ? true : false
  rescue
    return false
  end

  # blockers on one event spot -> :tile id, :boulder, :block or nil
  # spots that make you jump when you walk into them: { direction you face => [dx, dy] }
  def self.jump_spec(list)
    return nil if !list
    $rh_jspec ||= {}.compare_by_identity
    return $rh_jspec[list] if $rh_jspec.key?(list)
    spec = {}
    facing = {}
    list.each do |q|
      if q.code == 111 && q.parameters[0] == 6 && q.parameters[1] == -1
        facing[q.indent] = q.parameters[2]
      elsif q.code == 209 && q.parameters[0] == -1
        dir = nil
        facing.each { |ind, dd| dir = dd if ind < q.indent }
        (q.parameters[1].list rescue []).each do |mc|
          next if mc.code != 14
          spec[dir || :any] = [mc.parameters[0], mc.parameters[1]]
        end
      end
    end
    $rh_jspec[list] = spec.empty? ? nil : spec
  end

  def self.sort_blocker(md, x, y, through, tile_id, charname, list, name = "", moves = true)
    if (js = jump_spec(list)) && !through
      md[:jumps][[x, y]] = js      # not a wall: bumping into it jumps you over
      return
    end
    if climb_wall?(name, list)
      md[:block][[x, y]] = true
      return
    end
    return if through
    if tile_id.to_i > 0
      md[:evtile][[x, y]] = tile_id
    elsif charname.to_s != "" && !clearable?(list)
      # last try: only people who actually walk around get ignored - rocks, signs, guards and objects stay solid
      return if @rh_relax == :people && moves
      if boulder?(list) && (can_strength? || @rh_relax)   # relaxed search: assume boulders can be moved
        md[:boulder][[x, y]] = true
      else
        md[:block][[x, y]] = true
      end
    end
  end

  # static picture of one map: tiles, blocking events, warps (with landing spot).
  # For the map you are on, blockers come from the LIVE events (moved boulders, NPCs that walked away).
  def self.model(id)
    db = route_db
    ovk = nil
    if @rh_ov && !@rh_ov.empty?
      refs = map_refs(id)
      ovk = @rh_ov.select { |k, _| refs[k] }.sort_by { |k, _| k.to_s }
      ovk = nil if ovk.empty?
    end
    key = [id, @rh_relax, ovk]
    return db[:models][key] if db[:models].key?(key)
    slice!
    return db[:models][key] if db[:models].key?(key)
    db[:models][key] = nil
    m = ($cache.map_load(id) rescue nil)
    return nil if !m
    ts = ($cache.RXtilesets[m.tileset_id] rescue nil)
    return nil if !ts
    md = { :id => id, :w => m.width, :h => m.height, :data => m.data, :pas => ts.passages, :pri => ts.priorities,
           :tt => ts.terrain_tags, :evtile => {}, :block => {}, :boulder => {}, :warps => [], :floods => [], :jumps => {} }
    live = (id == ($game_map.map_id rescue nil)) && ($game_map.events rescue nil)
    # variables you can change yourself on this map (elevator panels, levers...): var => [values]
    settable = {}
    (m.events || {}).each do |eid, ev|
      pg = active_page(id, ev)
      next if !pg || pg.trigger != 0
      (pg.list || []).each do |c|
        next if c.code != 122 || c.parameters[3] != 0 || c.parameters[2] != 0 || c.parameters[0] != c.parameters[1]
        next if STORY_VARS.include?(c.parameters[0])
        (settable[c.parameters[0]] ||= []) << c.parameters[4]
      end
    end
    (m.events || {}).each do |eid, ev|
      # doors that open once you flip something on this map (e.g. pick the floor in an elevator)
      ev.pages.each do |op|
        next if op.equal?(active_page(id, ev))
        c = op.condition
        next if !c.variable_valid || !settable[c.variable_id]
        next if !settable[c.variable_id].any? { |v| v >= c.variable_value }
        next if c.switch1_valid && !gs(c.switch1_id)
        next if c.switch2_valid && !gs(c.switch2_id)
        next if c.self_switch_valid && !($game_self_switches[[id, ev.id, c.self_switch_ch]] rescue false)
        next if op.trigger == 3 || op.trigger == 4
        (op.list || []).each do |cmd|
          if cmd.code == 201 && cmd.parameters[0] == 0
            md[:warps] << [ev.x, ev.y, cmd.parameters[1], cmd.parameters[2], cmd.parameters[3], :lever]
            break
          end
        end
      end
    end
    # cutscenes that move you somewhere by themselves:
    #  - ones that start the moment you arrive (the way in sets a value / switch first)
    #  - ones that start after you step on / talk to something on this map
    tv, tsw = transit_vars(id)
    msv = {}   # values events on this map can set: var => [[value, x, y]]
    mss = {}   # switches events on this map turn on: switch => [[x, y]]
    (m.events || {}).each do |eid, ev|
      ev.pages.each do |pg|
        next if pg.trigger > 2
        (pg.list || []).each do |q|
          pr = q.parameters
          if q.code == 122 && pr[0] == pr[1] && pr[2] == 0 && pr[3] == 0
            (msv[pr[0]] ||= []) << [pr[4], ev.x, ev.y]
          elsif q.code == 121 && pr[0] == pr[1] && pr[2] == 0
            (mss[pr[0]] ||= []) << [ev.x, ev.y]
          end
        end
      end
    end
    (m.events || {}).each do |eid, ev|
      next if !ev.pages.any? { |op| (op.trigger == 3 || op.trigger == 4) && (op.list || []).any? { |q| q.code == 201 } }
      tries = []
      if id != ($game_map.map_id rescue nil)    # you're already here: "on arrival" scenes have had their chance
        tries << [nil]
        tv.each { |v, vals| vals.each { |x| tries << [:var, v, x, nil] } }
        tsw.each_key { |sw| tries << [:sw, sw, true, nil] }
      end
      ev.pages.each do |op|
        c = op.condition
        (msv[c.variable_id] || []).each { |val, sx, sy| tries << [:var, c.variable_id, val, [sx, sy]] } if c.variable_valid
        [c.switch1_valid ? c.switch1_id : nil, c.switch2_valid ? c.switch2_id : nil].compact.each do |sw|
          (mss[sw] || []).each { |sx, sy| tries << [:sw, sw, true, [sx, sy]] }
        end
      end
      tries.uniq.first(40).each do |kind, tid, tval, at|
        ev.pages.reverse_each do |op|
          c = op.condition
          s1 = c.switch1_valid && !(kind == :sw && tid == c.switch1_id) && !gs(c.switch1_id)
          s2 = c.switch2_valid && !(kind == :sw && tid == c.switch2_id) && !gs(c.switch2_id)
          next if s1 || s2
          next if c.self_switch_valid && !($game_self_switches[[id, ev.id, c.self_switch_ch]] rescue false)
          if c.variable_valid
            cur = (kind == :var && c.variable_id == tid) ? tval : gv(c.variable_id)
            next if cur < c.variable_value
          end
          # this is the page that will be live
          if op.trigger == 3 || op.trigger == 4
            cmd = live_transfer(op.list, id, ev.id, kind == :var ? [tid, tval] : nil)
            if cmd && cmd.parameters[1] != id
              w = at ? [at[0], at[1], cmd.parameters[1], cmd.parameters[2], cmd.parameters[3]] :
                       [ev.x, ev.y, cmd.parameters[1], cmd.parameters[2], cmd.parameters[3], :auto]
              md[:warps] << w if !md[:warps].include?(w)
            end
          end
          break
        end
      end
    end
    (m.events || {}).each do |eid, ev|
      pg = active_page(id, ev)
      next if !pg
      if !live
        gfx = pg.graphic
        sort_blocker(md, ev.x, ev.y, pg.through, gfx.tile_id, gfx.character_name, pg.list, ev.name, pg.move_type != 0)
      end
      next if pg.trigger == 3 || pg.trigger == 4
      # every destination this event can send you to (trains / boats / menus have several)
      tr, eff = live_effects(pg.list, id, ev.id)
      eff = nil if eff.empty?
      tr.each do |cmd|
        md[:warps] << [ev.x, ev.y, cmd.parameters[1], cmd.parameters[2], cmd.parameters[3], nil, eff]
      end
      (pg.list || []).each do |cmd|
        if cmd.code == 117
          common_warps(cmd.parameters[0]).each { |to, x2, y2| md[:warps] << [ev.x, ev.y, to, x2, y2] }
        end
      end
    end
    if live
      $game_map.events.each_value do |ev|
        mv = ((ev.instance_variable_get(:@move_type) || 0) != 0) rescue false
        sort_blocker(md, ev.x, ev.y, ev.through, ev.tile_id, ev.character_name, (ev.list rescue nil), (ev.name rescue ""), mv) rescue nil
      end
    end
    ($rh_blocked || {}).each_key { |(mid, t)| md[:block][t] = true if mid == id }   # learned walls (this visit only)
    db[:models][key] = md
    return md
  end

  # values that get set on the way INTO a map (by the event that sends you there): var => value
  def self.transit_vars(id)
    $rh_transit ||= begin
      t = {}
      RH_TRANSIT_DATA.split(";").each do |e|
        mid, rest = e.split(":")
        vs = {}
        sws = {}
        (rest || "").split(" ").each do |k|
          if k =~ /\Av(\d+)=(-?\d+)\z/
            next if STORY_VARS.include?($1.to_i)
            ((vs[$1.to_i] ||= []) << $2.to_i).uniq!
          elsif k =~ /\As(\d+)\z/
            sws[$1.to_i] = true
          end
        end
        t[mid.to_i] = [vs, sws]
      end
      t
    end
    return $rh_transit[id] || [{}, {}]
  end

  # the first "move the player" command a scene really reaches right now
  # (follows its if/else branches using the current switches and values; unknown checks count as "no")
  def self.live_transfer(list, map_id, ev_id, override = nil)
    skip = nil       # skipping commands deeper than this indent
    taken = {}
    (list || []).each do |q|
      ind = q.indent
      if skip
        next if ind > skip
        if ind == skip
          if q.code == 411 && !taken[ind]      # the "if" part was skipped: run the else part
            skip = nil
          elsif q.code == 412
            skip = nil
          end
          next
        end
        skip = nil
      end
      case q.code
      when 111
        taken[ind] = branch_true?(q.parameters, map_id, ev_id, override)
        skip = ind if !taken[ind]
      when 411
        skip = ind if taken[ind]                # "if" part ran: skip the else part
      when 201
        return q if q.parameters[0] == 0
      when 115
        return nil
      end
    end
    return nil
  end

  # every "move the player" command this event can really reach right now
  # (if/else follow the current switches and values; menu choices are all possible)
  def self.live_transfers(list, map_id, ev_id, unknown = true)
    return live_effects(list, map_id, ev_id, unknown)[0]
  end

  # [moves this event really reaches now, values / switches it sets on the way]
  def self.live_effects(list, map_id, ev_id, unknown = true)
    out = []
    eff = {}
    skip = nil
    taken = {}
    (list || []).each do |q|
      ind = q.indent
      if skip
        next if ind > skip
        if ind == skip
          if q.code == 411 && !taken[ind]
            skip = nil
          elsif q.code == 412
            skip = nil
          end
          next
        end
        skip = nil
      end
      pr = q.parameters
      case q.code
      when 111
        b = branch_true?(pr, map_id, ev_id, nil, unknown)
        taken[ind] = b
        skip = ind if !b
      when 411
        skip = ind if taken[ind]
      when 201
        out << q if pr[0] == 0
      when 122
        eff[[:v, pr[0]]] = pr[4] if pr[0] == pr[1] && pr[2] == 0 && pr[3] == 0 && route_var?(pr[0])
      when 121
        eff[[:s, pr[0]]] = (pr[2] == 0) if pr[0] == pr[1] && route_sw?(pr[0])
      end
    end
    return [out, eff]
  end

  # only values that decide which page an event is on matter for finding a way
  def self.route_var?(v)
    load_routevars
    @route_vars.empty? || @route_vars[v]
  end

  def self.route_sw?(sw)
    load_routevars
    @route_sws.empty? || @route_sws[sw]
  end

  def self.load_routevars
    return if @route_vars
    vs, ss = (defined?(RH_ROUTEVAR_DATA) ? RH_ROUTEVAR_DATA : "|").split("|")
    @route_vars = {}
    @route_sws = {}
    (vs || "").split(",").each { |x| @route_vars[x.to_i] = true }
    (ss || "").split(",").each { |x| @route_sws[x.to_i] = true }
  end

  def self.branch_true?(pr, map_id, ev_id, override, unknown = false)
    case pr[0]
    when 0    # switch
      gs(pr[1]) == (pr[2] == 0)
    when 1    # variable compare
      v = (override && override[0] == pr[1]) ? override[1] : gv(pr[1])
      o = pr[2] == 0 ? pr[3] : gv(pr[3])
      case pr[4]
      when 0 then v == o
      when 1 then v >= o
      when 2 then v <= o
      when 3 then v > o
      when 4 then v < o
      when 5 then v != o
      else false
      end
    when 2    # self switch
      ($game_self_switches[[map_id, ev_id, pr[1]]] rescue false) == (pr[2] == 0)
    when 6    # which way someone faces: you can always turn
      true
    else
      unknown
    end
  rescue
    false
  end

  # common events that move you (an event can call one)
  def self.common_warps(ce_id)
    $rh_cew ||= {}
    return $rh_cew[ce_id] if $rh_cew.key?(ce_id)
    ces = ($data_common_events || ($cache.RXevents rescue nil) || (load_data("Data/CommonEvents.rxdata") rescue nil)) rescue nil
    ce = (ces[ce_id] rescue nil)
    $rh_cew[ce_id] = ce ? (ce.list || []).find_all { |q| q.code == 201 && q.parameters[0] == 0 }.map { |q| q.parameters[1..3] } : []
    return $rh_cew[ce_id]
  rescue
    return []
  end

  # where the live events stand on this map (if this changes, re-plan)
  def self.live_sig
    ($game_map.events || {}).values.map { |e| [e.x, e.y, e.character_name.to_s.length, e.through ? 1 : 0] }.hash
  rescue
    0
  end

  # same rules as Game_Map#passable? for the player (walking)
  def self.m_pass(md, x, y, d)
    return false if x < 0 || y < 0 || x >= md[:w] || y >= md[:h]
    bit = (1 << (d / 2 - 1)) & 0x0f
    pas = md[:pas]
    pri = md[:pri]
    t = md[:evtile][[x, y]]
    if t
      return false if pas[t] & bit != 0
      return false if pas[t] & 0x0f == 0x0f
      return true if pri[t] == 0
    end
    data = md[:data]
    [2, 1, 0].each do |i|
      tid = data[x, y, i]
      return false if tid.nil?
      return true if @rh_surf && (pbIsPassableWaterTag?(md[:tt][tid]) rescue false)
      return true if @rh_surf && md[:tt][tid] == (PBTerrain::Waterfall rescue 8) && can_waterfall?
      return false if pas[tid] & bit != 0
      return false if pas[tid] & 0x0f == 0x0f
      return true if pri[tid] == 0
    end
    return true
  end

  def self.m_tag(md, x, y)
    data = md[:data]
    [2, 1, 0].each do |i|
      tid = data[x, y, i]
      next if !tid
      tg = md[:tt][tid]
      return tg if tg && tg != 0
    end
    return 0
  end

  def self.m_ledge?(md, x, y)
    data = md[:data]
    [2, 1, 0].each do |i|
      tid = data[x, y, i]
      next if !tid
      tg = md[:tt][tid]
      next if !tg || tg == 0
      return tg == (PBTerrain::Ledge rescue 1)
    end
    return false
  end

  def self.m_step(md, x, y, d, dx, dy)
    nx = x + dx
    ny = y + dy
    return nil if nx < 0 || ny < 0 || nx >= md[:w] || ny >= md[:h]
    if (js = md[:jumps] && md[:jumps][[nx, ny]]) && (jd = js[d] || js[:any])
      lx = x + jd[0]
      ly = y + jd[1]
      return nil if lx < 0 || ly < 0 || lx >= md[:w] || ly >= md[:h] || md[:block][[lx, ly]]
      return nil if !m_pass(md, lx, ly, 10 - d) && !m_pass(md, lx, ly, d)
      return [lx, ly]
    end
    return nil if !m_pass(md, x, y, d) || !m_pass(md, nx, ny, 10 - d) || md[:block][[nx, ny]]
    if md[:boulder][[nx, ny]]   # Strength boulder: only if it can be pushed one tile further
      bx = nx + dx
      by = ny + dy
      return nil if bx < 0 || by < 0 || bx >= md[:w] || by >= md[:h]
      return nil if md[:block][[bx, by]] || md[:boulder][[bx, by]] || !m_pass(md, bx, by, 10 - d)
    end
    if m_tag(md, nx, ny) == (PBTerrain::Ice rescue 12)   # ice: slide until stopped
      cx, cy = nx, ny
      loop do
        break if m_tag(md, cx, cy) != (PBTerrain::Ice rescue 12)
        tx = cx + dx
        ty = cy + dy
        break if tx < 0 || ty < 0 || tx >= md[:w] || ty >= md[:h]
        break if !m_pass(md, cx, cy, d) || !m_pass(md, tx, ty, 10 - d) || md[:block][[tx, ty]]
        cx, cy = tx, ty
      end
      return [cx, cy]
    end
    if m_ledge?(md, nx, ny)
      lx = nx + dx
      ly = ny + dy
      return nil if lx < 0 || ly < 0 || lx >= md[:w] || ly >= md[:h] || md[:block][[lx, ly]]
      return m_pass(md, lx, ly, 10 - d) ? [lx, ly] : nil
    end
    return [nx, ny]
  end

  # everything you can walk to from (sx, sy) on this map -> { tiles, exits }
  def self.m_flood(md, sx, sy)
    md[:floods].each { |f| return f if f[:tiles][[sx, sy]] }
    @rh_surf = can_surf?
    seen = { [sx, sy] => true }
    q = [[sx, sy]]
    dirs = [[2, 0, 1], [4, -1, 0], [6, 1, 0], [8, 0, -1]]
    until q.empty?
      cx, cy = q.shift
      dirs.each do |d, dx, dy|
        n = m_step(md, cx, cy, d, dx, dy)
        next if !n || seen[n]
        seen[n] = true
        q << n
      end
      break if seen.size > 25000
      slice! if (seen.size & 1023) == 0
    end
    f = { :tiles => seen, :id => md[:floods].length }
    md[:floods] << f
    return f
  end

  # a walkable line using the map itself (people ignored) - used when live walking finds nothing
  def self.model_path(goals, md = nil)
    md ||= model($game_map.map_id)
    return [] if !md || goals.nil? || goals.empty?
    @rh_surf = can_surf?
    sx, sy = $game_player.x, $game_player.y
    gs = {}
    goals.each { |x, y| gs[[x, y]] = true }
    near = lambda { |x, y| gs[[x, y]] || gs[[x + 1, y]] || gs[[x - 1, y]] || gs[[x, y + 1]] || gs[[x, y - 1]] }
    prev = { [sx, sy] => nil }
    q = [[sx, sy]]
    hit = nil
    dirs = [[2, 0, 1], [4, -1, 0], [6, 1, 0], [8, 0, -1]]
    until q.empty?
      c = q.shift
      if near.call(c[0], c[1])
        hit = c
        break
      end
      dirs.each do |d, dx, dy|
        n = m_step(md, c[0], c[1], d, dx, dy)
        next if !n || prev.key?(n)
        prev[n] = c
        q << n
      end
      slice! if (prev.size & 511) == 0
      break if prev.size > 20000
    end
    return [] if !hit
    path = []
    c = hit
    while c
      path.unshift(c)
      c = prev[c]
    end
    g0 = goals.find { |x, y| [x, y] == hit } || goals.find { |x, y| (x - hit[0]).abs + (y - hit[1]).abs == 1 }
    path << g0 if g0 && g0 != hit
    return fill_path(path)
  rescue
    return []
  end

  def self.touch?(tiles, x, y)
    tiles[[x, y]] || tiles[[x + 1, y]] || tiles[[x - 1, y]] || tiles[[x, y + 1]] || tiles[[x, y - 1]]
  end

  # exits from one walkable area: [[dest map, dest x, dest y, [tiles to walk to here]], ...]
  def self.m_exits(md, f)
    return f[:exits] if f[:exits]
    out = []
    md[:warps].each do |x, y, to, tx, ty, lv, eff|
      if lv == :auto      # happens by itself as soon as you arrive
        out << [to, tx, ty, [f[:tiles].keys.first], :walk, eff]
        next
      end
      out << [to, tx, ty, [[x, y]], lv ? :lever : :walk, eff] if touch?(f[:tiles], x, y)
    end
    w = md[:w]
    h = md[:h]
    connections(md[:id]).each do |to, ax, ay, bx, by|
      om = ($cache.map_load(to) rescue nil)
      next if !om
      groups = {}
      f[:tiles].each_key do |x, y|
        [[x == 0, -1, 0], [x == w - 1, 1, 0], [y == 0, 0, -1], [y == h - 1, 0, 1]].each do |edge, dx, dy|
          next if !edge
          ox = x + dx - ax + bx
          oy = y + dy - ay + by
          next if ox < 0 || oy < 0 || ox >= om.width || oy >= om.height   # this edge doesn't join that map here
          (groups[[ox, oy]] ||= []) << [x, y]
        end
      end
      groups.each { |(ox, oy), tl| out << [to, ox, oy, tl, :walk] }
    end
    # Dive down (dark deep water) / surface (light patch above)
    if can_dive?
      meta = ($cache.mapdata[md[:id]] rescue nil)
      dmap = (meta.DiveMap rescue nil)
      smap = (meta.SurfaceMap rescue nil)
      out += dive_exits(md, f, dmap, :dive) if dmap
      out += dive_exits(md, f, smap, :surface) if smap
    end
    f[:exits] = out
    return out
  end

  def self.can_dive?
    hm_ok?(:DIVE, (BADGEFORDIVE rescue 11), :GOLDENSCUBAGEAR, :HM06)
  end

  def self.deep?(md, x, y)
    data = md[:data]
    [2, 1, 0].each do |i|
      tid = data[x, y, i]
      next if !tid
      tg = md[:tt][tid]
      next if !tg || tg == 0
      return tg == (PBTerrain::DeepWater rescue 5)
    end
    return false
  end

  # dive: stand on deep water here -> same x,y on the map below
  # surface: deep water on the map above at your x,y -> same x,y up there
  def self.dive_exits(md, f, other, kind)
    om = model(other)
    return [] if !om
    groups = {}
    f[:tiles].each_key do |x, y|
      next if x >= om[:w] || y >= om[:h]
      ok = (kind == :dive) ? deep?(md, x, y) : deep?(om, x, y)
      next if !ok
      lf = om[:floods].find { |q| q[:tiles][[x, y]] }
      if !lf
        next if groups.length >= 30
        lf = m_flood(om, x, y)
      end
      (groups[lf[:id]] ||= [x, y, []])[2] << [x, y]
    end
    return groups.values.map { |x, y, tl| [other, x, y, tl, kind] }
  end

  # static map-to-map distance (cheap guide for the search)
  def self.static_dist(targets)
    db = route_db
    db[:dist] ||= {}
    return db[:dist][targets] if db[:dist][targets]
    db[:dist][targets] = static_dist_now(targets)
  end

  def self.static_dist_now(targets)
    dist = {}
    targets.each { |t| dist[t] = 0 }
    rev = {}
    warps.each_key do |a|
      neighbors(a).each { |b| (rev[b] ||= []) << a }
      slice!
    end
    q = targets.dup
    until q.empty?
      c = q.shift
      (rev[c] || []).each do |a|
        next if dist.key?(a)
        dist[a] = dist[c] + 1
        q << a
      end
    end
    return dist
  end

  # returns [first map to go to, tiles on this map to walk to] or nil
  def self.plan(targets, spot = nil, relax = false)
    @rh_relax = relax
    return nil if !$game_map || !$game_player
    here = $game_map.map_id
    db = route_db
    ls = live_sig
    if db[:live] != [here, ls]       # things moved on this map: rebuild its picture
      db[:live] = [here, ls]
      db[:models].delete([here, false])
      db[:models].delete([here, true])
      db[:models].delete([here, :people])
      db[:plans] = {}
    end
    # keep hold of every area picture this search uses, so things changing while it runs
    # in the background (people walking, values updating) can't mix two different pictures
    mods = {}
    get = lambda { |i|
      refs = map_refs(i)
      k = [i, (@rh_ov || {}).select { |kk, _| refs[kk] }]
      mods.key?(k) ? mods[k] : (mods[k] = model(i))
    }
    @rh_ov = {}
    md = get.call(here)
    return nil if !md
    start = m_flood(md, $game_player.x, $game_player.y)
    key = [here, start[:id], targets, spot, relax]
    return db[:plans][key] if db[:plans].key?(key)
    # a search that found nothing isn't repeated for a while (people walking around don't change the answer)
    fk = [here, start[:id], targets, relax, db[:sig]]
    $rh_fail ||= {}
    $rh_quick ||= {}
    return $rh_fail[fk][1] if $rh_fail[fk] && Graphics.frame_count - $rh_fail[fk][0] < 900
    return nil if !$rh_in_fiber && $rh_quick[fk] && Graphics.frame_count - $rh_quick[fk] < 900   # quick check already ran out of time
    dist = static_dist(targets)
    st0 = [here, start[:id], {}]
    prev = { st0 => nil }
    first = {}
    open = [[dist[here] || 99, 0, st0]]
    floods = 0
    found = nil
    t0 = Time.now
    until open.empty?
      slice!
      # in the background search there's time to look everywhere; quick checks elsewhere stay quick
      if Time.now - t0 > ($rh_in_fiber ? 20.0 : 0.15)
        floods = MAX_FLOODS + 1
        break
      end
      open.sort_by! { |a| [a[0] + a[1], a[1]] }
      _, g0, cur = open.shift
      cm, cf, cov = cur
      @rh_ov = cov
      cmd = get.call(cm)
      next if !cmd
      f = cmd[:floods][cf]
      next if !f
      m_exits(cmd, f).each do |to, tx, ty, tiles, kind, eff|
        nov = cov
        if eff
          # only remember changes that differ from how things really are now
          nov = cov.merge(eff).reject { |k, v| (k[0] == :v ? ($game_variables[k[1]] rescue 0).to_i : (($game_switches[k[1]] rescue false) ? true : false)) == v }
        end
        nov = cov if nov.size > 24          # keep the what-ifs small
        @rh_ov = nov
        if targets.include?(to)
          ok = true
          if spot
            dm = get.call(to)
            ok = false
            if dm && tx >= 0 && ty >= 0 && tx < dm[:w] && ty < dm[:h]
              lf = m_flood(dm, tx, ty)
              ok = spot.any? { |x, y| touch?(lf[:tiles], x, y) }
            end
          end
          if ok
            found = [cur, to, tiles, kind]
            break
          end
        end
        dm = get.call(to)
        next if !dm
        next if tx < 0 || ty < 0 || tx >= dm[:w] || ty >= dm[:h]
        nf = dm[:floods].find { |x| x[:tiles][[tx, ty]] }
        if !nf
          floods += 1
          next if floods > MAX_FLOODS
          nf = m_flood(dm, tx, ty)
        end
        st = [to, nf[:id], nov]
        next if prev.key?(st)
        prev[st] = cur
        first[st] = (cur == st0) ? [to, tiles, kind] : first[cur]
        open << [dist[to] || (kind == :walk ? 8 : 1), g0 + 1, st]
      end
      break if found || floods > MAX_FLOODS
    end
    res = (floods > MAX_FLOODS) ? nil : false   # false = searched everything, no walkable way
    if found
      cur, to, tiles, kind = found
      res = (cur == st0) ? [to, tiles, kind] : first[cur]
      chain = [to]
      c = cur
      while c
        chain.unshift(c[0])
        c = prev[c]
      end
      $rh_plan_chain = chain.chunk_while { |a, b| a == b }.map(&:first)
    end
    $rh_search_info = "from #{here} (#{$game_player.x},#{$game_player.y}) area #{start[:tiles].size} tiles, looked at #{prev.size} spots in #{prev.keys.map(&:first).uniq.size} places, relax #{relax.inspect}, result #{res.nil? ? 'unfinished' : res ? 'found' : 'none'}"
    db[:plans][key] = res if !res.nil?
    $rh_fail[fk] = [Graphics.frame_count, res] if res == false
    $rh_quick[fk] = Graphics.frame_count if res.nil? && !$rh_in_fiber
    return res
  rescue => e
    $rh_plan_err = "#{e.class}: #{e.message} @ #{(e.backtrace || []).first.to_s[-60, 60]}"
    return nil
  ensure
    @rh_relax = false
    @rh_ov = nil
  end
end

#==============================================================================
# Live story finder: looks at the REAL event pages (your switches, self switches,
# variables) to find what can move the story forward right now.
#==============================================================================
module RH
  def self.var_maps(var)
    if !$rh_varmaps
      $rh_varmaps = {}
      RH_VARMAP_DATA.split(";").each do |e|
        v, m = e.split(",").map(&:to_i)
        ($rh_varmaps[v] ||= []) << m
      end
    end
    return $rh_varmaps[var] || []
  end

  def self.speaker_of(list)
    (list || []).each do |c|
      if c.code == 101 && c.parameters[0].is_a?(String) && c.parameters[0] =~ /^\s*([A-Z][A-Z .'\-&]{1,20}):/
        return $1.strip.split(" ").map(&:capitalize).join(" ")
      end
    end
    return nil
  end

  # events whose CURRENT page would move story variable `var` past `cur`
  def self.live_cands(var, cur)
    here = ($game_map.map_id rescue 0)
    out = []
    var_maps(var).each do |mid|
      m = ($cache.map_load(mid) rescue nil)
      next if !m
      (m.events || {}).each do |eid, ev|
        if mid == here && $game_map.events && $game_map.events[eid]
          ge = $game_map.events[eid]
          list = (ge.list rescue nil)
          trig = (ge.trigger rescue 0)
          cond = (ge.instance_variable_get(:@page).condition rescue nil)
          ex = ge.x
          ey = ge.y
        else
          pg = active_page(mid, ev)
          next if !pg
          list = pg.list
          trig = pg.trigger
          cond = pg.condition
          ex = ev.x
          ey = ev.y
        end
        next if !list || trig == 4
        best = nil
        add = false
        list.each_with_index do |c, ci|
          next if c.code != 122 || c.parameters[0] != var || c.parameters[3] != 0
          next if !branch_ok?(list, ci)
          if c.parameters[2] == 0 && c.parameters[4] > cur
            best = [best || 0, c.parameters[4]].max
          elsif c.parameters[2] == 1 && c.parameters[4] > 0
            add = true
          end
        end
        next if !best && !add
        cv = (cond && cond.variable_valid && cond.variable_id == var) ? cond.variable_value : nil
        # how specific is this page to where you are in the story? (switch conditions = route-specific scenes)
        spec = 0
        if cond
          spec += 2 if cv
          spec += 3 if cond.switch1_valid
          spec += 3 if cond.switch2_valid
        end
        btl = nil
        list.each do |c|
          next if ![355, 655, 111].include?(c.code)
          t = c.parameters.last.to_s
          if t =~ /TrainerBattle\(\s*:(\w+)\s*,\s*"([^"]+)"/
            nm = $2
            sym = $1.to_sym
            cls = ($cache.trainertypes[sym].name rescue nil) || ($cache.trainertypes[sym][:name] rescue nil) || sym.to_s.split("_").map(&:capitalize).join(" ")
            btl = "#{cls} #{nm}"
            break
          elsif t =~ /pbWildBattle\(\s*:(\w+)/
            btl = $1.capitalize
            break
          end
        end
        out << { :map => mid, :id => eid, :x => ex, :y => ey, :trig => trig, :sp => speaker_of(list).to_s, :battle => btl,
                 :to => best || cur + 1, :add => add && !best, :v => var, :cv => cv, :spec => spec }
      end
    end
    return out
  end

  # is command `ci` inside "if" blocks that are false right now? (checks switch / variable branches)
  def self.branch_ok?(list, ci)
    ind = list[ci].indent
    i = ci - 1
    while i >= 0 && ind > 0
      c = list[i]
      if c.indent < ind
        if c.code == 111
          p = c.parameters
          ok = true
          if p[0] == 0                              # switch
            ok = (($game_switches[p[1]] rescue false) ? 0 : 1) == p[2]
          elsif p[0] == 1 && p[2] == 0              # variable vs constant
            a = ($game_variables[p[1]] rescue 0).to_i
            b = p[3].to_i
            ok = case p[4] when 0 then a == b when 1 then a >= b when 2 then a <= b when 3 then a > b when 4 then a < b else a != b end
          end
          return false if !ok
        elsif c.code == 411                         # "else": its "if" must have been false - skip, too complex
          return true
        end
        ind = c.indent
      end
      i -= 1
    end
    return true
  rescue
    return true
  end

  def self.live_step
    k = [STORY_VARS.map { |v| ($game_variables[v] rescue 0) }, ($game_map.map_id rescue 0), ($game_self_switches.instance_variable_get(:@data).length rescue 0)]
    busy = (pbMapInterpreterRunning? rescue false)
    if $rh_live && ($rh_live[0] == k || busy)   # during a cutscene keep the old answer, re-check after it ends
      r = $rh_live[1]
    else
      r = live_step_now
      $rh_live = [k, r]
    end
    # people move during scenes: always use where the event stands right now
    if r && r[:map] == ($game_map.map_id rescue -1) && (ge = ($game_map.events[r[:id]] rescue nil))
      r[:x] = ge.x
      r[:y] = ge.y
    end
    return r
  end

  def self.live_step_now
    vals = STORY_VARS.map { |v| ($game_variables[v] rescue 0).to_i }
    last = nil
    vals.each_with_index { |val, i| last = i if val > 0 }
    idxs = last ? [last, last + 1] : [0]
    here = ($game_map.map_id rescue 0)
    px = ($game_player.x rescue 0)
    py = ($game_player.y rescue 0)
    idxs.each do |i|
      next if i >= STORY_VARS.length
      cs = live_cands(STORY_VARS[i], vals[i])
      next if cs.empty?
      # 1) steps unlocked by reaching this exact point in the story, 2) other story steps, 3) "ask around" counters
      # ...and only ones you can actually get to right now
      # most story-specific scenes first (route switches + exact story point), then smallest step, "ask around" last
      real = cs.find_all { |c| !c[:add] }
      adds = cs.find_all { |c| c[:add] }
      groups = []
      # pages with no conditions at all are often leftovers - try them after "ask around"
      real.find_all { |c| c[:spec] > 0 }.group_by { |c| [-c[:spec], c[:to]] }.sort.each { |_, gp| groups << gp }
      groups << adds if !adds.empty?
      real.find_all { |c| c[:spec] == 0 }.group_by { |c| c[:to] }.sort.each { |_, gp| groups << gp }
      pickg = groups.first(6).map { |gp| gp.find_all { |c| reachable_spot?(c) } }.find { |gp| !gp.empty? }
      cs = pickg || groups.first
      mine = cs.find_all { |c| c[:map] == here }
      cs = mine if !mine.empty?
      r = cs.min_by { |c| (c[:map] == here ? 0 : 1000) + (c[:x] - px).abs + (c[:y] - py).abs }
      r[:count] = cs.length
      return r
    end
    return nil
  end

  def self.reachable_spot?(c)
    return false if ($rh_unreach || {})[[c[:map], c[:x], c[:y], route_db[:sig]]]
    spot = [[c[:x], c[:y]], [c[:x], c[:y] + 1], [c[:x] - 1, c[:y]], [c[:x] + 1, c[:y]], [c[:x], c[:y] - 1],
            [c[:x], c[:y] + 2], [c[:x] - 2, c[:y]], [c[:x] + 2, c[:y]], [c[:x], c[:y] - 2]]
    here = $game_map.map_id
    if c[:map] == here
      md = model(here)
      return true if !md
      f = m_flood(md, $game_player.x, $game_player.y)
      return true if spot.any? { |x, y| touch?(f[:tiles], x, y) }
    end
    [false, true, :people].each do |relax|
      pl = (plan([c[:map]], spot, relax) rescue nil)
      return true if pl.nil? || pl   # nil = search too big to tell, give it the benefit of the doubt
    end
    return false
  end

  # rough compass direction + distance from you (same map) or which part of the map (other map)
  def self.where_text(r)
    if r[:map] == ($game_map.map_id rescue 0)
      dx = r[:x] - $game_player.x
      dy = r[:y] - $game_player.y
      return "right here" if dx.abs + dy.abs <= 1
      return "right next to you" if dx.abs <= 2 && dy.abs <= 2
      ns = dy < -2 ? "north" : dy > 2 ? "south" : ""
      ew = dx < -2 ? "west" : dx > 2 ? "east" : ""
      return "#{ns}#{ew}".sub("northwest", "north-west").sub("northeast", "north-east").sub("southwest", "south-west").sub("southeast", "south-east") + " of you, ~#{dx.abs + dy.abs} steps"
    end
    md = (model(r[:map]) rescue nil)
    return "" if !md || md[:w] < 30
    ns = r[:y] < md[:h] / 3 ? "north" : r[:y] > md[:h] * 2 / 3 ? "south" : ""
    ew = r[:x] < md[:w] / 3 ? "west" : r[:x] > md[:w] * 2 / 3 ? "east" : ""
    part = ns + (ns != "" && ew != "" ? "-" : "") + ew
    return part.empty? ? "middle of the map" : "#{part} side"
  end

  def self.live_text(r)
    place = mapname(r[:map])
    place = "this area" if r[:map] == ($game_map.map_id rescue -1)
    where = (where_text(r) rescue "")
    wh = where.empty? ? "" : " (#{where})"
    if r[:add]
      return "Ask around #{place}: talk to the people the route points to#{r[:count] > 1 ? " (#{r[:count]} to check)" : ""}."
    end
    who = r[:sp].to_s.strip
    t = case r[:trig]
        when 0 then who.empty? ? "Check the marked spot in #{place}#{wh} (press A)." : "Talk to #{who} in #{place}#{wh}."
        when 1, 2 then "Walk onto the marked spot in #{place}#{wh}" + (who.empty? ? "." : " - #{who} is there.")
        else "Go to the marked spot in #{place}#{wh} - a scene starts" + (who.empty? ? "." : " (#{who}).")
        end
    t += " Battle ahead: #{r[:battle]} - heal first." if r[:battle]
    return t
  end
end

#==============================================================================
# Battle panel
#==============================================================================
module RH
  # damage of one move -> [min, max] HP, using the game's own damage calc
  def self.dmg(battle, attacker, opponent, move)
    return [0, 0] if !move || move.basedamage.to_i <= 0
    return [0, 0] if opponent.hp <= 0 || attacker.hp <= 0
    ai = battle.ai
    raw = nil
    if ai
      saved = [ai.mondata, ai.attacker, ai.opponent, ai.move]
      begin
        md = AI_MonData.new(nil, attacker.index, battle)
        md.skill = 100
        ai.mondata = md
        ai.attacker = attacker
        ai.opponent = opponent
        ai.move = move
        raw = ai.pbRoughDamage(move, attacker, opponent)
      rescue
        raw = nil
      ensure
        ai.mondata, ai.attacker, ai.opponent, ai.move = saved
      end
    end
    raw = simple_dmg(attacker, opponent, move) if raw.nil?
    raw = raw.to_i
    return [0, 0] if raw <= 0
    if opponent.index.even? # foe hitting you: game already applied the low roll
      return [raw, (raw / 0.85).round]
    else
      return [(raw * 0.85).floor, raw]
    end
  end

  def self.simple_dmg(a, o, m)
    phys = (m.category == :physical)
    atk = phys ? a.attack : a.spatk
    dfn = phys ? o.defense : o.spdef
    base = (((2.0 * a.level / 5 + 2) * m.basedamage * atk / [dfn, 1].max) / 50 + 2)
    base *= 1.5 if a.hasType?(m.type)
    eff = 1.0
    [o.type1, o.type2].uniq.compact.each { |t| eff *= PBTypes.oneTypeEff(m.type, t) / 2.0 rescue nil }
    return (base * eff).floor
  end

  def self.faster?(a, b, battle)
    sa = (a.pbSpeed rescue 0)
    sb = (b.pbSpeed rescue 0)
    tr = (battle.trickroom != 0 rescue false)
    return tr ? sa < sb : sa > sb
  end

  def self.foes(battle)
    live = [3, 1].map { |i| battle.battlers[i] }.compact.find_all { |b| b.hp > 0 && !b.isFainted? }   # screen order: left, right
    return live if !live.empty?
    return [@incoming] if @incoming && @incoming.hp > 0   # foe that is about to be sent in
    return []
  end

  def self.incoming
    @incoming
  end

  def self.incoming=(v)
    @incoming = v
  end

  def self.best_heal(mon)
    missing = mon.totalhp - mon.hp
    return nil if missing <= 0 || !$PokemonBag
    have = HEAL_ITEMS.keys.find_all { |k| ($PokemonBag.pbQuantity(k) rescue 0) > 0 }
    return nil if have.empty?
    fit = have.find_all { |k| HEAL_ITEMS[k] >= missing }.min_by { |k| HEAL_ITEMS[k] }
    fit ||= have.max_by { |k| HEAL_ITEMS[k] }
    return fit
  end

  def self.type_mult(atype, types)
    m = 1.0
    types.uniq.compact.each { |t| m *= (PBTypes.oneTypeEff(atype, t) / 2.0 rescue 1.0) }
    return m
  end

  def self.best_switch(battle, active, foe)
    party = $Trainer.party rescue []
    foe_types = foe.moves.find_all { |m| m && m.basedamage.to_i > 0 }.map { |m| m.type }
    best = nil
    party.each do |p|
      next if !p || p.isEgg? || p.hp <= 0
      next if battle.battlers.any? { |b| b && b.pokemon == p }
      types = [p.type1, p.type2]
      worst_in = foe_types.map { |t| type_mult(t, types) }.max || 1.0
      best_out = 0.0
      p.moves.each do |pm|
        next if !pm || !pm.move
        md = $cache.moves[pm.move] rescue nil
        next if !md || md.basedamage.to_i <= 0
        stab = (types.include?(md.type) ? 1.5 : 1.0)
        best_out = [best_out, type_mult(md.type, [foe.type1, foe.type2]) * stab].max
      end
      score = best_out - worst_in * 1.2 + p.hp.to_f / p.totalhp
      best = [score, p] if !best || score > best[0]
    end
    return best ? best[1] : nil
  end

  # rank your benched Pokemon against the foes on the field (real damage calc)
  # Rank your benched Pokemon vs the foes on the field, using CURRENT HP.
  # free = true when your Pokemon fainted (the switch-in doesn't get hit first).
  def self.rank_switches(battle, idx, free = false)
    fs = foes(battle)
    return [] if fs.empty? || !battle.ai
    party = (battle.pbParty(idx) rescue $Trainer.party)
    out = []
    party.each_with_index do |p, pi|
      next if !p || p.isEgg? || p.hp <= 0
      next if battle.battlers.any? { |b| b && b.pokemon.equal?(p) && b.hp > 0 }
      fake = (battle.ai.pbMakeFakeBattler(p, pi, false, idx) rescue nil)
      next if !fake
      out << rate(battle, fake, p, fs, free)
    end
    return out.sort_by { |o| -o[:score] }
  end

  # how one of your Pokemon (real or fake battler) does against the given foes, using current HP
  def self.rate(battle, fake, p, fs, free)
    kos = 0
    bestdeal = 0
    fs.each do |f|
      fbest = 0
      fko = false
      fake.moves.each do |m|
        next if !m || !m.move || m.pp <= 0
        lo, hi = dmg(battle, fake, f, m)
        fko = true if lo >= f.hp
        fbest = [fbest, pct(lo, f.hp)].max
      end
      kos += 1 if fko
      bestdeal = [bestdeal, [fbest, 100].min].max
    end
    worst = 0
    fs.each do |f|
      f.moves.each do |m|
        next if !m || !m.move
        lo, hi = dmg(battle, f, fake, m)
        worst = [worst, hi].max
      end
    end
    first = fs.all? { |f| faster?(fake, f, battle) }
    hits = free ? 1 : 2              # a normal switch takes a hit on the way in
    faints = worst * hits >= fake.hp
    faints = false if free && first && kos >= fs.length
    take = pct(worst, fake.hp)
    score = 0
    score += 1000 if !faints
    score += 300 * kos
    score += 150 if first
    score += bestdeal
    score -= [take, 100].min
    if faints
      word = "faints"
    elsif kos > 0 && first
      word = "KOs first"
    elsif kos > 0
      word = "survives, KOs"
    elsif take <= 33
      word = "safe"
    else
      word = "survives"
    end
    return { :mon => p, :faints => faints, :kos => kos, :first => first, :take => take, :score => score, :word => word,
             :hp => pct(fake.hp, fake.totalhp) }
  end

  # "X is about to send in Y. Will you change Pokemon?" - stay or switch?
  def self.draw_shift(bmp, battle)
    bmp.clear
    f = @incoming
    a = battle.battlers[0]
    return if !f || !a || a.hp <= 0 || !battle.ai
    stay = rate(battle, a, a.pokemon, [f], true)
    list = rank_switches(battle, 0, true)
    font(bmp)
    lines = [["Next: #{f.name} Lv#{f.level}", "", ACCENT]]
    lines << ["Stay: #{a.name} #{stay[:hp]}%", stay[:word], stay[:faints] ? BAD : TXT]
    list.first(3).each do |o|
      lines << ["#{o[:mon].name} #{o[:hp]}%", o[:word], o[:faints] ? BAD : TXT]
    end
    best = list.first
    if best && !best[:faints] && best[:score] > stay[:score] + 50
      lines << ["DO: Yes - switch to #{best[:mon].name}", "", GOOD]
    elsif stay[:faints] && best && best[:score] > stay[:score]
      lines << ["DO: Yes - switch to #{best[:mon].name}", "", GOOD]
    else
      lines << ["DO: No - keep #{a.name} in", "", GOOD]
    end
    draw_lines(bmp, lines, 184)
  end

  def self.draw_switch(bmp, battle, idx, free = false)
    bmp.clear
    list = rank_switches(battle, idx, free)
    return if list.empty?
    font(bmp)
    lines = [["Best switch-in", "", ACCENT]]
    list.first(5).each_with_index do |o, i|
      col = o[:faints] ? BAD : (i == 0 ? GOOD : TXT)
      lines << [(i == 0 && !o[:faints] ? "> " : "") + "#{o[:mon].name} #{o[:hp]}%", o[:word], col]
    end
    lines << ["Everyone is at risk", "", WARN] if list.all? { |o| o[:faints] }
    draw_lines(bmp, lines, 168)
  end

  def self.draw_lines(bmp, lines, w)
    # long advice lines (no value on the right) wrap instead of being cut off
    out = []
    lines.each do |l, r, c|
      if r.to_s.empty? && bmp.text_size(l.to_s).width > w - 12
        wrap(bmp, l.to_s, w - 12).first(3).each { |x| out << [x, "", c] }
      else
        out << [l, r, c]
      end
    end
    lines = out
    x0 = W - w - 2
    h = lines.length * RH.lh + 6
    bmp.fill_rect(x0, 2, w, h, BG)
    bmp.fill_rect(x0, 2, 1, h, ACCENT)
    y = 5
    lines.each do |l, r, c|
      rw = r.to_s.empty? ? 0 : bmp.text_size(r).width + 6
      text(bmp, x0 + 6, y, w - 10 - rw, cut(bmp, l, w - 12 - rw), c)
      text(bmp, x0 + 4, y, w - 9, r, c, 2) if rw > 0
      y += RH.lh
    end
  end

  # analysis for one of your battlers
  def self.analyze(battle, idx)
    me = battle.battlers[idx]
    return nil if !me || me.hp <= 0
    fs = foes(battle)
    return nil if fs.empty?
    rows = []
    best = nil
    perfoe = {}
    me.moves.each do |m|
      next if !m || !m.move
      row = { :name => mname(m.move), :pp => m.pp, :vs => [], :acc => (m.accuracy rescue 0) }
      ally = (me.pbPartner rescue nil)
      tgt = ($cache.moves[m.move].target rescue nil)
      if battle.doublebattle && ally && ally.hp > 0 && tgt == :AllNonUsers
        alo, ahi = dmg(battle, me, ally, m)
        row[:ally] = [ally, alo, ahi] if ahi > 0
      end
      fs.each do |f|
        lo, hi = dmg(battle, me, f, m)
        row[:vs] << [f, lo, hi]
        next if hi <= 0 || m.pp <= 0
        ko = lo >= f.hp ? 2 : (hi >= f.hp ? 1 : 0)
        acc = (m.accuracy rescue 100).to_i
        acc = 100 if acc <= 0
        val = ko * 1000 * acc / 100.0 + [lo, f.hp].min * 100.0 / f.totalhp * acc / 100.0
        if row[:ally]
          al, alo, ahi = row[:ally]
          val -= ahi >= al.hp ? 5000 : ahi * 150.0 / al.totalhp
        end
        best = [val, row, f, lo, hi, ko] if !best || val > best[0]
        perfoe[f] = [val, row, lo, hi, ko] if !perfoe[f] || val > perfoe[f][0]
      end
      rows << row
    end
    danger = nil
    fs.each do |f|
      f.moves.each do |m|
        next if !m || !m.move
        lo, hi = dmg(battle, f, me, m)
        danger = [hi, lo, f, m] if hi > 0 && (!danger || hi > danger[0])
      end
    end
    return { :me => me, :foes => fs, :rows => rows, :best => best, :danger => danger, :perfoe => perfoe }
  end

  RECOIL = { :BRAVEBIRD => 3, :FLAREBLITZ => 3, :WOODHAMMER => 3, :DOUBLEEDGE => 3, :VOLTTACKLE => 3,
             :HEADSMASH => 2, :WILDCHARGE => 4, :TAKEDOWN => 4, :SUBMISSION => 4, :HEADCHARGE => 4, :LIGHTOFRUIN => 2 }

  def self.special_move?(user, m)
    return (m.pbIsSpecial?(user, m.type) rescue (($cache.moves[m.move].category == :special) rescue false))
  end

  def self.side_fx(battle, idx, key)
    (battle.sides[idx & 1].effects[key] rescue 0).to_i
  end

  # strategy layer: screens, free switches (immunities), sacrificing for a safe switch-in, recoil
  def self.strategy(battle, a)
    me = a[:me]
    best = a[:best]
    dg = a[:danger]
    return nil if !dg
    hit, hitlo, foe, fmove = dg
    dies = hit >= me.hp
    foe_first = !faster?(me, foe, battle)
    big = hit >= me.totalhp * 0.45
    ko_now = best && best[5] == 2
    return nil if ko_now && (!dies || !foe_first)
    # 1) screens: halve their big hits for 5 turns (only if you survive setting it)
    if hitlo < me.hp && big && !(best && best[4] >= foe.hp)   # you usually live through one hit
      spc = special_move?(foe, fmove)
      want = spc ? [:LIGHTSCREEN, :AURORAVEIL] : [:REFLECT, :AURORAVEIL]
      key = spc ? :LightScreen : :Reflect
      if side_fx(battle, me.index, key) == 0 && side_fx(battle, me.index, :AuroraVeil) == 0
        sm = me.moves.find { |m| m && m.move && want.include?(m.move) && m.pp > 0 }
        return ["Set #{mname(sm.move)} - halves #{short(foe.name)}'s #{spc ? 'special' : 'physical'} hits for 5 turns", GOOD] if sm
      end
    end
    # 2) a teammate is immune to the move they're about to use -> free switch
    if (dies || big)
      bench = (rank_switches(battle, me.index, false) rescue [])
      bench.each do |o|
        fake = (battle.ai.pbMakeFakeBattler(o[:mon], $Trainer.party.index(o[:mon]), false, me.index) rescue nil)
        next if !fake
        flo, fhi = dmg(battle, foe, fake, fmove)
        next if fhi > 0 || o[:faints]
        return ["Switch to #{o[:mon].name} - immune to #{mname(fmove.move)} (free switch)", GOOD]
      end
    end
    # 3) you go down this turn no matter what: hit first if you can, then the next one comes in for free
    if dies && foe_first
      safe = (rank_switches(battle, me.index, false) rescue []).find { |o| !o[:faints] }
      if !safe
        nxt = (rank_switches(battle, me.index, true) rescue []).first
        if nxt && best
          return ["Attack: #{best[1][:name]} - if you faint, send #{nxt[:mon].name} in free (no hit taken)", WARN]
        end
      end
    end
    # 4) recoil would knock you out
    if best && (div = RECOIL[(me.moves.find { |m| m && mname(m.move) == best[1][:name] }.move rescue nil)])
      rec = [best[3], best[2].hp].min / div
      return ["Attack: #{best[1][:name]} (recoil ~#{rec} will KO you - make it count)", WARN] if rec >= me.hp && !ko_now
    end
    return nil
  end

  # One clear decision, based on everyone's CURRENT HP and speed.
  def self.advice(battle, a)
    st = (strategy(battle, a) rescue nil)
    return st if st
    me = a[:me]
    best = a[:best]
    dg = a[:danger]
    dies = dg && dg[0] >= me.hp
    foe_first = dg && !faster?(me, dg[2], battle)
    if best && best[5] == 2 && (!dies || !foe_first)
      return ["Attack: #{best[1][:name]} (KOs #{short(best[2].name)})", GOOD]
    end
    if dies && foe_first
      sw = (rank_switches(battle, me.index).find { |o| !o[:faints] } rescue nil)
      return ["Switch to #{sw[:mon].name}", WARN] if sw
      heal = best_heal(me)
      if heal && [me.hp + HEAL_ITEMS[heal], me.totalhp].min > dg[0]
        return ["Heal: #{iname(heal)}", WARN]
      end
      return ["Attack: #{best[1][:name]} (you may faint)", BAD] if best
      return ["You will likely faint", BAD]
    end
    return ["Attack now: #{best[1][:name]} (you're faster)", WARN] if dies && best
    return ["Attack: #{best[1][:name]}", GOOD] if best
    return ["No good move - switch", WARN]
  end

  def self.hp_after(f, hi)
    left = [f.hp - hi, 0].max
    return pct(left, f.totalhp)
  end

  def self.short(n, len = 8)
    n = n.to_s
    return n.length > len ? n[0, len - 1] + "." : n
  end

  # damage as % of the target's CURRENT HP
  def self.dtag(f, lo, hi)
    return "-" if hi <= 0
    return "KO" if lo >= f.hp
    return "KO?" if hi >= f.hp
    return "#{pct(lo, f.hp)}-#{pct(hi, f.hp)}%"
  end

  # small panel: every line is [left, right, color]
  def self.draw_battle(bmp, battle, idx, full)
    bmp.clear
    a = analyze(battle, idx)
    return if !a
    font(bmp)
    me = a[:me]
    dbl = a[:foes].length > 1
    lines = []
    if full
      # Fight screen: each move vs each foe (KO / % of their current HP)
      a[:rows].each do |r|
        segs = r[:vs].map { |f, lo, hi| dtag(f, lo, hi) }
        best = a[:best] && a[:best][1].equal?(r)
        col = best ? GOOD : (r[:pp] <= 0 ? DIM : TXT)
        lines << [(best ? "> " : "") + r[:name], segs.join("  "), col]
        if r[:ally]
          al, alo, ahi = r[:ally]
          lines << ["  also hits #{short(al.name)}", ahi >= al.hp ? "KOs ally" : "#{pct(ahi, al.hp)}%", ahi >= al.hp ? BAD : WARN]
        end
      end
      lines << ["", a[:foes].map { |f| short(f.name, 7) }.join("  "), DIM] if dbl
      if a[:danger]
        hi, lo, f, m = a[:danger]
        lines << ["Their best: " + mname(m.move), hi >= me.hp ? "KOs you" : "#{pct(hi, me.hp)}%", hi >= me.hp ? BAD : (hi * 2 >= me.hp ? WARN : DIM)]
      end
    else
      # Command screen: what to do, everyone's HP, who is faster
      adv = advice(battle, a)
      lines << [adv[0], "", adv[1]]
      hp = "You #{pct(me.hp, me.totalhp)}%"
      a[:foes].each { |f| hp += "   #{short(f.name, 7)} #{pct(f.hp, f.totalhp)}%" }
      lines << [hp, "", TXT]
      if a[:danger]
        hi, lo, f, m = a[:danger]
        who = faster?(me, f, battle) ? "You're faster." : "#{short(f.name, 7)} is faster."
        if hi >= me.hp
          lines << ["#{who} It can KO you", "", BAD]
        else
          lines << ["#{who} Max hit #{pct(hi, me.hp)}% of HP", "", hi * 2 >= me.hp ? WARN : DIM]
        end
      end
    end
    draw_lines(bmp, lines, full ? (dbl ? 172 : 156) : 184)
  end
end

class PokeBattle_Battle
  [:pbDisplay, :pbDisplayPaused, :pbDisplayBrief].each do |mt|
    next if !method_defined?(mt)
    al = "rh_#{mt}".to_sym
    next if method_defined?(al)
    alias_method al, mt
    define_method(mt) do |msg, *args|
      begin
        s = RH.clean(msg)
        RH.log << s if s.length > 0
        RH.log.shift while RH.log.length > 6
      rescue
      end
      send(al, msg, *args)
    end
  end

  # remember which foe is coming in next (for the "Will you change Pokemon?" prompt)
  alias rh_pbSwitchInBetween pbSwitchInBetween unless method_defined?(:rh_pbSwitchInBetween)
  def pbSwitchInBetween(index, lax, cancancel)
    ret = rh_pbSwitchInBetween(index, lax, cancancel)
    begin
      if ret.is_a?(Integer) && ret >= 0 && @opponent && pbIsOpposing?(index)
        RH.incoming = self.ai.pbMakeFakeBattler(pbParty(index)[ret], ret, false, index)
      end
    rescue
      RH.incoming = nil
    end
    return ret
  end

  alias rh_pbRecallAndReplace pbRecallAndReplace unless method_defined?(:rh_pbRecallAndReplace)
  def pbRecallAndReplace(index, newpoke, *rest)
    RH.incoming = nil if (pbIsOpposing?(index) rescue false)
    return rh_pbRecallAndReplace(index, newpoke, *rest)
  end
end

class PokeBattle_Scene
  def rh_panel
    if !@rh_sprite || @rh_sprite.disposed?
      @rh_vp = Viewport.new(0, 0, RH::W, RH::H)
      @rh_vp.z = 100_000
      @rh_sprite = Sprite.new(@rh_vp)
      @rh_sprite.bitmap = Bitmap.new(RH::W, RH::H)
    end
    return @rh_sprite
  end

  def rh_show(index, full)
    @rh_idx = index
    @rh_full = full
    return if !RH.g || !RH.g[:battle]
    begin
      s = rh_panel
      RH.draw_battle(s.bitmap, @battle, index, full)
      s.visible = true
    rescue
    end
  end

  def rh_hide
    @rh_sprite.visible = false if @rh_sprite && !@rh_sprite.disposed?
  end

  alias rh_pbStartBattle pbStartBattle unless method_defined?(:rh_pbStartBattle)
  def pbStartBattle(battle)
    $rh_battle_log = []
    RH.incoming = nil
    $rh_battle_chat = false
    RH.hud_hide rescue nil
    rh_pbStartBattle(battle)
  end

  alias rh_pbEndBattle pbEndBattle unless method_defined?(:rh_pbEndBattle)
  def pbEndBattle(result)
    RH.incoming = nil
    begin
      if @rh_sprite && !@rh_sprite.disposed?
        @rh_sprite.bitmap.dispose
        @rh_sprite.dispose
        @rh_vp.dispose
      end
    rescue
    end
    rh_pbEndBattle(result)
  end

  alias rh_pbCommandMenu pbCommandMenu unless method_defined?(:rh_pbCommandMenu)
  def pbCommandMenu(index)
    rh_show(index, false)
    ret = rh_pbCommandMenu(index)
    rh_hide
    return ret
  end

  alias rh_pbSwitch pbSwitch unless method_defined?(:rh_pbSwitch)
  def pbSwitch(index, lax, cancancel)
    begin
      if RH.g && RH.g[:battle]
        s = rh_panel
        s.viewport.z = 100_005
        free = (@battle.battlers[index].hp <= 0 rescue false) || !RH.incoming.nil?
        RH.draw_switch(s.bitmap, @battle, index, free)
        s.visible = true
      end
    rescue
    end
    ret = rh_pbSwitch(index, lax, cancancel)
    rh_hide
    return ret
  end

  alias rh_pbDisplayConfirmMessage pbDisplayConfirmMessage unless method_defined?(:rh_pbDisplayConfirmMessage)
  def pbDisplayConfirmMessage(msg)
    shown = false
    begin
      if RH.g && RH.g[:battle] && RH.incoming && msg.to_s =~ /change Pok/
        s = rh_panel
        s.viewport.z = 100_005
        RH.draw_shift(s.bitmap, @battle)
        s.visible = true
        shown = true
      end
    rescue
    end
    ret = rh_pbDisplayConfirmMessage(msg)
    rh_hide if shown
    return ret
  end

  alias rh_pbFightMenu pbFightMenu unless method_defined?(:rh_pbFightMenu)
  def pbFightMenu(index)
    rh_show(index, true)
    ret = rh_pbFightMenu(index)
    rh_hide
    return ret
  end
end

#==============================================================================
# Upcoming trainers + lead advice, icons
#==============================================================================
module RH
  TRAINER_RX = /pb(?:Double)?TrainerBattle(?:100)?\(\s*:(\w+)\s*,\s*"([^"]+)"(?:\s*,[^,]*,\s*(?:true|false)\s*,\s*(\d+))?/

  def self.map_trainers
    key = [$game_map.map_id, ($game_self_switches.instance_variable_get(:@data).size rescue 0)]
    return $rh_trainers[1] if $rh_trainers && $rh_trainers[0] == key
    found = []
    $game_map.events.each do |id, ev|
      next if ($game_self_switches[[$game_map.map_id, id, "A"]] rescue false)
      (ev.event.pages rescue []).each do |pg|
        txt = ""
        pg.list.each { |c| txt << c.parameters[0].to_s << "\n" if [355, 655, 111].include?(c.code) }
        txt.scan(TRAINER_RX) do |type, name, pid|
          found << [type.to_sym, name, pid.to_i, ev.x, ev.y]
        end
      end
    end
    found.uniq! { |t| t[0, 3] }
    res = []
    found.first(6).each do |type, name, pid, x, y|
      begin
        next if !findParty(type, name, pid)
        data = pbLoadTrainer(type, name, pid)
        next if !data
        res << { :name => name, :type => type, :party => data[2], :x => x, :y => y }
      rescue
      end
    end
    $rh_trainers = [key, res]
    return res
  end

  # simple matchup score of one of your Pokemon against a whole enemy team
  def self.lead_score(p, team)
    types = [p.type1, p.type2]
    score = 0.0
    team.each do |e|
      et = [e.type1, e.type2]
      off = 0.0
      p.moves.each do |m|
        next if !m || !m.move
        md = ($cache.moves[m.move] rescue nil)
        next if !md || md.basedamage.to_i <= 0
        stab = types.include?(md.type) ? 1.5 : 1.0
        off = [off, type_mult(md.type, et) * stab].max
      end
      dfn = 0.0
      e.moves.each do |m|
        next if !m || !m.move
        md = ($cache.moves[m.move] rescue nil)
        next if !md || md.basedamage.to_i <= 0
        dfn = [dfn, type_mult(md.type, types)].max
      end
      score += off - dfn
    end
    score += 0.3 if p.speed > (team.first.speed rescue 0)
    return score
  end

  def self.lead_advice(team)
    mine = $Trainer.party.find_all { |p| p && !p.isEgg? && p.hp > 0 }
    return [] if mine.empty? || team.empty?
    ranked = mine.sort_by { |p| -lead_score(p, team) }
    first = team.first
    vs_first = mine.max_by { |p| lead_score(p, [first]) }
    return [ranked.first(2), vs_first]
  end

  def self.icon(path)
    $rh_icons ||= {}
    return $rh_icons[path] if $rh_icons.key?(path)
    b = (Bitmap.new(path) rescue nil)
    $rh_icons[path] = b
    return b
  end

  def self.draw_mon_icon(bmp, p, x, y, size = 24)
    f = (pbPokemonIconFile(p) rescue nil)
    return if !f
    b = icon(f)
    return if !b
    fw = b.height
    bmp.stretch_blt(Rect.new(x, y, size, size), b, Rect.new(0, 0, fw, b.height))
  end

  def self.draw_item_icon(bmp, item, x, y, size = 16)
    f = (pbItemIconFile(item) rescue nil)
    return if !f
    b = icon(f)
    return if !b
    bmp.stretch_blt(Rect.new(x, y, size, size), b, Rect.new(0, 0, b.width, b.height))
  end
end

#==============================================================================
# Pre-battle coach: right before a trainer fight, tell you who to lead with
# (and offer to move it to the front). If you lose, it remembers and changes
# the plan next time.
#==============================================================================
module RH
  def self.battle_key(type, name, pid)
    "#{type}|#{name}|#{pid}"
  end

  def self.coach_rank(team, lost)
    mine = $Trainer.party.find_all { |p| p && !p.isEgg? && p.hp > 0 }
    mine.sort_by do |p|
      s = lead_score(p, team)
      s -= 3.0 * lost.count(p.species)            # led and lost before -> try someone else
      s += 0.2 * (p.hp.to_f / [p.totalhp, 1].max)
      -s
    end
  end

  def self.prebattle(type, name, pid)
    d = g
    return if !d || d[:battle] == false
    data = (pbLoadTrainer(type, name, pid) rescue nil)
    return if !data || !data[2] || data[2].empty?
    team = data[2]
    key = battle_key(type, name, pid)
    lost = ((d[:losses] ||= {})[key] ||= [])
    ranked = coach_rank(team, lost)
    best = ranked.first
    return if !best
    $rh_last_fight = [key, nil]
    foes = team.map { |p| (p.name rescue p.species.to_s) }.uniq.first(3).join(", ")
    why = lost.empty? ? "" : " (you lost #{lost.length}x - new plan)"
    lead = $Trainer.party.find { |p| p && !p.isEgg? && p.hp > 0 }
    if lead && !lead.equal?(best)
      # default answer = keep YOUR lead (so mashing A never changes your plan)
      pick = (Kernel.pbMessage(_INTL("Helper suggests leading with {1} vs {2}{3}.", best.name, foes, why),
                               [_INTL("Keep {1}", lead.name), _INTL("Swap to {1}", best.name)], 1) rescue 0)
      ok = (pick == 1)
      if ok
        i = $Trainer.party.index(best)
        j = $Trainer.party.index(lead)
        $Trainer.party[i], $Trainer.party[j] = $Trainer.party[j], $Trainer.party[i] if i && j
      end
    elsif !lost.empty?
      Kernel.pbMessage(_INTL("Helper: {1} leads - good pick vs {2}{3}.", best.name, foes, why)) rescue nil
    end
    first = $Trainer.party.find { |p| p && !p.isEgg? && p.hp > 0 }
    $rh_last_fight = [key, first ? first.species : nil]
  end

  def self.postbattle(won)
    return if !$rh_last_fight
    key, sp = $rh_last_fight
    $rh_last_fight = nil
    d = g
    return if !d
    if won
      d[:losses].delete(key) if d[:losses]
      d[:lostnote] = nil
    else
      ((d[:losses] ||= {})[key] ||= []) << sp if sp
      d[:lostnote] = "Lost a fight - the helper changed its plan. It will tell you who to lead with right before the rematch."
    end
  end
end

Object.send(:alias_method, :rh_pbTrainerBattle, :pbTrainerBattle) if Object.private_method_defined?(:pbTrainerBattle) && !Object.private_method_defined?(:rh_pbTrainerBattle)
def pbTrainerBattle(trainerid, trainername, endspeech = nil, doublebattle = false, trainerparty = 0, *args, **kw)
  begin
    RH.prebattle(trainerid, trainername, trainerparty)
  rescue
  end
  ret = rh_pbTrainerBattle(trainerid, trainername, endspeech, doublebattle, trainerparty, *args, **kw)
  RH.postbattle(ret ? true : false) rescue nil
  return ret
end

#==============================================================================
# Update channel from Claude (read-only download of a plain-text data file).
# It only reads text lines - it never runs anything it downloads.
# Format of updates.txt:
#   obj|<var>|<value>|<map id>|<x>|<y>|<objective text>
#   obj|<var>|<value>|<map id>|<x>|<y>|<min badges>|<max badges>|<objective text>
#   note|<text>
#==============================================================================
module RH
  UPDATE_URL = "https://raw.githubusercontent.com/kylerredfield24-sys/reborn-helper/main/updates.txt"
  MOD_URL    = "https://raw.githubusercontent.com/kylerredfield24-sys/reborn-helper/main/RebornHelper.rb"

  # self-update: if updates.txt says a newer version exists, download it and swap the file.
  # The new version is used the next time you start the game.
  def self.self_update(want)
    return if want <= RH_VERSION
    path = ["./patch/Mods/RebornHelper.rb", "patch/Mods/RebornHelper.rb"].find { |f| File.exist?(f) }
    return if !path
    code = IO.popen(["/usr/bin/curl", "-fsSL", "--max-time", "20", MOD_URL], err: File::NULL) { |io| io.read }.to_s
    # only accept a complete Reborn Helper file of the promised version
    return if code.length < 50_000 || !code.include?("module RH") || !code.include?("RH_VERSION = #{want}") || !code.include?("RH_VARMAP_DATA")
    tmp = path + ".new"
    File.open(tmp, "wb") { |f| f.write(code) }
    File.rename(path, path + ".old") rescue nil
    File.rename(tmp, path)
    updates[:selfupdate] = want
  rescue
  end

  def self.updates
    $rh_updates ||= { :obj => [], :notes => [], :status => "not checked" }
  end

  def self.fetch_updates
    return if $rh_fetching
    return if g && g[:sync] == false
    $rh_fetching = true
    updates[:status] = "checking..."
    Thread.new do
      begin
        txt = IO.popen(["/usr/bin/curl", "-fsSL", "--max-time", "6", UPDATE_URL], err: File::NULL) { |io| io.read }
        parse_updates(txt.to_s)
        self_update(updates[:version].to_i) if updates[:version].to_i > 0
        updates[:status] = txt.to_s.empty? ? "no updates found" : "updated"
      rescue
        updates[:status] = "offline"
      end
    end
  rescue
    updates[:status] = "not available"
  end

  def self.parse_updates(txt)
    objs = []
    notes = []
    updates[:choice] = {}
    txt.each_line do |l|
      a = l.strip.split("|")
      next if a.empty?
      if a[0] == "obj" && a.length >= 9 && a[6] =~ /^\d+$/ && a[7] =~ /^\d+$/
        objs << { :var => a[1].to_i, :val => a[2].to_i, :map => a[3].to_i, :x => a[4].to_i, :y => a[5].to_i,
                  :minb => a[6].to_i, :maxb => a[7].to_i, :text => a[8..-1].join("|")[0, 200] }
      elsif a[0] == "obj" && a.length >= 7
        objs << { :var => a[1].to_i, :val => a[2].to_i, :map => a[3].to_i, :x => a[4].to_i, :y => a[5].to_i,
                  :minb => 0, :maxb => 99, :text => a[6..-1].join("|")[0, 200] }
      elsif a[0] == "version" && a.length >= 2
        updates[:version] = a[1].to_i
      elsif a[0] == "choice" && a.length >= 4
        (updates[:choice] ||= {})[[a[1].to_i, a[2].to_i]] = a[3..-1].join("|")[0, 200]
      elsif a[0] == "note" && a.length >= 2
        notes << a[1..-1].join("|")[0, 200]
      end
    end
    updates[:obj] = objs
    updates[:notes] = notes.first(10)
  end

  def self.update_obj
    b = ($Trainer.numbadges rescue 0)
    updates[:obj].find { |o| ($game_variables[o[:var]] rescue -1).to_i == o[:val] && b >= o[:minb] && b <= o[:maxb] }
  end
end

#==============================================================================
# Choice helper: when the game asks you to pick (Yes / No, etc.) a small panel
# shows what each answer does (read from the event itself) + a tip for big ones.
#==============================================================================
module RH
  # hand-checked tips for story choices: [map, event] => advice
  # (points = relationship points with that character; sources: game files + community walkthrough)
  CHOICE_TIPS = {
    [457, 9]   => "Pick NO every time (it asks 3 times). Keep the Ring - needed for the best (postgame) route. Refusing all 3: +2 Cal, +1 Anna, +1 Shade.",
    [873, 4]   => "YES - take Cal's ride down (saying no: -1 Cal).",
    [478, 10]  => "Big choice: this picks your story route. YES (fight Taka): Zekrom route, +2 Taka +1 Ace -1 Titania. NO: Reshiram route, +1 Anna +1 Shade -2 Taka. Both are full routes.",
    [694, 1]   => "'Keep winning?' -> NO (+1 Taka). 'Can I come with you?' -> YES: needed for the postgame route (no = -3 Taka).",
    [693, 18]  => "YES = +1 Taka.",
    [414, 111] => "YES = +1 Amaria (no = -1).",
    [413, 102] => "YES: +2 Bennett, +2 Laura, +1 Eve, -2 Saphira. NO: +2 Saphira, -2 Bennett, -1 Laura.",
    [417, 23]  => "YES: +1 Hardy, -1 Florinia. NO: +1 Florinia, -1 Hardy.",
    [417, 33]  => "YES: +1 Saphira, -1 Laura. NO: +1 Laura, -1 Saphira. Press B (no answer): +1 Charlotte.",
    [418, 9]   => "If you're on good terms with Charlotte pick YES (+1), otherwise NO.",
    [413, 100] => "DECIDE = +1 Noel (feel = -1).",
    [774, 9]   => "NO: +1 Cal, -1 Victoria. YES: +1 Victoria, -1 Cal.",
    [768, 61]  => "YES (it's wrong) = +1 Victoria.",
    [733, 12]  => "YES - use Heal Bell (Hardy: +1 if used twice).",
    [736, 44]  => "YES - use Heal Bell on Noel (+1 Noel).",
    [733, 9]   => "'To make things different' = +2 Bennett (best). 'Stronger than anyone' = -1. 'Win Luna' = neutral.",
    [632, 7]   => "NO = +1 Eve, +1 Lumi (yes = -1 each).",
    [413, 51]  => "No-> +1 Hardy, -2 Charlotte. Yes -> +2 Charlotte, -1 Hardy."
  }

  # tips matched by what is being said (for choices made in scripts)
  TEXT_TIPS = [
    [/Pet Glaceon/i, "YES = +2 Lumi (no = -3 Lumi)."],
    [/Pet Espeon/i, "YES = +1 Eve (no = -1 Eve)."],
    [/Pet (Leafeon|Sylveon|Jolteon|Flareon|Vaporeon|Umbreon)/i, "YES - petting is always fine."],
    [/infiltrat/i, "YES (ready) = +1 Victoria (no = -1 Victoria, -1 Arclight)."],
    [/ADRIENN.*[Cc]hampion|[Cc]hampion.*ADRIENN/m, "YES = +1 Adrienn (no = -2)."],
    [/HARDY.*\bbet\b|\bbet\b.*HARDY/m, "YES - take Hardy's bet (+1 Hardy)."],
    [/HARDY.*ready.*Meteor|Meteor.*ready.*HARDY/m, "YES (ready) = +1 Hardy."],
    [/Fund Project|fund the project|Project #/i, "YES = +1 Adrienn."],
    [/Release\?/i, "Your call - this frees whoever is in the tube."]
  ]

  def self.text_tip(txt)
    return nil if !txt
    TEXT_TIPS.each { |re, tip| return tip if txt =~ re }
    return nil
  end

  def self.item_name(sym)
    n = (getItemName(sym) rescue nil)
    n ||= ($cache.items[sym].name rescue nil)
    n ||= sym.to_s.capitalize
    return n
  end

  # what each option leads to, read from the event's commands
  def self.choice_effects(list, idx)
    ind = list[idx].indent
    n = list[idx].parameters[0].length
    eff = Array.new(n) { [] }
    cur = nil
    i = idx + 1
    while i < list.length
      c = list[i]
      break if c.indent < ind
      if c.indent == ind
        break if c.code == 404
        cur = c.code == 402 ? c.parameters[0] : nil
        i += 1
        next
      end
      if cur.is_a?(Integer) && cur < n
        e = eff[cur]
        case c.code
        when 102 then e << "asks again"
        when 121 then e << "your choice is remembered" if c.parameters[2] == 0
        when 122 then e << "story moves on" if STORY_VARS.include?(c.parameters[0])
        when 125 then e << (c.parameters[0] == 0 ? "you get money" : "costs money")
        when 201 then e << "you leave this spot"
        when 301 then e << "battle"
        when 355, 655
          s = c.parameters[0].to_s
          e << "battle" if s =~ /TrainerBattle|WildBattle|DoubleTrainerBattle/
          s.scan(/pbReceiveItem\(\s*:(\w+)/).each { |m| e << "get #{item_name(m[0].to_sym)}" }
          s.scan(/pbItemBall\(\s*:(\w+)/).each { |m| e << "get #{item_name(m[0].to_sym)}" }
          e << "get a Pokemon" if s =~ /pbAddPokemon|pbAddToParty/
          e << "costs money" if s =~ /\$Trainer\.money\s*-=/
        end
      end
      i += 1
    end
    return eff.map { |e| e.uniq.first(3) }
  end

  def self.choice_show(list, idx, map_id, event_id)
    d = g
    return if !d || d[:hud] == false
    opts = list[idx].parameters[0]
    return if !opts || opts.empty?
    eff = choice_effects(list, idx)
    said = []
    z = idx - 1
    while z >= 0 && said.length < 6
      said.unshift(list[z].parameters[0].to_s) if [101, 401].include?(list[z].code)
      z -= 1
    end
    tip = ((updates[:choice] || {})[[map_id, event_id]] rescue nil)
    tip ||= CHOICE_TIPS[[map_id, event_id]] || text_tip(said.join(" ")) || text_tip($rh_last_said.to_s)
    lines = []
    lines << [tip, GOOD] if tip
    opts.each_with_index do |o, i|
      txt = eff[i] && !eff[i].empty? ? eff[i].join(", ") : "the scene just continues"
      lines << ["#{o}: #{txt}", TXT]
    end
    choice_draw(lines)
  end

  # choices made from scripts (Yes/No questions, menus inside events)
  def self.script_choice_show(message, commands)
    return if $rh_choice
    d = g
    return if !d || d[:hud] == false
    return if !(pbMapInterpreterRunning? rescue false)
    ev = ($game_system.map_interpreter.instance_variable_get(:@event_id) rescue 0)
    mid = ($game_map.map_id rescue 0)
    tip = ((updates[:choice] || {})[[mid, ev]] rescue nil)
    tip ||= CHOICE_TIPS[[mid, ev]] || text_tip(message.to_s) || text_tip($rh_last_said.to_s)
    lines = []
    lines << [tip, GOOD] if tip
    lines << ["No story effect known - either answer is fine.", DIM] if !tip
    choice_draw(lines)
  end

  def self.choice_draw(items)
    w = 210
    b = Bitmap.new(w + 12, 40)
    font(b)
    lines = [["Choice help", ACCENT]]
    items.each { |t, col| wrap(b, t.to_s, w).first(4).each { |l| lines << [l, col] } }
    b.dispose
    h = lines.length * RH.lh + 8
    choice_hide
    vp = Viewport.new(0, 0, Graphics.width, Graphics.height)
    vp.z = 100_010
    $rh_choice = Sprite.new(vp)
    $rh_choice.bitmap = Bitmap.new(w + 12, h)
    $rh_choice.bitmap.fill_rect(0, 0, w + 12, h, BG)
    $rh_choice.bitmap.fill_rect(0, 0, 2, h, ACCENT)
    font($rh_choice.bitmap)
    lines.each_with_index { |(t, col), i| text($rh_choice.bitmap, 8, 4 + i * RH.lh, w, t, col) }
    $rh_choice.x = 4
    $rh_choice.y = 4
  end

  def self.choice_hide
    return if !$rh_choice
    vp = $rh_choice.viewport
    $rh_choice.bitmap.dispose if $rh_choice.bitmap && !$rh_choice.bitmap.disposed?
    $rh_choice.dispose if !$rh_choice.disposed?
    vp.dispose if vp && !vp.disposed?
    $rh_choice = nil
  end
end

class Interpreter
  alias rh_command_102 command_102 unless method_defined?(:rh_command_102)
  def command_102
    begin
      RH.choice_show(@list, @index, @map_id, @event_id)
    rescue
    end
    ret = rh_command_102
    RH.choice_hide rescue nil
    return ret
  end
end

class << Kernel
  alias rh_choice_pbMessage pbMessage unless method_defined?(:rh_choice_pbMessage)
  def pbMessage(message, commands = nil, *args, **kw, &block)
    shown = false
    if commands && commands.is_a?(Array) && commands.length > 1
      begin
        RH.script_choice_show(message, commands)
        shown = !$rh_choice.nil?
      rescue
      end
    else
      $rh_last_said = message.to_s
    end
    ret = rh_choice_pbMessage(message, commands, *args, **kw, &block)
    if shown
      RH.choice_hide rescue nil
    end
    return ret
  end
end

#==============================================================================
# Map HUD, route line, Helper menu, context export
#==============================================================================
module RH
  #------------------------------------------------------------------ HUD + route line
  def self.hud_ok?
    return $rh_hud_vp && !$rh_hud_vp.disposed?
  end

  def self.hud_build
    return if hud_ok?
    $rh_hud_vp = Viewport.new(0, 0, W, H)
    $rh_hud_vp.z = 99_990
    $rh_hud = Sprite.new($rh_hud_vp)
    $rh_hud.bitmap = Bitmap.new(W, 140)
    $rh_hud.z = 10
    $rh_dot_bmp = Bitmap.new(32, 32)
    c = Color.new(255, 214, 90, 150)
    (8..23).each do |yy|
      (8..23).each do |xx|
        $rh_dot_bmp.set_pixel(xx, yy, c) if (xx - 15.5)**2 + (yy - 15.5)**2 <= 49
      end
    end
    $rh_dots = []
    $rh_hud_key = nil
    $rh_dot_key = nil
  end

  def self.hud_hide
    return if !hud_ok?
    $rh_hud.visible = false
    $rh_dots.each { |d| d.visible = false }
    $rh_dot_key = nil
  end

  # every ~5 seconds: re-check the story step and whether the world changed (gates, switches, people)
  def self.cond_vars
    @cond_vars ||= RH_CONDVAR_DATA.split(",").map(&:to_i)
  end

  def self.tick_refresh
    fc = (Graphics.frame_count rescue 0)
    return if $rh_tick && fc - $rh_tick < 300
    $rh_tick = fc
    sig = [($game_switches.instance_variable_get(:@data).hash rescue 0),
           ($game_self_switches.instance_variable_get(:@data).hash rescue 0),
           (RH.cond_vars.map { |v| $game_variables[v] rescue 0 }.hash)]   # only values that change which way events work
    if sig != $rh_world_sig
      $rh_world_sig = sig          # route planner rebuilds its picture of the world
      $rh_live = nil               # story step is worked out again
      $rh_obj = nil
    end
  end

  # if you keep pushing toward the next dot and can't move, that tile is blocked for you:
  # remember it and plan around it (catches anything the helper didn't know you can't do yet)
  def self.bump_learn
    dir = (Input.dir4 rescue 0)
    if dir == 0 || $game_player.moving? || (pbMapInterpreterRunning? rescue false)
      $rh_bump = nil
      return
    end
    nav = $rh_nav_cache && $rh_nav_cache[1]
    return if !nav || nav[0].length < 2
    dx = dir == 4 ? -1 : dir == 6 ? 1 : 0
    dy = dir == 8 ? -1 : dir == 2 ? 1 : 0
    tgt = [$game_player.x + dx, $game_player.y + dy]
    return if nav[0][1] != tgt            # only when you're following the dots
    return if ($PokemonGlobal.surfing rescue false) || (RH.ice?($game_player.x, $game_player.y) rescue false)
    return if ($game_map.events || {}).values.any? { |e| e.x == tgt[0] && e.y == tgt[1] }   # someone standing there - they move
    key = [$game_map.map_id, tgt]
    if !$rh_bump || $rh_bump[0] != key
      $rh_bump = [key, Graphics.frame_count]
    elsif Graphics.frame_count - $rh_bump[1] > 45
      ($rh_blocked ||= {})[key] = true
      g[:blocked] = nil
      $rh_bump = nil
      $rh_nav_cache = nil
      $rh_route_db = nil
      $rh_evpos = nil
    end
  end

  def self.hud_update
    hud_build
    tick_refresh rescue nil
    bump_learn rescue nil
    d = g
    fetch_updates if !$rh_fetching
    if d && !d[:navinit]
      d[:navinit] = true
      d[:nav] = :story
    end
    if !d
      hud_hide
      return
    end
    nav = begin; nav_path; rescue => e; log_err(e, "route"); $rh_nav_cache = nil; nil; end
    obj = begin; objective; rescue => e; log_err(e, "goal"); $rh_obj_last; end
    $rh_obj_last = obj
    route = nil
    if nav
      lbl = nav[1].to_s =~ /\A(towards|follow|you're|story|dark|surface|finding|no way)/ ? nav[1] : "to #{nav[1]}"
      route = nav[0].empty? ? "Route: #{nav[1]}" : "Route: #{lbl}  (#{nav[0].length - 1} steps)"
    end
    obj = nil if !d[:hud]
    route = nil if !d[:hud]
    key = [obj, route, d[:font]]
    if key != $rh_hud_key
      $rh_hud_key = key
      b = $rh_hud.bitmap
      b.clear
      font(b)
      lines = []
      lines += wrap(b, obj, 140).first(5).map { |l| [l, TXT] } if obj
      lines += wrap(b, route, 140).first(2).map { |l| [l, ACCENT] } if route
      lines << ["Update ready - restart game", GOOD] if (RH.updates[:selfupdate] rescue nil)
      if !lines.empty?
        w = 152
        x0 = W - w - 4
        h = lines.length * RH.lh + 6
        b.fill_rect(x0, 4, w, h, BG)
        b.fill_rect(x0, 4, 2, h, ACCENT)
        y = 6
        lines.each do |l, col|
          text(b, x0 + 8, y, w - 12, l, col)
          y += RH.lh
        end
      end
    end
    $rh_hud.visible = true
    # route dots
    path = (nav && d[:dots]) ? nav[0] : []
    path = (path[1..-1] || []).first(60)   # only the next 60 tiles (keeps it fast)
    while $rh_dots.length < path.length && $rh_dots.length < 60
      s = Sprite.new($rh_hud_vp)
      s.bitmap = $rh_dot_bmp
      $rh_dots << s
    end
    ox = ($game_map.display_x / 4.0).round
    oy = ($game_map.display_y / 4.0).round
    dk = [ox, oy, path.length, path.first, path.last]
    if dk != $rh_dot_key
      $rh_dot_key = dk
      $rh_dots.each_with_index do |s, i|
        if i < path.length
          s.x = path[i][0] * 32 - ox
          s.y = path[i][1] * 32 - oy
          s.visible = s.x > -32 && s.y > -32 && s.x < W && s.y < H
        else
          s.visible = false
        end
      end
    end
    # soft look: dots fade with distance, and a gentle glow runs along the line toward the goal
    n = [path.length, $rh_dots.length].min
    if n > 0
      head = (Graphics.frame_count / 3) % (n + 12)
      n.times do |i|
        s = $rh_dots[i]
        next if !s.visible
        base = 235 - [i * 6, 140].min
        glow = (i - head).abs < 2 ? 40 : 0
        s.opacity = [base + glow, 255].min
      end
    end
  end

  #------------------------------------------------------------------ context for Claude
  def self.context_text
    t = []
    t << "=== Pokemon Reborn context (paste this to Claude) ==="
    t << "Location: #{mapname($game_map.map_id)} (map #{$game_map.map_id}) x#{$game_player.x} y#{$game_player.y}"
    t << "Badges: #{$Trainer.numbadges}   Level cap: #{cap}   Money: $#{$Trainer.money}"
    sv = STORY_VARS.map { |v| "#{v}=#{$game_variables[v] rescue '?'}" }.join(" ")
    t << "Story vars: #{sv}"
    on = (1..2300).find_all { |i| ($game_switches[i] rescue false) && (i.between?(440, 620)) }
    t << "Story switches on: #{on.join(',')}"
    lr = (live_step rescue nil)
    t << "Helper target: #{lr ? "map #{lr[:map]} ev#{lr[:id]} (#{lr[:x]},#{lr[:y]}) trig#{lr[:trig]} to#{lr[:to]} spec#{lr[:spec]}" : 'none'}"
    np = (nav_path rescue nil)
    t << "Helper route: #{np ? "#{np[1]} (#{np[0].length} steps)" : 'none'}"
    t << "Helper error: #{$rh_plan_err}" if $rh_plan_err
    t << "Helper crash: #{$rh_last_err}" if $rh_last_err
    t << "Helper search: #{$rh_search_info}" if $rh_search_info
    t << "Helper abilities: surf #{RH.can_surf? rescue '?'}, waterfall #{RH.can_waterfall? rescue '?'}, dive #{RH.can_dive? rescue '?'}, strength #{RH.can_strength? rescue '?'}, smash #{RH.can_smash? rescue '?'}, cut #{RH.can_cut? rescue '?'}, climb #{RH.can_rockclimb? rescue '?'}"
    t << "Helper plan: " + ($rh_plan_chain || []).map { |m| RH.mapname(m) rescue m.to_s }.join(" > ") if $rh_plan_chain
    t << "Helper version: #{RH_VERSION}"
    dex = $Trainer.pokedex rescue nil
    t << "Pokedex: seen #{dex.getSeenCount} / owned #{dex.getOwnedCount}" if dex
    obj = objective
    t << "Current objective: #{obj}" if obj
    g[:clues].first(5).each { |c| t << "Clue#{c[:done] ? ' (done)' : ''}: #{c[:text]}" }
    t << ""
    t << "PARTY"
    $Trainer.party.each do |p|
      next if !p
      ab = (getAbilityName(p.ability) rescue p.ability.to_s)
      it = p.item ? iname(p.item) : "none"
      nat = (getNatureName(p.nature) rescue p.nature.to_s)
      mv = p.moves.find_all { |m| m && m.move }.map { |m| "#{mname(m.move)} #{m.pp}/#{m.totalpp}" }.join(", ")
      t << "- #{p.name} (#{getMonName(p.species) rescue p.species}) Lv#{p.level} HP #{p.hp}/#{p.totalhp} | #{ab} | #{nat} | item: #{it}"
      t << "    Atk #{p.attack} Def #{p.defense} SpA #{p.spatk} SpD #{p.spdef} Spe #{p.speed} | #{mv}"
    end
    t << ""
    t << "BAG"
    begin
      names = PokemonBag.pocketNames
      for i in 1...names.length
        items = $PokemonBag.pockets[i] rescue []
        next if !items || items.empty?
        list = items.map { |it| "#{iname(it)} x#{$PokemonBag.pbQuantity(it)}" }
        t << "#{names[i]}: #{list.join(', ')}"
      end
    rescue
    end
    t << ""
    t << "Max Candies used: #{g[:candy] + old_candies_used}"
    return t.join("\n")
  end

  def self.export_context
    s = context_text
    ok = []
    begin
      File.open("Claude_Context.txt", "wb") { |f| f.write(s) }
      ok << "saved Claude_Context.txt in the game folder"
    rescue
    end
    begin
      Input.clipboard = s
      ok << "copied to clipboard"
    rescue
    end
    return ok.empty? ? "Could not save the context." : "Context " + ok.join(" and ") + ". Paste it in your chat with Claude."
  end

  #------------------------------------------------------------------ menu
  TABS = ["Goal", "Route", "Team", "Stats", "More", "Claude"]

  class Menu
    PW = 220

    def initialize
      @vp = Viewport.new(0, 0, W, H)
      @vp.z = 99_995
      @spr = Sprite.new(@vp)
      @spr.bitmap = Bitmap.new(W, H)
      @tab = RH.g[:tab] || 0
      @sel = 0
      @note = nil
    end

    def dispose
      RH.g[:tab] = @tab
      @spr.bitmap.dispose
      @spr.dispose
      @vp.dispose
    end

    # one broken tab never stops the menu from opening
    def rows
      return rows_raw
    rescue => e
      RH.log_err(e, "menu tab #{TABS[@tab]}")
      return [[:info, "This tab hit a problem (saved to RebornHelper_errors.txt). Other tabs still work.", BAD]]
    end

    def rows_raw
      d = RH.g
      case TABS[@tab]
      when "Goal"
        r = []
        obj = RH.objective
        r << [:info, "Now: " + (obj || "No tracked objective yet - talk to people and it fills in."), TXT]
        d[:clues].each_with_index do |c, i|
          label = (c[:done] ? "[done] " : "") + c[:text]
          r << (c[:map] ? [:clue, label, c[:done] ? DIM : TXT, i] : [:info, label, c[:done] ? DIM : TXT])
        end
        r << [:info, "Select a clue to draw the route there.", DIM] if d[:clues].any? { |c| c[:map] }
        r << [:info, "Helper updated - restart the game to use the new version.", GOOD] if RH.updates[:selfupdate]
        r << [:info, d[:lostnote], BAD] if d[:lostnote]
        RH.updates[:notes].each { |n| r << [:info, "From Claude: " + n, ACCENT] }
        return r
      when "Route"
        r = []
        st = (RH.story_step rescue nil)
        r << [:story, "Follow the story: " + RH.step_text(st), d[:nav] == :story ? GOOD : TXT] if st
        if d[:nav]
          r << [:stop, "Stop route line", WARN]
        end
        c = d[:clues].find { |x| x[:map] && !x[:done] }
        r << [:clue, "Go to: #{c[:map]} (last clue)", GOOD, d[:clues].index(c)] if c
        RH.exits_here.each { |id, name| r << [:exit, "Exit to #{name}", TXT, id] }
        r << [:info, "No exits found on this map.", DIM] if r.empty?
        return r
      when "Team"
        r = []
        $Trainer.party.each_with_index do |p, i|
          next if !p
          r << [:mon, "#{p.name}  Lv#{p.level}  #{RH.pct(p.hp, p.totalhp)}%  #{p.item ? RH.iname(p.item) : '-'}", TXT, i]
        end
        (RH.map_trainers rescue []).each do |t|
          team = t[:party].map { |p| "#{p.name} #{p.level}" }.join(", ")
          adv = RH.lead_advice(t[:party])
          r << [:info, "Trainer here: #{t[:name]} - #{team}", WARN]
          if adv && !adv.empty?
            r << [:info, "Lead: #{adv[0].map { |p| p.name }.join(' or ')}   vs their 1st (#{t[:party].first.name}): #{adv[1].name}", GOOD]
          end
        end
        return r
      when "Stats"
        dex = $Trainer.pokedex rescue nil
        seen = dex ? dex.getSeenCount : "?"
        own = dex ? dex.getOwnedCount : "?"
        total = (dex.dexList.keys.length rescue "?")
        b = $Trainer.numbadges
        r = []
        r << [:info, "Story (badges): #{b}/18  =  #{RH.pct(b, 18)}%", ACCENT]
        r << [:info, "Pokedex: #{own} caught, #{seen} seen of #{total}", TXT]
        r << [:info, "Pokedex complete: #{own.is_a?(Integer) && total.is_a?(Integer) ? RH.pct(own, total) : '?'}%", TXT]
        r << [:info, "Level cap: #{RH.cap}", TXT]
        r << [:info, "Money: $#{$Trainer.money}", TXT]
        r << [:info, "Max Candies used: #{d[:candy] + RH.old_candies_used}", TXT]
        return r
      when "More"
        r = []
        r << [:candy, "Use a Max Candy (party to Lv #{RH.cap})", GOOD]
        r << [:info, "Max Candies used so far: #{d[:candy] + RH.old_candies_used}", DIM]
        r << [:tbattle, "Battle panel: #{d[:battle] ? 'ON' : 'OFF'}", TXT]
        r << [:tdots, "Walking path (L button): #{d[:dots] ? 'ON' : 'OFF'}", TXT]
        r << [:thud, "Objective box: #{d[:hud] ? 'ON' : 'OFF'}", TXT]
        r << [:tfont, "Font: #{RH::FONTS[d[:font] || 0][0]}", TXT]
        mods = (Dir["./patch/Mods/*.rb"].map { |f| File.basename(f, ".rb") } rescue [])
        r << [:tsync, "Get updates from Claude (GitHub): #{d[:sync] == false ? 'OFF' : 'ON'} - #{RH.updates[:status]}", TXT]
        r << [:info, "Mods installed: " + mods.join(", "), DIM]
        r << [:info, "Chat shortcuts: say \"next gym\" or \"whats next\" to Claude.", DIM]
        return r
      when "Claude"
        r = []
        r << [:export, "Copy context for Claude", GOOD]
        r << [:info, "Copies your party, stats, moves, bag, location, story step, clues and last battle. Paste it into the Claude app so Claude knows exactly where you are.", DIM]
        return r
      end
      return []
    end

    def act(row)
      d = RH.g
      case row[0]
      when :clue
        c = d[:clues][row[3]]
        ids = RH.map_names[c[:map]] || []
        if ids.empty?
          @note = "Can't find that place on the map list."
        else
          RH.nav_start(ids)
          @note = "Route line on. Follow the dots."
        end
      when :exit
        RH.nav_start([row[3]])
        @note = "Route line on. Follow the dots."
      when :story
        RH.nav_start(:story)
        @note = "Following the story. The dots update as you go."
      when :stop
        RH.nav_stop
        @note = "Route line off."
      when :candy
        @spr.visible = false
        RH.use_candy
        @spr.visible = true
      when :tbattle
        d[:battle] = !d[:battle]
      when :thud
        d[:hud] = !d[:hud]
      when :tdots
        d[:dots] = !d[:dots]
      when :tfont
        d[:font] = ((d[:font] || 0) + 1) % RH::FONTS.length
      when :tsync
        d[:sync] = (d[:sync] == false)
        $rh_fetching = false
        RH.fetch_updates if d[:sync]
      when :export
        @note = RH.export_context
      end
      RH.save_settings if [:tbattle, :thud, :tdots, :tfont, :tsync].include?(row[0])
    end

    def draw
      b = @spr.bitmap
      b.clear
      RH.font(b)
      x0 = W - PW
      b.fill_rect(x0, 0, PW, H, BG)
      b.fill_rect(x0, 0, 2, H, ACCENT)
      # tabs
      tx = x0 + 8
      pad = 8
      pad -= 1 while pad > 2 && TABS.map { |t| b.text_size(t).width + pad }.sum > PW - 12   # keep every tab on screen
      TABS.each_with_index do |t, i|
        tw = b.text_size(t).width + pad
        if i == @tab
          b.fill_rect(tx - 2, 6, tw, 18, BG2)
          RH.text(b, tx + pad / 2 - 2, 6, tw, t, ACCENT)
        else
          RH.text(b, tx + pad / 2 - 2, 6, tw, t, DIM)
        end
        tx += tw
      end
      b.fill_rect(x0 + 8, 27, PW - 16, 1, BG2)
      rs = rows
      @sel = [[@sel, rs.length - 1].min, 0].max
      y = 34
      maxy = H - 42
      # scroll so the selection is visible
      heights = rs.map { |r| [RH.wrap(b, r[1], PW - 28).length, 1].max * RH.lh + 3 }
      start = 0
      start += 1 while start < @sel && heights[start..@sel].sum > maxy - y
      rs.each_with_index do |r, i|
        next if i < start
        ls = RH.wrap(b, r[1], PW - 28)
        break if y + ls.length * RH.lh > maxy
        if i == @sel
          b.fill_rect(x0 + 6, y - 1, PW - 12, ls.length * RH.lh + 2, BG2)
          b.fill_rect(x0 + 6, y - 1, 2, ls.length * RH.lh + 2, ACCENT) if r[0] != :info
        end
        if r[0] == :mon
          p = $Trainer.party[r[3]]
          RH.draw_mon_icon(b, p, x0 + 10, y - 4, 24) rescue nil
          ls = RH.wrap(b, r[1], PW - 52)
          ls.each do |l|
            RH.text(b, x0 + 38, y, PW - 48, l, r[2])
            y += RH.lh
          end
          y += 4
        else
          ls.each do |l|
            RH.text(b, x0 + 14, y, PW - 24, l, r[2])
            y += RH.lh
          end
        end
        y += 3
      end
      # team detail
      if TABS[@tab] == "Team" && rs[@sel]
        p = $Trainer.party[rs[@sel][3]]
        if p
          y += 4
          det = []
          det << "#{(getAbilityName(p.ability) rescue p.ability)} / #{(getNatureName(p.nature) rescue p.nature)}"
          det << "Atk #{p.attack} Def #{p.defense} SpA #{p.spatk}"
          det << "SpD #{p.spdef} Spe #{p.speed}"
          p.moves.each { |m| det << "- #{RH.mname(m.move)}  #{m.pp}/#{m.totalpp}" if m && m.move }
          det.each do |l|
            break if y > maxy
            RH.text(b, x0 + 14, y, PW - 24, l, DIM)
            y += RH.lh
          end
        end
      end
      if @note
        RH.wrap(b, @note, PW - 24).first(2).each_with_index { |l, i| RH.text(b, x0 + 12, H - 36 + i * RH.lh, PW - 24, l, WARN) }
      else
        RH.text(b, x0 + 12, H - 22, PW - 24, "Left/Right tabs   A select   B close", DIM)
      end
    end

    def run
      draw
      loop do
        Graphics.update
        Input.update
        changed = false
        if Input.trigger?(Input::B) || Input.trigger?(Input::R)
          pbPlayCancelSE rescue nil
          break
        elsif Input.trigger?(Input::RIGHT)
          @tab = (@tab + 1) % TABS.length; @sel = 0; @note = nil; changed = true
        elsif Input.trigger?(Input::LEFT) || Input.trigger?(Input::L)
          @tab = (@tab - 1) % TABS.length; @sel = 0; @note = nil; changed = true
        elsif Input.repeat?(Input::DOWN)
          @sel += 1; changed = true
        elsif Input.repeat?(Input::UP)
          @sel -= 1 if @sel > 0; changed = true
        elsif Input.trigger?(Input::C)
          r = rows[@sel]
          if r && r[0] != :info
            pbPlayDecisionSE rescue nil
            act(r)
            changed = true
          end
        end
        if $rh_chat_changed
          $rh_chat_changed = false
          changed = true
        end
        if changed
          draw
        end
      end
    end
  end

  # problems get written to RebornHelper_errors.txt (and shown in Copy context) instead of failing silently
  def self.log_err(e, where = "")
    msg = "#{where}: #{e.class}: #{e.message} @ #{(e.backtrace || []).first(3).join(' | ')}"
    return if $rh_last_err == msg
    $rh_last_err = msg
    File.open("./patch/Mods/RebornHelper_errors.txt", "a") { |f| f.puts("[v#{RH_VERSION}] " + msg) } rescue nil
  end

  def self.open_menu
    hud_hide
    m = Menu.new
    begin
      m.run
    rescue Exception => e
      raise if e.is_a?(SystemExit) || e.class.name == "Reset"
      log_err(e, "menu")
      g[:tab] = 0
    ensure
      m.dispose rescue nil
    end
    $rh_hud_key = nil
    $rh_nav_cache = nil
    Input.update
  end
end

class Scene_Map
  alias rh_update update unless method_defined?(:rh_update)
  def update
    rh_update
    return if $scene != self
    begin
      if $rh_last_map != $game_map.map_id
        $rh_came_from = $rh_last_map
        $rh_last_map = $game_map.map_id
        ($rh_hist ||= []) << $game_map.map_id      # recent areas (stops ping-ponging between two places)
        $rh_hist.shift while $rh_hist.length > 6
        $rh_region = nil
        $rh_evpos = nil
        $rh_clearpos = nil
        $rh_region_entry = [$game_map.map_id, $rh_came_from]
        $rh_nav_cache = nil
        if $rh_blocked || (RH.g && RH.g[:blocked])   # learned walls only last while you're on that map
          $rh_blocked = nil
          RH.g[:blocked] = nil if RH.g
          $rh_route_db = nil
        end
        RH.mark_visited
      end
      free = !pbMapInterpreterRunning? && !$game_temp.message_window_showing && !$game_player.moving? &&
             !$game_temp.menu_calling && !$game_temp.in_battle
      if free && Input.trigger?(Input::R)
        RH.open_menu
      elsif free && Input.trigger?(Input::L)
        RH.g[:dots] = !RH.g[:dots]; RH.save_settings
        $rh_hud_key = nil
      end
      $rh_hud_frame = Graphics.frame_count
      RH.hud_update
    rescue => e
      RH.log_err(e, "map") rescue nil
      RH.hud_hide rescue nil
    end
  end

  if method_defined?(:miniupdate)
    alias rh_miniupdate miniupdate unless method_defined?(:rh_miniupdate)
    def miniupdate
      rh_miniupdate
      begin
        if $scene == self && $rh_hud_frame != Graphics.frame_count
          $rh_hud_frame = Graphics.frame_count
          RH.hud_update
        end
      rescue
      end
    end
  end

  alias rh_disposeSpritesets disposeSpritesets unless method_defined?(:rh_disposeSpritesets)
  def disposeSpritesets
    RH.hud_hide rescue nil
    rh_disposeSpritesets
  end
end

module RH
  def self.battle_context
    sc = $rh_battle_scene
    return "" if !sc
    b = sc.instance_variable_get(:@battle) rescue nil
    return "" if !b
    t = ["", "CURRENT BATTLE (#{b.doublebattle ? 'double' : 'single'})"]
    b.battlers.each_with_index do |x, i|
      next if !x || x.hp <= 0
      side = i.even? ? "Mine" : "Foe"
      mv = x.moves.find_all { |m| m && m.move }.map { |m| mname(m.move) }.join(", ")
      t << "#{side}: #{x.name} Lv#{x.level} HP #{x.hp}/#{x.totalhp} Spe #{x.pbSpeed rescue '?'} | #{mv}"
    end
    t << "Field: #{(b.FE rescue '?')}"
    t << "Recent: " + RH.log.last(4).join(" / ")
    return t.join("\n")
  end

end

class PokeBattle_Scene
  alias rh_chat_pbStartBattle pbStartBattle unless method_defined?(:rh_chat_pbStartBattle)
  def pbStartBattle(battle)
    $rh_battle_scene = self
    rh_chat_pbStartBattle(battle)
  end

  alias rh_chat_pbEndBattle pbEndBattle unless method_defined?(:rh_chat_pbEndBattle)
  def pbEndBattle(result)
    $rh_battle_scene = nil
    rh_chat_pbEndBattle(result)
  end
end

# map-to-map links from the game files: from,x,y,to,switch,var,value
RH_WARP_DATA = "1,9,4,113,0,0,0;2,9,4,113,0,0,0;3,9,4,113,0,0,0;4,9,4,113,0,0,0;5,9,4,113,0,0,0;6,9,4,113,0,0,0;7,9,4,113,0,0,0;8,2,3,9,0,0,0;8,3,3,9,0,0,0;8,20,12,57,0,0,0;8,21,12,57,0,0,0;9,12,2,8,0,0,0;9,12,23,10,0,0,0;9,13,2,8,0,0,0;9,13,6,11,2013,0,0;9,13,23,10,0,0,0;10,11,20,13,0,0,0;10,24,2,11,0,0,0;10,24,21,9,0,0,0;10,25,2,11,0,0,0;10,25,21,9,0,0,0;10,45,19,57,0,0,0;10,46,19,57,0,0,0;11,3,19,12,0,0,0;11,16,2,10,0,0,0;11,17,2,10,0,0,0;12,76,4,11,0,0,0;12,77,4,11,0,0,0;13,10,22,10,0,0,0;14,9,8,15,0,0,0;14,9,8,206,0,0,0;14,10,14,97,0,0,0;14,11,14,97,0,0,0;14,12,14,97,0,0,0;15,30,13,14,0,0,0;15,30,13,206,0,0,0;17,4,8,25,0,0,0;17,4,25,22,0,0,0;17,5,15,23,0,0,0;17,5,19,23,0,0,0;17,5,23,23,0,0,0;17,11,10,25,0,0,0;17,11,15,26,0,107,26;17,11,26,22,0,0,0;17,11,31,22,0,0,0;17,17,15,23,0,0,0;17,17,19,23,0,0,0;17,17,23,23,0,0,0;17,18,8,25,0,0,0;17,18,25,22,0,0,0;20,10,11,30,0,0,0;21,13,15,33,0,0,0;21,13,15,34,0,0,0;22,2,2,17,0,0,0;22,2,2,564,0,0,0;22,8,19,17,0,0,0;22,8,19,564,0,0,0;22,8,19,564,1718,0,0;22,8,26,17,0,0,0;22,8,26,564,0,0,0;22,14,2,17,0,0,0;22,14,2,564,0,0,0;23,5,5,17,0,0,0;23,5,5,564,0,0,0;23,5,17,17,0,0,0;23,5,17,564,0,0,0;23,5,30,17,0,0,0;23,5,30,564,0,0,0;23,14,5,17,0,0,0;23,14,5,564,0,0,0;23,14,17,17,0,0,0;23,14,17,564,0,0,0;23,14,30,17,0,0,0;23,14,30,564,0,0,0;24,12,9,563,0,0,0;24,12,9,899,0,0,0;24,12,13,636,0,0,0;24,12,14,825,0,576,1;24,13,13,636,0,0,0;24,13,14,825,0,0,0;24,14,0,207,0,0,0;24,14,1,207,0,0,0;24,14,2,206,0,0,0;24,15,4,855,0,0,0;24,15,5,855,0,0,0;24,15,6,855,0,0,0;24,15,7,855,0,0,0;24,16,1,57,0,0,0;24,16,1,57,51,0,0;24,19,14,508,0,0,0;25,2,25,17,0,0,0;25,2,25,564,0,0,0;25,10,2,26,0,0,0;25,10,9,17,0,0,0;25,10,9,564,0,0,0;25,17,25,17,0,0,0;25,17,25,564,0,0,0;26,9,13,25,0,0,0;27,18,7,21,0,0,0;27,21,31,205,0,0,0;27,26,23,26,0,118,9;29,8,9,37,0,0,0;29,8,10,37,0,0,0;29,8,11,37,0,0,0;29,8,12,37,0,0,0;29,8,13,37,0,0,0;29,8,60,37,0,0,0;29,8,61,37,0,0,0;29,8,62,37,0,0,0;29,8,63,37,0,0,0;29,8,64,37,0,0,0;29,30,9,40,0,0,0;29,30,10,40,0,0,0;29,30,11,40,0,0,0;29,30,12,40,0,0,0;29,30,13,40,0,0,0;29,31,8,79,0,0,0;29,32,8,79,0,0,0;29,33,8,79,0,0,0;29,34,8,79,0,0,0;29,34,45,38,0,0,0;29,34,48,38,0,0,0;29,35,8,79,0,0,0;29,35,45,38,0,0,0;29,35,48,38,0,0,0;29,36,8,79,0,0,0;29,37,8,79,0,0,0;29,38,8,79,0,0,0;29,39,8,79,0,0,0;29,40,9,40,0,0,0;29,40,10,40,0,0,0;29,40,11,40,0,0,0;29,40,12,40,0,0,0;29,40,12,40,0,104,27;29,40,13,40,0,0,0;29,40,13,40,0,104,27;29,59,9,41,0,0,0;29,59,10,41,0,0,0;29,59,11,41,0,0,0;29,59,12,41,0,0,0;29,59,13,41,0,0,0;29,59,33,36,0,0,0;29,59,34,36,0,0,0;29,59,35,36,0,0,0;29,59,36,36,0,0,0;29,59,37,36,0,0,0;29,59,38,36,0,0,0;29,59,39,36,0,0,0;30,16,14,31,0,0,0;30,40,56,20,0,0,0;30,40,56,567,0,0,0;31,16,8,887,0,664,1;31,17,8,887,0,664,1;31,26,31,30,0,0,0;32,15,18,31,0,0,0;33,17,35,34,0,0,0;33,25,31,201,0,0,0;33,25,31,202,0,0,0;33,27,52,21,0,0,0;33,27,52,568,0,0,0;33,35,11,201,0,0,0;33,35,11,202,0,0,0;33,41,27,35,0,0,0;33,41,27,199,0,0,0;33,47,43,35,0,0,0;33,47,43,199,0,0,0;34,20,51,33,0,0,0;34,25,31,201,0,0,0;34,25,31,202,0,0,0;34,27,52,21,0,0,0;34,27,52,568,0,0,0;34,35,11,201,0,0,0;34,35,11,202,0,0,0;34,47,43,35,0,0,0;34,47,43,199,0,0,0;35,17,27,200,0,0,0;35,18,9,33,0,0,0;35,18,9,34,0,0,0;35,37,27,199,0,0,0;35,40,9,200,0,0,0;35,40,14,200,0,0,0;35,61,27,200,0,0,0;36,8,34,29,0,0,0;36,8,35,29,0,0,0;36,8,36,29,0,0,0;36,8,37,29,0,0,0;36,8,38,29,0,0,0;36,8,39,29,0,0,0;36,8,40,29,0,0,0;36,18,8,227,0,0,0;36,19,53,105,0,0,0;36,20,18,102,0,0,0;36,20,36,82,0,0,0;36,25,23,104,0,0,0;36,26,36,369,0,0,0;36,28,11,226,0,0,0;36,35,36,84,0,0,0;36,36,24,83,0,0,0;36,38,15,111,0,0,0;36,40,24,106,0,0,0;36,42,54,81,0,0,0;36,43,36,256,0,0,0;36,43,54,81,0,0,0;36,44,54,81,0,0,0;36,45,54,81,0,0,0;36,46,54,81,0,0,0;36,47,54,81,0,0,0;36,59,15,112,0,0,0;36,59,33,269,0,0,0;36,60,23,108,0,0,0;36,68,12,421,0,0,0;36,69,12,421,0,0,0;36,70,12,421,0,0,0;36,70,54,81,0,0,0;36,71,12,421,0,0,0;36,71,54,81,0,0,0;36,72,12,421,0,0,0;36,72,54,81,0,0,0;36,73,12,421,0,0,0;36,73,54,81,0,0,0;36,74,12,421,0,0,0;36,74,54,81,0,0,0;37,12,15,56,0,0,0;37,14,8,56,0,0,0;37,19,44,47,0,0,0;37,20,31,49,0,0,0;37,24,6,57,0,0,0;37,25,6,57,0,0,0;37,26,6,57,0,0,0;37,27,6,57,0,0,0;37,28,6,57,0,0,0;37,29,6,57,0,0,0;37,29,33,42,0,0,0;37,33,11,55,0,0,0;37,33,44,46,0,0,0;37,33,46,45,0,0,0;37,33,50,45,0,0,0;37,35,33,48,0,0,0;37,38,54,44,0,0,0;37,42,24,50,0,0,0;37,52,11,54,0,0,0;37,54,7,52,0,0,0;37,57,52,43,0,0,0;37,58,43,42,0,0,0;37,64,28,78,61,0,0;37,68,9,53,0,0,0;37,75,11,29,0,0,0;37,75,12,29,0,0,0;37,75,13,29,0,0,0;37,75,14,29,0,0,0;37,75,15,29,0,0,0;37,75,62,29,0,0,0;37,75,63,29,0,0,0;37,75,64,29,0,0,0;37,75,65,29,0,0,0;37,75,66,29,0,0,0;38,9,4,39,0,0,0;38,14,28,39,0,0,0;38,15,29,29,0,0,0;38,15,29,519,0,0,0;38,19,4,764,0,0,0;39,1,3,38,0,26,1;39,2,2,38,0,0,0;39,8,3,899,0,0,0;40,1,6,29,0,0,0;40,1,7,29,0,0,0;40,1,8,29,0,0,0;40,1,9,29,0,0,0;40,1,10,29,0,0,0;40,1,11,29,0,0,0;40,16,6,29,0,0,0;40,16,7,29,0,0,0;40,16,8,29,0,0,0;40,16,9,29,0,0,0;40,16,10,29,0,0,0;40,16,11,29,0,0,0;41,0,6,29,0,0,0;41,0,6,519,479,0,0;41,0,7,29,0,0,0;41,0,7,519,479,0,0;41,0,8,29,0,0,0;41,0,8,519,479,0,0;41,0,9,29,0,0,0;41,0,9,519,479,0,0;41,0,10,29,0,0,0;41,0,10,519,479,0,0;42,9,10,37,0,0,0;42,30,10,37,0,0,0;42,30,10,530,479,0,0;43,9,10,37,0,0,0;44,7,10,37,0,0,0;45,6,2,37,0,0,0;45,6,10,37,0,0,0;46,6,10,37,0,0,0;47,9,10,37,0,0,0;47,9,10,530,0,0,0;48,10,11,37,0,0,0;48,10,11,530,0,0,0;49,10,12,37,0,0,0;49,10,12,530,0,0,0;50,9,11,37,0,0,0;51,0,0,689,0,0,0;51,0,14,25,0,0,0;52,20,7,37,0,0,0;52,20,8,37,0,0,0;52,20,9,37,0,0,0;52,20,10,37,0,0,0;53,9,11,37,0,0,0;53,9,11,530,0,0,0;54,9,11,37,0,0,0;54,9,11,530,0,0,0;55,9,11,37,0,0,0;55,9,11,530,0,0,0;56,7,13,37,0,0,0;56,7,13,530,0,0,0;56,12,5,57,0,0,0;56,12,5,522,479,0,0;57,8,36,8,0,0,0;57,16,30,68,0,0,0;57,16,49,10,0,0,0;57,29,46,70,0,0,0;57,33,38,67,0,0,0;57,39,25,423,0,0,0;57,40,25,423,0,0,0;57,41,25,423,0,0,0;57,41,46,69,0,0,0;57,42,25,423,0,0,0;57,43,25,423,0,0,0;57,44,25,423,0,0,0;57,45,25,423,0,0,0;57,53,29,60,0,0,0;57,60,46,63,0,0,0;57,61,61,71,48,0,0;57,64,18,64,0,0,0;57,66,78,56,0,0,0;57,68,43,61,0,0,0;57,71,10,62,0,0,0;57,76,77,37,0,0,0;57,77,77,37,0,0,0;57,78,77,37,0,0,0;57,79,77,37,0,0,0;57,80,41,65,0,0,0;57,80,77,37,0,0,0;57,81,77,37,0,0,0;57,83,35,58,0,0,0;57,83,58,59,0,0,0;58,8,19,57,0,0,0;58,9,19,57,0,0,0;59,8,9,57,0,0,0;59,8,9,522,0,0,0;60,8,9,57,0,0,0;60,8,9,522,0,0,0;61,8,9,57,0,0,0;61,8,9,522,479,0,0;62,8,9,57,0,0,0;62,22,4,328,0,323,2;62,25,9,522,0,0,0;63,9,11,57,0,0,0;63,9,11,522,0,0,0;64,9,9,57,0,0,0;64,9,9,522,0,0,0;65,8,11,57,0,0,0;65,8,11,522,0,0,0;66,8,18,8,0,0,0;66,16,12,68,0,0,0;66,16,31,10,0,0,0;66,29,28,70,0,0,0;66,33,20,67,0,0,0;66,39,7,423,0,0,0;66,40,7,423,0,0,0;66,41,7,423,0,0,0;66,41,28,69,0,0,0;66,42,7,423,0,0,0;66,43,7,423,0,0,0;66,44,7,423,0,0,0;66,45,7,423,0,0,0;67,6,10,57,0,0,0;68,6,10,57,0,0,0;68,6,10,522,0,0,0;69,10,13,57,0,0,0;69,10,13,522,0,0,0;70,8,10,57,0,0,0;70,8,10,522,0,0,0;71,41,60,57,0,0,0;71,41,60,57,51,0,0;71,91,65,57,58,0,0;72,16,1,73,52,0,0;72,17,1,73,52,0,0;72,18,26,71,0,0,0;73,14,14,74,53,0,0;73,16,1,72,0,0,0;73,17,1,72,0,0,0;74,2,7,73,0,0,0;74,8,3,77,56,0,0;74,9,3,77,56,0,0;74,9,12,75,0,0,0;74,10,3,77,56,0,0;74,16,7,76,0,0,0;75,11,1,74,0,0,0;76,8,13,74,0,0,0;77,8,9,57,0,0,0;78,10,2,351,0,0,0;78,10,25,37,0,0,0;78,10,25,530,0,0,0;78,54,19,899,0,0,0;78,55,2,351,0,0,0;78,55,25,37,0,0,0;78,55,25,530,0,0,0;79,7,18,424,0,0,0;79,7,19,424,0,0,0;79,7,20,424,0,0,0;79,7,21,424,0,0,0;79,7,22,424,0,0,0;79,8,35,164,0,0,0;79,13,35,164,0,0,0;79,22,50,29,0,0,0;79,23,50,29,0,0,0;79,24,50,29,0,0,0;79,25,20,177,0,92,2;79,25,50,29,0,0,0;79,26,7,295,0,150,23;79,26,11,97,0,150,24;79,26,50,29,0,0,0;79,27,50,29,0,0,0;79,28,50,29,0,0,0;79,29,50,29,0,0,0;79,30,50,29,0,0,0;79,36,22,826,0,0,0;79,56,22,164,0,0,0;79,63,18,165,0,0,0;79,70,34,517,0,0,0;79,70,35,517,0,0,0;80,12,10,168,0,0,0;80,13,18,322,0,0,0;80,13,19,322,0,0,0;80,16,36,168,0,0,0;80,18,22,169,0,0,0;80,18,61,169,0,0,0;80,19,55,166,0,0,0;80,19,73,167,0,0,0;80,27,10,169,0,0,0;80,28,56,41,0,104,23;80,30,22,171,0,0,0;80,30,53,181,0,92,16;80,30,53,181,0,104,3;80,30,53,181,0,104,4;80,34,23,169,0,0,0;80,41,12,175,0,92,13;80,41,55,170,0,0,0;80,43,60,169,0,0,0;80,56,59,424,0,0,0;80,56,60,424,0,0,0;80,56,61,424,0,0,0;80,56,62,424,0,0,0;81,38,8,36,0,0,0;81,39,8,36,0,0,0;81,40,8,36,0,0,0;81,41,8,36,0,0,0;81,42,8,36,0,0,0;81,42,29,91,0,0,0;81,43,8,36,0,0,0;81,46,11,86,0,0,0;81,47,40,91,0,0,0;81,54,22,85,0,0,0;81,59,41,85,0,0,0;81,63,11,101,0,0,0;81,64,43,420,0,0,0;81,65,43,420,0,0,0;81,66,8,36,0,0,0;81,66,29,210,0,118,12;81,66,43,420,0,0,0;81,67,8,36,0,0,0;81,67,29,210,0,118,12;81,67,43,420,0,0,0;81,68,8,36,0,0,0;81,68,43,420,0,0,0;81,69,8,36,0,0,0;81,69,43,420,0,0,0;81,70,8,36,0,0,0;81,70,43,420,0,0,0;82,7,12,36,0,0,0;82,7,12,520,0,0,0;83,10,11,36,0,0,0;83,10,11,520,0,0,0;84,9,10,36,0,0,0;84,9,10,520,0,0,0;84,26,5,622,0,0,0;84,35,5,623,0,339,12;85,8,3,90,0,0,0;85,12,8,88,0,0,0;85,13,24,89,0,638,4;85,39,24,89,0,638,2;85,40,12,88,0,0,0;85,48,48,81,0,0,0;85,48,48,528,0,0,0;85,49,16,90,0,0,0;85,49,17,90,0,0,0;85,49,48,81,0,0,0;85,49,48,528,0,0,0;85,50,48,81,0,0,0;85,50,48,528,0,0,0;85,55,39,90,0,0,0;85,76,23,81,0,0,0;85,76,23,528,0,0,0;85,77,23,81,0,0,0;85,77,23,528,0,0,0;85,78,23,81,0,0,0;85,78,23,528,0,0,0;86,9,11,81,0,0,0;86,9,11,528,479,0,0;86,9,11,585,653,0,0;87,16,29,88,0,0,0;87,17,29,88,0,0,0;87,18,29,88,0,0,0;87,30,10,85,0,0,0;87,31,10,85,0,0,0;87,32,10,85,0,0,0;88,20,5,96,0,0,0;88,25,23,89,0,638,4;88,27,7,85,0,0,0;88,37,15,95,0,0,0;88,38,15,95,0,0,0;88,39,15,95,0,0,0;88,46,6,95,0,0,0;88,49,11,85,0,0,0;88,51,23,89,0,0,0;88,86,22,228,0,0,0;88,87,22,228,0,0,0;89,4,9,85,0,640,1;89,4,9,88,0,0,0;89,4,9,91,0,640,2;89,23,9,85,0,639,1;89,23,9,88,0,0,0;89,23,9,91,0,639,2;90,2,12,85,0,0,0;90,2,13,85,0,0,0;90,9,48,85,0,0,0;90,24,39,91,0,0,0;90,26,25,85,0,0,0;91,3,44,89,0,0,0;91,6,30,81,0,0,0;91,6,30,528,0,0,0;91,7,30,81,0,0,0;91,7,30,528,0,0,0;91,11,15,92,0,0,0;91,16,43,81,0,0,0;91,16,43,528,0,0,0;91,25,4,90,0,0,0;91,29,43,89,0,0,0;91,29,44,89,0,0,0;92,7,9,91,0,0,0;93,10,0,92,0,0,0;93,10,1,92,0,0,0;93,10,2,92,0,0,0;93,14,2,94,0,0,0;94,9,4,95,0,56,11;94,9,13,93,0,0,0;95,15,68,88,0,0,0;95,16,68,88,0,0,0;95,17,68,88,0,0,0;95,18,68,88,0,0,0;95,26,58,88,0,0,0;95,27,58,88,0,0,0;96,9,4,320,0,0,0;96,9,17,88,0,0,0;97,28,21,109,0,0,0;97,29,10,14,162,0,0;97,40,9,98,0,0,0;97,42,19,292,0,150,25;97,47,26,248,0,0,0;97,48,17,99,0,0,0;97,52,6,420,0,0,0;97,53,6,420,0,0,0;97,54,6,420,0,0,0;97,55,6,420,0,0,0;97,55,26,110,0,0,0;97,56,6,420,0,0,0;97,56,16,100,0,0,0;97,57,6,420,0,0,0;97,58,6,420,0,0,0;98,8,11,97,0,0,0;98,8,11,526,0,0,0;99,9,10,97,0,0,0;100,10,11,97,0,0,0;100,10,11,526,0,0,0;101,14,10,81,0,0,0;101,14,10,528,0,0,0;101,14,10,585,0,0,0;102,7,6,103,0,0,0;102,7,6,635,0,0,0;102,10,10,36,0,0,0;102,10,10,520,0,0,0;103,20,3,102,0,0,0;103,20,4,102,0,0,0;103,20,5,102,0,0,0;103,20,6,102,0,0,0;104,10,13,36,0,0,0;104,10,13,520,479,0,0;105,0,10,36,0,0,0;105,0,11,36,0,0,0;105,0,12,36,0,0,0;106,7,12,36,0,0,0;106,7,12,520,0,0,0;107,13,60,36,0,0,0;107,50,12,36,0,0,0;108,12,8,36,0,0,0;108,12,8,269,0,0,0;109,9,14,97,0,0,0;109,10,14,97,0,0,0;109,11,14,97,0,0,0;110,8,14,97,0,0,0;110,9,14,97,0,0,0;110,10,14,97,0,0,0;111,9,14,36,0,0,0;111,9,14,520,0,0,0;112,9,4,113,0,0,0;112,9,11,36,0,0,0;112,9,11,520,479,0,0;113,9,11,1,0,0,0;113,9,11,2,0,0,0;113,9,11,3,0,0,0;113,9,11,4,0,0,0;113,9,11,5,0,0,0;113,9,11,6,0,0,0;113,9,11,7,0,0,0;113,9,11,112,0,0,0;113,9,11,114,0,0,0;113,9,11,141,0,0,0;113,9,11,183,0,0,0;113,9,11,425,0,0,0;114,9,4,113,0,0,0;115,16,38,116,0,0,0;115,20,14,119,0,0,0;115,30,35,118,0,0,0;115,41,38,117,0,0,0;115,44,41,421,0,0,0;115,45,14,120,0,0,0;115,45,41,421,0,0,0;115,46,41,421,0,0,0;115,47,41,421,0,0,0;115,48,41,421,0,0,0;115,49,41,421,0,0,0;115,50,41,421,0,0,0;116,6,11,115,0,0,0;116,6,11,521,0,0,0;117,36,8,115,0,0,0;117,36,8,521,0,0,0;118,10,13,115,0,0,0;118,10,13,521,0,0,0;118,14,6,129,0,0,0;119,2,6,125,0,0,0;119,9,14,115,0,0,0;119,9,14,521,0,0,0;119,15,6,124,0,0,0;119,15,28,590,0,0,0;120,0,5,124,0,0,0;120,10,14,115,0,0,0;120,10,14,521,479,0,0;120,39,6,121,0,0,0;121,3,9,124,0,0,0;121,7,7,123,0,278,2;121,8,7,123,0,278,2;121,15,7,123,0,0,0;121,23,4,122,0,0,0;121,33,4,122,0,0,0;121,37,6,120,0,0,0;122,2,11,121,0,0,0;122,17,11,121,0,0,0;123,10,14,121,0,0,0;123,29,4,516,0,0,0;123,31,14,121,0,0,0;123,32,14,121,0,0,0;124,0,7,119,0,0,0;124,37,11,121,0,0,0;124,39,5,120,0,0,0;125,5,8,126,0,0,0;125,16,11,119,0,0,0;126,8,8,127,0,73,8;126,8,14,125,0,0,0;127,9,4,125,0,0,0;127,9,15,126,0,0,0;127,12,8,899,1959,0,0;128,16,13,129,0,0,0;129,9,11,118,0,0,0;129,9,11,128,0,0,0;129,9,11,573,0,0,0;130,8,14,132,0,0,0;130,8,35,132,0,0,0;130,19,14,138,0,0,0;130,19,31,135,0,0,0;130,21,27,135,0,0,0;130,24,14,138,0,0,0;130,25,23,134,0,0,0;130,32,17,134,0,0,0;130,32,31,134,0,0,0;130,34,14,136,0,0,0;130,44,14,138,0,0,0;130,49,32,133,0,0,0;130,49,38,423,0,0,0;130,50,38,423,0,0,0;130,51,38,423,0,0,0;130,52,38,423,0,0,0;130,53,38,423,0,0,0;130,54,38,423,0,0,0;130,55,38,423,0,0,0;130,73,8,422,0,0,0;130,74,8,422,0,0,0;130,75,8,422,0,0,0;130,76,8,422,0,0,0;130,76,25,137,0,0,0;130,77,8,422,0,0,0;130,78,8,422,0,0,0;130,79,8,422,0,0,0;132,56,29,885,0,0,0;132,57,29,885,0,0,0;132,99,41,130,0,0,0;132,106,14,130,0,0,0;133,3,10,130,0,0,0;133,3,10,523,479,0,0;133,10,5,150,0,107,5;134,0,4,130,0,0,0;134,13,1,130,0,0,0;134,13,13,130,0,0,0;135,12,13,130,0,0,0;135,16,10,130,0,0,0;136,10,11,130,0,0,0;137,8,11,130,0,0,0;138,9,11,130,0,0,0;138,29,4,139,0,0,0;138,29,11,130,0,0,0;138,49,4,139,0,0,0;138,49,11,130,0,0,0;139,9,11,138,0,0,0;139,9,11,140,0,0,0;139,29,11,138,0,0,0;140,8,3,139,0,0,0;141,9,4,113,0,0,0;142,7,8,161,0,0,0;142,12,14,160,0,0,0;142,21,22,159,0,0,0;142,27,38,422,0,0,0;142,28,38,422,0,0,0;142,29,38,422,0,0,0;142,30,38,422,0,0,0;142,31,38,422,0,0,0;142,32,38,422,0,0,0;142,33,38,422,0,0,0;143,27,13,422,0,0,0;143,28,13,422,0,0,0;143,29,13,422,0,0,0;143,30,13,422,0,0,0;143,31,13,422,0,0,0;143,32,13,422,0,0,0;143,33,13,422,0,0,0;146,12,19,382,0,0,0;146,23,10,197,0,104,27;149,8,7,150,0,0,0;149,8,16,150,0,0,0;149,8,24,150,0,0,0;149,8,33,150,0,0,0;149,12,15,155,0,0,0;149,16,15,155,0,0,0;149,23,16,426,0,0,0;149,34,29,158,0,0,0;150,24,102,154,0,0,0;150,24,103,154,0,0,0;150,30,91,153,0,0,0;150,40,94,153,0,0,0;150,40,95,153,0,0,0;150,41,94,153,0,0,0;150,41,95,153,0,0,0;150,53,13,186,0,0,0;150,56,86,154,0,0,0;150,67,52,154,0,0,0;150,70,100,153,0,0,0;150,74,12,153,0,0,0;150,74,13,153,0,0,0;150,75,12,153,0,0,0;150,75,13,153,0,0,0;150,86,70,154,0,0,0;150,90,21,153,0,0,0;150,90,21,153,0,660,3;150,90,21,153,0,660,35;150,127,24,889,0,660,30;150,129,19,886,0,660,3;150,129,19,886,0,660,12;150,129,19,886,0,660,23;150,129,19,886,0,660,35;150,130,23,133,0,107,6;150,134,26,149,0,0,0;150,137,84,153,0,0,0;150,137,85,153,0,0,0;150,138,84,153,0,0,0;150,138,85,153,0,0,0;150,142,53,154,0,0,0;150,148,81,153,0,0,0;150,159,39,149,0,0,0;150,159,39,544,0,0,0;150,159,62,149,0,0,0;150,159,79,149,0,0,0;150,159,79,544,0,0,0;150,159,101,149,0,0,0;150,159,101,544,0,0,0;151,10,6,184,0,0,0;151,31,16,162,0,0,0;151,32,16,162,0,0,0;153,1,0,150,0,77,3;153,16,68,150,0,0,0;153,28,86,150,0,0,0;153,60,15,150,0,0,0;153,60,15,150,0,660,3;153,60,15,150,0,660,35;153,85,49,150,0,0,0;154,12,15,150,0,0,0;154,12,32,150,0,0,0;154,13,15,150,0,0,0;154,13,32,150,0,0,0;154,22,49,150,0,0,0;154,22,50,150,0,0,0;154,22,51,150,0,0,0;154,26,31,150,0,0,0;154,26,32,150,0,0,0;154,33,16,150,0,0,0;154,34,16,150,0,0,0;155,3,6,149,0,0,0;155,12,8,149,0,0,0;156,2,11,149,0,0,0;158,8,10,149,0,0,0;159,10,11,142,0,0,0;159,10,11,525,0,0,0;160,8,10,142,0,0,0;160,8,10,525,0,0,0;161,6,6,172,0,0,0;161,9,12,142,0,0,0;161,9,12,525,479,0,0;162,10,3,370,0,0,0;162,10,21,151,0,0,0;162,10,21,551,479,0,0;162,15,10,163,0,0,0;163,9,11,899,0,0,0;163,9,14,162,0,0,0;163,11,1,437,0,0,0;164,4,11,79,0,0,0;164,4,11,527,0,0,0;164,24,11,79,0,0,0;164,45,11,79,0,0,0;164,63,11,79,0,0,0;164,63,11,527,479,0,0;164,79,9,899,0,0,0;165,32,11,79,0,0,0;165,32,12,79,0,0,0;165,32,13,79,0,0,0;166,10,11,80,0,0,0;166,10,11,524,0,0,0;167,8,13,80,0,0,0;167,8,13,524,479,0,0;168,3,12,80,0,0,0;168,3,12,524,0,0,0;168,16,44,324,0,0,0;168,16,44,324,127,0,0;168,30,12,80,0,0,0;168,30,12,524,0,0,0;169,4,8,174,0,0,0;169,4,9,80,0,0,0;169,4,12,80,0,0,0;169,4,12,524,0,0,0;169,30,10,80,0,0,0;169,46,11,80,0,0,0;169,46,11,524,0,0,0;169,65,11,80,0,0,0;169,65,11,524,0,0,0;169,81,11,80,0,0,0;169,81,11,524,0,0,0;170,0,21,80,0,0,0;170,0,22,80,0,0,0;171,8,10,80,0,0,0;171,8,10,524,0,0,0;172,9,10,161,0,0,0;172,9,10,173,0,0,0;173,11,8,172,0,0,0;174,9,12,169,0,0,0;175,4,7,176,0,0,0;175,4,7,176,0,104,5;175,4,7,176,0,104,6;175,4,12,80,0,0,0;175,4,12,524,479,0,0;175,11,7,182,0,0,0;176,4,7,175,0,0,0;176,8,9,175,0,0,0;176,10,9,80,0,0,0;176,14,9,182,0,0,0;177,10,11,79,0,0,0;177,10,11,588,0,0,0;177,19,16,178,0,0,0;178,17,39,179,0,0,0;178,20,19,179,0,0,0;178,31,37,179,0,0,0;178,33,27,177,0,0,0;178,35,5,188,0,0,0;178,55,42,179,0,0,0;179,9,31,302,0,0,0;179,21,8,178,0,0,0;179,25,45,178,0,0,0;179,48,6,178,0,0,0;179,57,53,180,0,0,0;179,59,33,303,0,0,0;179,63,42,304,0,0,0;179,69,47,180,0,0,0;179,70,31,180,0,0,0;179,71,26,178,0,0,0;179,77,45,303,0,0,0;180,10,26,79,0,92,11;180,28,19,304,1305,0,0;180,28,25,304,0,0,0;180,29,19,304,1305,0,0;180,42,6,179,0,0,0;180,66,19,179,0,0,0;180,67,32,179,0,0,0;180,71,28,512,0,0,0;181,4,2,193,0,0,0;181,10,1,190,0,0,0;181,10,1,190,0,104,13;181,10,10,80,0,0,0;181,10,12,80,0,0,0;181,10,12,524,0,0,0;181,11,4,80,0,104,22;181,15,1,192,0,0,0;182,0,16,176,0,0,0;182,9,33,175,0,0,0;183,9,4,113,0,0,0;184,11,28,185,0,0,0;184,25,7,743,0,0,0;184,39,34,151,0,0,0;184,39,34,551,0,0,0;185,9,23,186,0,0,0;185,21,18,896,0,725,1;185,22,18,896,0,725,1;185,35,6,184,0,0,0;186,11,24,150,0,0,0;186,13,6,185,0,0,0;188,13,29,178,0,0,0;189,12,14,146,0,0,0;190,11,2,191,0,0,0;190,11,2,191,479,0,0;190,16,2,191,0,0,0;190,16,6,181,0,0,0;191,6,9,190,0,0,0;191,24,10,190,0,0,0;192,2,10,181,0,0,0;193,5,3,181,0,0,0;193,5,11,899,0,0,0;193,16,7,194,0,0,0;194,9,3,195,0,0,0;194,14,38,193,0,0,0;195,7,8,194,0,0,0;195,11,4,181,0,0,0;196,27,5,225,0,107,1;196,27,6,197,0,0,0;196,28,5,225,0,107,1;197,4,22,198,0,0,0;197,9,5,196,0,0,0;197,9,25,146,0,0,0;197,9,25,560,0,0,0;197,14,22,198,0,0,0;198,17,6,281,389,0,0;198,20,22,197,0,0,0;198,28,22,197,0,0,0;198,31,6,281,390,0,0;199,17,27,200,0,0,0;199,18,9,33,0,0,0;199,18,9,34,0,0,0;199,40,9,200,0,0,0;199,61,27,200,0,0,0;200,8,11,35,0,0,0;200,8,11,199,0,0,0;200,14,24,35,0,0,0;200,31,9,35,0,0,0;200,31,9,199,0,0,0;201,10,36,202,0,0,0;201,20,11,203,0,0,0;201,20,11,204,0,0,0;201,21,38,33,0,0,0;201,21,38,34,0,0,0;201,25,32,33,0,0,0;201,25,32,34,0,0,0;201,30,22,33,0,0,0;201,32,10,203,0,0,0;201,32,10,204,0,0,0;202,20,11,203,0,0,0;202,20,11,204,0,0,0;202,21,38,33,0,0,0;202,21,38,34,0,0,0;202,25,32,33,0,0,0;202,25,32,34,0,0,0;202,32,10,203,0,0,0;202,32,10,204,0,0,0;203,8,33,201,0,0,0;203,8,33,202,0,0,0;203,9,9,205,0,0,0;203,20,13,201,0,0,0;203,32,35,201,0,0,0;203,32,35,202,0,0,0;204,8,33,201,0,0,0;204,8,33,202,0,0,0;204,9,9,205,0,0,0;204,32,35,201,0,0,0;204,32,35,202,0,0,0;205,12,9,203,0,0,0;205,12,9,204,0,0,0;205,12,13,27,0,0,0;206,25,8,14,0,0,0;206,25,8,15,0,0,0;206,40,64,207,0,0,0;207,7,3,208,0,0,0;207,7,5,208,0,0,0;207,8,3,208,0,0,0;207,8,5,208,0,0,0;207,9,12,206,0,0,0;207,9,12,569,0,0,0;207,10,12,206,0,0,0;207,10,12,569,0,0,0;208,8,24,207,0,0,0;208,9,7,15,0,118,2;208,9,7,367,0,118,2;208,9,24,207,0,0,0;209,3,67,218,0,0,0;209,5,27,210,0,0,0;209,6,16,210,0,0,0;209,11,43,217,0,0,0;209,12,64,217,0,0,0;209,15,10,212,0,0,0;209,21,46,218,0,0,0;209,21,61,218,0,0,0;209,24,44,215,0,0,0;209,28,7,212,0,0,0;209,32,65,214,0,0,0;209,45,30,211,0,0,0;209,45,38,211,0,0,0;209,56,9,212,0,0,0;209,64,12,211,0,0,0;209,65,16,211,0,0,0;209,75,49,211,190,0,0;209,83,47,211,0,0,0;209,83,71,215,0,0,0;209,84,38,211,0,0,0;209,90,65,216,0,0,0;209,100,23,223,0,0,0;210,4,11,81,0,0,0;210,4,11,528,0,0,0;210,4,11,585,0,0,0;210,5,21,760,0,0,0;210,9,20,209,0,0,0;210,14,11,209,0,0,0;211,8,24,209,0,0,0;211,9,2,209,0,0,0;211,9,24,209,0,0,0;211,23,24,209,0,0,0;211,28,2,209,0,0,0;211,29,7,209,0,0,0;211,31,19,214,0,0,0;211,44,25,209,0,0,0;211,45,5,209,0,0,0;212,8,11,209,0,0,0;212,23,14,209,0,0,0;212,39,31,213,0,0,0;212,48,34,209,0,0,0;213,9,14,212,0,0,0;214,11,12,209,0,0,0;214,22,15,215,0,0,0;214,51,11,215,0,0,0;214,57,21,211,0,0,0;214,57,22,211,0,0,0;215,9,10,209,0,0,0;215,9,10,214,0,0,0;215,9,10,217,0,0,0;215,29,23,209,0,0,0;215,29,23,214,0,0,0;215,29,23,216,0,0,0;216,9,14,215,0,0,0;216,14,22,209,0,0,0;216,16,9,219,194,0,0;217,9,10,209,0,0,0;217,9,21,209,0,0,0;217,29,18,215,0,0,0;217,31,6,218,0,0,0;218,14,14,209,0,0,0;218,14,27,217,0,0,0;218,14,33,209,0,0,0;218,44,14,209,0,0,0;219,15,8,220,0,0,0;219,19,8,222,0,0,0;219,20,21,216,0,0,0;219,29,8,221,0,0,0;220,14,18,219,0,0,0;221,15,17,219,0,0,0;222,9,8,890,0,651,2;222,9,12,219,0,0,0;222,10,8,890,0,651,2;223,0,17,224,0,0,0;223,12,20,209,0,0,0;224,24,14,223,0,0,0;225,1,1,226,0,0,0;225,1,2,226,0,0,0;225,1,3,226,0,0,0;225,3,13,196,0,0,0;225,3,13,634,0,0,0;225,4,13,196,0,0,0;225,4,13,634,0,0,0;225,15,8,228,0,123,9;225,15,9,228,0,123,9;226,11,8,36,0,0,0;226,15,5,225,0,0,0;227,9,79,36,0,0,0;227,9,79,36,0,123,8;227,9,79,36,208,0,0;227,37,6,225,0,0,0;228,0,3,225,0,0,0;228,0,4,225,0,0,0;228,0,15,229,0,0,0;228,0,16,229,0,0,0;228,0,17,229,0,0,0;228,7,19,762,0,0,0;228,13,85,762,0,0,0;228,14,91,88,0,0,0;228,15,37,368,0,0,0;228,20,75,761,0,0,0;228,30,14,368,0,0,0;228,43,2,368,0,0,0;228,44,49,368,0,0,0;228,51,29,761,0,0,0;228,59,26,230,0,0,0;228,59,27,230,0,0,0;228,59,28,230,0,0,0;228,59,29,230,0,0,0;229,1,6,622,0,0,0;229,1,7,622,0,0,0;229,1,8,622,0,0,0;229,6,56,368,0,0,0;229,11,8,368,0,0,0;229,12,56,368,0,0,0;229,28,14,228,0,0,0;229,28,15,228,0,0,0;230,10,27,228,0,0,0;230,10,28,228,0,0,0;230,18,5,231,0,0,0;230,19,28,761,0,0,0;230,23,11,243,0,0,0;230,31,27,234,0,0,0;230,31,28,234,0,0,0;231,13,9,272,0,0,0;231,28,8,232,0,0,0;231,40,80,230,0,0,0;231,67,32,244,0,0,0;232,10,12,233,0,0,0;232,10,12,233,0,149,3;232,10,12,233,0,149,4;232,11,12,233,0,0,0;232,12,12,233,0,0,0;232,12,42,371,0,0,0;232,12,43,371,0,0,0;232,18,68,231,0,0,0;232,19,20,899,0,0,0;232,20,15,233,0,149,1;233,4,52,899,0,0,0;233,9,12,232,0,0,0;233,11,11,232,0,0,0;233,12,11,232,0,0,0;233,12,56,232,0,0,0;233,29,8,266,0,149,3;234,8,27,230,0,0,0;234,8,28,230,0,0,0;234,25,11,238,0,0,0;234,34,57,250,0,0,0;234,35,16,253,0,0,0;234,45,7,271,0,0,0;234,46,7,271,0,0,0;234,55,54,838,0,588,1;234,56,54,838,0,588,1;234,69,22,465,0,0,0;234,70,22,465,0,0,0;234,99,19,251,0,0,0;235,12,39,242,0,0,0;235,12,48,234,0,0,0;235,13,48,234,0,0,0;235,14,32,242,0,0,0;235,31,23,242,0,0,0;236,35,16,251,0,0,0;237,13,13,250,0,0,0;238,14,39,545,0,0,0;238,16,20,546,0,0,0;238,25,29,545,0,0,0;238,31,43,545,0,0,0;238,33,61,234,0,0,0;238,36,25,545,0,0,0;238,40,37,545,0,0,0;238,42,56,545,0,0,0;238,45,27,545,0,0,0;238,53,17,545,0,0,0;238,54,39,546,0,0,0;239,11,3,506,0,123,16;239,11,6,899,0,0,0;239,11,17,271,0,0,0;239,11,39,510,0,123,21;239,12,3,506,0,123,16;239,12,17,271,0,0,0;239,12,39,510,0,123,21;240,10,11,271,0,0,0;241,10,18,242,0,0,0;241,10,19,242,0,0,0;241,37,24,271,0,0,0;242,1,50,241,0,0,0;242,1,51,241,0,0,0;242,3,59,271,0,0,0;242,4,37,271,0,0,0;242,5,24,271,0,0,0;242,5,37,271,0,0,0;242,22,2,271,0,0,0;242,23,24,271,0,0,0;242,24,36,271,0,0,0;242,25,36,271,0,0,0;243,8,10,230,0,0,0;244,12,11,231,0,0,0;244,40,20,246,0,0,0;244,46,22,261,0,149,14;245,2,19,254,0,0,0;245,3,19,254,0,0,0;245,4,19,254,0,0,0;245,6,12,257,0,0,0;245,8,14,265,0,149,14;246,9,4,254,0,0,0;246,9,14,244,0,0,0;247,10,23,259,0,149,21;247,16,52,258,0,0,0;247,23,5,260,0,0,0;247,38,63,261,0,149,14;247,74,62,244,0,0,0;247,74,62,244,259,0,0;248,8,12,97,0,0,0;248,9,12,97,0,0,0;248,10,12,97,0,0,0;249,18,8,275,0,0,0;250,12,6,234,0,0,0;251,8,11,252,0,0,0;251,12,15,252,0,0,0;251,14,6,252,0,0,0;251,14,16,234,0,0,0;252,10,16,251,0,0,0;252,31,17,251,0,0,0;252,49,6,847,0,616,1;252,50,6,847,0,616,1;253,9,10,234,0,0,0;254,7,14,255,0,0,0;254,7,22,255,0,0,0;254,8,14,255,0,0,0;254,13,2,245,0,149,10;254,13,24,246,0,0,0;254,19,14,255,0,0,0;254,19,22,255,0,0,0;254,20,14,255,0,0,0;255,2,19,254,0,0,0;255,18,19,254,0,0,0;255,54,1,254,0,0,0;255,67,1,254,0,0,0;256,9,14,36,0,0,0;256,9,14,520,0,0,0;256,10,14,36,0,0,0;256,10,14,520,0,0,0;257,11,10,258,0,0,0;258,12,6,247,0,149,13;258,12,6,262,0,149,12;258,12,6,263,0,149,11;258,12,6,264,0,0,0;258,17,33,257,0,0,0;259,10,25,511,0,726,2;259,11,25,511,0,726,2;259,40,10,247,0,0,0;260,10,15,614,0,0,0;260,10,15,617,0,0,0;260,37,38,247,0,0,0;260,49,10,614,0,0,0;260,49,10,617,0,0,0;260,62,24,614,0,0,0;260,62,24,617,0,0,0;261,11,23,247,0,0,0;261,39,23,244,0,0,0;262,16,52,258,0,0,0;262,45,79,247,0,0,0;262,46,79,247,0,0,0;262,46,82,247,0,0,0;262,47,79,247,0,0,0;262,48,79,247,0,0,0;262,49,79,247,0,0,0;263,16,52,258,0,0,0;263,62,24,262,0,0,0;263,62,25,262,0,0,0;263,62,26,262,0,0,0;263,62,27,262,0,0,0;263,65,27,262,0,0,0;264,14,9,263,0,0,0;264,14,13,263,0,0,0;264,15,13,263,0,0,0;264,16,13,263,0,0,0;264,16,52,258,0,0,0;264,17,13,263,0,0,0;265,12,9,245,0,0,0;266,10,8,233,0,0,0;267,5,22,164,0,0,0;267,15,22,164,0,0,0;267,18,48,227,0,0,0;267,22,18,165,0,0,0;268,8,9,37,0,0,0;268,8,10,37,0,0,0;268,8,11,37,0,0,0;268,8,12,37,0,0,0;268,8,13,37,0,0,0;268,8,14,37,0,0,0;268,28,9,40,39,0,0;268,28,10,40,39,0,0;268,28,11,40,39,0,0;268,28,12,40,39,0,0;268,28,13,40,39,0,0;268,28,14,40,39,0,0;268,29,8,79,0,0,0;268,30,8,79,0,0,0;268,31,8,79,0,0,0;268,32,8,79,0,0,0;268,33,8,79,0,0,0;268,34,8,79,0,0,0;268,35,8,79,0,0,0;268,36,8,79,0,0,0;268,37,8,79,0,0,0;268,38,8,79,0,0,0;268,39,8,79,0,0,0;268,40,8,79,0,0,0;268,41,8,79,0,0,0;268,41,12,41,0,104,26;268,42,9,40,39,0,0;268,42,10,40,39,0,0;268,42,11,40,39,0,0;268,42,12,40,39,0,0;268,42,12,40,39,104,27;268,42,13,40,39,0,0;268,42,13,40,39,104,27;268,42,14,40,39,0,0;268,59,9,41,0,0,0;268,59,10,41,0,0,0;268,59,11,41,0,0,0;268,59,12,41,0,0,0;268,59,13,41,0,0,0;268,59,14,41,0,0,0;269,16,14,36,0,0,0;269,35,42,36,0,0,0;269,36,42,36,0,0,0;269,38,8,108,0,0,0;270,6,16,253,0,0,0;270,16,7,235,0,0,0;270,17,7,235,0,0,0;271,12,39,242,0,0,0;271,12,48,234,0,0,0;271,13,48,234,0,0,0;271,14,32,242,0,0,0;271,31,23,242,0,0,0;271,35,15,242,0,0,0;271,36,18,242,0,0,0;271,36,23,242,0,0,0;271,36,23,242,1558,0,0;271,39,19,241,0,0,0;271,45,14,240,0,0,0;271,56,8,239,0,123,14;271,56,10,239,0,123,20;271,57,8,239,0,123,14;272,11,7,282,0,0,0;272,15,55,231,0,0,0;272,24,38,273,0,0,0;272,24,39,273,0,0,0;273,8,13,272,0,0,0;273,8,14,272,0,0,0;273,25,34,274,0,0,0;274,11,8,273,0,0,0;275,9,11,249,0,0,0;275,17,14,276,0,0,0;276,10,6,275,0,0,0;276,20,16,277,0,0,0;277,13,6,276,0,0,0;277,20,6,278,0,0,0;278,9,8,279,0,0,0;278,15,13,277,0,0,0;278,75,10,279,0,0,0;278,96,7,280,0,0,0;279,4,10,278,0,0,0;279,47,13,278,0,0,0;280,11,7,874,0,636,1;280,12,7,874,0,636,1;280,14,14,278,0,0,0;281,3,8,198,0,0,0;281,16,37,198,0,0,0;282,12,7,285,0,0,0;282,13,7,285,0,0,0;282,17,52,272,0,0,0;282,33,46,834,0,572,2;282,34,46,834,0,572,2;282,38,7,285,0,0,0;282,39,7,285,0,0,0;282,52,7,285,0,0,0;282,53,7,285,0,0,0;283,12,5,286,0,0,0;283,13,5,286,0,0,0;283,26,5,286,0,0,0;283,27,5,286,0,0,0;283,55,5,286,0,0,0;283,56,5,286,0,0,0;284,16,7,287,0,0,0;284,17,7,287,0,0,0;284,36,7,287,0,0,0;284,37,7,287,0,0,0;285,9,41,282,0,0,0;285,10,41,282,0,0,0;285,59,41,282,0,0,0;285,60,41,282,0,0,0;285,66,8,289,0,0,0;285,67,8,289,0,0,0;285,76,41,282,0,0,0;285,77,41,282,0,0,0;286,11,39,283,0,0,0;286,12,39,283,0,0,0;286,30,10,288,0,0,0;286,31,10,288,0,0,0;286,34,39,283,0,0,0;286,35,39,283,0,0,0;286,59,10,288,0,0,0;286,60,10,288,0,0,0;286,72,39,283,0,0,0;286,73,39,283,0,0,0;286,76,10,288,0,0,0;286,77,10,288,0,0,0;287,8,12,289,0,0,0;287,9,12,289,0,0,0;287,19,43,284,0,0,0;287,20,43,284,0,0,0;287,34,12,289,0,0,0;287,35,12,289,0,0,0;287,59,43,284,0,0,0;287,60,43,284,0,0,0;287,69,12,289,0,0,0;287,70,12,289,0,0,0;288,12,18,434,0,0,0;288,15,52,286,0,0,0;288,16,52,286,0,0,0;288,26,52,286,0,0,0;288,27,52,286,0,0,0;288,34,52,286,0,0,0;288,35,52,286,0,0,0;289,23,52,285,0,0,0;289,24,52,285,0,0,0;289,35,10,299,0,0,0;289,49,52,287,0,0,0;289,50,52,287,0,0,0;289,57,9,834,0,572,2;289,58,9,834,0,572,2;289,63,52,287,0,0,0;289,64,52,287,0,0,0;289,80,52,287,0,0,0;289,81,52,287,0,0,0;290,14,12,294,0,0,0;290,18,10,833,0,572,2;290,19,10,833,0,572,2;290,20,18,294,0,0,0;290,20,97,295,0,0,0;290,20,97,572,0,0,0;290,21,97,295,0,0,0;290,21,97,572,0,0,0;290,22,97,295,0,0,0;290,22,97,572,0,0,0;290,23,97,295,0,0,0;290,23,97,572,0,0,0;290,24,97,295,0,0,0;290,24,97,572,0,0,0;290,25,97,295,0,0,0;290,25,97,572,0,0,0;290,26,97,295,0,0,0;290,26,97,572,0,0,0;290,27,97,295,0,0,0;290,27,97,572,0,0,0;290,28,97,295,0,0,0;290,28,97,572,0,0,0;290,31,90,291,0,150,24;290,31,90,291,2226,150,24;291,53,24,290,0,150,24;291,53,24,290,2226,150,24;291,63,30,333,0,0,0;292,15,15,293,0,0,0;292,15,15,293,1305,0,0;292,16,15,293,0,0,0;292,16,15,293,1305,0,0;292,44,8,336,0,0,0;293,5,31,899,0,0,0;293,9,3,319,0,0,0;293,9,12,292,0,0,0;293,9,24,831,0,562,1;293,9,29,313,0,150,27;293,9,29,313,1305,0,0;293,10,3,319,0,0,0;293,10,7,292,0,159,2;293,10,12,292,0,0,0;293,10,24,831,0,562,1;293,10,29,313,0,150,27;293,10,29,313,1305,0,0;294,9,49,290,0,0,0;294,13,13,290,0,0,0;295,0,9,296,0,0,0;295,0,9,312,0,150,22;295,0,10,296,0,0,0;295,0,10,312,0,150,22;295,11,5,290,0,0,0;295,11,13,79,0,150,22;296,5,8,302,0,150,12;296,5,9,302,0,150,14;296,17,8,295,0,0,0;296,17,9,295,0,0,0;297,25,12,298,0,0,0;298,8,1,354,0,0,0;298,8,1,355,0,173,2;298,8,1,763,0,0,0;298,8,14,297,0,0,0;299,9,13,289,0,0,0;300,22,25,288,0,0,0;300,24,7,301,0,0,0;301,42,7,300,0,0,0;302,10,42,179,0,0,0;302,20,10,296,0,150,14;302,20,10,312,0,150,23;303,11,12,179,0,0,0;303,28,18,179,0,0,0;304,10,33,180,1305,0,0;304,11,33,180,1305,0,0;304,12,6,305,0,0,0;304,12,6,305,0,150,14;304,12,6,899,0,150,14;304,12,33,180,1305,0,0;304,13,33,180,1305,0,0;304,30,7,179,0,0,0;305,23,19,307,0,0,0;305,23,19,899,0,0,0;305,23,31,304,0,0,0;305,23,31,304,0,150,22;305,23,31,304,0,150,23;305,23,31,899,0,150,23;305,24,19,307,0,0,0;305,24,19,899,0,0,0;306,11,10,823,0,0,0;306,11,10,899,0,0,0;306,12,10,823,0,0,0;306,12,10,899,0,0,0;306,32,26,824,0,552,23;306,32,26,902,0,773,1;306,33,26,824,0,552,23;306,33,26,902,0,773,1;306,33,27,312,0,0,0;306,53,10,310,0,0,0;306,54,10,310,0,0,0;307,6,2,822,0,0,0;307,6,2,899,0,0,0;307,7,2,822,0,0,0;307,7,2,899,0,0,0;307,8,14,305,0,0,0;307,8,14,899,0,0,0;307,9,14,305,0,0,0;307,9,14,899,0,0,0;307,13,2,310,0,150,17;307,14,2,310,0,150,17;308,3,11,822,0,475,100;308,3,12,822,0,475,100;308,4,11,822,0,475,100;308,4,12,822,0,475,100;308,9,3,309,0,0,0;308,9,3,899,0,0,0;308,10,3,309,0,0,0;308,10,3,899,0,0,0;308,15,3,310,0,0,0;308,15,4,310,0,0,0;308,15,11,311,0,0,0;308,15,12,311,0,0,0;308,16,3,310,0,0,0;308,16,4,310,0,0,0;308,16,11,311,0,0,0;308,16,12,311,0,0,0;309,3,2,823,0,0,0;309,3,2,899,0,0,0;309,4,2,823,0,0,0;309,4,2,899,0,0,0;309,9,3,308,0,0,0;309,9,3,899,0,0,0;309,10,3,308,0,0,0;309,10,3,899,0,0,0;309,15,2,310,0,150,20;309,16,2,310,0,150,20;310,7,8,307,0,0,0;310,7,19,308,0,150,18;310,7,20,308,0,150,18;310,7,63,306,0,0,0;310,7,79,309,0,0,0;310,8,8,307,0,0,0;310,8,19,308,0,150,18;310,8,20,308,0,150,18;310,8,63,306,0,0,0;310,8,79,309,0,0,0;311,8,4,308,0,0,0;311,8,5,308,0,0,0;311,9,4,308,0,0,0;311,9,5,308,0,0,0;312,5,9,302,0,150,14;312,17,8,295,0,0,0;312,17,9,295,0,0,0;313,1,16,314,0,0,0;313,1,16,314,1305,0,0;313,1,17,314,0,0,0;313,1,17,314,283,0,0;313,1,17,314,1305,0,0;313,9,5,316,0,150,31;313,9,5,316,1305,0,0;313,9,20,293,0,0,0;313,9,20,293,283,0,0;313,9,20,293,1305,0,0;313,10,5,316,0,150,31;313,10,5,316,1305,0,0;313,10,20,293,0,0,0;313,10,20,293,283,0,0;313,10,20,293,1305,0,0;314,21,9,313,0,0,0;314,21,9,313,283,0,0;314,21,9,313,1305,0,0;314,21,10,313,0,0,0;314,21,10,313,283,0,0;314,21,10,313,1305,0,0;315,9,34,318,0,0,0;315,9,34,318,1305,0,0;315,10,10,527,0,670,3;315,10,34,318,0,0,0;315,10,34,318,1305,0,0;316,9,5,317,0,150,34;316,9,5,317,1305,0,0;316,9,20,313,0,0,0;316,9,20,313,283,0,0;316,9,20,313,1305,0,0;316,10,5,317,0,150,34;316,10,5,317,1305,0,0;316,10,20,313,0,0,0;316,10,20,313,1305,0,0;317,9,5,318,0,150,37;317,9,5,318,1305,0,0;317,9,20,316,0,0,0;317,9,20,316,1305,0,0;317,10,5,318,0,150,37;317,10,5,318,1305,0,0;317,10,20,316,0,0,0;317,10,20,316,1305,0,0;318,9,5,315,0,150,40;318,9,5,315,0,150,42;318,9,5,315,1305,0,0;318,9,20,317,0,0,0;318,9,20,317,1305,0,0;318,10,5,315,0,150,40;318,10,5,315,0,150,42;318,10,5,315,1305,0,0;318,10,20,317,0,0,0;318,10,20,317,1305,0,0;319,14,6,293,0,0,0;320,3,4,321,0,0,0;320,13,11,96,0,0,0;320,14,11,96,0,0,0;321,14,44,320,0,0,0;322,15,14,80,0,0,0;322,15,14,524,0,0,0;322,15,15,80,0,0,0;322,15,15,524,0,0,0;323,14,3,764,0,0,0;323,14,4,29,0,0,0;323,15,3,764,0,0,0;324,5,30,168,0,0,0;324,6,8,168,0,0,0;324,11,34,352,0,159,12;324,21,14,327,0,0,0;324,22,9,637,0,0,0;324,28,30,326,0,0,0;324,30,8,328,0,0,0;324,40,12,325,0,0,0;324,40,33,325,0,0,0;325,13,20,324,0,0,0;325,30,20,324,0,0,0;326,4,14,324,0,0,0;327,4,3,478,0,0,0;327,10,11,324,0,0,0;327,11,11,324,0,0,0;328,4,29,329,0,0,0;328,5,22,291,0,0,0;328,5,29,329,0,0,0;328,6,29,329,0,0,0;328,11,20,62,0,0,0;328,75,22,324,0,0,0;329,24,2,328,0,0,0;329,24,69,330,0,0,0;329,25,2,328,0,0,0;329,25,23,331,0,159,12;329,25,69,330,0,0,0;329,26,2,328,0,0,0;329,26,69,330,0,0,0;329,27,69,330,0,0,0;329,30,51,328,0,0,0;330,0,19,332,0,0,0;330,0,19,332,0,628,9;330,0,19,332,0,628,10;330,0,19,871,0,628,9;330,0,20,332,0,0,0;330,0,20,332,0,628,9;330,0,20,332,0,628,10;330,0,20,871,0,628,9;330,0,21,332,0,0,0;330,0,21,332,0,628,9;330,0,21,332,0,628,10;330,0,21,871,0,628,9;330,3,34,331,0,0,0;330,7,4,331,0,0,0;330,9,10,331,0,0,0;330,9,26,331,0,0,0;330,13,16,331,0,0,0;330,20,25,331,0,0,0;330,21,9,331,0,0,0;330,23,0,329,0,0,0;330,23,0,329,0,628,9;330,23,0,329,0,628,10;330,23,0,871,0,628,9;330,23,39,331,0,0,0;330,23,39,331,0,628,9;330,23,39,331,0,628,10;330,23,39,871,0,628,9;330,24,0,329,0,0,0;330,24,0,329,0,628,9;330,24,0,329,0,628,10;330,24,0,871,0,628,9;330,24,5,331,0,0,0;330,24,39,331,0,0,0;330,24,39,331,0,628,9;330,24,39,331,0,628,10;330,24,39,871,0,628,9;330,25,0,329,0,0,0;330,25,0,329,0,628,9;330,25,0,329,0,628,10;330,25,0,871,0,628,9;330,25,39,331,0,0,0;330,25,39,331,0,628,9;330,25,39,331,0,628,10;330,25,39,871,0,628,9;330,26,0,329,0,0,0;330,26,0,329,0,628,9;330,26,0,329,0,628,10;330,26,0,871,0,628,9;330,26,39,331,0,0,0;330,26,39,331,0,628,9;330,26,39,331,0,628,10;330,26,39,871,0,628,9;330,27,29,331,0,0,0;330,32,12,331,0,0,0;330,32,18,331,0,0,0;330,37,4,331,0,0,0;330,41,18,331,0,0,0;330,41,21,331,0,0,0;330,46,31,331,0,0,0;330,49,19,332,0,0,0;330,49,19,332,0,628,9;330,49,19,332,0,628,10;330,49,19,871,0,628,9;330,49,20,332,0,0,0;330,49,20,332,0,628,9;330,49,20,332,0,628,10;330,49,20,871,0,628,9;330,49,21,332,0,0,0;330,49,21,332,0,628,9;330,49,21,332,0,628,10;330,49,21,871,0,628,9;331,6,2,330,0,0,0;331,7,2,330,0,0,0;331,8,2,330,0,0,0;331,9,2,330,0,0,0;332,1,6,330,0,0,0;332,1,7,330,0,0,0;332,1,8,330,0,0,0;332,34,3,328,0,628,10;332,36,3,871,0,628,1;332,36,3,871,0,628,9;332,37,3,871,0,628,1;332,37,3,871,0,628,9;332,41,6,330,0,0,0;332,41,7,330,0,0,0;332,41,8,330,0,0,0;333,9,24,291,0,0,0;333,10,22,337,0,0,0;333,29,6,338,0,163,3;333,38,36,341,0,165,3;333,38,36,346,0,165,3;333,45,41,346,0,0,0;333,46,22,340,0,164,3;333,46,22,507,0,164,3;334,11,11,342,0,167,3;334,11,11,347,0,167,3;334,15,9,342,0,166,3;334,15,9,347,0,166,3;334,39,1,341,0,0,0;335,9,8,347,0,0,0;335,13,3,342,0,0,0;335,18,1,342,0,0,0;335,18,1,347,0,0,0;335,23,23,344,0,168,3;335,23,23,349,0,168,3;335,23,43,344,0,0,0;335,28,51,345,0,171,3;335,32,38,349,0,0,0;335,35,34,344,0,170,3;335,35,34,349,0,170,3;335,43,23,343,0,169,3;335,43,23,348,0,169,3;335,43,29,348,0,0,0;336,10,31,292,0,0,0;336,17,6,337,0,162,3;337,9,10,336,0,0,0;337,12,10,345,0,0,0;337,19,13,333,0,0,0;338,12,33,333,0,0,0;339,11,7,893,0,697,1;339,11,7,893,0,697,25;339,11,7,893,0,697,26;339,11,7,893,0,697,27;339,12,7,893,0,697,1;339,12,7,893,0,697,25;339,12,7,893,0,697,26;339,12,7,893,0,697,27;340,12,13,333,0,0,0;341,8,8,333,0,0,0;341,12,28,334,0,0,0;342,16,33,335,0,0,0;342,18,9,334,0,0,0;342,21,33,335,0,0,0;342,26,7,334,0,0,0;343,8,9,335,0,0,0;344,10,28,335,0,0,0;344,15,8,335,0,0,0;344,26,18,335,0,0,0;345,15,38,335,0,0,0;345,20,33,337,2193,0,0;346,8,8,333,0,0,0;346,31,14,333,0,0,0;347,10,33,335,0,0,0;347,18,9,334,0,0,0;347,21,33,335,0,0,0;347,26,7,334,0,0,0;348,8,9,335,0,0,0;348,13,26,335,0,0,0;349,15,8,335,0,0,0;349,19,28,335,0,0,0;349,26,18,335,0,0,0;351,12,24,78,0,0,0;352,9,14,324,0,0,0;352,10,14,324,0,0,0;353,1,24,50,0,0,0;353,11,11,54,0,0,0;353,13,7,52,0,0,0;353,16,52,43,0,0,0;353,17,43,42,0,0,0;353,23,28,78,61,0,0;353,27,9,53,0,0,0;353,34,11,268,0,0,0;353,34,12,268,0,0,0;353,34,13,268,0,0,0;353,34,14,268,0,0,0;353,34,15,268,0,0,0;353,34,16,268,0,0,0;353,34,60,29,0,0,0;353,34,61,29,0,0,0;353,34,62,29,0,0,0;353,34,63,29,0,0,0;353,34,64,29,0,0,0;353,34,65,29,0,0,0;353,34,66,29,0,0,0;354,34,86,298,0,0,0;354,35,86,298,0,0,0;354,36,80,355,0,0,0;354,36,86,298,0,0,0;354,37,86,298,0,0,0;354,38,86,298,0,0,0;355,12,33,365,0,0,0;355,12,34,365,0,0,0;355,30,12,356,0,0,0;355,31,12,356,0,0,0;355,43,8,867,0,0,0;355,44,8,867,0,0,0;355,51,20,365,0,0,0;356,14,31,355,0,0,0;356,15,31,355,0,0,0;356,22,19,357,0,173,12;356,22,19,357,0,276,38;356,30,19,357,0,0,0;357,2,7,356,0,173,10;357,2,7,356,0,173,11;357,3,6,356,0,276,37;357,4,11,356,0,0,0;357,4,11,765,0,0,0;357,5,5,446,0,193,31;357,5,5,446,0,193,32;357,5,11,356,0,0,0;357,5,11,765,0,0,0;358,18,13,364,0,0,0;358,18,13,390,0,0,0;358,40,66,360,0,0,0;358,45,66,360,0,0,0;358,46,66,360,0,0,0;358,47,12,361,2040,0,0;358,55,60,365,0,0,0;358,55,61,365,0,0,0;359,19,11,362,0,0,0;359,19,11,508,0,0,0;359,20,65,466,0,0,0;359,20,65,589,0,0,0;359,21,46,380,0,0,0;359,21,65,466,0,0,0;359,21,65,589,0,0,0;359,22,17,362,0,0,0;359,22,17,362,0,276,31;359,22,17,362,0,276,32;359,22,17,362,0,276,33;359,22,17,508,0,0,0;359,22,45,380,0,0,0;359,22,65,466,0,0,0;359,22,65,589,0,0,0;359,23,10,509,0,0,0;359,23,44,380,0,0,0;359,23,65,466,0,0,0;359,23,65,589,0,0,0;359,24,44,380,0,0,0;359,24,65,466,0,0,0;359,24,65,589,0,0,0;359,25,43,380,0,0,0;359,25,65,466,0,0,0;359,25,65,589,0,0,0;359,26,43,380,0,0,0;359,26,65,466,0,0,0;359,26,65,589,0,0,0;359,27,43,380,0,0,0;359,27,65,466,0,0,0;359,27,65,589,0,0,0;359,28,44,380,0,0,0;359,28,65,466,0,0,0;359,28,65,589,0,0,0;359,29,44,380,0,0,0;359,29,65,466,0,0,0;359,29,65,589,0,0,0;359,30,45,380,0,0,0;359,30,65,466,0,0,0;359,30,65,589,0,0,0;359,31,65,466,0,0,0;359,31,65,589,0,0,0;359,51,52,360,0,0,0;359,51,53,360,0,0,0;359,51,54,360,0,0,0;359,51,55,360,0,0,0;359,51,56,360,0,0,0;359,51,58,360,0,0,0;360,10,91,359,0,0,0;360,10,92,359,0,0,0;360,10,93,359,0,0,0;360,10,94,359,0,0,0;360,10,95,359,0,0,0;360,10,97,359,0,0,0;360,19,8,439,0,0,0;360,25,90,636,0,0,0;360,40,12,358,0,0,0;360,45,12,358,0,0,0;360,46,12,358,0,0,0;361,7,16,364,0,0,0;361,7,16,390,0,0,0;361,7,16,390,0,184,15;361,24,6,418,0,0,0;361,37,27,358,2040,0,0;361,38,6,438,0,0,0;362,2,6,508,0,0,0;362,3,6,508,0,0,0;362,11,11,508,0,276,32;362,11,12,359,0,0,0;362,15,24,359,0,0,0;362,16,5,509,0,0,0;362,28,16,508,579,0,0;362,31,22,359,0,0,0;364,30,7,366,0,0,0;364,57,35,366,0,185,2;364,57,35,375,0,185,1;364,76,18,366,0,0,0;364,76,61,375,0,0,0;364,77,18,366,0,0,0;364,77,61,375,0,0,0;364,78,18,366,0,0,0;364,78,61,375,0,0,0;364,79,18,366,0,0,0;364,79,61,375,0,0,0;364,80,18,366,0,0,0;364,80,61,375,0,0,0;364,81,18,366,0,0,0;364,81,61,375,0,0,0;364,82,18,366,0,0,0;364,82,61,375,0,0,0;364,97,20,361,0,0,0;364,97,39,358,0,0,0;365,3,7,355,0,0,0;365,3,8,355,0,0,0;365,3,63,358,0,0,0;365,3,64,358,0,0,0;365,16,35,355,0,0,0;365,16,36,355,0,0,0;365,19,7,298,0,0,0;365,19,7,354,0,0,0;365,19,7,763,0,0,0;365,19,8,298,0,0,0;365,19,8,354,0,0,0;365,19,8,763,0,0,0;366,0,13,359,0,0,0;366,0,14,359,0,0,0;366,0,15,359,0,0,0;366,1,14,359,0,0,0;366,11,17,373,0,0,0;366,12,17,373,0,0,0;366,13,17,373,0,0,0;366,14,17,373,0,0,0;366,15,17,373,0,0,0;366,16,17,373,0,0,0;366,16,54,364,0,0,0;366,17,17,373,0,0,0;366,39,25,364,0,185,1;366,39,25,373,0,185,2;366,57,46,364,0,0,0;366,57,46,390,0,0,0;366,58,46,364,0,0,0;366,58,46,390,0,0,0;366,59,12,373,0,0,0;366,59,46,364,0,0,0;366,59,46,390,0,0,0;366,60,46,364,0,0,0;366,60,46,390,0,0,0;366,61,46,364,0,0,0;366,61,46,390,0,0,0;366,62,46,364,0,0,0;366,62,46,390,0,0,0;366,63,46,364,0,0,0;366,63,46,390,0,0,0;367,9,7,208,0,0,0;368,2,7,228,0,0,0;368,4,20,228,0,0,0;368,17,7,228,0,0,0;368,17,20,229,0,0,0;368,32,7,228,0,0,0;368,32,20,229,0,0,0;368,47,20,229,0,0,0;369,8,13,36,0,0,0;369,8,13,520,0,0,0;369,9,13,36,0,0,0;369,9,13,520,0,0,0;370,9,19,162,0,0,0;371,23,11,615,0,0,0;371,23,11,618,0,0,0;371,33,14,232,0,0,0;371,33,15,232,0,0,0;372,12,8,381,0,0,0;373,10,35,366,0,0,0;373,11,35,366,0,0,0;373,12,35,366,0,0,0;373,13,35,366,0,0,0;373,14,35,366,0,0,0;373,15,35,366,0,0,0;373,16,35,366,0,0,0;373,22,11,366,0,185,1;373,22,11,374,0,185,2;373,45,7,374,0,0,0;373,50,38,366,0,0,0;373,51,26,439,0,0,0;374,17,22,373,0,0,0;374,18,22,373,0,0,0;374,19,22,373,0,0,0;374,20,22,373,0,0,0;374,21,22,373,0,0,0;374,21,31,457,0,0,0;374,22,22,373,0,0,0;374,33,14,373,0,0,0;374,45,9,440,0,0,0;375,28,28,364,0,185,2;375,28,28,376,0,185,1;375,38,11,364,0,0,0;375,38,11,390,0,0,0;375,39,11,364,0,0,0;375,39,11,390,0,0,0;375,40,11,364,0,0,0;375,40,11,390,0,0,0;375,41,11,364,0,0,0;375,41,11,390,0,0,0;375,42,11,364,0,0,0;375,42,11,390,0,0,0;375,43,11,364,0,0,0;375,43,11,390,0,0,0;375,44,11,364,0,0,0;375,44,11,390,0,0,0;376,34,31,375,0,185,2;376,34,31,377,0,185,1;376,61,35,377,0,0,0;376,62,35,377,0,0,0;376,63,35,377,0,0,0;376,64,35,377,0,0,0;377,28,26,376,0,185,2;377,28,26,378,0,185,1;377,53,27,376,0,0,0;377,54,27,376,0,0,0;377,55,27,376,0,0,0;378,21,14,377,0,185,2;378,21,14,379,0,185,1;379,19,15,378,0,0,0;379,20,15,378,0,0,0;379,21,15,378,0,0,0;379,22,15,378,0,0,0;379,23,15,378,0,0,0;379,24,15,378,0,0,0;380,37,57,359,0,0,0;380,38,57,359,0,0,0;380,39,57,359,0,0,0;380,40,57,359,0,0,0;380,41,57,359,0,0,0;380,42,57,359,0,0,0;380,43,57,359,0,0,0;380,44,57,359,0,0,0;380,45,57,359,0,0,0;380,51,6,384,0,0,0;380,51,6,430,0,0,0;380,56,40,386,0,0,0;380,57,40,386,0,0,0;380,58,40,386,0,0,0;380,59,40,386,0,0,0;380,60,40,386,0,0,0;381,16,31,372,0,0,0;381,29,9,382,0,0,0;382,35,9,146,0,0,0;382,35,9,560,0,0,0;382,46,48,429,0,0,0;382,53,67,381,0,0,0;382,66,20,383,0,0,0;382,67,20,383,0,0,0;382,68,20,383,0,0,0;382,69,20,383,0,0,0;383,10,24,382,0,0,0;383,11,24,382,0,0,0;383,12,24,382,0,0,0;383,13,24,382,0,0,0;383,28,8,884,0,650,1;383,29,8,884,0,650,1;384,70,21,385,0,0,0;384,71,21,385,0,0,0;384,72,21,385,0,0,0;384,73,21,385,0,0,0;384,74,21,385,0,0,0;384,75,21,385,0,0,0;384,76,21,385,0,0,0;384,77,21,385,0,0,0;384,94,50,380,0,0,0;385,12,62,384,0,0,0;385,12,62,430,0,0,0;385,13,62,384,0,0,0;385,13,62,430,0,0,0;385,14,62,384,0,0,0;385,14,62,430,0,0,0;385,15,62,384,0,0,0;385,15,62,430,0,0,0;385,16,62,384,0,0,0;385,16,62,430,0,0,0;385,17,62,384,0,0,0;385,17,62,430,0,0,0;385,18,62,384,0,0,0;385,18,62,430,0,0,0;385,19,62,384,0,0,0;385,19,62,430,0,0,0;385,35,36,396,0,0,0;385,36,36,396,0,0,0;385,37,36,396,0,0,0;385,38,36,396,0,0,0;385,39,36,396,0,0,0;386,11,15,380,0,0,0;386,12,15,380,0,0,0;386,13,15,380,0,0,0;386,14,15,380,0,0,0;386,15,15,380,0,0,0;386,42,46,387,0,0,0;386,43,46,387,0,0,0;386,44,46,387,0,0,0;386,45,46,387,0,0,0;386,46,46,387,0,0,0;387,47,18,386,0,0,0;387,48,18,386,0,0,0;387,49,18,386,0,0,0;387,50,18,386,0,0,0;387,51,18,386,0,0,0;387,52,18,386,0,0,0;388,16,8,870,0,631,1;388,16,8,870,0,631,5;388,17,8,870,0,631,1;388,17,8,870,0,631,5;389,53,34,393,0,0,0;390,30,7,366,0,0,0;390,76,18,366,0,0,0;390,76,61,375,0,0,0;390,77,18,366,0,0,0;390,77,61,375,0,0,0;390,78,18,366,0,0,0;390,78,61,375,0,0,0;390,79,18,366,0,0,0;390,79,61,375,0,0,0;390,80,18,366,0,0,0;390,80,61,375,0,0,0;390,81,18,366,0,0,0;390,81,61,375,0,0,0;390,82,18,366,0,0,0;390,82,61,375,0,0,0;390,97,20,361,0,0,0;390,97,39,358,0,0,0;392,19,45,463,0,0,0;393,31,31,389,0,0,0;393,54,30,402,0,0,0;394,13,41,395,0,0,0;395,34,16,394,0,0,0;396,20,33,385,0,0,0;396,21,33,385,0,0,0;396,22,33,385,0,0,0;396,23,33,385,0,0,0;396,24,33,385,0,0,0;400,54,18,401,0,0,0;401,16,9,400,0,0,0;401,17,9,400,0,0,0;402,16,60,403,0,0,0;402,39,8,393,0,0,0;403,13,17,856,0,622,1;403,14,17,856,0,622,1;403,42,8,402,0,0,0;404,15,12,405,0,0,0;404,27,15,405,0,0,0;404,62,12,409,0,0,0;404,62,20,409,0,0,0;404,86,15,410,0,0,0;404,120,13,411,0,0,0;404,120,22,411,0,0,0;405,12,31,404,0,0,0;405,21,6,835,0,586,1;405,22,6,835,0,586,1;405,40,8,407,0,0,0;405,52,31,404,0,0,0;406,7,14,775,0,0,0;406,7,15,775,0,0,0;406,16,0,417,0,0,0;406,16,27,407,0,0,0;406,35,27,408,0,0,0;406,49,27,408,0,0,0;407,8,5,406,0,0,0;407,8,13,405,0,0,0;408,2,14,409,0,0,0;408,11,3,406,0,0,0;408,11,14,410,0,0,0;408,20,14,411,0,0,0;408,25,3,406,0,0,0;408,25,14,411,0,0,0;409,15,27,404,0,0,0;409,30,45,410,0,0,0;409,45,52,404,0,0,0;409,48,10,408,0,0,0;410,16,19,409,0,0,0;410,24,43,404,0,0,0;410,29,5,408,0,0,0;411,13,6,408,0,0,0;411,14,31,404,0,0,0;411,47,7,408,0,0,0;411,60,22,404,0,0,0;412,11,18,418,0,0,0;412,60,32,710,0,0,0;413,8,18,414,0,0,0;413,8,19,414,0,0,0;413,8,20,414,0,0,0;413,8,21,414,0,0,0;413,8,22,414,0,0,0;413,8,23,414,0,0,0;413,8,24,414,0,0,0;413,8,25,414,0,0,0;413,8,26,414,0,0,0;413,20,13,417,0,0,0;413,26,41,418,0,0,0;413,27,41,418,0,0,0;413,28,31,417,0,0,0;413,28,41,418,0,0,0;413,29,21,417,0,0,0;413,33,9,419,0,0,0;413,34,9,419,0,0,0;413,45,27,415,0,0,0;413,46,14,417,0,0,0;413,54,31,417,0,0,0;413,57,13,417,0,0,0;413,66,12,416,0,0,0;413,69,68,766,0,0,0;413,69,85,419,0,0,0;413,70,85,419,0,0,0;413,78,26,418,0,0,0;414,12,12,632,0,611,4;414,12,18,774,0,0,0;414,16,35,774,0,475,27;414,19,16,774,0,0,0;414,19,30,774,0,0,0;414,27,40,899,0,0,0;414,33,43,774,0,0,0;414,35,21,773,0,0,0;414,43,35,774,0,0,0;414,45,9,768,0,0,0;414,45,9,768,0,475,32;414,46,9,768,0,0,0;414,46,9,768,0,475,32;414,59,21,772,0,0,0;414,63,11,774,0,0,0;414,68,42,774,0,0,0;414,84,32,413,0,0,0;414,84,33,413,0,0,0;414,84,34,413,0,0,0;414,84,35,413,0,0,0;414,84,36,413,0,0,0;414,84,37,413,0,0,0;414,84,38,413,0,0,0;414,84,39,413,0,0,0;414,84,40,413,0,0,0;415,10,11,413,0,0,0;416,8,10,413,0,0,0;417,11,9,413,0,0,0;417,11,29,413,0,0,0;417,11,48,413,0,0,0;417,11,57,413,0,0,0;417,12,9,413,0,0,0;417,13,66,406,0,0,0;417,33,2,413,0,214,9;417,37,8,413,0,0,0;417,38,47,413,0,0,0;418,4,2,413,0,0,0;418,4,11,361,0,0,0;418,16,7,413,0,0,0;418,29,7,412,0,0,0;419,8,62,413,0,0,0;419,9,3,413,0,0,0;419,9,62,413,0,0,0;419,10,62,413,0,0,0;420,6,2,81,0,0,0;420,6,12,97,0,0,0;420,7,2,81,0,0,0;420,7,12,97,0,0,0;420,8,2,81,0,0,0;420,8,12,97,0,0,0;420,9,2,81,0,0,0;420,9,12,97,0,0,0;420,10,2,81,0,0,0;420,10,12,97,0,0,0;420,11,2,81,0,0,0;420,11,12,97,0,0,0;420,12,2,81,0,0,0;420,12,12,97,0,0,0;421,6,2,115,0,0,0;421,6,14,36,0,0,0;421,7,2,115,0,0,0;421,7,14,36,0,0,0;421,8,2,115,0,0,0;421,8,14,36,0,0,0;421,9,2,115,0,0,0;421,9,14,36,0,0,0;421,10,2,115,0,0,0;421,10,14,36,0,0,0;421,11,2,115,0,0,0;421,11,14,36,0,0,0;421,12,2,115,0,0,0;421,12,14,36,0,0,0;422,6,2,142,0,0,0;422,6,14,130,0,0,0;422,7,2,142,0,0,0;422,7,14,130,0,0,0;422,8,2,142,0,0,0;422,8,14,130,0,0,0;422,9,2,142,0,0,0;422,9,14,130,0,0,0;422,10,2,142,0,0,0;422,10,14,130,0,0,0;422,11,2,142,0,0,0;422,11,14,130,0,0,0;422,12,2,142,0,0,0;422,12,14,130,0,0,0;423,6,2,130,0,0,0;423,6,14,57,0,0,0;423,7,2,130,0,0,0;423,7,14,57,0,0,0;423,8,2,130,0,0,0;423,8,14,57,0,0,0;423,9,2,130,0,0,0;423,9,14,57,0,0,0;423,10,2,130,0,0,0;423,10,14,57,0,0,0;423,11,2,130,0,0,0;423,11,14,57,0,0,0;423,12,2,130,0,0,0;423,12,14,57,0,0,0;424,2,5,80,0,0,0;424,2,5,524,0,0,0;424,2,6,80,0,0,0;424,2,6,524,0,0,0;424,13,5,79,0,0,0;424,13,5,527,0,0,0;424,13,6,79,0,0,0;424,13,6,527,479,0,0;425,9,2,113,0,0,0;426,6,26,149,0,0,0;426,9,8,427,0,0,0;426,14,0,428,0,0,0;426,15,0,428,0,0,0;426,16,0,428,0,0,0;426,20,8,427,0,0,0;427,5,13,426,0,0,0;427,15,13,426,0,0,0;428,24,8,426,0,0,0;428,25,8,426,0,0,0;428,26,8,426,0,0,0;429,14,15,382,0,0,0;430,70,21,385,0,0,0;430,71,21,385,0,0,0;430,72,21,385,0,0,0;430,73,21,385,0,0,0;430,74,21,385,0,0,0;430,75,21,385,0,0,0;430,76,21,385,0,0,0;430,77,21,385,0,0,0;430,94,50,380,0,0,0;432,19,12,364,0,0,0;434,62,11,288,0,0,0;437,9,11,163,0,0,0;438,8,9,361,0,0,0;439,12,94,459,0,0,0;439,31,88,460,0,0,0;439,34,108,461,0,0,0;439,48,94,460,0,0,0;439,65,93,457,0,193,15;439,67,37,464,0,0,0;439,69,100,460,0,0,0;439,73,113,460,0,0,0;439,78,93,460,0,0,0;439,81,113,458,0,0,0;439,84,28,442,0,0,0;439,88,34,441,0,0,0;439,104,79,440,0,0,0;439,126,72,462,0,0,0;439,126,73,462,0,193,18;439,154,91,373,0,0,0;439,163,103,360,0,0,0;440,11,7,374,0,0,0;440,13,13,439,0,0,0;441,11,7,442,0,0,0;441,12,27,439,0,0,0;442,12,7,441,0,0,0;442,12,12,439,0,0,0;443,15,44,446,0,0,0;443,16,44,446,0,0,0;443,17,44,446,0,0,0;443,18,44,446,0,0,0;443,21,8,445,0,215,6;445,14,36,447,0,0,0;445,15,36,447,0,0,0;445,25,15,443,0,0,0;446,9,3,443,0,0,0;446,9,3,453,0,193,41;446,9,3,456,0,193,43;446,9,11,357,0,0,0;446,10,3,443,0,0,0;446,10,3,453,0,193,41;446,10,3,456,0,193,43;446,10,11,357,0,0,0;447,7,32,448,0,0,0;447,26,22,445,0,0,0;447,27,22,445,0,0,0;448,25,15,449,0,0,0;448,26,15,449,0,0,0;448,28,3,447,0,0,0;449,14,16,448,0,0,0;449,14,24,448,0,0,0;449,18,20,450,0,0,0;449,18,20,450,0,193,39;449,18,24,448,0,0,0;449,25,16,448,0,0,0;449,26,24,448,0,0,0;450,11,35,451,0,0,0;450,26,23,899,0,0,0;450,43,38,449,0,0,0;451,7,2,450,0,0,0;451,20,15,452,0,0,0;452,17,14,451,0,0,0;452,17,22,453,0,0,0;452,17,22,453,0,193,41;452,18,14,451,0,0,0;452,18,22,453,0,0,0;452,18,22,453,0,193,41;453,10,7,455,0,0,0;453,10,29,452,0,0,0;453,11,7,455,0,0,0;453,11,29,452,0,0,0;454,6,0,456,0,0,0;454,7,0,456,0,0,0;455,12,13,446,0,0,0;455,36,20,454,0,0,0;456,8,11,446,0,0,0;456,9,11,446,0,0,0;457,6,11,439,0,0,0;457,23,6,374,0,0,0;458,10,11,439,0,0,0;459,8,10,439,0,0,0;460,5,11,439,0,0,0;460,6,11,439,0,0,0;460,7,11,439,0,0,0;460,7,28,439,0,0,0;460,7,45,439,0,0,0;460,31,48,439,0,0,0;460,41,7,439,0,0,0;461,13,11,439,0,0,0;461,14,11,439,0,0,0;462,8,10,439,0,0,0;462,9,6,439,0,0,0;463,19,23,392,0,0,0;464,7,11,439,0,0,0;465,10,6,234,0,0,0;465,11,6,234,0,0,0;466,10,22,359,0,185,2;466,10,22,467,0,185,1;467,4,28,470,0,0,0;467,4,28,479,0,256,1;467,4,28,480,0,256,2;467,4,28,497,0,256,3;467,6,8,466,0,0,0;467,6,8,589,479,0,0;467,7,8,466,0,0,0;467,7,8,589,479,0,0;467,8,8,466,0,0,0;467,8,8,589,479,0,0;467,9,8,466,0,0,0;467,9,8,589,479,0,0;467,10,8,466,0,0,0;467,10,8,589,479,0,0;467,11,8,466,0,0,0;467,11,8,589,479,0,0;467,12,26,473,0,0,0;467,13,28,470,0,0,0;467,13,28,479,0,256,1;467,13,28,480,0,256,2;467,13,28,497,0,256,3;468,10,27,474,0,0,0;468,10,27,489,0,259,1;468,10,27,490,0,259,2;468,10,27,502,0,259,3;468,15,4,492,0,0,0;468,15,4,503,0,0,0;469,3,9,470,0,0,0;469,3,9,479,0,256,1;469,3,9,480,0,256,2;469,3,9,497,0,256,3;469,5,33,473,0,0,0;469,5,33,487,0,258,1;469,5,33,488,0,258,2;469,5,33,501,0,258,3;469,23,14,482,0,0,0;469,23,14,498,0,0,0;469,38,3,606,0,0,0;469,44,6,471,0,0,0;469,44,6,483,0,260,1;469,44,6,484,0,260,2;469,44,6,499,0,260,3;469,44,33,472,0,0,0;469,44,33,485,0,261,1;469,44,33,486,0,261,2;469,44,33,500,0,261,3;470,4,5,474,0,0,0;470,4,5,489,0,259,1;470,4,5,490,0,259,2;470,4,5,502,0,259,3;470,4,13,474,0,0,0;470,4,13,489,0,259,1;470,4,13,490,0,259,2;470,4,13,502,0,259,3;470,11,3,467,0,0,0;470,16,9,480,0,0,0;470,16,9,497,0,0,0;470,18,21,473,0,0,0;470,18,21,487,0,258,1;470,18,21,488,0,258,2;470,18,21,501,0,258,3;470,21,3,467,0,0,0;470,34,7,469,0,0,0;470,34,7,481,0,257,1;470,34,7,482,0,257,2;470,34,7,498,0,257,3;471,1,20,469,0,0,0;471,1,20,481,0,257,1;471,1,20,482,0,257,2;471,1,20,498,0,257,3;471,19,11,484,0,0,0;471,19,11,499,0,0,0;471,19,28,472,0,0,0;471,19,28,485,0,261,1;471,19,28,486,0,261,2;471,19,28,500,0,261,3;472,1,24,469,0,0,0;472,1,24,481,0,257,1;472,1,24,482,0,257,2;472,1,24,498,0,257,3;472,4,3,486,0,0,0;472,4,3,500,0,0,0;472,19,2,471,0,0,0;472,19,2,483,0,260,1;472,19,2,484,0,260,2;472,19,2,499,0,260,3;473,0,10,474,0,0,0;473,0,10,489,0,259,1;473,0,10,490,0,259,2;473,0,10,502,0,259,3;473,0,20,474,0,0,0;473,0,20,489,0,259,1;473,0,20,490,0,259,2;473,0,20,502,0,259,3;473,6,14,501,0,0,0;473,12,14,488,0,0,0;473,12,14,501,0,0,0;473,14,3,470,0,0,0;473,14,3,479,0,256,1;473,14,3,480,0,256,2;473,14,3,497,0,256,3;473,29,19,469,0,0,0;473,29,19,481,0,257,1;473,29,19,482,0,257,2;473,29,19,498,0,257,3;474,5,24,475,0,0,0;474,5,24,493,0,263,1;474,5,24,494,0,263,2;474,5,24,504,0,263,3;474,5,34,475,0,0,0;474,5,34,493,0,263,1;474,5,34,494,0,263,2;474,5,34,504,0,263,3;474,21,3,468,0,0,0;474,21,3,491,0,262,1;474,21,3,492,0,262,2;474,21,3,503,0,262,3;474,23,18,490,0,0,0;474,23,18,502,0,0,0;474,35,3,477,546,0,0;474,44,5,470,0,0,0;474,44,5,479,0,256,1;474,44,5,480,0,256,2;474,44,5,497,0,256,3;474,44,15,470,0,0,0;474,44,15,479,0,256,1;474,44,15,480,0,256,2;474,44,15,497,0,256,3;474,44,26,473,0,0,0;474,44,26,487,0,258,1;474,44,26,488,0,258,2;474,44,26,501,0,258,3;474,44,34,473,0,0,0;474,44,34,487,0,258,1;474,44,34,488,0,258,2;474,44,34,501,0,258,3;475,3,3,476,0,0,0;475,3,3,495,0,264,1;475,3,3,496,0,264,2;475,3,3,505,0,264,3;475,9,3,476,0,0,0;475,9,3,495,0,264,1;475,9,3,496,0,264,2;475,9,3,505,0,264,3;475,16,4,494,0,0,0;475,16,4,504,0,0,0;475,39,10,474,0,0,0;475,39,10,489,0,259,1;475,39,10,490,0,259,2;475,39,10,502,0,259,3;475,39,20,474,0,0,0;475,39,20,489,0,259,1;475,39,20,490,0,259,2;475,39,20,502,0,259,3;476,4,28,475,0,0,0;476,4,28,493,0,263,1;476,4,28,494,0,263,2;476,4,28,504,0,263,3;476,12,28,475,0,0,0;476,12,28,493,0,263,1;476,12,28,494,0,263,2;476,12,28,504,0,263,3;476,13,23,496,0,276,22;476,14,11,496,0,276,22;476,14,12,496,0,276,22;476,16,17,496,0,276,22;476,21,17,496,0,0,0;476,21,17,505,0,0,0;476,35,2,478,0,0,0;477,10,13,474,0,0,0;477,10,13,489,0,259,1;477,10,13,490,0,259,2;477,10,13,502,0,259,3;478,10,21,327,0,0,0;478,12,10,505,0,0,0;478,12,13,476,0,0,0;478,12,13,495,0,264,1;478,12,13,496,0,264,2;478,12,13,505,0,264,3;479,4,5,474,0,0,0;479,4,5,489,0,259,1;479,4,5,490,0,259,2;479,4,5,502,0,259,3;479,4,13,474,0,0,0;479,4,13,489,0,259,1;479,4,13,490,0,259,2;479,4,13,502,0,259,3;479,11,3,467,0,0,0;479,16,9,480,0,0,0;479,16,9,497,0,0,0;479,18,21,473,0,0,0;479,18,21,487,0,258,1;479,18,21,488,0,258,2;479,18,21,501,0,258,3;479,21,3,467,0,0,0;479,34,7,469,0,0,0;479,34,7,481,0,257,1;479,34,7,482,0,257,2;479,34,7,498,0,257,3;480,4,5,474,0,0,0;480,4,5,489,0,259,1;480,4,5,490,0,259,2;480,4,5,502,0,259,3;480,4,13,474,0,0,0;480,4,13,489,0,259,1;480,4,13,490,0,259,2;480,4,13,502,0,259,3;480,11,3,467,0,0,0;480,16,9,470,0,0,0;480,16,9,479,0,0,0;480,18,21,473,0,0,0;480,18,21,487,0,258,1;480,18,21,488,0,258,2;480,18,21,501,0,258,3;480,21,3,467,0,0,0;480,34,7,469,0,0,0;480,34,7,481,0,257,1;480,34,7,482,0,257,2;480,34,7,498,0,257,3;481,3,9,470,0,0,0;481,3,9,479,0,256,1;481,3,9,480,0,256,2;481,3,9,497,0,256,3;481,5,33,473,0,0,0;481,5,33,487,0,258,1;481,5,33,488,0,258,2;481,5,33,501,0,258,3;481,23,14,482,0,0,0;481,23,14,498,0,0,0;481,38,3,606,0,0,0;481,44,6,471,0,0,0;481,44,6,483,0,260,1;481,44,6,484,0,260,2;481,44,6,499,0,260,3;481,44,33,472,0,0,0;481,44,33,485,0,261,1;481,44,33,486,0,261,2;481,44,33,500,0,261,3;482,3,9,470,0,0,0;482,3,9,479,0,256,1;482,3,9,480,0,256,2;482,3,9,497,0,256,3;482,5,33,473,0,0,0;482,5,33,487,0,258,1;482,5,33,488,0,258,2;482,5,33,501,0,258,3;482,23,14,469,0,0,0;482,23,14,481,0,0,0;482,38,3,606,0,0,0;482,44,6,471,0,0,0;482,44,6,483,0,260,1;482,44,6,484,0,260,2;482,44,6,499,0,260,3;482,44,33,472,0,0,0;482,44,33,485,0,261,1;482,44,33,486,0,261,2;482,44,33,500,0,261,3;483,1,20,469,0,0,0;483,1,20,481,0,257,1;483,1,20,482,0,257,2;483,1,20,498,0,257,3;483,17,3,543,0,697,13;483,18,3,543,0,697,13;483,19,11,484,0,0,0;483,19,11,499,0,0,0;483,19,28,472,0,0,0;483,19,28,485,0,261,1;483,19,28,486,0,261,2;483,19,28,500,0,261,3;484,1,20,469,0,0,0;484,1,20,481,0,257,1;484,1,20,482,0,257,2;484,1,20,498,0,257,3;484,2,20,471,0,0,0;484,19,11,471,0,0,0;484,19,11,483,0,0,0;484,19,28,472,0,0,0;484,19,28,485,0,261,1;484,19,28,486,0,261,2;484,19,28,500,0,261,3;485,1,24,469,0,0,0;485,1,24,481,0,257,1;485,1,24,482,0,257,2;485,1,24,498,0,257,3;485,4,3,486,0,0,0;485,4,3,500,0,0,0;485,19,2,471,0,0,0;485,19,2,483,0,260,1;485,19,2,484,0,260,2;485,19,2,499,0,260,3;486,1,24,469,0,0,0;486,1,24,481,0,257,1;486,1,24,482,0,257,2;486,1,24,498,0,257,3;486,4,3,472,0,0,0;486,4,3,485,0,0,0;486,17,21,472,0,0,0;486,18,21,472,0,0,0;486,19,2,471,0,0,0;486,19,2,483,0,260,1;486,19,2,484,0,260,2;486,19,2,499,0,260,3;487,0,10,474,0,0,0;487,0,10,489,0,259,1;487,0,10,490,0,259,2;487,0,10,502,0,259,3;487,0,20,474,0,0,0;487,0,20,489,0,259,1;487,0,20,490,0,259,2;487,0,20,502,0,259,3;487,6,14,501,0,0,0;487,12,14,488,0,0,0;487,12,14,501,0,0,0;487,14,3,470,0,0,0;487,14,3,479,0,256,1;487,14,3,480,0,256,2;487,14,3,497,0,256,3;487,29,19,469,0,0,0;487,29,19,481,0,257,1;487,29,19,482,0,257,2;487,29,19,498,0,257,3;488,0,10,474,0,0,0;488,0,10,489,0,259,1;488,0,10,490,0,259,2;488,0,10,502,0,259,3;488,0,20,474,0,0,0;488,0,20,489,0,259,1;488,0,20,490,0,259,2;488,0,20,502,0,259,3;488,6,14,501,0,0,0;488,12,14,473,0,0,0;488,12,14,487,0,0,0;488,14,3,470,0,0,0;488,14,3,479,0,256,1;488,14,3,480,0,256,2;488,14,3,497,0,256,3;488,29,19,469,0,0,0;488,29,19,481,0,257,1;488,29,19,482,0,257,2;488,29,19,498,0,257,3;489,5,24,475,0,0,0;489,5,24,493,0,263,1;489,5,24,494,0,263,2;489,5,24,504,0,263,3;489,5,34,475,0,0,0;489,5,34,493,0,263,1;489,5,34,494,0,263,2;489,5,34,504,0,263,3;489,21,3,468,0,0,0;489,21,3,491,0,262,1;489,21,3,492,0,262,2;489,21,3,503,0,262,3;489,23,18,490,0,0,0;489,23,18,502,0,0,0;489,35,3,477,546,0,0;489,44,5,470,0,0,0;489,44,5,479,0,256,1;489,44,5,480,0,256,2;489,44,5,497,0,256,3;489,44,15,470,0,0,0;489,44,15,479,0,256,1;489,44,15,480,0,256,2;489,44,15,497,0,256,3;489,44,26,473,0,0,0;489,44,26,487,0,258,1;489,44,26,488,0,258,2;489,44,26,501,0,258,3;489,44,34,473,0,0,0;489,44,34,487,0,258,1;489,44,34,488,0,258,2;489,44,34,501,0,258,3;490,5,24,475,0,0,0;490,5,24,493,0,263,1;490,5,24,494,0,263,2;490,5,24,504,0,263,3;490,5,34,475,0,0,0;490,5,34,493,0,263,1;490,5,34,494,0,263,2;490,5,34,504,0,263,3;490,21,3,468,0,0,0;490,21,3,491,0,262,1;490,21,3,492,0,262,2;490,21,3,503,0,262,3;490,23,18,474,0,0,0;490,23,18,489,0,0,0;490,35,3,477,546,0,0;490,44,5,470,0,0,0;490,44,5,479,0,256,1;490,44,5,480,0,256,2;490,44,5,497,0,256,3;490,44,15,470,0,0,0;490,44,15,479,0,256,1;490,44,15,480,0,256,2;490,44,15,497,0,256,3;490,44,26,473,0,0,0;490,44,26,487,0,258,1;490,44,26,488,0,258,2;490,44,26,501,0,258,3;490,44,34,473,0,0,0;490,44,34,487,0,258,1;490,44,34,488,0,258,2;490,44,34,501,0,258,3;491,10,27,474,0,0,0;491,10,27,489,0,259,1;491,10,27,490,0,259,2;491,10,27,502,0,259,3;491,15,4,492,0,0,0;491,15,4,503,0,0,0;492,10,27,474,0,0,0;492,10,27,489,0,259,1;492,10,27,490,0,259,2;492,10,27,502,0,259,3;492,15,4,468,0,0,0;492,15,4,491,0,0,0;493,3,3,476,0,0,0;493,3,3,495,0,264,1;493,3,3,496,0,264,2;493,3,3,505,0,264,3;493,9,3,476,0,0,0;493,9,3,495,0,264,1;493,9,3,496,0,264,2;493,9,3,505,0,264,3;493,16,4,494,0,0,0;493,16,4,504,0,0,0;493,39,10,474,0,0,0;493,39,10,489,0,259,1;493,39,10,490,0,259,2;493,39,10,502,0,259,3;493,39,20,474,0,0,0;493,39,20,489,0,259,1;493,39,20,490,0,259,2;493,39,20,502,0,259,3;494,3,3,476,0,0,0;494,3,3,495,0,264,1;494,3,3,496,0,264,2;494,3,3,505,0,264,3;494,9,3,476,0,0,0;494,9,3,495,0,264,1;494,9,3,496,0,264,2;494,9,3,505,0,264,3;494,16,4,475,0,0,0;494,16,4,493,0,0,0;494,25,4,475,0,0,0;494,39,10,474,0,0,0;494,39,10,489,0,259,1;494,39,10,490,0,259,2;494,39,10,502,0,259,3;494,39,20,474,0,0,0;494,39,20,489,0,259,1;494,39,20,490,0,259,2;494,39,20,502,0,259,3;495,4,28,475,0,0,0;495,4,28,493,0,263,1;495,4,28,494,0,263,2;495,4,28,504,0,263,3;495,12,28,475,0,0,0;495,12,28,493,0,263,1;495,12,28,494,0,263,2;495,12,28,504,0,263,3;495,21,17,496,0,0,0;495,21,17,505,0,0,0;495,21,18,505,0,276,22;495,35,2,478,0,0,0;496,4,28,475,0,0,0;496,4,28,493,0,263,1;496,4,28,494,0,263,2;496,4,28,504,0,263,3;496,9,21,476,0,276,22;496,10,21,476,0,276,22;496,12,28,475,0,0,0;496,12,28,493,0,263,1;496,12,28,494,0,263,2;496,12,28,504,0,263,3;496,17,15,476,0,276,22;496,18,11,476,0,276,22;496,18,12,476,0,276,22;496,21,17,476,0,0,0;496,21,17,495,0,0,0;496,31,22,476,0,0,0;496,31,22,495,0,276,23;496,32,22,476,0,0,0;496,32,22,495,0,276,23;496,35,2,478,0,0,0;497,4,5,474,0,0,0;497,4,5,489,0,259,1;497,4,5,490,0,259,2;497,4,5,502,0,259,3;497,4,13,474,0,0,0;497,4,13,489,0,259,1;497,4,13,490,0,259,2;497,4,13,502,0,259,3;497,11,3,467,0,0,0;497,16,9,470,0,0,0;497,16,9,479,0,0,0;497,18,21,473,0,0,0;497,18,21,487,0,258,1;497,18,21,488,0,258,2;497,18,21,501,0,258,3;497,21,3,467,0,0,0;497,34,7,469,0,0,0;497,34,7,481,0,257,1;497,34,7,482,0,257,2;497,34,7,498,0,257,3;498,3,9,470,0,0,0;498,3,9,479,0,256,1;498,3,9,480,0,256,2;498,3,9,497,0,256,3;498,5,33,473,0,0,0;498,5,33,487,0,258,1;498,5,33,488,0,258,2;498,5,33,501,0,258,3;498,23,14,469,0,0,0;498,23,14,481,0,0,0;498,38,3,606,0,0,0;498,44,6,471,0,0,0;498,44,6,483,0,260,1;498,44,6,484,0,260,2;498,44,6,499,0,260,3;498,44,33,472,0,0,0;498,44,33,485,0,261,1;498,44,33,486,0,261,2;498,44,33,500,0,261,3;499,1,20,469,0,0,0;499,1,20,481,0,257,1;499,1,20,482,0,257,2;499,1,20,498,0,257,3;499,17,3,543,0,697,13;499,18,3,543,0,697,13;499,19,11,471,0,0,0;499,19,11,483,0,0,0;499,19,28,472,0,0,0;499,19,28,485,0,261,1;499,19,28,486,0,261,2;499,19,28,500,0,261,3;500,1,24,469,0,0,0;500,1,24,481,0,257,1;500,1,24,482,0,257,2;500,1,24,498,0,257,3;500,4,3,472,0,0,0;500,4,3,485,0,0,0;500,19,2,471,0,0,0;500,19,2,483,0,260,1;500,19,2,484,0,260,2;500,19,2,499,0,260,3;501,0,10,474,0,0,0;501,0,10,489,0,259,1;501,0,10,490,0,259,2;501,0,10,502,0,259,3;501,0,20,474,0,0,0;501,0,20,489,0,259,1;501,0,20,490,0,259,2;501,0,20,502,0,259,3;501,12,14,473,0,0,0;501,12,14,487,0,0,0;501,14,3,470,0,0,0;501,14,3,479,0,256,1;501,14,3,480,0,256,2;501,14,3,497,0,256,3;501,29,19,469,0,0,0;501,29,19,481,0,257,1;501,29,19,482,0,257,2;501,29,19,498,0,257,3;502,5,24,475,0,0,0;502,5,24,493,0,263,1;502,5,24,494,0,263,2;502,5,24,504,0,263,3;502,5,34,475,0,0,0;502,5,34,493,0,263,1;502,5,34,494,0,263,2;502,5,34,504,0,263,3;502,21,3,468,0,0,0;502,21,3,491,0,262,1;502,21,3,492,0,262,2;502,21,3,503,0,262,3;502,23,18,474,0,0,0;502,23,18,489,0,0,0;502,35,3,477,546,0,0;502,44,5,470,0,0,0;502,44,5,479,0,256,1;502,44,5,480,0,256,2;502,44,5,497,0,256,3;502,44,15,470,0,0,0;502,44,15,479,0,256,1;502,44,15,480,0,256,2;502,44,15,497,0,256,3;502,44,26,473,0,0,0;502,44,26,487,0,258,1;502,44,26,488,0,258,2;502,44,26,501,0,258,3;502,44,34,473,0,0,0;502,44,34,487,0,258,1;502,44,34,488,0,258,2;502,44,34,501,0,258,3;503,10,27,474,0,0,0;503,10,27,489,0,259,1;503,10,27,490,0,259,2;503,10,27,502,0,259,3;503,15,4,468,0,0,0;503,15,4,491,0,0,0;504,3,3,476,0,0,0;504,3,3,495,0,264,1;504,3,3,496,0,264,2;504,3,3,505,0,264,3;504,9,3,476,0,0,0;504,9,3,495,0,264,1;504,9,3,496,0,264,2;504,9,3,505,0,264,3;504,16,4,475,0,0,0;504,16,4,493,0,0,0;504,39,10,474,0,0,0;504,39,10,489,0,259,1;504,39,10,490,0,259,2;504,39,10,502,0,259,3;504,39,20,474,0,0,0;504,39,20,489,0,259,1;504,39,20,490,0,259,2;504,39,20,502,0,259,3;505,4,28,475,0,0,0;505,4,28,493,0,263,1;505,4,28,494,0,263,2;505,4,28,504,0,263,3;505,12,28,475,0,0,0;505,12,28,493,0,263,1;505,12,28,494,0,263,2;505,12,28,504,0,263,3;505,21,17,476,0,0,0;505,21,17,495,0,0,0;505,35,2,478,0,0,0;506,8,67,239,0,0,0;506,9,4,271,0,0,0;506,9,67,239,0,0,0;507,12,13,333,0,0,0;508,2,6,362,0,0,0;508,3,6,362,0,0,0;508,10,5,678,0,381,14;508,11,5,678,0,381,14;508,15,24,359,0,0,0;508,16,5,509,0,0,0;508,28,6,362,0,0,0;508,28,16,362,0,0,0;508,31,22,359,0,0,0;509,10,7,362,0,0,0;509,10,7,362,0,276,31;509,10,7,508,579,0,0;509,14,5,359,0,276,31;510,15,10,239,0,0,0;510,16,10,239,0,0,0;511,20,35,895,0,0,0;511,21,35,895,0,0,0;511,39,63,259,0,0,0;512,10,14,180,0,0,0;513,1,6,519,0,0,0;513,1,7,519,0,0,0;513,1,8,519,0,0,0;513,1,9,519,0,0,0;513,1,10,519,0,0,0;513,1,11,519,0,0,0;513,16,6,519,0,0,0;513,16,7,519,0,0,0;513,16,8,519,0,0,0;513,16,9,519,0,0,0;513,16,10,519,0,0,0;513,16,11,519,0,0,0;513,16,13,519,0,0,0;513,16,14,519,0,0,0;513,16,15,519,0,0,0;513,16,16,519,0,0,0;513,16,17,519,0,0,0;513,16,18,519,0,0,0;513,16,19,519,0,0,0;513,16,20,519,0,0,0;513,16,21,519,0,0,0;513,16,22,519,0,0,0;513,16,23,519,0,0,0;514,0,42,291,0,0,0;514,1,43,291,0,0,0;514,2,44,291,0,0,0;514,3,45,291,0,0,0;514,4,46,291,0,0,0;514,5,47,291,0,0,0;514,6,48,291,0,0,0;514,7,49,291,0,0,0;514,8,3,364,0,0,0;514,8,3,390,0,0,0;514,8,50,291,0,0,0;514,9,51,291,0,0,0;514,45,51,365,0,0,0;515,10,52,291,0,0,0;515,10,144,359,0,0,0;515,10,145,359,0,0,0;515,10,146,359,0,0,0;515,10,147,359,0,0,0;515,10,148,359,0,0,0;515,10,150,359,0,0,0;515,11,53,291,0,0,0;515,12,54,291,0,0,0;515,13,55,291,0,0,0;515,14,56,291,0,0,0;515,15,57,291,0,0,0;515,16,58,291,0,0,0;515,17,59,291,0,0,0;515,18,13,364,0,0,0;515,18,13,390,0,0,0;515,18,60,291,0,0,0;515,19,61,291,0,0,0;515,55,61,365,0,0,0;516,12,7,123,0,0,0;517,2,7,79,0,0,0;517,2,7,527,0,0,0;517,2,8,79,0,0,0;517,2,8,527,479,0,0;517,8,7,899,0,0,0;519,8,9,530,0,0,0;519,8,10,530,0,0,0;519,8,11,530,0,0,0;519,8,12,530,0,0,0;519,8,13,530,0,0,0;519,8,60,530,0,0,0;519,8,61,530,0,0,0;519,8,62,530,0,0,0;519,8,63,530,0,0,0;519,8,64,530,0,0,0;519,30,9,513,0,0,0;519,30,10,513,0,0,0;519,30,11,513,0,0,0;519,30,12,513,0,0,0;519,30,13,513,0,0,0;519,31,8,527,0,0,0;519,32,8,527,0,0,0;519,33,8,527,0,0,0;519,34,8,527,0,0,0;519,34,45,38,0,0,0;519,35,8,527,0,0,0;519,35,45,38,0,0,0;519,36,8,527,0,0,0;519,37,8,527,0,0,0;519,38,8,527,0,0,0;519,39,8,527,0,0,0;519,40,9,513,0,0,0;519,40,10,513,0,0,0;519,40,11,513,0,0,0;519,40,12,513,0,0,0;519,40,13,513,0,0,0;519,40,15,513,0,0,0;519,40,16,513,0,0,0;519,40,16,513,39,0,0;519,40,17,513,0,0,0;519,40,18,513,0,0,0;519,40,19,513,0,0,0;519,40,20,513,0,0,0;519,40,20,513,39,0,0;519,59,9,602,652,0,0;519,59,9,633,0,0,0;519,59,10,602,652,0,0;519,59,10,633,0,0,0;519,59,11,602,652,0,0;519,59,11,633,0,0,0;519,59,12,602,652,0,0;519,59,12,633,0,0,0;519,59,13,602,652,0,0;519,59,13,633,0,0,0;519,59,33,520,0,0,0;519,59,34,520,0,0,0;519,59,35,520,0,0,0;519,59,36,520,0,0,0;519,59,37,520,0,0,0;519,59,38,520,0,0,0;519,59,39,520,0,0,0;519,68,65,528,0,0,0;519,68,65,585,0,0,0;519,69,66,528,0,0,0;519,69,66,585,0,0,0;519,69,67,528,0,0,0;519,69,67,585,0,0,0;520,8,34,519,0,0,0;520,8,35,519,0,0,0;520,8,36,519,0,0,0;520,8,37,519,0,0,0;520,8,38,519,0,0,0;520,8,39,519,0,0,0;520,8,40,519,0,0,0;520,10,7,527,0,0,0;520,11,7,527,0,0,0;520,12,7,527,0,0,0;520,13,7,527,0,0,0;520,17,53,570,0,0,0;520,19,8,571,0,0,0;520,20,36,82,0,0,0;520,21,18,102,0,0,0;520,21,18,541,0,0,0;520,23,7,527,0,0,0;520,24,7,527,0,0,0;520,25,7,527,0,0,0;520,25,23,104,0,0,0;520,26,7,527,0,0,0;520,26,36,369,0,0,0;520,27,7,527,0,0,0;520,28,7,527,0,0,0;520,33,37,632,0,611,2;520,35,36,84,0,0,0;520,35,36,84,0,339,10;520,36,24,83,0,0,0;520,38,15,111,0,0,0;520,40,24,106,0,0,0;520,42,54,528,0,0,0;520,42,54,585,0,0,0;520,43,36,256,0,0,0;520,43,54,528,0,0,0;520,43,54,585,0,0,0;520,44,54,528,0,0,0;520,44,54,585,0,0,0;520,45,54,528,0,0,0;520,45,54,585,0,0,0;520,46,54,528,0,0,0;520,46,54,585,0,0,0;520,47,54,528,0,0,0;520,47,54,585,0,0,0;520,49,14,611,0,0,0;520,60,15,112,0,0,0;520,68,12,540,0,0,0;520,69,12,540,0,0,0;520,70,12,540,0,0,0;520,71,12,540,0,0,0;520,72,12,540,0,0,0;520,72,55,528,0,0,0;520,72,55,585,0,0,0;520,73,12,540,0,0,0;520,74,12,540,0,0,0;520,74,55,528,0,0,0;520,74,55,585,0,0,0;521,16,38,116,0,0,0;521,20,14,119,0,0,0;521,30,35,118,0,0,0;521,41,38,117,0,0,0;521,44,41,540,0,0,0;521,45,14,120,0,0,0;521,45,41,540,0,0,0;521,46,41,540,0,0,0;521,47,41,540,0,0,0;521,48,41,540,0,0,0;521,49,41,540,0,0,0;521,50,41,540,0,0,0;522,11,87,538,0,0,0;522,12,87,538,0,0,0;522,13,88,538,0,0,0;522,18,88,538,0,0,0;522,21,88,538,0,0,0;522,22,88,538,0,0,0;522,23,88,538,0,0,0;522,24,88,538,0,0,0;522,25,88,538,0,0,0;522,26,88,538,0,0,0;522,27,88,538,0,0,0;522,28,36,592,0,0,0;522,28,88,538,0,0,0;522,29,88,538,0,0,0;522,30,88,538,0,0,0;522,31,88,538,0,0,0;522,32,88,538,0,0,0;522,33,88,538,0,0,0;522,34,88,538,0,0,0;522,35,88,538,0,0,0;522,36,30,68,0,0,0;522,36,49,594,0,0,0;522,36,88,538,0,0,0;522,37,88,538,0,0,0;522,38,88,538,0,0,0;522,39,88,538,0,0,0;522,40,88,538,0,0,0;522,41,88,538,0,0,0;522,42,88,538,0,0,0;522,43,88,538,0,0,0;522,44,88,538,0,0,0;522,45,88,538,0,0,0;522,46,88,538,0,0,0;522,47,88,538,0,0,0;522,48,88,538,0,0,0;522,49,46,70,0,0,0;522,49,88,538,0,0,0;522,50,88,538,0,0,0;522,51,88,538,0,0,0;522,52,88,538,0,0,0;522,53,88,538,0,0,0;522,54,88,538,0,0,0;522,55,88,538,0,0,0;522,56,88,538,0,0,0;522,57,88,538,0,0,0;522,58,88,538,0,0,0;522,59,25,539,0,0,0;522,59,88,538,0,0,0;522,60,25,539,0,0,0;522,60,88,538,0,0,0;522,61,25,539,0,0,0;522,61,46,69,0,0,0;522,61,88,538,0,0,0;522,62,25,539,0,0,0;522,62,88,538,0,0,0;522,63,25,539,0,0,0;522,64,25,539,0,0,0;522,65,25,539,0,0,0;522,65,88,538,0,0,0;522,66,88,538,0,0,0;522,67,88,538,0,0,0;522,72,84,530,0,0,0;522,73,29,60,0,0,0;522,73,84,530,0,0,0;522,74,84,530,0,0,0;522,75,84,530,0,0,0;522,76,84,530,0,0,0;522,77,84,530,0,0,0;522,78,84,530,0,0,0;522,79,84,530,0,0,0;522,80,46,63,0,0,0;522,80,84,530,0,0,0;522,81,84,530,0,0,0;522,84,18,64,0,0,0;522,86,78,56,0,0,0;522,87,75,878,0,641,1;522,87,75,879,0,641,17;522,88,43,61,0,0,0;522,88,75,878,0,641,1;522,88,75,879,0,641,17;522,89,75,878,0,641,1;522,89,75,879,0,641,17;522,92,9,62,0,0,0;522,92,29,541,0,0,0;522,92,29,557,0,0,0;522,92,29,590,0,0,0;522,92,29,591,0,0,0;522,92,29,597,0,0,0;522,92,29,598,0,0,0;522,92,29,599,0,0,0;522,95,78,530,0,0,0;522,96,78,530,0,0,0;522,97,78,530,0,0,0;522,98,78,530,0,0,0;522,99,78,530,0,0,0;522,100,41,65,0,0,0;522,101,70,899,0,0,0;522,103,35,532,0,0,0;522,103,58,59,0,0,0;523,8,14,533,0,0,0;523,8,34,533,0,0,0;523,19,14,537,0,0,0;523,19,31,534,0,0,0;523,24,14,537,0,0,0;523,32,31,535,0,0,0;523,33,14,598,0,0,0;523,44,14,537,0,0,0;523,49,31,133,0,0,0;523,49,38,539,0,0,0;523,50,38,539,0,0,0;523,51,38,539,0,0,0;523,52,38,539,0,0,0;523,53,38,539,0,0,0;523,54,38,539,0,0,0;523,55,38,539,0,0,0;523,73,8,554,0,0,0;523,74,8,554,0,0,0;523,75,8,554,0,0,0;523,76,8,554,0,0,0;523,77,8,554,0,0,0;523,77,22,534,0,0,0;523,78,8,554,0,0,0;523,79,8,554,0,0,0;524,12,16,168,0,0,0;524,13,24,322,0,0,0;524,13,25,322,0,0,0;524,16,42,168,0,0,0;524,18,70,169,0,0,0;524,19,61,166,0,0,0;524,19,79,167,0,0,0;524,26,29,612,0,0,0;524,27,16,169,0,0,0;524,30,59,181,0,0,0;524,31,28,171,0,0,0;524,35,29,169,0,0,0;524,41,18,175,0,0,0;524,41,61,542,0,0,0;524,43,66,169,0,0,0;524,47,66,597,0,0,0;524,56,67,424,0,0,0;524,56,68,424,0,0,0;525,7,5,161,0,0,0;525,13,14,160,0,0,0;525,21,22,159,0,0,0;525,27,38,554,0,0,0;525,28,38,554,0,0,0;525,29,38,554,0,0,0;525,30,38,554,0,0,0;525,31,38,554,0,0,0;525,32,38,554,0,0,0;525,33,38,554,0,0,0;526,8,9,536,0,0,0;526,8,10,536,0,0,0;526,8,11,536,0,0,0;526,8,12,536,0,0,0;526,8,13,536,0,0,0;526,8,14,536,0,0,0;526,8,15,536,0,0,0;526,8,16,536,0,0,0;526,8,17,536,0,0,0;526,8,18,536,0,0,0;526,8,19,536,0,0,0;526,8,20,536,0,0,0;526,26,5,609,0,0,0;526,38,9,555,0,0,0;526,43,8,557,0,0,0;526,52,19,613,0,0,0;526,55,9,98,0,0,0;526,62,6,559,0,0,0;526,63,6,559,0,0,0;526,64,6,559,0,0,0;526,65,6,559,0,0,0;526,66,6,559,0,0,0;526,66,18,100,0,0,0;526,67,6,559,0,0,0;526,68,6,559,0,0,0;527,7,18,424,0,0,0;527,7,19,424,0,0,0;527,7,20,424,0,0,0;527,7,21,424,0,0,0;527,7,22,424,0,0,0;527,12,35,164,0,0,0;527,22,50,519,0,0,0;527,23,50,519,0,0,0;527,24,7,572,0,0,0;527,24,50,519,0,0,0;527,25,7,572,0,0,0;527,25,50,519,0,0,0;527,26,7,572,0,0,0;527,26,50,519,0,0,0;527,27,7,572,0,0,0;527,27,50,519,0,0,0;527,28,7,572,0,0,0;527,28,50,519,0,0,0;527,29,50,519,0,0,0;527,30,50,519,0,0,0;527,31,21,588,0,0,0;527,35,24,827,0,0,0;527,36,22,826,0,0,0;527,51,48,520,0,0,0;527,52,48,520,0,0,0;527,53,48,520,0,0,0;527,54,48,520,0,0,0;527,63,18,529,0,0,0;527,64,48,520,0,0,0;527,65,48,520,0,0,0;527,66,48,520,0,0,0;527,67,48,520,0,0,0;527,68,48,520,0,0,0;527,69,48,520,0,0,0;527,70,27,628,0,339,44;527,70,34,517,0,0,0;527,70,35,517,0,0,0;527,70,48,520,0,0,0;527,71,48,520,0,0,0;528,22,22,519,0,0,0;528,22,23,519,0,0,0;528,23,21,519,0,0,0;528,48,8,520,0,0,0;528,49,8,520,0,0,0;528,50,8,520,0,0,0;528,51,8,520,0,0,0;528,52,8,520,0,0,0;528,52,29,91,0,0,0;528,53,8,520,0,0,0;528,56,11,86,0,0,0;528,57,40,91,0,0,0;528,64,22,85,0,0,0;528,69,41,85,0,0,0;528,73,11,101,0,0,0;528,74,43,559,0,0,0;528,75,43,559,0,0,0;528,76,28,210,0,0,0;528,76,43,559,0,0,0;528,77,28,210,0,0,0;528,77,43,559,0,0,0;528,78,9,520,0,0,0;528,78,43,559,0,0,0;528,79,43,559,0,0,0;528,80,9,520,0,0,0;528,80,43,559,0,0,0;529,32,11,527,0,0,0;529,32,12,527,0,0,0;529,32,13,527,0,0,0;530,8,61,538,0,0,0;530,8,62,538,0,0,0;530,8,63,538,0,0,0;530,8,64,538,0,0,0;530,8,65,538,0,0,0;530,8,66,538,0,0,0;530,8,69,538,0,0,0;530,20,11,522,0,0,0;530,21,11,522,0,0,0;530,22,11,522,0,0,0;530,23,11,522,0,0,0;530,24,11,522,0,0,0;530,25,11,522,0,0,0;530,26,11,522,0,0,0;530,27,11,522,0,0,0;530,28,11,522,0,0,0;530,29,11,522,0,0,0;530,32,15,56,0,0,0;530,34,8,56,0,0,0;530,35,5,878,0,641,1;530,35,5,879,0,641,17;530,35,81,567,0,0,0;530,36,5,878,0,641,1;530,36,5,879,0,641,17;530,36,81,567,0,0,0;530,37,5,878,0,641,1;530,37,5,879,0,641,17;530,37,81,567,0,0,0;530,38,81,567,0,0,0;530,39,44,47,0,0,0;530,39,81,567,0,0,0;530,40,31,49,0,0,0;530,40,81,567,0,0,0;530,41,81,567,0,0,0;530,42,81,567,0,0,0;530,43,7,522,0,0,0;530,43,81,567,0,0,0;530,44,7,522,0,0,0;530,45,7,522,0,0,0;530,45,66,591,0,0,0;530,46,7,522,0,0,0;530,47,7,522,0,0,0;530,49,33,42,0,0,0;530,53,11,55,0,0,0;530,54,33,48,0,0,0;530,72,11,54,0,0,0;530,74,7,531,0,0,0;530,84,28,78,0,0,0;530,84,28,78,1993,0,0;530,87,10,53,0,0,0;530,95,11,519,0,0,0;530,95,12,519,0,0,0;530,95,13,519,0,0,0;530,95,14,519,0,0,0;530,95,15,519,0,0,0;530,95,62,519,0,0,0;530,95,63,519,0,0,0;530,95,64,519,0,0,0;530,95,65,519,0,0,0;530,95,66,519,0,0,0;531,20,7,530,0,0,0;531,20,8,530,0,0,0;531,20,9,530,0,0,0;531,20,10,530,0,0,0;532,8,19,522,0,0,0;532,9,17,899,1955,0,0;532,9,19,522,0,0,0;533,99,41,523,0,0,0;533,106,14,523,0,0,0;534,10,12,523,0,0,0;534,21,8,523,0,0,0;535,10,12,523,0,0,0;536,8,14,567,0,0,0;536,8,15,567,0,0,0;536,8,16,567,0,0,0;536,8,17,567,0,0,0;536,8,18,567,0,0,0;536,8,19,567,0,0,0;536,8,20,567,0,0,0;536,33,47,569,0,0,0;536,33,47,586,0,0,0;536,34,47,569,0,0,0;536,34,47,586,0,0,0;536,35,47,569,0,0,0;536,35,47,586,0,0,0;536,36,47,569,0,0,0;536,36,47,586,0,0,0;536,37,47,569,0,0,0;536,37,47,586,0,0,0;536,38,47,569,0,0,0;536,38,47,586,0,0,0;536,39,47,569,0,0,0;536,39,47,586,0,0,0;536,40,47,569,0,0,0;536,40,47,586,0,0,0;536,41,47,569,0,0,0;536,41,47,586,0,0,0;536,97,30,526,0,0,0;536,97,31,526,0,0,0;536,97,32,526,0,0,0;536,97,33,526,0,0,0;536,97,34,526,0,0,0;536,97,35,526,0,0,0;536,97,36,526,0,0,0;536,97,37,526,0,0,0;536,97,38,526,0,0,0;536,97,39,526,0,0,0;536,97,40,526,0,0,0;536,97,41,526,0,0,0;537,8,12,523,0,0,0;537,29,12,523,0,0,0;537,49,12,523,0,0,0;538,13,6,522,0,0,0;538,13,70,567,0,0,0;538,14,6,522,0,0,0;538,15,5,522,0,0,0;538,19,5,522,0,0,0;538,20,5,522,0,0,0;538,21,5,522,0,0,0;538,22,5,522,0,0,0;538,23,5,522,0,0,0;538,24,5,522,0,0,0;538,25,5,522,0,0,0;538,26,5,522,0,0,0;538,27,5,522,0,0,0;538,27,71,567,0,0,0;538,28,5,522,0,0,0;538,28,71,567,0,0,0;538,29,5,522,0,0,0;538,29,71,567,0,0,0;538,30,5,522,0,0,0;538,30,71,567,0,0,0;538,31,5,522,0,0,0;538,31,71,567,0,0,0;538,32,5,522,0,0,0;538,32,71,567,0,0,0;538,33,5,522,0,0,0;538,33,71,567,0,0,0;538,34,5,522,0,0,0;538,34,71,567,0,0,0;538,35,5,522,0,0,0;538,36,5,522,0,0,0;538,37,5,522,0,0,0;538,38,5,522,0,0,0;538,39,5,522,0,0,0;538,40,5,522,0,0,0;538,41,5,522,0,0,0;538,42,5,522,0,0,0;538,43,5,522,0,0,0;538,44,5,522,0,0,0;538,45,5,522,0,0,0;538,46,5,522,0,0,0;538,47,5,522,0,0,0;538,48,5,522,0,0,0;538,49,5,522,0,0,0;538,50,5,522,0,0,0;538,51,5,522,0,0,0;538,52,5,522,0,0,0;538,53,5,522,0,0,0;538,53,26,604,0,0,0;538,54,5,522,0,0,0;538,55,5,522,0,0,0;538,56,5,522,0,0,0;538,57,5,522,0,0,0;538,58,5,522,0,0,0;538,59,5,522,0,0,0;538,60,5,522,0,0,0;538,61,5,522,0,0,0;538,62,5,522,0,0,0;538,63,5,522,0,0,0;538,64,5,522,0,0,0;538,65,5,522,0,0,0;538,65,50,530,0,0,0;538,65,51,530,0,0,0;538,65,52,530,0,0,0;538,65,53,530,0,0,0;538,65,54,530,0,0,0;538,65,55,530,0,0,0;538,65,56,530,0,0,0;538,65,57,530,0,0,0;538,65,58,530,0,0,0;538,65,59,530,0,0,0;538,66,5,522,0,0,0;538,67,5,522,0,0,0;538,68,5,522,0,0,0;539,6,2,523,0,0,0;539,6,14,522,0,0,0;539,7,2,523,0,0,0;539,7,14,522,0,0,0;539,8,2,523,0,0,0;539,8,14,522,0,0,0;539,9,2,523,0,0,0;539,9,14,522,0,0,0;539,10,2,523,0,0,0;539,10,14,522,0,0,0;539,11,2,523,0,0,0;539,11,14,522,0,0,0;539,12,2,523,0,0,0;539,12,14,522,0,0,0;540,6,2,521,0,0,0;540,6,14,520,0,0,0;540,7,2,521,0,0,0;540,7,14,520,0,0,0;540,8,2,521,0,0,0;540,8,14,520,0,0,0;540,9,2,521,0,0,0;540,9,14,520,0,0,0;540,10,2,521,0,0,0;540,10,14,520,0,0,0;540,11,2,521,0,0,0;540,11,14,520,0,0,0;540,12,2,521,0,0,0;540,12,14,520,0,0,0;541,10,10,520,0,0,0;541,11,7,522,0,0,0;541,11,7,557,0,0,0;541,11,7,590,0,0,0;541,11,7,591,0,0,0;541,11,7,597,0,0,0;541,11,7,598,0,0,0;541,11,7,599,0,0,0;542,0,21,524,0,0,0;542,0,22,524,0,0,0;543,45,9,530,0,697,15;544,8,7,150,0,0,0;544,8,24,150,0,0,0;544,8,33,150,0,0,0;544,15,29,830,0,0,0;544,23,16,548,0,0,0;544,25,5,599,0,0,0;544,45,22,600,0,0,0;545,13,40,546,0,0,0;545,22,33,238,0,0,0;545,26,49,238,0,0,0;545,34,47,238,0,0,0;545,38,54,238,0,0,0;545,41,36,238,0,0,0;545,49,18,546,0,0,0;546,17,17,238,0,0,0;546,17,29,545,0,0,0;546,40,17,545,0,0,0;546,40,33,238,0,0,0;547,40,5,578,0,0,0;547,42,28,578,0,0,0;547,56,15,578,0,0,0;548,6,26,544,0,0,0;548,9,8,549,0,0,0;548,11,15,899,0,0,0;548,14,0,428,0,0,0;548,15,0,428,0,0,0;548,16,0,428,0,0,0;548,20,8,549,0,0,0;549,5,13,548,0,0,0;549,15,13,548,0,0,0;550,16,25,153,0,0,0;550,22,29,154,0,0,0;550,46,8,544,0,0,0;550,46,24,544,0,0,0;550,46,33,544,0,0,0;551,10,6,184,0,0,0;551,31,16,162,0,0,0;551,32,16,162,0,0,0;553,39,21,579,0,0,0;553,57,15,579,0,0,0;553,57,31,579,0,0,0;553,68,23,579,0,0,0;553,73,45,579,0,0,0;553,76,18,579,0,0,0;553,96,61,579,0,0,0;553,98,50,579,0,0,0;553,109,35,579,0,0,0;553,110,53,579,0,0,0;554,6,2,525,0,0,0;554,6,14,523,0,0,0;554,7,2,525,0,0,0;554,7,14,523,0,0,0;554,8,2,525,0,0,0;554,8,14,523,0,0,0;554,9,2,525,0,0,0;554,9,14,523,0,0,0;554,10,2,525,0,0,0;554,10,14,523,0,0,0;554,11,2,525,0,0,0;554,11,14,523,0,0,0;554,12,2,525,0,0,0;554,12,14,523,0,0,0;555,9,14,526,0,0,0;555,10,14,526,0,0,0;555,11,14,526,0,0,0;556,14,34,576,0,0,0;557,2,12,526,0,0,0;557,3,12,526,0,0,0;557,4,12,526,0,0,0;557,10,2,522,0,0,0;557,10,2,541,0,0,0;557,10,2,590,0,0,0;557,10,2,591,0,0,0;557,10,2,597,0,0,0;557,10,2,598,0,0,0;557,10,2,599,0,0,0;557,10,6,522,0,0,0;557,10,6,541,0,0,0;557,10,6,590,0,0,0;557,10,6,591,0,0,0;557,10,6,597,0,0,0;557,10,6,598,0,0,0;557,10,6,599,0,0,0;558,19,5,574,0,0,0;558,20,5,574,0,0,0;558,21,5,574,0,0,0;558,23,5,574,0,0,0;558,23,31,577,0,0,0;558,24,5,574,0,0,0;558,25,5,574,0,0,0;558,26,5,574,0,0,0;558,26,63,577,0,0,0;558,27,5,574,0,0,0;558,28,5,574,0,0,0;558,29,5,574,0,0,0;558,30,5,574,0,0,0;558,31,5,574,0,0,0;558,32,5,574,0,0,0;558,33,5,574,0,0,0;558,34,5,574,0,0,0;558,35,5,574,0,0,0;558,35,42,577,0,0,0;558,36,5,574,0,0,0;558,47,5,574,0,0,0;558,48,5,574,0,0,0;558,49,5,574,0,0,0;558,50,5,574,0,0,0;558,51,5,574,0,0,0;558,51,13,577,0,0,0;558,51,42,577,0,0,0;558,52,5,574,0,0,0;558,53,5,574,0,0,0;558,54,5,574,0,0,0;558,55,5,574,0,0,0;558,56,5,574,0,0,0;558,57,5,574,0,0,0;558,58,5,574,0,0,0;558,59,5,574,0,0,0;558,60,5,574,0,0,0;558,60,33,577,0,0,0;558,61,5,574,0,0,0;558,62,5,574,0,0,0;558,63,5,574,0,0,0;558,64,5,574,0,0,0;559,6,2,528,0,0,0;559,6,2,585,0,0,0;559,6,12,526,0,0,0;559,7,2,528,0,0,0;559,7,2,585,0,0,0;559,7,12,526,0,0,0;559,8,2,528,0,0,0;559,8,2,585,0,0,0;559,8,12,526,0,0,0;559,9,2,528,0,0,0;559,9,2,585,0,0,0;559,9,12,526,0,0,0;559,10,2,528,0,0,0;559,10,2,585,0,0,0;559,10,12,526,0,0,0;559,11,2,528,0,0,0;559,11,2,585,0,0,0;559,11,12,526,0,0,0;559,12,2,528,0,0,0;559,12,2,585,0,0,0;559,12,12,526,0,0,0;560,12,19,382,0,0,0;560,23,10,197,0,104,28;562,51,3,569,0,0,0;562,51,3,586,0,0,0;562,51,4,569,0,0,0;562,51,4,586,0,0,0;562,51,5,569,0,0,0;562,51,5,586,0,0,0;562,51,6,569,0,0,0;562,51,6,586,0,0,0;562,51,7,569,0,0,0;562,51,7,586,0,0,0;563,24,12,899,0,0,0;564,4,8,25,0,0,0;564,4,25,22,0,0,0;564,5,15,23,0,0,0;564,5,19,23,0,0,0;564,5,23,23,0,0,0;564,11,10,25,0,0,0;564,11,26,22,0,0,0;564,11,31,22,0,0,0;564,17,15,23,0,0,0;564,17,19,23,0,0,0;564,17,23,23,0,0,0;564,18,8,25,0,0,0;564,18,25,22,0,0,0;567,13,8,538,0,0,0;567,15,19,30,0,0,0;567,29,8,538,0,0,0;567,30,8,538,0,0,0;567,31,8,538,0,0,0;567,32,8,538,0,0,0;567,33,8,538,0,0,0;567,34,8,538,0,0,0;567,35,8,538,0,0,0;567,36,8,538,0,0,0;567,36,47,603,0,0,0;567,91,8,530,0,0,0;567,92,8,530,0,0,0;567,93,8,530,0,0,0;567,94,8,530,0,0,0;567,95,8,530,0,0,0;567,96,8,530,0,0,0;567,97,8,530,0,0,0;567,121,24,536,0,0,0;567,121,25,536,0,0,0;567,121,26,536,0,0,0;567,121,27,536,0,0,0;567,121,28,536,0,0,0;567,121,29,536,0,0,0;567,121,30,536,0,0,0;567,121,31,536,0,0,0;568,13,15,33,0,0,0;568,13,15,34,0,0,0;569,8,65,562,0,0,0;569,8,66,562,0,0,0;569,8,67,562,0,0,0;569,34,6,536,0,0,0;569,35,6,536,0,0,0;569,36,6,536,0,0,0;569,37,6,536,0,0,0;569,38,6,536,0,0,0;569,39,6,536,0,0,0;569,40,6,536,0,0,0;569,41,6,536,0,0,0;569,50,72,207,0,0,0;570,0,10,520,0,0,0;570,0,11,520,0,0,0;570,0,12,520,0,0,0;571,10,13,520,0,0,0;572,0,9,296,0,0,0;572,0,9,312,0,150,22;572,0,10,296,0,0,0;572,0,10,312,0,150,22;572,7,13,527,0,150,22;572,8,13,527,0,150,22;572,9,5,290,0,0,0;572,9,13,527,0,150,22;572,10,5,290,0,0,0;572,10,13,527,0,150,22;572,11,5,290,0,0,0;572,11,13,527,0,150,22;572,12,5,290,0,0,0;572,12,13,527,0,150,22;572,13,5,290,0,0,0;572,13,13,527,0,150,22;572,14,13,527,0,150,22;572,15,13,527,0,150,22;573,17,13,129,0,0,0;574,19,87,558,0,0,0;574,20,87,558,0,0,0;574,21,87,558,0,0,0;574,22,87,558,0,0,0;574,23,87,558,0,0,0;574,24,87,558,0,0,0;574,25,87,558,0,0,0;574,26,87,558,0,0,0;574,27,87,558,0,0,0;574,28,87,558,0,0,0;574,29,83,575,0,0,0;574,29,87,558,0,0,0;574,30,87,558,0,0,0;574,31,87,558,0,0,0;574,32,77,575,0,0,0;574,32,87,558,0,0,0;574,33,87,558,0,0,0;574,34,87,558,0,0,0;574,35,87,558,0,0,0;574,36,87,558,0,0,0;574,37,87,558,0,0,0;574,43,87,558,0,0,0;574,44,87,558,0,0,0;574,45,87,558,0,0,0;574,46,76,575,0,0,0;574,46,87,558,0,0,0;574,47,87,558,0,0,0;574,48,87,558,0,0,0;574,49,87,558,0,0,0;574,50,87,558,0,0,0;574,51,87,558,0,0,0;574,52,87,558,0,0,0;574,53,87,558,0,0,0;574,54,87,558,0,0,0;574,55,87,558,0,0,0;574,56,87,558,0,0,0;574,57,87,558,0,0,0;574,58,87,558,0,0,0;574,59,87,558,0,0,0;574,60,87,558,0,0,0;574,61,87,558,0,0,0;575,4,22,574,0,0,0;575,5,8,574,0,0,0;575,25,7,574,0,0,0;576,11,10,556,0,0,0;577,4,7,558,0,0,0;577,4,22,558,0,0,0;577,4,37,558,0,0,0;577,25,7,558,0,0,0;577,25,23,558,0,0,0;577,25,38,558,0,0,0;578,4,22,547,0,0,0;578,5,8,547,0,0,0;578,25,7,547,0,0,0;579,4,7,553,0,0,0;579,4,22,553,0,0,0;579,4,37,553,0,0,0;579,24,8,553,0,0,0;579,24,23,553,0,0,0;579,24,38,553,0,0,0;579,46,14,553,0,0,0;579,46,30,553,0,0,0;579,66,14,553,0,0,0;579,67,30,553,0,0,0;585,22,22,519,0,0,0;585,22,23,519,0,0,0;585,23,21,519,0,0,0;585,48,8,520,0,0,0;585,49,8,520,0,0,0;585,50,8,520,0,0,0;585,51,8,520,0,0,0;585,52,8,520,0,0,0;585,53,8,520,0,0,0;585,56,11,86,0,0,0;585,58,26,587,0,0,0;585,73,11,101,0,0,0;585,74,43,559,0,0,0;585,75,43,559,0,0,0;585,76,28,210,0,0,0;585,76,43,559,0,0,0;585,77,28,210,0,0,0;585,77,43,559,0,0,0;585,78,9,520,0,0,0;585,78,43,559,0,0,0;585,79,43,559,0,0,0;585,80,9,520,0,0,0;585,80,43,559,0,0,0;586,8,65,562,0,0,0;586,8,66,562,0,0,0;586,8,67,562,0,0,0;586,34,6,536,0,0,0;586,35,6,536,0,0,0;586,36,6,536,0,0,0;586,37,6,536,0,0,0;586,38,6,536,0,0,0;586,39,6,536,0,0,0;586,40,6,536,0,0,0;586,41,6,536,0,0,0;586,46,70,601,0,0,0;586,49,74,601,0,0,0;587,13,10,585,0,0,0;588,4,4,177,0,0,0;588,15,10,899,0,0,0;588,15,11,527,0,150,22;589,10,22,359,0,185,2;589,10,22,467,0,185,1;590,2,3,119,0,0,0;590,7,3,522,0,0,0;590,7,3,541,0,0,0;590,7,3,557,0,0,0;590,7,3,591,0,0,0;590,7,3,597,0,0,0;590,7,3,598,0,0,0;590,7,3,599,0,0,0;590,7,6,522,0,0,0;590,7,6,541,0,0,0;590,7,6,557,0,0,0;590,7,6,591,0,0,0;590,7,6,597,0,0,0;590,7,6,598,0,0,0;590,7,6,599,0,0,0;590,7,9,522,0,0,0;590,7,9,541,0,0,0;590,7,9,557,0,0,0;590,7,9,591,0,0,0;590,7,9,597,0,0,0;590,7,9,598,0,0,0;590,7,9,599,0,0,0;590,19,29,899,0,0,0;591,3,11,530,0,619,25;591,5,5,858,0,619,1;591,6,24,530,0,0,0;591,14,14,522,0,322,1;591,14,14,541,0,322,1;591,14,14,557,0,322,1;591,14,14,590,0,322,1;591,14,14,597,0,322,1;591,14,14,598,0,322,1;591,14,14,599,0,322,1;591,14,14,694,0,322,1;591,14,14,703,0,322,1;591,14,14,704,0,322,1;591,14,14,705,0,322,1;592,2,3,593,0,0,0;592,3,3,593,0,0,0;592,20,12,522,0,0,0;592,21,12,522,0,0,0;593,12,2,592,0,0,0;593,12,23,594,0,0,0;593,13,2,592,0,0,0;593,13,23,594,0,0,0;594,11,20,877,0,637,9;594,11,23,899,0,0,0;594,24,2,595,0,0,0;594,24,2,877,0,0,0;594,24,21,593,0,0,0;594,25,2,595,0,0,0;594,25,2,877,0,0,0;594,25,21,593,0,0,0;594,45,19,522,0,0,0;594,46,19,522,0,0,0;594,70,23,877,0,637,9;595,2,19,596,0,0,0;595,2,19,596,0,637,1;595,2,19,877,0,637,1;595,3,19,596,0,0,0;595,3,19,596,0,637,1;595,3,19,877,0,637,1;595,16,2,594,0,0,0;595,16,2,877,0,0,0;595,17,2,594,0,0,0;595,17,2,877,0,0,0;596,3,6,877,0,637,10;596,4,6,877,0,637,10;596,76,4,595,0,0,0;596,76,4,877,0,0,0;596,76,5,877,0,637,30;596,77,4,595,0,0,0;596,77,4,877,0,0,0;596,77,5,877,0,637,30;597,3,12,524,0,0,0;597,4,12,524,0,0,0;597,8,4,522,0,0,0;597,8,4,541,0,0,0;597,8,4,557,0,0,0;597,8,4,590,0,0,0;597,8,4,591,0,0,0;597,8,4,598,0,0,0;597,8,4,599,0,0,0;597,8,8,522,0,0,0;597,8,8,541,0,0,0;597,8,8,557,0,0,0;597,8,8,590,0,0,0;597,8,8,591,0,0,0;597,8,8,598,0,0,0;597,8,8,599,0,0,0;598,2,4,899,1986,0,0;598,10,12,523,0,0,0;598,18,4,522,0,0,0;598,18,4,541,0,0,0;598,18,4,557,0,0,0;598,18,4,590,0,0,0;598,18,4,591,0,0,0;598,18,4,597,0,0,0;598,18,4,599,0,0,0;598,18,7,522,0,0,0;598,18,7,541,0,0,0;598,18,7,557,0,0,0;598,18,7,590,0,0,0;598,18,7,591,0,0,0;598,18,7,597,0,0,0;598,18,7,599,0,0,0;599,2,12,544,0,0,0;599,3,12,544,0,0,0;599,8,3,522,0,0,0;599,8,3,541,0,0,0;599,8,3,557,0,0,0;599,8,3,590,0,0,0;599,8,3,591,0,0,0;599,8,3,597,0,0,0;599,8,3,598,0,0,0;599,9,3,522,0,0,0;599,9,3,541,0,0,0;599,9,3,557,0,0,0;599,9,3,590,0,0,0;599,9,3,591,0,0,0;599,9,3,597,0,0,0;599,9,3,598,0,0,0;600,4,6,544,0,0,0;600,4,7,544,0,0,0;600,5,6,899,0,0,0;601,5,34,586,0,0,0;601,6,34,586,0,0,0;601,10,12,586,0,0,0;601,11,12,586,0,0,0;602,0,11,519,0,0,0;602,0,12,519,0,0,0;602,0,13,519,0,0,0;602,0,14,519,0,0,0;602,0,15,519,0,0,0;603,26,14,567,0,0,0;603,26,15,567,0,0,0;604,48,22,538,0,0,0;604,48,23,538,0,0,0;605,48,22,538,0,0,0;605,48,23,538,0,0,0;606,15,21,469,0,0,0;606,15,21,481,0,257,1;606,15,21,482,0,257,2;606,15,21,498,0,257,3;606,16,1,469,0,0,0;606,17,1,469,0,0,0;606,28,1,469,0,0,0;606,29,1,469,0,0,0;606,37,18,469,0,0,0;606,37,19,469,0,0,0;608,26,19,610,0,0,0;609,18,19,526,0,0,0;610,34,13,608,0,0,0;611,7,10,520,0,0,0;612,3,11,524,0,0,0;612,4,11,524,0,0,0;613,9,32,526,0,0,0;614,16,18,260,0,0,0;614,30,14,617,0,0,0;614,39,19,260,0,0,0;614,62,11,260,0,0,0;615,17,19,371,0,0,0;616,25,24,618,0,0,0;616,52,21,620,0,0,0;617,16,18,260,0,0,0;617,39,19,260,0,0,0;617,62,11,260,0,0,0;618,17,19,371,0,0,0;618,32,26,616,0,0,0;619,12,19,620,0,0,0;619,18,21,620,0,0,0;619,18,51,620,0,0,0;619,27,7,621,0,0,0;620,11,19,616,0,0,0;620,11,49,616,0,0,0;620,29,15,619,0,0,0;620,33,15,619,0,0,0;621,18,21,619,0,0,0;621,18,51,619,0,0,0;622,2,10,84,0,0,0;622,10,6,229,0,0,0;622,24,10,84,0,0,0;623,6,3,624,0,0,0;623,7,3,624,0,0,0;623,12,9,84,0,0,0;623,13,9,84,0,0,0;624,6,3,625,0,0,0;624,7,3,625,0,0,0;624,12,8,623,0,0,0;625,5,3,626,0,0,0;625,5,7,626,0,0,0;625,5,11,624,0,0,0;626,2,3,627,0,0,0;626,3,3,627,0,0,0;626,12,3,625,0,339,27;626,13,3,625,0,339,27;627,2,3,626,0,0,0;627,3,3,626,0,0,0;627,6,8,628,0,339,27;628,9,3,630,0,339,33;628,9,21,629,0,339,36;628,9,43,631,0,0,0;628,9,53,629,0,0,0;628,10,3,630,0,339,33;628,10,21,629,0,339,36;628,10,43,631,0,0,0;628,10,53,629,0,0,0;628,28,48,527,0,0,0;628,28,49,527,0,0,0;628,29,23,630,0,0,0;628,30,23,630,0,0,0;628,31,45,765,0,0,0;628,33,45,765,0,0,0;628,35,45,765,0,0,0;628,38,48,631,0,0,0;628,38,49,631,0,0,0;629,5,28,628,0,0,0;629,6,28,628,0,0,0;629,12,2,628,0,0,0;630,25,2,628,0,0,0;630,26,27,628,0,0,0;630,27,27,628,0,0,0;631,1,5,628,0,0,0;631,9,27,628,0,0,0;631,10,27,628,0,0,0;631,14,2,632,0,0,0;631,14,2,632,0,339,40;631,15,2,632,0,0,0;631,15,2,632,0,339,40;631,24,2,632,0,0,0;631,24,2,632,0,339,40;631,25,2,632,0,0,0;631,25,2,632,0,339,40;632,4,11,631,0,0,0;632,4,27,414,0,611,3;632,4,29,631,0,0,0;632,12,11,631,0,0,0;632,12,29,631,0,0,0;632,27,18,631,0,0,0;632,32,10,899,0,0,0;632,35,18,631,0,0,0;633,0,6,29,0,0,0;633,0,6,519,479,0,0;633,0,7,29,0,0,0;633,0,7,519,479,0,0;633,0,8,29,0,0,0;633,0,8,519,479,0,0;633,0,9,29,0,0,0;633,0,9,519,479,0,0;633,0,10,29,0,0,0;633,0,10,519,479,0,0;634,27,5,225,0,107,1;634,28,5,225,0,107,1;635,20,3,102,0,0,0;635,20,4,102,0,0,0;635,20,5,102,0,0,0;635,20,6,102,0,0,0;636,13,8,825,0,576,1;636,13,13,360,0,0,0;636,14,8,825,0,576,1;637,15,4,324,0,0,0;637,15,5,324,0,0,0;638,15,7,639,0,0,0;638,15,7,647,841,0,0;638,18,16,687,0,0,0;639,15,10,640,0,375,3;639,15,10,648,0,375,3;639,19,20,638,0,0,0;640,11,12,645,0,0,0;640,11,12,649,0,0,0;640,18,8,641,0,0,0;640,18,8,650,0,0,0;640,23,30,639,0,0,0;640,23,30,647,0,0,0;640,24,9,641,0,376,3;640,24,9,650,0,376,3;641,12,11,643,0,0,0;641,15,34,640,0,0,0;641,15,34,648,842,0,0;641,28,35,640,0,0,0;641,28,35,648,842,0,0;641,30,11,642,0,0,0;642,15,58,641,0,0,0;642,15,58,650,0,0,0;643,7,19,644,0,0,0;643,37,22,641,0,0,0;643,37,22,650,0,0,0;644,9,7,646,0,0,0;644,25,21,645,0,0,0;644,25,21,649,0,0,0;644,29,11,643,0,0,0;645,13,14,644,0,0,0;645,28,22,640,0,0,0;645,28,22,648,842,0,0;646,21,8,876,0,0,0;646,21,8,876,1727,0,0;646,22,8,876,0,0,0;646,22,8,876,1727,0,0;646,36,47,644,0,0,0;647,15,10,640,0,375,3;647,15,10,648,0,375,3;647,19,20,638,0,0,0;648,11,12,645,0,0,0;648,11,12,649,0,0,0;648,18,8,641,0,0,0;648,18,8,650,0,0,0;648,23,30,639,0,0,0;648,23,30,647,0,0,0;648,24,9,641,0,376,3;648,24,9,650,0,376,3;649,13,14,644,0,0,0;649,28,22,640,0,0,0;649,28,22,648,842,0,0;650,12,11,643,0,0,0;650,15,34,640,0,0,0;650,15,34,648,842,0,0;650,28,35,640,0,0,0;650,28,35,648,842,0,0;650,30,11,642,0,0,0;651,14,40,657,0,0,0;651,14,41,657,0,0,0;651,15,40,657,0,0,0;651,15,41,657,0,0,0;651,21,11,657,0,0,0;651,21,12,657,0,0,0;651,22,11,657,0,0,0;651,22,12,657,0,0,0;651,32,45,694,0,0,0;651,32,45,703,0,360,2;651,32,45,704,0,360,3;651,32,45,705,0,360,4;651,33,45,694,0,0,0;651,33,45,703,0,360,2;651,33,45,704,0,360,3;651,33,45,705,0,360,4;651,34,45,694,0,0,0;651,34,45,703,0,360,2;651,34,45,704,0,360,3;651,34,45,705,0,360,4;651,35,45,694,0,0,0;651,35,45,703,0,360,2;651,35,45,704,0,360,3;651,35,45,705,0,360,4;651,36,25,656,0,0,0;651,36,26,656,0,0,0;651,37,25,656,0,0,0;651,37,26,656,0,0,0;651,54,22,656,0,0,0;651,54,23,656,0,0,0;651,55,22,656,0,0,0;651,55,23,656,0,0,0;652,15,17,657,0,0,0;652,15,18,657,0,0,0;652,16,17,657,0,0,0;652,16,18,657,0,0,0;652,16,33,657,0,0,0;652,16,34,657,0,0,0;652,16,50,657,0,0,0;652,16,51,657,0,0,0;652,17,33,657,0,0,0;652,17,34,657,0,0,0;652,17,50,657,0,0,0;652,17,51,657,0,0,0;652,27,24,657,0,0,0;652,27,25,657,0,0,0;652,28,24,657,0,0,0;652,28,25,657,0,0,0;652,29,45,657,0,0,0;652,29,46,657,0,0,0;652,30,45,657,0,0,0;652,30,46,657,0,0,0;652,31,11,657,0,0,0;652,31,12,657,0,0,0;652,32,11,657,0,0,0;652,32,12,657,0,0,0;652,40,42,657,0,0,0;652,40,52,657,0,0,0;652,40,53,657,0,0,0;652,41,52,657,0,0,0;652,41,53,657,0,0,0;653,12,10,658,0,0,0;653,12,11,658,0,0,0;653,12,32,657,0,0,0;653,13,10,658,0,0,0;653,13,11,658,0,0,0;653,13,22,658,0,0,0;653,13,23,658,0,0,0;653,14,22,658,0,0,0;653,14,23,658,0,0,0;653,15,32,657,0,0,0;653,15,33,657,0,0,0;653,16,32,657,0,0,0;653,16,33,657,0,0,0;653,20,17,658,0,0,0;653,20,18,658,0,0,0;653,21,17,658,0,0,0;653,21,18,658,0,0,0;653,22,12,658,0,0,0;653,22,13,658,0,0,0;653,23,12,658,0,0,0;653,23,13,658,0,0,0;653,24,26,658,0,0,0;653,24,27,658,0,0,0;653,25,26,658,0,0,0;653,25,27,658,0,0,0;653,28,11,658,0,0,0;653,28,12,658,0,0,0;653,29,11,658,0,0,0;653,29,12,658,0,0,0;653,30,19,658,0,0,0;653,30,20,658,0,0,0;653,31,19,658,0,0,0;653,31,20,658,0,0,0;653,31,29,657,0,0,0;653,31,30,657,0,0,0;653,32,29,657,0,0,0;653,32,30,657,0,0,0;653,35,15,658,0,0,0;653,36,27,657,0,0,0;653,44,39,657,0,0,0;653,50,23,654,0,0,0;653,52,38,657,0,0,0;653,52,39,657,0,0,0;653,53,38,657,0,0,0;653,53,39,657,0,0,0;654,8,24,653,0,0,0;654,18,10,660,0,0,0;654,33,47,656,0,0,0;654,34,23,659,0,0,0;654,34,47,656,0,0,0;655,16,11,659,0,0,0;655,16,12,659,0,0,0;655,17,11,659,0,0,0;655,17,12,659,0,0,0;655,18,17,659,0,0,0;655,18,18,659,0,0,0;655,19,17,659,0,0,0;655,19,18,659,0,0,0;655,20,24,659,0,0,0;655,20,25,659,0,0,0;655,21,24,659,0,0,0;655,21,25,659,0,0,0;655,21,41,659,0,0,0;655,21,42,659,0,0,0;655,21,49,656,0,0,0;655,22,32,659,0,0,0;655,22,33,659,0,0,0;655,22,41,659,0,0,0;655,22,42,659,0,0,0;655,23,32,659,0,0,0;655,23,33,659,0,0,0;655,25,14,659,0,0,0;655,25,15,659,0,0,0;655,26,14,659,0,0,0;655,26,15,659,0,0,0;655,26,27,659,0,0,0;655,26,28,659,0,0,0;655,27,21,659,0,0,0;655,27,22,659,0,0,0;655,27,27,659,0,0,0;655,27,28,659,0,0,0;655,27,48,656,0,0,0;655,27,49,656,0,0,0;655,28,21,659,0,0,0;655,28,22,659,0,0,0;655,28,38,659,0,0,0;655,28,39,659,0,0,0;655,28,48,656,0,0,0;655,28,49,656,0,0,0;655,29,38,659,0,0,0;655,29,39,659,0,0,0;655,32,17,659,0,0,0;655,32,18,659,0,0,0;655,33,17,659,0,0,0;655,33,18,659,0,0,0;655,33,28,659,0,0,0;655,33,29,659,0,0,0;655,34,11,659,0,0,0;655,34,12,659,0,0,0;655,34,28,659,0,0,0;655,34,29,659,0,0,0;655,34,42,659,0,0,0;655,34,43,659,0,0,0;655,35,11,659,0,0,0;655,35,12,659,0,0,0;655,35,42,659,0,0,0;655,35,43,659,0,0,0;656,17,9,654,0,0,0;656,18,9,654,0,0,0;656,19,9,654,0,0,0;656,20,9,654,0,0,0;656,25,30,651,0,0,0;656,25,31,651,0,0,0;656,26,30,651,0,0,0;656,26,31,651,0,0,0;656,37,27,651,0,0,0;656,37,28,651,0,0,0;656,38,27,651,0,0,0;656,38,28,651,0,0,0;656,44,24,655,0,0,0;657,11,11,653,0,0,0;657,15,20,651,0,0,0;657,15,21,651,0,0,0;657,16,20,651,0,0,0;657,16,21,651,0,0,0;657,19,60,651,0,0,0;657,19,61,651,0,0,0;657,20,60,651,0,0,0;657,20,61,651,0,0,0;657,24,50,651,0,0,0;657,24,51,651,0,0,0;657,25,50,651,0,0,0;657,25,51,651,0,0,0;657,31,16,651,0,0,0;657,31,17,651,0,0,0;657,32,16,651,0,0,0;657,32,17,651,0,0,0;657,32,29,651,0,0,0;657,32,30,651,0,0,0;657,33,29,651,0,0,0;657,33,30,651,0,0,0;657,38,13,653,0,0,0;657,49,53,652,0,0,0;657,55,26,653,0,0,0;657,56,51,651,0,0,0;657,56,52,651,0,0,0;657,57,51,651,0,0,0;657,57,52,651,0,0,0;657,70,29,651,0,0,0;657,70,30,651,0,0,0;657,71,29,651,0,0,0;657,71,30,651,0,0,0;658,15,10,651,0,0,0;658,15,11,651,0,0,0;658,16,10,651,0,0,0;658,16,11,651,0,0,0;658,16,22,651,0,0,0;658,16,23,651,0,0,0;658,17,22,651,0,0,0;658,17,23,651,0,0,0;658,23,17,651,0,0,0;658,23,18,651,0,0,0;658,24,17,651,0,0,0;658,24,18,651,0,0,0;658,27,26,651,0,0,0;658,27,27,651,0,0,0;658,28,26,651,0,0,0;658,28,27,651,0,0,0;658,31,11,651,0,0,0;658,31,12,651,0,0,0;658,32,11,651,0,0,0;658,32,12,651,0,0,0;658,33,19,651,0,0,0;658,33,20,651,0,0,0;658,34,19,651,0,0,0;658,34,20,651,0,0,0;658,42,14,653,0,0,0;659,13,27,654,0,0,0;659,21,11,651,0,0,0;659,21,12,651,0,0,0;659,22,11,651,0,0,0;659,22,12,651,0,0,0;659,23,17,651,0,0,0;659,23,18,651,0,0,0;659,24,17,651,0,0,0;659,24,18,651,0,0,0;659,25,24,651,0,0,0;659,25,25,651,0,0,0;659,26,24,651,0,0,0;659,26,25,651,0,0,0;659,26,41,651,0,0,0;659,26,42,651,0,0,0;659,27,32,651,0,0,0;659,27,33,651,0,0,0;659,27,41,651,0,0,0;659,27,42,651,0,0,0;659,28,32,651,0,0,0;659,28,33,651,0,0,0;659,31,27,651,0,0,0;659,31,28,651,0,0,0;659,32,21,651,0,0,0;659,32,22,651,0,0,0;659,32,27,651,0,0,0;659,32,28,651,0,0,0;659,33,21,651,0,0,0;659,33,22,651,0,0,0;659,33,38,651,0,0,0;659,33,39,651,0,0,0;659,34,38,651,0,0,0;659,34,39,651,0,0,0;659,37,17,651,0,0,0;659,37,18,651,0,0,0;659,38,17,651,0,0,0;659,38,18,651,0,0,0;659,39,11,651,0,0,0;659,39,12,651,0,0,0;659,39,34,651,0,0,0;659,39,35,651,0,0,0;659,39,42,651,0,0,0;659,39,43,651,0,0,0;659,40,11,651,0,0,0;659,40,12,651,0,0,0;659,40,34,651,0,0,0;659,40,35,651,0,0,0;659,40,42,651,0,0,0;659,40,43,651,0,0,0;660,14,8,661,0,0,0;660,14,47,654,0,0,0;661,15,34,662,0,0,0;661,15,35,662,0,0,0;661,16,34,662,0,0,0;661,16,35,662,0,0,0;661,16,56,662,0,0,0;661,16,57,662,0,0,0;661,17,56,662,0,0,0;661,17,57,662,0,0,0;661,21,14,662,0,0,0;661,21,15,662,0,0,0;661,22,14,662,0,0,0;661,22,15,662,0,0,0;661,37,19,662,0,0,0;661,44,17,662,0,0,0;661,44,18,662,0,0,0;661,45,17,662,0,0,0;661,45,18,662,0,0,0;661,48,51,662,0,0,0;661,48,52,662,0,0,0;661,49,33,662,0,0,0;661,49,34,662,0,0,0;661,49,51,662,0,0,0;661,49,52,662,0,0,0;661,50,33,662,0,0,0;661,50,34,662,0,0,0;661,52,60,660,0,0,0;661,67,15,883,0,0,0;661,67,15,883,0,649,1;661,68,15,883,0,0,0;661,68,15,883,0,649,1;661,70,50,662,0,0,0;661,70,51,662,0,0,0;661,71,50,662,0,0,0;661,71,51,662,0,0,0;661,75,20,662,0,0,0;661,75,21,662,0,0,0;661,76,20,662,0,0,0;661,76,21,662,0,0,0;661,78,34,662,0,0,0;661,78,35,662,0,0,0;661,79,34,662,0,0,0;661,79,35,662,0,0,0;662,14,15,651,0,0,0;662,14,16,651,0,0,0;662,15,15,651,0,0,0;662,15,16,651,0,0,0;662,27,10,661,0,0,0;662,41,40,651,0,0,0;662,41,41,651,0,0,0;662,42,40,651,0,0,0;662,42,41,651,0,0,0;662,43,12,651,0,0,0;662,43,13,651,0,0,0;662,44,12,651,0,0,0;662,44,13,651,0,0,0;662,65,56,651,0,0,0;662,65,57,651,0,0,0;662,66,56,651,0,0,0;662,66,57,651,0,0,0;662,69,14,651,0,0,0;662,69,15,651,0,0,0;662,70,14,651,0,0,0;662,70,15,651,0,0,0;663,18,52,664,0,0,0;663,28,42,665,0,0,0;663,34,49,665,0,0,0;663,43,67,692,0,371,1;663,54,73,693,0,0,0;663,55,77,664,0,0,0;663,82,78,664,0,0,0;663,97,77,664,0,0,0;663,101,17,691,0,0,0;664,6,3,663,0,0,0;664,6,8,694,0,0,0;664,6,8,703,0,360,2;664,6,8,704,0,360,3;664,6,8,705,0,360,4;664,6,22,694,0,0,0;664,6,22,703,0,360,2;664,6,22,704,0,360,3;664,6,22,705,0,360,4;664,6,32,663,0,0,0;664,6,37,694,0,0,0;664,6,37,703,0,360,2;664,6,37,704,0,360,3;664,6,37,705,0,360,4;664,30,18,663,0,0,0;664,51,44,687,0,0,0;664,52,6,663,0,0,0;665,6,7,663,0,0,0;665,7,81,663,0,0,0;665,7,124,693,0,0,0;665,7,159,691,0,0,0;665,29,6,693,0,0,0;665,29,154,692,0,0,0;666,6,7,693,0,0,0;666,7,22,693,0,0,0;666,8,40,668,0,0,0;666,8,40,707,0,0,0;666,15,43,693,0,0,0;666,21,22,693,0,0,0;666,21,56,698,0,0,0;666,24,8,693,0,0,0;667,8,5,37,0,0,0;667,8,5,689,0,0,0;668,3,19,669,0,0,0;668,4,17,669,0,0,0;668,5,16,669,0,0,0;668,7,15,669,0,0,0;668,8,14,669,0,0,0;668,9,14,669,0,0,0;668,10,13,669,0,0,0;668,13,13,669,0,0,0;668,13,35,688,0,0,0;668,14,13,669,0,0,0;668,14,35,688,0,0,0;668,15,13,669,0,0,0;668,16,13,669,0,0,0;668,17,13,669,0,0,0;668,18,14,669,0,0,0;668,19,14,669,0,0,0;668,20,15,669,0,0,0;668,22,16,669,0,0,0;668,23,17,669,0,0,0;668,24,19,669,0,0,0;669,33,38,881,0,645,2;669,34,38,881,0,645,2;669,41,28,668,0,0,0;669,41,28,707,0,377,1;670,0,27,707,0,0,0;670,0,28,707,0,0,0;670,0,29,707,0,0,0;671,13,5,709,0,0,0;671,14,5,709,0,0,0;672,0,17,708,0,0,0;672,0,18,708,0,0,0;673,0,8,690,0,0,0;673,0,9,690,0,0,0;673,23,45,674,0,0,0;673,24,45,674,0,0,0;673,49,31,674,0,0,0;673,49,32,674,0,0,0;673,49,33,674,0,0,0;674,4,23,673,0,0,0;674,4,24,673,0,0,0;674,14,67,706,0,0,0;674,15,67,706,0,0,0;674,30,41,673,0,377,5;674,30,41,706,0,377,6;674,46,26,675,0,0,0;674,46,26,861,0,632,1;674,47,26,675,0,0,0;674,47,26,861,0,632,1;675,37,22,674,0,0,0;675,38,22,674,0,0,0;675,41,92,676,0,0,0;676,25,54,677,0,0,0;676,25,55,677,0,0,0;676,26,22,675,0,0,0;676,26,22,861,0,632,1;676,26,54,677,0,0,0;676,26,55,677,0,0,0;677,13,22,880,0,645,2;677,13,35,688,0,0,0;677,14,22,880,0,645,2;677,14,35,688,0,0,0;678,29,52,508,0,0,0;678,30,52,508,0,0,0;678,31,48,679,0,0,0;679,24,34,678,0,0,0;680,10,91,683,0,0,0;680,10,104,681,0,0,0;680,11,11,681,0,0,0;680,11,91,683,0,0,0;680,12,11,681,0,0,0;680,12,91,683,0,0,0;680,13,11,681,0,0,0;680,13,91,683,0,0,0;680,26,34,683,0,0,0;680,26,141,683,0,0,0;680,27,17,681,0,0,0;680,27,34,683,0,0,0;680,27,141,683,0,0,0;680,28,17,681,0,0,0;680,28,34,683,0,0,0;680,29,34,683,0,0,0;680,36,56,681,0,0,0;680,39,68,681,0,0,0;680,44,9,681,0,0,0;680,45,9,681,0,0,0;680,48,69,681,0,0,0;680,48,90,681,0,0,0;680,49,53,681,0,0,0;680,50,53,681,0,0,0;680,60,20,681,0,0,0;680,61,20,681,0,0,0;680,67,56,683,0,0,0;680,68,56,683,0,0,0;680,69,56,683,0,0,0;680,70,56,683,0,0,0;680,70,141,683,0,0,0;680,71,32,681,0,0,0;680,71,141,683,0,0,0;680,72,141,683,0,0,0;680,73,141,683,0,0,0;680,86,49,683,0,0,0;680,87,49,683,0,0,0;680,88,49,683,0,0,0;680,88,104,681,0,0,0;680,89,49,683,0,0,0;681,10,21,680,0,0,0;681,12,37,680,0,0,0;681,19,9,682,0,0,0;681,20,9,682,0,0,0;681,21,35,683,0,0,0;681,22,29,680,0,0,0;681,22,35,683,0,0,0;681,23,29,680,0,0,0;681,23,46,680,0,0,0;681,27,38,683,0,0,0;681,28,38,683,0,0,0;681,29,29,680,0,0,0;681,30,29,680,0,0,0;681,30,47,680,0,0,0;681,35,27,680,0,0,0;681,36,9,682,0,0,0;681,36,27,680,0,0,0;681,36,45,680,0,0,0;681,37,9,682,0,0,0;681,37,34,683,0,0,0;681,38,34,683,0,0,0;681,48,28,680,0,0,0;681,48,34,680,0,0,0;681,48,40,680,0,0,0;681,49,21,680,0,0,0;682,13,42,681,0,0,0;682,35,42,681,0,0,0;683,10,21,680,0,0,0;683,10,66,680,0,0,0;683,11,21,680,0,0,0;683,11,66,680,0,0,0;683,12,21,680,0,0,0;683,12,66,680,0,0,0;683,13,21,680,0,0,0;683,13,66,680,0,0,0;683,19,128,679,0,0,0;683,20,128,679,0,0,0;683,21,128,679,0,0,0;683,22,128,679,0,0,0;683,27,8,681,0,0,0;683,28,8,681,0,0,0;683,29,116,508,0,381,18;683,37,45,681,0,0,0;683,38,45,681,0,0,0;683,41,26,681,0,0,0;683,42,26,681,0,0,0;683,62,92,679,0,0,0;683,63,8,680,0,0,0;683,63,92,679,0,0,0;683,64,8,680,0,0,0;683,64,92,679,0,0,0;683,65,8,680,0,0,0;683,65,92,679,0,0,0;683,66,8,680,0,0,0;683,77,39,680,0,0,0;683,78,39,680,0,0,0;683,79,39,680,0,0,0;683,80,39,680,0,0,0;683,87,100,680,0,0,0;683,88,100,680,0,0,0;683,105,79,680,0,0,0;683,106,79,680,0,0,0;683,107,79,680,0,0,0;683,108,79,680,0,0,0;686,7,118,691,0,0,0;686,33,1,696,0,0,0;686,34,1,696,0,0,0;687,29,21,638,0,0,0;687,51,167,694,0,0,0;687,51,167,703,0,360,2;687,51,167,704,0,360,3;687,51,167,705,0,360,4;687,52,167,694,0,0,0;687,52,167,703,0,360,2;687,52,167,704,0,360,3;687,52,167,705,0,360,4;687,53,167,694,0,0,0;687,53,167,703,0,360,2;687,53,167,704,0,360,3;687,53,167,705,0,360,4;687,54,167,694,0,0,0;687,54,167,703,0,360,2;687,54,167,704,0,360,3;687,54,167,705,0,360,4;687,55,167,694,0,0,0;687,55,167,703,0,360,2;687,55,167,704,0,360,3;687,55,167,705,0,360,4;687,56,167,694,0,0,0;687,56,167,703,0,360,2;687,56,167,704,0,360,3;687,56,167,705,0,360,4;687,70,153,664,0,0,0;688,61,167,694,0,0,0;688,61,167,703,0,360,2;688,61,167,704,0,360,3;688,61,167,705,0,360,4;688,62,167,694,0,0,0;688,62,167,703,0,360,2;688,62,167,704,0,360,3;688,62,167,705,0,360,4;688,63,167,694,0,0,0;688,63,167,703,0,360,2;688,63,167,704,0,360,3;688,63,167,705,0,360,4;688,69,22,668,0,0,0;688,69,22,707,0,377,1;688,70,22,668,0,0,0;688,70,22,707,0,377,1;688,74,167,694,0,0,0;688,74,167,703,0,360,2;688,74,167,704,0,360,3;688,74,167,705,0,360,4;688,75,167,694,0,0,0;688,75,167,703,0,360,2;688,75,167,704,0,360,3;688,75,167,705,0,360,4;688,76,167,694,0,0,0;688,76,167,703,0,360,2;688,76,167,704,0,360,3;688,76,167,705,0,360,4;688,77,167,694,0,0,0;688,77,167,703,0,360,2;688,77,167,704,0,360,3;688,77,167,705,0,360,4;689,15,25,667,0,0,0;689,38,76,37,0,0,0;689,39,76,37,0,0,0;689,40,76,37,0,0,0;689,41,76,37,0,0,0;689,42,76,37,0,0,0;689,43,76,37,0,0,0;689,44,76,37,0,0,0;689,45,76,37,0,0,0;690,0,17,708,0,0,0;690,0,18,708,0,0,0;690,7,5,673,0,0,0;690,8,5,673,0,0,0;691,17,10,665,0,0,0;691,21,36,663,0,0,0;691,60,14,686,0,0,0;692,53,44,665,0,0,0;693,10,20,665,0,0,0;693,19,32,666,0,0,0;693,21,53,666,0,0,0;693,26,63,665,0,0,0;693,30,24,899,0,0,0;693,32,20,666,0,0,0;693,42,33,666,0,0,0;693,42,55,666,0,0,0;694,31,112,703,0,0,0;694,31,112,704,0,0,0;694,31,112,705,0,0,0;694,51,10,687,0,0,0;694,52,10,687,0,0,0;694,53,10,687,0,0,0;694,54,10,687,0,0,0;694,55,10,687,0,0,0;694,56,10,687,0,0,0;694,77,253,591,0,0,0;694,106,18,664,0,0,0;694,120,243,841,0,0,0;694,121,243,841,0,0,0;694,131,19,664,0,0,0;694,148,18,664,0,0,0;694,167,129,651,0,0,0;694,168,129,651,0,0,0;694,169,129,651,0,0,0;694,170,129,651,0,0,0;694,233,10,688,0,359,3;694,233,10,695,0,0,0;694,234,10,688,0,359,3;694,234,10,695,0,0,0;694,235,10,688,0,359,3;694,235,10,695,0,0,0;694,246,10,688,0,359,3;694,246,10,695,0,0,0;694,247,10,688,0,359,3;694,247,10,695,0,0,0;694,248,10,688,0,359,3;694,248,10,695,0,0,0;694,249,10,688,0,359,3;694,249,10,695,0,0,0;695,61,167,694,0,0,0;695,61,167,703,0,360,2;695,61,167,704,0,360,3;695,61,167,705,0,360,4;695,62,167,694,0,0,0;695,62,167,703,0,360,2;695,62,167,704,0,360,3;695,62,167,705,0,360,4;695,63,167,694,0,0,0;695,63,167,703,0,360,2;695,63,167,704,0,360,3;695,63,167,705,0,360,4;695,74,167,694,0,0,0;695,74,167,703,0,360,2;695,74,167,704,0,360,3;695,74,167,705,0,360,4;695,75,167,694,0,0,0;695,75,167,703,0,360,2;695,75,167,704,0,360,3;695,75,167,705,0,360,4;695,76,167,694,0,0,0;695,76,167,703,0,360,2;695,76,167,704,0,360,3;695,76,167,705,0,360,4;695,77,167,694,0,0,0;695,77,167,703,0,360,2;695,77,167,704,0,360,3;695,77,167,705,0,360,4;696,31,24,686,0,0,0;696,31,24,686,0,380,4;696,49,25,697,0,380,3;696,50,25,697,0,380,3;697,23,8,698,0,0,0;697,24,8,698,0,0,0;697,30,65,696,0,0,0;697,31,65,696,0,0,0;698,9,79,697,0,0,0;698,9,94,699,0,0,0;698,31,100,666,0,0,0;698,34,82,699,0,0,0;698,34,83,699,0,0,0;698,34,84,699,0,0,0;698,34,85,699,0,0,0;698,34,86,699,0,0,0;698,34,87,699,0,0,0;698,36,82,699,0,362,1;698,36,83,699,0,362,1;698,36,84,699,0,362,1;698,36,85,699,0,362,1;698,36,86,699,0,362,1;698,36,87,699,0,362,1;699,6,66,700,0,0,0;700,17,57,699,0,0,0;700,59,18,701,0,0,0;701,10,123,700,0,0,0;701,24,14,702,0,0,0;701,24,21,332,0,628,10;702,24,11,698,0,0,0;702,24,34,701,0,0,0;703,51,10,687,0,0,0;703,52,10,687,0,0,0;703,53,10,687,0,0,0;703,54,10,687,0,0,0;703,55,10,687,0,0,0;703,56,10,687,0,0,0;703,77,253,591,0,0,0;703,106,18,664,0,0,0;703,120,243,841,0,0,0;703,121,243,841,0,0,0;703,131,19,664,0,0,0;703,148,18,664,0,0,0;703,163,188,694,0,0,0;703,163,188,704,0,0,0;703,163,188,705,0,0,0;703,167,129,651,0,0,0;703,168,129,651,0,0,0;703,169,129,651,0,0,0;703,170,129,651,0,0,0;703,233,10,688,0,359,3;703,233,10,695,0,0,0;703,234,10,688,0,359,3;703,234,10,695,0,0,0;703,235,10,688,0,359,3;703,235,10,695,0,0,0;703,246,10,688,0,359,3;703,246,10,695,0,0,0;703,247,10,688,0,359,3;703,247,10,695,0,0,0;703,248,10,688,0,359,3;703,248,10,695,0,0,0;703,249,10,688,0,359,3;703,249,10,695,0,0,0;704,50,236,694,0,0,0;704,50,236,703,0,0,0;704,50,236,705,0,0,0;704,51,10,687,0,0,0;704,52,10,687,0,0,0;704,53,10,687,0,0,0;704,54,10,687,0,0,0;704,55,10,687,0,0,0;704,56,10,687,0,0,0;704,77,253,591,0,0,0;704,106,18,664,0,0,0;704,120,243,841,0,0,0;704,121,243,841,0,0,0;704,131,19,664,0,0,0;704,148,18,664,0,0,0;704,167,129,651,0,0,0;704,168,129,651,0,0,0;704,169,129,651,0,0,0;704,170,129,651,0,0,0;704,233,10,688,0,359,3;704,233,10,695,0,0,0;704,234,10,688,0,359,3;704,234,10,695,0,0,0;704,235,10,688,0,359,3;704,235,10,695,0,0,0;704,246,10,688,0,359,3;704,246,10,695,0,0,0;704,247,10,688,0,359,3;704,247,10,695,0,0,0;704,248,10,688,0,359,3;704,248,10,695,0,0,0;704,249,10,688,0,359,3;704,249,10,695,0,0,0;705,51,10,687,0,0,0;705,52,10,687,0,0,0;705,53,10,687,0,0,0;705,54,10,687,0,0,0;705,55,10,687,0,0,0;705,56,10,687,0,0,0;705,77,253,591,0,0,0;705,106,18,664,0,0,0;705,120,243,841,0,0,0;705,121,243,841,0,0,0;705,131,19,664,0,0,0;705,148,18,664,0,0,0;705,151,293,694,0,0,0;705,151,293,703,0,0,0;705,151,293,704,0,0,0;705,167,129,651,0,0,0;705,168,129,651,0,0,0;705,169,129,651,0,0,0;705,170,129,651,0,0,0;705,233,10,688,0,359,3;705,233,10,695,0,0,0;705,234,10,688,0,359,3;705,234,10,695,0,0,0;705,235,10,688,0,359,3;705,235,10,695,0,0,0;705,246,10,688,0,359,3;705,246,10,695,0,0,0;705,247,10,688,0,359,3;705,247,10,695,0,0,0;705,248,10,688,0,359,3;705,248,10,695,0,0,0;705,249,10,688,0,359,3;705,249,10,695,0,0,0;706,21,13,674,0,0,0;706,22,13,674,0,0,0;706,23,45,674,0,0,0;706,24,45,674,0,0,0;707,3,19,669,0,0,0;707,4,17,669,0,0,0;707,5,16,669,0,0,0;707,7,15,669,0,0,0;707,7,30,666,0,0,0;707,8,14,669,0,0,0;707,9,14,669,0,0,0;707,10,13,669,0,0,0;707,11,10,670,0,0,0;707,11,10,709,0,377,2;707,12,10,670,0,0,0;707,12,10,709,0,377,2;707,13,13,669,0,0,0;707,13,35,688,0,0,0;707,14,13,669,0,0,0;707,14,35,688,0,0,0;707,15,13,669,0,0,0;707,16,13,669,0,0,0;707,17,13,669,0,0,0;707,18,14,669,0,0,0;707,19,14,669,0,0,0;707,20,15,669,0,0,0;707,22,16,669,0,0,0;707,23,17,669,0,0,0;707,24,19,669,0,0,0;708,13,5,709,0,0,0;708,14,5,709,0,0,0;708,37,17,672,0,0,0;708,37,17,690,0,377,4;708,37,18,672,0,0,0;708,37,18,690,0,377,4;709,0,27,707,0,0,0;709,0,28,707,0,0,0;709,0,29,707,0,0,0;709,23,5,671,0,0,0;709,23,5,708,0,377,3;709,24,5,671,0,0,0;709,24,5,708,0,377,3;710,22,49,412,0,0,0;710,31,22,836,0,589,2;710,32,22,836,0,589,2;710,39,24,711,0,0,0;710,44,43,715,0,0,0;710,47,36,711,0,0,0;711,18,37,710,0,0,0;711,19,58,710,0,0,0;711,22,20,712,0,0,0;711,22,20,725,0,0,0;711,33,52,713,0,0,0;712,23,14,711,0,0,0;713,16,24,711,0,0,0;713,25,32,716,0,450,5;713,28,19,717,0,0,0;713,35,15,718,0,0,0;713,35,15,726,0,0,0;713,36,15,718,0,0,0;713,36,15,726,0,0,0;713,47,22,719,0,0,0;713,47,22,727,0,0,0;713,48,37,714,0,0,0;713,62,35,721,0,0,0;713,62,35,728,0,0,0;714,15,25,715,0,0,0;714,17,9,713,0,0,0;714,41,29,722,0,0,0;714,41,29,729,0,0,0;715,13,12,710,0,0,0;715,21,16,730,921,0,0;715,21,16,731,0,0,0;715,38,15,734,0,391,45;715,39,15,733,0,391,9;715,39,15,733,0,391,13;715,59,34,742,0,0,0;715,60,34,742,0,0,0;715,61,34,742,0,0,0;715,66,17,714,0,0,0;716,22,11,713,0,0,0;717,13,11,748,0,0,0;717,13,11,748,920,0,0;717,14,11,748,0,0,0;717,14,11,748,920,0,0;717,19,18,713,0,0,0;717,20,9,726,0,0,0;718,22,17,713,0,0,0;718,23,17,713,0,0,0;719,13,16,713,0,0,0;719,19,10,749,0,0,0;719,19,10,750,0,0,0;720,11,8,749,0,0,0;720,11,8,750,0,0,0;721,16,12,713,0,0,0;722,14,9,714,0,0,0;722,18,10,836,0,589,2;722,19,10,836,0,589,2;723,12,16,729,0,0,0;724,12,16,729,0,0,0;725,23,14,711,0,0,0;726,12,12,717,0,0,0;726,22,17,713,0,0,0;726,23,17,713,0,0,0;727,13,16,713,0,0,0;728,16,12,713,0,0,0;729,14,9,714,0,0,0;729,18,10,836,0,589,2;729,19,10,836,0,589,2;729,24,13,723,0,0,0;729,24,13,724,0,0,0;730,3,6,733,957,0,0;730,3,11,715,0,0,0;730,4,11,715,0,0,0;731,3,11,715,0,0,0;731,4,11,715,0,0,0;732,6,18,733,957,0,0;732,6,23,733,957,0,0;732,7,18,733,957,0,0;732,7,23,733,957,0,0;732,8,49,738,0,0,0;732,11,24,737,0,0,0;732,22,27,737,0,0,0;732,24,7,736,0,0,0;732,29,27,737,0,0,0;732,38,8,734,958,0,0;732,38,8,735,958,391,47;732,39,8,734,958,0,0;732,39,8,735,958,391,47;732,43,49,736,0,0,0;732,48,27,737,0,0,0;732,48,49,738,0,0,0;732,53,13,736,0,0,0;732,58,27,737,0,0,0;732,66,17,733,0,0,0;732,66,18,733,0,0,0;732,66,24,737,0,0,0;732,70,23,733,957,0,0;732,70,49,738,0,0,0;732,71,23,733,957,0,0;733,2,1,715,0,0,0;733,3,44,730,0,432,3;733,3,44,732,0,0,0;733,3,44,732,0,432,2;733,24,7,732,0,0,0;733,24,16,715,0,0,0;733,26,44,732,957,0,0;734,17,22,735,0,391,46;734,22,12,754,0,0,0;735,16,19,413,0,391,48;735,16,19,715,0,0,0;735,18,19,414,0,611,1;735,18,19,632,0,611,1;735,18,25,732,0,0,0;736,8,17,732,0,0,0;736,11,52,732,0,0,0;736,12,52,732,0,0,0;736,16,34,732,0,0,0;737,7,12,732,0,0,0;737,19,16,732,0,0,0;737,19,16,732,0,408,1;737,34,24,732,0,0,0;737,46,24,732,0,0,0;737,64,16,732,0,0,0;737,73,12,732,0,0,0;738,9,11,732,0,0,0;738,10,11,732,0,0,0;738,36,11,732,0,0,0;738,37,11,732,0,0,0;738,56,11,732,0,0,0;738,57,11,732,0,0,0;739,11,4,740,0,0,0;739,11,58,763,0,0,0;739,12,4,740,0,0,0;739,12,58,763,0,0,0;740,9,22,739,0,0,0;741,48,11,869,0,618,1;741,49,11,869,0,618,1;742,12,20,836,0,589,2;742,13,10,715,0,0,0;742,13,20,836,0,589,2;742,14,10,715,0,0,0;742,15,10,715,0,0,0;742,18,24,763,0,0,0;742,19,24,763,0,0,0;742,20,24,763,0,0,0;742,21,24,763,0,0,0;742,22,24,763,0,0,0;743,14,35,744,0,0,0;743,14,41,184,0,0,0;744,16,46,743,0,0,0;744,19,8,745,0,0,0;744,19,8,746,0,0,0;745,15,12,747,0,0,0;745,15,22,744,0,0,0;746,15,12,747,0,0,0;746,15,22,744,0,0,0;747,17,20,745,0,0,0;747,17,20,746,0,0,0;748,4,14,717,0,0,0;748,5,14,717,0,0,0;748,24,14,717,0,0,0;748,25,14,717,0,0,0;749,41,48,719,0,0,0;749,43,70,720,0,0,0;750,41,48,719,0,0,0;750,43,70,720,0,0,0;751,8,10,763,0,0,0;752,10,11,763,0,0,0;753,4,39,763,0,0,0;753,6,8,763,0,0,0;753,6,24,763,0,0,0;753,7,24,763,0,0,0;753,27,24,763,0,0,0;753,27,39,763,0,0,0;753,29,9,763,0,0,0;753,56,7,767,0,471,1;754,33,17,758,0,0,0;754,58,80,755,0,0,0;756,102,19,757,0,0,0;757,120,159,758,0,0,0;758,40,176,759,0,0,0;759,43,191,735,0,0,0;760,36,9,210,0,0,0;760,36,10,210,0,0,0;760,36,11,210,0,0,0;761,5,5,228,0,0,0;761,5,5,230,0,0,0;762,7,5,228,0,0,0;762,14,66,228,0,0,0;763,12,53,365,0,0,0;763,12,54,365,0,0,0;763,16,47,753,999,0,0;763,23,71,753,999,0,0;763,27,45,751,0,0,0;763,34,42,753,999,0,0;763,34,86,298,0,0,0;763,35,86,298,0,0,0;763,36,86,298,0,0,0;763,37,86,298,0,0,0;763,38,86,298,0,0,0;763,42,22,739,999,0,0;763,46,69,752,0,0,0;763,51,71,753,999,0,0;763,67,43,753,999,0,0;763,68,58,753,999,0,0;763,74,11,742,0,0,0;763,75,11,742,0,0,0;763,76,11,742,0,0,0;763,77,11,742,0,0,0;763,78,11,742,0,0,0;764,9,28,323,0,0,0;764,9,99,901,0,0,0;764,10,28,323,0,0,0;764,19,15,899,0,0,0;764,20,3,38,0,0,0;765,10,10,628,0,0,0;765,11,53,356,0,0,0;765,12,10,628,0,0,0;765,14,10,628,0,0,0;766,10,13,413,0,0,0;767,9,4,753,0,0,0;768,24,44,769,0,0,0;768,24,44,769,0,475,63;768,24,45,769,0,0,0;768,24,45,769,0,475,63;768,36,42,776,0,0,0;768,37,42,776,0,0,0;768,41,33,414,0,0,0;768,42,33,414,0,0,0;768,66,42,769,0,0,0;768,67,42,769,0,0,0;769,2,14,768,0,0,0;769,2,15,768,0,0,0;769,23,10,776,0,475,62;769,23,19,768,0,0,0;769,24,10,776,0,475,62;769,24,19,768,0,0,0;770,23,10,777,0,475,87;770,23,19,776,0,0,0;770,24,10,777,0,475,87;770,24,19,776,0,0,0;770,45,14,776,0,0,0;771,23,10,778,0,475,93;771,23,19,777,0,0,0;771,24,10,778,0,475,93;771,24,19,777,0,0,0;771,45,14,777,0,0,0;772,10,11,414,0,0,0;773,8,10,414,0,0,0;774,8,38,414,0,0,0;774,8,90,775,0,0,0;774,9,21,414,0,0,0;774,10,94,414,0,0,0;774,27,64,414,0,0,0;774,27,76,414,0,0,0;774,29,8,414,0,0,0;774,34,23,414,0,0,0;774,34,39,414,0,0,0;775,4,4,774,0,0,0;775,86,4,853,0,615,1;775,87,4,853,0,615,1;775,87,6,414,0,611,5;775,94,39,406,0,0,0;775,94,40,406,0,0,0;776,0,45,770,0,0,0;776,0,45,770,0,475,86;776,36,83,777,0,0,0;776,37,83,777,0,0,0;776,52,76,768,0,0,0;776,53,76,768,0,0,0;776,66,83,770,0,0,0;776,67,83,770,0,0,0;776,82,69,769,0,0,0;776,83,69,769,0,0,0;777,1,45,771,0,475,86;777,1,71,771,0,0,0;777,1,71,771,0,475,86;777,41,90,778,0,0,0;777,42,90,778,0,0,0;777,52,76,776,0,0,0;777,53,76,776,0,0,0;777,71,90,771,0,0,0;777,72,90,771,0,0,0;777,82,69,770,0,0,0;777,83,69,770,0,0,0;778,1,14,779,0,0,0;778,1,14,780,1098,0,0;778,1,15,779,0,0,0;778,1,15,780,1098,0,0;778,24,86,781,0,0,0;778,52,76,777,0,0,0;778,53,76,777,0,0,0;778,82,69,771,0,0,0;778,83,69,771,0,0,0;779,40,81,778,0,0,0;779,40,82,778,0,0,0;780,40,81,778,0,0,0;780,40,82,778,0,0,0;781,23,9,783,0,0,0;781,24,9,783,0,0,0;781,33,22,782,0,0,0;782,10,11,781,0,0,0;783,19,7,784,0,0,0;783,19,7,812,0,0,0;783,19,29,781,0,0,0;783,20,7,784,0,0,0;783,20,7,812,0,0,0;783,20,29,781,0,0,0;784,15,69,783,0,0,0;784,16,69,783,0,0,0;784,19,13,785,0,0,0;784,20,13,785,0,0,0;784,25,12,785,0,0,0;784,26,12,785,0,0,0;784,34,72,786,0,0,0;784,34,72,811,0,0,0;784,35,72,786,0,0,0;784,35,72,811,0,0,0;784,52,13,786,0,0,0;784,52,13,811,0,0,0;784,53,13,786,0,0,0;784,53,13,811,0,0,0;784,55,72,786,0,0,0;784,55,72,811,0,0,0;784,56,72,786,0,0,0;784,56,72,811,0,0,0;784,65,28,786,0,0,0;784,65,28,811,0,0,0;784,67,63,786,0,0,0;784,67,63,811,0,0,0;784,94,20,786,0,0,0;784,94,20,811,0,0,0;784,95,61,786,0,0,0;784,95,61,811,0,0,0;784,129,32,787,0,0,0;784,129,32,813,0,0,0;784,129,33,787,0,0,0;784,129,33,813,0,0,0;785,16,51,852,0,0,0;785,17,26,784,0,0,0;785,17,26,812,0,0,0;785,17,51,852,0,0,0;785,18,26,784,0,0,0;785,18,26,812,0,0,0;785,23,26,784,0,0,0;785,23,26,812,0,0,0;785,24,26,784,0,0,0;785,24,26,812,0,0,0;785,54,90,786,0,0,0;785,55,90,786,0,0,0;786,48,78,784,0,0,0;786,48,78,812,0,0,0;786,49,78,784,0,0,0;786,49,78,812,0,0,0;786,53,14,784,0,0,0;786,53,14,812,0,0,0;786,54,14,784,0,0,0;786,54,14,812,0,0,0;786,61,22,788,0,0,0;786,62,22,788,0,0,0;786,77,72,784,0,0,0;786,77,72,812,0,0,0;786,78,72,784,0,0,0;786,78,72,812,0,0,0;787,13,74,784,0,0,0;787,13,74,812,0,0,0;787,13,75,784,0,0,0;787,13,75,812,0,0,0;787,23,33,789,0,0,0;787,24,33,789,0,0,0;787,29,31,789,0,0,0;787,30,31,789,0,0,0;787,39,78,790,0,0,0;787,69,20,813,0,0,0;787,83,21,792,0,0,0;787,84,21,792,0,0,0;787,84,83,790,0,0,0;787,85,9,795,0,0,0;787,85,42,790,0,0,0;787,85,83,790,0,0,0;787,86,9,795,0,0,0;787,86,42,790,0,0,0;787,90,54,794,0,0,0;787,90,55,794,0,0,0;788,20,70,786,0,0,0;788,20,70,811,0,0,0;788,21,70,786,0,0,0;788,21,70,811,0,0,0;788,56,38,784,0,0,0;788,56,38,812,0,0,0;788,58,36,784,0,0,0;788,58,36,812,0,0,0;788,58,40,784,0,0,0;788,58,40,812,0,0,0;788,60,38,784,0,0,0;788,60,38,812,0,0,0;789,18,31,787,0,0,0;789,18,31,813,0,0,0;789,19,31,787,0,0,0;789,19,31,813,0,0,0;789,35,30,787,0,0,0;789,35,30,813,0,0,0;789,36,30,787,0,0,0;789,36,30,813,0,0,0;790,14,65,791,0,0,0;790,15,65,791,0,0,0;790,21,65,787,0,0,0;790,21,65,813,0,0,0;790,22,65,787,0,0,0;790,22,65,813,0,0,0;790,26,9,787,0,0,0;790,26,9,813,0,0,0;790,27,9,787,0,0,0;790,27,9,813,0,0,0;790,58,31,791,0,0,0;790,59,31,791,0,0,0;790,65,69,787,0,0,0;790,65,69,813,0,0,0;790,66,69,787,0,0,0;790,66,69,813,0,0,0;791,13,42,801,0,0,0;791,14,42,801,0,0,0;791,14,58,790,0,0,0;791,15,12,800,0,0,0;791,15,58,790,0,0,0;791,16,12,800,0,0,0;791,32,14,796,0,0,0;791,35,12,809,0,596,3;791,36,11,807,0,597,3;791,36,29,790,0,0,0;791,37,11,808,0,598,3;791,37,29,790,0,0,0;791,38,12,810,0,599,3;791,49,51,802,0,0,0;791,50,51,802,0,0,0;791,53,10,799,0,0,0;791,54,10,799,0,0,0;792,15,55,787,0,0,0;792,15,55,813,0,0,0;792,16,55,787,0,0,0;792,16,55,813,0,0,0;792,32,9,793,0,475,134;792,67,26,793,0,0,0;792,68,26,793,0,0,0;792,124,37,794,0,0,0;792,125,37,794,0,0,0;793,12,40,792,0,0,0;793,13,40,792,0,0,0;793,46,40,792,0,0,0;793,47,40,792,0,0,0;794,12,50,787,0,0,0;794,12,50,813,0,0,0;794,13,50,787,0,0,0;794,13,50,813,0,0,0;794,21,7,795,0,0,0;794,22,7,795,0,0,0;794,98,41,796,0,475,140;794,119,52,792,0,0,0;794,120,52,792,0,0,0;794,132,26,796,0,0,0;794,132,27,796,0,0,0;795,14,50,787,0,0,0;795,14,50,813,0,0,0;795,15,50,787,0,0,0;795,15,50,813,0,0,0;795,50,49,794,0,0,0;795,51,49,794,0,0,0;796,24,11,798,0,0,0;796,25,11,798,0,0,0;796,25,111,794,0,0,0;796,26,11,798,0,0,0;796,26,46,791,0,0,0;796,26,111,794,0,0,0;796,40,96,797,0,0,0;796,40,97,797,0,0,0;797,10,21,796,0,0,0;797,10,22,796,0,0,0;798,13,44,796,0,0,0;798,14,44,796,0,0,0;798,15,44,796,0,0,0;798,43,46,814,0,0,0;798,44,46,814,0,0,0;799,13,39,791,0,0,0;799,14,39,791,0,0,0;799,34,56,802,0,0,0;799,35,56,802,0,0,0;799,40,11,803,0,0,0;799,41,11,803,0,0,0;800,16,10,804,0,0,0;800,17,10,804,0,0,0;800,18,56,801,0,0,0;800,19,56,801,0,0,0;800,40,40,791,0,0,0;800,41,40,791,0,0,0;801,14,56,805,0,0,0;801,15,56,805,0,0,0;801,17,9,800,0,0,0;801,18,9,800,0,0,0;801,39,27,791,0,0,0;801,40,27,791,0,0,0;802,15,24,791,0,0,0;802,16,24,791,0,0,0;802,31,9,799,0,0,0;802,32,9,799,0,0,0;802,39,56,806,0,0,0;802,39,56,806,0,520,-8;802,39,56,806,0,520,9;802,40,56,806,0,0,0;802,40,56,806,0,520,-8;802,40,56,806,0,520,9;803,15,69,799,0,0,0;803,16,69,799,0,0,0;803,61,9,807,0,0,0;803,62,9,807,0,0,0;804,13,10,808,0,0,0;804,14,10,808,0,0,0;804,63,70,800,0,0,0;804,64,70,800,0,0,0;805,37,11,809,0,0,0;805,38,11,809,0,0,0;805,64,59,801,0,0,0;805,65,59,801,0,0,0;806,0,2,802,0,0,0;806,14,11,802,0,0,0;806,15,11,802,0,0,0;806,64,70,810,0,0,0;806,65,70,810,0,0,0;807,12,46,803,0,0,0;807,13,46,803,0,0,0;807,25,39,791,0,597,3;807,27,32,855,0,617,1;807,28,32,855,0,617,1;808,29,21,855,0,617,1;808,29,24,791,0,598,3;808,30,21,855,0,617,1;808,40,46,804,0,0,0;808,41,46,804,0,0,0;809,26,27,791,0,596,3;809,38,28,855,0,617,1;809,39,28,855,0,617,1;809,40,8,805,0,0,0;809,41,8,805,0,0,0;810,12,8,806,0,0,0;810,13,8,806,0,0,0;810,25,20,791,0,599,3;810,33,24,855,0,617,1;810,34,24,855,0,617,1;811,48,78,784,0,0,0;811,48,78,812,0,0,0;811,49,78,784,0,0,0;811,49,78,812,0,0,0;811,53,14,784,0,0,0;811,53,14,812,0,0,0;811,54,14,784,0,0,0;811,54,14,812,0,0,0;811,61,22,788,0,0,0;811,62,22,788,0,0,0;811,77,72,784,0,0,0;811,77,72,812,0,0,0;811,78,72,784,0,0,0;811,78,72,812,0,0,0;812,15,69,783,0,0,0;812,16,69,783,0,0,0;812,19,13,785,0,0,0;812,20,13,785,0,0,0;812,25,12,785,0,0,0;812,26,12,785,0,0,0;812,34,72,786,0,0,0;812,34,72,811,0,0,0;812,35,72,786,0,0,0;812,35,72,811,0,0,0;812,52,13,786,0,0,0;812,52,13,811,0,0,0;812,53,13,786,0,0,0;812,53,13,811,0,0,0;812,55,72,786,0,0,0;812,55,72,811,0,0,0;812,56,72,786,0,0,0;812,56,72,811,0,0,0;812,65,28,786,0,0,0;812,65,28,811,0,0,0;812,67,63,786,0,0,0;812,67,63,811,0,0,0;812,94,20,786,0,0,0;812,94,20,811,0,0,0;812,95,61,786,0,0,0;812,95,61,811,0,0,0;812,129,32,787,0,0,0;812,129,32,813,0,0,0;812,129,33,787,0,0,0;812,129,33,813,0,0,0;813,13,74,784,0,0,0;813,13,74,812,0,0,0;813,13,75,784,0,0,0;813,13,75,812,0,0,0;813,23,33,789,0,0,0;813,24,33,789,0,0,0;813,29,31,789,0,0,0;813,30,31,789,0,0,0;813,39,78,790,0,0,0;813,83,21,792,0,0,0;813,84,21,792,0,0,0;813,84,83,790,0,0,0;813,85,9,795,0,0,0;813,85,42,790,0,0,0;813,85,83,790,0,0,0;813,86,9,795,0,0,0;813,86,42,790,0,0,0;813,90,54,794,0,0,0;813,90,55,794,0,0,0;814,19,10,798,0,0,0;814,20,10,798,0,0,0;814,42,30,816,0,0,0;814,48,33,848,0,618,2;814,49,33,848,0,618,2;814,53,32,815,0,0,0;814,53,32,815,0,611,8;814,55,33,844,0,618,4;815,9,4,817,0,0,0;815,9,399,814,0,0,0;815,10,4,817,0,0,0;815,10,399,814,0,0,0;816,10,11,814,0,0,0;817,13,31,820,0,618,12;817,15,9,818,0,0,0;817,15,38,899,0,0,0;817,16,9,818,0,0,0;817,16,35,814,0,552,1;818,18,6,819,0,0,0;819,16,5,820,0,0,0;819,16,5,843,0,611,10;819,17,5,820,0,0,0;819,17,5,843,0,611,10;820,24,10,821,0,0,0;820,24,79,821,0,618,16;821,11,5,461,0,0,0;821,11,5,519,0,0,0;821,11,34,845,0,618,18;821,12,34,845,0,618,18;821,12,44,180,0,552,9;822,7,8,307,0,0,0;822,7,8,899,0,0,0;822,7,19,308,0,0,0;822,7,20,308,0,0,0;822,8,8,307,0,0,0;822,8,8,899,0,0,0;822,8,19,308,0,0,0;822,8,20,308,0,0,0;823,7,33,306,0,0,0;823,7,33,899,0,0,0;823,7,49,309,0,0,0;823,7,49,899,0,0,0;823,8,33,306,0,0,0;823,8,33,899,0,0,0;823,8,49,309,0,0,0;823,8,49,899,0,0,0;824,14,4,306,0,0,0;824,14,4,530,0,0,0;825,7,103,866,0,619,20;825,29,114,636,0,0,0;825,30,114,636,0,0,0;825,74,110,831,0,619,20;826,9,12,79,0,0,0;826,9,12,527,0,0,0;826,10,4,827,1305,0,0;826,10,12,79,0,0,0;826,10,12,527,0,0,0;826,11,12,79,0,0,0;826,11,12,527,0,0,0;827,8,6,829,0,0,0;827,8,6,829,17,0,0;827,9,6,580,0,0,0;827,9,6,580,17,0,0;827,10,6,842,0,0,0;827,10,6,842,17,0,0;827,13,12,828,0,0,0;827,19,12,828,0,0,0;827,21,14,828,0,0,0;827,24,30,899,0,0,0;827,24,32,826,0,0,0;827,25,1,893,0,697,17;827,25,32,826,0,0,0;827,33,12,899,1965,0,0;827,50,14,333,0,697,1;828,14,9,827,0,0,0;828,14,9,827,0,558,36;828,14,9,827,1371,0,0;829,3,13,827,0,0,0;830,10,13,544,0,0,0;831,5,14,832,0,562,7;831,6,14,832,0,562,7;831,17,61,293,0,0,0;831,18,7,832,0,562,10;831,18,49,826,0,562,13;831,18,61,293,0,0,0;831,19,7,832,0,562,10;831,24,16,825,0,619,20;831,32,35,836,0,619,20;831,34,9,832,0,0,0;831,34,30,832,0,562,8;831,35,9,832,0,0,0;831,35,30,832,0,562,8;831,56,14,832,0,0,0;831,57,14,832,0,0,0;831,57,39,832,0,0,0;831,58,39,832,0,0,0;831,58,77,832,0,0,0;831,59,77,832,0,0,0;832,5,10,899,0,0,0;832,5,13,831,0,0,0;832,5,17,831,0,0,0;832,6,17,831,0,0,0;832,13,32,899,0,0,0;832,13,41,831,0,0,0;832,14,41,831,0,0,0;832,15,4,831,0,0,0;832,33,5,831,0,562,12;832,33,29,831,0,0,0;832,34,5,831,0,562,12;832,34,29,831,0,0,0;832,41,8,831,0,0,0;833,7,127,290,0,0,0;833,8,127,290,0,0,0;834,19,86,282,0,0,0;834,20,86,282,0,0,0;834,93,85,289,0,0,0;834,94,85,289,0,0,0;835,60,73,405,0,0,0;835,61,73,405,0,0,0;835,62,15,839,0,586,11;835,100,46,866,0,619,20;836,10,40,742,0,589,2;836,11,40,742,0,589,2;836,22,84,837,0,0,0;836,42,52,837,0,0,0;836,43,89,837,0,0,0;836,58,52,837,0,0,0;836,58,96,710,0,0,0;836,59,96,710,0,0,0;836,61,84,837,0,0,0;836,62,58,837,0,0,0;836,62,67,831,0,619,20;836,64,80,866,0,619,20;836,65,47,837,0,0,0;836,68,94,837,0,0,0;836,74,51,837,0,0,0;836,82,69,837,0,0,0;836,83,76,837,0,0,0;836,87,57,837,0,0,0;836,100,62,837,0,0,0;836,101,48,837,0,0,0;836,117,93,837,0,0,0;836,149,71,837,0,0,0;836,167,85,837,0,0,0;836,176,52,722,0,0,0;836,176,52,729,918,0,0;836,177,52,722,0,0,0;836,177,52,729,918,0,0;836,177,58,837,0,0,0;837,10,85,836,0,0,0;837,23,83,836,0,0,0;837,25,56,836,0,0,0;837,31,66,836,0,0,0;837,31,95,836,0,0,0;837,35,90,836,0,0,0;837,37,70,836,0,0,0;837,38,52,836,0,0,0;837,39,59,836,0,0,0;837,45,68,836,0,0,0;837,46,76,836,0,0,0;837,49,86,836,0,0,0;837,57,56,836,0,0,0;837,59,70,836,0,0,0;837,65,69,836,0,0,0;837,69,94,836,0,0,0;837,77,79,836,0,0,0;837,86,87,836,0,0,0;837,95,70,836,0,0,0;838,22,26,234,0,0,0;838,23,26,234,0,0,0;838,52,72,840,0,0,0;838,53,72,840,0,0,0;838,91,27,840,0,0,0;838,92,27,840,0,0,0;839,0,1,527,0,586,15;839,11,10,866,0,619,20;839,11,50,835,0,0,0;839,12,14,826,0,586,13;840,14,67,847,0,616,13;840,15,67,847,0,616,13;840,51,9,838,0,588,1;840,52,9,838,0,588,1;840,103,33,838,0,588,1;840,104,33,838,0,588,1;840,131,111,875,0,0,0;840,135,65,826,0,636,17;840,150,37,899,0,0,0;840,170,32,826,0,616,18;841,47,18,846,0,0,0;841,68,109,694,0,0,0;841,68,109,703,0,360,2;841,68,109,704,0,360,3;841,68,109,705,0,360,4;841,69,109,694,0,0,0;841,69,109,703,0,360,2;841,69,109,704,0,360,3;841,69,109,705,0,360,4;841,75,20,846,0,0,0;841,117,26,846,0,0,0;841,155,20,846,0,0,0;843,17,5,821,0,0,0;844,14,35,817,0,618,9;844,14,35,817,913,618,9;845,17,23,763,0,618,28;846,8,9,841,0,0,0;846,16,29,841,0,0,0;846,17,48,841,0,0,0;846,51,49,841,0,0,0;847,25,12,252,0,0,0;847,26,12,252,0,0,0;847,133,116,840,0,0,0;847,134,116,840,0,0,0;848,53,8,814,0,618,3;848,54,8,814,0,618,3;849,11,58,850,0,0,0;849,17,10,850,0,0,0;849,19,33,850,0,0,0;849,24,13,850,0,0,0;849,24,14,850,0,0,0;849,30,19,826,0,613,11;849,41,57,850,0,0,0;849,53,20,850,0,0,0;849,57,55,850,0,0,0;849,59,36,852,0,0,0;849,60,36,852,0,0,0;850,15,77,849,0,0,0;850,18,9,849,0,0,0;850,39,111,860,0,0,0;850,42,17,883,0,0,0;850,53,51,826,0,649,12;850,62,108,849,0,0,0;850,72,19,849,0,0,0;850,75,69,849,0,0,0;852,4,96,849,0,0,0;852,5,96,849,0,0,0;852,53,8,785,0,0,0;852,54,8,785,0,0,0;853,15,52,775,0,0,0;853,16,52,775,0,0,0;853,24,18,854,0,0,0;853,24,18,854,0,615,41;853,24,18,854,0,615,49;853,24,18,854,0,615,55;853,46,42,854,0,0,0;854,11,28,853,0,0,0;854,20,111,853,0,0,0;854,21,111,853,0,0,0;854,74,97,853,0,0,0;855,29,45,807,0,0,0;855,29,45,808,0,621,4;855,29,45,809,0,621,3;855,29,45,810,0,621,2;855,29,289,808,0,0,0;855,30,45,807,0,0,0;855,30,45,808,0,621,4;855,30,45,809,0,621,3;855,30,45,810,0,621,2;855,30,106,807,0,0,0;855,30,289,808,0,0,0;855,31,106,807,0,0,0;855,31,167,810,0,0,0;855,31,228,809,0,0,0;855,32,167,810,0,0,0;855,32,228,809,0,0,0;856,55,214,403,0,0,0;856,56,214,403,0,0,0;857,13,43,859,0,0,0;857,20,20,859,0,0,0;857,23,40,859,0,0,0;857,23,75,859,0,0,0;857,24,13,859,0,0,0;857,24,40,859,0,0,0;857,25,40,859,0,0,0;857,26,71,859,0,0,0;857,30,32,859,0,0,0;857,30,45,859,0,0,0;857,32,43,859,0,0,0;857,34,65,859,0,0,0;857,41,75,859,0,0,0;857,44,42,859,0,0,0;857,45,42,859,0,0,0;857,46,54,859,0,0,0;857,48,75,859,0,0,0;857,59,35,859,0,0,0;857,59,37,288,0,622,15;857,59,37,376,0,622,15;857,65,53,859,0,0,0;857,66,53,859,0,0,0;857,66,79,859,0,0,0;857,69,59,859,0,0,0;857,70,63,859,0,0,0;858,11,7,866,0,619,15;859,6,66,857,0,0,0;859,7,44,857,0,0,0;859,7,66,857,0,0,0;859,7,98,857,0,0,0;859,8,44,857,0,0,0;859,8,98,857,0,0,0;859,17,26,857,0,0,0;859,18,26,857,0,0,0;859,20,8,857,0,0,0;859,21,8,857,0,0,0;859,25,40,857,0,0,0;859,26,40,857,0,0,0;859,29,99,857,0,0,0;859,30,67,857,0,0,0;859,30,82,857,0,0,0;859,30,99,857,0,0,0;859,31,67,857,0,0,0;859,31,82,857,0,0,0;859,37,14,857,0,0,0;859,38,14,857,0,0,0;859,41,11,857,0,0,0;859,41,40,857,0,0,0;859,42,40,857,0,0,0;859,55,13,857,0,0,0;859,56,13,857,0,0,0;859,57,66,857,0,0,0;859,58,66,857,0,0,0;859,60,25,857,0,0,0;859,61,25,857,0,0,0;859,62,45,857,0,0,0;859,63,30,857,0,0,0;859,63,45,857,0,0,0;859,64,30,857,0,0,0;859,78,32,857,0,0,0;859,79,8,857,0,0,0;859,79,32,857,0,0,0;860,15,116,826,0,626,31;860,24,25,850,0,0,0;860,123,12,865,0,576,1;860,124,12,865,0,0,0;861,37,22,674,0,0,0;861,38,22,674,0,0,0;861,41,92,676,0,0,0;862,78,61,863,0,0,0;862,79,61,863,0,0,0;863,37,21,862,0,632,1;863,38,21,862,0,632,1;865,14,26,860,0,0,0;865,15,26,860,0,0,0;866,4,4,835,0,619,15;866,32,8,825,0,0,0;866,42,40,591,0,0,0;866,55,42,839,0,0,0;866,82,42,858,0,0,0;866,87,2,836,0,619,15;867,28,30,355,0,0,0;867,29,30,355,0,0,0;867,42,23,899,0,0,0;867,48,17,868,0,627,4;867,48,17,868,0,627,6;867,48,17,868,0,627,8;867,48,17,868,0,627,10;867,48,17,868,0,627,12;867,48,17,868,0,627,15;868,13,9,867,0,627,15;868,13,10,867,0,0,0;868,13,10,867,0,627,6;868,13,10,867,0,627,8;868,13,10,867,0,627,10;868,13,10,867,0,627,12;869,101,22,741,0,618,1;869,102,22,741,0,618,1;870,36,90,388,0,0,0;870,37,7,872,0,0,0;870,37,7,872,0,631,6;870,38,7,872,0,0,0;870,38,7,872,0,631,6;870,126,90,388,0,0,0;870,127,7,872,0,0,0;870,127,7,872,0,631,6;870,128,7,872,0,0,0;870,128,7,872,0,631,6;871,12,119,330,0,628,9;871,13,119,330,0,628,9;871,14,119,330,0,628,9;871,15,119,330,0,628,9;871,27,51,332,0,628,1;871,28,51,332,0,628,1;871,32,54,330,0,628,9;871,32,55,330,0,628,9;871,32,56,330,0,628,9;871,142,71,330,0,0,0;871,142,72,330,0,0,0;871,142,73,330,0,0,0;871,146,104,330,0,0,0;871,147,104,330,0,0,0;871,148,104,330,0,0,0;871,149,104,330,0,0,0;871,152,21,332,0,628,1;871,153,21,332,0,628,1;871,155,75,332,0,0,0;871,155,75,701,0,0,0;871,156,70,332,0,0,0;871,156,70,701,0,0,0;871,156,75,332,0,0,0;871,156,75,701,0,0,0;871,157,24,330,0,0,0;871,157,24,330,0,628,9;871,157,25,330,0,0,0;871,157,25,330,0,628,9;871,157,26,330,0,0,0;871,157,26,330,0,628,9;872,25,8,873,0,0,0;872,27,57,870,0,0,0;872,27,57,870,0,631,5;872,27,57,870,1693,0,0;872,85,8,873,0,0,0;872,87,57,870,0,0,0;872,87,57,870,0,631,5;872,87,57,870,1693,0,0;873,18,33,527,0,631,10;873,25,50,872,0,0,0;873,25,50,872,0,631,6;873,25,50,872,1693,0,0;874,7,64,899,0,0,0;874,21,9,875,0,636,9;874,22,9,875,0,636,9;874,40,85,280,0,0,0;874,41,85,280,0,0,0;875,23,15,874,0,636,9;875,24,15,874,0,636,9;875,69,45,840,0,0,0;876,36,57,646,0,0,0;876,37,57,646,0,0,0;876,41,60,899,0,0,0;877,30,102,596,0,0,0;877,31,102,596,0,0,0;877,40,137,527,0,637,31;878,68,140,522,0,0,0;878,69,140,522,0,0,0;878,82,79,879,0,641,16;879,68,140,522,0,0,0;879,69,140,522,0,0,0;880,17,141,707,0,648,6;880,20,43,677,0,0,0;880,21,43,677,0,0,0;881,13,22,669,0,0,0;881,14,22,669,0,0,0;881,66,52,669,0,0,0;881,67,52,669,0,0,0;882,13,22,669,0,0,0;882,14,22,669,0,0,0;882,66,52,669,0,0,0;882,67,52,669,0,0,0;882,68,146,668,0,647,8;882,68,146,707,0,647,8;883,32,87,661,0,0,0;883,33,87,661,0,0,0;883,35,37,850,0,0,0;883,36,37,850,0,0,0;884,28,86,383,0,0,0;884,29,86,383,0,0,0;885,21,18,132,0,0,0;885,22,18,132,0,0,0;885,22,39,132,0,0,0;885,23,18,132,0,0,0;886,18,15,889,2199,0,0;886,18,15,889,2226,0,0;886,18,15,889,2227,0,0;886,23,104,889,0,663,3;886,23,133,889,0,0,0;886,23,291,889,0,0,0;886,24,13,889,0,739,1;886,24,28,150,0,0,0;886,24,54,889,0,0,0;886,24,104,889,0,663,3;886,24,110,889,0,0,0;886,24,190,889,0,0,0;886,25,28,150,0,0,0;886,25,211,889,0,0,0;886,25,331,889,0,660,18;886,26,272,889,0,0,0;886,27,350,889,0,0,0;887,36,113,31,0,0,0;887,37,109,888,0,664,5;887,37,113,31,0,0,0;887,81,52,888,0,0,0;888,10,21,887,0,0,0;888,10,65,887,0,0,0;888,35,65,887,0,0,0;888,35,66,887,0,0,0;888,37,18,826,0,664,20;888,37,20,826,0,664,12;888,38,62,887,0,664,5;889,30,46,899,0,0,0;889,43,45,150,0,660,30;889,45,43,886,0,0,0;889,45,43,886,1803,0,0;889,45,43,886,1803,739,1;889,45,46,527,1880,0,0;889,49,44,897,2010,0,0;889,49,44,898,2010,0,0;889,49,48,150,0,660,21;889,50,44,897,0,0,0;889,50,44,898,2010,0,0;890,2,0,892,0,681,10;890,28,128,222,0,0,0;890,28,129,222,0,0,0;890,31,82,222,0,0,0;890,38,128,222,0,0,0;890,38,129,222,0,0,0;890,46,76,222,0,0,0;890,46,77,222,0,0,0;890,48,87,222,0,0,0;890,48,88,222,0,0,0;890,49,39,222,0,0,0;890,49,40,222,0,0,0;890,52,161,222,0,0,0;890,53,52,222,0,0,0;890,53,53,222,0,0,0;890,55,31,222,0,0,0;890,55,32,222,0,0,0;890,56,77,222,0,0,0;890,56,78,222,0,0,0;890,62,33,222,0,0,0;890,62,34,222,0,0,0;890,66,38,222,0,0,0;890,66,39,222,0,0,0;890,66,96,222,0,0,0;890,66,97,222,0,0,0;891,2,0,892,0,681,10;891,26,77,222,0,0,0;891,26,78,222,0,0,0;891,28,46,222,0,0,0;891,28,47,222,0,0,0;891,37,76,222,0,0,0;891,37,77,222,0,0,0;891,37,92,222,0,0,0;891,37,93,222,0,0,0;891,42,43,222,0,0,0;891,42,44,222,0,0,0;891,43,76,222,0,0,0;891,43,77,222,0,0,0;891,44,33,222,0,0,0;891,44,34,222,0,0,0;891,45,56,222,0,0,0;891,45,57,222,0,0,0;891,51,31,222,0,0,0;891,51,32,222,0,0,0;891,52,161,222,0,0,0;891,53,87,222,0,0,0;891,53,88,222,0,0,0;891,54,95,222,0,0,0;891,54,96,222,0,0,0;891,61,56,222,0,0,0;891,61,57,222,0,0,0;891,64,43,222,0,0,0;891,64,44,222,0,0,0;891,72,68,222,0,0,0;891,72,69,222,0,0,0;891,75,89,222,0,0,0;891,75,90,222,0,0,0;891,76,77,222,0,0,0;891,76,78,222,0,0,0;891,81,86,222,0,0,0;891,81,87,222,0,0,0;891,82,70,222,0,0,0;891,82,71,222,0,0,0;892,23,22,222,0,0,0;892,23,94,222,0,651,14;892,23,94,890,0,0,0;893,14,11,894,0,0,0;893,20,80,339,0,0,0;893,21,80,339,0,0,0;893,59,81,339,0,697,27;893,59,82,339,0,697,27;894,79,81,339,0,697,12;895,20,93,511,0,0,0;895,54,23,527,0,739,3;895,56,15,899,0,0,0;896,22,82,185,0,0,0;896,23,82,185,0,0,0;897,44,118,889,0,0,0;897,44,118,889,0,739,19;897,45,118,889,0,0,0;897,45,118,889,0,739,19;898,44,118,889,0,0,0;898,44,118,889,0,739,18;898,45,118,889,0,0,0;898,45,118,889,0,739,18;899,0,39,826,0,769,1000;899,1,1,39,0,0,0;899,1,3,840,0,0,0;899,1,5,590,0,0,0;899,1,7,517,0,0,0;899,3,1,693,0,0,0;899,3,3,764,0,0,0;899,3,5,832,0,0,0;899,3,7,588,0,0,0;899,4,9,598,0,0,0;899,5,1,532,0,0,0;899,5,3,232,0,0,0;899,5,5,293,0,0,0;899,5,7,600,0,0,0;899,6,9,832,0,0,0;899,7,1,874,0,0,0;899,7,3,867,0,0,0;899,7,5,889,0,0,0;899,7,7,548,0,0,0;899,8,9,527,0,0,0;899,9,1,164,0,0,0;899,9,3,827,0,0,0;899,9,5,450,0,0,0;899,9,7,563,0,0,0;899,10,9,632,0,0,0;899,11,1,594,0,0,0;899,11,3,163,0,0,0;899,11,5,414,0,0,0;899,11,7,895,0,0,0;899,13,1,127,0,0,0;899,13,3,78,0,0,0;899,13,5,239,0,0,0;899,13,7,522,0,0,0;899,15,1,193,0,0,0;899,15,3,233,0,0,0;899,15,5,817,0,0,0;899,15,7,876,0,0,0;899,18,10,900,0,0,0;899,19,7,39,0,769,1;899,19,7,78,0,769,1;899,19,7,127,0,769,1;899,19,7,163,0,769,1;899,19,7,164,0,769,1;899,19,7,193,0,769,1;899,19,7,232,0,769,1;899,19,7,233,0,769,1;899,19,7,239,0,769,1;899,19,7,293,0,769,1;899,19,7,414,0,769,1;899,19,7,450,0,769,1;899,19,7,517,0,769,1;899,19,7,522,0,769,1;899,19,7,527,0,769,1;899,19,7,532,0,769,1;899,19,7,548,0,769,1;899,19,7,563,0,769,1;899,19,7,588,0,769,1;899,19,7,590,0,769,1;899,19,7,594,0,769,1;899,19,7,598,0,769,1;899,19,7,600,0,769,1;899,19,7,632,0,769,1;899,19,7,693,0,769,1;899,19,7,764,0,769,1;899,19,7,817,0,769,1;899,19,7,826,0,769,100;899,19,7,827,0,769,1;899,19,7,832,0,769,1;899,19,7,840,0,769,1;899,19,7,867,0,769,1;899,19,7,874,0,769,1;899,19,7,876,0,769,1;899,19,7,889,0,769,1;899,19,7,895,0,769,1;900,30,22,899,0,766,1;901,5,48,764,0,0,0;902,9,30,306,0,0,0;902,10,30,306,0,0,0"

# every story-advancing event in the game: var,to,map,event,x,y,trigger,condvar,condval,switch,speaker
RH_STORY_DATA = "107,8,8,3,9,7,0,0,0,0,AMARIA;107,8,8,6,8,7,1,0,0,0,AMARIA;107,12,11,15,9,8,0,110,1,0,GRUNT;107,13,11,15,9,8,0,110,3,0,GRUNT;107,11,11,15,9,8,0,110,7,0,GRUNT;107,10,11,17,7,9,1,0,0,0,GRUNT;107,10,11,17,7,9,1,0,0,168,GRUNT;107,10,11,18,10,9,1,0,0,0,GRUNT;107,10,11,18,10,9,1,0,0,168,GRUNT;107,13,11,27,12,5,1,0,0,0,;107,17,13,14,7,10,0,107,16,0,AMARIA;107,16,13,15,9,14,3,0,0,0,GRUNT;118,5,15,2,27,15,3,118,4,0,CAIN;107,19,16,14,24,12,0,0,0,0,KIKI;107,20,16,14,24,12,3,107,19,0,KIKI;107,25,17,24,11,20,0,107,21,0,VICTORIA;107,27,17,39,11,15,0,107,26,0,KIKI;118,6,21,13,19,15,0,118,4,0,CAIN;118,5,22,1,8,26,1,0,0,0,;107,18,25,16,10,3,0,0,0,0,;107,28,26,6,7,9,3,107,27,0,KIKI;118,11,26,7,8,9,3,118,10,0,VICTORIA;107,25,26,10,9,10,0,107,20,0,KIKI;107,21,26,10,9,10,0,107,20,0,KIKI;107,26,26,10,9,10,3,107,25,0,KIKI;107,25,27,1,18,7,0,0,0,0,CAL;118,9,27,4,31,27,1,118,7,0,VICTORIA;118,10,27,15,26,23,1,118,9,0,VICTORIA;118,8,27,29,14,31,3,118,7,0,VICTORIA;56,2,29,7,53,36,0,56,1,0,VICTORIA;118,7,33,16,27,50,3,118,6,0,GRUNT;118,7,34,16,27,50,3,118,6,0,GRUNT;56,3,36,55,59,37,0,0,0,0,FLORINIA;56,19,36,69,51,28,3,56,18,0,AMARIA;56,1,37,100,64,34,0,0,0,62,VICTORIA;339,1,38,54,15,9,0,0,0,0,AME;339,5,38,54,15,9,0,339,4,0,AME;107,9,57,144,16,51,0,107,8,0,AMARIA;107,7,66,21,12,35,0,107,6,0,AMARIA;92,3,79,64,31,26,0,92,2,0,CAIN;92,12,79,71,25,29,0,92,11,0,VICTORIA;150,25,79,104,26,11,3,150,24,0,ADRIENN;77,18,80,20,35,9,1,0,0,0,SHELLY;92,2,80,20,35,9,1,0,0,0,SHELLY;92,16,80,34,30,53,1,92,15,0,;104,9,80,34,30,53,1,104,3,0,CAIN;92,1,80,35,30,54,0,0,0,0,;104,24,80,39,28,56,3,104,23,0,ANNA;92,13,80,67,41,12,1,92,12,0,CAL;104,3,80,86,38,11,0,104,2,0,CAIN;104,2,80,88,39,16,3,104,1,0,VICTORIA;118,12,81,38,66,30,0,118,11,0,CAIN;339,11,84,11,31,5,3,339,10,0,ARC;339,12,84,35,11,8,0,339,10,0,;56,4,85,4,9,9,0,56,3,0,VICTORIA;56,4,87,11,11,12,1,0,0,0,;56,9,93,1,7,6,1,0,0,0,;56,10,94,1,9,6,3,0,0,0,SCRAGGY;56,11,94,1,9,6,3,0,0,0,SCRAGGY;56,12,94,1,9,6,3,0,0,0,SCRAGGY;56,9,95,18,16,34,1,0,0,0,;56,7,95,28,16,65,3,0,0,0,;56,8,95,29,15,49,1,0,0,0,;56,10,95,31,16,10,3,56,9,0,SCRAGGY;56,11,95,31,16,10,3,56,9,0,SCRAGGY;56,12,95,31,16,10,3,56,9,0,SCRAGGY;56,8,95,31,16,10,3,56,9,0,SCRAGGY;56,13,97,10,17,11,0,0,0,0,AMARIA;150,26,97,50,42,19,0,150,25,0,ADRIENN;56,16,107,50,13,56,1,0,0,0,AMARIA;56,17,107,54,28,51,1,0,0,0,FLORINIA;56,18,107,75,50,12,1,0,0,0,;56,19,107,84,61,3,3,56,18,0,AMARIA;56,17,107,87,58,5,1,0,0,0,;56,18,107,87,58,5,1,0,0,0,;56,20,119,1,9,10,3,0,0,0,FERN;56,21,119,1,9,10,3,0,0,0,FERN;56,22,125,3,5,9,0,0,0,0,FERN;77,1,127,2,9,4,0,0,0,0,FLORINIA;107,5,130,24,52,39,3,107,4,0,CAIN;107,4,130,44,55,38,1,0,0,0,;107,4,130,48,54,38,1,0,0,0,;107,4,130,70,53,38,1,0,0,0,;107,4,130,71,52,38,1,0,0,0,;107,4,130,73,51,38,1,0,0,0,;107,4,130,109,50,38,1,0,0,0,;107,4,130,140,49,38,1,0,0,0,;107,5,133,15,10,5,3,107,3,0,AMARIA;107,6,133,15,10,5,3,107,5,0,CAIN;107,8,133,15,10,5,3,107,7,0,ACE;77,17,144,8,26,10,1,77,16,0,COREY;77,18,144,8,26,10,1,77,16,0,COREY;92,3,147,3,38,14,0,0,0,0,SHELLY;77,11,149,4,21,7,4,77,10,0,;77,15,149,20,32,19,1,0,0,0,BOREALIS;77,15,149,20,32,19,1,0,0,0,STREET RAT;77,9,149,82,8,33,1,0,0,0,;77,4,150,49,138,85,1,0,0,0,;77,7,150,56,21,19,3,77,5,0,FERN;77,6,150,56,21,19,3,77,5,0,FERN;77,7,150,57,25,19,3,77,6,0,CHATOT;77,4,150,59,137,85,1,0,0,0,;77,4,150,61,137,84,1,0,0,0,;77,4,150,62,138,84,1,0,0,0,;77,5,150,66,105,100,3,77,4,0,METEOR;77,4,150,69,115,102,1,0,0,0,METEOR;77,4,150,70,113,101,1,0,0,0,METEOR;77,4,150,71,113,98,1,0,0,0,METEOR;77,4,150,72,114,97,1,0,0,0,METEOR;77,4,150,73,112,96,1,0,0,0,METEOR;77,4,150,74,114,103,1,0,0,0,METEOR;77,4,150,75,112,100,1,0,0,0,METEOR;77,4,150,76,114,102,1,0,0,0,METEOR;77,8,150,249,41,13,3,0,0,0,CAIN;77,9,150,250,35,40,0,77,8,0,CAIN;77,9,150,263,130,52,0,0,0,0,FERN;77,10,150,268,138,48,1,0,0,0,;107,7,150,320,130,23,3,107,6,0,LIN;77,10,150,328,137,48,1,0,0,0,;77,5,153,39,1,0,3,77,3,0,NUZLEAF;159,5,165,14,8,12,0,95,13,423,MAXWELL;159,5,165,14,8,12,0,159,5,0,MAXWELL;159,6,168,3,30,9,0,159,5,128,;159,6,168,4,3,8,0,159,5,127,;159,5,170,5,9,8,0,95,13,127,ARCHER;92,16,175,4,3,7,3,92,14,0,CAIN;92,18,176,2,11,7,3,92,17,0,CAL;92,14,176,9,8,9,3,0,0,0,CAIN;104,1,176,10,10,9,1,0,0,0,CAL;92,6,180,7,34,22,1,0,0,0,;92,7,180,7,34,22,1,0,0,0,;92,8,180,7,34,22,1,0,0,0,;92,9,180,7,34,22,1,0,0,0,;92,5,180,7,34,22,1,0,0,0,;92,10,180,7,34,22,1,0,0,0,;92,11,180,12,12,26,0,0,0,0,;92,11,180,13,12,27,0,0,0,0,;92,10,180,14,10,26,3,92,11,0,ASTER;92,17,181,1,10,10,3,0,0,0,ANNA;104,10,181,10,10,8,3,104,9,0,ANNA;104,13,181,19,11,6,0,104,12,0,SHELLY;104,17,181,27,19,2,3,104,16,0,SHELLY;104,23,181,28,11,4,3,104,22,0,ANNA;92,19,182,101,28,2,0,0,0,0,SHELLY;104,18,192,20,1,6,0,0,0,0,;104,19,192,20,1,6,3,104,18,0,CHARLOTTE;104,20,192,27,9,14,1,0,0,0,CHARLOTTE;104,21,192,27,9,14,1,0,0,0,CHARLOTTE;104,20,192,28,10,14,1,0,0,0,CHARLOTTE;104,21,192,28,10,14,1,0,0,0,CHARLOTTE;104,12,193,8,14,12,1,0,0,0,ORDERLY;104,11,193,8,14,12,1,0,0,0,ORDERLY;104,17,194,12,9,19,0,0,0,0,NOEL;104,15,194,14,11,8,3,104,14,0,ORDERLY;104,13,194,14,11,8,3,104,14,0,ORDERLY;104,16,194,20,11,6,0,0,0,0,;104,14,194,30,12,8,1,0,0,0,;104,14,194,34,12,7,1,0,0,0,;104,14,194,35,12,9,1,0,0,0,;104,22,195,5,11,4,3,0,0,0,SHELLY;104,28,196,18,25,6,0,104,24,0,CHARLOTTE;107,1,196,26,27,6,3,0,0,0,ANNA;107,2,196,26,27,6,3,0,0,0,ANNA;107,3,197,30,9,5,3,107,2,139,SHADE;118,1,206,81,39,50,1,0,0,0,ASTER;118,3,208,3,9,7,3,118,2,0,TAKA;118,4,208,3,9,7,3,118,2,0,TAKA;118,1,208,3,9,7,3,118,2,0,TAKA;118,2,208,10,8,11,1,0,0,0,;118,2,208,15,9,11,1,0,0,0,;118,13,209,87,67,43,0,0,0,0,ACE;118,17,209,92,11,28,0,118,16,0,CAIN;118,18,210,4,4,11,1,0,0,0,;118,14,223,3,11,17,3,0,0,0,LANA;118,15,224,2,19,13,3,0,0,0,AYA;118,16,224,2,19,13,0,118,15,0,AYA;123,1,225,1,6,8,1,0,0,0,;123,2,225,2,3,12,3,123,1,0,CAIN;123,1,225,3,6,9,1,0,0,0,;123,9,225,20,13,9,3,123,8,0,CAIN;123,3,227,43,17,47,0,0,0,0,;123,7,227,54,8,6,3,0,0,0,SIGMUND;123,8,227,56,37,6,3,0,0,0,SIRIUS;123,4,227,62,10,33,1,0,0,0,CAIN;123,5,227,63,40,56,1,123,4,0,GRUNT;123,6,227,93,33,33,1,0,0,0,CHARLOTTE;339,6,229,150,6,9,0,339,5,0,ARC;339,6,229,152,6,10,1,339,5,0,ARC;339,7,229,153,1,6,1,0,0,0,;339,7,229,154,1,7,1,0,0,0,;339,7,229,170,1,8,1,0,0,0,;123,10,230,3,8,28,3,0,0,0,SHELLY;149,6,231,62,63,42,0,149,5,0,SAPHIRA;149,6,231,62,63,42,0,149,5,0,LAURA;149,21,232,1,18,68,1,0,0,0,;149,2,232,12,20,15,0,149,1,0,NOEL;149,19,232,12,20,15,0,149,18,0,NOEL;149,4,233,7,9,11,3,149,3,0,SIGMUND;149,1,233,19,4,29,0,0,0,0,LAURA;149,3,233,25,6,4,3,149,2,0,NOEL;149,5,233,44,33,22,0,149,4,0,SAPHIRA;149,5,233,45,5,20,0,149,4,0,SAPHIRA;149,5,233,53,9,8,0,149,4,0,SAPHIRA;149,5,233,56,3,3,1,149,4,0,LAURA;149,21,233,59,28,6,0,149,20,0,NOEL;149,18,233,62,15,3,0,149,17,0,ANNA;149,20,233,68,6,6,0,149,19,0,NOEL;123,16,239,19,11,6,0,0,0,0,SERRA;123,15,239,20,9,7,0,0,0,0,BENNETT;123,22,239,27,11,7,3,123,21,0,SERRA;149,15,244,11,47,23,3,149,14,0,SAPHIRA;149,17,245,14,4,16,3,149,16,0,SIRIUS;149,14,247,58,74,62,3,0,0,0,SAPHIRA;149,14,247,58,74,62,3,0,0,259,SAPHIRA;149,7,254,31,65,15,0,0,0,0,LAURA;149,7,254,31,65,15,0,0,0,0,ANNA;149,7,254,31,65,15,0,0,0,0,CHARLOTTE;149,7,254,35,66,16,0,0,0,0,LAURA;149,8,254,41,40,6,0,149,7,0,SAPHIRA;149,13,262,22,48,79,1,0,0,0,SAPHIRA;149,13,262,23,49,79,1,0,0,0,SAPHIRA;149,13,262,24,47,79,1,0,0,0,SAPHIRA;149,13,262,25,46,79,1,0,0,0,SAPHIRA;149,13,262,26,45,79,1,0,0,0,SAPHIRA;149,13,262,27,46,82,0,0,0,0,LAURA;149,12,263,13,62,26,1,0,0,0,SAPHIRA;149,12,263,14,62,25,1,0,0,0,SAPHIRA;149,12,263,15,62,24,1,0,0,0,SAPHIRA;149,12,263,16,62,27,1,0,0,0,SAPHIRA;149,12,263,17,65,27,0,0,0,0,LAURA;149,11,264,9,17,13,1,0,0,0,SAPHIRA;149,11,264,10,15,13,1,0,0,0,SAPHIRA;149,11,264,11,16,13,1,0,0,0,SAPHIRA;149,11,264,12,14,13,1,0,0,0,SAPHIRA;149,11,264,13,14,9,0,0,0,0,LAURA;149,16,265,5,12,9,3,0,0,0,SAPHIRA;104,27,268,147,41,12,3,104,26,0,DR. SIGMUND;56,14,269,57,36,41,3,0,0,0,VICTORIA;56,15,269,96,68,22,1,0,0,0,;56,16,269,99,65,12,3,56,15,0,VICTORIA;56,17,269,107,16,14,1,0,0,0,;56,18,269,107,16,14,1,0,0,0,;123,14,271,187,56,9,1,0,0,0,SERRA;123,14,271,188,57,9,1,0,0,0,SERRA;123,21,271,192,56,10,3,123,20,0,EL;150,1,272,25,15,42,1,0,0,0,SAPHIRA;149,21,272,25,15,42,1,0,0,0,SAPHIRA;150,2,272,25,15,42,1,0,0,0,SAPHIRA;150,1,272,27,16,42,1,0,0,0,SAPHIRA;149,21,272,27,16,42,1,0,0,0,SAPHIRA;150,2,272,27,16,42,1,0,0,0,SAPHIRA;150,1,272,28,17,42,1,0,0,0,SAPHIRA;149,21,272,28,17,42,1,0,0,0,SAPHIRA;150,2,272,28,17,42,1,0,0,0,SAPHIRA;150,25,282,1,17,52,1,0,0,0,;150,4,285,67,2,30,3,150,3,0,FERN;150,2,285,67,2,30,3,150,3,0,FERN;150,3,285,68,5,36,1,0,0,0,;159,4,292,23,12,39,1,159,3,0,RADOMUS;159,2,293,5,9,39,1,0,0,0,;159,2,293,6,10,39,1,0,0,0,;150,7,293,10,9,7,3,0,0,0,;150,27,293,10,9,7,3,150,26,0,LUNA;150,8,293,12,8,31,0,0,0,0,GARDEVOIR;150,9,293,18,10,10,0,150,8,0,CAIN;150,9,293,19,9,10,0,150,8,0,CAIN;159,1,293,26,9,33,3,0,0,456,ELIAS;159,3,293,31,10,7,3,159,2,0,METEOR;150,10,295,5,10,9,3,150,8,0,EL;150,24,295,14,6,9,3,150,23,0,ADRIENN;150,11,296,5,12,8,1,0,0,0,CAIN;150,12,296,6,8,8,2,0,0,0,CAIN;173,1,298,4,8,8,0,0,0,0,CAIN;150,13,302,2,11,17,0,0,0,0,RADOMUS;150,23,305,9,23,31,1,150,22,0,;150,14,305,10,24,26,3,0,0,0,RADOMUS;150,22,306,58,33,27,0,0,0,0,EL;150,23,306,58,33,27,0,0,0,0,EL;150,15,307,8,13,7,1,0,0,0,CAIN;150,16,307,8,13,7,1,0,0,0,CAIN;150,15,307,9,7,4,1,0,0,0,CAIN;150,16,307,9,7,4,1,0,0,0,CAIN;150,17,307,14,13,2,0,0,0,0,;150,17,307,15,14,2,0,0,0,0,;150,19,309,3,10,10,3,0,0,0,ADRIENN;150,20,309,9,15,2,0,0,0,0,;150,20,309,10,16,2,0,0,0,0,;150,18,310,12,4,23,0,0,0,0,;150,18,310,13,4,19,0,0,0,0,;150,18,310,14,11,19,0,0,0,0,;150,21,310,39,4,42,0,0,0,0,;150,21,310,40,4,38,0,0,0,0,;150,21,310,41,11,42,0,0,0,0,;150,21,310,42,11,38,0,0,0,0,;150,28,313,1,12,19,3,0,0,0,GARDEVOIR;150,31,313,10,13,8,0,150,29,0,;150,29,313,43,9,5,0,0,0,0,RADOMUS;150,30,313,43,9,5,0,0,0,0,RADOMUS;150,29,313,44,10,5,0,0,0,0,RADOMUS;150,30,313,44,10,5,0,0,0,0,RADOMUS;150,40,313,49,15,16,1,0,0,2226,;150,40,313,49,15,16,1,0,0,2227,;150,40,313,49,15,16,1,0,0,2202,;150,41,315,35,9,4,3,0,0,2033,RADOMUS;150,42,315,35,9,4,3,0,0,2033,RADOMUS;150,32,316,35,12,19,3,0,0,0,CAIN;150,34,316,43,10,8,0,150,33,0,;150,33,316,49,9,5,0,0,0,0,CAIN;150,33,316,54,10,5,0,0,0,0,CAIN;150,35,317,35,12,19,3,0,0,0,LUNA;150,37,317,37,7,8,0,150,36,0,;150,36,317,57,9,5,0,0,0,0,LUNA;150,36,317,59,10,5,0,0,0,0,LUNA;150,38,318,35,12,19,3,0,0,0,GARDEVOIR;150,40,318,43,13,9,0,150,39,0,;150,39,318,51,9,5,0,0,0,0,GARDEVOIR;150,39,318,60,10,5,0,0,0,0,GARDEVOIR;159,8,324,45,21,25,0,0,0,0,NIHIL;159,8,324,46,16,22,0,0,0,0,DARM;159,8,324,47,25,18,0,0,0,0,PIERCE;159,8,324,48,14,34,0,0,0,0,RAZZY;159,10,324,49,25,12,3,159,9,0,;159,11,325,10,13,11,0,159,10,0,BENNETT;159,9,327,1,10,11,1,0,0,0,;159,9,327,2,11,11,1,0,0,0,;159,18,328,27,5,22,3,0,0,0,GARDEVOIR;159,11,328,34,75,17,1,0,0,0,BENNETT;159,12,329,8,25,20,1,0,0,0,;159,12,329,19,24,20,1,0,0,0,;159,12,329,20,26,20,1,0,0,0,;159,15,329,21,31,41,0,0,0,0,;159,15,329,22,19,41,0,0,0,0,;159,15,329,23,19,47,0,0,0,0,;159,15,329,24,31,47,0,0,0,0,;159,16,329,33,22,43,4,159,15,0,;159,14,329,33,22,43,4,159,15,0,;159,15,329,53,22,62,1,0,0,0,;159,13,331,6,10,4,3,0,0,0,;159,14,331,9,15,5,0,0,0,0,RANDALL;159,19,334,1,15,9,1,166,3,0,BENNETT;159,20,343,5,25,10,1,159,19,0,BENNETT;159,20,343,6,25,9,1,159,19,0,BENNETT;159,21,345,4,15,33,3,0,0,0,LUNA;56,1,353,44,23,34,0,0,0,62,VICTORIA;173,2,355,51,48,20,3,0,0,0,TERRA;173,4,355,79,23,21,0,0,0,0,STRIKER;173,5,356,40,15,26,3,0,0,0,SAMSON;173,13,356,43,22,19,3,173,12,0,RINGMASTER;173,11,356,43,22,19,3,173,12,0,RINGMASTER;276,39,356,43,22,19,3,276,38,0,RINGMASTER;276,37,356,43,22,19,3,276,38,0,RINGMASTER;173,6,357,3,14,6,0,0,0,0,AYA;193,32,357,15,5,5,0,193,31,0,SAMSON;193,45,357,15,5,5,3,193,44,0,CIEL;276,37,357,15,5,5,0,276,34,0,SAMSON;173,12,357,16,2,7,0,173,10,0,SAMSON;173,11,357,16,2,7,0,173,10,0,SAMSON;173,12,357,16,2,7,0,173,11,0,SAMSON;173,14,357,16,2,7,3,173,13,0,RINGMASTER;193,31,357,21,9,7,0,193,30,0,SAMSON;276,38,357,36,3,6,0,276,37,0,CIEL;276,40,357,36,3,6,3,276,39,0,RINGMASTER;276,32,359,6,22,17,1,276,31,0,SOLARIS;276,32,359,6,22,17,1,276,32,0,;184,5,359,28,26,59,3,184,4,0,AMARIA;276,30,359,69,30,26,1,276,26,0,;276,30,359,70,29,26,1,276,26,0,;276,30,359,71,31,26,1,276,26,0,;276,31,359,72,30,33,3,276,30,0,JULIA;276,35,359,89,25,19,0,276,34,0,TITANIA;184,7,361,53,22,16,3,0,0,0,CAIN;173,9,362,14,27,19,0,0,0,0,TITANIA;173,8,362,15,4,13,0,0,0,0,AMARIA;173,10,362,28,0,11,3,0,0,0,TV;184,4,362,37,11,12,0,0,0,0,TITANIA;193,2,364,26,42,32,3,193,1,0,SHELLY;77,16,370,2,9,6,0,0,0,477,COREY;184,6,390,25,43,36,0,184,5,0,AYA;184,9,404,1,11,13,3,0,0,0,AYA;184,10,404,25,33,15,1,0,0,0,;184,8,404,71,2,11,1,184,7,0,HARDY;184,8,404,74,2,12,1,184,7,0,HARDY;184,10,404,76,33,13,1,184,9,0,;184,10,404,77,33,14,1,184,9,0,;184,11,404,78,42,14,1,0,0,0,AYA;184,11,404,79,42,15,1,0,0,0,AYA;184,14,404,81,83,11,1,184,13,0,;184,14,404,82,83,12,1,184,13,0,;184,14,404,83,83,13,1,184,13,0,;184,15,406,6,35,24,3,0,0,0,AYA;184,13,408,17,8,7,0,0,0,0,AYA;184,12,409,12,23,17,1,0,0,0,AYA;391,3,412,46,59,32,0,391,1,0,HARDY;184,21,413,51,19,26,0,0,0,0,SAPHIRA;391,50,413,93,43,30,0,391,49,0,EVE;475,1,413,102,19,25,0,0,0,0,HARDY;475,2,413,118,21,28,0,475,1,0,BENNETT;475,27,414,54,16,35,1,475,26,0,LIN;475,3,414,76,48,25,1,0,0,0,SAPHIRA;475,26,414,102,37,22,3,0,0,1349,CAL;475,7,414,103,21,31,1,0,0,0,;475,9,414,104,20,22,1,0,0,0,;475,8,414,105,16,36,3,475,7,0,LAURA;475,9,414,109,21,22,1,0,0,0,;475,9,414,110,22,22,1,0,0,0,;475,10,414,111,18,22,3,475,9,0,METEOR;475,8,414,111,18,22,3,475,9,0,METEOR;475,10,414,111,18,22,3,475,9,1048,METEOR;475,8,414,111,18,22,3,475,9,1048,METEOR;475,22,414,119,12,11,3,475,23,0,ZERO;391,1,417,23,13,23,3,0,0,503,FLORINIA;391,51,417,29,11,27,3,391,50,0,HARDY;391,51,417,30,12,25,3,391,50,503,FLORINIA;184,16,418,4,19,7,1,0,0,0,HARDY;184,22,418,4,19,7,1,184,21,0,CHARLOTTE;391,2,418,9,23,8,0,391,1,0,CHARLOTTE;77,2,423,15,9,10,0,77,1,0,;193,1,432,1,19,12,0,0,0,0,AVALUGG;193,15,439,15,34,113,0,193,14,0,SHELLY;193,15,439,59,35,113,0,193,14,0,SHELLY;193,18,439,66,126,73,0,193,17,0,SHELLY;193,19,439,112,24,81,0,193,18,0,SHELLY;193,21,439,112,24,81,1,193,20,0,;193,19,439,115,23,81,1,193,18,0,SHELLY;193,21,439,115,23,81,1,193,20,0,;193,21,439,116,85,65,3,193,20,0,SHELLY;193,19,439,116,85,65,3,193,20,0,SHELLY;193,24,439,116,85,65,3,193,23,0,CAL;193,22,439,116,85,65,3,193,23,0,CAL;193,20,439,117,84,64,1,0,0,0,;193,23,439,117,84,64,1,193,22,0,;193,20,439,118,84,65,1,0,0,0,;193,23,439,118,84,65,1,193,22,0,;193,23,439,123,121,58,3,193,22,0,SHELLY;193,21,439,123,121,58,3,193,22,0,SHELLY;193,22,439,124,119,60,1,193,21,0,;193,25,439,124,119,60,0,193,24,0,SHELLY;193,24,439,130,98,47,1,193,23,0,CAL;193,26,439,130,98,47,1,193,25,506,SHELLY;193,28,439,138,98,39,1,193,23,0,BLAKE;193,17,439,142,65,95,3,193,16,0,SHELLY;193,20,439,143,126,74,3,193,19,0,SHELLY;193,22,439,147,23,79,3,193,21,0,BLAKE;193,27,439,152,89,37,1,193,25,0,BLAKE;193,30,439,157,82,20,1,0,0,0,BLAKE;193,28,441,4,12,21,1,193,27,0,ASTER;193,34,443,5,17,40,0,0,0,0,;193,34,443,6,15,40,1,0,0,0,;193,34,443,7,16,40,1,0,0,0,;193,34,443,8,18,40,1,0,0,0,;193,35,443,9,17,23,0,0,0,0,;193,35,443,10,18,23,1,0,0,0,;193,36,443,11,21,9,0,0,0,0,TERRA;193,36,443,19,20,9,1,0,0,0,TERRA;193,36,443,39,22,9,1,0,0,0,TERRA;193,36,443,40,24,9,1,0,0,0,TERRA;193,36,443,42,19,9,1,0,0,0,TERRA;193,36,443,43,23,9,1,0,0,0,TERRA;193,33,446,3,11,5,0,0,0,0,;193,33,446,4,10,5,1,0,0,0,;193,33,446,5,9,5,1,0,0,0,;193,37,447,4,26,24,0,0,0,0,;193,37,447,19,27,24,1,0,0,0,;193,38,449,2,26,17,3,0,0,0,;193,39,449,13,18,20,1,0,0,0,;193,40,451,13,11,6,0,0,0,0,;193,41,452,3,18,22,1,0,0,0,;193,41,452,4,17,22,1,0,0,0,;193,42,454,2,6,13,0,0,0,0,;193,42,454,3,7,13,0,0,0,0,;193,43,454,4,6,0,1,0,0,0,;193,43,454,5,7,0,1,0,0,0,;193,44,456,3,9,5,0,0,0,0,TERRA;193,16,457,9,24,10,0,0,0,0,SHELLY;193,17,457,30,23,7,0,0,0,508,SHELLY;193,18,457,30,23,7,0,0,0,508,SHELLY;193,11,461,6,13,10,3,193,5,0,SHELLY;193,12,461,6,13,10,3,193,5,0,SHELLY;193,13,461,6,13,10,3,193,5,0,SHELLY;193,14,461,6,13,10,3,193,5,0,SHELLY;193,19,462,4,9,6,3,0,0,0,HEATHER;276,1,466,3,10,22,3,185,1,0,;276,29,466,3,10,22,3,185,2,0,;276,2,467,14,13,11,3,0,0,0,TITANIA;276,4,467,14,13,11,3,276,3,0,TITANIA;276,3,467,15,12,11,1,0,0,0,;276,28,467,15,12,11,1,276,27,0,TITANIA;276,22,467,22,12,26,1,0,0,0,;276,9,469,59,19,15,0,276,7,0,TITANIA;276,6,470,48,22,8,3,276,5,0,TITANIA;276,11,471,45,11,18,3,0,0,0,TITANIA;276,14,472,43,13,15,3,0,0,0,TITANIA;276,23,473,50,15,16,0,0,0,0,;276,20,475,37,23,4,3,0,0,0,TITANIA;276,21,475,40,11,10,1,0,0,0,TITANIA;276,26,478,10,12,10,3,0,0,0,TAKA;276,27,479,19,21,3,1,0,0,0,SHADE;276,5,480,40,23,6,3,0,0,0,TITANIA;276,7,482,43,21,9,0,0,0,0,TITANIA;276,9,482,44,19,15,0,276,7,0,TITANIA;276,13,484,38,11,18,3,276,12,0,TITANIA;276,12,484,40,21,11,3,276,11,0,;276,15,486,38,2,3,3,276,14,0,;276,17,486,38,2,3,3,276,16,0,;276,16,486,39,13,15,3,276,15,0,;276,18,486,40,7,10,3,276,17,0,TITANIA;276,19,488,26,17,6,1,0,0,0,TITANIA;276,19,488,28,17,7,1,0,0,0,TITANIA;276,21,494,32,11,10,1,0,0,0,TITANIA;276,22,496,57,31,22,1,0,0,0,TITANIA;276,22,496,59,32,22,1,0,0,0,TITANIA;276,27,497,19,21,3,1,0,0,0,SHADE;276,25,505,38,24,10,0,0,0,0,TITANIA;276,24,505,57,21,18,3,276,22,0,TITANIA;123,17,506,13,6,43,1,0,0,0,;123,18,506,53,8,30,3,123,17,0,BENNETT;123,16,506,53,8,30,3,123,17,0,BENNETT;123,19,506,55,9,4,0,0,0,0,SERRA;123,20,506,55,9,4,0,0,0,0,SERRA;276,33,508,1,10,7,3,0,0,0,ORDERLY;276,34,508,1,10,7,3,0,0,0,ORDERLY;276,36,508,15,10,8,0,276,35,0,JULIA;276,36,508,17,16,7,0,276,35,0,JULIA;381,19,508,33,29,20,3,381,18,0,AMARIA;276,32,509,5,10,7,1,276,31,0,;339,45,527,75,67,27,3,339,44,0,ADRIENN;339,50,613,5,14,27,0,339,45,0,ADRIENN;339,46,613,5,14,27,0,339,45,0,ADRIENN;339,46,613,5,14,27,0,339,55,0,ADRIENN;339,46,613,5,14,27,0,339,60,0,ADRIENN;339,46,613,5,14,27,0,339,65,0,ADRIENN;339,47,613,7,9,18,1,339,46,0,ADRIENN;339,48,613,7,9,18,1,339,46,0,ADRIENN;339,10,622,2,2,10,1,0,0,0,;339,8,622,10,10,7,3,0,0,0,METEOR;339,9,622,10,10,7,3,0,0,0,METEOR;339,13,623,32,11,11,3,0,0,0,VICTORIA;339,14,624,68,11,8,3,0,0,0,METEOR;339,15,624,70,6,4,1,0,0,0,;339,15,624,71,7,4,1,0,0,0,;339,16,624,71,7,4,3,339,15,0,METEOR;339,17,625,3,5,7,3,0,0,0,VICTORIA;339,18,625,3,5,7,3,0,0,0,VICTORIA;339,19,625,3,5,7,3,0,0,0,VICTORIA;339,20,625,3,5,7,3,0,0,0,VICTORIA;339,21,625,3,5,7,3,0,0,0,VICTORIA;339,22,625,3,5,7,3,0,0,0,VICTORIA;339,23,625,3,5,7,3,0,0,0,VICTORIA;339,24,625,3,5,7,3,0,0,0,VICTORIA;339,25,626,6,14,4,3,0,0,0,ARC;339,26,627,3,1,4,3,0,0,0,ARC;339,27,627,4,6,8,1,0,0,0,;339,28,627,4,6,8,3,339,27,0,;339,30,628,23,5,7,1,0,0,0,VICTORIA;339,31,628,23,5,7,1,0,0,0,VICTORIA;339,32,628,23,5,7,1,0,0,0,VICTORIA;339,33,628,23,5,7,1,0,0,0,VICTORIA;339,29,628,23,5,7,1,0,0,0,VICTORIA;339,34,628,40,5,25,1,0,0,0,ARC;339,35,628,40,5,25,1,0,0,0,ARC;339,36,628,40,5,25,1,0,0,0,ARC;339,33,628,40,5,25,1,0,0,0,ARC;339,38,628,45,5,47,3,339,37,0,AME;339,41,628,66,30,45,0,0,0,0,ADRIENN;339,42,628,66,30,45,0,0,0,0,ADRIENN;339,43,628,66,30,45,0,0,0,0,ADRIENN;339,44,628,66,30,45,0,0,0,0,ADRIENN;339,37,629,11,12,2,1,0,0,0,;339,39,632,7,8,6,3,0,0,0,;339,40,632,8,4,26,0,0,0,0,;381,21,678,5,30,49,1,381,20,0,JULIA;381,21,678,7,29,49,1,381,20,0,JULIA;381,18,678,17,33,46,1,0,0,0,;381,19,678,17,33,46,1,0,0,878,;381,15,679,1,24,22,0,381,14,0,AMARIA;381,19,679,1,24,22,0,381,18,0,TITANIA;381,20,679,1,24,22,0,381,19,0,AMARIA;381,19,679,2,24,23,0,381,18,0,TITANIA;381,18,680,44,50,103,0,381,17,0,AMARIA;381,17,680,45,56,132,0,381,16,0,AMARIA;381,16,683,38,24,61,0,381,15,0,AMARIA;381,17,683,39,64,121,0,381,16,0,AMARIA;381,16,683,40,81,74,0,381,15,0,AMARIA;381,18,683,41,29,116,0,381,17,0,AMARIA;381,1,698,20,9,19,1,0,0,0,;381,1,698,21,10,19,1,0,0,0,;381,1,698,22,8,19,1,0,0,0,;381,2,698,23,9,10,3,381,1,0,LIN;381,3,698,80,36,83,1,362,1,0,LIN;381,3,698,81,36,84,1,362,1,0,LIN;381,3,698,82,36,85,1,362,1,0,LIN;381,3,698,83,36,87,1,362,1,0,LIN;381,3,698,84,36,86,1,362,1,0,LIN;381,3,698,85,36,82,1,362,1,0,LIN;381,3,698,86,34,82,1,0,0,0,LIN;381,3,698,87,34,83,1,0,0,0,LIN;381,3,698,88,34,84,1,0,0,0,LIN;381,3,698,89,34,85,1,0,0,0,LIN;381,3,698,90,34,86,1,0,0,0,LIN;381,3,698,91,34,87,1,0,0,0,LIN;381,8,699,5,9,2,1,0,0,0,;381,8,699,6,10,2,1,0,0,0,;381,8,699,7,2,24,1,0,0,0,;381,8,699,8,3,24,1,0,0,0,;381,8,699,9,9,45,1,0,0,0,;381,8,699,10,10,45,1,0,0,0,;381,8,699,11,2,67,1,0,0,0,;381,8,699,12,3,67,1,0,0,0,;381,8,699,13,9,74,1,0,0,0,;381,8,699,14,10,74,1,0,0,0,;381,8,699,15,2,52,1,0,0,0,;381,8,699,16,3,52,1,0,0,0,;381,8,699,17,9,31,1,0,0,0,;381,8,699,18,10,31,1,0,0,0,;381,8,699,19,2,9,1,0,0,0,;381,8,699,20,3,9,1,0,0,0,;381,9,700,47,39,21,1,0,0,0,;381,10,700,48,44,23,3,381,9,0,TITANIA;381,11,701,8,24,88,1,0,0,0,;381,13,701,15,24,21,3,381,12,0,LIN;381,12,701,16,25,24,1,0,0,0,;381,12,701,17,24,24,1,0,0,0,;381,14,702,5,24,17,0,0,0,0,TITANIA;391,21,715,63,39,15,1,391,13,0,;391,4,715,69,26,20,0,0,0,0,HARDY;391,7,715,70,24,18,0,391,6,0,HARDY;391,8,715,72,23,17,0,391,7,0,HARDY;391,9,715,72,23,17,0,391,7,0,HARDY;391,10,715,83,39,14,0,391,9,0,HARDY;391,46,715,85,38,15,3,391,45,0,GARDEVOIR;391,5,731,3,3,11,1,0,0,0,;391,5,731,4,4,11,1,0,0,0,;391,6,731,5,4,8,4,391,5,0,HARDY;391,6,731,6,8,1,4,391,4,0,HARDY;391,15,732,2,72,19,0,0,0,0,;391,16,732,3,73,30,0,391,15,0,GLACEON;391,17,732,30,67,39,0,391,16,0,;391,18,732,47,68,37,0,391,17,0,GLACEON;391,19,732,50,67,24,0,391,18,0,METEOR;391,21,732,93,11,24,1,391,20,0,GLACEON;391,22,732,102,19,30,1,391,21,0,ESPEON;391,22,732,103,19,31,1,391,21,0,ESPEON;391,11,733,1,25,26,0,0,0,0,HARDY;391,12,733,1,25,26,0,0,0,0,HARDY;391,13,733,9,28,40,1,0,0,0,HARDY;391,14,733,24,27,3,1,0,0,0,;391,21,733,25,26,44,1,0,0,957,;391,47,734,16,17,22,3,391,46,0,GARDEVOIR;391,45,735,4,16,19,3,0,0,0,ELIAS;391,49,735,4,16,19,3,391,48,0,RADOMUS;391,48,735,7,15,19,3,391,47,0,BENNETT;391,20,737,4,64,14,1,0,0,0,METEOR;391,23,737,20,19,11,0,0,0,0,ESPEON;391,21,738,4,57,11,1,0,0,0,;391,21,738,5,56,11,1,0,0,0,;391,60,740,3,9,18,1,0,0,0,HARDY;391,61,740,3,9,18,1,0,0,0,HARDY;391,56,741,2,46,15,3,391,55,0,LIN;391,55,741,4,46,42,1,0,0,0,;391,25,755,3,98,94,0,0,0,0,VICTORIA;391,25,755,11,99,94,1,0,0,0,VICTORIA;391,26,756,4,102,19,0,0,0,0,FERN;391,27,757,3,172,9,1,0,0,0,;391,27,757,29,172,10,1,0,0,0,;391,28,757,34,187,80,3,0,0,0,;391,29,757,55,157,138,3,0,0,0,;391,30,757,76,156,23,1,0,0,0,;391,30,757,84,156,20,1,0,0,0,;391,34,758,30,31,16,1,0,0,0,;391,37,758,31,22,64,4,391,36,0,;391,38,758,31,22,64,4,391,36,0,;391,39,758,31,22,64,4,391,36,0,;391,40,758,31,22,64,4,391,36,0,;391,31,758,62,83,18,1,0,0,0,;391,31,758,63,83,19,1,0,0,0,;391,32,758,89,54,18,1,0,0,0,;391,33,758,92,37,57,1,0,0,0,;391,34,758,101,31,9,1,0,0,0,;391,35,758,102,17,16,1,0,0,0,;391,35,758,103,17,9,1,0,0,0,;391,36,758,107,19,63,1,0,0,0,;391,36,758,108,18,63,1,0,0,0,;391,54,763,44,46,50,3,391,53,0,HARDY;391,52,763,44,46,50,3,391,53,0,HARDY;391,52,763,82,30,62,1,0,0,0,;391,52,763,83,31,62,1,0,0,0,;391,52,763,84,32,62,1,0,0,0,;391,57,763,89,60,68,1,391,56,0,;391,57,763,90,61,68,1,391,56,0,;391,53,763,110,43,52,1,0,0,0,;391,53,763,113,44,52,1,0,0,0,;391,53,763,114,45,52,1,0,0,0,;391,53,763,115,46,52,1,0,0,0,;391,53,763,116,47,52,1,0,0,0,;391,53,763,117,48,52,1,0,0,0,;391,57,763,161,59,62,1,391,56,0,;391,57,763,162,66,59,1,391,56,0,;391,59,763,163,61,64,0,391,58,0,SHELLY;391,58,763,170,69,61,3,391,57,0,CIEL;475,31,768,1,41,16,3,0,0,0,HARDY;475,60,768,1,41,16,3,0,0,0,HARDY;475,61,769,1,23,6,3,0,0,0,JULIA;475,62,769,1,23,6,3,0,0,0,JULIA;475,63,769,1,23,6,3,0,0,0,JULIA;475,85,770,2,23,5,3,0,0,0,RADOMUS;475,86,770,2,23,5,3,0,0,0,RADOMUS;475,87,770,2,23,5,3,0,0,0,RADOMUS;475,91,771,2,23,5,3,0,0,0,HARDY;475,92,771,2,23,5,3,0,0,0,HARDY;475,93,771,2,23,5,3,0,0,0,HARDY;475,4,774,2,9,19,1,0,0,0,METEOR;475,5,774,9,9,10,0,0,0,0,VICTORIA;475,6,774,9,9,10,0,0,0,0,VICTORIA;475,23,774,25,27,76,1,0,0,0,;475,11,774,33,28,61,1,0,0,0,;475,12,774,34,29,59,1,0,0,0,;475,12,774,35,29,60,1,0,0,0,;475,13,774,36,31,59,1,0,0,0,;475,13,774,37,31,60,1,0,0,0,;475,13,774,38,31,61,1,0,0,0,;475,14,774,39,33,60,1,0,0,0,;475,15,774,56,32,50,1,0,0,0,;475,16,774,57,28,49,1,0,0,0,;475,16,774,58,28,50,1,0,0,0,;475,17,774,59,24,49,1,0,0,0,;475,18,774,60,20,49,1,0,0,0,;475,18,774,61,20,50,1,0,0,0,;475,19,774,62,16,50,1,0,0,0,;475,20,774,63,12,50,1,0,0,0,;475,21,774,88,11,56,1,0,0,0,;475,21,774,89,12,56,1,0,0,0,;475,22,774,98,10,77,1,0,0,0,;475,22,774,99,10,78,1,0,0,0,;475,29,774,114,8,90,1,0,0,0,;475,28,774,115,10,91,4,0,0,0,;475,29,774,115,10,91,4,0,0,0,;475,27,774,115,10,91,4,0,0,0,;475,30,775,11,87,5,1,0,0,0,;475,84,776,12,41,10,3,0,0,1062,CHARLOTTE;475,88,777,10,15,12,0,0,0,0,HARDY;475,89,777,10,15,12,0,0,0,0,HARDY;475,90,777,10,15,12,0,0,0,0,HARDY;475,94,778,9,9,65,1,0,0,0,;475,95,778,9,9,65,1,0,0,0,;475,96,778,9,9,65,1,0,0,0,;475,97,778,9,9,65,1,0,0,0,;475,98,778,9,9,65,1,0,0,0,;475,99,778,9,9,65,1,0,0,0,;475,100,778,10,9,69,3,475,99,0,SAPHIRA;475,94,778,11,10,65,1,0,0,0,;475,95,778,11,10,65,1,0,0,0,;475,96,778,11,10,65,1,0,0,0,;475,97,778,11,10,65,1,0,0,0,;475,98,778,11,10,65,1,0,0,0,;475,99,778,11,10,65,1,0,0,0,;475,106,778,24,8,14,1,475,105,0,;475,106,778,25,8,15,1,475,105,0,;475,108,778,27,18,9,4,0,0,0,;475,107,778,43,24,14,1,475,106,0,;475,107,778,44,24,15,1,475,106,0,;475,109,778,49,40,11,0,475,108,0,FLORINIA;475,101,779,73,12,82,0,0,0,0,SAPHIRA;475,102,779,74,26,43,0,475,101,0,;475,102,779,75,27,43,0,475,101,0,;475,103,779,76,5,50,3,475,102,0,SAPHIRA;475,103,779,80,11,78,1,0,0,0,;475,105,780,91,26,43,0,475,104,0,;475,105,780,92,27,43,0,475,104,0,;475,104,780,93,30,11,1,0,0,0,SAPHIRA;475,113,784,12,55,72,1,0,0,0,;475,113,784,13,56,72,1,0,0,0,;475,110,784,106,83,31,3,0,0,0,FERN;475,111,786,28,54,25,1,0,0,0,;475,112,786,29,64,27,3,475,111,0,CHARLOTTE;475,119,786,103,1,0,3,475,118,0,;475,122,787,75,22,64,1,0,0,0,;475,122,787,78,23,64,1,0,0,0,;475,122,787,79,24,64,1,0,0,0,;475,123,787,80,74,56,3,475,122,0,FERN;475,124,787,89,41,66,3,0,0,0,FERN;475,125,787,89,41,66,3,0,0,0,FERN;475,114,788,50,27,67,3,0,0,0,CHARLOTTE;475,119,788,83,19,65,1,0,0,0,;475,128,790,46,47,30,0,0,0,0,VICTORIA;475,129,790,46,47,30,0,0,0,0,VICTORIA;475,126,790,49,60,54,1,0,0,0,;475,126,790,50,61,54,1,0,0,0,;475,127,790,51,57,53,3,475,126,0,VICTORIA;475,127,790,51,57,53,3,475,126,0,TITANIA;475,127,790,52,48,30,0,475,128,0,VICTORIA;475,127,790,52,48,30,0,475,128,0,TITANIA;475,129,790,70,64,52,1,0,0,0,;475,130,791,39,36,25,3,0,0,0,VICTORIA;475,130,791,39,36,25,3,0,0,0,TITANIA;475,131,792,9,26,50,0,0,0,0,;475,132,792,60,27,46,3,475,131,0,HARDY;475,133,792,65,31,11,1,0,0,0,;475,134,792,67,32,18,3,475,133,0,VICTORIA;475,135,792,67,32,18,3,475,133,0,VICTORIA;475,136,793,82,21,32,1,0,0,0,VICTORIA;475,141,794,7,132,26,1,0,0,0,;475,140,794,7,132,26,1,0,0,0,;475,141,794,8,132,27,1,0,0,0,;475,140,794,8,132,27,1,0,0,0,;475,139,794,70,96,41,1,475,138,0,SOLARIS;475,141,794,72,98,41,3,475,140,0,SOLARIS;475,139,794,72,98,41,1,0,0,0,;475,141,794,79,90,34,3,475,139,0,CHATOT;475,139,794,80,98,40,1,0,0,0,;475,142,796,26,25,16,1,0,0,0,;475,143,796,27,18,23,3,475,142,0,FLORINIA;475,144,798,14,30,16,1,0,0,0,;475,144,798,15,30,17,1,0,0,0,;475,145,798,16,21,18,3,475,144,0,FERN;475,143,798,16,21,18,3,475,144,0,FERN;475,111,811,28,54,25,1,0,0,0,;475,113,812,12,55,72,1,0,0,0,;475,113,812,13,56,72,1,0,0,0,;475,121,812,91,85,38,3,475,120,0,CHARLOTTE;475,120,812,106,81,39,0,0,0,0,;475,138,813,7,90,54,1,0,0,0,;475,138,813,8,90,55,1,0,0,0,;475,122,813,75,22,64,1,0,0,0,;475,122,813,78,23,64,1,0,0,0,;475,122,813,79,24,64,1,0,0,0,;475,137,813,85,69,20,3,0,0,0,HARDY;475,124,813,89,41,66,3,0,0,0,FERN;475,125,813,89,41,66,3,0,0,0,FERN;77,3,885,6,22,39,1,0,0,0,TAKA"

# which maps can change each story variable: var,map
RH_VARMAP_DATA = "56,29;56,36;56,37;56,85;56,87;56,93;56,94;56,95;56,97;56,107;56,119;56,125;56,269;56,353;77,80;77,127;77,144;77,149;77,150;77,153;77,370;77,423;77,885;92,79;92,80;92,147;92,175;92,176;92,180;92,181;92,182;104,80;104,176;104,181;104,192;104,193;104,194;104,195;104,196;104,198;104,268;107,8;107,9;107,10;107,11;107,13;107,16;107,17;107,25;107,26;107,27;107,57;107,66;107,130;107,133;107,150;107,196;107,197;118,15;118,21;118,22;118,26;118,27;118,33;118,34;118,81;118,206;118,208;118,209;118,210;118,223;118,224;123,225;123,227;123,230;123,239;123,271;123,506;149,231;149,232;149,233;149,244;149,245;149,247;149,254;149,262;149,263;149,264;149,265;149,272;150,79;150,97;150,272;150,282;150,285;150,293;150,295;150,296;150,302;150,305;150,306;150,307;150,309;150,310;150,313;150,315;150,316;150,317;150,318;159,165;159,168;159,170;159,292;159,293;159,324;159,325;159,327;159,328;159,329;159,331;159,334;159,343;159,345;173,298;173,355;173,356;173,357;173,362;184,359;184,361;184,362;184,390;184,404;184,406;184,408;184,409;184,413;184,418;184,419;193,357;193,364;193,432;193,439;193,441;193,443;193,446;193,447;193,449;193,451;193,452;193,454;193,456;193,457;193,461;193,462;276,356;276,357;276,359;276,466;276,467;276,469;276,470;276,471;276,472;276,473;276,475;276,478;276,479;276,480;276,482;276,484;276,486;276,488;276,494;276,496;276,497;276,505;276,508;276,509;339,38;339,53;339,84;339,117;339,229;339,520;339,524;339,526;339,527;339,528;339,530;339,531;339,535;339,543;339,548;339,551;339,552;339,559;339,570;339,594;339,613;339,622;339,623;339,624;339,625;339,626;339,627;339,628;339,629;339,632;381,508;381,678;381,679;381,680;381,683;381,698;381,699;381,700;381,701;381,702;391,412;391,413;391,417;391,418;391,715;391,731;391,732;391,733;391,734;391,735;391,737;391,738;391,740;391,741;391,755;391,756;391,757;391,758;391,763;475,413;475,414;475,768;475,769;475,770;475,771;475,774;475,775;475,776;475,777;475,778;475,779;475,780;475,784;475,786;475,787;475,788;475,790;475,791;475,792;475,793;475,794;475,796;475,798;475,811;475,812;475,813"

# values / switches set on the way into each map (by the event that sends you there): map:vN=X sN ...
RH_TRANSIT_DATA = "11:v108=1 v109=2 v111=5 v112=4 v113=3 v114=7 v115=6 s172;97:s285 v150=25;22:s178;26:v192=0 s525 v107=27 v107=25 v107=21 s789 v118=10 s183;17:v118=5;564:v635=2 v635=6;57:s51 v107=9 s59 s1719 s58 s60;508:s1024 s525 s579 s458 s884;855:v620=0 v621=1 v621=2 v621=3 v621=4 v621=0 v620=1 v620=4 v620=3 v620=2;21:v192=0 s2016 v107=25 s2021 s181;38:s31;887:s1810 s779 s1809 s1819 s1817 s1818 s1820 s1821 s1822 s1824 s1823 s1829 s1827 v664=5 v62=887 v664=4;34:s175;199:s174;29:s39 s421;519:s977 s39 s649 v552=0 v611=15;39:s32 s1987 s1953 v62=0 v747=4 v747=5 v769=99;764:v62=0 v440=6 v438=30 s979 v440=4 s1962 v747=4 v747=5 v769=99;899:s1987 s1993 s484 s1990 s1995 s1998 v742=1 v742=2 v742=3 v742=0 v742=4 v322=2 v322=0 s652 s2003 s2069 s1988 v552=0 s1370 s2018 s1612 s2011 s1996 s1991 s2002 s2006 v769=1001 v769=1020 v769=0 v766=2 v769=1000;689:v358=1 v62=0 v358=6 v358=0 v151=0 v151=1 s289 v151=2 s707 s2086 s1060 s2243;71:s410 v634=24 v634=30;64:v52=6;522:v323=0 v321=0 v322=1 v322=0 v322=-1 v322=4 v322=2 s655 s649 v322=3 s1984 v62=0 v747=4 v747=5 v769=99;328:v323=0 s2203 s434 s435 v749=0 v628=11 s1315 v628=12 s1334 s1691 v628=10;78:s1993 s1967 v62=0 v747=4 v747=5 v769=99;181:s1058 s152 v104=9 v192=2 v192=0 v104=23 v104=22;41:v104=24 v104=27;175:v97=0 v98=0 v99=0 v100=0 v101=0 v102=0 v103=0 v320=0 v319=7 v92=14;91:v638=1 v61=0;623:s779;89:v639=1 v640=1 v639=0 v640=0 v639=2 v640=2;90:v61=5;92:v61=5;81:v61=5 v638=0 v118=18;95:v56=9;292:v150=26 s423 v159=3;526:s285 s649 v322=0;103:v157=4;635:v157=4;106:v62=0 v770=100000 s2090;36:s457 v56=18 s63 s785 s208 v56=17 v644=90 v644=95 v644=100;113:v68=1;129:v74=0;125:v192=0 s525 s586 s592 v77=1 s64;128:v75=7;118:v75=7;423:v107=4;150:v107=6 v77=9 s2160 v77=5 s1804 s1785 s1802 v660=22;130:s2095;382:v185=0 s649;153:s1804 s1784 v77=4 s1785 s1652 s1789 s1788;149:s457 s525 v192=0 s1000 s1802 v655=11 s98 s91;889:s1804 v661=7 v662=10 v660=19 v663=13 s1106 s1971 v62=0 v747=4 v747=5 v769=99;886:s1804 v661=9 v662=6 s1806 v661=7 v662=5 v662=10 v661=12 v662=14 v661=10 v662=9 v661=30 v662=26 v661=24 v662=21 v661=18 v662=24 v661=20 v662=31;133:v107=7;162:s101 s102 s106 s105;184:s541;172:v93=0;163:s484 s1966 v62=0 v747=4 v747=5 v769=99;168:v79=0 v79=1 v160=13 v349=5 s2203;324:s437 s426 v159=9 s2034 s436;176:s151 v106=2;80:v104=1 v92=17 s154 v192=2 v192=0 v104=23;79:s130 v92=10;304:v552=10 v552=11 v552=12 v552=13 v552=14 s2211 v150=23;896:s1891 s1893 s1892;190:s1042;193:s1990 s1960 v62=0 v747=4 v747=5 v769=99;197:v107=1 v107=2 v161=0;146:v161=0;560:v161=0;196:s157 v192=0 s525 s139;202:s176;15:s260 v192=1 v118=3 v118=4 v118=1;367:s260 v192=1 v118=3 v118=4 v118=1;214:s193;215:s196;227:s785;225:v192=0 s525 v123=8;761:s968 s2106;622:v339=7 s777;228:s282;232:v748=12 s2032 s1963 v62=0 v747=4 v747=5 v769=99;231:v149=21;233:v748=14 v149=2 s2032 v192=1 v149=4 s256 s257 s1995 s1968 v62=0 v747=4 v747=5 v769=99;271:v145=8 v123=19 v192=0 s525 s569 s207 v123=20;251:s248 v146=0;234:v145=8 v146=0 s248;246:s272;265:s457;244:s290 v149=14;252:s248 v146=0;614:v341=3 v341=2 v341=1;617:v341=3 v341=2 v341=1 s740 s741 s742;247:v149=13;262:v149=12;263:v149=11;245:v149=16;235:v145=8;239:v123=21 s1975 v62=0 v747=4 v747=5 v769=99;282:s292 s361 s362 s363 s364 s365;272:v150=25;283:s356 s357 s358 s359 s360 s292;284:s366 s292;289:s292 s393 s326 s334 s335;288:s292 s336 s337 s338 v622=16;434:v185=0 v473=0 v474=0;293:v159=2 s1998 s1972 v62=0 v747=4 v747=5 v769=99;831:v562=12;295:v150=24;354:s461;355:s461;763:s461 s649 v618=29 s2074 v552=0;312:s789 s250 v150=22 v150=23;318:s456 v154=0;527:v670=4 s1314 v670=2 v616=2 v192=0 s1316 v586=16 v586=14 v631=11 s1335 s1336 v637=32 s1803 v660=34 v161=0 v660=35 s1337 s1338 s1325 s1309 s1313 v660=33 s1939 s1308 s2008 v62=0 v747=4 v747=5 v769=99;316:v154=0;317:v154=0;315:v154=0;327:s2203;326:s2203;325:s2203;352:s2203;637:s2203 s795 s796;478:v160=13 v349=5;291:v159=18;62:v323=2 v160=13 v349=5;329:s528;332:s2100 s784 v628=11 s1315 v628=12 s1334 s1691 v628=10 s2089;331:s427;347:v159=19;342:v159=19;356:s2324 s2043 v173=12 v173=11 v276=38 v332=1 s479 s733 s2051 v750=0;357:v192=0 s525 s460 v173=13 v173=11 s581 v276=39 v276=37;446:v193=32;390:v185=0 s649;360:s410;362:v276=32 s2042;380:s649 v185=0;466:s649 v185=1 v185=2;589:s649 v185=1 v185=2;358:s410;364:v185=0 s649 s457 s290 s483 v193=1 s2050;359:v184=4 s649 v276=29 v185=0 s580;375:s649;366:s649;365:v74=0 v74=1;373:s649 v185=0 v185=1;381:v185=0;374:s649 s521 v185=0;376:s649 v622=16;377:s649;378:s649 v185=2;379:s649;386:s649;383:s649;385:s649;430:s649;384:s649;396:s649;387:v473=0 v474=0 s649;835:v586=3;404:s410;417:s503 v214=9 v214=1;419:s1032;413:s1047 v475=2 v560=0 s1087 v214=10 v469=0 s921 v391=49 s410;414:s1831 v611=3 v611=2 v611=5 s1053 v475=26 s1830 v611=4 v475=23 s2135 v611=6 s1974 v62=0 v747=4 v747=5 v769=99;632:s1831 v611=3 v611=2 v611=5 s782 s525 v192=4 s457 s1000 v192=-1 v339=39 s2069 v611=4 s1982 v62=0 v747=4 v747=5 v769=99;426:v82=0 v326=0;441:v185=0;440:v185=0;442:v185=0;439:v192=0 s525 v193=30 v193=19;450:v193=39 s1973 v62=0 v747=4 v747=5 v769=99;452:s261;453:v193=41;456:v193=43;454:s290;457:v74=0 v74=1;460:v74=0 v74=1;467:v256=2 v257=2 v258=2 v259=2 v260=2 v261=2 v262=2 v263=2 v264=2 s575 v276=1 s649 v276=27;473:s549 s550 s551 s552 s553 s554 s555 s556 s557 s585 s584 s576 v276=22 v258=1 v258=0;503:v262=3 v262=2 v235=0 v275=1 v237=15 v238=11 v239=15 v240=12 v241=0 v242=0 v243=0 v244=0 v245=0 v246=0 v273=0 v274=0 v236=2 v275=2 v238=16 v240=17 v275=3 v237=17 v238=14 v239=12 v240=14 v275=4 v237=7 v238=6 v239=7 v240=7 v241=12 v242=7 v236=3;492:v262=3 v262=2 v235=0 v275=1 v237=15 v238=11 v239=15 v240=12 v241=0 v242=0 v243=0 v244=0 v245=0 v246=0 v273=0 v274=0 v236=2 v275=2 v238=16 v240=17 v275=3 v237=17 v238=14 v239=12 v240=14 v275=4 v237=7 v238=6 v239=7 v240=7 v241=12 v242=7 v236=3;498:v257=3 v257=2 v235=0 v275=1 v237=21 v238=9 v239=21 v240=14 v241=25 v242=9 v243=25 v244=14 v245=26 v246=9 v273=26 v274=14 v236=6 v275=2 v237=19 v238=16 v239=19 v240=17 v241=14 v242=16 v243=14 v244=18 v236=4 v275=3 v238=21 v239=23 v240=26 v241=23 v242=21 v243=26 v244=26 v275=4 v237=14 v238=31 v240=31 v241=37 v242=32 v236=3;482:v257=3 v257=2 v235=0 v275=1 v237=21 v238=9 v239=21 v240=14 v241=25 v242=9 v243=25 v244=14 v245=26 v246=9 v273=26 v274=14 v236=6 v275=2 v237=19 v238=16 v239=19 v240=17 v241=14 v242=16 v243=14 v244=18 v236=4 v275=3 v238=21 v239=23 v240=26 v241=23 v242=21 v243=26 v244=26 v275=4 v237=14 v238=31 v240=31 v241=37 v242=32 v236=3;497:v256=3 v256=2 v235=0 v275=1 v237=9 v238=10 v239=14 v240=10 v241=17 v242=10 v243=22 v244=10 v245=22 v246=11 v273=14 v274=11 v236=6;480:v256=3 v256=2 v235=0 v275=1 v237=9 v238=10 v239=14 v240=10 v241=17 v242=10 v243=22 v244=10 v245=22 v246=11 v273=14 v274=11 v236=6;499:v260=3 v260=2 v235=0 v275=1 v237=11 v238=23 v239=11 v240=19 v241=10 v242=19 v243=11 v244=18 v245=15 v246=19 v273=19 v274=17 v236=6;484:v260=3 v260=2 v235=0 v275=1 v237=11 v238=23 v239=11 v240=19 v241=10 v242=19 v243=11 v244=18 v245=15 v246=19 v273=19 v274=17 v236=6;500:v261=3 v261=2 v235=0 v275=1 v237=7 v238=13 v239=14 v240=10 v241=14 v242=14 v243=14 v244=15 v245=13 v246=15 v273=13 v274=19 v236=6;486:v261=3 v261=2 v235=0 v275=1 v237=7 v238=13 v239=14 v240=10 v241=14 v242=14 v243=14 v244=15 v245=13 v246=15 v273=13 v274=19 v236=6;501:v258=3 v258=2;488:v258=3 v258=2;502:v259=3 v259=2 s1363;490:v259=3 v259=2 s1363;504:v263=3 v263=2;494:v263=3 v263=2;505:v264=3 v264=2 v235=0 v275=1 v237=6 v238=14 v239=10 v240=14 v241=11 v242=11 v243=14 v244=11 v245=14 v246=12 v273=0 v274=0 v236=5 v275=2 v237=13 v238=23 v239=16 v240=18 v241=15 v242=21 v243=15 v244=18 v245=16 v246=21 v192=2 s577 v192=0 v276=26;496:v264=3 v264=2 v235=0 v275=1 v237=6 v238=14 v239=10 v240=14 v241=11 v242=11 v243=14 v244=11 v245=14 v246=12 v273=0 v274=0 v236=5 v275=2 v237=13 v238=23 v239=16 v240=18 v241=15 v242=21 v243=15 v244=18 v245=16 v246=21;474:s1363 v259=1 v259=0;489:s1363 v259=1 v259=0;479:v256=1 v256=0;470:v256=1 v256=0;481:v257=1 v257=0;469:v257=1 v257=0;543:v697=15;483:v260=1 v260=0;471:v260=1 v260=0;485:v261=1 v261=0;472:v261=1 v261=0;487:v258=1 v258=0;491:v262=1 v262=0;468:v262=1 v262=0;493:v263=1 v263=0;475:v263=1 v263=0;495:v264=1 v264=0;476:v264=1 v264=0 s557 v276=22;506:v316=0 v123=17;180:v161=0 s1000 v192=0 v552=8 s1304;528:s649;585:s649;513:s649;538:s649;65:s726;591:v321=0 v322=1 v322=0 v322=-1 v322=4 v322=2 s655 v322=3 s806 s828 s829 s1597 s1596 v619=25;541:v321=0 v322=1 v322=0 v322=-1 v322=4 v322=2 s655 v322=3;590:v321=0 v322=1 v322=0 v322=-1 v322=4 v322=2 s655 v322=3 s652 s1969 v62=0 v747=4 v747=5 v769=99;598:v321=0 v322=1 v322=0 v322=-1 v322=4 v322=2 s655 v322=3 s1986 v62=0 v747=4 v747=5 v769=99;597:v321=0 v322=1 v322=0 v322=-1 v322=4 v322=2 s655 v322=3;599:v321=0 v322=1 v322=0 v322=-1 v322=4 v322=2 s655 v322=3;557:v321=0 v322=1 v322=0 v322=-1 v322=4 v322=2 s655 v322=3;530:s649 v697=16 v697=14 v322=0 s1320 s1318 s1307 v619=26 v192=1 s1303 s1000 s1351 v571=0 v192=0 s2018 s2158 v675=1 v675=0 v747=1 v747=0 s1305;536:s649;628:s779 v339=28 s780 v339=37 v461=0 v458=0 v460=0 v454=0 v468=0 v452=0 v463=0 v451=0 v467=0 v456=0 v465=0 v453=0 v462=0 v455=0 v466=0 v457=0 v464=0 v459=0;567:s649;535:v49=535 s1068;569:s649;586:s649;604:s649;520:v322=0;238:v161=0;545:v161=0 v325=0;548:v326=0 s1980 v62=0 v747=4 v747=5 v769=99;563:v742=1 v742=2 v742=3 v742=0 v742=4 s1981 v62=0 v747=4 v747=5 v769=99;603:s649;562:s649;580:v161=0 v192=-1 s1582 v772=0 s1586 s2248 s1355 s2249 s1370 v813=0;601:s996;119:v322=0;694:v322=0 v322=-1 s829 v359=0;703:v322=0 v322=-1 s829 v359=0;704:v322=0 v322=-1 s829 v359=0;705:v322=0 v322=-1 s829 v359=0;858:s1574 s1605 v619=3 v619=14 v619=9 v619=15 s1678 v619=13 v619=16;594:v637=7 s1578 s1606 s1589 v637=8 s1958 v62=0 v747=4 v747=5 v769=99;877:s1997 v637=31;524:v322=0;523:v322=0;544:v322=0;600:s2003 s1979 v62=0 v747=4 v747=5 v769=99;84:v339=10;626:v339=17 v339=18 v339=19 v339=20 v339=21 v339=22 v339=23 v339=24;660:v382=0;651:s900 s867;662:s897;692:v62=4 v62=3 v62=2 v62=1 v371=6;693:v371=6 s1988 s1954 v62=0 v747=4 v747=5 v769=99;663:v370=1;666:s875 s876 v362=12 s2107;37:s1060 s2243;679:s910 v49=679 s649 s2103;678:s907;683:s910;682:s910;680:s910;696:s824 v380=4 v380=3 v361=8 v361=6 v361=4 v361=2;638:s866;664:s869;668:s868 v647=10 v647=9;686:s908;697:s874;699:s879 v381=3 v381=8;707:s1601 s1608 s1317 s1326 s1324 v645=5 v648=7 v647=10 v647=9;836:v787=1 v787=3 v787=2;727:s410;719:s410;718:s649;726:s649;742:s649;733:s956 v391=21 v408=0 v432=3 v432=2 v432=1 v434=2;734:v391=46;713:s649;715:s962 s963 v391=5 v391=45 s649 s410;736:v434=3;735:s410 s975 v391=47;732:v391=21 v408=0 s410 s964 s965;730:s921;754:v192=1 v192=0 s420;741:v391=55;757:v391=26;759:s974;769:v477=1 v477=2 v477=3 v477=0 v192=0 v475=61 v475=62 v475=63;770:v477=1 v477=2 v477=3 v477=0 v192=3 v475=85 v475=86 v161=0 v475=87 v192=2;771:v477=1 v477=0 v192=3 v161=0 v475=91 v475=92 v475=93 v192=2;775:v475=29;774:s2135;853:s2135 s290 s1080 v615=42 v615=43 v615=58;406:s2135;776:s1062;779:s1075 v478=0;781:v484=0 v485=0 v486=0 v487=0 v488=0 v489=0 v490=0 v491=0 v492=0 v493=0 v495=0 v494=0 v496=0 v498=0 v497=0 v499=0 v500=0 v501=0 v502=0 v503=0 v504=0 v505=0 v506=0 v507=0 v508=0 v509=0 v510=0 v511=0 v512=0 v513=0 v514=0 v515=0 v516=0 v517=0 v518=0 v519=0 v520=0 v521=0 v522=0 v523=0 s2157;778:s1075 v478=0 s2126;783:v513=1 v514=2 v515=3 v516=4 v517=1 v518=1 v519=2 v519=3 v519=4 v517=2 v518=2 v519=1 v517=3 v518=3 v517=4 v518=4 v513=0 v514=0 v515=0 v516=0 v517=0 v518=0 v519=0 s1229 v613=2;784:v485=0 v484=2 v487=1 v487=0 s1144 v484=3 v487=2 s1105 s1109 v485=2 v492=0 v493=0 v494=0 v495=0;812:v485=0 v484=2 v487=1 v487=0 s1144 v484=3 v487=2 s1105 s1109 v485=2 v492=0 v493=0 v494=0 v495=0;786:v486=0 v487=0 v488=0 v489=0 v490=0 s1110 v486=2 v475=113 v499=0 s1106 v492=2 v492=1 v492=0 s1128 s1129 s1130;811:v486=0 v487=0 v488=0 v489=0 v490=0 s1110 v486=2 v475=113 v499=0 s1106 v492=2 v492=1 v492=0 s1128 s1129 s1130;785:v613=5;788:s1143 s1144;790:v503=0 v502=0 v501=0 v504=0 s1157 s1166 v475=129 s1160 v503=2;813:s1227;787:s1106 v475=124 v475=125;796:v475=141 v475=140 v505=3;806:v520=9 v520=-1;810:v520=9;802:v520=-1;794:v475=138;844:v552=999 v618=5;817:v552=0 v553=0 v618=10 s1977 v62=0 v747=4 v747=5 v769=99;820:v618=13;814:s1594 v611=10 v192=1 v192=0 v552=2 v611=11;821:v618=17 s1394 v192=-1 s1395 v28=0 v161=0 v601=0 v608=0 v552=10;845:v618=19;461:v552=0 v611=15;822:v552=20;306:v192=1 s1303 s1000 s1351 v571=0 v192=0 s2018 s2158 v675=1 v675=0 v747=1 v747=0 s1305;825:v744=1 v577=0 v578=1 v579=2 v744=2 v578=2 v580=2 v581=2 v744=3 v582=0 v583=0 v584=0 v585=0;826:s1325 v739=2 s1370 s290 s1000 s1080 s1511 s1512 s1513 s1508 s1509 s1510 v562=14 v562=12 v586=14 v586=16 v586=12 s1331 v636=20 s1329 s1333 s1312 v613=12 v649=13 s1322 s1323 s1308 s1307 s1321 v649=14 s1330 v626=32 v192=0 s2052 s1340 s1339 v664=13 s1334 v664=11 v747=2 v769=0 v769=1001 v769=1020;827:s1370 s1320 v697=18 v31=0 v33=0 v29=-1 v602=-1 s1345 s1395 v29=0 s1348 v558=0 s1347 v601=0 v602=0 v603=0 s1400 s1397 s1399 s789 v161=0 v62=250 s1587 v192=-1 s1582 s1396 s2204 v28=0 s1398 v726=2 s1965 v62=0 v747=4 v747=5 v769=99;893:s1320 v697=18 v697=25 v192=1 v192=0 v697=26;828:v31=0 v33=0 s1370 v29=-1 v602=-1 s1345 s1395 v29=0 s1348 v558=0 s1347 v601=0 v602=0 v603=0 s1400 s1397 s1399;829:v772=0 s2326 s1355 s1586 s1583 s1370 v775=0 v161=0 v192=-1 s1582 v726=2;842:v772=0 s1586 s1584 s1585 s1355 s1392 s1370 v777=0 v161=0;832:s1996 s1970 s2007 v62=0 v747=4 v747=5 v769=99;840:s410 s1991 s1961 v62=0 v747=4 v747=5 v769=99;850:s1652 s1653 v649=5 v649=6 v649=9 v649=13 s1322 s1323 s1308 s1307 s1321 v649=14 s649 s1765;849:v613=10 s410;883:s649;851:s1653;854:v615=16 v615=28 v615=20 v615=25 v615=33 v615=10 v615=13 v615=14 v615=30 v615=31 v615=27 v615=41 s290 s1080 v615=42 v615=43 v615=52 v615=56;857:v622=13 s1581 s1308 s1616;860:v626=31 s649;862:v632=7;868:s1582;867:s2002 v627=5 s1679 v192=1 v192=0 v627=7 v627=9 v627=11 s1367 s1680 v627=13 s290 s1080 v161=0 v627=16 s1338 s1307 s1316 s1964 v62=0 v747=4 v747=5 v769=99;870:v631=4 s1693 s1692 v631=6;871:v628=2 v628=8;872:v631=5 s1693;878:v49=878 s1776 s1772 s1775;879:v161=0 v49=879 s1772 s1780;881:v647=2 v647=4;132:s457 s525 v192=0 s1000 v77=3 v652=9 s85;885:s1652;888:s1809 s1857 v192=0 s1000 s2052 s1340 s1339 v664=13 s1334 v664=11;890:v676=-2 v677=-2 v678=-2 v679=-2 v680=-2 v681=0 v682=0 v683=0 v684=0 v685=0 v686=2 v687=2 v688=2 v689=2 v690=2 v651=5 v651=7;891:v676=-2 v677=-2 v678=-2 v679=-2 v680=-2 v681=0 v682=0 v683=0 v684=0 v685=0 v686=2 v687=2 v688=2 v689=2 v690=2 v651=5 v651=7;222:v651=15 s1080 s2092 v675=1 v675=0;894:v161=0 v697=2 v697=9 v62=0 v675=1 v697=12 v675=0;339:v697=13 s1877;895:s2006 s1983 v62=0 v747=4 v747=5 v769=99;532:s1955 v62=0 v747=4 v747=5 v769=99;874:s1956 v62=0 v747=4 v747=5 v769=99;164:s1957 v62=0 v747=4 v747=5 v769=99;127:s1959 v62=0 v747=4 v747=5 v769=99;876:s1985 v62=0 v747=4 v747=5 v769=99;588:s1978 v62=0 v747=4 v747=5 v769=99;517:s1978 v62=0 v747=4 v747=5 v769=99;900:v766=2 v769=1000 s2093 v751=2 v760=2 v763=2 v758=2 v753=2 v762=2 v756=2 v759=2 v752=2 v757=2 v754=2 v755=2 v761=2;902:v48=13 v49=902 v773=4 v773=5"

# variables that decide which page an event is on
RH_CONDVAR_DATA = "11,12,26,29,31,33,43,50,52,54,56,59,62,65,66,73,74,75,77,78,79,80,82,91,92,94,95,96,97,98,99,100,101,102,103,104,105,107,108,109,110,111,112,113,114,115,118,119,120,121,123,124,125,126,127,128,129,131,132,134,135,136,137,138,139,140,144,145,146,147,148,149,150,152,154,155,156,157,159,160,162,163,164,165,166,167,168,169,170,171,172,173,176,181,182,183,184,185,186,187,188,189,190,193,194,195,196,197,198,199,200,201,202,203,204,205,206,207,208,209,210,212,213,214,215,222,223,224,225,226,231,256,257,258,259,260,261,262,263,264,276,278,319,321,322,323,325,326,329,332,337,338,339,341,342,343,349,350,351,352,353,354,355,356,357,358,359,360,362,363,364,365,366,367,368,369,370,371,372,373,374,375,376,377,380,381,382,383,391,393,396,397,398,399,400,401,402,403,408,409,410,411,412,413,414,415,416,417,418,419,420,421,422,423,424,425,426,427,428,429,430,431,432,433,435,436,438,440,449,450,451,452,453,454,455,456,457,458,459,460,461,462,463,464,465,466,467,468,470,471,472,475,476,477,478,480,505,513,514,515,516,517,518,519,520,521,522,523,546,547,549,550,551,552,553,554,555,556,557,558,561,562,568,569,570,572,576,577,578,579,580,581,582,583,584,585,586,588,589,596,597,598,599,611,612,613,615,616,617,618,619,620,621,622,623,626,627,628,631,632,633,634,635,636,637,638,639,640,641,642,643,644,645,646,647,648,649,650,651,652,653,654,655,656,657,658,659,660,663,664,665,670,676,677,678,679,680,681,682,683,684,685,686,687,688,689,690,692,694,695,696,697,699,721,722,725,726,739,740,741,742,743,744,748,749,750,751,752,753,754,755,756,757,758,759,760,761,762,763,766,769,773,778,781,795,796"

# values / switches that change which way you can go: vars|switches
RH_ROUTEVAR_DATA = "1,2,11,12,26,29,31,33,43,47,48,49,50,52,54,55,56,59,61,62,65,66,68,73,74,75,77,78,79,80,82,91,92,93,94,95,96,97,98,99,100,102,103,104,105,107,108,109,110,111,112,113,114,115,117,118,119,120,121,123,124,125,126,127,128,129,131,132,134,135,136,137,138,140,145,146,147,148,149,150,151,152,154,155,156,157,159,160,162,163,164,165,166,167,168,169,170,171,172,173,176,181,183,184,185,186,187,193,194,195,196,197,198,199,200,201,202,203,204,205,206,207,208,209,210,212,213,214,215,222,223,224,225,226,231,256,257,258,259,260,261,262,263,264,276,278,297,314,316,319,321,322,323,325,326,332,338,339,341,342,343,349,350,351,352,353,354,356,357,358,359,360,361,362,363,364,365,366,367,368,369,370,371,372,373,374,375,376,377,379,380,381,382,383,391,393,396,397,398,399,400,401,402,403,408,409,410,411,412,413,414,415,416,417,418,419,420,421,422,423,424,425,426,427,428,429,430,431,432,433,434,436,438,440,449,450,451,452,453,454,455,456,457,458,459,460,461,462,463,464,465,466,467,468,470,471,475,476,477,478,480,484,485,486,487,492,503,505,513,514,515,516,517,518,519,520,521,522,523,549,550,551,552,553,554,555,556,557,558,560,561,562,563,564,568,569,570,571,572,573,576,577,578,579,580,581,582,583,584,585,586,588,589,593,596,597,598,599,600,611,612,613,615,616,617,618,619,620,621,622,623,626,627,628,631,632,633,634,635,636,637,638,639,640,641,642,643,644,645,646,647,648,649,650,651,652,653,654,655,656,657,658,660,663,664,665,670,675,676,677,678,679,680,681,686,687,688,689,690,692,694,695,696,697,699,721,722,725,726,739,740,741,742,743,744,748,749,751,752,753,754,755,756,757,758,759,760,761,762,763,766,769,770,773,778,787,795,796,812|2,4,5,9,10,11,12,17,27,28,30,31,32,33,36,37,39,40,41,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,66,70,71,74,75,76,77,78,80,81,82,83,84,85,86,88,91,93,96,97,98,99,100,101,102,103,104,105,106,107,109,110,111,112,113,114,115,116,120,121,122,126,127,128,130,131,132,133,134,135,136,139,140,141,142,143,144,145,146,147,148,149,150,152,153,154,155,157,160,161,162,163,164,165,166,167,168,170,171,173,174,175,176,177,178,179,180,181,183,184,185,186,187,188,189,190,191,192,193,194,195,196,197,200,201,202,203,205,207,208,209,210,212,215,216,217,219,220,223,224,225,226,227,228,229,230,231,232,233,234,235,236,237,238,239,242,243,244,245,246,247,248,250,252,253,254,255,256,257,258,259,260,264,265,266,267,268,269,270,272,273,276,277,278,279,280,283,284,285,287,288,289,291,292,294,295,296,299,300,301,302,303,304,305,306,307,308,309,310,311,312,313,314,315,316,317,318,319,320,321,322,323,327,328,339,340,341,342,343,344,367,368,369,370,371,372,373,374,375,376,377,378,379,380,381,382,383,384,385,386,387,388,389,390,391,393,401,402,404,408,409,410,411,412,413,414,417,418,422,423,426,427,428,429,430,431,432,435,436,439,440,441,442,443,444,445,446,447,448,449,450,451,452,453,454,455,456,460,462,465,466,467,468,469,470,471,472,473,474,475,476,477,479,482,483,484,486,487,488,489,492,493,494,495,496,497,498,499,500,501,502,503,505,506,507,508,516,517,518,519,520,521,522,523,526,527,528,530,531,532,533,534,535,536,537,538,539,541,542,543,544,546,547,548,549,550,551,552,553,554,555,556,557,558,559,560,561,562,563,565,569,570,571,573,574,575,576,577,578,579,580,581,583,584,585,586,587,588,589,590,591,593,594,595,596,597,598,599,600,601,602,603,604,606,607,608,609,610,611,612,613,614,615,617,618,619,620,621,622,623,624,625,626,627,628,629,630,631,632,633,634,635,636,638,639,647,648,651,652,653,654,655,656,657,658,659,661,662,663,664,665,666,667,668,669,670,671,672,673,674,675,676,677,678,679,681,683,685,686,687,688,689,692,693,708,709,710,711,713,714,715,716,717,718,719,720,721,722,723,724,725,726,727,728,730,733,734,735,736,737,738,739,740,741,742,743,744,745,750,751,752,757,758,759,760,769,770,771,772,773,774,775,776,777,779,780,781,782,784,791,792,793,794,795,796,798,799,800,801,802,803,804,805,806,807,808,809,810,811,812,813,814,816,817,818,819,820,821,822,823,826,827,828,829,830,831,832,833,834,835,836,837,838,840,841,842,843,844,845,846,847,848,849,852,853,854,855,856,857,858,859,860,873,874,875,877,878,879,885,886,887,888,889,890,891,892,893,894,895,896,897,898,899,900,905,907,908,909,910,913,914,915,916,917,918,919,920,921,922,924,925,926,927,928,929,930,931,935,936,937,940,941,942,943,945,946,947,948,949,953,956,957,958,959,960,961,966,967,968,969,970,971,972,973,975,976,977,978,979,980,981,983,984,985,987,988,989,990,996,998,999,1022,1023,1024,1026,1027,1028,1029,1030,1031,1032,1033,1034,1035,1036,1037,1039,1040,1042,1043,1044,1045,1048,1049,1050,1051,1052,1054,1055,1056,1057,1059,1060,1062,1063,1064,1065,1066,1067,1068,1069,1070,1071,1072,1073,1074,1075,1077,1078,1082,1084,1086,1088,1098,1099,1101,1102,1103,1104,1105,1107,1108,1109,1110,1111,1112,1113,1114,1115,1116,1117,1118,1119,1120,1121,1122,1123,1124,1125,1126,1127,1128,1129,1130,1131,1132,1133,1134,1135,1136,1137,1138,1139,1140,1141,1142,1143,1144,1145,1146,1147,1148,1152,1153,1154,1155,1156,1158,1159,1160,1161,1162,1163,1164,1165,1166,1168,1169,1170,1171,1172,1173,1174,1175,1176,1177,1178,1179,1183,1184,1191,1195,1201,1202,1203,1204,1205,1206,1207,1208,1209,1210,1211,1212,1214,1215,1216,1217,1218,1219,1220,1221,1222,1223,1224,1225,1226,1227,1228,1229,1230,1231,1232,1233,1234,1235,1236,1237,1238,1239,1240,1241,1242,1243,1244,1245,1246,1247,1248,1249,1250,1251,1252,1253,1257,1258,1259,1261,1262,1263,1264,1265,1266,1267,1268,1269,1270,1271,1272,1273,1274,1275,1276,1277,1278,1279,1280,1281,1282,1283,1284,1286,1291,1292,1293,1294,1304,1305,1307,1308,1309,1310,1311,1312,1313,1314,1315,1316,1317,1318,1319,1320,1321,1322,1323,1324,1329,1334,1335,1340,1345,1346,1347,1348,1349,1350,1352,1354,1355,1358,1359,1360,1364,1366,1367,1370,1371,1372,1373,1374,1375,1376,1379,1380,1381,1382,1383,1384,1392,1395,1396,1397,1398,1399,1401,1403,1404,1405,1406,1408,1409,1412,1413,1416,1417,1420,1421,1423,1424,1426,1427,1428,1429,1430,1432,1433,1436,1437,1440,1441,1443,1444,1446,1447,1449,1450,1451,1452,1453,1454,1458,1459,1460,1461,1463,1466,1467,1468,1469,1471,1472,1473,1474,1475,1477,1479,1481,1482,1483,1484,1486,1489,1493,1494,1495,1498,1501,1505,1513,1514,1517,1518,1519,1520,1521,1522,1523,1524,1525,1526,1530,1531,1532,1533,1535,1536,1537,1538,1539,1540,1541,1542,1543,1544,1545,1546,1547,1548,1549,1550,1551,1554,1556,1557,1558,1559,1560,1561,1562,1563,1564,1565,1566,1567,1568,1569,1570,1571,1573,1582,1583,1584,1585,1586,1587,1612,1613,1614,1648,1649,1650,1651,1652,1661,1662,1663,1664,1665,1666,1667,1668,1669,1670,1671,1672,1675,1676,1677,1678,1679,1680,1681,1683,1684,1685,1686,1687,1688,1689,1690,1692,1693,1694,1695,1696,1697,1698,1699,1700,1701,1702,1703,1704,1705,1706,1708,1709,1710,1711,1712,1713,1714,1715,1716,1717,1718,1719,1720,1726,1727,1728,1729,1730,1731,1732,1733,1734,1735,1736,1737,1738,1739,1740,1741,1742,1743,1744,1745,1746,1747,1748,1749,1750,1751,1752,1753,1754,1755,1756,1757,1759,1760,1761,1763,1765,1766,1767,1769,1770,1771,1772,1773,1774,1775,1776,1777,1778,1779,1780,1781,1782,1783,1784,1785,1786,1787,1788,1789,1790,1791,1792,1793,1794,1795,1796,1797,1798,1799,1800,1801,1802,1803,1804,1805,1806,1807,1808,1809,1810,1811,1812,1813,1814,1815,1816,1817,1818,1819,1820,1821,1822,1823,1824,1825,1826,1828,1829,1830,1831,1832,1833,1834,1835,1836,1837,1838,1839,1840,1841,1842,1843,1844,1845,1846,1847,1848,1849,1850,1852,1853,1854,1855,1856,1857,1858,1859,1860,1861,1862,1863,1865,1867,1868,1871,1872,1873,1874,1876,1877,1879,1880,1881,1882,1883,1884,1885,1886,1887,1888,1889,1890,1891,1892,1893,1895,1896,1897,1898,1899,1900,1901,1902,1903,1904,1905,1906,1907,1908,1909,1910,1911,1912,1913,1914,1915,1916,1917,1918,1919,1920,1921,1922,1923,1924,1925,1926,1927,1928,1929,1930,1931,1932,1933,1934,1935,1936,1937,1938,1939,1941,1945,1946,1948,1949,1952,1953,1954,1955,1956,1957,1958,1959,1960,1961,1962,1963,1964,1965,1966,1967,1968,1969,1970,1971,1972,1973,1974,1975,1977,1978,1979,1980,1981,1982,1983,1984,1985,1986,1987,1989,1993,1995,1997,1999,2000,2001,2002,2007,2008,2010,2011,2012,2013,2014,2015,2016,2019,2020,2021,2024,2025,2026,2027,2028,2029,2030,2031,2032,2033,2034,2035,2036,2037,2040,2041,2042,2043,2045,2046,2047,2048,2049,2050,2052,2053,2056,2057,2058,2059,2060,2061,2062,2063,2064,2065,2066,2067,2068,2069,2074,2075,2078,2080,2086,2089,2090,2091,2092,2093,2094,2095,2099,2100,2101,2105,2106,2107,2108,2109,2110,2116,2117,2124,2125,2126,2127,2128,2129,2131,2139,2140,2141,2142,2143,2144,2145,2146,2147,2148,2154,2157,2162,2165,2166,2167,2172,2173,2174,2175,2176,2178,2182,2183,2185,2186,2187,2189,2190,2193,2196,2197,2198,2199,2201,2202,2205,2206,2208,2209,2211,2212,2213,2214,2215,2218,2226,2227,2228,2231,2232,2237,2242,2243,2245,2248,2311,2312,2321,2322,2324,2326,2328,2329,2332,2333,2334,2337,2338"
