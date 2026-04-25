class LevelingService
  HP_PER_LEVEL      = 20
  ATTACK_PER_LEVEL  = 3
  DEFENSE_PER_LEVEL = 2
  SPEED_PER_LEVEL   = 2

  def self.xp_for_next_level(level)
    level * 100
  end

  def self.award_xp(character, amount)
    character.experience += amount

    while character.experience >= xp_for_next_level(character.level)
      character.experience -= xp_for_next_level(character.level)
      level_up!(character)
    end

    character.save!
    character
  end

  def self.level_up!(character)
    character.level      += 1
    character.max_hp     += HP_PER_LEVEL
    character.attack     += ATTACK_PER_LEVEL
    character.defense    += DEFENSE_PER_LEVEL
    character.speed      += SPEED_PER_LEVEL
    character.current_hp  = character.max_hp
    character.is_alive    = true
  end
end
