                                                                                                                                                                                                                                        
  INSERT INTO formula_aliases (name, description, expression, inserted_at, updated_at) VALUES                                                                                                                                             
    ('self',             'Target is the caster',                     '{"===": [{"var": "caster.id"}, {"var": "target.id"}]}',                                              NOW(), NOW()),
    ('not_self',         'Target is not the caster',                 '{"!": [{"===": [{"var": "caster.id"}, {"var": "target.id"}]}]}',                                     NOW(), NOW()),                                                 
    ('ally',             'Target is on the same team as caster',     '{"===": [{"var": "caster.team"}, {"var": "target.team"}]}',                                          NOW(), NOW()),                                                 
    ('enemy',            'Target is on a different team from caster','{"!==": [{"var": "caster.team"}, {"var": "target.team"}]}',                                          NOW(), NOW()),                                                 
    ('target_alive',     'Target has HP above zero',                 '{">":[{"var":"target.hp"},0]}',                                                                      NOW(), NOW()),                                                 
    ('target_enemy_alive','Target is an enemy with HP above zero',   '{"and":[{"!==": [{"var": "caster.team"}, {"var": "target.team"}]}, {">": [{"var": "target.hp"}, 0]}]}', NOW(), NOW()),                                              
    ('target_ally_alive','Ta
    rget is an ally with HP above zero',     '{"and":[{"===": [{"var": "caster.team"}, {"var": "target.team"}]}, {">": [{"var": "target.hp"}, 0]}]}', NOW(), NOW()),                                              
    ('target_self',      'Target is only the caster themselves',     '{"===": [{"var": "caster.id"}, {"var": "target.id"}]}',                                              NOW(), NOW()),                                                 
    ('caster_missing_hp','How much HP the caster is missing',        '{"-": [{"var": "caster.max_hp"}, {"var": "caster.hp"}]}',                                            NOW(), NOW()),                                                 
    ('target_missing_hp','How much HP the target is missing',        '{"-": [{"var": "target.max_hp"}, {"var": "target.hp"}]}',                                            NOW(), NOW()),                                                 
    ('caster_hp_percent','Caster current HP as a fraction of max',   '{"/": [{"var": "caster.hp"}, {"var": "caster.max_hp"}]}',                                            NOW(), NOW()),                                                 
    ('target_hp_percent','Target current HP as a fraction of max',   '{"/": [{"var": "target.hp"}, {"var": "target.max_hp"}]}',                                            NOW(), NOW()),                                                 
    ('target_below_half','Target HP is below 50%',                   '{"<": [{"var": "target.hp"}, {"/": [{"var": "target.max_hp"}, 2]}]}',                               NOW(), NOW());                                                  
                                                                                                                                                                                                                             













INSERT INTO formula_aliases (name, description, expression, inserted_at, updated_at) VALUES                                                                                                                                             
    -- ('caster_hand_size',      'Number of cards in caster hand',      '{"reduce":[{"map":[{"var":["caster.cards.hand"]},{"*":[1,1]}]},{"+": [  {"var": "current"},  {"var": "accumulator"}  ]},0]}', NOW(), NOW()),
    ('caster_graveyard_size', 'Number of cards in caster graveyard', '{"reduce":[{"var":["caster.cards.graveyard"]},{"+": [  {"var": "current"},  1  ]},0]}',                                       NOW(), NOW()),
    ('caster_draw_size',      'Number of cards in caster draw',      '{"reduce":[{"var":["caster.cards.draw"]},{"+": [  {"var": "current"},  1  ]},0]}',                                            NOW(), NOW()),
    ('target_hand_size',      'Number of cards in target hand',      '{"reduce":[{"map":[{"var":["target.cards.hand"]},{"*":[1,1]}]},{"+": [  {"var": "current"},  {"var": "accumulator"}  ]},0]}', NOW(), NOW()),
    -- ('target_graveyard_size', 'Number of cards in target graveyard', '{"reduce":[{"var":["target.cards.graveyard"]},{"+": [  {"var": "current"},  1  ]},0]}',                                       NOW(), NOW())
    ('target_draw_size',      'Number of cards in target draw',      '{"reduce":[{"var":["target.cards.draw"]},{"+": [  {"var": "current"},  1  ]},0]}',                                            NOW(), NOW()),
;



INSERT INTO formula_aliases (name, description, expression, inserted_at, updated_at) VALUES                                                                 
    ('count',                 'Expression to be used inside recude, counting the items in a list',                  '{"+": [  {"var": "accumulator"},  1  ]}',      NOW(), NOW()),
    )                                                                            
    ('caster_hand_size',      'Number of cards in caster hand',      '{"reduce":[{"var":["target.cards.hand"]},      {"+": [  {"var": "accumulator"},  1  ]}, 0]}', NOW(), NOW()),
    ('caster_graveyard_size', 'Number of cards in caster graveyard', '{"reduce":[{"var":["caster.cards.graveyard"]}, {"+": [  {"var": "accumulator"},  1  ]}, 0]}', NOW(), NOW()),
    ('caster_draw_size',      'Number of cards in caster draw',      '{"reduce":[{"var":["caster.cards.draw"]},      {"+": [  {"var": "accumulator"},  1  ]}, 0]}', NOW(), NOW()),
    ('target_hand_size',      'Number of cards in target hand',      '{"reduce":[{"var":["target.cards.hand"]},      {"+": [  {"var": "accumulator"},  1  ]}, 0]}', NOW(), NOW()),
    ('target_graveyard_size', 'Number of cards in target graveyard', '{"reduce":[{"var":["target.cards.graveyard"]}, {"+": [  {"var": "accumulator"},  1  ]}, 0]}', NOW(), NOW())
    ('target_draw_size',      'Number of cards in target draw',      '{"reduce":[{"var":["target.cards.draw"]},      {"+": [  {"var": "accumulator"},  1  ]}, 0]}', NOW(), NOW())
;