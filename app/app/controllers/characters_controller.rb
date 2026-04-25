class CharactersController < ApplicationController
  before_action :authenticate_player!, only: [:create, :heal]
  before_action :set_character,        only: [:show, :heal]

  HEAL_COOLDOWN = 60.seconds

  def create
    character = current_player.characters.create!(
      name:    params.require(:name),
      element: params.require(:element)
    )
    render json: serialize(character), status: :created
  end

  def show
    render json: serialize(@character).merge(
      battles: @character.battles_history.limit(20).map { |b| battle_summary(b) }
    )
  end

  def heal
    unless @character.player_id == current_player.id
      return render json: { error: "not your character" }, status: :forbidden
    end

    # Per spec: cooldown tracked via updated_at. Imperfect (any update
    # touches updated_at), kept as-is for debug practice.
    if @character.updated_at > HEAL_COOLDOWN.ago
      retry_after = (@character.updated_at + HEAL_COOLDOWN - Time.current).to_i
      response.set_header("Retry-After", retry_after)
      return render json: { error: "heal cooldown active",
                            retry_after_seconds: retry_after },
                    status: :too_many_requests
    end

    @character.update!(current_hp: @character.max_hp, is_alive: true)
    render json: serialize(@character)
  end

  private

  def set_character
    @character = Character.find(params[:id])
  end

  def serialize(c)
    {
      id: c.id, name: c.name, element: c.element,
      level: c.level, experience: c.experience,
      current_hp: c.current_hp, max_hp: c.max_hp,
      attack: c.attack, defense: c.defense, speed: c.speed,
      wins: c.wins, losses: c.losses, is_alive: c.is_alive,
      player_id: c.player_id
    }
  end

  def battle_summary(b)
    { id: b.id, status: b.status, winner_id: b.winner_id, turn_count: b.turn_count }
  end
end
