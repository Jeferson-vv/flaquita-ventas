# La Flaquita: app de ventas e inventario con Supabase

## Archivos

- `index.html`: la app de ventas (login, ventas por voz o texto, historial, dashboard y avisos de stock).
- `admin.html`: página de administración (precios, productos activos, control de stock, entradas de mercadería, conteos físicos y últimos movimientos).
- `parser.js`: entiende lo que se dice o escribe ("dos chicharrones de 20 y una coca de 1 litro").
- `sw.js`, `manifest.json`, `icon-*.png`: para instalarla en el celular.
- `supabase/schema.sql`: crea las tablas base (`productos`, `ventas`, `venta_detalles`), reglas de acceso y función `registrar_venta`.
- `supabase/seed.sql`: carga la carta (35 productos).
- `supabase/inventario.sql`: agrega control de stock en bebidas, tabla `stock_movimientos`, tabla `administradores`, funciones `aplicar_stock`, `ajustar_stock`, `es_admin`, descuento automático al vender y devolución automática al anular.

## Paso 1: crear la cuenta y el proyecto en Supabase

1. Entra a **supabase.com** y toca **Start your project**. Puedes crear la cuenta con GitHub o con correo.
2. Crea una organización (plan **Free**), por ejemplo "La Flaquita".
3. Toca **New project** y completa:
   - **Name:** flaquita-ventas
   - **Database password:** una contraseña fuerte. Guárdala en un lugar seguro.
   - **Region:** South America (São Paulo), la más cercana a Perú.
4. Espera 1 a 2 minutos a que el proyecto esté listo.

## Paso 2: crear las tablas, cargar la carta y activar el inventario

1. En el menú izquierdo de Supabase, abre **SQL Editor** y toca **New query**.
2. Abre `supabase/schema.sql`, copia todo, pégalo y toca **Run**.
3. Repite con `supabase/seed.sql`.
4. Repite con `supabase/inventario.sql` (agrega las columnas de stock, movimientos y permisos de administrador).
5. Verifica en **Table Editor**: deben aparecer `productos` (35 filas), `ventas`, `venta_detalles`, `stock_movimientos` y `administradores`.

## Paso 3: conectar la app

1. Ve a **Project Settings > API** (ícono de engranaje).
2. Copia **Project URL** y la clave **anon public**.
3. Verifica que `CONFIG` al inicio de `index.html` y `admin.html` tenga esos valores:

```js
const CONFIG = {
  url: 'https://xxxxxxxx.supabase.co',   // tu Project URL
  key: 'eyJhbGciOi...'                   // tu clave anon public
};
```

La clave anon es pública por diseño. Lo que protege los datos son las reglas (RLS) del esquema. **Nunca** pongas la clave `service_role` en el HTML ni en el repositorio.

## Paso 4: crear usuarios (vendedores y administrador)

1. Ve a **Authentication > Users** y toca **Add user > Create new user**.
2. Crea el usuario de quien anota las ventas (marcando **Auto Confirm User**).
3. Crea también el usuario del **administrador** (o usa tu propio correo si ya lo creaste).
4. En **Authentication > Sign In / Providers** (o Settings), desactiva **Allow new users to sign up**. Así nadie más puede crear una cuenta.

## Paso 5: registrar el correo del administrador

Solo el correo registrado en la tabla `administradores` puede entrar a `admin.html`, cambiar precios o ajustar el stock. Los usuarios que anotan ventas no pueden modificar precios ni inventario.

1. En Supabase, abre **SQL Editor > New query** y ejecuta (cambiando el correo por el tuyo):

```sql
insert into administradores (email)
values ('tu-correo-admin@ejemplo.com')
on conflict (email) do nothing;
```

*(También puedes agregarlo directamente en **Table Editor > administradores > Insert row**).*

## Paso 6: usar la página de administración (`admin.html`)

Entra a `https://flaquita-ventas.netlify.app/admin.html` (o toca el botón **⚙️ Admin** arriba a la derecha en la app si ingresaste con la cuenta de administrador):

1. **📦 Stock y Entradas:**
   - **Registrar entrada (compra):** elige la bebida/cerveza, escribe cuántas unidades llegaron (ej. `24`) y toca **Sumar al stock**.
   - **Conteo físico (ajuste):** elige el producto, escribe cuántas unidades contaste realmente en tienda y toca **Guardar conteo físico**. El sistema calcula la diferencia automáticamente y guarda el movimiento.
   - También puedes usar los botones rápidos **+ Entrada** y **Conteo** en cada fila de la lista.
2. **🍽️ Carta y Precios:**
   - Cambia el **Precio (S/)**, el **Stock mínimo** (para alertas de stock bajo), si el producto está **Activo (en venta)**, **Visible web** o si **Controla stock**, y toca **Guardar**.
   - Los nombres de los productos no se editan para que el reconocimiento de voz (`parser.js`) siga funcionando sin fallos.
3. **🕓 Movimientos:**
   - Consulta el historial de entradas, ventas, anulaciones y conteos físicos con fecha, hora y stock antes/después.

## Cómo funciona el stock en las ventas

- Cada vez que se registra una venta en `index.html`, los productos con `controla_stock = true` (bebidas embotelladas y cervezas) descuentan su stock automáticamente.
- Si una bebida se queda sin stock (0 o negativo) o llega al stock mínimo, **la venta se guarda igual** y la app muestra un aviso inmediato indicando cuánto queda.
- Si se usa **↩ Anular última venta**, un trigger en la base de datos devuelve automáticamente el stock descontado y lo registra en `stock_movimientos`.
- Los chicharrones quedan sin control de stock por unidad (descuentan insumos en una segunda etapa).

## Notas

- Las ventas no se borran: solo se anulan y queda registrado quién y cuándo la anuló.
- Cada venta guarda el precio del momento. Si luego cambias un precio en `admin.html`, las ventas anteriores no cambian.
- No vuelvas a ejecutar `seed.sql` si no es necesario (usa `on conflict do nothing`, por lo que no pisa precios existentes).
