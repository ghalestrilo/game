defimpl Inspect, for: Game.Character do
  def inspect(%Game.Character{} = character, _opts) do
    # Get max values using existing functions
    max_hp = Game.Character.get_max_hp(character)
    max_ap = Game.Character.get_max_ap(character)

    # Format the output with the requested information
    "#Character<#{character.name} (#{character.team}) HP:#{character.hp}/#{max_hp} AP:#{character.ap}/#{max_ap}>"
  end
end
