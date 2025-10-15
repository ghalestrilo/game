defprotocol Game.Combat.CardEffect do
  alias __MODULE__

  defstruct [:type, :value, :targeting]

  @spec process(t(), any(), CombatState.t()) :: CombatState.t()
  def process(card_effect, target, combat_state)

  @spec get_description(t()) :: string()
  def get_description(card_effect)
end
