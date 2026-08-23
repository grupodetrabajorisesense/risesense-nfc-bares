-- db/001_schema.sql
-- Schema inicial: hosteleria.establecimientos, mesas, categorias, productos, pedidos, pedido_lineas
-- Reconstruido desde el estado real de la BBDD (no existía como .sql hasta ahora)

CREATE SCHEMA IF NOT EXISTS hosteleria;

-- Table: hosteleria.establecimientos
CREATE TABLE IF NOT EXISTS hosteleria.establecimientos
(
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    nombre text COLLATE pg_catalog."default" NOT NULL,
    slug text COLLATE pg_catalog."default" NOT NULL,
    activo boolean NOT NULL DEFAULT true,
    moneda character(3) COLLATE pg_catalog."default" NOT NULL DEFAULT 'EUR'::bpchar,
    stripe_account_id text COLLATE pg_catalog."default",
    logo_url text COLLATE pg_catalog."default",
    color_primario text COLLATE pg_catalog."default" DEFAULT '#111111'::text,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    token text COLLATE pg_catalog."default" NOT NULL,
    CONSTRAINT establecimientos_pkey PRIMARY KEY (id),
    CONSTRAINT establecimientos_slug_key UNIQUE (slug),
    CONSTRAINT establecimientos_token_key UNIQUE (token)
)
TABLESPACE pg_default;
ALTER TABLE IF EXISTS hosteleria.establecimientos OWNER to risesense_admin;

-- Table: hosteleria.mesas
CREATE TABLE IF NOT EXISTS hosteleria.mesas
(
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    establecimiento_id uuid NOT NULL,
    numero text COLLATE pg_catalog."default" NOT NULL,
    token text COLLATE pg_catalog."default" NOT NULL,
    zona text COLLATE pg_catalog."default",
    activa boolean NOT NULL DEFAULT true,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT mesas_pkey PRIMARY KEY (id),
    CONSTRAINT mesas_token_key UNIQUE (token),
    CONSTRAINT mesas_establecimiento_id_fkey FOREIGN KEY (establecimiento_id)
        REFERENCES hosteleria.establecimientos (id) MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE CASCADE
)
TABLESPACE pg_default;
ALTER TABLE IF EXISTS hosteleria.mesas OWNER to risesense_admin;

