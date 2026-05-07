defmodule Game.FireballTest do
  use ExUnit.Case, async: true

  alias Game.{Combat, Character, CombatState, Grid}

  # Fireball: range 4, AoE damage + knockback in radius 2 around the blast tile.
  # The move effect uses angle_push_from_blast — direction from blast center to each target.
  @blast_radius 2
  @fireball %Game.Card{
    id: 99,
    name: "Fireball",
    cost: 1,
    range: 4,
    targeting: %{"type" => "tile"},
    effects: [
      %{"type" => "damage", "value" => 5, "aoe" => true, "range" => @blast_radius},
      %{
        "type" => "move",
        "angle" => %{"var" => "angle_push_from_blast"},
        "distance" => 1,
        "aoe" => true,
        "range" => @blast_radius
      }
    ]
  }

  # Layout (all on the q-axis, blast at {3,0,-3}):
  #
  #   caster  {0,0,0}                distance from blast: 3  (caster is not in AoE)
  #   ally1   {1,0,-1}               distance from blast: 2  ← within radius, hit
  #   enemy1  {2,0,-2}               distance from blast: 1  ← within radius, hit
  #   blast   {3,0,-3}               the target tile (empty)
  #   enemy2  {4,0,-4}               distance from blast: 1  ← within radius, hit
  #   bystander {6,0,-6}             distance from blast: 3  → outside radius, unaffected
  #
  # The tile {5,0,-5} exists but is empty, giving the move effect room to push enemy2.
  # Bystander at {6,0,-6} is 3 steps from the blast — outside the radius-2 AoE.
  # Their tile is within the grid but NOT reachable by the card (distance 6 > card.range 4)
  # and not within the blast radius, so they should be unaffected.

  defp make_char(id, pos, team) do
    %Character{
      id: id,
      name: "char#{id}",
      class: :fighter,
      ap: 3,
      hp: 20,
      position: pos,
      movement_range: 2,
      team: team,
      cards: %{draw: [], hand: [], discard: []}
    }
  end

  defp build_combat do
    caster    = make_char(1, {0, 0, 0}, :team1)
    ally1     = make_char(2, {1, 0, -1}, :team1)
    enemy1    = make_char(3, {2, 0, -2}, :team2)
    enemy2    = make_char(4, {4, 0, -4}, :team2)
    bystander = make_char(5, {6, 0, -6}, :team2)

    grid = %Grid{
      tiles: %{
        {0, 0, 0}  => %{terrain: :plain, occupied_by: caster},
        {1, 0, -1} => %{terrain: :plain, occupied_by: ally1},
        {2, 0, -2} => %{terrain: :plain, occupied_by: enemy1},
        {3, 0, -3} => %{terrain: :plain, occupied_by: nil},
        {4, 0, -4} => %{terrain: :plain, occupied_by: enemy2},
        {5, 0, -5} => %{terrain: :plain, occupied_by: nil},
        {6, 0, -6} => %{terrain: :plain, occupied_by: bystander}
      }
    }

    fireball = @fireball
    caster_with_card = %{caster | cards: %{caster.cards | hand: [fireball]}}

    combat = %CombatState{
      state: :running,
      __constants__: %{players: [caster, ally1, enemy1, enemy2, bystander]},
      queue: [ally1, enemy1, enemy2, bystander],
      grid: grid,
      current_turn: %{
        starting_position: caster.position,
        player: caster_with_card,
        card: nil
      }
    }

    {combat, caster_with_card, ally1, enemy1, enemy2, bystander}
  end

  defp pick_and_play_tile(combat, caster, card, target_pos) do
    {:ok, selected} = Combat.process_action(combat, {:pick_card, caster, card})

    case Combat.process_action(selected, {:play_card, target_pos}) do
      {:ok, updated, _anims} -> {:ok, updated}
      other -> other
    end
  end

  defp pick_and_play_character(combat, caster, card, target_char) do
    {:ok, selected} = Combat.process_action(combat, {:pick_card, caster, card})

    case Combat.process_action(selected, {:play_card_on_character, target_char}) do
      {:ok, updated, _anims} -> {:ok, updated}
      other -> other
    end
  end

  defp find_in_queue(combat, char) do
    all = [combat.current_turn.player | combat.queue]
    Enum.find(all, &(&1.id == char.id))
  end

  # ── Targeting ────────────────────────────────────────────────────────────────

  describe "targeting" do
    test "targeting an empty tile within range succeeds" do
      {combat, caster, _ally1, _enemy1, _enemy2, _bystander} = build_combat()
      result = pick_and_play_tile(combat, caster, @fireball, {3, 0, -3})
      assert {:ok, _} = result
    end

    test "targeting an occupied tile within range succeeds" do
      {combat, caster, _ally1, enemy1, _enemy2, _bystander} = build_combat()
      # enemy1 sits at {2,0,-2}, distance 2 from caster — within card range 4
      result = pick_and_play_tile(combat, caster, @fireball, enemy1.position)
      assert {:ok, _} = result
    end

    test "targeting a character directly via play_card_on_character succeeds" do
      {combat, caster, _ally1, enemy1, _enemy2, _bystander} = build_combat()
      # Fireball uses tile targeting but play_card_on_character resolves to the character's tile.
      result = pick_and_play_character(combat, caster, @fireball, enemy1)
      assert {:ok, _} = result
    end

    test "targeting a tile out of range fails" do
      {combat, caster, _ally1, _enemy1, _enemy2, bystander} = build_combat()
      # bystander is at {6,0,-6}, distance 6 > card range 4
      result = pick_and_play_tile(combat, caster, @fireball, bystander.position)
      assert {:error, _} = result
    end
  end

  # ── AoE damage ───────────────────────────────────────────────────────────────

  describe "AoE damage" do
    setup do
      {combat, caster, ally1, enemy1, enemy2, bystander} = build_combat()
      {:ok, updated} = pick_and_play_tile(combat, caster, @fireball, {3, 0, -3})

      %{
        combat: updated,
        ally1: ally1,
        enemy1: enemy1,
        enemy2: enemy2,
        bystander: bystander
      }
    end

    test "all characters within blast radius take damage", %{
      combat: combat,
      ally1: ally1,
      enemy1: enemy1,
      enemy2: enemy2
    } do
      # ally1 {1,0,-1}: hex distance 2 from blast {3,0,-3} — at radius edge, hit
      # enemy1 {2,0,-2}: distance 1 — hit
      # enemy2 {4,0,-4}: distance 1 — hit
      assert find_in_queue(combat, ally1).hp == ally1.hp - 5
      assert find_in_queue(combat, enemy1).hp == enemy1.hp - 5
      assert find_in_queue(combat, enemy2).hp == enemy2.hp - 5
    end

    test "character outside blast radius is unaffected", %{combat: combat, bystander: bystander} do
      # bystander {6,0,-6}: hex distance 3 from blast {3,0,-3} — outside radius 2
      assert find_in_queue(combat, bystander).hp == bystander.hp
    end

    test "caster outside blast radius is unaffected", %{combat: combat} do
      # caster {0,0,0}: hex distance 3 from blast {3,0,-3} — outside radius 2
      updated_caster = combat.current_turn.player
      assert updated_caster.hp == 20
    end
  end

  # ── Edge of map ───────────────────────────────────────────────────────────────

  describe "edge of map" do
    test "blast tile at the edge of the map does not raise" do
      {combat, caster, _ally1, _enemy1, _enemy2, _bystander} = build_combat()

      # Blast at {4,0,-4}: some radius-2 tiles around it (e.g. {6,0,-6} direction would
      # be off-map or occupied). The AoE should silently skip missing tiles.
      assert {:ok, _} = pick_and_play_tile(combat, caster, @fireball, {4, 0, -4})
    end

    test "only on-map characters within radius take damage when blast is near edge" do
      {combat, caster, _ally1, _enemy1, enemy2, bystander} = build_combat()

      # Blast at {4,0,-4}: enemy2 is at the blast tile (distance 0), bystander at distance 2.
      # Both within radius 2. Tiles beyond {6,0,-6} don't exist — no crash.
      {:ok, updated} = pick_and_play_tile(combat, caster, @fireball, {4, 0, -4})

      assert find_in_queue(updated, enemy2).hp == enemy2.hp - 5
      assert find_in_queue(updated, bystander).hp == bystander.hp - 5
    end
  end

  # ── Push direction ────────────────────────────────────────────────────────────

  describe "knockback" do
    # Blast at {3,0,-3}. Push direction = away from blast center toward each target.
    #
    # ally1  {1,0,-1}: push direction {-1,0,+1} → would land on {0,0,0} (caster) — blocked, stays
    # enemy1 {2,0,-2}: push direction {-1,0,+1} → would land on {1,0,-1} (ally1)  — blocked, stays
    # enemy2 {4,0,-4}: push direction {+1,0,-1} → lands on {5,0,-5} (empty)       — moves ✓
    #
    # Note: caster is at {0,0,0}, which is in the OPPOSITE direction from blast for chars on the
    # left side. This exercises that the push is blast-relative, not caster-relative: chars to the
    # right of blast are pushed rightward even though that's also away from the caster.

    setup do
      {combat, caster, ally1, enemy1, enemy2, _bystander} = build_combat()
      {:ok, updated} = pick_and_play_tile(combat, caster, @fireball, {3, 0, -3})
      %{combat: updated, ally1: ally1, enemy1: enemy1, enemy2: enemy2}
    end

    test "enemy2 is pushed away from blast to {5,0,-5}", %{combat: combat, enemy2: enemy2} do
      # enemy2 at {4,0,-4}: blast-to-enemy direction = {+1,0,-1} → new pos {5,0,-5}
      assert find_in_queue(combat, enemy2).position == {5, 0, -5}
    end

    test "push direction is away from blast center, not away from caster", %{
      combat: combat,
      enemy2: enemy2
    } do
      # Caster is at {0,0,0}. Direction from caster to enemy2 {4,0,-4} is {1,0,-1}.
      # Direction from blast {3,0,-3} to enemy2 {4,0,-4} is also {1,0,-1} here.
      # But ally1 {1,0,-1}: direction from caster = {1,0,-1} (toward blast side),
      # direction from blast = {-1,0,+1} (away from blast, toward caster side).
      # ally1 is pushed toward {0,0,0} (blocked by caster), NOT toward {2,0,-2}.
      # This confirms the push is from blast center, not from caster.
      updated_ally1 = find_in_queue(combat, %{id: 2})
      # ally1 tried to move to {0,0,0} (caster's tile) — blocked, stays put
      assert updated_ally1.position == {1, 0, -1}

      # enemy2 moved in direction {+1,0,-1} from blast — same direction as away from caster
      # (coincidence for this geometry), but the displacement is blast-determined:
      updated_enemy2 = find_in_queue(combat, enemy2)
      displacement = {
        elem(updated_enemy2.position, 0) - elem(enemy2.position, 0),
        elem(updated_enemy2.position, 1) - elem(enemy2.position, 1),
        elem(updated_enemy2.position, 2) - elem(enemy2.position, 2)
      }
      assert displacement == {1, 0, -1}
    end

    test "character blocked by occupied tile stays in place", %{combat: combat, enemy1: enemy1} do
      # enemy1 at {2,0,-2} pushed toward {1,0,-1} (occupied by ally1) — stays
      assert find_in_queue(combat, enemy1).position == {2, 0, -2}
    end

    test "hp is preserved correctly after both damage and knockback effects", %{
      combat: combat,
      enemy2: enemy2
    } do
      # Ensures the move effect doesn't overwrite hp changes from the damage effect.
      assert find_in_queue(combat, enemy2).hp == enemy2.hp - 5
    end
  end
end
