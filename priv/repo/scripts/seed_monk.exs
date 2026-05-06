alias Game.{Repo, BaseCards.BaseCard, BaseDecks.BaseDeck, Content.BaseDeckCard, Content.BaseClass}

# Charge is shared with the Barbarian seed — insert only if not already present
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

# JsonLogic formula: sum all shield values from the caster's status_effects
caster_shield_sum = %{
  "reduce" => [
    %{
      "filter" => [
        %{"var" => "caster.status_effects"},
        %{"===" => [%{"var" => "current.type"}, "shield"]}
      ]
    },
    %{"+" => [%{"var" => "accumulator"}, %{"var" => "current.value"}]},
    0
  ]
}

new_cards = [
  %{
    name: "Iron Skin",
    headline: "Harden your body against all blows",
    ap: 1,
    range: 1,
    rarity: :common,
    targeting: %{"type" => "character", "rule" => %{"alias" => "self"}},
    effects: [
      %{type: "shield", value: 5, target_formula: %{"var" => "caster.id"}}
    ]
  },
  %{
    name: "Mountain Aspect",
    headline: "Become as immovable as a mountain",
    ap: 2,
    range: 1,
    rarity: :uncommon,
    targeting: %{"type" => "character", "rule" => %{"alias" => "self"}},
    effects: [
      %{type: "shield", value: 8, target_formula: %{"var" => "caster.id"}}
    ]
  },
  %{
    name: "Ki Slam",
    headline: "Release your accumulated ki as a devastating strike — damage equals your current shield",
    ap: 2,
    range: 1,
    rarity: :rare,
    targeting: %{"type" => "character", "rule" => %{"alias" => "enemy"}},
    effects: [
      %{type: "damage", value: caster_shield_sum}
    ]
  },
  %{
    name: "Phase",
    headline: "Shift partially out of reality — attacks pass through you",
    ap: 1,
    range: 1,
    rarity: :uncommon,
    targeting: %{"type" => "character", "rule" => %{"alias" => "self"}},
    effects: [
      %{type: "ethereal", value: 1, target_formula: %{"var" => "caster.id"}}
    ]
  },
  %{
    name: "Bounceback",
    headline: "Strike hard, then step away before they can retaliate",
    ap: 2,
    range: 1,
    rarity: :uncommon,
    targeting: %{"type" => "character", "rule" => %{"alias" => "enemy"}},
    effects: [
      %{type: "damage", value: 4},
      # Move the caster 2 tiles away from the target (angle_toward_caster = direction from enemy to caster)
      %{
        type: "move",
        value: %{"angle" => %{"var" => "angle_toward_caster"}, "distance" => 2},
        target_formula: %{"var" => "caster.id"}
      }
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
  |> Map.put("Strike", Repo.get_by!(BaseCard, name: "Strike")))

{:ok, deck} = Repo.insert(%BaseDeck{name: "Monk Starter"})

([
  {"Iron Skin", 3},
  {"Mountain Aspect", 2},
  {"Ki Slam", 3},
  {"Phase", 2},
  {"Bounceback", 2},
  {"Strike", 3}
]
|> Enum.each(fn {name, count} ->
  Repo.insert!(%BaseDeckCard{deck_id: deck.id, card_id: Map.get(cards_map, name).id, count: count})
end))

Repo.insert!(%BaseClass{
  class: "monk",
  base_hp: 18,
  base_ap: 4,
  base_movement: 3,
  deck_id: deck.id
})
