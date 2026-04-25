class BattlesController < ApplicationController
  before_action :authenticate_player!, only: [:create, :attack]
  before_action :set_battle,           only: [:show, :attack]

  def create
    attacker = Character.find(params.require(:attacker_character_id))
    defender = Character.find(params.require(:defender_character_id))

    unless attacker.player_id == current_player.id
      return render json: { error: "attacker is not your character" }, status: :forbidden
    end

    if defender.player_id == current_player.id
      return render json: { error: "defender must belong to a different player" },
                    status: :unprocessable_entity
    end

    battle = Battle.create!(
      attacker:        attacker,
      defender:        defender,
      attacker_player: current_player,
      status:          :pending
    )

    render json: serialize(battle), status: :created
  end

  def show
    render json: serialize(@battle).merge(
      turns: @battle.battle_turns.map { |t| turn_summary(t) }
    )
  end

  def attack
    unless @battle.attacker.player_id == current_player.id
      return render json: { error: "you do not own the attacker" }, status: :forbidden
    end

    if @battle.completed?
      return render json: { error: "battle already finished" }, status: :unprocessable_entity
    end

    # Per spec: deliberately NOT idempotent. Two near-simultaneous POSTs
    # both execute a turn, exposing the race condition in BattleEngine.
    turn = BattleEngine.execute_turn(@battle)
    @battle.reload

    render json: {
      battle:        serialize(@battle),
      turn:          turn_summary(turn),
      defender_hp:   @battle.defender.reload.current_hp,
      battle_status: @battle.status,
      winner_id:     @battle.winner_id
    }
  end

  private

  def set_battle
    @battle = Battle.find(params[:id])
  end

  def serialize(b)
    {
      id: b.id, status: b.status, turn_count: b.turn_count,
      attacker_id: b.attacker_id, defender_id: b.defender_id,
      attacker_player_id: b.attacker_player_id, winner_id: b.winner_id
    }
  end

  def turn_summary(t)
    {
      turn_number:  t.turn_number,
      attacker_id:  t.attacker_character_id,
      defender_id:  t.defender_character_id,
      damage:       t.damage_dealt,
      critical_hit: t.critical_hit,
      defender_hp:  t.defender_hp_after
    }
  end
end
