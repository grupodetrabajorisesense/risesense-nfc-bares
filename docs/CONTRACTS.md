# CONTRACTS.md

Formato exacto de cada endpoint y función. **Esta es la fuente de verdad.** Si un
formato cambia, se cambia aquí primero y se avisa al equipo. Dueño: Dev 1.

Convenciones:
- Todo el dinero en **céntimos (integer)**. `precio_centimos: 180` = 1,80 €.
- IDs en **UUID**.
- Base URL de webhooks: `https://n8n.risesense.es/webhook`

Leyenda de estado:
- ✅ implementado y verificado
- 🚧 por construir

---

## 1. GET /bar/carta ✅

Devuelve la carta del bar a partir del token de la mesa. Lo consume la web cliente al
cargar.

**Request**
```
GET /bar/carta?token=DEMO1234
```

**Response 200**
```json
{
  "establecimiento": {
    "id": "3a1cfc71-3353-4623-ade9-7a05fa89794d",
    "nombre": "Bar Demo",
    "moneda": "EUR",
    "logo_url": null,
    "color_primario": "#c1272d"
  },
  "mesas": [
    {
      "id": "1ea784e7-9a4b-4a52-a64f-6ba2173dfa41",
      "numero": "5",
      "zona": "terraza"
    }
  ],
  "categorias": [
    {
      "id": "9b2636db-0ff9-40e3-841b-e1ad52dab3f6",
      "nombre": "Cervezas",
      "productos": [
        {
          "id": "9c2f4797-8a68-4031-9b08-471cae455931",
          "nombre": "Caña",
          "descripcion": "Cerveza de barril 20cl",
          "precio_centimos": 180,
          "imagen_url": null
        }
      ]
    }
  ]
}
```

**Notas**
- Solo devuelve categorías activas y productos con `disponible = true`.
- Si el token no existe o la mesa/bar está inactivo → la función devuelve `null`.
  El frontend interpreta `null` como "Mesa no encontrada".
- Header CORS `Access-Control-Allow-Origin: *` obligatorio (web en otro dominio).
- **Cambio (QR único por bar):** el `token` ahora identifica al establecimiento
  (`establecimientos.token`), no a una mesa individual. El cliente elige su mesa
  manualmente en el frontend a partir del array `mesas[]`. El campo `mesa` (objeto
  único) queda obsoleto; el frontend mantiene compatibilidad hacia atrás con el
  formato viejo, pero no se debe generar más.
Función SQL: `hosteleria.get_carta(p_token text) RETURNS jsonb`

---

## 2. POST /bar/pedido 🚧

Crea el pedido (total calculado en servidor) y, si es online, genera el PaymentIntent
de Stripe. Co-propiedad Dev 1 (crear_pedido) + Dev 2 (Stripe).

**Request**
```json
{
  "token": "DEMO1234",
  "mesa_id": "1ea784e7-9a4b-4a52-a64f-6ba2173dfa41",
  "items": [
    { "producto_id": "9c2f4797-8a68-4031-9b08-471cae455931", "cantidad": 2 },
    { "producto_id": "39fbd653-4e39-45e1-81cf-e8735a116940", "cantidad": 1 }
  ],
  "metodo_pago": "online",
  "notas": "sin hielo"
}
```
- `metodo_pago`: `"online"` | `"caja"`
  (`"efectivo"` queda soportado por la función SQL por compatibilidad, pero el frontend
  ya no lo usa: se fusionó con `"caja"` — ambos significan "pago no online, cobra el camarero").
- `notas`: opcional
- El cliente **nunca** manda precios ni total. Solo producto + cantidad.
- mesa_id: obligatorio. UUID de la mesa elegida (viene de `mesas[]` de `GET /bar/carta`).
  El backend valida que pertenece al mismo establecimiento del token y está activa.
- mesa_numero: opcional, informativo. Si el frontend lo manda, n8n puede incluirlo en
  logs, pero no se pasa a `crear_pedido` (la mesa se resuelve por mesa_id).
- **Decisión (21/08/2026, Dev 1 + Dev 3):** se evaluó permitir `mesa_id: null` con
  entrada manual de mesa como fallback si `mesas[]` llega vacío, y se descartó. Con el
  flujo real de alta de mesas (siempre dadas de alta antes de publicar el QR del bar),
  no hay caso de negocio que lo justifique. Si `mesas[]` llega vacío, el frontend
  muestra un error ("no hay mesas disponibles, avisa al camarero") y no permite
  continuar el pedido. `mesa_id` es y seguirá siendo obligatorio; `crear_pedido` no
  necesita soportar `NULL`.
**Response 200 — método `online`**
```json
{
  "pedido_id": "…",
  "numero_pedido": 23,
  "total_centimos": 560,
  "moneda": "EUR",
  "client_secret": "pi_3ABC…_secret_XYZ",
  "stripe_account_id": "acct_1U12BeIrKBroXx3M"
}
```
El frontend usa `client_secret` + `stripe_account_id` para montar el Payment Element
(el `stripeAccount` va en la config de Stripe.js por ser direct charge).

