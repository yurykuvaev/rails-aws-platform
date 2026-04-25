class ElementAdvantage
  STRONG_AGAINST = {
    "fire"     => "grass",
    "grass"    => "water",
    "water"    => "fire",
    "electric" => "water"
  }.freeze

  def self.lookup(attacker_element, defender_element)
    a = attacker_element.to_s
    d = defender_element.to_s
    return 0.5 if a == d
    return 2.0 if STRONG_AGAINST[a] == d

    1.0
  end
end
