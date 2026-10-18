-- ============================================================
-- La Flaquita: migración de inventario y administración
-- Ejecutar en Supabase: SQL Editor > New query > Run
-- (Ejecutar DESPUÉS de schema.sql y seed.sql)
-- ============================================================

-- 1) Columnas de stock en productos
alter table productos
  add column if not exists controla_stock boolean not null default false,
  add column if not exists stock          int not null default 0,
  add column if not exists stock_minimo   int not null default 0;

-- Activar control de stock por defecto en bebidas embotelladas y cervezas
-- (La chicha morada y los platos de chicharrón/sarza quedan sin control por unidad)
update productos
set controla_stock = true,
    stock_minimo = case when stock_minimo = 0 then 6 else stock_minimo end
where categoria in ('bebida', 'cerveza')
  and nombre not like 'Chicha morada%';

-- 2) Tabla de administradores (solo los correos en esta tabla pueden administrar)
create table if not exists administradores (
  email      text primary key,
  creado_en  timestamptz not null default now()
);

-- Función para saber si el usuario autenticado actual es administrador
create or replace function es_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.administradores
    where lower(email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;

revoke all on function es_admin() from public;
grant execute on function es_admin() to authenticated;

-- 3) Tabla de movimientos de stock (kardex / historial de inventario)
create table if not exists stock_movimientos (
  id            bigint generated always as identity primary key,
  producto_id   bigint not null references productos(id) on delete cascade,
  tipo          text not null check (tipo in ('entrada', 'venta', 'anulacion', 'ajuste')),
  cantidad      int not null,          -- positivo si suma al stock, negativo si descuenta
  stock_antes   int not null,
  stock_despues int not null,
  venta_id      bigint references ventas(id) on delete set null,
  nota          text,
  creado_por    uuid references auth.users(id) default auth.uid(),
  creado_en     timestamptz not null default now()
);

create index if not exists idx_stock_mov_producto on stock_movimientos(producto_id, creado_en desc);
create index if not exists idx_stock_mov_fecha on stock_movimientos(creado_en desc);

-- 4) Función para registrar entradas de mercadería (o movimientos de stock del admin)
create or replace function aplicar_stock(
  p_producto_id bigint,
  p_cantidad int,
  p_nota text default null
) returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_antes int;
  v_despues int;
begin
  if not es_admin() then
    raise exception 'Solo el administrador puede registrar entradas de stock';
  end if;

  if p_cantidad is null or p_cantidad = 0 then
    raise exception 'La cantidad no puede ser 0';
  end if;

  select stock into v_antes
  from productos
  where id = p_producto_id
  for update;

  if not found then
    raise exception 'Producto no encontrado (id=%)' , p_producto_id;
  end if;

  v_despues := v_antes + p_cantidad;

  update productos
  set stock = v_despues,
      controla_stock = true
  where id = p_producto_id;

  insert into stock_movimientos (
    producto_id, tipo, cantidad, stock_antes, stock_despues, nota, creado_por
  ) values (
    p_producto_id,
    case when p_cantidad > 0 then 'entrada' else 'ajuste' end,
    p_cantidad,
    v_antes,
    v_despues,
    coalesce(nullif(trim(p_nota), ''), 'Entrada de mercadería'),
    auth.uid()
  );

  return v_despues;
end;
$$;

revoke all on function aplicar_stock(bigint, int, text) from public, anon;
grant execute on function aplicar_stock(bigint, int, text) to authenticated;

-- 5) Función para ajustar el stock según conteo físico
create or replace function ajustar_stock(
  p_producto_id bigint,
  p_stock_fisico int,
  p_nota text default 'Conteo físico'
) returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  v_antes int;
  v_delta int;
begin
  if not es_admin() then
    raise exception 'Solo el administrador puede ajustar el stock';
  end if;

  if p_stock_fisico is null then
    raise exception 'Debes indicar el conteo físico';
  end if;

  select stock into v_antes
  from productos
  where id = p_producto_id
  for update;

  if not found then
    raise exception 'Producto no encontrado (id=%)', p_producto_id;
  end if;

  v_delta := p_stock_fisico - v_antes;

  update productos
  set stock = p_stock_fisico,
      controla_stock = true
  where id = p_producto_id;

  insert into stock_movimientos (
    producto_id, tipo, cantidad, stock_antes, stock_despues, nota, creado_por
  ) values (
    p_producto_id,
    'ajuste',
    v_delta,
    v_antes,
    p_stock_fisico,
    coalesce(nullif(trim(p_nota), ''), 'Conteo físico'),
    auth.uid()
  );

  return p_stock_fisico;
end;
$$;