**Response 200 — método `efectivo` / `caja`**
```json
{
  "pedido_id": "…",
  "numero_pedido": 23,
  "total_centimos": 560,
  "moneda": "EUR",
  "estado": "nuevo"
}
```
No hay pago online: el pedido nace ya en `nuevo` y el camarero cobra en persona.

**Response 4xx — validación**
```json
{ "error": "productos inválidos, ajenos al bar o no disponibles" }
```
`crear_pedido` lanza excepción si algún producto no es del bar, no está disponible, o
el pedido no tiene líneas válidas. n8n lo traduce a error.

Función SQL:
`hosteleria.crear_pedido(p_token text, p_items jsonb, p_mesa_id uuid, p_metodo_pago text DEFAULT 'online', p_notas text DEFAULT NULL) RETURNS jsonb`
→ devuelve `{ pedido_id, total_centimos, moneda, metodo_pago, stripe_account_id }`

**Nota de orden de parámetros:** `p_mesa_id` va en tercera posición (entre `p_items` y
`p_metodo_pago`). n8n debe llamar a la función con parámetros nombrados o respetar
exactamente este orden.
- `numero_pedido`: correlativo legible por establecimiento, reiniciado cada día
  (ej. "Pedido #23" en el ticket). No confundir con `pedido_id` (UUID interno).
---

## 3. POST /stripe/webhook 🚧

Recibe eventos de Stripe. Dueño: Dev 2.

**Verificación:** comprobar la firma con el `webhook secret` antes de procesar nada.

**Direct charges + Connect:** los eventos de pago llegan con el campo `account`
(la cuenta conectada del bar). Configurar el webhook como **Connect webhook** en Stripe,
o filtrar por ese campo.

**Eventos a manejar**

`payment_intent.succeeded` →
```
UPDATE hosteleria.pedidos
   SET pagado = true,
       estado = 'nuevo',
       pagado_at = now(),
       stripe_payment_intent_id = <id>
 WHERE id = <pedido_id>;
```
El `pedido_id` se recupera del `metadata` del PaymentIntent (Dev 2 lo mete al crearlo).

`payment_intent.payment_failed` → dejar el pedido en `pendiente_pago` (o `cancelado`
según se decida). No debe aparecer en el panel.

**Idempotencia obligatoria:** un mismo evento puede llegar varias veces. Antes de
aplicar, comprobar si ese `event.id` ya se procesó (tabla de eventos procesados o
guard por estado). Mismo patrón que el webhook de A Casa da Igrexa.

**Responder 200 rápido** aunque el procesamiento sea async, para que Stripe no reintente
en bucle.

---

## 4. Panel del bar 🚧

### GET /bar/pedidos-activos 🚧✅
Lo consume el panel por polling. Dueño: Dev 1 (función) + Dev 3 (panel).

**Request**
```
GET /bar/pedidos-activos?establecimiento_id=…
```
> Nota de seguridad: el panel va detrás de login. No exponer esto sin autenticar, o
> cualquiera lista los pedidos de un bar. Definir auth antes de publicarlo.
> ⚠️ **Sin auth todavía (pendiente, ver DECISIONS.md).** Implementado y funcional para
> desarrollo, pero no debe exponerse en producción hasta resolver el login del panel.

**Response 200**
```json
{
  "pedidos": [
    {
      "pedido_id": "…",
      "numero_pedido": 23,
      "mesa_numero": "5",
      "estado": "nuevo",
      "pagado": true,
      "metodo_pago": "online",
      "total_centimos": 560,
      "created_at": "2026-08-10T18:32:00Z",
      "lineas": [
        { "nombre_producto": "Caña", "cantidad": 2 },
        { "nombre_producto": "Coca-Cola", "cantidad": 1 }
      ]
    }
  ]
}
```

Función SQL: `hosteleria.get_pedidos_activos(p_establecimiento_id uuid) RETURNS jsonb`

### POST /bar/pedido-estado 🚧✅
Botones del camarero (en preparación / servido / cancelado).

**Request**
```json
{ "pedido_id": "…", "nuevo_estado": "en_preparacion" }
```
Estados válidos: `nuevo` → `en_preparacion` → `servido`. `cancelado` desde cualquiera.

Función SQL: `hosteleria.marcar_estado_pedido(p_pedido_id uuid, p_nuevo_estado text) RETURNS jsonb`

---

## Referencia: estados del pedido

| estado          | significado                                             |
|-----------------|---------------------------------------------------------|
| pendiente_pago  | online creado, esperando confirmación de Stripe         |
| nuevo           | pagado (o efectivo/caja) — visible para el bar          |
| en_preparacion  | el bar lo está preparando                               |
| servido         | entregado en mesa                                       |
| cancelado       | anulado                                                 |

`metodo_pago`: `online` | `efectivo` | `caja`

### Control de stock ✅

Los productos tienen una columna `stock` (integer, `NULL` = sin controlar, comportamiento
igual que antes). Se descuenta atómicamente dentro de `crear_pedido` por cada línea —
si no hay stock suficiente para alguna línea, se aborta todo el pedido (ninguna línea
se descuenta ni se crea el pedido).

