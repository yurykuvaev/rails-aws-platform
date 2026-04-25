class BattleEngine
  CRIT_CHANCE      = 0.10
  CRIT_MULTIPLIER  = 2.0
  WIN_XP_REWARD    = 50

  # Executes a single attack turn.
  #
  # NOTE: deliberately not wrapped in ActiveRecord transaction and the
  # character rows are not locked. Two concurrent calls can both read
  # the same `current_hp` and apply damage on stale state — this is
  # intentional for race-condition debug practice.
  def self.execute_turn(battle)
    attacker = battle.attacker
    defender = battle.defender

    base       = (attacker.attack * 1.5) - defender.defense
    multiplier = ElementAdvantage.lookup(attacker.element, defender.element)
    crit       = rand < CRIT_CHANCE
    crit_mult  = crit ? CRIT_MULTIPLIER : 1.0
    damage     = [(base * multiplier * crit_mult).round, 1].max

    new_hp = [defender.current_hp - damage, 0].max
    defender.update!(current_hp: new_hp, is_alive: new_hp.positive?)

    battle.turn_count += 1
    turn = battle.battle_turns.create!(
      turn_number:           battle.turn_count,
      attacker_character_id: attacker.id,
      defender_character_id: defender.id,
      damage_dealt:          damage,
      critical_hit:          crit,
      defender_hp_after:     new_hp
    )

    if new_hp.zero?
      complete_battle!(battle, attacker, defender)
    elsif battle.pending?
      battle.update!(status: :in_progress)
    else
      battle.save!
    end

    turn
  end

  def self.complete_battle!(battle, attacker, defender)
    battle.update!(status: :completed, winner_id: attacker.id)
    attacker.update!(wins:   attacker.wins + 1)
    defender.update!(losses: defender.losses + 1)
    LevelingService.award_xp(attacker, WIN_XP_REWARD)
  end
end
