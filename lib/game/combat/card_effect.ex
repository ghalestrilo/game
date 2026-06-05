defprotocol Game.Combat.CardEffect do
  # defstruct [:type, :value]

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

  @doc """
  Returns the list of parameter keys this effect requires.
  Each key corresponds to an entry in the stored value map and gets its own formula input in the admin.
  Defaults to [\"value\"] for simple single-value effects.
  """
  @spec params(t()) :: [String.t()]
  def params(card_effect)
end
