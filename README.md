# RiseSense Hostelería

Sistema de pedido y pago en mesa para bares y pubs. El cliente acerca el móvil a una
pegatina NFC (o escanea el QR) de su mesa, cae en una web con la carta del bar, pide y
paga desde el móvil. El bar recibe el pedido —ya cobrado— en un panel de control.

Producto multi-tenant: la misma instalación sirve para 1 bar o para 50.

---

## Arquitectura

```
  Cliente (móvil)                    Bar (panel)
        │                                 │
        │  https://bar.risesense.es/m/{token}
        ▼                                 ▼
   Web cliente  ──┐                 Panel camarero
   (pegatina)     │                       │
                  │  fetch JSON            │  polling JSON
                  ▼                        ▼
            ┌─────────────── n8n (webhooks) ───────────────┐
            │  /bar/carta   /bar/pedido   /stripe/webhook  │
            └───────────────────┬──────────────────────────┘
                                │  (red interna Docker)
                    ┌───────────┴───────────┐
                    ▼                        ▼
             PostgreSQL              Stripe (Connect)
           (bd: hosteleria)         direct charges
```

**Principio de seguridad:** el único punto público es n8n. La web nunca habla con
PostgreSQL/PostgREST directamente. Postgres y Stripe (clave secreta) se quedan dentro
de la red Docker. Todo el acceso a datos pasa por funciones `SECURITY DEFINER`; las
tablas no son accesibles directamente por el rol de la web.

**Modelo de pago:** Stripe Connect con *direct charges*. Cada bar es una cuenta
conectada y **el comercio de registro** (aparece en el extracto del cliente, gestiona
su IVA y sus disputas). RiseSense cobra su comisión vía `application_fee_amount`.
RiseSense NO es intermediario del dinero.

---

## Stack

- **VPS** Ubuntu + Docker, red `risesense-network`
- **PostgreSQL** `postgres-risesense` → base de datos dedicada `hosteleria`
- **n8n** para toda la lógica y los webhooks
- **Traefik** (reverse proxy + Let's Encrypt) / **nginx** (sirve las webs estáticas)
- **Stripe Connect** (pagos)
- **Cloudflare** delante de `risesense.es`

---

## Reparto de tareas

Se trabaja **por dueño de componente y en paralelo**, no por turnos. Los contratos
JSON (ver `docs/CONTRACTS.md`) permiten que cada uno avance sin esperar a los demás.

### Dev 1 — Backend + n8n (dueño de datos y contratos)
- Funciones de alta para gestión: crear establecimiento, mesas (con su `token`),
  categorías, productos.
- `get_pedidos_activos(establecimiento_id)` → alimenta el panel del bar.
- `marcar_estado_pedido(pedido_id, nuevo_estado)` → botones del camarero.
- Esqueleto del webhook `/bar/pedido` (llama a `crear_pedido`, deja el pedido listo
  para que Dev 2 le enchufe Stripe).
- **Dueño de `docs/CONTRACTS.md`.** Nadie define un formato sin apuntarlo aquí.

### Dev 2 — Pagos (Stripe Connect)
- Terminar onboarding de la cuenta conectada de test hasta `charges_enabled: true`.
- Nodo Stripe en `/bar/pedido`: PaymentIntent como *direct charge* sobre la cuenta del
  bar, con `application_fee_amount`, devolviendo `client_secret`.
- Webhook `/stripe/webhook`: verificar firma, en `payment_intent.succeeded` marcar el
  pedido pagado. **Con idempotencia** (reutilizar patrón de A Casa da Igrexa).
- Fallo de pago (`payment_intent.payment_failed`) y, más adelante, reembolsos.
- Centraliza la fórmula de comisión en un solo sitio.

### Dev 3 — Frontends
- Web cliente: token en URL → `/bar/carta` → carta → carrito → checkout.
  Selector "pagar online / pagar en caja". En online, Stripe Payment Element con el
  `client_secret`.
- Estados de error: mesa no encontrada, pago fallido.
- Generación del QR por mesa a partir del token.
- Panel del bar (si le sobra tiempo; si no, lo coge Dev 2): polling a
  `get_pedidos_activos`, aviso de pedido nuevo, botones de estado. Reutilizar estilo
  single-file de los paneles de Belladona/SynWash.

**Único punto compartido:** el workflow `/bar/pedido` (co-propiedad Dev 1 + Dev 2), con
costura limpia: Dev 1 entrega `{pedido_id, total_centimos, stripe_account_id}`, Dev 2
devuelve `client_secret`.

---

## Estructura del repo

```
/db            → migraciones SQL numeradas (001_schema.sql, 002_funciones.sql...)
/n8n           → workflows exportados a JSON
/web-cliente   → web de la pegatina
/panel-bar     → panel del camarero
/docs          → CONTRACTS.md, DECISIONS.md
.env.example   → nombres de variables (SIN valores reales)
README.md
```

---

## Reglas de trabajo (importante con 3 personas)

**1. Todo cambio de BBDD es un `.sql` numerado y commiteado.** Nada de ejecutar SQL
suelto en pgAdmin sin dejar rastro. Cada tabla o función nueva → un archivo en `/db`.
Así cualquiera reconstruye la base desde cero y el estado real vive en Git.

**2. Los workflows de n8n se exportan a JSON y se commitean.** (los tres puntos →
Download). El JSON de n8n **fusiona muy mal**: un dueño por workflow, nunca lo tocan
dos a la vez.

**3. `docs/CONTRACTS.md` es la biblia.** El formato exacto de cada endpoint. Es lo que
permite trabajar en paralelo (frontend contra JSON mockeado mientras el backend real
se construye).

**4. Nunca se commitean secretos.** `sk_test_...` de Stripe, contraseñas de BBDD y
tokens van en un `.env` local. En el repo solo `.env.example` con los nombres.

### Flujo diario
- Rama por feature → Pull Request a `develop` → revisión rápida del otro → merge.
- `main` solo lo estable y desplegable.
- Integrar a menudo (nada de ramas que divergen 2 semanas).
- El mensaje del commit y la descripción del PR **ya son la documentación** de qué
  hiciste. No hace falta "dejo apuntado dónde me quedé".
- Sync diario de 10 min (async por el canal): qué hice, qué hago, en qué estoy
  bloqueado.

---

## Puesta en marcha local

1. Reconstruir la base: ejecutar en orden los `.sql` de `/db` contra la bd `hosteleria`.
2. Importar los workflows de `/n8n` en la instancia de n8n.
3. Copiar `.env.example` a `.env` y rellenar con los valores reales (pedir al equipo).
4. Credencial Postgres de n8n: usuario `n8n_hosteleria` sobre la bd `hosteleria`.
# risesense-nfc-bares
