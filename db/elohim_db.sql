-- ============================================================
--  Inversiones Elohim, S.A. — Script mínimo PostgreSQL
--  Ajustado según P01DB.json
-- ============================================================

DROP DATABASE IF EXISTS elohim_db;
DROP ROLE IF EXISTS elohim_user;

CREATE ROLE elohim_user WITH LOGIN PASSWORD 'ElohimS3cur3!';
CREATE DATABASE elohim_db WITH OWNER = elohim_user ENCODING = 'UTF8';

\c elohim_db

-- ------------------------------------------------------------
-- Tablas maestras
-- ------------------------------------------------------------
CREATE TABLE Rol (
    id             VARCHAR(255) PRIMARY KEY,
    nombre         VARCHAR(30)  NOT NULL,
    descripcion    TEXT,
    fecha_creacion TIMESTAMP
);

CREATE TABLE Marca (
    id           VARCHAR(255) PRIMARY KEY,
    nombre_marca VARCHAR(15)  NOT NULL,
    descripcion  TEXT
);

CREATE TABLE Categoria (
    id               VARCHAR(255) PRIMARY KEY,
    nombre_categoria VARCHAR(15)  NOT NULL,
    descripcion      TEXT,
    fecha_creacion   TIMESTAMP
);

CREATE TABLE MetodoPago (
    id_metodo_pago VARCHAR(255) PRIMARY KEY,
    nombre_metodo  VARCHAR(15)  NOT NULL,
    descripcion    TEXT,
    activo         BOOLEAN      NOT NULL
);

CREATE TABLE TipoCliente (
    id_tipo        VARCHAR(255) PRIMARY KEY,
    nombre         VARCHAR(15)  NOT NULL,
    descripcion    TEXT,
    fecha_creacion TIMESTAMP    NOT NULL
);

-- ------------------------------------------------------------
-- Usuarios
-- ------------------------------------------------------------
CREATE TABLE Cliente (
    id_cliente      VARCHAR(255) PRIMARY KEY,
    correo          VARCHAR(100) NOT NULL,
    nombre          VARCHAR(30)  NOT NULL,
    apellido        VARCHAR(30),
    telefono        VARCHAR(30),
    contrasena      VARCHAR(255) NOT NULL,
    direccion       TEXT,
    tipo_cliente_id VARCHAR(255) REFERENCES TipoCliente (id_tipo),
    fecha_registro  TIMESTAMP    NOT NULL,
    estado_cuenta   BOOLEAN      NOT NULL
);

CREATE TABLE Administrador (
    id_usuario     VARCHAR(255) PRIMARY KEY,
    correo         VARCHAR(100) NOT NULL,
    nombre         VARCHAR(30)  NOT NULL,
    apellido       VARCHAR(30),
    telefono       VARCHAR(30),
    contrasena     VARCHAR(255) NOT NULL,
    id_rol         VARCHAR(255) REFERENCES Rol (id),
    estado         VARCHAR(255),
    fecha_creacion TIMESTAMP    NOT NULL
);

CREATE TABLE Consulta (
    id_consulta    VARCHAR(255) PRIMARY KEY,
    id_cliente     VARCHAR(255) NOT NULL REFERENCES Cliente      (id_cliente),
    id_usuario     VARCHAR(255) NOT NULL REFERENCES Administrador(id_usuario),
    fecha_consulta TIMESTAMP    NOT NULL
);

-- ------------------------------------------------------------
-- Catálogo
-- ------------------------------------------------------------
CREATE TABLE Producto (
    id_producto         VARCHAR(255) PRIMARY KEY,
    codigo_producto     VARCHAR(100) NOT NULL,
    nombre_producto     VARCHAR(100) NOT NULL,
    descripcion         TEXT,
    precio              INTEGER      NOT NULL,
    stock_actual        INTEGER      NOT NULL,
    id_marca            VARCHAR(255) REFERENCES Marca     (id),
    categoria_id        VARCHAR(255) REFERENCES Categoria (id),
    fecha_vencimiento   TIMESTAMP    NOT NULL,
    imagen_principal    TEXT,
    fecha_creacion      TIMESTAMP    NOT NULL,
    fecha_actualizacion TIMESTAMP    NOT NULL
);

-- ------------------------------------------------------------
-- Transacciones
-- ------------------------------------------------------------
CREATE TABLE Reservacion (
    id_reservacion      VARCHAR(255) PRIMARY KEY,
    codigo_reservacion  VARCHAR(60)  NOT NULL,
    cliente_id          VARCHAR(255) REFERENCES Cliente    (id_cliente),
    fecha_renovacion    TIMESTAMP    NOT NULL,
    estado_renovacion   VARCHAR(60),
    total_renovacion    NUMERIC,
    metodo_pado_id      VARCHAR(255) REFERENCES MetodoPago (id_metodo_pago),
    pagado              BOOLEAN      NOT NULL,
    observaciones       TEXT,
    fecha_limite_retiro TIMESTAMP    NOT NULL
);

CREATE TABLE DetalleReservacion (
    id_details      VARCHAR(255) PRIMARY KEY,
    reservacion_id  VARCHAR(255) REFERENCES Reservacion (id_reservacion),
    producto_id     VARCHAR(255) REFERENCES Producto    (id_producto),
    cantidad        INTEGER      NOT NULL,
    precio_unitario NUMERIC      NOT NULL,
    subtotal        NUMERIC      GENERATED ALWAYS AS (cantidad * precio_unitario) STORED
);

CREATE TABLE Venta (
    id_venta          VARCHAR(255) PRIMARY KEY,
    reservacion_id    VARCHAR(255) UNIQUE REFERENCES Reservacion  (id_reservacion),
    monto_total       NUMERIC      NOT NULL,
    usuario_cajero_id VARCHAR(255) REFERENCES Administrador (id_usuario),
    fecha_venta       TIMESTAMP    NOT NULL,
    tipo_comprobante  VARCHAR(255) NOT NULL,
    estado_venta      VARCHAR(255) NOT NULL
);
