-- db/036_panel_login.sql

CREATE OR REPLACE FUNCTION hosteleria.panel_login(
    p_pin text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = hosteleria, pg_temp
AS $$
DECLARE
  v_estab hosteleria.establecimientos%ROWTYPE;
BEGIN
  IF p_pin IS NULL OR p_pin !~ '^[0-9]{6}$' THEN
    RAISE EXCEPTION 'PIN incorrecto';
  END IF;

  SELECT * INTO v_estab
  FROM hosteleria.establecimientos
  WHERE pin_acceso = p_pin AND activo = true;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'PIN incorrecto';
  END IF;

  IF v_estab.pin_bloqueado_hasta IS NOT NULL AND v_estab.pin_bloqueado_hasta > now() THEN
    RAISE EXCEPTION 'demasiados intentos, inténtalo de nuevo en unos minutos';
  END IF;

  -- PIN correcto: resetea el contador
  UPDATE hosteleria.establecimientos
  SET pin_intentos_fallidos = 0, pin_bloqueado_hasta = NULL
  WHERE id = v_estab.id;

  RETURN jsonb_build_object(
    'establecimiento_id', v_estab.id,
    'nombre', v_estab.nombre
  );
END;
$$;

ALTER FUNCTION hosteleria.panel_login(text) OWNER TO risesense_admin;
GRANT EXECUTE ON FUNCTION hosteleria.panel_login(text) TO n8n_hosteleria;
GRANT EXECUTE ON FUNCTION hosteleria.panel_login(text) TO risesense_admin;
REVOKE ALL ON FUNCTION hosteleria.panel_login(text) FROM PUBLIC;
