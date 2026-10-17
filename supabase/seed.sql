-- ============================================================
-- Carta de La Flaquita (según la carta impresa).
-- Ejecutar DESPUÉS de schema.sql. Se puede volver a ejecutar sin duplicar.
-- ============================================================
insert into productos (nombre, categoria, precio, orden) values
  -- Chicharrones
  ('Chicharrón Taypa',                 'chicharron', 20,    10),
  ('Chicharrón plato normal',          'chicharron', 17,    11),
  ('Chicharrón 1 porción',             'chicharron', 15,    12),
  ('Chicharrón ½ porción',             'chicharron', 10,    13),
  -- Combinados
  ('Combinado Taypa con sarza',        'combinado',  20,    20),
  -- Sarza
  ('Sarza de cabeza',                  'sarza',      15,    30),
  ('Sarza ½ porción',                  'sarza',      10,    31),
  -- Chicha morada
  ('Chicha morada ½ litro',            'bebida',     3.50,  40),
  ('Chicha morada 1 litro',            'bebida',     7,     41),
  ('Chicha morada de cortesía',        'bebida',     0,     42),
  -- Coca / Inca Kola
  ('Coca 400 ml',                      'bebida',     2.50,  50),
  ('Inca 400 ml',                      'bebida',     2.50,  51),
  ('Coca 625 ml',                      'bebida',     4.50,  52),
  ('Inca 625 ml',                      'bebida',     4.50,  53),
  ('Coca ½ litro',                     'bebida',     4,     54),
  ('Inca ½ litro',                     'bebida',     4,     55),
  ('Coca 1 litro',                     'bebida',     7,     56),
  ('Inca 1 litro',                     'bebida',     7,     57),
  ('Coca 1½ litros',                   'bebida',     9,     58),
  ('Inca 1½ litros',                   'bebida',     9,     59),
  ('Coca 2½ litros',                   'bebida',     12,    60),
  ('Inca 2½ litros',                   'bebida',     12,    61),
  ('Coca 3 litros',                    'bebida',     15,    62),
  ('Inca 3 litros',                    'bebida',     15,    63),
  -- Escocesa
  ('Escocesa personal (vidrio)',       'bebida',     4,     70),
  ('Escocesa ½ litro',                 'bebida',     4,     71),
  ('Escocesa 1 litro (vidrio)',        'bebida',     8,     72),
  ('Escocesa 1½ litros',               'bebida',     10,    73),
  ('Escocesa 2 litros',                'bebida',     12,    74),
  -- Agua
  ('Agua (Cielo, San Luis)',           'bebida',     2,     80),
  -- Cervezas
  ('Heineken',                         'cerveza',    8,     90),
  ('Arequipeña',                       'cerveza',    10,    91),
  ('Pilsen',                           'cerveza',    10,    92),
  ('Trigo',                            'cerveza',    10,    93),
  ('Negra',                            'cerveza',    11,    94)
on conflict (nombre) do nothing;   -- no pisa precios que hayas cambiado después
