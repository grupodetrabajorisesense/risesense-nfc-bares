-- db/020_stripe_eventos.sql
-- Idempotencia de los webhooks de Stripe: registro de eventos ya procesados.
-- Un mismo event.id de Stripe puede llegar varias veces (reintentos); se procesa UNA sola vez.
-- La PK sobre event_id es la que garantiza el "una sola vez" (vía ON CONFLICT DO NOTHING).
-- Dueño: Dev 2.

CREATE TABLE IF NOT EXISTS hosteleria.stripe_eventos
(
    event_id     text NOT NULL,
    tipo         text NOT NULL,
    pedido_id    uuid,
    procesado_at timestamp with time zone NOT NULL DEFAULT now(),
    CONSTRAINT stripe_eventos_pkey PRIMARY KEY (event_id)
)
TABLESPACE pg_default;

ALTER TABLE IF EXISTS hosteleria.stripe_eventos OWNER TO risesense_admin;