CREATE INDEX IF NOT EXISTS idx_mesas_token
    ON hosteleria.mesas USING btree (token COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;

-- Table: hosteleria.categorias
CREATE TABLE IF NOT EXISTS hosteleria.categorias
(
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    establecimiento_id uuid NOT NULL,
    nombre text COLLATE pg_catalog."default" NOT NULL,
    orden integer NOT NULL DEFAULT 0,
    activa boolean NOT NULL DEFAULT true,
    CONSTRAINT categorias_pkey PRIMARY KEY (id),
    CONSTRAINT categorias_establecimiento_id_fkey FOREIGN KEY (establecimiento_id)
        REFERENCES hosteleria.establecimientos (id) MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE CASCADE
)
TABLESPACE pg_default;
ALTER TABLE IF EXISTS hosteleria.categorias OWNER to risesense_admin;

-- Table: hosteleria.productos
CREATE TABLE IF NOT EXISTS hosteleria.productos
(
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    establecimiento_id uuid NOT NULL,
    categoria_id uuid,
    nombre text COLLATE pg_catalog."default" NOT NULL,
    descripcion text COLLATE pg_catalog."default",
    precio_centimos integer NOT NULL,
    imagen_url text COLLATE pg_catalog."default",
    disponible boolean NOT NULL DEFAULT true,
    orden integer NOT NULL DEFAULT 0,
    CONSTRAINT productos_pkey PRIMARY KEY (id),
    CONSTRAINT productos_categoria_id_fkey FOREIGN KEY (categoria_id)
        REFERENCES hosteleria.categorias (id) MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE SET NULL,
    CONSTRAINT productos_establecimiento_id_fkey FOREIGN KEY (establecimiento_id)
        REFERENCES hosteleria.establecimientos (id) MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE CASCADE,
    CONSTRAINT productos_precio_centimos_check CHECK (precio_centimos >= 0)
)
TABLESPACE pg_default;
ALTER TABLE IF EXISTS hosteleria.productos OWNER to risesense_admin;

CREATE INDEX IF NOT EXISTS idx_productos_estab
    ON hosteleria.productos USING btree (establecimiento_id ASC NULLS LAST, categoria_id ASC NULLS LAST)
    TABLESPACE pg_default;

-- Table: hosteleria.pedidos
CREATE TABLE IF NOT EXISTS hosteleria.pedidos
(
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    establecimiento_id uuid NOT NULL,
    mesa_id uuid NOT NULL,
    estado text COLLATE pg_catalog."default" NOT NULL DEFAULT 'nuevo'::text,
    metodo_pago text COLLATE pg_catalog."default" NOT NULL DEFAULT 'online'::text,
    pagado boolean NOT NULL DEFAULT false,
    total_centimos integer NOT NULL DEFAULT 0,
    stripe_payment_intent_id text COLLATE pg_catalog."default",
    notas text COLLATE pg_catalog."default",
    pagado_at timestamp with time zone,
    created_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT pedidos_pkey PRIMARY KEY (id),
    CONSTRAINT pedidos_establecimiento_id_fkey FOREIGN KEY (establecimiento_id)
        REFERENCES hosteleria.establecimientos (id) MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE CASCADE,
    CONSTRAINT pedidos_mesa_id_fkey FOREIGN KEY (mesa_id)
        REFERENCES hosteleria.mesas (id) MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE RESTRICT,
    CONSTRAINT pedidos_estado_check CHECK (estado = ANY (ARRAY['pendiente_pago'::text, 'nuevo'::text, 'en_preparacion'::text, 'servido'::text, 'cancelado'::text])),
    CONSTRAINT pedidos_metodo_pago_check CHECK (metodo_pago = ANY (ARRAY['online'::text, 'efectivo'::text, 'caja'::text])),
    CONSTRAINT pedidos_total_centimos_check CHECK (total_centimos >= 0)
)
TABLESPACE pg_default;
ALTER TABLE IF EXISTS hosteleria.pedidos OWNER to risesense_admin;

CREATE INDEX IF NOT EXISTS idx_pedidos_estado
    ON hosteleria.pedidos USING btree (establecimiento_id ASC NULLS LAST, estado COLLATE pg_catalog."default" ASC NULLS LAST)
    TABLESPACE pg_default;
CREATE INDEX IF NOT EXISTS idx_pedidos_mesa
    ON hosteleria.pedidos USING btree (mesa_id ASC NULLS LAST)
    TABLESPACE pg_default;

-- Table: hosteleria.pedido_lineas
CREATE TABLE IF NOT EXISTS hosteleria.pedido_lineas
(
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    pedido_id uuid NOT NULL,
    producto_id uuid,
    nombre_producto text COLLATE pg_catalog."default" NOT NULL,
    precio_unitario_centimos integer NOT NULL,
    cantidad integer NOT NULL,
    subtotal_centimos integer NOT NULL,
    CONSTRAINT pedido_lineas_pkey PRIMARY KEY (id),
    CONSTRAINT pedido_lineas_pedido_id_fkey FOREIGN KEY (pedido_id)
        REFERENCES hosteleria.pedidos (id) MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE CASCADE,
    CONSTRAINT pedido_lineas_producto_id_fkey FOREIGN KEY (producto_id)
        REFERENCES hosteleria.productos (id) MATCH SIMPLE
        ON UPDATE NO ACTION ON DELETE SET NULL,
    CONSTRAINT pedido_lineas_cantidad_check CHECK (cantidad > 0)
)
TABLESPACE pg_default;
ALTER TABLE IF EXISTS hosteleria.pedido_lineas OWNER to risesense_admin;

CREATE INDEX IF NOT EXISTS idx_lineas_pedido
    ON hosteleria.pedido_lineas USING btree (pedido_id ASC NULLS LAST)
    TABLESPACE pg_default;
