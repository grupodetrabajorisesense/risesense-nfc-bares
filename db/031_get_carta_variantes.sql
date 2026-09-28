-- db/031_get_carta_variantes.sql
CREATE OR REPLACE FUNCTION hosteleria.get_carta(
	p_token text)
    RETURNS jsonb
    LANGUAGE 'sql'
    COST 100
    STABLE SECURITY DEFINER PARALLEL UNSAFE
    SET search_path=hosteleria, pg_temp
AS $BODY$
  SELECT jsonb_build_object(
    'establecimiento', jsonb_build_object(
      'id', e.id,
      'nombre', e.nombre,
      'moneda', e.moneda,
      'logo_url', e.logo_url,
      'color_primario', e.color_primario
    ),
    'mesas', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', m.id,
        'numero', m.numero,
        'zona', m.zona
      ) ORDER BY m.numero)
      FROM hosteleria.mesas m
      WHERE m.establecimiento_id = e.id
        AND m.activa = true
    ), '[]'::jsonb),
    'categorias', COALESCE((
      SELECT jsonb_agg(cat ORDER BY orden)
      FROM (
        SELECT c.orden AS orden,
          jsonb_build_object(
            'id', c.id,
            'nombre', c.nombre,
            'productos', COALESCE((
              SELECT jsonb_agg(
                jsonb_build_object(
                  'id', p.id,
                  'nombre', p.nombre,
                  'descripcion', p.descripcion,
                  'precio_centimos', p.precio_centimos,
                  'imagen_url', p.imagen_url,
                  'solo_pago_presencial', (p.stock IS NOT NULL AND p.stock > 0 AND p.stock <= 3)
                )
                || CASE WHEN vs.variantes IS NOT NULL
                        THEN jsonb_build_object('variantes', vs.variantes)
                        ELSE '{}'::jsonb END
                ORDER BY p.orden, p.nombre)
              FROM hosteleria.productos p
              LEFT JOIN LATERAL (
                SELECT jsonb_agg(jsonb_build_object(
                  'id', v.id,
                  'nombre', v.nombre,
                  'precio_centimos', v.precio_centimos,
                  'solo_pago_presencial', (v.stock IS NOT NULL AND v.stock > 0 AND v.stock <= 3)
                ) ORDER BY v.orden, v.precio_centimos) AS variantes
                FROM hosteleria.producto_variantes v
                WHERE v.producto_id = p.id
                  AND v.eliminado = false
                  AND (v.stock IS NULL OR v.stock > 0)
              ) vs ON true
              WHERE p.categoria_id = c.id
                AND p.eliminado = false
                AND p.disponible = true
                AND (p.stock IS NULL OR p.stock > 0)
            ), '[]'::jsonb)
          ) AS cat
        FROM hosteleria.categorias c
        WHERE c.establecimiento_id = e.id
          AND c.activa = true
      ) sub
    ), '[]'::jsonb)
  )
  FROM hosteleria.establecimientos e
    AND e.activo = true;
$BODY$;

ALTER FUNCTION hosteleria.get_carta(text) OWNER TO risesense_admin;
GRANT EXECUTE ON FUNCTION hosteleria.get_carta(text) TO bar_web;
GRANT EXECUTE ON FUNCTION hosteleria.get_carta(text) TO risesense_admin;
REVOKE ALL ON FUNCTION hosteleria.get_carta(text) FROM PUBLIC;
