---                                                                                                                                                                                                                                     
  Feature Milestones (chronological)
                                                                                                                                                                                                                                          
  1. Project Foundation (Mar 2025)                                                                                                                            
                                                                                                                                                                                                                                          
  Initial commit, docs, and a sketched hex grid component. The very beginning of the project.                                                                                                                                             
                                                                            
  2. Core Rules Engine (May 2025)                                                                                                                                                                                                         
                                                                                                                               
  Basic ruleset, game state, GenServer-backed game process, and a minimal LiveView to render the board. Docker setup included.                                                                                                            
                                                                                                                               
  3. Card System & Combat UI (May–Jun 2025)                                                                                                                                                                                               
                                                                                                                            
  Hand rendering, card picking/unpicking, card selection state machine, damage/healing demos, movement, and error reporting. The first playable combat loop.                                                                              
   
  4. Database Schema & Deck Management (Aug 2025)                                                                                                                                                                                         
                                                                                                                            
  basecards, basedeck, and base_deck_cards tables introduced. Card shuffling, multi-effect cards, seeds, and a Mix task to seed data. Action log and queue panel inspector added.                                                         
   
  5. Game State Serialization (Sep 2025)                                                                                                                                                                                                  
                                                                                                                               
  JSON encoders, encoded/decoded game state via URI, and state persistence — enabling game reload and session continuity.                                                                                                                 
                                                                                                                               
  6. Characters, Classes & Admin (Oct 2025)                                                                                                                                                                                               
                                                                                                                            
  Characters loaded from DB, characters admin panel, deck form with card counts, admin menu, effects edit UI, and a hexmap library swap. Summon effect added.                                                                             
   
  7. Campaign Mode & Shop (Dec 2025)                                                                                                                                                                                                      
                                                                                                                                                                                        
  /sandbox route, campaign flow (character select → combat → shop), shop dialog to buy and add cards to deck, deck inspector, shield and summon effects, and targeting rules per effect. Extensive test coverage added.                   
   
  8. Authentication & PVP Lobby (Apr 2026)                                                                                                                                                                                                
                                                                                                                                                                                        
  User authentication (Swoosh/Backpex), lobby build-out (class selection, ready toggle), full PVP working end-to-end, formula editor with recursive expression trees, targeting conditions, and parameterized values.                     
   
  9. Animations, HUD & Formula System (Apr–May 2026)                                                                                                                                                                                      
                                                                                                                                                                                        
  Floating HUD, multilayer rendering, float-up (+999) animations, formula aliases, procedurally generated values, stealth timer, AI in multiplayer, turn queue visual polish.                                                             
                                                                                                                                                                                        
  10. Rich Status Effects & Blast Mechanics (May 2026)                                                                                                                                                                                    
                                                                                                                                                                                        
  New effects: regen, cleanse, DoT, ethereal, self-destruct, move, slow, stuck, stun, modify-attribute. Blast radius mapping, AoE fixes, hotkeys (Enter to skip, card hotkeys), "hidden" HUD state, and barbarian/monk class seeds.       
                                                                                                                                                                                        
  11. Multiplayer Lobby & Card Rarity (May 2026)                                                                                                                                                                                          
                                                                                                                                                                                        
  Rarity borders on cards, visual effect indicators, clone feature, performance improvements, multiplayer lobby refinements, and PVP grouping.                                                                                            
   
  12. Booster Draft (May 2026 — current)                                                                                                                                                                                                  
                                                                                                                                                                                        
  Pile visibility, movement constraints, loading state for draft, and the booster drafting flow — allowing players to draft cards from booster packs.  