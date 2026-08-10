# DECISIONS.md

Decisiones ya tomadas. Antes de rediscutir algo, mirad aquí. Si se cambia una decisión,
se edita la entrada y se anota la fecha.

---

**Base de datos dedicada `hosteleria`** (no compartida con otros proyectos de RiseSense).
Aislada, se mueve de VPS de una pieza. Mismo criterio que `centros_estetica`.

**Multi-tenant desde el día uno.** Tabla `establecimientos`, todo cuelga de ahí.

**Dinero siempre en céntimos (integer).** Nada de `numeric`/decimales para importes.
Evita bugs de redondeo en pagos.

**El total lo calcula SIEMPRE el servidor.** La web solo manda producto + cantidad.
`crear_pedido` busca el precio real y valida que el producto es del bar y está
disponible. Nunca fiarse del importe que venga del cliente.

**Precios congelados en las líneas de pedido.** `pedido_lineas` copia nombre y precio
del momento. Cambiar el precio de un producto no altera pedidos pasados.

**Un solo punto público: n8n.** La web no toca Postgres/PostgREST directamente. Acceso
a datos solo vía funciones `SECURITY DEFINER`; tablas no accesibles por el rol web.

**Stripe Connect con direct charges.** El bar es la cuenta conectada y el comercio de
registro (su IVA, sus disputas, aparece en el extracto del cliente). RiseSense cobra
vía `application_fee_amount`. RiseSense NO es intermediario del dinero.

**Onboarding de Stripe: "Elige lo que necesitas" → Crea una plataforma + Aceptación de
pagos online.** Se descartó Managed Payments (merchant of record de Stripe) por el
+3,5 % y porque convierte a Stripe en responsable fiscal, chocando con que el bar sea
el comercio.

---

## Pendiente de decidir

**Modelo de comisión de RiseSense.** El `application_fee_amount` es un número en céntimos
que se calcula como se quiera (fijo, %, mixto, con mínimo/tope): es decisión de negocio,
no técnica. Contexto para decidir:
- Coste de Stripe en España: 1,5 % + 0,25 € por transacción (tarjeta estándar EEE).
  Verificar tarifa vigente en el dashboard.
- El fijo de 0,25 € pesa muchísimo en tickets pequeños (una caña de 1,80 € → ~14 % solo
  de Stripe). Diseño derivado: empujar a **pagar la ronda/mesa junta**, no bebida a
  bebida, y valorar **importe mínimo de pedido online**.
- Con direct charges, el coste marginal de RiseSense por transacción es ~0 (paga el bar).
- Opciones de monetización sobre la mesa: recargo al cliente (gastos de gestión fijos) +
  cuota mensual al bar (SaaS), que suele funcionar mejor que un % puro en hostelería.
- Para test: 5 % de marcador, se ajusta luego.

**Auth del panel del bar.** El panel y `/bar/pedidos-activos` deben ir tras login antes
de publicarse. Definir mecanismo (reutilizar patrón de login de otros paneles RiseSense).
