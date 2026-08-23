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
- `metodo_pago`: `"online"` | `"efectivo"` | `"caja"`
- `notas`: opcional
- El cliente **nunca** manda precios ni total. Solo producto + cantidad.
- mesa_id: obligatorio. UUID de la mesa elegida (viene de `mesas[]` de `GET /bar/carta`).
  El backend valida que pertenece al mismo establecimiento del token y está activa.
- mesa_numero: opcional, informativo. Si el frontend lo manda, n8n puede incluirlo en
  logs, pero no se pasa a `crear_pedido` (la mesa se resuelve por mesa_id).
**Response 200 — método `online`**
```json
{
  "pedido_id": "…",
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
