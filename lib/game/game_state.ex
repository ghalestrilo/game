defmodule Game.GameState do
  @moduledoc """
  Represents the overall game state including campaign, current view, and combat.
  """

  alias Game.CombatState

  @derive Jason.Encoder

  defstruct [
    :current_view,
    :campaign,
    :combat
  ]

  @type view :: :combat | :shop
  @type campaign :: %{
          character: Game.Character.t(),
          player: %{name: String.t()}
        }

  @type t :: %__MODULE__{
          current_view: view(),
          campaign: campaign(),
          combat: CombatState.t()
        }
end
