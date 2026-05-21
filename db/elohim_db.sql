-- ============================================================
--  Inversiones Elohim, S.A. — Esquema PostgreSQL
--  Alineado con el modelo EF Core (ElohimShop.Infrastructure)
--  Convención: tablas en PascalCase se crean sin comillas y
--  quedan en minúsculas en PostgreSQL (producto, marca, …).
-- ============================================================

-- DROP DATABASE IF EXISTS elohim_db;
-- DROP ROLE IF EXISTS elohim_user;

-- CREATE ROLE elohim_user WITH LOGIN PASSWORD 'ElohimS3cur3!';
-- CREATE DATABASE elohim_db WITH OWNER = elohim_user ENCODING = 'UTF8';

-- \c elohim_db

-- ------------------------------------------------------------
-- Usuarios y perfiles
-- ------------------------------------------------------------
CREATE TABLE Usuario (
    id              VARCHAR(255) PRIMARY KEY,
    correo          VARCHAR(100) NOT NULL UNIQUE,
    nombre          VARCHAR(30)  NOT NULL,
    apellido        VARCHAR(30),
    telefono        VARCHAR(30),
    contrasena      VARCHAR(255) NOT NULL,
    tipo_usuario    VARCHAR(20)  NOT NULL
        CHECK (tipo_usuario IN ('cliente', 'administrador')),
    estado          BOOLEAN      NOT NULL DEFAULT TRUE,
    fecha_creacion  TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    stripe_customer_id VARCHAR(255)
);

CREATE TABLE ClientePerfil (
    usuario_id    VARCHAR(255) PRIMARY KEY REFERENCES Usuario (id) ON DELETE CASCADE,
    direccion     TEXT,
    tipo_cliente  VARCHAR(20) NOT NULL
        CHECK (tipo_cliente IN ('mayorista', 'minorista', 'particular'))
);

CREATE TABLE AdministradorPerfil (
    usuario_id VARCHAR(255) PRIMARY KEY REFERENCES Usuario (id) ON DELETE CASCADE,
    rol        VARCHAR(20) NOT NULL
        CHECK (rol IN ('cajero', 'administrador'))
);

-- ------------------------------------------------------------
-- Revocación de JWT (logout / seguridad)
-- ------------------------------------------------------------
CREATE TABLE TokenRevocado (
    id          VARCHAR(255) PRIMARY KEY,
    jti         VARCHAR(100) NOT NULL UNIQUE,
    usuario_id  VARCHAR(255) NOT NULL REFERENCES Usuario (id) ON DELETE CASCADE,
    expira_en   TIMESTAMPTZ NOT NULL,
    revocado_en TIMESTAMPTZ NOT NULL
);

CREATE INDEX ix_token_revocado_usuario_id ON TokenRevocado (usuario_id);

-- ------------------------------------------------------------
-- Catálogo
-- ------------------------------------------------------------
CREATE TABLE Marca (
    id           VARCHAR(255) PRIMARY KEY,
    nombre_marca VARCHAR(15) NOT NULL,
    descripcion  TEXT
);

CREATE TABLE Categoria (
    id               VARCHAR(255) PRIMARY KEY,
    nombre_categoria VARCHAR(15) NOT NULL,
    descripcion      TEXT,
    fecha_creacion   TIMESTAMPTZ
);

CREATE TABLE Producto (
    id_producto         VARCHAR(255) PRIMARY KEY,
    codigo_producto     VARCHAR(100) NOT NULL UNIQUE,
    nombre_producto     VARCHAR(100) NOT NULL,
    descripcion         TEXT,
    precio              INTEGER      NOT NULL CHECK (precio > 0),
    stock_actual        INTEGER      NOT NULL CHECK (stock_actual >= 0),
    id_marca            VARCHAR(255) REFERENCES Marca (id) ON DELETE SET NULL,
    categoria_id        VARCHAR(255) REFERENCES Categoria (id) ON DELETE SET NULL,
    fecha_vencimiento   TIMESTAMPTZ  NOT NULL,
    imagen_principal    TEXT,
    fecha_creacion      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    fecha_actualizacion TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    stock_minimo         INTEGER      NOT NULL CHECK (stock_minimo >= 0),
    descuento_porcentaje  DECIMAL(5, 2)   NOT NULL CHECK (descuento_porcentaje >= 0 AND descuento_porcentaje <= 100),
    oferta_hasta         timestamptz 
);

CREATE INDEX ix_producto_categoria_id ON Producto (categoria_id);
CREATE INDEX ix_producto_id_marca ON Producto (id_marca);

-- ------------------------------------------------------------
-- Métodos de pago (incl. metadatos Stripe por tarjeta guardada)
-- ------------------------------------------------------------
CREATE TABLE MetodoPago (
    id_metodo_pago           VARCHAR(255) PRIMARY KEY,
    usuario_id               VARCHAR(255) REFERENCES Usuario (id) ON DELETE SET NULL,
    nombre_metodo            VARCHAR(15)  NOT NULL,
    descripcion              TEXT,
    stripe_payment_method_id VARCHAR(255),
    alias_tarjeta            VARCHAR(120),
    marca_tarjeta            VARCHAR(30),
    ultimos_digitos          VARCHAR(4),
    expira_mes               INTEGER,
    expira_anio              INTEGER,
    activo                   BOOLEAN      NOT NULL
);

