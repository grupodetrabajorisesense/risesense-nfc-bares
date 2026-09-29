-- db/036_panel_login_intentos.sql

CREATE TABLE IF NOT EXISTS hosteleria.panel_login_intentos
(
    id bigserial PRIMARY KEY,
    ip text NOT NULL,
    exitoso boolean NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE hosteleria.panel_login_intentos OWNER TO risesense_admin;

CREATE INDEX IF NOT EXISTS idx_panel_login_intentos_ip_fecha
  ON hosteleria.panel_login_intentos (ip, created_at);

CREATE OR REPLACE FUNCTION hosteleria.panel_login(
    p_pin text,
    p_ip text DEFAULT 'desconocida'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = hosteleria, pg_temp
AS $$
DECLARE
  v_estab       hosteleria.establecimientos%ROWTYPE;
  v_fallos_ip   integer;
BEGIN
  -- límite global: más de 10 fallos desde esta IP en los últimos 15 minutos → bloqueado
  SELECT count(*) INTO v_fallos_ip
  FROM hosteleria.panel_login_intentos
  WHERE ip = p_ip
    AND exitoso = false
    AND created_at > now() - INTERVAL '15 minutes';

  IF v_fallos_ip >= 10 THEN
    RAISE EXCEPTION 'demasiados intentos, inténtalo de nuevo en unos minutos';
  END IF;

  IF p_pin IS NULL OR p_pin !~ '^[0-9]{6}$' THEN
    INSERT INTO hosteleria.panel_login_intentos (ip, exitoso) VALUES (p_ip, false);
    RAISE EXCEPTION 'PIN incorrecto';
  END IF;

  SELECT * INTO v_estab
  FROM hosteleria.establecimientos
  WHERE pin_acceso = p_pin AND activo = true;

  IF NOT FOUND THEN
    INSERT INTO hosteleria.panel_login_intentos (ip, exitoso) VALUES (p_ip, false);
    RAISE EXCEPTION 'PIN incorrecto';
  END IF;

  INSERT INTO hosteleria.panel_login_intentos (ip, exitoso) VALUES (p_ip, true);

  RETURN jsonb_build_object(
    'establecimiento_id', v_estab.id,
    'nombre', v_estab.nombre
  );
END;
$$;

ALTER FUNCTION hosteleria.panel_login(text, text) OWNER TO risesense_admin;
GRANT EXECUTE ON FUNCTION hosteleria.panel_login(text, text) TO n8n_hosteleria;
GRANT EXECUTE ON FUNCTION hosteleria.panel_login(text, text) TO risesense_admin;
REVOKE ALL ON FUNCTION hosteleria.panel_login(text, text) FROM PUBLIC;
