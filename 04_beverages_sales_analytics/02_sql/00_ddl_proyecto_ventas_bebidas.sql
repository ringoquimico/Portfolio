-- DDL PARA CARGAR TABLAS EN SNOWFLAKE PARA EL PROYECTO DE ANALÍTICA DE VENTAS DE BEBIDAS (SIMULACIÓN DE DATOS)
-- Este script crea un esquema y varias tablas necesarias para el análisis de ventas de Bebidas.

-- CREACIÓN DEL ESQUEMA

CREATE SCHEMA IF NOT EXISTS bebidas_analytics;

-- CREACIÓN DE LAS TABLAS

-- Tabla: Clientes
CREATE TABLE IF NOT EXISTS bebidas_analytics.clientes (
    cliente_id INTEGER PRIMARY KEY,
    nombre VARCHAR(100),
    edad INTEGER,
    genero VARCHAR(1),
    ciudad VARCHAR(50),
    frecuencia_compra INTEGER,
    ultima_compra DATE
);

-- Tabla: Productos
CREATE TABLE IF NOT EXISTS bebidas_analytics.productos (
    producto_id INTEGER PRIMARY KEY,
    nombre_producto VARCHAR(50),
    categoria VARCHAR(50),
    precio_base FLOAT,
    costo_variable FLOAT,
    marca VARCHAR(50)
);

-- Tabla: Canales
CREATE TABLE IF NOT EXISTS bebidas_analytics.canales (
    canal_id INTEGER PRIMARY KEY,
    nombre_canal VARCHAR(50),
    tipo_canal VARCHAR(20)
);

-- Tabla: Regiones
CREATE TABLE IF NOT EXISTS bebidas_analytics.regiones (
    region_id INTEGER PRIMARY KEY,
    nombre_region VARCHAR(50),
    ciudad VARCHAR(50)
);

-- Tabla: Promociones
CREATE TABLE IF NOT EXISTS bebidas_analytics.promociones (
    promocion_id INTEGER PRIMARY KEY,
    nombre_promocion VARCHAR(50),
    descuento_porcentaje INTEGER,
    fecha_inicio DATE,
    fecha_fin DATE
);

-- Tabla: Inventarios
CREATE TABLE IF NOT EXISTS bebidas_analytics.inventarios (
    inventario_id INTEGER PRIMARY KEY,
    producto_id INTEGER,
    region_id INTEGER,
    stock INTEGER,
    fecha_actualizacion DATE,
    FOREIGN KEY (producto_id) REFERENCES bebidas_analytics.productos(producto_id),
    FOREIGN KEY (region_id) REFERENCES bebidas_analytics.regiones(region_id)
);

-- Tabla: Ventas

CREATE TABLE IF NOT EXISTS bebidas_analytics.ventas (
    venta_id INTEGER PRIMARY KEY,
    fecha DATE,
    cliente_id INTEGER,
    producto_id INTEGER,
    cantidad INTEGER,
    canal_id INTEGER,
    region_id INTEGER,
    promocion_id INTEGER,
    historico_precio_id INTEGER,
    FOREIGN KEY (cliente_id) REFERENCES bebidas_analytics.clientes(cliente_id),
    FOREIGN KEY (producto_id) REFERENCES bebidas_analytics.productos(producto_id),
    FOREIGN KEY (canal_id) REFERENCES bebidas_analytics.canales(canal_id),
    FOREIGN KEY (region_id) REFERENCES bebidas_analytics.regiones(region_id),
    FOREIGN KEY (historico_precio_id) REFERENCES bebidas_analytics.historico_precios(historico_precio_id),
    FOREIGN KEY (promocion_id) REFERENCES bebidas_analytics.promociones(promocion_id)
);


-- CREACIÓN DE VISTAS

