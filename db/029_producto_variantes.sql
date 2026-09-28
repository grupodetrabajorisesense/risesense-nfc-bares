-- db/029_producto_variantes.sql
CREATE TABLE IF NOT EXISTS hosteleria.producto_variantes
(
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    producto_id uuid NOT NULL,
    nombre text NOT NULL,
    precio_centimos integer NOT NULL,
    stock integer,                       -- NULL = sin controlar
    orden integer NOT NULL DEFAULT 0,
    eliminado boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT producto_variantes_pkey PRIMARY KEY (id),
    CONSTRAINT producto_variantes_producto_fkey FOREIGN KEY (producto_id)
        REFERENCES hosteleria.productos (id) ON DELETE CASCADE,
    CONSTRAINT producto_variantes_precio_check CHECK (precio_centimos >= 0),
    CONSTRAINT producto_variantes_stock_check CHECK (stock IS NULL OR stock >= 0)
);
ALTER TABLE hosteleria.producto_variantes OWNER TO risesense_admin;

CREATE INDEX IF NOT EXISTS idx_variantes_producto
    ON hosteleria.producto_variantes (producto_id);

ALTER TABLE hosteleria.pedido_lineas
    ADD COLUMN variante_id uuid
    REFERENCES hosteleria.producto_variantes (id) ON DELETE SET NULL;
