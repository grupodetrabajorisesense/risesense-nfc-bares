-- db/030_crear_pedido_variantes.sql
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
  v_mesa          hosteleria.mesas%ROWTYPE;
  v_estab         hosteleria.establecimientos%ROWTYPE;
  v_pedido_id     uuid;
  v_total         int;
  v_numero_pedido int;
  v_item          record;
  v_prod          hosteleria.productos%ROWTYPE;
  v_var           hosteleria.producto_variantes%ROWTYPE;
  v_filas         int;
  v_hay_items     boolean := false;
  v_nombre        text;
  v_precio        int;
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

  -- Validación previa de TODAS las líneas (nada se inserta ni descuenta si alguna falla)
  FOR v_item IN
    SELECT (i->>'producto_id')::uuid AS producto_id,
           NULLIF(i->>'variante_id', '')::uuid AS variante_id,
           (i->>'cantidad')::int AS cantidad
    FROM jsonb_array_elements(p_items) i
    WHERE (i->>'cantidad')::int > 0 AND (i->>'producto_id') IS NOT NULL
  LOOP
    v_hay_items := true;

    SELECT p.* INTO v_prod
    FROM hosteleria.productos p
    WHERE p.id = v_item.producto_id
      AND p.establecimiento_id = v_estab.id
      AND p.disponible = true
      AND p.eliminado = false;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'productos inválidos, ajenos al bar o no disponibles';
    END IF;

    IF v_item.variante_id IS NULL THEN
      -- producto con variantes activas: la variante es obligatoria
      IF EXISTS (
        SELECT 1 FROM hosteleria.producto_variantes v
        WHERE v.producto_id = v_prod.id AND v.eliminado = false
      ) THEN
        RAISE EXCEPTION 'este producto requiere elegir un tamaño';
      END IF;
    ELSE
      IF NOT EXISTS (
        SELECT 1 FROM hosteleria.producto_variantes v
        WHERE v.id = v_item.variante_id
          AND v.producto_id = v_prod.id
          AND v.eliminado = false
      ) THEN
        RAISE EXCEPTION 'variante inválida para este producto';
      END IF;
    END IF;
  END LOOP;

  IF NOT v_hay_items THEN
    RAISE EXCEPTION 'pedido sin líneas válidas';
  END IF;

  -- Descuento atómico de stock: sobre la variante si la hay, si no sobre el producto.
  -- Si una línea falla, la excepción revierte toda la transacción.
  FOR v_item IN
    SELECT (i->>'producto_id')::uuid AS producto_id,
           NULLIF(i->>'variante_id', '')::uuid AS variante_id,
           (i->>'cantidad')::int AS cantidad
    FROM jsonb_array_elements(p_items) i
    WHERE (i->>'cantidad')::int > 0
  LOOP
    IF v_item.variante_id IS NOT NULL THEN
      UPDATE hosteleria.producto_variantes
         SET stock = stock - v_item.cantidad
       WHERE id = v_item.variante_id
         AND (stock IS NULL OR stock >= v_item.cantidad);
    ELSE
      UPDATE hosteleria.productos
         SET stock = stock - v_item.cantidad
       WHERE id = v_item.producto_id
         AND (stock IS NULL OR stock >= v_item.cantidad);
    END IF;
    GET DIAGNOSTICS v_filas = ROW_COUNT;
    IF v_filas = 0 THEN
      RAISE EXCEPTION 'producto sin stock suficiente';
    END IF;
  END LOOP;

  PERFORM pg_advisory_xact_lock(hashtext(v_estab.id::text || '-' || CURRENT_DATE::text));

  SELECT COALESCE(MAX(numero_pedido), 0) + 1 INTO v_numero_pedido
  FROM hosteleria.pedidos
  WHERE establecimiento_id = v_estab.id
    AND created_at >= CURRENT_DATE
    AND created_at < CURRENT_DATE + INTERVAL '1 day';

  INSERT INTO hosteleria.pedidos
    (establecimiento_id, mesa_id, estado, metodo_pago, total_centimos, notas, numero_pedido)
  VALUES (
    v_estab.id, v_mesa.id,
    CASE WHEN p_metodo_pago = 'online' THEN 'pendiente_pago' ELSE 'nuevo' END,
    p_metodo_pago, 0, p_notas, v_numero_pedido
  )
  RETURNING id INTO v_pedido_id;

  -- Líneas con nombre y precio congelados (los de la variante si la hay)
  INSERT INTO hosteleria.pedido_lineas
    (pedido_id, producto_id, variante_id, nombre_producto, precio_unitario_centimos, cantidad, subtotal_centimos)
  SELECT v_pedido_id, p.id, v.id,
         CASE WHEN v.id IS NULL THEN p.nombre ELSE p.nombre || ' (' || v.nombre || ')' END,
         COALESCE(v.precio_centimos, p.precio_centimos),
         it.cantidad,
         COALESCE(v.precio_centimos, p.precio_centimos) * it.cantidad
  FROM (
    SELECT (i->>'producto_id')::uuid AS producto_id,
           NULLIF(i->>'variante_id', '')::uuid AS variante_id,
           (i->>'cantidad')::int AS cantidad
    FROM jsonb_array_elements(p_items) i
    WHERE (i->>'cantidad')::int > 0
  ) it
  JOIN hosteleria.productos p ON p.id = it.producto_id
  LEFT JOIN hosteleria.producto_variantes v ON v.id = it.variante_id;

  SELECT COALESCE(sum(subtotal_centimos), 0) INTO v_total
  FROM hosteleria.pedido_lineas WHERE pedido_id = v_pedido_id;
  UPDATE hosteleria.pedidos SET total_centimos = v_total WHERE id = v_pedido_id;

  RETURN jsonb_build_object(
    'pedido_id',         v_pedido_id,
    'numero_pedido',     v_numero_pedido,
    'moneda',            v_estab.moneda,
END;
$BODY$;

ALTER FUNCTION hosteleria.crear_pedido(text, jsonb, uuid, text, text) OWNER TO risesense_admin;
GRANT EXECUTE ON FUNCTION hosteleria.crear_pedido(text, jsonb, uuid, text, text) TO bar_web;
GRANT EXECUTE ON FUNCTION hosteleria.crear_pedido(text, jsonb, uuid, text, text) TO risesense_admin;
REVOKE ALL ON FUNCTION hosteleria.crear_pedido(text, jsonb, uuid, text, text) FROM PUBLIC;    'metodo_pago',       p_metodo_pago,
    'stripe_account_id', v_estab.stripe_account_id
  );

