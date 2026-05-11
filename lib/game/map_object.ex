defprotocol Game.MapObject do
  @doc "Returns true if this object blocks movement into its tile."
  def blocks_movement?(object)

  @doc """
  Called when a character enters the tile containing this object.
  Returns `{:ok, updated_combat_state}` or `{:collect, item, updated_combat_state}`.
  """
  def on_enter(object, character, combat_state)
end
