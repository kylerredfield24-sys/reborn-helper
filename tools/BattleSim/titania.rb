# Plays Titania's gym battle with the game's real engine + AI. Player side follows POLICY:
module PBDebug; def self.open(*a) end; def self.log(*a) end; def self.disableLog(*a) end; def self.logonerr; yield end; def self.flush; end; def self.method_missing(*a) nil end; end
$INTERNAL = false
#   "helper" = what Reborn Helper's battle panel says, "dmg" = always the strongest-damage move.
POLICY = ENV["POLICY"] || "helper"; SEED = (ENV["SEED"] || 1).to_i; VERB = ENV["V"] == "1"
srand(SEED)
$game_switches = Game_Switches.new; $game_variables = Game_Variables.new
$game_variables[:Forced_Field_Effect] = (ENV["FIELD"] || "FAIRYTALE").to_sym rescue nil
$PokemonGlobal = PokemonGlobalMetadata.new; $PokemonTemp = PokemonTemp.new
$Settings = PokemonOptions.new rescue nil
$game_temp = Game_Temp.new rescue nil
$game_screen = BH.new; $game_map = BH.new; def $game_map.map_id; (ENV["MAP"] || 702).to_i end; def $game_map.terrain_tag(*a) 0 end
$game_player = BH.new; def $game_player.x; 0 end; def $game_player.y; 0 end; $game_system = BH.new; $scene = BH.new
$Trainer = PokeBattle_Trainer.new("Kyler", :PkMnTRAINER_Male)
$Trainer.badges = [true] * 18 rescue nil
$PokemonBag = PokemonBag.new
$PokemonStorage = (PokemonStorage.new rescue BH.new)
{ :FULLRESTORE => 30, :REVIVE => 15, :HYPERPOTION => 39, :ULTRAPOTION => 51 }.each { |k, v| $PokemonBag.pbStoreItem(k, v) }
TEAM = [
  [:METAGROSS, :METALCOAT, [:MAGNETRISE, :METEORMASH, :HAMMERARM, :METALCLAW], :CLEARBODY],
  [:MAGNEZONE, :METALCOAT, [:FLASHCANNON, :DISCHARGE, :MAGNETRISE, :LIGHTSCREEN], :ANALYTIC],
  [:MILOTIC, :MYSTICWATER, [:HYDROPUMP, :TACKLE, :RECOVER, :AQUARING], :CUTECHARM],
  [:RHYPERIOR, :WIDELENS, [:ROCKWRECKER, :HAMMERARM, :STONEEDGE, :EARTHQUAKE], :SOLIDROCK],
  [:PORYGON2, :EVIOLITE, [:TRICKROOM, :RECOVER, :HYPERBEAM, :SIGNALBEAM], :DOWNLOAD],
  [:BRONZONG, :TWISTEDSPOON, [:IRONDEFENSE, :EXTRASENSORY, :HEAVYSLAM, :GYROBALL], :LEVITATE],
  [:BLAZIKEN, :CHARCOAL, [:FLAREBLITZ, :HIJUMPKICK, :BULKUP, :BLAZEKICK], :SPEEDBOOST],
]
# TEAM env: "METAGROSS,BLAZIKEN:FLAREBLITZ/HIGHJUMPKICK/PROTECT/SWORDSDANCE@LIFEORB,..." (no moves = keep known/level-up)
specs = ENV["TEAM"] ? ENV["TEAM"].split(",") : TEAM.map { |t| t[0].to_s }
party = specs.map do |spec|
  spec, itm = spec.split("@")
  sp, mvs = spec.split(":")
  sp = sp.to_sym
  known = TEAM.find { |t| t[0] == sp }
  pk = PokeBattle_Pokemon.new(sp, 85, $Trainer)
  it = itm ? itm.to_sym : (known ? known[1] : nil)
  pk.setItem(it) if it
  mv = mvs ? mvs.split("/").map(&:to_sym) : (known ? known[2] : nil)
  pk.instance_variable_set(:@moves, mv.map { |m| PBMove.new(m) }) if mv
  ab = known && known[3]
  (pk.ability = ab rescue pk.instance_variable_set(:@ability, ab)) if ab
  pk.calcStats; pk.hp = pk.totalhp
  pk
end
$Trainer.party = party
STDERR.puts "TEAM " + party.map { |p| "#{p.name}[#{p.moves.map { |m| m && m.move }.compact.join('/')}]@#{p.item}" }.join(" ") if ENV["SHOWTEAM"]
$tr = trainer = pbLoadTrainer(:TITANIA1, "Titania", 0)
$LOG = []
def lg(s) $LOG << s; puts s if VERB end
class SimScene
  def initialize; end
  def method_missing(*a) nil end
  def pbStartBattle(b) @battle = b end
  def pbChooseEnemyCommand; @battle.ai.processAIturn end
  def pbChooseNewEnemy(index, party) $ai_log_data[index].reset(@battle.battlers[index]); @battle.ai.pbDefaultChooseNewEnemy(index, party) end
  def pbDisplayMessage(m, *a) lg("  " + m.to_s.gsub(/\\\w\[?\d*\]?/, "")) end
  def pbDisplayPausedMessage(m, *a) pbDisplayMessage(m) end
  def pbDisplayConfirmMessage(*a) false end
  def pbShowCommands(*a) 0 end
  def pbForgetMove(*a) -1 end
  def pbFightMenu(i) $pick[:move] || 0 end
  def pbItemMenu(i) [$pick[:item], $pick[:itarget]] end
  def pbSwitch(index, lax, cancancel)
    party = @battle.pbParty(index)
    if lax   # replacing a fainted one
      $pick = Policy.send_in(@battle, index) ; lg("  >> send #{party[$pick[:switch]].name}")
      return $pick[:switch]
    end
    return $pick[:switch] || -1
  end
  def pbCommandMenu(i)
    $pick = Policy.choose(@battle, i)
    return $pick[:cmd]
  end
