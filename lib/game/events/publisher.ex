defmodule Game.Events.Publisher do
  def publish_game_over(combat) do
    payload =
      Jason.encode!(%{
        event: "game_over",
        winning_team: winning_team(combat),
        characters_by_team: characters_by_team(combat)
      })

    publish("game_over", payload)
  end

  defp winning_team(%{queue: chars}) do
    chars
    |> Enum.find(&(!&1.dead))
    |> case do
      nil -> nil
      char -> char.team
    end
  end

  defp characters_by_team(%{queue: chars}) do
    Enum.group_by(chars, & &1.team, &Map.take(&1, [:id, :name, :class, :dead]))
  end

  defp publish(routing_key, json) do
    case Application.fetch_env(:game, :rabbitmq) do
      :error -> :ok
      {:ok, cfg} -> do_publish(cfg, routing_key, json)
    end
  end

  defp do_publish(cfg, routing_key, json) do
    with {:ok, conn} <- AMQP.Connection.open(cfg[:url]),
         {:ok, chan} <- AMQP.Channel.open(conn) do
      AMQP.Exchange.declare(chan, cfg[:exchange], :topic, durable: true)

      AMQP.Basic.publish(chan, cfg[:exchange], routing_key, json,
        content_type: "application/json",
        persistent: true
      )

      AMQP.Connection.close(conn)
    end
  end
end
