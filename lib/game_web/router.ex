defmodule GameWeb.Router do
  use GameWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {GameWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", GameWeb do
    pipe_through :browser

    get "/", PageController, :home
    live "/game", GameLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", GameWeb do
  #   pipe_through :api
  # end
  #
  scope "/admin", GameWeb do
    pipe_through :browser

    live "/", Admin.AdminMenuLive

    live "/basecards", BaseCardLive.Index, :index
    live "/basecards/new", BaseCardLive.Index, :new
    live "/basecards/:id/edit", BaseCardLive.Index, :edit

    live "/basecards/:id", BaseCardLive.Show, :show
    live "/basecards/:id/show/edit", BaseCardLive.Show, :edit

    live "/basedecks", BaseDeckLive.Index, :index
    live "/basedecks/new", BaseDeckLive.Index, :new
    live "/basedecks/:id/edit", BaseDeckLive.Index, :edit

    live "/basedecks/:id", BaseDeckLive.Show, :show
    live "/basedecks/:id/show/edit", BaseDeckLive.Show, :edit

    live "/base_classes", BaseClassLive.Index, :index
    live "/base_classes/new", BaseClassLive.Index, :new
    live "/base_classes/:id/edit", BaseClassLive.Index, :edit

    live "/base_classes/:id", BaseClassLive.Show, :show
    live "/base_classes/:id/show/edit", BaseClassLive.Show, :edit
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
end
