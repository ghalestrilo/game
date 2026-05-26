# Invite to Lobby

## Overview

A player in a lobby can open an invite modal with two actions: copy a shareable link, or send
an in-app notification to another player by email. The notification is delivered over PubSub
to any LiveView session the invited user has open, where it appears as a flash-style popup.

---

## UI

### Invite Button

Add a prominent button to `LobbyLive` below the "Waiting for players…" status line (inside
the left column `fieldset`):

```heex
<button
  class="btn btn-secondary w-full"
  phx-click={show_modal("invite-modal")}
>
  <.icon name="hero-user-plus-solid" /> Invite Player
</button>
```

### Invite Modal

Use the existing `<.modal>` component from `CoreComponents`. Place it at the bottom of
`render/1`, outside the main grid:

```heex
<.modal id="invite-modal">
  <h2 class="text-2xl font-bold mb-6">Invite a Player</h2>

  <%# --- Copy link section --- %>
  <p class="fieldset-label mb-2">Share lobby link</p>
  <div class="join w-full mb-6">
    <input
      id="lobby-link-input"
      type="text"
      readonly
      value={url(~p"/multiplayer/#{@lobby_id}")}
      class="join-item input input-bordered flex-1"
    />
    <button
      class="join-item btn btn-neutral"
      phx-hook="CopyToClipboard"
      data-target="lobby-link-input"
      id="copy-lobby-link-btn"
    >
      <.icon name="hero-clipboard-solid" /> Copy
    </button>
  </div>

  <%# --- Email invite section --- %>
  <p class="fieldset-label mb-2">Send invite notification</p>
  <form phx-submit="send_invite" class="join w-full">
    <input
      type="email"
      name="email"
      placeholder="player@example.com"
      required
      class="join-item input input-bordered flex-1"
    />
    <button type="submit" class="join-item btn btn-primary">
      <.icon name="hero-paper-airplane-solid" /> Send Invite
    </button>
  </form>
  <%= if @invite_feedback do %>
    <p class="mt-3 text-sm text-success">{@invite_feedback}</p>
  <% end %>
</.modal>
```

---

## PubSub Channel

Add an invite-specific subscription to `Game.Lobby`:

```elixir
# lib/game/lobby.ex

def subscribe_invites(user_email) do
  Phoenix.PubSub.subscribe(Game.PubSub, "invites:#{user_email}")
end

def broadcast_invite(to_email, from_email, lobby_id) do
  Phoenix.PubSub.broadcast(
    Game.PubSub,
    "invites:#{to_email}",
    {:invited, %{from: from_email, lobby_id: lobby_id}}
  )
end
```

Topic: `"invites:<email>"` — unique per user, requires no server-side process, survives
across lobbies.

---

## LobbyLive Changes

### mount/3

1. Subscribe to the invite channel for the current user.
2. Add `invite_feedback: nil` to initial assigns.

```elixir
Lobby.subscribe(id)
Lobby.subscribe_invites(user.email)   # <-- add

assign(socket,
  ...,
  invite_feedback: nil
)
```

### handle_event("send_invite")

```elixir
@impl true
def handle_event("send_invite", %{"email" => email}, socket) do
  from = socket.assigns.current_scope.user.email
  Lobby.broadcast_invite(email, from, socket.assigns.lobby_id)
  {:noreply, assign(socket, invite_feedback: "Invite sent to #{email}")}
end
```

No validation against registered users — if the target email has no active LiveView session,
the broadcast is a no-op.

### handle_info({:invited, ...})

```elixir
@impl true
def handle_info({:invited, %{from: from, lobby_id: lobby_id}}, socket) do
  {:noreply,
   socket
   |> put_flash(:info, "#{from} invited you to a lobby!")
   |> push_event("lobby_invite", %{from: from, lobby_id: lobby_id})}
end
```

`put_flash/3` renders the built-in flash banner — no extra component needed. The
`push_event` is optional and can drive a richer JS popup later if desired.

---

## MultiplayerLive

Any LiveView behind a session can receive the invite. Subscribe in `MultiplayerLive` too so
players browsing the lobby list also get notified:

```elixir
# lib/game_web/live/multiplayer_live.ex

def mount(_params, _session, socket) do
  if connected?(socket) do
    Lobby.subscribe_invites(socket.assigns.current_scope.user.email)
  end
  ...
end

def handle_info({:invited, %{from: from, lobby_id: lobby_id}}, socket) do
  {:noreply,
   socket
   |> put_flash(:info, "#{from} invited you!")
   |> push_navigate(to: ~p"/multiplayer/#{lobby_id}")}
  # or just put_flash and let the player click themselves
end
```

---

## JS Hook: CopyToClipboard

Add a small hook in `assets/js/hooks/`:

```js
// assets/js/hooks/CopyToClipboard.js
const CopyToClipboard = {
  mounted() {
    this.el.addEventListener("click", () => {
      const target = document.getElementById(this.el.dataset.target)
      navigator.clipboard.writeText(target.value)
      const original = this.el.innerHTML
      this.el.innerHTML = "Copied!"
      setTimeout(() => { this.el.innerHTML = original }, 1500)
    })
  }
}

export default CopyToClipboard
```

Register it in `app.js`:

```js
import CopyToClipboard from "./hooks/CopyToClipboard"

let liveSocket = new LiveSocket("/live", Socket, {
  hooks: { ...BackpexHooks, CharacterEffects, BoardTileClasses, ThreeJS, ThreeJSBoard, CopyToClipboard }
})
```

---

## Notes

- **No server roundtrip for copy** — the hook reads the input value directly; the server never
  touches the clipboard action.
- **No email delivery** — this is an in-app PubSub notification only. If the recipient has no
  active session, the invite is silently dropped. Actual email delivery (Swoosh, etc.) is out
  of scope.
- **`invite_feedback` resets on next mount** — it is not persisted. Sending a second invite
  overwrites it, which is fine.
- **`url/1` helper** — `url(~p"/multiplayer/#{@lobby_id}")` produces a full absolute URL
  (scheme + host) suitable for sharing. Available in LiveView via `Phoenix.VerifiedRoutes`.
