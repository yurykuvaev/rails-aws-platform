class PlayersController < ApplicationController
  before_action :authenticate_player!, only: [:me]

  def create
    player = Player.create!(username: params.require(:username))
    render json: { id: player.id, username: player.username, api_token: player.api_token },
           status: :created
  end

  def me
    render json: {
      id:         current_player.id,
      username:   current_player.username,
      characters: current_player.characters.map { |c| character_summary(c) }
    }
  end

  private

  def character_summary(c)
    {
      id: c.id, name: c.name, element: c.element,
      level: c.level, current_hp: c.current_hp, max_hp: c.max_hp,
      wins: c.wins, losses: c.losses, is_alive: c.is_alive
    }
  end
end
