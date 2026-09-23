-- db/008_get_pedidos_activos.sql
CREATE OR REPLACE FUNCTION hosteleria.get_pedidos_activos(
    p_establecimiento_id uuid
)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = hosteleria, pg_temp
AS $$
  SELECT COALESCE(jsonb_agg(pedido ORDER BY created_at), '[]'::jsonb)
  FROM (
    SELECT
      p.created_at AS created_at,
      jsonb_build_object(
        'pedido_id', p.id,
        'mesa_numero', m.numero,
        'estado', p.estado,
        'pagado', p.pagado,
        'metodo_pago', p.metodo_pago,
        'total_centimos', p.total_centimos,
        'created_at', p.created_at,
        'lineas', COALESCE((
          SELECT jsonb_agg(jsonb_build_object(
            'nombre_producto', pl.nombre_producto,
            'cantidad', pl.cantidad
          ))
          FROM hosteleria.pedido_lineas pl
          WHERE pl.pedido_id = p.id
        ), '[]'::jsonb)
      ) AS pedido
    FROM hosteleria.pedidos p
    JOIN hosteleria.mesas m ON m.id = p.mesa_id
    WHERE p.establecimiento_id = p_establecimiento_id
      AND p.estado IN ('nuevo', 'en_preparacion', 'servido')
      AND p.created_at >= CURRENT_DATE
  ) sub;
$$;

ALTER FUNCTION hosteleria.get_pedidos_activos(uuid) OWNER TO risesense_admin;
GRANT EXECUTE ON FUNCTION hosteleria.get_pedidos_activos(uuid) TO n8n_hosteleria;
GRANT EXECUTE ON FUNCTION hosteleria.get_pedidos_activos(uuid) TO risesense_admin;
REVOKE ALL ON FUNCTION hosteleria.get_pedidos_activos(uuid) FROM PUBLIC;
