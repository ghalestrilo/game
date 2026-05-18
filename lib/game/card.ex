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
    "give" => CardEffects.Give,
    "modify_attribute" => CardEffects.ModifyAttribute
  }

  def effect_types, do: @effect_types

  @rarity_order %{common: 0, uncommon: 1, rare: 2, legendary: 3}

  def sort_by_rarity(cards) do
    Enum.sort_by(cards, fn card ->
      {Map.get(@rarity_order, card.rarity, 99), card.name}
    end, :desc)
  end

  defstruct [
    :id,
    :base_card_id,
    :name,
    :headline,
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
          base_card_id: integer(),
          name: String.t(),
          headline: String.t(),
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

    # Process card effects (heal, damage, etc) with the updated target.
    # Pass combat_state (pre-dispel) as the formula context so caster status effects
    # like stealth are visible to conditional formulas evaluated during effect resolution.
    apply_card_effects(updated_combat, card.effects, updated_target, combat_state)
  end

  # Helper function to apply multiple card effects; returns {combat_state, animations}
  defp apply_card_effects(initial_combat_state, effects, target, formula_state \\ nil)
       when is_list(effects) do
    formula_state = formula_state || initial_combat_state
    cast_distance = compute_cast_distance(initial_combat_state, target)

    Enum.reduce(effects, {initial_combat_state, []}, fn effect, {combat_state, anims} ->
      current_target = refresh_target(target, combat_state)

      case get_structured_effect(effect) do
        :skip ->
          {combat_state, anims}

        resolved ->
          # resolve_effect_target runs on the raw effect (before get_structured_effect strips
          # target_formula), so we use the original `effect` from the outer closure.
          effective_target = resolve_effect_target(effect, current_target, combat_state)
          aoe_range = Map.get(effect, :range) || Map.get(effect, "range") || 0

          if aoe_range > 0 do
            # Skip pre-resolution: AoE effects resolve formulas per-target inside apply_aoe_effect,
            # using blast-relative context (e.g. angle_push_from_blast).
            {new_combat, new_anims} =
              apply_aoe_effect(resolved, aoe_range, effective_target, combat_state, cast_distance)

            {new_combat, Enum.reverse(new_anims) ++ anims}
          else
            # Formula context always uses the card's selected target for directional variables
            # (push_delta, pull_delta, etc.), even when the effect itself targets someone else.
            # formula_state preserves caster status effects from before dispel_stealth ran.
            resolved =
              resolve_effect_value(resolved, current_target, formula_state, cast_distance)

            new_combat = CardEffect.process(resolved, effective_target, combat_state)
            new_anim = CardEffect.animate(resolved)
            {new_combat, if(new_anim, do: [new_anim | anims], else: anims)}
          end
      end
    end)
    |> then(fn {combat, anims} -> {combat, Enum.reverse(anims)} end)
  end

  defp apply_aoe_effect(effect, radius, blast_origin, combat_state, cast_distance) do
    origin_pos = if is_struct(blast_origin), do: blast_origin.position, else: blast_origin

    targets =
      Grid.tiles_in_range(combat_state.grid, origin_pos, radius || 1)
      |> Enum.flat_map(fn pos ->
        case Grid.get_object(combat_state.grid, pos) do
          {:ok, %Game.Character{} = char} -> [char]
          _ -> []
        end
      end)

    Enum.reduce(targets, {combat_state, []}, fn char_target, {cs, anims} ->
      # Refresh from queue so prior effects in this AoE loop (e.g. damage) aren't undone.
      fresh_target = refresh_target(char_target, cs)
      # Expose blast-relative direction vectors so formulas can push away from the blast origin
      # rather than away from the caster.
      blast_context = build_blast_context(origin_pos, fresh_target, cs)

      resolved_for_target =
        resolve_effect_value(effect, fresh_target, cs, cast_distance, blast_context)

      new_cs = CardEffect.process(resolved_for_target, fresh_target, cs)
      anim = CardEffect.animate(resolved_for_target)
      {new_cs, if(anim, do: [anim | anims], else: anims)}
    end)
    |> then(fn {cs, anims} -> {cs, Enum.reverse(anims)} end)
  end

  defp build_blast_context(blast_pos, target, combat_state) when is_struct(target) do
    {dq, dr, ds} = Grid.direction_toward(combat_state.grid, blast_pos, target.position)
    push = %{"q" => dq, "r" => dr, "s" => ds}
    pull = %{"q" => -dq, "r" => -dr, "s" => -ds}

    angle_push =
      Enum.find_index(Grid.hex_directions(), &(&1 == {dq, dr, ds}))

    angle_pull =
      Enum.find_index(Grid.hex_directions(), &(&1 == {-dq, -dr, -ds}))

    %{
      "push_delta_from_blast" => push,
      "pull_delta_from_blast" => pull,
      "angle_push_from_blast" => angle_push,
      "angle_pull_from_blast" => angle_pull
    }
  end

  defp build_blast_context(_blast_pos, _target, _combat_state), do: %{}

  defp refresh_target(target, _combat_state) when is_tuple(target), do: target

  defp refresh_target(target, combat_state) do
    CombatState.get_current_queue(combat_state)
    |> Enum.find(fn char -> char.id == target.id end)
    |> Kernel.||(target)
  end

  defp resolve_effect_target(%{target_formula: formula}, _target, combat_state)
       when is_map(formula) and map_size(formula) > 0 do
    caster = CombatState.get_current_player(combat_state)
    {:ok, caster_json} = Jason.encode(caster)
    {:ok, caster_map} = Jason.decode(caster_json)
    id = Game.Formula.resolve(formula, %{"caster" => caster_map})

    CombatState.get_current_queue(combat_state)
    |> Enum.find(&(&1.id == id))
    |> Kernel.||(caster)
  end

  defp resolve_effect_target(_effect, target, _combat_state), do: target

  defp resolve_effect_value(effect, target, combat_state, cast_distance, extra_context \\ %{}) do
    params = CardEffect.params(effect)

    if Enum.any?(params, fn p ->
         Map.get(effect, String.to_existing_atom(p)) |> is_map()
       end) do
      context =
        build_effect_context(target, combat_state, cast_distance)
        |> Map.merge(extra_context)

      Enum.reduce(params, effect, fn param, acc ->
        key = String.to_existing_atom(param)

        case Map.get(acc, key) do
          v when is_map(v) -> Map.put(acc, key, Game.Formula.resolve(v, context))
          _ -> acc
        end
      end)
    else
      effect
    end
  end

  # Backwards-compatible arity-3 clause used by existing callers
  defp resolve_effect_value(effect, target, combat_state),
    do: resolve_effect_value(effect, target, combat_state, nil)

  defp build_effect_context(target, combat_state, cast_distance \\ nil) do
    caster = CombatState.get_current_player(combat_state)
    {:ok, state_json} = Jason.encode(combat_state)
    {:ok, state_map} = Jason.decode(state_json)
    {:ok, caster_json} = Jason.encode(caster)
    {:ok, caster_map} = Jason.decode(caster_json)

    caster_map =
      caster_map
      |> Map.put("max_hp", Game.Character.effective_attribute(caster, "max_hp"))
      |> Map.put("max_ap", Game.Character.effective_attribute(caster, "max_ap"))

    %{
      "caster" => caster_map,
      "target" => encode_target(target),
      "state" => state_map,
      "pull_delta" => compute_pull_delta(caster, target, combat_state),
      "push_delta" => compute_push_delta(caster, target, combat_state),
      "angle_toward_target" => compute_angle_toward(caster, target, combat_state),
      "angle_toward_caster" => compute_angle_toward(target, caster, combat_state),
      "distance_from_caster" => compute_distance_from_caster(caster, target, combat_state),
      "cast_distance" => cast_distance
    }
  end

  defp compute_pull_delta(caster, target, combat_state) when is_struct(target) do
    {dq, dr, ds} = Grid.direction_toward(combat_state.grid, target.position, caster.position)
    %{"q" => dq, "r" => dr, "s" => ds}
  end

  defp compute_pull_delta(_caster, _target, _combat_state), do: nil

  defp compute_push_delta(caster, target, combat_state) when is_struct(target) do
    {dq, dr, ds} = Grid.direction_toward(combat_state.grid, caster.position, target.position)
    %{"q" => dq, "r" => dr, "s" => ds}
  end

  defp compute_push_delta(_caster, _target, _combat_state), do: nil

  defp compute_angle_toward(from, to, combat_state)
       when is_struct(from) and is_struct(to) do
    dir = Grid.direction_toward(combat_state.grid, from.position, to.position)
    Enum.find_index(Grid.hex_directions(), &(&1 == dir))
  end

  defp compute_angle_toward(_from, _to, _combat_state), do: nil

  defp compute_distance_from_caster(caster, target, combat_state) when is_struct(target) do
    Grid.distance(combat_state.grid, target.position, caster.position)
  end

  defp compute_distance_from_caster(_caster, _target, _combat_state), do: nil

  defp compute_cast_distance(combat_state, target) when is_struct(target) do
    caster = CombatState.get_current_player(combat_state)
    Grid.distance(combat_state.grid, caster.position, target.position)
  end

  defp compute_cast_distance(_combat_state, _target), do: nil

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

  def get_targeting_mode(%__MODULE__{targeting: %{"mode" => mode}}) when is_binary(mode),
    do: String.to_atom(mode)

  def get_targeting_mode(%__MODULE__{}), do: :null

  @doc "Returns true if `target_pos` is within the card's effective range from `caster_pos`."
  def card_in_range?(%__MODULE__{range: range} = card, caster_pos, target_pos, grid) do
    case get_targeting_mode(card) do
      :guided ->
        case Grid.astar_path_length(grid, caster_pos, target_pos) do
          {:ok, len} -> len <= range
          :unreachable -> false
        end

      _ ->
        Grid.distance(grid, caster_pos, target_pos) <= range
    end
  end

  def is_target_cell_valid?(
        %__MODULE__{targeting: targeting} = card,
        target_position,
        combat_state
      ) do
    targeting_type = get_targeting_type(card)
    position_result = Game.Grid.get_object(combat_state.grid, target_position)

    base_result =
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

    case base_result do
      {:ok, _} = ok ->
        caster = CombatState.get_current_player(combat_state)

        if is_nil(caster) or is_nil(caster.position) do
          ok
        else
          case validate_mode_constraint(
                 get_targeting_mode(card),
                 caster.position,
                 target_position,
                 card.range,
                 combat_state.grid
               ) do
            :ok -> ok
            err -> err
          end
        end

      err ->
        err
    end
  end

  def is_target_valid_for_character?(
        %__MODULE__{targeting: targeting} = card,
        character,
        combat_state
      ) do
    position_result = {:ok, character}

    base_result =
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

    case base_result do
      {:ok, _} = ok ->
        caster = CombatState.get_current_player(combat_state)

        if is_nil(caster) or is_nil(caster.position) do
          ok
        else
          case validate_mode_constraint(
                 get_targeting_mode(card),
                 caster.position,
                 character.position,
                 card.range,
                 combat_state.grid
               ) do
            :ok -> ok
            err -> err
          end
        end

      err ->
        err
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

  defp validate_mode_constraint(:null, _caster_pos, _target_pos, _range, _grid), do: :ok
  defp validate_mode_constraint(:area, _caster_pos, _target_pos, _range, _grid), do: :ok

  defp validate_mode_constraint(:linear, caster_pos, target_pos, _range, grid) do
    if Grid.has_linear_path?(grid, caster_pos, target_pos) do
      :ok
    else
      {:error, "No clear line of sight to target"}
    end
  end

  defp validate_mode_constraint(:emanation, caster_pos, target_pos, _range, grid) do
    if Grid.has_linear_path?(grid, caster_pos, target_pos) do
      :ok
    else
      {:error, "No clear line of sight to target"}
    end
  end

  defp validate_mode_constraint(:guided, caster_pos, target_pos, range, grid) do
    case Grid.astar_path_length(grid, caster_pos, target_pos) do
      {:ok, len} when len <= range -> :ok
      {:ok, _} -> {:error, "Target is out of guided range"}
      :unreachable -> {:error, "No walkable path to target"}
    end
  end

  def build_tile_overlay(%__MODULE__{range: range} = card, combat) when is_integer(range) do
    player = CombatState.get_current_player(combat)
    mode = get_targeting_mode(card)
    in_range = filter_by_mode(mode, combat.grid, player.position, range)

    {:ok, state_json} = Jason.encode(combat)
    {:ok, state_map} = Jason.decode(state_json)

    targeting_rule = get_in(card.targeting, ["rule"])

    overlay =
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

    blast_map =
      if aoe > 0 do
        overlay
        |> Enum.flat_map(fn
          {coord, :valid} ->
            blast = Game.Grid.tiles_in_range(combat.grid, coord, aoe)
            [{coord, blast}]

          _ ->
            []
        end)
        |> Map.new()
      else
        %{}
      end

    {overlay, blast_map}
  end

  def build_tile_overlay(_card, _combat), do: {%{}, %{}}

  defp filter_by_mode(mode, grid, origin, range) when mode in [:null, :area] do
    Game.Grid.tiles_in_range(grid, origin, range)
  end

  defp filter_by_mode(mode, grid, origin, range) when mode in [:linear, :emanation] do
    Game.Grid.tiles_in_range(grid, origin, range)
    |> Enum.filter(&Game.Grid.has_linear_path?(grid, origin, &1))
  end

  defp filter_by_mode(:guided, grid, origin, range) do
    Game.Grid.tiles_in_range(grid, origin, range)
    |> Enum.filter(fn pos ->
      case Game.Grid.astar_path_length(grid, origin, pos) do
        {:ok, len} -> len <= range
        :unreachable -> false
      end
    end)
  end

  defp filter_by_mode(_mode, grid, origin, range) do
    Game.Grid.tiles_in_range(grid, origin, range)
  end

  def aoe_radius(%__MODULE__{effects: effects}) when is_list(effects) do
    effects
    |> Enum.map(&(Map.get(&1, :range) || Map.get(&1, "range") || 0))
    |> Enum.max(fn -> 0 end)
  end

  def aoe_radius(_), do: 0

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

  def is_one_time_use?(%{effects: effects}) when is_list(effects) do
    Enum.any?(effects, fn effect ->
      Map.get(effect, :type) == "self_destruct"
    end)
  end

  def is_one_time_use?(card) do
    false
  end
end
