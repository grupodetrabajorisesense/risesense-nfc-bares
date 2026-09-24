-- db/028_get_productos_gestion_descripcion_imagen.sql
CREATE OR REPLACE FUNCTION hosteleria.get_productos_gestion(
    p_establecimiento_id uuid
)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = hosteleria, pg_temp
AS $$
  SELECT jsonb_build_object(
    'categorias', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', c.id,
        'nombre', c.nombre,
        'productos', COALESCE((
          SELECT jsonb_agg(jsonb_build_object(
            'id', p.id,
            'nombre', p.nombre,
            'precio_centimos', p.precio_centimos,
            'disponible', p.disponible,
            'stock', p.stock,
            'descripcion', p.descripcion,
            'imagen_url', p.imagen_url
          ) ORDER BY p.orden, p.nombre)
          FROM hosteleria.productos p
          WHERE p.categoria_id = c.id
            AND p.eliminado = false
        ), '[]'::jsonb)
      ) ORDER BY c.orden)
      FROM hosteleria.categorias c
      WHERE c.establecimiento_id = p_establecimiento_id
    ), '[]'::jsonb)
  );
$$;

ALTER FUNCTION hosteleria.get_productos_gestion(uuid) OWNER TO risesense_admin;
GRANT EXECUTE ON FUNCTION hosteleria.get_productos_gestion(uuid) TO n8n_hosteleria;
