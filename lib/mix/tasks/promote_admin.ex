defmodule Mix.Tasks.Game.PromoteAdmin do
  use Mix.Task

  @shortdoc "Promotes a user to admin by email"

  @impl Mix.Task
  def run([email]) do
    case Game.Accounts.get_user_by_email(email) do
      nil ->
        Mix.shell().error("No user found with email: #{email}")

      user ->
        user
        |> Ecto.Changeset.change(role: "admin")
        |> Game.Repo.update!()

        Mix.shell().info("#{email} promoted to admin")
    end
  end

  def run(_) do
    Mix.shell().error("Usage: mix Game.promote_admin <email>")
  end
end