CREATE OR REPLACE VIEW BEBIDAS_PROJECT.BEBIDAS_ANALYTICS.vw_ventas_ml AS
    WITH LastCompleteMonth AS (
    SELECT
        CASE
            WHEN DATE_TRUNC('month', CURRENT_DATE()) > DATE_TRUNC('month', MAX(v.fecha)) THEN DATE_TRUNC('month', MAX(v.fecha))
            WHEN DATE_TRUNC('month', CURRENT_DATE()) = DATE_TRUNC('month', MAX(v.fecha)) THEN DATE_TRUNC('month', DATEADD(month, -1, CURRENT_DATE()))
            ELSE DATE_TRUNC('month', MAX(v.fecha))
        END AS mes_limite
    FROM BEBIDAS_PROJECT.BEBIDAS_ANALYTICS.ventas AS v
)
SELECT
    r.nombre_region,
    p.categoria,
    p.nombre_producto,
    p.marca,
    DATE_TRUNC('month', v.fecha) AS MES,
    SUM(v.cantidad * p.volumen_ml_base * p.unidades_caja_base) / 1000000 AS m3_VENDIDOS,
    CONCAT(r.nombre_region, '-', p.categoria, '-', p.nombre_producto) AS Region_Categoria_Producto,
    COUNT(DISTINCT v.venta_id) AS TICKETS,
    SUM(v.cantidad) AS CANTIDAD,
    AVG(hp.precio_base) AS PRECIO_PROMEDIO,
    SUM(
        CASE
            WHEN v.promocion_id IS NOT NULL THEN
                hp.precio_base * (100 - pr.descuento_porcentaje) / 100 * v.cantidad
            ELSE
                hp.precio_base * v.cantidad
        END
    ) AS VENTAS_TOTALES,
    SUM(hp.precio_base * v.cantidad) AS VENTAS_BRUTAS,
    (SUM(hp.precio_base * v.cantidad) - SUM(
        CASE
            WHEN v.promocion_id IS NOT NULL THEN
                hp.precio_base * (100 - pr.descuento_porcentaje) / 100 * v.cantidad
            ELSE
                hp.precio_base * v.cantidad
        END
    )) AS DESCUENTOS,
    (CASE WHEN SUM(hp.precio_base * v.cantidad) > 0 THEN
        ((SUM(hp.precio_base * v.cantidad) - SUM(
            CASE
                WHEN v.promocion_id IS NOT NULL THEN
                    hp.precio_base * (100 - pr.descuento_porcentaje) / 100 * v.cantidad
                ELSE
                    hp.precio_base * v.cantidad
                END
        )) / SUM(hp.precio_base * v.cantidad)) * 100
        ELSE 0
    END) AS DESC_PORCENTAJE,
    SUM(hp.costo_variable * v.cantidad) AS COSTOS,
    (SUM(
        CASE
            WHEN v.promocion_id IS NOT NULL THEN
                hp.precio_base * (100 - pr.descuento_porcentaje) / 100 * v.cantidad
            ELSE
                hp.precio_base * v.cantidad
        END
    ) - SUM(hp.costo_variable * v.cantidad)) AS GANANCIA_NETA,
    CASE
        WHEN SUM(
            CASE
                WHEN v.promocion_id IS NOT NULL THEN
                    hp.precio_base * (100 - pr.descuento_porcentaje) / 100 * v.cantidad
                ELSE
                    hp.precio_base * v.cantidad
            END
        ) > 0 THEN
            (SUM(
                CASE
                    WHEN v.promocion_id IS NOT NULL THEN
                        hp.precio_base * (100 - pr.descuento_porcentaje) / 100 * v.cantidad
                    ELSE
                        hp.precio_base * v.cantidad
                END
            ) - SUM(hp.costo_variable * v.cantidad)) / SUM(
                CASE
                    WHEN v.promocion_id IS NOT NULL THEN
                        hp.precio_base * (100 - pr.descuento_porcentaje) / 100 * v.cantidad
                    ELSE
                        hp.precio_base * v.cantidad
                END
            ) * 100
        ELSE 0
    END AS MARGEN_GANANCIA_NETA_PORCENTAJE
