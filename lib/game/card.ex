defmodule Game.Card do
  alias Game.CombatState
  alias Game.Combat.CardEffect
  alias Game.Combat.CardEffects
  alias Game.Grid
  require Logger

  @effect_types %{
    "damage" => CardEffects.Damage,
    "heal" => CardEffects.Heal,
    "draw" => CardEffects.Draw,
    "discard" => CardEffects.Discard,
    "shield" => CardEffects.Shield,
    "summon" => CardEffects.Summon,
    "stealth" => CardEffects.Stealth,
    "stuck" => CardEffects.Stuck,
    "slow" => CardEffects.Slow,
    "stun" => CardEffects.Stun,
    "move" => CardEffects.Move,
    "dot" => CardEffects.Dot,
    "regen" => CardEffects.Regen,
    "cleanse" => CardEffects.Cleanse,
    "ethereal" => CardEffects.Ethereal,
    "hex" => CardEffects.Hex,
    "self_destruct" => CardEffects.SelfDestruct,
    "give" => CardEffects.Give
  }

  def effect_types, do: @effect_types

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
    :scaling,
    :targeting
  ]

  @type card_effect() :: [CardEffect]

  @type t() :: %__MODULE__{
          id: integer(),
          name: String.t(),
          description: String.t(),
          cost: integer(),
          effects: list(card_effect()),
          targeting: map() | nil
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
      # Process ap cost, hand, etc — and break stealth before effects resolve
      |> CombatState.update_target(
        current_player,
        current_player
        |> Game.Character.discard_card(card)
        |> Game.Character.spend_ap(card.cost)
      )
      |> CombatState.dispel_stealth()

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

  # Helper function to apply multiple card effects; returns {combat_state, animations}
  defp apply_card_effects(initial_combat_state, effects, target) when is_list(effects) do
    Enum.reduce(effects, {initial_combat_state, []}, fn effect, {combat_state, anims} ->
      current_target = refresh_target(target, combat_state)

      case get_structured_effect(effect) do
        :skip ->
          {combat_state, anims}

        resolved ->
          resolved = resolve_effect_value(resolved, current_target, combat_state)
          new_combat = CardEffect.process(resolved, current_target, combat_state)
          new_anim = CardEffect.animate(resolved)
          {new_combat, if(new_anim, do: [new_anim | anims], else: anims)}
      end
    end)
    |> then(fn {combat, anims} -> {combat, Enum.reverse(anims)} end)
  end

  defp refresh_target(target, _combat_state) when is_tuple(target), do: target

  defp refresh_target(target, combat_state) do
    CombatState.get_current_queue(combat_state)
    |> Enum.find(fn char -> char.id == target.id end)
    |> Kernel.||(target)
  end

  defp resolve_effect_value(%{value: value} = effect, target, combat_state) when is_map(value) do
    context = build_effect_context(target, combat_state)
    %{effect | value: Game.Formula.resolve(value, context)}
  end

  defp resolve_effect_value(effect, _target, _combat_state), do: effect

  defp build_effect_context(target, combat_state) do
    caster = CombatState.get_current_player(combat_state)
    {:ok, state_json} = Jason.encode(combat_state)
    {:ok, state_map} = Jason.decode(state_json)
    {:ok, caster_json} = Jason.encode(caster)
    {:ok, caster_map} = Jason.decode(caster_json)

    %{
      "caster" => caster_map,
      "target" => encode_target(target),
      "state" => state_map,
      "pull_delta" => compute_pull_delta(caster, target, combat_state),
      "distance_from_caster" => compute_distance_from_caster(caster, target, combat_state)
    }
  end

  defp compute_pull_delta(caster, target, combat_state) when is_struct(target) do
    {dq, dr, ds} = Grid.direction_toward(combat_state.grid, target.position, caster.position)
    %{"q" => dq, "r" => dr, "s" => ds}
  end

  defp compute_pull_delta(_caster, _target, _combat_state), do: nil

  defp compute_distance_from_caster(caster, target, combat_state) when is_struct(target) do
    Grid.distance(combat_state.grid, target.position, caster.position)
  end

  defp compute_distance_from_caster(_caster, _target, _combat_state), do: nil

  defp encode_target(target) when is_tuple(target),
    do: %{"position" => Tuple.to_list(target)}

  defp encode_target(target) do
    {:ok, json} = Jason.encode(target)
    {:ok, map} = Jason.decode(json)
    map
  end

  # Already a concrete CardEffect impl struct (e.g. %CardEffects.Damage{}) — pass through
  def get_structured_effect(%_{type: _} = effect)
      when not is_struct(effect, Game.BaseCards.BaseCard.Effect),
      do: effect

  # Ecto-loaded embedded schema from the database
  def get_structured_effect(%Game.BaseCards.BaseCard.Effect{type: type} = effect) do
    effect_data =
      effect
      |> Map.from_struct()
      |> Map.delete(:__meta__)
      |> Map.update(:value, nil, fn
        v when is_binary(v) ->
          case Integer.parse(v) do
            {int, ""} -> int
            _ -> v
          end

        v ->
          v
      end)
      |> unpack_params_map()

    build_effect_struct(type, effect_data)
  end

  # Raw string-keyed map (e.g. from seeds or test fixtures)
  def get_structured_effect(%{"type" => type} = effect) do
    effect_data =
      Map.new(effect, fn {k, v} -> {String.to_atom(k), v} end)
      |> unpack_params_map()

    build_effect_struct(type, effect_data)
  end

  def get_structured_effect(effect) do
    Logger.warning("Unrecognized effect shape, ignoring: #{inspect(effect)}")
    :skip
  end

  defp build_effect_struct(type, effect_data) do
    case Map.fetch(@effect_types, type) do
      {:ok, module} ->
        struct(module, effect_data)

      :error ->
        Logger.warning("Effect not implemented, ignoring: #{inspect(effect_data)}")
        :skip
    end
  end

  # When value is a plain params map (not a JsonLogic formula), unpack its keys as top-level
  # struct fields so e.g. %{"damage" => 5, "value" => 3} becomes damage: 5, value: 3.
  # A formula map has exactly one key which is a known JsonLogic operator.
  @formula_operators MapSet.new(
                       ~w(var == === != !== ! !! if or and > >= < <= max min + - * / % map filter reduce all none some in cat log alias)
                     )

  defp unpack_params_map(%{value: value} = effect_data) when is_map(value) do
    keys = Map.keys(value)

    if length(keys) == 1 and hd(keys) in @formula_operators do
      effect_data
    else
      atomized = Map.new(value, fn {k, v} -> {String.to_atom(k), v} end)
      Map.merge(effect_data, atomized)
    end
  end

  defp unpack_params_map(effect_data), do: effect_data

  @doc "Returns the param keys required by the effect of the given type string, or [\"value\"] if unknown."
  def effect_params(type) when is_binary(type) do
    case Map.fetch(@effect_types, type) do
      {:ok, module} -> CardEffect.params(struct(module))
      :error -> ["value"]
    end
  end

  def selectable?(%__MODULE__{cost: cost}, combat_state) do
    player = CombatState.get_current_player(combat_state)
    player.ap >= cost
  end

  def effect_implemented?(%{type: type} = effect) do
    if type && Map.has_key?(@effect_types, type) do
      true
    else
      Logger.warning("Effect not implemented, ignoring: #{inspect(effect)}")
      false
    end
  end

  def get_targeting_type(%__MODULE__{targeting: %{"type" => type}}) when is_binary(type),
    do: String.to_atom(type)

  def get_targeting_type(%__MODULE__{}), do: :character

  def is_target_cell_valid?(
        %__MODULE__{targeting: targeting} = card,
        target_position,
        combat_state
      ) do
    targeting_type = get_targeting_type(card)
    position_result = Game.Grid.get_object(combat_state.grid, target_position)

    case targeting do
      %{"rule" => targeting_rule} ->
        data_context = build_data_context(position_result, combat_state)
        result = JsonLogic.resolve(targeting_rule, data_context)

        if result do
          case targeting_type do
            :tile ->
              {:ok, nil}

            :character ->
              case position_result do
                {:ok, character} when not is_nil(character) -> {:ok, character}
                _ -> {:error, "No character at this position"}
              end
          end
        else
          {:error, "Target does not match targeting rule"}
        end

      _ ->
        case targeting_type do
          :tile ->
            case position_result do
              {:ok, _} -> {:ok, nil}
              _ -> {:error, "Invalid tile position"}
            end

          :character ->
            case position_result do
              {:ok, character} when not is_nil(character) -> {:ok, character}
              _ -> {:error, "No character at this position"}
            end
        end
    end
  end

  def is_target_valid_for_character?(
        %__MODULE__{targeting: targeting} = _card,
        character,
        combat_state
      ) do
    position_result = {:ok, character}

    case targeting do
      %{"rule" => targeting_rule} ->
        data_context = build_data_context(position_result, combat_state)
        result = JsonLogic.resolve(targeting_rule, data_context)

        if result do
          {:ok, character}
        else
          {:error, "Target does not match targeting rule"}
        end

      _ ->
        {:ok, character}
    end
  end

  # Build data context for JsonLogic evaluation including target and game state
  defp build_data_context(position_result, combat_state) do
    target_data = build_target_data(position_result)

    # Encode combat state to JSON and decode to get a plain map structure
    {:ok, state_json} = Jason.encode(combat_state)
    {:ok, state_map} = Jason.decode(state_json)

    %{
      "target" => target_data,
      "state" => %{
        "combat" => state_map
      }
    }
  end

  def build_tile_overlay(%__MODULE__{range: range} = card, combat) when is_integer(range) do
    player = CombatState.get_current_player(combat)
    in_range = Game.Grid.tiles_in_range(combat.grid, player.position, range)

    {:ok, state_json} = Jason.encode(combat)
    {:ok, state_map} = Jason.decode(state_json)

    targeting_rule = get_in(card.targeting, ["rule"])

    base_overlay =
      Map.new(in_range, fn coord ->
        position_result = Game.Grid.get_object(combat.grid, coord)

        data_context = %{
          "target" => build_target_data(position_result),
          "state" => %{"combat" => state_map}
        }

        valid? = targeting_rule && JsonLogic.resolve(targeting_rule, data_context)
        {coord, if(valid?, do: :valid, else: :invalid)}
      end)

    aoe = aoe_radius(card)

    if aoe > 0 do
      blast_coords =
        base_overlay
        |> Enum.flat_map(fn
          {coord, :valid} -> Game.Grid.tiles_in_range(combat.grid, coord, aoe)
          _ -> []
        end)
        |> Enum.reject(&Map.has_key?(base_overlay, &1))

      Map.merge(base_overlay, Map.new(blast_coords, &{&1, :blast}))
    else
      base_overlay
    end
  end

  def build_tile_overlay(_card, _combat), do: %{}

  defp aoe_radius(%__MODULE__{effects: effects}) when is_list(effects) do
    effects
    |> Enum.filter(&(Map.get(&1, :aoe) || Map.get(&1, "aoe")))
    |> Enum.map(&(Map.get(&1, :range) || Map.get(&1, "range") || 1))
    |> Enum.max(fn -> 0 end)
  end

  defp aoe_radius(_), do: 0

  # Build target-specific data for JsonLogic evaluation
  defp build_target_data(position_result) do
    case position_result do
      {:ok, nil} ->
        %{
          "occupied" => false,
          "team" => nil,
          "hp" => nil,
          "max_hp" => nil
        }

      {:ok, character} when not is_nil(character) ->
        %{
          "occupied" => true,
          "team" => to_string(character.team),
          "hp" => Map.get(character, :hp),
          "max_hp" => Map.get(character, :max_hp)
        }

      nil ->
        %{
          "occupied" => false,
          "team" => nil,
          "hp" => nil,
          "max_hp" => nil
        }
    end
  end
end
