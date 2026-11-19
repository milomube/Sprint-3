-- Sprint #3: Introducción a BigQuery y SQL en la Nube

-- NIVEL 1: Entorno e Ingesta Híbrida (Code-First)

-- Script para crear dataset sprint3_silver
CREATE SCHEMA IF NOT EXISTS `sprint3-analytics-juan-camilo.sprint3_silver`
OPTIONS ( location = 'EU');

-- Script para crear dataset sprint3_gold en Cloud shell

bq mk --dataset --location=EU sprint3-analytics-juan-camilo:sprint3_gold

-- Script para crear la tabla transactions_raw

CREATE EXTERNAL TABLE IF NOT EXISTS `sprint3-analytics-juan-camilo.sprint3_bronze.transactions_raw`
OPTIONS (format = 'CSV', uris = ['gs://bootcamp-data-analytics-public/ERP/transactions.csv'], field_delimiter = ';');

-- Script para crear la tabla companies_raw

CREATE EXTERNAL TABLE IF NOT EXISTS `sprint3-analytics-juan-camilo.sprint3_bronze.companies_raw`
(   id STRING,
    company_name STRING,
    phone STRING,
    email STRING,
    country STRING,
    website STRING)
OPTIONS ( format = 'CSV', uris = ['gs://bootcamp-data-analytics-public/ERP/companies.csv'], skip_leading_rows = 1);

-- Script para crear la tabla american_users_raw

CREATE EXTERNAL TABLE IF NOT EXISTS `sprint3-analytics-juan-camilo.sprint3_bronze.american_users_raw`
OPTIONS ( format = 'CSV', uris = ['gs://bootcamp-data-analytics-public/CRM/american_users.csv'], skip_leading_rows = 1);

-- Script para crear la tabla european_users_raw

CREATE EXTERNAL TABLE IF NOT EXISTS `sprint3-analytics-juan-camilo.sprint3_bronze.european_users_raw`
OPTIONS ( format = 'CSV', uris = ['gs://bootcamp-data-analytics-public/CRM/european_users.csv'], skip_leading_rows = 1);

-- Script para crear la tabla credit_cards_raw

CREATE EXTERNAL TABLE IF NOT EXISTS `sprint3-analytics-juan-camilo.sprint3_bronze.credit_cards_raw`
OPTIONS ( format = 'CSV', uris = ['gs://bootcamp-data-analytics-public/CRM/credit_cards.csv'], skip_leading_rows = 1);

-- Script generado por IA para el ejercicio 4 del nivel 1

CREATE OR REPLACE TABLE `sprint3-analytics-juan-camilo.sprint3_bronze.transactions_raw_native` AS
SELECT * FROM `sprint3-analytics-juan-camilo.sprint3_bronze.transactions_raw`;

-- Scripts del ejercicio 4: Consumo de Bytes

SELECT *
FROM `sprint3-analytics-juan-camilo.sprint3_bronze.transactions_raw_native`;

SELECT *
FROM `sprint3-analytics-juan-camilo.sprint3_bronze.transactions_raw_native`
LIMIT 10;

SELECT id
FROM `sprint3-analytics-juan-camilo.sprint3_bronze.transactions_raw_native`;

SELECT *
FROM `sprint3-analytics-juan-camilo.sprint3_bronze.transactions_raw`
LIMIT 10;

-- Script para el ejercicio 5: 5 días con mayores ingresos de 2021

SELECT DATE(timestamp) AS fecha, ROUND(SUM(amount), 2) AS ingresos_totales
FROM `sprint3-analytics-juan-camilo.sprint3_bronze.transactions_raw_native`
WHERE EXTRACT(YEAR FROM timestamp) = 2021 AND declined = 0
GROUP BY fecha
ORDER BY ingresos_totales DESC
LIMIT 5;

-- Script para el ejercicio 6: consultas complejas

SELECT c.company_name, c.country, DATE(t.timestamp) AS transaction_date
FROM `sprint3-analytics-juan-camilo.sprint3_bronze.companies_raw` AS c
INNER JOIN `sprint3-analytics-juan-camilo.sprint3_bronze.transactions_raw_native` AS t ON c.id = t.business_id
WHERE t.amount BETWEEN 100 AND 200 AND DATE(t.timestamp) IN ( '2015-04-29', '2018-07-20', '2024-03-13')
ORDER BY transaction_date, c.company_name;

-- NIVEL 2: Limpieza y Transformación (ELT)

-- Script para el ejercicio 1: Limpieza de Productos (Data Quality)

CREATE OR REPLACE TABLE `sprint3-analytics-juan-camilo.sprint3_silver.products_clean` AS
SELECT id AS product_id, product_name AS name,
    CAST(REPLACE(warehouse_id, 'WH-', '') AS INT64) AS warehouse_id,
    CAST(price AS FLOAT64) AS price,
    weight
FROM `sprint3-analytics-juan-camilo.sprint3_bronze.products_raw`;

