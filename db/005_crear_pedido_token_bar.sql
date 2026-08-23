DROP FUNCTION IF EXISTS hosteleria.crear_pedido(text, jsonb, text, text);

CREATE OR REPLACE FUNCTION hosteleria.crear_pedido(
	p_token text,
	p_items jsonb,
	p_mesa_id uuid,
	p_metodo_pago text DEFAULT 'online'::text,
	p_notas text DEFAULT NULL::text)
    RETURNS jsonb
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE SECURITY DEFINER PARALLEL UNSAFE
    SET search_path=hosteleria, pg_temp
AS $BODY$
DECLARE
  v_mesa        hosteleria.mesas%ROWTYPE;
  v_estab       hosteleria.establecimientos%ROWTYPE;
  v_pedido_id   uuid;
  v_total       int;
  v_num_items   int;
  v_num_validos int;
BEGIN
  IF p_metodo_pago NOT IN ('online','efectivo','caja') THEN
    RAISE EXCEPTION 'metodo_pago no válido: %', p_metodo_pago;
  END IF;

  SELECT e.* INTO v_estab
  FROM hosteleria.establecimientos e
  WHERE e.token = p_token AND e.activo = true;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'enlace no válido';
  END IF;

  SELECT m.* INTO v_mesa
  FROM hosteleria.mesas m
  WHERE m.id = p_mesa_id
    AND m.establecimiento_id = v_estab.id
    AND m.activa = true;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'mesa no encontrada o inactiva';
  END IF;

  SELECT count(*) INTO v_num_items
  FROM jsonb_array_elements(p_items) i
  WHERE (i->>'cantidad')::int > 0 AND (i->>'producto_id') IS NOT NULL;
  IF v_num_items = 0 THEN
    RAISE EXCEPTION 'pedido sin líneas válidas';
  END IF;

  SELECT count(*) INTO v_num_validos
  FROM jsonb_array_elements(p_items) i
  JOIN hosteleria.productos p
    ON p.id = (i->>'producto_id')::uuid
   AND p.establecimiento_id = v_estab.id
   AND p.disponible = true
  WHERE (i->>'cantidad')::int > 0;
  IF v_num_validos <> v_num_items THEN
    RAISE EXCEPTION 'productos inválidos, ajenos al bar o no disponibles';
  END IF;

  INSERT INTO hosteleria.pedidos (establecimiento_id, mesa_id, estado, metodo_pago, total_centimos, notas)
  VALUES (
    v_estab.id, v_mesa.id,
    CASE WHEN p_metodo_pago = 'online' THEN 'pendiente_pago' ELSE 'nuevo' END,
    p_metodo_pago, 0, p_notas
  )
  RETURNING id INTO v_pedido_id;

  INSERT INTO hosteleria.pedido_lineas
    (pedido_id, producto_id, nombre_producto, precio_unitario_centimos, cantidad, subtotal_centimos)
  SELECT v_pedido_id, p.id, p.nombre, p.precio_centimos,
         (i->>'cantidad')::int,
         p.precio_centimos * (i->>'cantidad')::int
  FROM jsonb_array_elements(p_items) i
  JOIN hosteleria.productos p ON p.id = (i->>'producto_id')::uuid
  WHERE (i->>'cantidad')::int > 0;

  SELECT COALESCE(sum(subtotal_centimos), 0) INTO v_total
  FROM hosteleria.pedido_lineas WHERE pedido_id = v_pedido_id;
  UPDATE hosteleria.pedidos SET total_centimos = v_total WHERE id = v_pedido_id;

  RETURN jsonb_build_object(
    'pedido_id',         v_pedido_id,
    'total_centimos',    v_total,
    'moneda',            v_estab.moneda,
    'metodo_pago',       p_metodo_pago,
    'stripe_account_id', v_estab.stripe_account_id
  );
END;
$BODY$;

ALTER FUNCTION hosteleria.crear_pedido(text, jsonb, uuid, text, text)
    OWNER TO risesense_admin;

GRANT EXECUTE ON FUNCTION hosteleria.crear_pedido(text, jsonb, uuid, text, text) TO bar_web;
GRANT EXECUTE ON FUNCTION hosteleria.crear_pedido(text, jsonb, uuid, text, text) TO risesense_admin;
REVOKE ALL ON FUNCTION hosteleria.crear_pedido(text, jsonb, uuid, text, text) FROM PUBLIC;
