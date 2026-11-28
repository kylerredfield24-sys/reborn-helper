src = File.read("#{__dir__}/titania.rb".sub("withrh", "")) rescue File.read(ENV["SIMDIR"] + "/titania.rb")
src = src.sub("dec = battle.pbStartBattle(false)", <<'X')
class SimScene; def pbCommandMenu(i)
  b = @battle.battlers[i]; f = @battle.battlers[1]
  f.moves.each do |m|
    lo, hi = RH.dmg(@battle, f, b, m)
    real = (0...30).map { m.pbCalcDamage(f, b) rescue -1 }
    puts "#{f.name} #{m.move} -> #{b.name}: helper #{lo}-#{hi}  engine #{real.min}-#{real.max}"
  end
  b.moves.each do |m|
    lo, hi = RH.dmg(@battle, b, f, m)
    real = (0...30).map { m.pbCalcDamage(b, f) rescue -1 }
    puts "#{b.name} #{m.move} -> #{f.name}: helper #{lo}-#{hi}  engine #{real.min}-#{real.max}"
  end
  exit
end; end
dec = battle.pbStartBattle(false)
X
eval(src, TOPLEVEL_BINDING, "t")
