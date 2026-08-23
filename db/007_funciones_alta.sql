-- db/007_funciones_alta.sql
-- Funciones de gestión: crear establecimiento, mesa, categoria, producto.
-- Solo ejecutables por n8n_hosteleria / risesense_admin, NO por bar_web
-- (no son de cara al cliente final, son de gestión/backoffice).

-- 1. crear_establecimiento
CREATE OR REPLACE FUNCTION hosteleria.crear_establecimiento(
    p_nombre text,
    p_slug text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = hosteleria, pg_temp
AS $$
DECLARE
  v_token text;
  v_estab hosteleria.establecimientos%ROWTYPE;
BEGIN
  IF p_nombre IS NULL OR btrim(p_nombre) = '' THEN
    RAISE EXCEPTION 'nombre obligatorio';
  END IF;
  IF p_slug IS NULL OR btrim(p_slug) = '' THEN
    RAISE EXCEPTION 'slug obligatorio';
  END IF;

  -- token aleatorio, legible, sin ambigüedad (sin 0/O/1/I)
  v_token := upper(substr(encode(gen_random_bytes(8), 'hex'), 1, 10));

  INSERT INTO hosteleria.establecimientos (nombre, slug, token)
  VALUES (p_nombre, p_slug, v_token)
  RETURNING * INTO v_estab;

  RETURN jsonb_build_object(
    'id', v_estab.id,
    'nombre', v_estab.nombre,
    'slug', v_estab.slug,
    'token', v_estab.token,
    'moneda', v_estab.moneda
  );
END;
$$;

ALTER FUNCTION hosteleria.crear_establecimiento(text, text) OWNER TO risesense_admin;
GRANT EXECUTE ON FUNCTION hosteleria.crear_establecimiento(text, text) TO n8n_hosteleria;
GRANT EXECUTE ON FUNCTION hosteleria.crear_establecimiento(text, text) TO risesense_admin;
REVOKE ALL ON FUNCTION hosteleria.crear_establecimiento(text, text) FROM PUBLIC;

-- 2. crear_mesa
CREATE OR REPLACE FUNCTION hosteleria.crear_mesa(
    p_establecimiento_id uuid,
    p_numero text,
    p_zona text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql

  INSERT INTO hosteleria.mesas (establecimiento_id, numero, zona, token)
  VALUES (p_establecimiento_id, p_numero, p_zona, NULL)
  RETURNING * INTO v_mesa;

  RETURN jsonb_build_object(
    'id', v_mesa.id,
    'numero', v_mesa.numero,
    'zona', v_mesa.zona
  );
END;
$$;

ALTER FUNCTION hosteleria.crear_mesa(uuid, text, text) OWNER TO risesense_admin;
GRANT EXECUTE ON FUNCTION hosteleria.crear_mesa(uuid, text, text) TO n8n_hosteleria;
GRANT EXECUTE ON FUNCTION hosteleria.crear_mesa(uuid, text, text) TO risesense_admin;
REVOKE ALL ON FUNCTION hosteleria.crear_mesa(uuid, text, text) FROM PUBLIC;

-- 3. crear_categoria
CREATE OR REPLACE FUNCTION hosteleria.crear_categoria(
    p_establecimiento_id uuid,
    p_nombre text,
    p_orden integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = hosteleria, pg_temp
AS $$
DECLARE
  v_cat hosteleria.categorias%ROWTYPE;
BEGIN
    'orden', v_cat.orden
  );
END;
GRANT EXECUTE ON FUNCTION hosteleria.crear_categoria(uuid, text, integer) TO n8n_hosteleria;
GRANT EXECUTE ON FUNCTION hosteleria.crear_categoria(uuid, text, integer) TO risesense_admin;
REVOKE ALL ON FUNCTION hosteleria.crear_categoria(uuid, text, integer) FROM PUBLIC;

    p_categoria_id uuid,
    p_nombre text,
    p_descripcion text,
    p_precio_centimos integer,
    p_imagen_url text DEFAULT NULL,
    p_orden integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = hosteleria, pg_temp
AS $$
DECLARE
  v_prod hosteleria.productos%ROWTYPE;
BEGIN
  IF NOT EXISTS (
    RAISE EXCEPTION 'categoria no pertenece a este establecimiento';
  END IF;
  VALUES
    (p_establecimiento_id, p_categoria_id, p_nombre, p_descripcion, p_precio_centimos, p_imagen_url, p_orden)
  RETURNING * INTO v_prod;

  RETURN jsonb_build_object(
    'id', v_prod.id,
    'nombre', v_prod.nombre,
    'descripcion', v_prod.descripcion,
    'precio_centimos', v_prod.precio_centimos,
    'imagen_url', v_prod.imagen_url
  );
END;
$$;

ALTER FUNCTION hosteleria.crear_producto(uuid, uuid, text, text, integer, text, integer) OWNER TO risesense_admin;
GRANT EXECUTE ON FUNCTION hosteleria.crear_producto(uuid, uuid, text, text, integer, text, integer) TO n8n_hosteleria;
GRANT EXECUTE ON FUNCTION hosteleria.crear_producto(uuid, uuid, text, text, integer, text, integer) TO risesense_admin;
REVOKE ALL ON FUNCTION hosteleria.crear_producto(uuid, uuid, text, text, integer, text, integer) FROM PUBLIC;
  INSERT INTO hosteleria.productos
    (establecimiento_id, categoria_id, nombre, descripcion, precio_centimos, imagen_url, orden)
    SELECT 1 FROM hosteleria.categorias
    WHERE id = p_categoria_id AND establecimiento_id = p_establecimiento_id
  ) THEN
    SELECT 1 FROM hosteleria.establecimientos

  IF p_categoria_id IS NOT NULL AND NOT EXISTS (
    WHERE id = p_establecimiento_id AND activo = true
    RAISE EXCEPTION 'precio_centimos invalido';
  END IF;
  ) THEN
    RAISE EXCEPTION 'establecimiento no encontrado o inactivo';
  IF p_precio_centimos IS NULL OR p_precio_centimos < 0 THEN
  END IF;
  END IF;


  IF p_nombre IS NULL OR btrim(p_nombre) = '' THEN
    RAISE EXCEPTION 'nombre de producto obligatorio';
-- 4. crear_producto
CREATE OR REPLACE FUNCTION hosteleria.crear_producto(
    p_establecimiento_id uuid,
$$;

ALTER FUNCTION hosteleria.crear_categoria(uuid, text, integer) OWNER TO risesense_admin;
  IF NOT EXISTS (
    SELECT 1 FROM hosteleria.establecimientos
    'nombre', v_cat.nombre,

  RETURN jsonb_build_object(
    'id', v_cat.id,
    WHERE id = p_establecimiento_id AND activo = true
  VALUES (p_establecimiento_id, p_nombre, p_orden)
  RETURNING * INTO v_cat;
  ) THEN
    RAISE EXCEPTION 'establecimiento no encontrado o inactivo';
  INSERT INTO hosteleria.categorias (establecimiento_id, nombre, orden)
  END IF;
  END IF;


  IF p_nombre IS NULL OR btrim(p_nombre) = '' THEN
    RAISE EXCEPTION 'nombre de categoria obligatorio';
    RAISE EXCEPTION 'establecimiento no encontrado o inactivo';
    RAISE EXCEPTION 'numero de mesa obligatorio';
  END IF;
  END IF;

  IF p_numero IS NULL OR btrim(p_numero) = '' THEN
SECURITY DEFINER
SET search_path = hosteleria, pg_temp
  ) THEN
AS $$
    SELECT 1 FROM hosteleria.establecimientos
    WHERE id = p_establecimiento_id AND activo = true
DECLARE
  v_mesa hosteleria.mesas%ROWTYPE;
  IF NOT EXISTS (