revoke all on function ajustar_stock(bigint, int, text) from public, anon;
grant execute on function ajustar_stock(bigint, int, text) to authenticated;

-- 6) Reemplazar registrar_venta para descontar stock automáticamente por cada línea
--    Permite vender aunque no haya stock suficiente (el stock puede quedar en negativo
--    y la app muestra un aviso al vendedor).
create or replace function registrar_venta(
  p_items jsonb,
  p_metodo_pago text default 'efectivo',
  p_canal text default 'local'
) returns bigint
language plpgsql
security definer
set search_path = public
as $$
declare
  v_id bigint;
  v_total numeric(8,2);
  v_item jsonb;
  v_prod_id bigint;
  v_cant int;
  v_precio numeric(6,2);
  v_antes int;
  v_despues int;
  v_controla boolean;
begin
  if auth.uid() is null then
    raise exception 'Debes iniciar sesión para registrar ventas';
  end if;

  if p_items is null or jsonb_array_length(p_items) = 0 then
    raise exception 'La venta no tiene productos';
  end if;

  insert into ventas (metodo_pago, canal, registrado_por)
  values (p_metodo_pago, p_canal, auth.uid())
  returning id into v_id;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_prod_id := (v_item ->> 'producto_id')::bigint;
    v_cant    := (v_item ->> 'cantidad')::int;
    v_precio  := (v_item ->> 'precio_unitario')::numeric;

    insert into venta_detalles (venta_id, producto_id, cantidad, precio_unitario)
    values (v_id, v_prod_id, v_cant, v_precio);

    select stock, controla_stock into v_antes, v_controla
    from productos
    where id = v_prod_id
    for update;

    if found and v_controla then
      v_despues := v_antes - v_cant;

      update productos
      set stock = v_despues
      where id = v_prod_id;

      insert into stock_movimientos (
        producto_id, tipo, cantidad, stock_antes, stock_despues, venta_id, nota, creado_por
      ) values (
        v_prod_id, 'venta', -v_cant, v_antes, v_despues, v_id, 'Venta #' || v_id, auth.uid()
      );
    end if;
  end loop;

  select coalesce(sum(cantidad * precio_unitario), 0) into v_total
  from venta_detalles where venta_id = v_id;

  update ventas set total = v_total where id = v_id;
  return v_id;
end;
$$;

revoke all on function registrar_venta(jsonb, text, text) from public, anon;
grant execute on function registrar_venta(jsonb, text, text) to authenticated;

-- 7) Trigger que devuelve el stock automáticamente al anular una venta
create or replace function ventas_anulacion() returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  r record;
  v_antes int;
  v_despues int;
begin
  if old.estado = 'anulada' and new.estado <> 'anulada' then
    raise exception 'Una venta anulada no se puede reactivar';
  end if;

  if new.estado = 'anulada' and old.estado <> 'anulada' then
    new.anulado_por := auth.uid();
    new.anulado_en := now();

    for r in
      select vd.producto_id, vd.cantidad
      from venta_detalles vd
      join productos p on p.id = vd.producto_id
      where vd.venta_id = new.id
        and p.controla_stock = true
    loop
      select stock into v_antes
      from productos
      where id = r.producto_id
      for update;

      v_despues := v_antes + r.cantidad;

      update productos
      set stock = v_despues
      where id = r.producto_id;

      insert into stock_movimientos (
        producto_id, tipo, cantidad, stock_antes, stock_despues, venta_id, nota, creado_por
      ) values (
        r.producto_id, 'anulacion', r.cantidad, v_antes, v_despues, new.id, 'Anulación venta #' || new.id, auth.uid()
      );
    end loop;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_anulacion on ventas;
create trigger trg_anulacion before update on ventas
for each row execute function ventas_anulacion();

-- ============================================================
-- 8) SEGURIDAD (RLS): permisos de administrador e inventario
-- ============================================================
alter table administradores   enable row level security;
alter table stock_movimientos enable row level security;

drop policy if exists "usuario consulta si es admin" on administradores;
create policy "usuario consulta si es admin" on administradores
  for select to authenticated
  using (lower(email) = lower(coalesce(auth.jwt() ->> 'email', '')) or es_admin());

drop policy if exists "admin lee movimientos" on stock_movimientos;
create policy "admin lee movimientos" on stock_movimientos
  for select to authenticated
  using (es_admin());

drop policy if exists "admin actualiza productos" on productos;
create policy "admin actualiza productos" on productos
  for update to authenticated
  using (es_admin())
  with check (es_admin());

drop policy if exists "admin crea productos" on productos;
create policy "admin crea productos" on productos
  for insert to authenticated
  with check (es_admin());
