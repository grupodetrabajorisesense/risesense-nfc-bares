-- db/012_marcar_pedido_pagado.sql
-- Reconciliación de pagos desde el webhook de Stripe. Idempotente vía hosteleria.stripe_eventos.
-- Requiere: 011_stripe_eventos.sql
-- Dueño: Dev 2.

-- ── payment_intent.succeeded ────────────────────────────────────────────────
-- Marca el pedido como pagado UNA sola vez, aunque el evento llegue repetido.
CREATE OR REPLACE FUNCTION hosteleria.marcar_pedido_pagado(
    p_event_id          text,
    p_pedido_id         uuid,
    p_payment_intent_id text)
    RETURNS jsonb
    LANGUAGE 'plpgsql'
    VOLATILE SECURITY DEFINER
    SET search_path = hosteleria, pg_temp
AS $BODY$
DECLARE
  v_filas int;
BEGIN
  -- Guard de idempotencia: si el event_id ya existía, no insertamos y no repetimos nada.
  INSERT INTO hosteleria.stripe_eventos (event_id, tipo, pedido_id)
  VALUES (p_event_id, 'payment_intent.succeeded', p_pedido_id)
  ON CONFLICT (event_id) DO NOTHING;

  GET DIAGNOSTICS v_filas = ROW_COUNT;   -- 1 = primera vez, 0 = evento repetido
  IF v_filas = 0 THEN
    RETURN jsonb_build_object('status', 'duplicate', 'pedido_id', p_pedido_id);
  END IF;

  -- Solo activa el pedido si seguía esperando pago: no pisa estados posteriores
  -- (en_preparacion, servido) ni reactiva uno cancelado.
  UPDATE hosteleria.pedidos
     SET pagado                   = true,
         estado                   = 'nuevo',
         pagado_at                = now(),
         stripe_payment_intent_id = p_payment_intent_id
   WHERE id = p_pedido_id
     AND estado = 'pendiente_pago';

  RETURN jsonb_build_object('status', 'ok', 'pedido_id', p_pedido_id);
END;
$BODY$;

-- ── payment_intent.payment_failed ───────────────────────────────────────────
-- Registra el fallo (para idempotencia y auditoría) pero NO cambia el estado del
-- pedido a propósito: con el Payment Element el cliente puede reintentar con otra
-- tarjeta sobre el MISMO PaymentIntent, que luego emitiría un succeeded. Si aquí
-- cancelásemos, ese reintento con éxito no encontraría el pedido en 'pendiente_pago'
-- y no se activaría. El pedido en 'pendiente_pago' ya no aparece en el panel.
-- La limpieza de pedidos abandonados (expirar 'pendiente_pago' viejos) irá aparte.
CREATE OR REPLACE FUNCTION hosteleria.marcar_pago_fallido(
    p_event_id  text,
    p_pedido_id uuid)
    RETURNS jsonb
    LANGUAGE 'plpgsql'
    VOLATILE SECURITY DEFINER
    SET search_path = hosteleria, pg_temp
AS $BODY$
DECLARE
  v_filas int;
BEGIN
  INSERT INTO hosteleria.stripe_eventos (event_id, tipo, pedido_id)
  VALUES (p_event_id, 'payment_intent.payment_failed', p_pedido_id)
  ON CONFLICT (event_id) DO NOTHING;

  GET DIAGNOSTICS v_filas = ROW_COUNT;
  IF v_filas = 0 THEN
    RETURN jsonb_build_object('status', 'duplicate', 'pedido_id', p_pedido_id);
  END IF;

  RETURN jsonb_build_object('status', 'ok', 'pedido_id', p_pedido_id);
END;
$BODY$;

ALTER FUNCTION hosteleria.marcar_pedido_pagado(text, uuid, text) OWNER TO risesense_admin;
ALTER FUNCTION hosteleria.marcar_pago_fallido(text, uuid)          OWNER TO risesense_admin;

GRANT EXECUTE ON FUNCTION hosteleria.marcar_pedido_pagado(text, uuid, text) TO n8n_hosteleria;
GRANT EXECUTE ON FUNCTION hosteleria.marcar_pedido_pagado(text, uuid, text) TO risesense_admin;
GRANT EXECUTE ON FUNCTION hosteleria.marcar_pago_fallido(text, uuid)        TO n8n_hosteleria;
GRANT EXECUTE ON FUNCTION hosteleria.marcar_pago_fallido(text, uuid)        TO risesense_admin;

REVOKE ALL ON FUNCTION hosteleria.marcar_pedido_pagado(text, uuid, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION hosteleria.marcar_pago_fallido(text, uuid)        FROM PUBLIC;
