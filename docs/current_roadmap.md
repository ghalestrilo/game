## Roadmap

### Instructions

This is a current summary of our roadmap for the game.

The way to process this document is: Read the item at the top of the list and its child items. This describes the scope of a feature. Remove it from the list, investigate the feature closely, then output a markdown plan for implementing it under the `docs/features` subfolder.

Once the plan is written, revisit this document and do the exact same process again, unless the list is empty.

## Feature list.

1. push_content_sync should use insert_all
4. universes should exist (capturing cards, etc)
5. cards should have `:class` to appear in boosters
  - picking up a booster on the map should trigger a class select (player's class + 2 random additionals)
6. cards to add _permanently_ or _temporarily_ add cards to other player's hands
7. implement `scry` and `dredge` effects
  - implement card actions in card view dialog
8. orbital coordinate helper (arrows)
9. additional key support:
  - "esc" when selecting a card
  - "left/right" when selecting a card
  - up/down (make header sticky) cycling through targets
  - highlighting selected targets
10. UI
  - Improve landing
  - use Fieldsets for:
    - Card effects
    - lobby settings
11. Card mechanics:
  - calculation based on _number of cards played this turn_
12. reaction cards