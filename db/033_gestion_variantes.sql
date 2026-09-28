-- db/033_gestion_variantes.sql

CREATE OR REPLACE FUNCTION hosteleria.crear_variante(
    p_producto_id uuid,
    p_nombre text,
    p_precio_centimos integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = hosteleria, pg_temp
AS $$
DECLARE
  v_var hosteleria.producto_variantes%ROWTYPE;
BEGIN
  IF p_nombre IS NULL OR btrim(p_nombre) = '' THEN
    RAISE EXCEPTION 'nombre obligatorio';
  END IF;
  IF p_precio_centimos IS NULL OR p_precio_centimos < 0 THEN
    RAISE EXCEPTION 'precio_centimos invalido';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM hosteleria.productos
    WHERE id = p_producto_id AND eliminado = false
  ) THEN
    RAISE EXCEPTION 'producto no encontrado';
  END IF;

  INSERT INTO hosteleria.producto_variantes (producto_id, nombre, precio_centimos)
  VALUES (p_producto_id, p_nombre, p_precio_centimos)
  RETURNING * INTO v_var;

  RETURN jsonb_build_object(
    'id', v_var.id,
    'producto_id', v_var.producto_id,
    'nombre', v_var.nombre,
    'precio_centimos', v_var.precio_centimos,
    'stock', v_var.stock
  );
END;
$$;

CREATE OR REPLACE FUNCTION hosteleria.editar_variante(
    p_variante_id uuid,
    p_nombre text,
    p_precio_centimos integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = hosteleria, pg_temp
AS $$
DECLARE
  v_var hosteleria.producto_variantes%ROWTYPE;
BEGIN
  IF p_nombre IS NULL OR btrim(p_nombre) = '' THEN
    RAISE EXCEPTION 'nombre obligatorio';
  END IF;
  IF p_precio_centimos IS NULL OR p_precio_centimos < 0 THEN
    RAISE EXCEPTION 'precio_centimos invalido';
  END IF;

  UPDATE hosteleria.producto_variantes
  SET nombre = p_nombre, precio_centimos = p_precio_centimos
  WHERE id = p_variante_id AND eliminado = false
  RETURNING * INTO v_var;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'variante no encontrada';
  END IF;

  RETURN jsonb_build_object(
    'id', v_var.id,
    'nombre', v_var.nombre,
    'precio_centimos', v_var.precio_centimos
  );
END;
$$;

CREATE OR REPLACE FUNCTION hosteleria.actualizar_stock_variante(
    p_variante_id uuid,
    p_stock integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = hosteleria, pg_temp
AS $$
DECLARE
  v_var hosteleria.producto_variantes%ROWTYPE;
BEGIN
  IF p_stock IS NOT NULL AND p_stock < 0 THEN
    RAISE EXCEPTION 'stock no puede ser negativo';
  END IF;

  UPDATE hosteleria.producto_variantes
  SET stock = p_stock
  WHERE id = p_variante_id AND eliminado = false
  RETURNING * INTO v_var;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'variante no encontrada';
  END IF;

  RETURN jsonb_build_object(
    'id', v_var.id,
    'nombre', v_var.nombre,
    'stock', v_var.stock
  );
END;
$$;

CREATE OR REPLACE FUNCTION hosteleria.eliminar_variante(
    p_variante_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = hosteleria, pg_temp
AS $$
DECLARE
  v_var hosteleria.producto_variantes%ROWTYPE;
BEGIN
  UPDATE hosteleria.producto_variantes
  SET eliminado = true
  WHERE id = p_variante_id AND eliminado = false
  RETURNING * INTO v_var;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'variante no encontrada o ya eliminada';
  END IF;

  RETURN jsonb_build_object('id', v_var.id, 'eliminado', true);
END;
$$;

ALTER FUNCTION hosteleria.crear_variante(uuid, text, integer) OWNER TO risesense_admin;
ALTER FUNCTION hosteleria.editar_variante(uuid, text, integer) OWNER TO risesense_admin;
ALTER FUNCTION hosteleria.actualizar_stock_variante(uuid, integer) OWNER TO risesense_admin;
ALTER FUNCTION hosteleria.eliminar_variante(uuid) OWNER TO risesense_admin;
GRANT EXECUTE ON FUNCTION hosteleria.crear_variante(uuid, text, integer) TO n8n_hosteleria, risesense_admin;
GRANT EXECUTE ON FUNCTION hosteleria.editar_variante(uuid, text, integer) TO n8n_hosteleria, risesense_admin;
REVOKE ALL ON FUNCTION hosteleria.crear_variante(uuid, text, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION hosteleria.editar_variante(uuid, text, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION hosteleria.actualizar_stock_variante(uuid, integer) FROM PUBLIC;
REVOKE ALL ON FUNCTION hosteleria.eliminar_variante(uuid) FROM PUBLIC;GRANT EXECUTE ON FUNCTION hosteleria.actualizar_stock_variante(uuid, integer) TO n8n_hosteleria, risesense_admin;
GRANT EXECUTE ON FUNCTION hosteleria.eliminar_variante(uuid) TO n8n_hosteleria, risesense_admin;


