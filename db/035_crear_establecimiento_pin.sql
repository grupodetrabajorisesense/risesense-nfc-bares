-- db/035_crear_establecimiento_pin.sql

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
  v_pin   text;
  v_estab hosteleria.establecimientos%ROWTYPE;
BEGIN
  IF p_nombre IS NULL OR btrim(p_nombre) = '' THEN
    RAISE EXCEPTION 'nombre obligatorio';
  END IF;
  IF p_slug IS NULL OR btrim(p_slug) = '' THEN
    RAISE EXCEPTION 'slug obligatorio';
  END IF;

  v_token := upper(substr(encode(gen_random_bytes(8), 'hex'), 1, 10));

  LOOP
    v_pin := lpad(floor(random() * 1000000)::text, 6, '0');
    EXIT WHEN NOT EXISTS (SELECT 1 FROM hosteleria.establecimientos WHERE pin_acceso = v_pin);
  END LOOP;

  INSERT INTO hosteleria.establecimientos (nombre, slug, token, pin_acceso)
  VALUES (p_nombre, p_slug, v_token, v_pin)
  RETURNING * INTO v_estab;

  RETURN jsonb_build_object(
    'id', v_estab.id,
    'nombre', v_estab.nombre,
    'slug', v_estab.slug,
    'token', v_estab.token,
    'pin_acceso', v_estab.pin_acceso,
    'moneda', v_estab.moneda
  );
END;
$$;

ALTER FUNCTION hosteleria.crear_establecimiento(text, text) OWNER TO risesense_admin;
GRANT EXECUTE ON FUNCTION hosteleria.crear_establecimiento(text, text) TO n8n_hosteleria;
GRANT EXECUTE ON FUNCTION hosteleria.crear_establecimiento(text, text) TO risesense_admin;
REVOKE ALL ON FUNCTION hosteleria.crear_establecimiento(text, text) FROM PUBLIC;
