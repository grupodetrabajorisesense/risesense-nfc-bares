-- db/004_get_carta_token_bar.sql
-- get_carta ahora busca por el token del establecimiento (QR único por bar)
-- y devuelve mesas[] en vez de una sola mesa

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
              SELECT jsonb_agg(jsonb_build_object(
                'id', p.id,
                'nombre', p.nombre,
                'descripcion', p.descripcion,
                'precio_centimos', p.precio_centimos,
                'imagen_url', p.imagen_url
              ) ORDER BY p.orden, p.nombre)
              FROM hosteleria.productos p
              WHERE p.categoria_id = c.id
                AND p.disponible = true
            ), '[]'::jsonb)
          ) AS cat
        FROM hosteleria.categorias c
        WHERE c.establecimiento_id = e.id
          AND c.activa = true
      ) sub
    ), '[]'::jsonb)
  )
  FROM hosteleria.establecimientos e
  WHERE e.token = p_token
    AND e.activo = true;
$BODY$;

ALTER FUNCTION hosteleria.get_carta(text)
    OWNER TO risesense_admin;

GRANT EXECUTE ON FUNCTION hosteleria.get_carta(text) TO bar_web;
GRANT EXECUTE ON FUNCTION hosteleria.get_carta(text) TO risesense_admin;
REVOKE ALL ON FUNCTION hosteleria.get_carta(text) FROM PUBLIC;
