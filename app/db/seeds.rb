require "faker"

puts "Seeding players..."
usernames = %w[ash_ketchum misty_rocks brock_solid gary_oak may_petal
               dawn_diamond serena_grace iris_dragon n_natural lillie_z]
players = usernames.map do |username|
  Player.find_or_create_by!(username: username)
end

puts "Seeding characters..."
elements = Character.elements.keys
characters = []
30.times do
  player  = players.sample
  level   = rand(1..10)
  max_hp  = 100 + (level - 1) * 20
  attack  = 10  + (level - 1) * 3
  defense =  5  + (level - 1) * 2
  speed   =  5  + (level - 1) * 2

  character = player.characters.create!(
    name:       Faker::Games::Pokemon.unique.name,
    element:    elements.sample,
    level:      level,
    max_hp:     max_hp,
    current_hp: max_hp,
    attack:     attack,
    defense:    defense,
    speed:      speed
  )
  characters << character
rescue ActiveRecord::RecordInvalid => e
  puts "  skipped: #{e.message}"
end

Faker::Games::Pokemon.unique.clear

puts "Seeding battles..."
20.times do
  attacker, defender = characters.sample(2)
  next if attacker.nil? || defender.nil? || attacker == defender

  battle = Battle.create!(
    attacker:        attacker,
    defender:        defender,
    attacker_player: attacker.player,
    status:          :in_progress
  )

  rand(2..5).times do
    BattleEngine.execute_turn(battle)
    break if battle.reload.completed?
  end
end

puts "Done. #{Player.count} players, #{Character.count} characters, #{Battle.count} battles."
