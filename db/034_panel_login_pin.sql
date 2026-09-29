-- db/034_panel_login_pin.sql

ALTER TABLE hosteleria.establecimientos
  ADD COLUMN pin_acceso char(6),
  ADD COLUMN pin_intentos_fallidos integer NOT NULL DEFAULT 0,
  ADD COLUMN pin_bloqueado_hasta timestamptz;

ALTER TABLE hosteleria.establecimientos
  ADD CONSTRAINT establecimientos_pin_acceso_key UNIQUE (pin_acceso);

ALTER TABLE hosteleria.establecimientos
  ADD CONSTRAINT establecimientos_pin_formato_check
  CHECK (pin_acceso IS NULL OR pin_acceso ~ '^[0-9]{6}$');

CREATE INDEX IF NOT EXISTS idx_establecimientos_pin
  ON hosteleria.establecimientos (pin_acceso);
