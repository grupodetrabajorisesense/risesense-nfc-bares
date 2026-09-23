ALTER TABLE hosteleria.pedidos
  ADD COLUMN numero_pedido integer;

CREATE INDEX IF NOT EXISTS idx_pedidos_numero
  ON hosteleria.pedidos (establecimiento_id, numero_pedido);
