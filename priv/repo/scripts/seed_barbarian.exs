alias Game.{Repo, BaseCards.BaseCard, BaseDecks.BaseDeck, Content.BaseDeckCard, Content.BaseClass}

# Charge is shared with the Monk seed — insert only if not already present
charge_attrs = %{
  name: "Charge",
  headline: "Rush an enemy — the farther you charge, the harder you hit",
  ap: 2,
  range: 4,
  rarity: :uncommon,
  targeting: %{"type" => "character", "rule" => %{"alias" => "enemy"}},
  effects: [
    %{
      type: "move",
      value: %{
        "angle" => %{"var" => "angle_toward_target"},
        "distance" => %{"var" => "cast_distance"}
      },
      target_formula: %{"var" => "caster.id"}
    },
    %{type: "damage", value: %{"var" => "cast_distance"}}
  ]
}

Repo.insert!(%BaseCard{} |> BaseCard.changeset(charge_attrs),
  on_conflict: :nothing,
  conflict_target: :name
)

charge_card = Repo.get_by!(BaseCard, name: "Charge")

# JsonLogic formula: sum all shield values from target's status_effects
target_shield_sum = %{
  "reduce" => [
    %{
      "filter" => [
        %{"var" => "target.status_effects"},
        %{"===" => [%{"var" => "current.type"}, "shield"]}
      ]
    },
    %{"+" => [%{"var" => "accumulator"}, %{"var" => "current.value"}]},
    0
  ]
}

new_cards = [
  %{
    name: "Get Over Here",
    headline: "Drag your enemy across the battlefield",
    ap: 1,
    range: 2,
    rarity: :uncommon,
    targeting: %{"type" => "character", "rule" => %{"alias" => "enemy"}},
    effects: [
      %{
        type: "move",
        value: %{"angle" => %{"var" => "angle_toward_caster"}, "distance" => 2}
      }
    ]
  },
  %{
    name: "War Cry",
    headline: "A thunderous roar that shields all nearby warriors",
    ap: 2,
    range: 1,
    rarity: :uncommon,
    targeting: %{"type" => "character", "rule" => %{"alias" => "self"}},
    effects: [
      # Strong personal shield for the caster
      %{type: "shield", value: 6, target_formula: %{"var" => "caster.id"}},
      # Smaller shield AoE to everyone adjacent (allies and enemies — it's a war cry)
      %{type: "shield", value: 4, aoe: true}
    ]
  },
  %{
    name: "Shield Break",
    headline: "Shatter the enemy's defenses — the stronger their shield, the harder you hit",
    ap: 2,
    range: 1,
    rarity: :rare,
    targeting: %{"type" => "character", "rule" => %{"alias" => "enemy"}},
    effects: [
      %{type: "damage", value: %{"+" => [3, target_shield_sum]}}
    ]
  }
]

cards_map =
  (new_cards
  |> Enum.map(fn c -> Repo.insert!(%BaseCard{} |> BaseCard.changeset(c)) end)
  |> Map.new(&{&1.name, &1}))

cards_map =
  (cards_map
  |> Map.put("Charge", charge_card)
  |> Map.put("Strike", Repo.get_by!(BaseCard, name: "Strike"))
  |> Map.put("Cleave", Repo.get_by!(BaseCard, name: "Cleave"))
  |> Map.put("Whirlwind", Repo.get_by!(BaseCard, name: "Whirlwind")))

{:ok, deck} = Repo.insert(%BaseDeck{name: "Barbarian Starter"})

([
  {"Get Over Here", 2},
  {"War Cry", 2},
  {"Shield Break", 3},
  {"Cleave", 3},
  {"Whirlwind", 2},
  {"Strike", 3}
]
|> Enum.each(fn {name, count} ->
  Repo.insert!(%BaseDeckCard{deck_id: deck.id, card_id: cards_map[name].id, count: count})
end))

Repo.insert!(%BaseClass{
  class: "barbarian",
  base_hp: 24,
  base_ap: 3,
  base_movement: 2,
  deck_id: deck.id
})