end
module Policy
  def self.mv_index(b, name) b.moves.index { |m| m && m.move && RH.mname(m.move) == name } end
  def self.alive_idx(battle, i, name = nil)
    pt = battle.pbParty(i)
    pt.each_with_index.find { |p, j| p && p.hp > 0 && !battle.battlers.any? { |x| x && x.pokemon.equal?(p) } && (!name || p.name == name) }&.last
  end
  def self.choose(battle, i)
    b = battle.battlers[i]
    a = RH.analyze(battle, i)
    best = a && a[:best] ? mv_index(b, a[:best][1][:name]) : 0
    if POLICY == "dmg"
      lg("T#{battle.turncount} #{b.name} #{b.hp}/#{b.totalhp} vs #{a[:foes][0].name} #{a[:foes][0].hp}/#{a[:foes][0].totalhp}: dmg -> #{b.moves[best || 0].move}")
      return { :cmd => 0, :move => best || 0 }
    end
    adv = (RH.advice(battle, a) rescue ["?", nil])[0].to_s
    if ENV["DBG"]
      lg("   rows: " + a[:rows].map { |r| "#{r[:name]}=#{r[:vs].map { |f, lo, hi| "#{lo}-#{hi}" }.join}" }.join(" ") + " danger=#{a[:danger] && [a[:danger][0], a[:danger][3].move]} race=#{(RH.race_advice(battle, a) rescue $!).inspect[0,80]} strat=#{(RH.strategy(battle, a) rescue $!).inspect[0,80]} smart=#{(RH.smart_advice(battle, a) rescue $!).inspect[0,60]}")
    end
    lg("T#{battle.turncount} #{b.name} #{b.hp}/#{b.totalhp} vs #{a[:foes][0].name} #{a[:foes][0].hp}/#{a[:foes][0].totalhp}: #{adv}")
    if adv =~ /\A(?:Attack(?: now)?:|Use|Set)\s+(.+?)(?:\s+on\s|\s+-|\s+\(|,|\z)/
      nm = $1
      if (mi = mv_index(b, nm)) then return { :cmd => 0, :move => mi } end
      it = $cache.items.keys.find { |k| RH.iname(k) == nm }
      if it && $PokemonBag.pbQuantity(it) > 0
        tgt = adv[/ on (\w+)/, 1]
        ti = tgt ? battle.pbParty(i).index { |p| p && p.name == tgt } : (battle.pbParty(i).index { |p| p.equal?(b.pokemon) })
        return { :cmd => 1, :item => it, :itarget => ti }
      end
    end
    if adv =~ /\AHeal: (.+)\z/
      it = $cache.items.keys.find { |k| RH.iname(k) == $1 }
      return { :cmd => 1, :item => it, :itarget => battle.pbParty(i).index { |p| p.equal?(b.pokemon) } } if it
    end
    if adv =~ /Switch to (\w+)/ && (si = alive_idx(battle, i, $1))
      return { :cmd => 2, :switch => si }
    end
    return { :cmd => 0, :move => best || 0 }
  end
  def self.send_in(battle, i)
    pt = battle.pbParty(i)
    list = (RH.rank_switches(battle, i, true) rescue [])
    m = (RH.boss_send(battle, list) rescue nil) || (list.find { |o| !o[:faints] } || list.first || {})[:mon]
    si = m ? pt.index { |p| p.equal?(m) } : alive_idx(battle, i)
    { :switch => si || alive_idx(battle, i) }
  end
end
scene = SimScene.new
battle = PokeBattle_Battle.new(scene, $Trainer.party, trainer[2], $Trainer, trainer[0])
battle.items = trainer[1]
battle.instance_variable_set(:@battleRandom, Random.new(SEED))
battle.internalbattle = true
battle.controlPlayer = true if POLICY == "ai"
battle.disableExpGain = true rescue nil
class PokeBattle_Battle; def noExp?(*a) true end; end
$rh_boss = nil
dec = battle.pbStartBattle(false)
left = $Trainer.party.count { |p| p.hp > 0 }
foel = trainer[2].count { |p| p.hp > 0 }
puts "RESULT policy=#{POLICY} seed=#{SEED} decision=#{dec} (1=win) turns=#{battle.turncount} mine_left=#{left} foe_left=#{foel}"
