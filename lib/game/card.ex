defmodule Game.Card do
  alias Game.CombatState
  alias Game.Combat.CardEffect
  alias Game.Combat.CardEffects
  require Logger

  @effect_types %{
    "damage" => CardEffects.Damage,
    "heal" => CardEffects.Heal,
    "draw" => CardEffects.Draw,
    "discard" => CardEffects.Discard,
    "shield" => CardEffects.Shield,
    "summon" => CardEffects.Summon
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

  @type card_effect() :: [CardEffect]

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

    updated_combat =
      combat_state
      # Process ap cost, hand, etc
      |> CombatState.update_target(
        current_player,
        current_player
        |> Game.Character.discard_card(card)
        |> Game.Character.spend_ap(card.cost)
      )

    # For tile targeting (like summon), target is a position tuple
    # For character targeting, target is a character struct
    updated_target =
      if is_tuple(target) do
        # Target is a position, pass it through
        target
      else
        # Target is a character, get the updated version from combat state
        CombatState.get_current_queue(updated_combat)
        |> Enum.find(fn char -> char.id == target.id end)
        |> Kernel.||(target)
      end

    # Process card effects (heal, damage, etc) with the updated target
    apply_card_effects(updated_combat, card.effects, updated_target)
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

  def get_structured_effect(%CardEffect{} = effect), do: effect

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
      # Extract type directly from effect without calling get_structured_effect
      # to avoid KeyError for unimplemented effects
      type =
        case effect do
          %{"type" => t} -> t
          %{type: t} -> t
          _ -> nil
        end

      if type && Map.has_key?(@effect_types, type) do
        Logger.info("Processing Card Effect: #{inspect(effect)}")
        true
      else
        Logger.warning("Effect not implemented, ignoring: #{inspect(effect)}")
        false
      end
    end)
  end

  @doc """
  Determines the targeting type for a card based on its effects.
  Returns :tile for cards with summon effects, :character otherwise.
  """
  def get_targeting_type(%__MODULE__{effects: effects}) do
    has_tile_targeting =
      Enum.any?(effects || [], fn effect ->
        case effect do
          %{"type" => "summon"} -> true
          %{type: :summon} -> true
          _ -> false
        end
      end)

    if has_tile_targeting, do: :tile, else: :character
  end

  @doc """
  Validates whether a target cell is valid for playing this card.

  For :tile targeting cards (like summon):
  - Target must be a valid position on the grid
  - Target cell must be empty

  For :character targeting cards:
  - Target must resolve to a character
  """
  def is_target_cell_valid?(%__MODULE__{} = card, target_position, combat_state) do
    targeting_type = get_targeting_type(card)
    position_result = Game.Grid.get_object(combat_state.grid, target_position)

    case targeting_type do
      :tile ->
        # For tile targeting, we need an empty tile
        case position_result do
          {:ok, nil} -> {:ok, nil}  # Empty tile is valid
          {:ok, _character} -> {:error, "Tile must be empty"}
          nil -> {:error, "Invalid tile position"}
        end

      :character ->
        # For character targeting, we need a character at the position
        case position_result do
          {:ok, character} when not is_nil(character) -> {:ok, character}
          {:ok, nil} -> {:error, "No character at this position"}
          nil -> {:error, "No character at this position"}
        end
    end
  end
end