**`GET /bar/carta`** — cambios:
- Un producto con `stock = 0` no aparece en la carta (igual que `disponible = false`).
- Cada producto incluye `"solo_pago_presencial": true` cuando `0 < stock <= 3`
  (umbral fijo por ahora). El frontend debe forzar pago en caja/efectivo para esos
  productos, para evitar reservar la última unidad con un pago online abandonado.

**GET /bar/productos?establecimiento_id=XXX** ✅ (gestión, no cliente final)

Devuelve TODOS los productos, incluidos agotados/no disponibles.
\`\`\`json
{
  "categorias": [
    { "id", "nombre", "productos": [
      { "id", "nombre", "precio_centimos", "disponible", "stock" }
    ]}
  ]
}
\`\`\`
Función SQL: `hosteleria.get_productos_gestion(p_establecimiento_id uuid) RETURNS jsonb`

**POST /bar/producto-stock** ✅ (gestión, no cliente final)

**Request**
\`\`\`json
{ "producto_id": "…", "stock": 10 }
\`\`\`
`stock: null` desactiva el control de stock para ese producto (vuelve a "sin límite").

**Response 200**
\`\`\`json
{ "id": "…", "nombre": "…", "stock": 10 }
\`\`\`

Función SQL: `hosteleria.actualizar_stock_producto(p_producto_id uuid, p_stock integer) RETURNS jsonb`

> **Pendiente de decisión de negocio:** si NFCBARES sustituye por completo el TPV del
> bar (facturación homologada, inventario real) o convive como canal adicional
> (tipo Glovo/Uber Eats). Afecta al alcance del control de stock y otras piezas
> futuras — sin decidir todavía, ver conversación de equipo.

### Gestión de productos y categorías ✅ (parcial — falta producto-crear)

Endpoints de gestión (panel del bar), no para el cliente final.

**POST /bar/producto-editar**
\`\`\`json
{ "producto_id": "…", "nombre": "…", "precio_centimos": integer }
\`\`\`
Se manda siempre el par completo (nombre + precio), no parches sueltos.
Función SQL: `hosteleria.editar_producto(p_producto_id uuid, p_nombre text, p_precio_centimos integer)`

**POST /bar/producto-eliminar**
\`\`\`json
{ "producto_id": "…" }
\`\`\`
Borrado lógico: pone `eliminado = true`. Nunca DELETE físico — `pedido_lineas` guarda
copia congelada de nombre/precio de cada línea vendida, y un DELETE real rompería esa
trazabilidad. Con `eliminado = true` desaparece de la carta y de la gestión, sin tocar
el histórico.

`eliminado` es independiente de `disponible` (interruptor manual de "cerrado hoy") y
de `stock` (control de unidades). `get_carta` (cliente) filtra por los tres a la vez;
`GET /bar/productos` (gestión) filtra solo por `eliminado = false`, para que el
camarero siga viendo y pudiendo reactivar cualquier producto agotado o cerrado.

Función SQL: `hosteleria.eliminar_producto(p_producto_id uuid)`

**POST /bar/categoria-editar**
\`\`\`json
{ "categoria_id": "…", "nombre": "…" }
\`\`\`
Función SQL: `hosteleria.editar_categoria(p_categoria_id uuid, p_nombre text)`

**POST /bar/producto-crear** ✅ (reutiliza `crear_producto` ya existente)
\`\`\`json
{ "establecimiento_id": "…", "categoria_id": "…", "nombre": "…", "precio_centimos": integer }
\`\`\`
`descripcion`, `imagen_url` (NULL) y `orden` (0) se rellenan por defecto — el panel
todavía no los pide en el formulario. Si en el futuro el panel los añade, la función
ya está preparada para recibirlos sin cambios.

> **Nota de implementación:** el nodo Postgres de n8n serializa `null` de JavaScript
> como el string literal `"null"` dentro del campo de Query Parameters, en vez de un
> valor nulo real. Se resuelve con `NULLIF($n, 'null')::text` en la query SQL para
> los parámetros opcionales. Aplicar el mismo patrón en futuros webhooks que acepten
> valores opcionales por defecto a NULL.

**POST /bar/categoria-crear** ✅ (reutiliza `crear_categoria` ya existente)
\`\`\`json
{ "establecimiento_id": "…", "nombre": "…" }
\`\`\`

**POST /bar/categoria-eliminar**
\`\`\`json
{ "categoria_id": "…" }
\`\`\`
DELETE físico de la fila (a diferencia de `eliminar_producto`, aquí sí es seguro: no
hay `pedido_lineas` que referencien una categoría directamente). Se rechaza si la
categoría tiene algún producto con `eliminado = false` — un producto ya eliminado
lógicamente no cuenta como bloqueante.

Función SQL: `hosteleria.eliminar_categoria(p_categoria_id uuid)`

> **Corrección de datos (24/09/2026):** dos productos de prueba tenían el string
> literal `"null"` guardado en `descripcion`/`imagen_url` en vez de `NULL` real
> (efecto del bug de serialización de n8n, antes del fix con `NULLIF`). Corregido
> con un `UPDATE` puntual; no afecta a datos creados después del fix.
