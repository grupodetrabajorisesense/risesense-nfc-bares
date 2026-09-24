-- db/026_eliminar_categoria.sql
CREATE OR REPLACE FUNCTION hosteleria.eliminar_categoria(
    p_categoria_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = hosteleria, pg_temp
AS $$
DECLARE
  v_num_productos int;
BEGIN
  SELECT count(*) INTO v_num_productos
  FROM hosteleria.productos
  WHERE categoria_id = p_categoria_id
    AND eliminado = false;

  IF v_num_productos > 0 THEN
    RAISE EXCEPTION 'no se puede eliminar una categoria con productos';
  END IF;

  DELETE FROM hosteleria.categorias
  WHERE id = p_categoria_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'categoria no encontrada';
  END IF;

  RETURN jsonb_build_object(
    'categoria_id', p_categoria_id,
    'eliminada', true
  );
END;
$$;

ALTER FUNCTION hosteleria.eliminar_categoria(uuid) OWNER TO risesense_admin;
GRANT EXECUTE ON FUNCTION hosteleria.eliminar_categoria(uuid) TO n8n_hosteleria;
GRANT EXECUTE ON FUNCTION hosteleria.eliminar_categoria(uuid) TO risesense_admin;
REVOKE ALL ON FUNCTION hosteleria.eliminar_categoria(uuid) FROM PUBLIC;