-- Script para el ejercicio 2: Creación de Transacciones Limpias (Capa Silver)

CREATE OR REPLACE TABLE `sprint3-analytics-juan-camilo.sprint3_silver.transactions_clean` AS
SELECT * EXCEPT (id, amount, timestamp, lat, longitude, product_ids), id AS transaction_id,
    IFNULL(SAFE_CAST(amount AS FLOAT64), 0) AS amount,
    CAST(timestamp AS TIMESTAMP) AS timestamp,
    SAFE_CAST(lat AS FLOAT64) AS lat,
    SAFE_CAST(longitude AS FLOAT64) AS longitude,
    ARRAY( SELECT SAFE_CAST(TRIM(product_id) AS INT64)
        FROM UNNEST(SPLIT(product_ids, ',')) AS product_id
			) AS product_ids
FROM `sprint3-analytics-juan-camilo.sprint3_bronze.transactions_raw`;

-- Script para el ejercicio 3: Unificación de Usuarios (UNION)

CREATE OR REPLACE TABLE `sprint3-analytics-juan-camilo.sprint3_silver.users_combined` AS
SELECT id AS user_id, * EXCEPT(id), 'American' AS origin
FROM `sprint3-analytics-juan-camilo.sprint3_bronze.american_users_raw`
UNION ALL
SELECT id AS user_id, * EXCEPT(id), 'European' AS origin
FROM `sprint3-analytics-juan-camilo.sprint3_bronze.european_users_raw`;

-- Script para el ejercicio 4: Materialización de Compañías y Tarjetas de Crédito

CREATE OR REPLACE TABLE `sprint3-analytics-juan-camilo.sprint3_silver.companies_clean` AS
SELECT id AS company_id, * EXCEPT(id)
FROM `sprint3-analytics-juan-camilo.sprint3_bronze.companies_raw`;

CREATE OR REPLACE TABLE `sprint3-analytics-juan-camilo.sprint3_silver.credit_cards_clean` AS
SELECT id AS card_id, * EXCEPT(id)
FROM `sprint3-analytics-juan-camilo.sprint3_bronze.credit_cards_raw`;

-- Nivel 3: Presentación de Datos y Creación de Vistas

-- Script del ejercicio 1: La Vista de Marketing (Lógica de Negocio)

CREATE OR REPLACE VIEW `sprint3-analytics-juan-camilo.sprint3_gold.v_marketing_kpis` AS
SELECT c.company_name, c.phone, c.country, ROUND(AVG(t.amount), 2) AS average_purchase,
    CASE WHEN AVG(t.amount) > 260 THEN 'Premium'
        ELSE 'Standard'
    END AS client_tier
FROM `sprint3-analytics-juan-camilo.sprint3_silver.companies_clean` AS c
INNER JOIN `sprint3-analytics-juan-camilo.sprint3_silver.transactions_clean` AS t ON c.company_id = t.business_id
GROUP BY c.company_id, c.company_name, c.phone, c.country;

SELECT *
FROM `sprint3-analytics-juan-camilo.sprint3_gold.v_marketing_kpis`
ORDER BY CASE WHEN client_tier = 'Premium' THEN 0
        ELSE 1
    END, average_purchase DESC;

-- Script del ejercicio 2: Ranking de Productos (La Potencia de los Arrays)

-- como no tenias color en la tabla, lo que hicimos es modificar la tabla products_clean para que aparezca la columna color
CREATE OR REPLACE TABLE `sprint3-analytics-juan-camilo.sprint3_silver.products_clean` AS
SELECT id AS product_id, product_name AS name,
    CAST(REPLACE(warehouse_id, 'WH-', '') AS INT64) AS warehouse_id,
    CAST(price AS FLOAT64) AS price,
    weight,
    colour AS color
FROM `sprint3-analytics-juan-camilo.sprint3_bronze.products_raw`;

CREATE OR REPLACE TABLE `sprint3-analytics-juan-camilo.sprint3_gold.product_sales_ranking` AS
WITH ventas_por_producto AS (SELECT product_id, COUNT(*) AS total_vendido
    FROM `sprint3-analytics-juan-camilo.sprint3_silver.transactions_clean` AS t
    CROSS JOIN UNNEST(t.product_ids) AS product_id
    GROUP BY product_id)
SELECT p.product_id, p.name, p.price, p.color, IFNULL(v.total_vendido, 0) AS total_vendido
FROM `sprint3-analytics-juan-camilo.sprint3_silver.products_clean` AS p
LEFT JOIN ventas_por_producto AS v ON p.product_id = v.product_id;

-- Con esto validamos el top de productos 
SELECT *
FROM `sprint3-analytics-juan-camilo.sprint3_gold.product_sales_ranking`
ORDER BY total_sold DESC;

-- Script del ejercicio 3: Exportación de Resultados

SELECT product_id, name, price, color, total_vendido
FROM `sprint3-analytics-juan-camilo.sprint3_gold.product_sales_ranking`
ORDER BY total_vendido DESC;
