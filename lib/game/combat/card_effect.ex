defprotocol Game.Combat.CardEffect do
  defstruct [:type, :value]

  @type t() :: %{
          type: String.t() | atom(),
          value: any()
        }

  @spec process(t(), any(), CombatState.t()) :: CombatState.t()
  def process(card_effect, target, combat_state)

  @spec get_description(t()) :: String.t()
  def get_description(card_effect)

  @spec get_icon(t()) :: String.t()
  def get_icon(card_effect)

  @spec get_value_label(t()) :: String.t()
  def get_value_label(card_effect)

  @spec animate(t()) :: %{label: String.t(), color: :red | :green | :blue | :yellow} | nil
  def animate(card_effect)
end
