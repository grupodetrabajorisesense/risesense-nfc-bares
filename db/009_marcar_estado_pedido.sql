CREATE OR REPLACE FUNCTION hosteleria.marcar_estado_pedido(
    p_pedido_id uuid,
    p_nuevo_estado text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = hosteleria, pg_temp
AS $$
DECLARE
  v_pedido hosteleria.pedidos%ROWTYPE;
BEGIN
  IF p_nuevo_estado NOT IN ('nuevo', 'en_preparacion', 'servido', 'cancelado') THEN
    RAISE EXCEPTION 'estado no válido: %', p_nuevo_estado;
  END IF;

  SELECT * INTO v_pedido
  FROM hosteleria.pedidos
  WHERE id = p_pedido_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'pedido no encontrado';
  END IF;

  IF p_nuevo_estado = 'cancelado' THEN
    IF v_pedido.estado = 'servido' THEN
      RAISE EXCEPTION 'no se puede cancelar un pedido ya servido';
    END IF;
  ELSE
    IF NOT (
      (v_pedido.estado = 'nuevo' AND p_nuevo_estado = 'en_preparacion') OR
      (v_pedido.estado = 'en_preparacion' AND p_nuevo_estado = 'servido')
    ) THEN
      RAISE EXCEPTION 'transición no válida: % -> %', v_pedido.estado, p_nuevo_estado;
    END IF;
  END IF;

  UPDATE hosteleria.pedidos
  SET estado = p_nuevo_estado
  WHERE id = p_pedido_id;

  RETURN jsonb_build_object(
    'pedido_id', p_pedido_id,
    'estado', p_nuevo_estado
  );
END;
$$;

ALTER FUNCTION hosteleria.marcar_estado_pedido(uuid, text) OWNER TO risesense_admin;
GRANT EXECUTE ON FUNCTION hosteleria.marcar_estado_pedido(uuid, text) TO n8n_hosteleria;
GRANT EXECUTE ON FUNCTION hosteleria.marcar_estado_pedido(uuid, text) TO risesense_admin;
REVOKE ALL ON FUNCTION hosteleria.marcar_estado_pedido(uuid, text) FROM PUBLIC;
