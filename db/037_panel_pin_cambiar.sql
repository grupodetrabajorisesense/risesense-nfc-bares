-- db/037_panel_pin_cambiar.sql

CREATE OR REPLACE FUNCTION hosteleria.panel_pin_cambiar(
    p_establecimiento_id uuid,
    p_pin_actual text,
    p_pin_nuevo text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = hosteleria, pg_temp
AS $$
DECLARE
  v_estab hosteleria.establecimientos%ROWTYPE;
BEGIN
  IF p_pin_nuevo IS NULL OR p_pin_nuevo !~ '^[0-9]{6}$' THEN
    RETURN jsonb_build_object('error', 'el PIN nuevo debe tener 6 dígitos');
  END IF;

  SELECT * INTO v_estab
  FROM hosteleria.establecimientos
  WHERE id = p_establecimiento_id AND activo = true;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('error', 'establecimiento no encontrado');
  END IF;

  IF v_estab.pin_acceso IS DISTINCT FROM p_pin_actual THEN
    RETURN jsonb_build_object('error', 'PIN actual incorrecto');
  END IF;

  IF EXISTS (
    SELECT 1 FROM hosteleria.establecimientos
    WHERE pin_acceso = p_pin_nuevo AND id <> p_establecimiento_id
  ) THEN
    RETURN jsonb_build_object('error', 'ese PIN ya está en uso, elige otro');
  END IF;

  UPDATE hosteleria.establecimientos
  SET pin_acceso = p_pin_nuevo
  WHERE id = p_establecimiento_id;

  RETURN jsonb_build_object('ok', true);
END;
$$;

ALTER FUNCTION hosteleria.panel_pin_cambiar(uuid, text, text) OWNER TO risesense_admin;
GRANT EXECUTE ON FUNCTION hosteleria.panel_pin_cambiar(uuid, text, text) TO n8n_hosteleria;
GRANT EXECUTE ON FUNCTION hosteleria.panel_pin_cambiar(uuid, text, text) TO risesense_admin;
REVOKE ALL ON FUNCTION hosteleria.panel_pin_cambiar(uuid, text, text) FROM PUBLIC;
