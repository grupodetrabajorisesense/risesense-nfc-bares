-- db/022_gestion_producto_categoria.sql

CREATE OR REPLACE FUNCTION hosteleria.editar_producto(
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
  v_prod hosteleria.productos%ROWTYPE;
BEGIN
  IF p_nombre IS NULL OR btrim(p_nombre) = '' THEN
    RAISE EXCEPTION 'nombre obligatorio';
  END IF;
  IF p_precio_centimos IS NULL OR p_precio_centimos < 0 THEN
    RAISE EXCEPTION 'precio_centimos invalido';
  END IF;

  UPDATE hosteleria.productos
  SET nombre = p_nombre,
      precio_centimos = p_precio_centimos
  WHERE id = p_producto_id
    AND eliminado = false
  RETURNING * INTO v_prod;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'producto no encontrado';
  END IF;

  RETURN jsonb_build_object(
    'id', v_prod.id,
    'nombre', v_prod.nombre,
    'precio_centimos', v_prod.precio_centimos
  );
END;
$$;

ALTER FUNCTION hosteleria.editar_producto(uuid, text, integer) OWNER TO risesense_admin;
GRANT EXECUTE ON FUNCTION hosteleria.editar_producto(uuid, text, integer) TO n8n_hosteleria;
GRANT EXECUTE ON FUNCTION hosteleria.editar_producto(uuid, text, integer) TO risesense_admin;
REVOKE ALL ON FUNCTION hosteleria.editar_producto(uuid, text, integer) FROM PUBLIC;


CREATE OR REPLACE FUNCTION hosteleria.eliminar_producto(
    p_producto_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = hosteleria, pg_temp
AS $$
DECLARE
  v_prod hosteleria.productos%ROWTYPE;
BEGIN
  UPDATE hosteleria.productos
  SET eliminado = true
  WHERE id = p_producto_id
    AND eliminado = false
  RETURNING * INTO v_prod;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'producto no encontrado o ya estaba eliminado';
  END IF;

  RETURN jsonb_build_object(
    'id', v_prod.id,
    'eliminado', true
  );
END;
$$;

ALTER FUNCTION hosteleria.eliminar_producto(uuid) OWNER TO risesense_admin;
GRANT EXECUTE ON FUNCTION hosteleria.eliminar_producto(uuid) TO n8n_hosteleria;
GRANT EXECUTE ON FUNCTION hosteleria.eliminar_producto(uuid) TO risesense_admin;
REVOKE ALL ON FUNCTION hosteleria.eliminar_producto(uuid) FROM PUBLIC;


CREATE OR REPLACE FUNCTION hosteleria.editar_categoria(
    p_categoria_id uuid,
    p_nombre text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = hosteleria, pg_temp
AS $$
DECLARE
  v_cat hosteleria.categorias%ROWTYPE;
BEGIN
  IF p_nombre IS NULL OR btrim(p_nombre) = '' THEN
    RAISE EXCEPTION 'nombre obligatorio';
  END IF;

  UPDATE hosteleria.categorias
  SET nombre = p_nombre
  WHERE id = p_categoria_id
  RETURNING * INTO v_cat;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'categoria no encontrada';
  END IF;

  RETURN jsonb_build_object(
    'id', v_cat.id,
    'nombre', v_cat.nombre
  );
END;
$$;

ALTER FUNCTION hosteleria.editar_categoria(uuid, text) OWNER TO risesense_admin;
GRANT EXECUTE ON FUNCTION hosteleria.editar_categoria(uuid, text) TO n8n_hosteleria;
GRANT EXECUTE ON FUNCTION hosteleria.editar_categoria(uuid, text) TO risesense_admin;
REVOKE ALL ON FUNCTION hosteleria.editar_categoria(uuid, text) FROM PUBLIC;
