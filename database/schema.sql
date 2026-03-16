-- ============================================================
-- Bodeguín — Schema de Base de Datos
-- Proyecto: TECHO Puebla — Gestión de herramienta
-- Autor: Luis Humberto Islas Guzmán
-- Base de datos: Supabase (PostgreSQL)
-- ============================================================


-- ============================================================
-- TABLAS
-- ============================================================

CREATE TABLE articulos (
    id_articulo  SERIAL PRIMARY KEY,
    nombre       VARCHAR NOT NULL,
    descripcion  VARCHAR
);

CREATE TABLE ubicaciones (
    id_ubicacion  SERIAL PRIMARY KEY,
    nombre_lugar  VARCHAR NOT NULL,
    direccion     VARCHAR
);

CREATE TABLE usuarios (
    id_usuario   SERIAL PRIMARY KEY,
    nom_usuario  VARCHAR NOT NULL,
    telefono_wa  VARCHAR NOT NULL,
    rol          VARCHAR DEFAULT 'Voluntario',  -- 'Voluntario' | 'Staff' | 'Administrador'
    telegram_id  BIGINT UNIQUE
);

CREATE TABLE inventario (
    id_inventario  SERIAL PRIMARY KEY,
    id_articulo    INTEGER NOT NULL REFERENCES articulos(id_articulo),
    id_ubicacion   INTEGER NOT NULL REFERENCES ubicaciones(id_ubicacion),
    id_encargado   INTEGER REFERENCES usuarios(id_usuario),  -- NULL = en bodega
    estado         VARCHAR DEFAULT 'Bueno',                  -- 'Bueno' | 'Roto' | 'Perdido' | 'Reparacion'
    cantidad       INTEGER DEFAULT 0
);

CREATE TABLE construcciones (
    id_construccion  SERIAL PRIMARY KEY,
    nombre           VARCHAR NOT NULL,
    ubicacion        VARCHAR NOT NULL,
    fecha_inicio     DATE NOT NULL,
    fecha_fin        DATE            -- NULL = construcción activa
);

CREATE TABLE cuadrillas (
    id_cuadrilla     SERIAL PRIMARY KEY,
    id_construccion  INTEGER NOT NULL REFERENCES construcciones(id_construccion),
    nombre           VARCHAR NOT NULL,
    id_lider         INTEGER NOT NULL REFERENCES usuarios(id_usuario)
);

CREATE TABLE asignacion_herramienta (
    id_asignacion      SERIAL PRIMARY KEY,
    id_cuadrilla       INTEGER NOT NULL REFERENCES cuadrillas(id_cuadrilla),
    id_articulo        INTEGER NOT NULL REFERENCES articulos(id_articulo),
    cantidad_asignada  INTEGER NOT NULL,
    cantidad_regresada INTEGER,        -- NULL = no regresado aún
    estado_regreso     VARCHAR         -- NULL | 'Completo' | 'Parcial'
);


-- ============================================================
-- VISTAS
-- ============================================================

-- Vista de inventario general (bodega)
CREATE VIEW vista_inventario AS
SELECT
    a.nombre       AS articulo,
    u.nombre_lugar AS ubicacion,
    i.estado,
    i.cantidad,
    us.nom_usuario AS encargado
FROM inventario i
JOIN articulos  a  ON i.id_articulo  = a.id_articulo
JOIN ubicaciones u ON i.id_ubicacion = u.id_ubicacion
LEFT JOIN usuarios us ON i.id_encargado = us.id_usuario;

-- Vista de herramienta faltante por cuadrilla (construcciones activas)
CREATE VIEW vista_faltantes AS
SELECT
    c.nombre                                        AS cuadrilla,
    u.nom_usuario                                   AS lider,
    a.nombre                                        AS articulo,
    ah.cantidad_asignada,
    COALESCE(ah.cantidad_regresada, 0)              AS cantidad_regresada,
    ah.cantidad_asignada - COALESCE(ah.cantidad_regresada, 0) AS cantidad_faltante,
    ah.estado_regreso,
    co.nombre                                       AS construccion
FROM asignacion_herramienta ah
JOIN cuadrillas   c  ON ah.id_cuadrilla  = c.id_cuadrilla
JOIN usuarios     u  ON c.id_lider       = u.id_usuario
JOIN articulos    a  ON ah.id_articulo   = a.id_articulo
JOIN construcciones co ON c.id_construccion = co.id_construccion
WHERE co.fecha_fin IS NULL  -- Solo construcciones activas
  AND (ah.cantidad_regresada IS NULL OR ah.cantidad_regresada < ah.cantidad_asignada);


-- ============================================================
-- RPCs (Stored Procedures)
-- ============================================================

-- Sacar material de bodega a un encargado
CREATE OR REPLACE FUNCTION pedir_material(
    p_id_articulo          INTEGER,
    p_id_ubicacion_origen  INTEGER,
    p_id_ubicacion_destino INTEGER,
    p_id_usuario           INTEGER,
    p_cantidad             INTEGER,
    p_estado               VARCHAR
)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    stock_disponible INT;
    filas_afectadas  INT;
