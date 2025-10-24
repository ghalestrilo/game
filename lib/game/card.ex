defmodule Game.Card do
  alias Game.CombatState
  alias Game.Combat.CardEffect
  alias Game.Combat.CardEffects
  require Logger

  @effect_types %{
    "damage" => CardEffects.Damage,
    "heal" => CardEffects.Heal,
    "draw" => CardEffects.Draw,
    "discard" => CardEffects.Discard
  }

  defstruct [
    :id,
    :name,
    :description,
    # AP cost to play
    :cost,
    # Function reference or data structure representing effect
    :effects,
    # Range of effect in hex tiles
    :range,
    # Type of targeting (self, single, AoE, etc.)
    :targeting,
    # Rarity tier (Common, Uncommon, Rare, etc.)
    :rarity,
    # Elemental affinity (Fire, Ice, Lightning, etc.)
    :element,
    # Number of times the action is repeated
    :multi_strike,
    # List of additional effects triggered under certain conditions
    :conditional_effects,
    # Tags that interact with other cards in a deck
    :synergy_tags,
    # Number of rune slots available for further customization
    :rune_slots,
    # Scaling mechanics (e.g., increased power per use, missing HP bonus, etc.)
    :scaling
  ]

  @type card_effect() ::
          {:damage, integer()} | {:heal, integer()} | {:draw, integer()} | {:discard, integer()}

  @type t() :: %__MODULE__{
          id: integer(),
          name: String.t(),
          description: String.t(),
          cost: integer(),
          effects: list(card_effect())
        }

  defimpl Jason.Encoder, for: Game.Card do
    def encode(card, opts) do
      card_map = Map.from_struct(card)

      # Convert effect tuples to lists for proper JSON encoding
      updated_effects =
        case card_map.effects do
          effects when is_list(effects) ->
            Enum.map(effects, fn
              tuple when is_tuple(tuple) -> Tuple.to_list(tuple)
              other -> other
            end)

          effect when is_tuple(effect) ->
            Tuple.to_list(effect)

          other ->
            other
        end

      # Also handle conditional_effects if present
      updated_conditional_effects =
        case card_map.conditional_effects do
          effects when is_list(effects) ->
            Enum.map(effects, fn
              tuple when is_tuple(tuple) -> Tuple.to_list(tuple)
              other -> other
            end)

          effect when is_tuple(effect) ->
            Tuple.to_list(effect)

          other ->
            other
        end

      card_map = %{
        card_map
        | effects: updated_effects,
          conditional_effects: updated_conditional_effects
      }

      Jason.Encode.map(card_map, opts)
    end
  end

  def process_card(combat_state, target, card) do
    current_player = CombatState.get_current_player(combat_state)

    combat_state
    # Process ap cost, hand, etc
    |> CombatState.update_target(
      current_player,
      current_player
      |> Game.Character.discard_card(card)
      |> Game.Character.spend_ap(card.cost)
    )
    # Process card effects (heal, damage, etc)
    |> apply_card_effects(card.effects, target)
  end

  # Helper function to apply multiple card effects
  defp apply_card_effects(initial_combat_state, effects, target) when is_list(effects) do
    effects
    |> temporary_hack_filter_only_allowed_effects()
    |> Enum.reduce(initial_combat_state, fn effect, combat_state ->
      effect
      |> get_structured_effect()
      |> CardEffect.process(target, combat_state)
    end)
  end

  def get_structured_effect(%{"type" => type} = effect) do
    effect_data =
      Enum.reduce(effect, %{}, fn {key, value}, acc ->
        Map.put(acc, String.to_atom(key), value)
      end)

    @effect_types
    |> Map.fetch!(type)
    |> struct(effect_data)
  end

  defp temporary_hack_filter_only_allowed_effects(effects) do
    Enum.filter(effects, fn effect ->
      if Map.has_key?(@effect_types, effect["type"]) do
        Logger.info("Processing Card Effect: #{inspect(effect)}")
        true
      else
        Logger.warn("Effect not implemented, ignoring: #{inspect(effect)}")
        false
      end
    end)
  end
end
