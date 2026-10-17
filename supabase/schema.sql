-- ============================================================
-- La Flaquita: esquema de la base de datos (Supabase / PostgreSQL)
-- Ejecutar completo en: SQL Editor > New query > Run
-- ============================================================

-- 1) PRODUCTOS (la carta). La web y la app leen de aquí.
create table if not exists productos (
  id          bigint generated always as identity primary key,
  nombre      text not null unique,
  categoria   text not null check (categoria in ('chicharron','sarza','combinado','bebida','cerveza','otro')),
  precio      numeric(6,2) not null check (precio >= 0),
  activo      boolean not null default true,   -- false = no se vende (agotado o retirado)
  visible_web boolean not null default true,   -- false = no aparece en la página pública
  orden       int not null default 0,
  creado_en   timestamptz not null default now()
);

-- 2) VENTAS (cabecera: una fila por pedido/cobro)
create table if not exists ventas (
  id            bigint generated always as identity primary key,
  fecha         date not null default ((now() at time zone 'America/Lima')::date),
  hora          timestamptz not null default now(),
  metodo_pago   text not null default 'efectivo'
                  check (metodo_pago in ('efectivo','yape','plin','tarjeta','transferencia')),
  canal         text not null default 'local' check (canal in ('local','web','delivery')),
  estado        text not null default 'valida' check (estado in ('valida','anulada')),
  total         numeric(8,2) not null default 0,
  registrado_por uuid references auth.users(id) default auth.uid(),
  anulado_por   uuid references auth.users(id),
  anulado_en    timestamptz
);

-- 3) VENTA_DETALLES (cada producto de una venta, con el precio del momento)
create table if not exists venta_detalles (
  id              bigint generated always as identity primary key,
  venta_id        bigint not null references ventas(id) on delete cascade,
  producto_id     bigint not null references productos(id),
  cantidad        int not null check (cantidad > 0),
  precio_unitario numeric(6,2) not null check (precio_unitario >= 0)
);

create index if not exists idx_ventas_fecha on ventas(fecha);
create index if not exists idx_detalles_venta on venta_detalles(venta_id);

-- 4) Función para registrar una venta completa en una sola operación.
--    Si algo falla, no queda una venta a medias.
create or replace function registrar_venta(
  p_items jsonb,
  p_metodo_pago text default 'efectivo',
  p_canal text default 'local'
) returns bigint
language plpgsql
security invoker   -- respeta las reglas de acceso (RLS) del usuario que llama
as $$
declare
  v_id bigint;
  v_total numeric(8,2);
begin
  if p_items is null or jsonb_array_length(p_items) = 0 then
    raise exception 'La venta no tiene productos';
  end if;

  insert into ventas (metodo_pago, canal)
  values (p_metodo_pago, p_canal)
  returning id into v_id;

  insert into venta_detalles (venta_id, producto_id, cantidad, precio_unitario)
  select v_id,
         (x->>'producto_id')::bigint,
         (x->>'cantidad')::int,
         (x->>'precio_unitario')::numeric
  from jsonb_array_elements(p_items) as x;

  select coalesce(sum(cantidad * precio_unitario), 0) into v_total
  from venta_detalles where venta_id = v_id;

  update ventas set total = v_total where id = v_id;
  return v_id;
end;
$$;

-- 5) Al anular una venta se guarda quién y cuándo (auditoría).
--    Las ventas no se borran: solo se anulan.
create or replace function ventas_anulacion() returns trigger
language plpgsql as $$
begin
  if new.estado = 'anulada' and old.estado <> 'anulada' then
    new.anulado_por := auth.uid();
    new.anulado_en := now();
  end if;
  return new;
end;
$$;

drop trigger if exists trg_anulacion on ventas;
create trigger trg_anulacion before update on ventas
for each row execute function ventas_anulacion();

-- ============================================================
-- SEGURIDAD (RLS): quién puede hacer qué
-- ============================================================
alter table productos      enable row level security;
alter table ventas         enable row level security;
alter table venta_detalles enable row level security;

-- La web pública solo puede leer productos activos y visibles en web.
create policy "carta publica" on productos
  for select to anon using (activo and visible_web);

-- El personal logueado puede leer toda la carta, pero no editarla desde la app.
-- Los precios se cambian desde el panel de Supabase (Table Editor).
create policy "personal lee productos" on productos
  for select to authenticated using (true);

-- El personal registra y consulta ventas. No hay permiso para borrar.
create policy "personal lee ventas" on ventas
  for select to authenticated using (true);
create policy "personal crea ventas" on ventas
  for insert to authenticated with check (true);
create policy "personal anula ventas" on ventas
  for update to authenticated using (true) with check (true);

create policy "personal lee detalles" on venta_detalles
  for select to authenticated using (true);
create policy "personal crea detalles" on venta_detalles
  for insert to authenticated with check (true);
