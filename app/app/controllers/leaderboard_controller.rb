class LeaderboardController < ApplicationController
  # NOTE: deliberate N+1 — each character.player.username triggers a
  # separate SELECT. Useful for practising bullet/log inspection.
  def index
    characters = Character.top_wins

    render json: characters.map { |c|
      {
        id:        c.id,
        player_id: c.player_id,
        name:      c.name,
        level:     c.level,
        wins:      c.wins,
        losses:    c.losses,
        element:   c.element,
        is_alive:  c.is_alive,
        owner:     c.player.username
      }
    }
  end
end
