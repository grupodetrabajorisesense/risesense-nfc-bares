CREATE OR REPLACE FUNCTION hosteleria.marcar_pedido_cobrado(
    p_pedido_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = hosteleria, pg_temp
AS $$
DECLARE
  v_pedido hosteleria.pedidos%ROWTYPE;
BEGIN
  SELECT * INTO v_pedido
  FROM hosteleria.pedidos
  WHERE id = p_pedido_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'pedido no encontrado';
  END IF;

  IF v_pedido.metodo_pago = 'online' THEN
    RAISE EXCEPTION 'un pedido online ya está pagado por Stripe, no se puede marcar como cobrado manualmente';
  END IF;

  IF v_pedido.pagado = true THEN
    RAISE EXCEPTION 'este pedido ya estaba marcado como cobrado';
  END IF;

  UPDATE hosteleria.pedidos
  SET pagado = true,
      pagado_at = now()
  WHERE id = p_pedido_id;

  RETURN jsonb_build_object(
    'pedido_id', p_pedido_id,
    'pagado', true
  );
END;
$$;

ALTER FUNCTION hosteleria.marcar_pedido_cobrado(uuid) OWNER TO risesense_admin;
GRANT EXECUTE ON FUNCTION hosteleria.marcar_pedido_cobrado(uuid) TO n8n_hosteleria;
GRANT EXECUTE ON FUNCTION hosteleria.marcar_pedido_cobrado(uuid) TO risesense_admin;
REVOKE ALL ON FUNCTION hosteleria.marcar_pedido_cobrado(uuid) FROM PUBLIC;
