defprotocol Game.Combat.CardEffect do

  defstruct [:type, :value, :targeting]

  @type t() :: %{
    type: String.t(), value: any(), targeting: any()
  }

  @spec process(t(), any(), CombatState.t()) :: CombatState.t()
  def process(card_effect, target, combat_state)

  @spec get_description(t()) :: String.t()
  def get_description(card_effect)
end
