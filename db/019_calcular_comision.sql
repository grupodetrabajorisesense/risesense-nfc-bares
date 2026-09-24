-- db/019_calcular_comision.sql
-- Fórmula de la comisión de RiseSense (el application_fee_amount de Stripe), en céntimos.
-- ESTE es el único sitio donde vive la fórmula (ver DECISIONS.md). Si cambia el modelo
-- de negocio (fijo, %, mixto, con mínimo/tope), se cambia SOLO aquí.
-- Para test: 5% de marcador.
-- Dueño: Dev 2.

CREATE OR REPLACE FUNCTION hosteleria.calcular_comision_centimos(p_total_centimos int)
    RETURNS int
    LANGUAGE sql
    IMMUTABLE
AS $BODY$
  -- 5% del total. floor() para no pasarnos nunca del importe; GREATEST por seguridad.
  SELECT GREATEST(0, floor(COALESCE(p_total_centimos, 0) * 0.05))::int;
$BODY$;

ALTER FUNCTION hosteleria.calcular_comision_centimos(int) OWNER TO risesense_admin;

GRANT EXECUTE ON FUNCTION hosteleria.calcular_comision_centimos(int) TO bar_web;
GRANT EXECUTE ON FUNCTION hosteleria.calcular_comision_centimos(int) TO n8n_hosteleria;
GRANT EXECUTE ON FUNCTION hosteleria.calcular_comision_centimos(int) TO risesense_admin;
REVOKE ALL ON FUNCTION hosteleria.calcular_comision_centimos(int) FROM PUBLIC;