BEGIN
    IF p_cantidad <= 0 THEN
        RAISE EXCEPTION 'La cantidad debe ser mayor a cero';
    END IF;

    IF p_estado NOT IN ('Bueno', 'Roto', 'Perdido', 'Reparacion') THEN
        RAISE EXCEPTION 'Estado no válido';
    END IF;

    SELECT cantidad INTO stock_disponible
    FROM inventario
    WHERE id_articulo  = p_id_articulo
      AND id_ubicacion = p_id_ubicacion_origen
      AND id_encargado IS NULL
      AND estado = p_estado
    FOR UPDATE;

    IF stock_disponible IS NULL OR stock_disponible < p_cantidad THEN
        RAISE EXCEPTION 'Stock insuficiente en bodega';
    END IF;

    -- Restar de bodega
    UPDATE inventario
    SET cantidad = cantidad - p_cantidad
    WHERE id_articulo  = p_id_articulo
      AND id_ubicacion = p_id_ubicacion_origen
      AND id_encargado IS NULL
      AND estado = p_estado;

    -- Sumar al encargado
    UPDATE inventario
    SET cantidad = cantidad + p_cantidad
    WHERE id_articulo  = p_id_articulo
      AND id_ubicacion = p_id_ubicacion_destino
      AND id_encargado = p_id_usuario
      AND estado = p_estado;

    GET DIAGNOSTICS filas_afectadas = ROW_COUNT;

    IF filas_afectadas = 0 THEN
        INSERT INTO inventario (id_articulo, id_ubicacion, id_encargado, estado, cantidad)
        VALUES (p_id_articulo, p_id_ubicacion_destino, p_id_usuario, p_estado, p_cantidad);
    END IF;

    DELETE FROM inventario WHERE cantidad <= 0;
END;
$$;

-- Regresar material de encargado a bodega
CREATE OR REPLACE FUNCTION regresar_material(
    p_id_articulo            INTEGER,
    p_id_ubicacion_origen    INTEGER,
    p_id_ubicacion_destino   INTEGER,
    p_id_usuario             INTEGER,
    p_cantidad               INTEGER,
    p_estado                 VARCHAR
)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    filas_afectadas INT;
BEGIN
    IF p_cantidad <= 0 THEN
        RAISE EXCEPTION 'La cantidad debe ser mayor a cero';
    END IF;

    IF p_estado NOT IN ('Bueno', 'Roto', 'Perdido', 'Reparacion') THEN
        RAISE EXCEPTION 'Estado no válido';
    END IF;

    -- Sumar a bodega destino
    UPDATE inventario
    SET cantidad = cantidad + p_cantidad
    WHERE id_articulo  = p_id_articulo
      AND id_ubicacion = p_id_ubicacion_destino
      AND id_encargado IS NULL
      AND estado = p_estado;

    GET DIAGNOSTICS filas_afectadas = ROW_COUNT;

    IF filas_afectadas = 0 THEN
        INSERT INTO inventario (id_articulo, id_ubicacion, id_encargado, estado, cantidad)
        VALUES (p_id_articulo, p_id_ubicacion_destino, NULL, p_estado, p_cantidad);
    END IF;

    -- Restar del encargado
    UPDATE inventario
    SET cantidad = cantidad - p_cantidad
    WHERE id_articulo  = p_id_articulo
      AND id_ubicacion = p_id_ubicacion_origen
      AND id_encargado = p_id_usuario
      AND estado = p_estado;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No se encontró inventario suficiente para regresar';
    END IF;

    DELETE FROM inventario WHERE cantidad <= 0;
END;
$$;

-- Regresar todo el material al inventario general (solo Administradores)
CREATE OR REPLACE FUNCTION regresar_todo_a_bodega(
    p_id_bodega INTEGER
)
RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO inventario (id_articulo, id_ubicacion, id_encargado, estado, cantidad)
    SELECT id_articulo, p_id_bodega, NULL, estado, SUM(cantidad)
    FROM inventario
    WHERE id_encargado IS NOT NULL
    GROUP BY id_articulo, estado;

    DELETE FROM inventario WHERE id_encargado IS NOT NULL;

    -- Consolidar duplicados en bodega
    DELETE FROM inventario a
    USING inventario b
    WHERE a.ctid < b.ctid
      AND a.id_articulo  = b.id_articulo
      AND a.id_ubicacion = b.id_ubicacion
      AND a.estado       = b.estado
      AND a.id_encargado IS NULL
      AND b.id_encargado IS NULL;
END;
$$;

-- Registrar asignación de herramienta a cuadrilla
CREATE OR REPLACE FUNCTION asignar_herramienta(
    p_id_cuadrilla    INTEGER,
    p_id_articulo     INTEGER,
    p_cantidad_asignada INTEGER
)
RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO asignacion_herramienta (
        id_cuadrilla,
        id_articulo,
        cantidad_asignada,
        cantidad_regresada,
        estado_regreso
    ) VALUES (
        p_id_cuadrilla,
        p_id_articulo,
        p_cantidad_asignada,
        NULL,
        NULL
    );
END;
$$;

-- Registrar regreso de herramienta de cuadrilla
CREATE OR REPLACE FUNCTION regresar_herramienta_cuadrilla(
    p_id_cuadrilla      INTEGER,
    p_id_articulo       INTEGER,
    p_cantidad_regresada INTEGER,
    p_estado_regreso    VARCHAR
)
RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    UPDATE asignacion_herramienta
    SET cantidad_regresada = p_cantidad_regresada,
        estado_regreso     = p_estado_regreso
    WHERE id_cuadrilla = p_id_cuadrilla
      AND id_articulo  = p_id_articulo;
END;
$$;
