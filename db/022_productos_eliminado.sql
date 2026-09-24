-- db/019_productos_eliminado.sql (ajusta el número si hace falta)
ALTER TABLE hosteleria.productos
  ADD COLUMN eliminado boolean NOT NULL DEFAULT false;
