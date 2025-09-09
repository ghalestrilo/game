# Script to capture the initial combat state encoded string
alias Game.CombatState.StateSave

# Get characters from fixtures with their decks
warrior = Game.Fixtures.warrior()
mage = Game.Fixtures.mage()

# Set positions that work well in a hex grid
warrior = %{warrior | position: {0, 0, 0}}
mage = %{mage | position: {2, -1, -1}}

# Draw initial cards for warrior only (first player)
# The mage will draw cards when their turn starts
warrior_with_cards = Game.Character.draw_cards(warrior, 5)
# No cards initially for second player
mage_with_cards = mage

updated_players = [warrior_with_cards, mage_with_cards]

# Create a proper hex grid with radius 2 (creates a balanced grid)
grid = Game.Grid.new({2, 2, 2})

# Update the grid with our characters
grid = Game.Grid.update_character(grid, warrior_with_cards)
grid = Game.Grid.update_character(grid, mage_with_cards)

# Create combat struct with proper state
combat = %Game.CombatState{
  state: :running,
  __constants__: %{
    players: updated_players
  },
  queue: updated_players,
  grid: grid,
  current_turn: %{
    starting_position: warrior_with_cards.position,
    player: warrior_with_cards,
    card: nil
  }
}

# Encode the combat state
encoded_state = StateSave.encode(combat)

# Print the encoded state
IO.puts("Encoded initial game state:")
IO.puts(encoded_state)

# Verify that decoding works
{:ok, decoded_state} = StateSave.decode(encoded_state)
IO.inspect(decoded_state, label: "Decoded state")
