-- db/017_actualizar_stock_producto.sql
CREATE OR REPLACE FUNCTION hosteleria.actualizar_stock_producto(
    p_producto_id uuid,
    p_stock integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = hosteleria, pg_temp
AS $$
DECLARE
  v_prod hosteleria.productos%ROWTYPE;
BEGIN
  IF p_stock IS NOT NULL AND p_stock < 0 THEN
    RAISE EXCEPTION 'stock no puede ser negativo';
  END IF;

  UPDATE hosteleria.productos
  SET stock = p_stock
  WHERE id = p_producto_id
  RETURNING * INTO v_prod;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'producto no encontrado';
  END IF;

  RETURN jsonb_build_object(
    'id', v_prod.id,
    'nombre', v_prod.nombre,
    'stock', v_prod.stock
  );
END;
$$;

ALTER FUNCTION hosteleria.actualizar_stock_producto(uuid, integer) OWNER TO risesense_admin;
GRANT EXECUTE ON FUNCTION hosteleria.actualizar_stock_producto(uuid, integer) TO n8n_hosteleria;
GRANT EXECUTE ON FUNCTION hosteleria.actualizar_stock_producto(uuid, integer) TO risesense_admin;
REVOKE ALL ON FUNCTION hosteleria.actualizar_stock_producto(uuid, integer) FROM PUBLIC;
