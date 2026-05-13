defmodule GameWeb.Router do
  use GameWeb, :router

  import GameWeb.UserAuth

  import Backpex.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {GameWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", GameWeb do
    pipe_through :browser

    get "/", PageController, :home

    live_session :game, layout: {GameWeb.Layouts, :game} do
      live "/sandbox", GameLive, :sandbox
      live "/campaign/play", GameLive, :campaign
    end

    live "/campaign/character-select", Campaign.CharacterSelectLive
    live "/sandbox/setup", SandboxSetupLive

    # Catch-all: redirect any other /campaign/* routes to character select
    live "/campaign/*path", Campaign.CatchAllLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", GameWeb do
  #   pipe_through :api
  # end
  #
  scope "/admin", GameWeb do
    pipe_through [:browser, :require_authenticated_user, :require_admin]

    backpex_routes()

    live_session :admin,
      on_mount: [
        {GameWeb.UserAuth, :require_authenticated},
        {GameWeb.UserAuth, :require_admin},
        Backpex.InitAssigns
      ] do
      live "/", Admin.HomeLive

      live_resources "/base_cards", Admin.BaseCardLive
      live_resources "/base_decks", Admin.BaseDeckLive
      live_resources "/base_classes", Admin.BaseClassLive
      live_resources "/formula_aliases", Admin.FormulaAliasLive
      live_resources "/strategies", Admin.StrategyLive
      live_resources "/maps", Admin.MapLive
      live "/maps/:id/edit-map", Admin.MapEditorLive
    end
  end

  # Test routes (only available in test environment)
  scope "/", GameWeb do
    pipe_through :browser

    live "/formula-editor-test", FormulaEditorTestLive
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:game, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: GameWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", GameWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{GameWeb.UserAuth, :require_authenticated}] do
      live "/users/settings", UserLive.Settings, :edit
      live "/users/settings/confirm-email/:token", UserLive.Settings, :confirm_email
    end

    live_session :require_authenticated_multiplayer,
      on_mount: [{GameWeb.UserAuth, :require_authenticated}] do
      live "/multiplayer", MultiplayerLive
      live "/multiplayer/:id", LobbyLive
      live "/multiplayer/:id/play", GameLive, :pvp
    end

    post "/users/update-password", UserSessionController, :update_password
  end

  scope "/", GameWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{GameWeb.UserAuth, :mount_current_scope}] do
      live "/users/register", UserLive.Registration, :new
      live "/users/log-in", UserLive.Login, :new
      live "/users/log-in/:token", UserLive.Confirmation, :new
    end

    post "/users/log-in", UserSessionController, :create
    delete "/users/log-out", UserSessionController, :delete
  end
end
