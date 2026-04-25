FactoryBot.define do
  factory :character do
    player
    sequence(:name) { |n| "Char#{n}" }
    element { "fire" }
    level      { 1 }
    max_hp     { 100 }
    current_hp { 100 }
    attack     { 10 }
    defense    { 5 }
    speed      { 5 }

    trait :grass    do; element { "grass" };    end
    trait :water    do; element { "water" };    end
    trait :electric do; element { "electric" }; end
  end
end
