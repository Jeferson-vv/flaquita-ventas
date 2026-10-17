# La Flaquita: app de ventas con Supabase

## Archivos

- `index.html`: la app (login, ventas por voz o texto, historial, dashboard).
- `parser.js`: entiende lo que se dice o escribe ("dos chicharrones de 20 y una coca de 1 litro").
- `sw.js`, `manifest.json`, `icon-*.png`: para instalarla en el celular.
- `supabase/schema.sql`: crea las tablas, las reglas de acceso y la función de registro.
- `supabase/seed.sql`: carga la carta (35 productos).

## Paso 1: crear la cuenta y el proyecto en Supabase

1. Entra a **supabase.com** y toca **Start your project**. Puedes crear la cuenta con GitHub o con correo.
2. Crea una organización (plan **Free**), por ejemplo "La Flaquita".
3. Toca **New project** y completa:
   - **Name:** flaquita-ventas
   - **Database password:** una contraseña fuerte. Guárdala en un lugar seguro.
   - **Region:** South America (São Paulo), la más cercana a Perú.
4. Espera 1 a 2 minutos a que el proyecto esté listo.

## Paso 2: crear las tablas y cargar la carta

1. En el menú izquierdo, abre **SQL Editor** y toca **New query**.
2. Abre `supabase/schema.sql` en un editor de texto, copia todo, pégalo y toca **Run**.
3. Repite con `supabase/seed.sql`.
4. Verifica en **Table Editor**: debe aparecer la tabla `productos` con 35 filas.

## Paso 3: conectar la app

1. Ve a **Project Settings > API** (ícono de engranaje).
2. Copia **Project URL** y la clave **anon public**.
3. Abre `index.html` y reemplaza los valores de `CONFIG` al inicio:

```js
const CONFIG = {
  url: 'https://xxxxxxxx.supabase.co',   // tu Project URL
  key: 'eyJhbGciOi...'                   // tu clave anon public
};
```

La clave anon es pública por diseño. Lo que protege los datos son las reglas (RLS) del esquema. **Nunca** pongas la clave `service_role` en la app.

## Paso 4: crear el usuario de quien registra ventas

1. Ve a **Authentication > Users** y toca **Add user > Create new user**.
2. Escribe el correo y la contraseña de la persona que anota las ventas.
3. Marca **Auto Confirm User** para que no tenga que confirmar el correo.
4. Para cada persona adicional, repite este paso. Así cada venta queda con el nombre de quien la registró.
5. En **Authentication > Sign In / Providers** (o Settings), desactiva **Allow new users to sign up**. Así nadie más puede crear una cuenta.

## Paso 5: publicar en Netlify

Vuelve a subir la carpeta (o el zip) a tu sitio en Netlify, como ya lo hiciste antes. La app nueva reemplaza a la anterior.

## Cambiar precios o productos

No hace falta tocar el código. En Supabase, abre **Table Editor > productos** y edita el precio, o pon `activo` en `false` para quitar un producto de la venta. Los cambios aplican a la app de inmediato.

Importante: no vuelvas a ejecutar `seed.sql` después de cambiar precios. Solo agrega productos nuevos si no existen.

## Notas

- Las ventas no se borran. Si hay un error, se usa **Anular última venta** y queda registrado quién la anuló.
- Cada venta guarda el precio del momento. Si luego cambias un precio, las ventas anteriores no cambian.
- El plan gratis de Supabase pausa el proyecto tras 1 semana sin uso. Como la app se usa a diario, no debería pasar. Si ocurre, se reactiva desde el panel.
- Los pagos registrados (efectivo, Yape, Plin) son solo para control. No hay conexión con los bancos ni con SUNAT.
