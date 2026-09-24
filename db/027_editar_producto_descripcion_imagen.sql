-- db/027_editar_producto_descripcion_imagen.sql
CREATE OR REPLACE FUNCTION hosteleria.editar_producto(
    p_producto_id uuid,
    p_nombre text,
    p_precio_centimos integer,
    p_descripcion text DEFAULT NULL,
    p_imagen_url text DEFAULT NULL,
    p_actualizar_descripcion boolean DEFAULT false,
    p_actualizar_imagen boolean DEFAULT false
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
      precio_centimos = p_precio_centimos,
      descripcion = CASE WHEN p_actualizar_descripcion THEN p_descripcion ELSE descripcion END,
      imagen_url = CASE WHEN p_actualizar_imagen THEN p_imagen_url ELSE imagen_url END
  WHERE id = p_producto_id
    AND eliminado = false
  RETURNING * INTO v_prod;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'producto no encontrado';
  END IF;

  RETURN jsonb_build_object(
    'id', v_prod.id,
    'nombre', v_prod.nombre,
    'precio_centimos', v_prod.precio_centimos,
    'descripcion', v_prod.descripcion,
    'imagen_url', v_prod.imagen_url
  );
END;
$$;

ALTER FUNCTION hosteleria.editar_producto(uuid, text, integer, text, text, boolean, boolean) OWNER TO risesense_admin;
GRANT EXECUTE ON FUNCTION hosteleria.editar_producto(uuid, text, integer, text, text, boolean, boolean) TO n8n_hosteleria;
GRANT EXECUTE ON FUNCTION hosteleria.editar_producto(uuid, text, integer, text, text, boolean, boolean) TO risesense_admin;
REVOKE ALL ON FUNCTION hosteleria.editar_producto(uuid, text, integer, text, text, boolean, boolean) FROM PUBLIC;