-- ------------------------------------------------------------
-- Carrito de compras
-- ------------------------------------------------------------
CREATE TABLE Carrito (
    id_carrito         VARCHAR(255) PRIMARY KEY,
    cliente_id         VARCHAR(255) NOT NULL UNIQUE REFERENCES Usuario (id) ON DELETE CASCADE,
    activo             BOOLEAN      NOT NULL,
    fecha_creacion     TIMESTAMPTZ  NOT NULL,
    fecha_actualizacion TIMESTAMPTZ NOT NULL
);

CREATE TABLE ArticuloCarrito (
    id_articulo      VARCHAR(255) PRIMARY KEY,
    carrito_id       VARCHAR(255) NOT NULL REFERENCES Carrito (id_carrito) ON DELETE CASCADE,
    producto_id      VARCHAR(255) NOT NULL REFERENCES Producto (id_producto) ON DELETE CASCADE,
    nombre_producto  VARCHAR(255) NOT NULL,
    cantidad         INTEGER        NOT NULL CHECK (cantidad > 0),
    precio_unitario  NUMERIC        NOT NULL CHECK (precio_unitario > 0),
    subtotal         NUMERIC        NOT NULL,
    UNIQUE (carrito_id, producto_id)
);

CREATE INDEX ix_articulo_carrito_producto_id ON ArticuloCarrito (producto_id);

-- ------------------------------------------------------------
-- Reservaciones y ventas
-- ------------------------------------------------------------
CREATE TABLE Reservacion (
    id_reservacion        VARCHAR(255) PRIMARY KEY,
    codigo_reservacion    VARCHAR(60)  NOT NULL UNIQUE,
    cliente_id            VARCHAR(255) REFERENCES Usuario (id) ON DELETE SET NULL,
    fecha_renovacion      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    estado_renovacion     VARCHAR(60)  NOT NULL DEFAULT 'pendiente',
    total_renovacion      NUMERIC,
    metodo_pago_id        VARCHAR(255) REFERENCES MetodoPago (id_metodo_pago) ON DELETE SET NULL,
    pagado                BOOLEAN      NOT NULL DEFAULT FALSE,
    observaciones         TEXT,
    fecha_limite_retiro   TIMESTAMPTZ  NOT NULL,
    stripe_payment_intent_id VARCHAR(255)
);

CREATE INDEX ix_reservacion_cliente_id ON Reservacion (cliente_id);
CREATE INDEX ix_reservacion_metodo_pago_id ON Reservacion (metodo_pago_id);

CREATE TABLE DetalleReservacion (
    id_details       VARCHAR(255) PRIMARY KEY,
    reservacion_id   VARCHAR(255) NOT NULL REFERENCES Reservacion (id_reservacion) ON DELETE CASCADE,
    producto_id      VARCHAR(255) REFERENCES Producto (id_producto) ON DELETE SET NULL,
    nombre_producto  TEXT         NOT NULL,
    cantidad         INTEGER      NOT NULL CHECK (cantidad > 0),
    precio_unitario  NUMERIC      NOT NULL CHECK (precio_unitario > 0),
    subtotal         NUMERIC      NOT NULL GENERATED ALWAYS AS (cantidad * precio_unitario) STORED
);

CREATE INDEX ix_detalle_reservacion_producto_id ON DetalleReservacion (producto_id);
CREATE INDEX ix_detalle_reservacion_reservacion_id ON DetalleReservacion (reservacion_id);

CREATE TABLE Venta (
    id_venta           VARCHAR(255) PRIMARY KEY,
    reservacion_id     VARCHAR(255) UNIQUE REFERENCES Reservacion (id_reservacion) ON DELETE SET NULL,
    monto_total        NUMERIC      NOT NULL,
    usuario_cajero_id  VARCHAR(255) REFERENCES Usuario (id) ON DELETE SET NULL,
    fecha_venta        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    tipo_comprobante   VARCHAR(255) NOT NULL,
    estado_venta       VARCHAR(255) NOT NULL
);

CREATE INDEX ix_venta_usuario_cajero_id ON Venta (usuario_cajero_id);

-- ------------------------------------------------------------
-- Consultas (cliente ↔ administrador)
-- ------------------------------------------------------------
CREATE TABLE Consulta (
    id_consulta    VARCHAR(255) PRIMARY KEY,
    id_cliente     VARCHAR(255) NOT NULL REFERENCES Usuario (id) ON DELETE CASCADE,
    id_usuario     VARCHAR(255) NOT NULL REFERENCES Usuario (id) ON DELETE CASCADE,
    fecha_consulta TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX ix_consulta_id_cliente ON Consulta (id_cliente);
CREATE INDEX ix_consulta_id_usuario ON Consulta (id_usuario);
