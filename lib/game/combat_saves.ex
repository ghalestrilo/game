defmodule Game.CombatSaves do
  use Agent

  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def save(session_id, %Game.CombatState{} = combat_state) do
    Agent.update(__MODULE__, &Map.put(&1, session_id, combat_state))
  end

  def load(session_id) do
    case Agent.get(__MODULE__, &Map.get(&1, session_id)) do
      nil -> {:error, :not_found}
      combat_state -> {:ok, combat_state}
    end
  end

  def delete(session_id) do
    Agent.update(__MODULE__, &Map.delete(&1, session_id))
  end
end