FROM BEBIDAS_PROJECT.BEBIDAS_ANALYTICS.ventas AS v
LEFT JOIN BEBIDAS_PROJECT.BEBIDAS_ANALYTICS.productos AS p
    ON v.producto_id = p.producto_id
LEFT JOIN BEBIDAS_PROJECT.BEBIDAS_ANALYTICS.REGIONES AS r
    ON v.region_id = r.region_id
LEFT JOIN BEBIDAS_PROJECT.BEBIDAS_ANALYTICS.PROMOCIONES AS pr
    ON v.promocion_id = pr.promocion_id
LEFT JOIN BEBIDAS_PROJECT.BEBIDAS_ANALYTICS.HISTORICO_PRECIOS AS hp
    ON v.historico_precio_id = hp.historico_precio_id,
    LastCompleteMonth lcm
WHERE
    p.marca = 'Zulianita'
    AND DATE_TRUNC('month', v.fecha) <= lcm.mes_limite
GROUP BY
    r.nombre_region,
    p.categoria,
    p.nombre_producto,
    p.marca,
    DATE_TRUNC('month', v.fecha)
ORDER BY
    r.nombre_region,
    p.categoria,
    p.nombre_producto,
    MES;


-- Vista para Optimización de Precios

CREATE OR REPLACE VIEW BEBIDAS_PROJECT.BEBIDAS_ANALYTICS.vw_precios_ml AS
SELECT 
    v.producto_id,
    v.precio_unitario AS precio,
    p.categoria,
    p.marca,
    CASE WHEN v.cantidad > 0 THEN 1 ELSE 0 END AS compra,
    MONTH(v.fecha) AS mes
FROM BEBIDAS_PROJECT.BEBIDAS_ANALYTICS.ventas v
JOIN BEBIDAS_PROJECT.BEBIDAS_ANALYTICS.productos p ON v.producto_id = p.producto_id;

-- Vista para Predicción de Rotación de Inventario

CREATE OR REPLACE VIEW BEBIDAS_PROJECT.BEBIDAS_ANALYTICS.vw_inventario_ml AS
SELECT 
    i.producto_id,
    i.region_id,
    i.stock,
    SUM(v.cantidad) / AVG(i.stock) AS rotacion,
    AVG(v.cantidad) AS ventas_historicas,
    MONTH(v.fecha) AS mes
FROM BEBIDAS_PROJECT.BEBIDAS_ANALYTICS.inventarios i
LEFT JOIN BEBIDAS_PROJECT.BEBIDAS_ANALYTICS.ventas v ON i.producto_id = v.producto_id AND i.region_id = v.region_id
GROUP BY i.producto_id, i.region_id, i.stock, MONTH(v.fecha);

-- VISTA CLIENTES FULL

CREATE OR REPLACE VIEW BEBIDAS_PROJECT.BEBIDAS_ANALYTICS.VW_CLIENTES_FULL AS 

WITH PRIMERA_COMPRA  AS (
SELECT DISTINCT(CLIENTE_ID), MIN(FECHA) AS  "PRIMERA_COMPRA" FROM VENTAS GROUP BY CLIENTE_ID),

ULTIMA_COMPRA  AS (
SELECT DISTINCT(CLIENTE_ID), MAX(FECHA) AS  "ULTIMA_COMPRA" FROM VENTAS GROUP BY CLIENTE_ID)

SELECT
cl.cliente_id,
cl.nombre,
cl.genero,
cl.edad,
cl.ciudad,
cl.frecuencia_compra,
pc.primera_compra,
uc.ultima_compra,
DATEDIFF('months',pc.primera_compra, CURRENT_DATE()) AS tiempo_cliente_meses, 
DATEDIFF('days',uc.ultima_compra, CURRENT_DATE()) AS dias_ultima_compra
FROM CLIENTES cl
LEFT JOIN ULTIMA_COMPRA uc ON cl.cliente_id = uc.cliente_id 
LEFT JOIN PRIMERA_COMPRA pc ON cl.cliente_id = pc.cliente_id 
ORDER BY cl.cliente_id ;