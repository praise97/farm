-- FarmSmartPro Crop Database Schema (PostgreSQL)
-- This schema supports crop management, alerts, treatments, weather, and dashboard analytics.

BEGIN;

-- ======================================================
-- 1) Reference Data: Crops
-- ======================================================
CREATE TABLE IF NOT EXISTS crops (
    crop_id              SERIAL PRIMARY KEY,
    crop_name            VARCHAR(50) NOT NULL UNIQUE,
    crop_group           VARCHAR(30) NOT NULL,
    days_to_maturity     INT NOT NULL CHECK (days_to_maturity > 0),
    optimal_season       VARCHAR(20),
    market_price_usd     NUMERIC(10, 2) CHECK (market_price_usd IS NULL OR market_price_usd >= 0),
    use_category         VARCHAR(30),
    created_at           TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ======================================================
-- 2) Varieties
-- ======================================================
CREATE TABLE IF NOT EXISTS varieties (
    variety_id           SERIAL PRIMARY KEY,
    crop_id              INT NOT NULL REFERENCES crops(crop_id) ON DELETE CASCADE,
    variety_name         VARCHAR(50) NOT NULL,
    seed_source          VARCHAR(100),
    days_to_maturity     INT CHECK (days_to_maturity IS NULL OR days_to_maturity > 0),
    created_at           TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_variety_per_crop UNIQUE (crop_id, variety_name)
);

-- ======================================================
-- 3) Fields / Plots
-- ======================================================
CREATE TABLE IF NOT EXISTS fields (
    field_id             SERIAL PRIMARY KEY,
    field_name           VARCHAR(50) NOT NULL UNIQUE,
    size_ha              NUMERIC(8, 2) NOT NULL CHECK (size_ha > 0),
    soil_type            VARCHAR(30),
    gps_lat              NUMERIC(10, 7),
    gps_lon              NUMERIC(10, 7),
    elevation_m          INT,
    climate_zone         VARCHAR(20),
    created_at           TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ======================================================
-- 4) Planting Records (core event)
-- ======================================================
CREATE TABLE IF NOT EXISTS plantings (
    planting_id          SERIAL PRIMARY KEY,
    field_id             INT NOT NULL REFERENCES fields(field_id) ON DELETE CASCADE,
    variety_id           INT NOT NULL REFERENCES varieties(variety_id) ON DELETE CASCADE,
    planting_date        DATE NOT NULL,
    harvest_date         DATE,
    crop_type            VARCHAR(30) NOT NULL,
    planting_density     INT CHECK (planting_density IS NULL OR planting_density > 0),
    row_spacing_cm       INT CHECK (row_spacing_cm IS NULL OR row_spacing_cm > 0),
    plant_spacing_cm     INT CHECK (plant_spacing_cm IS NULL OR plant_spacing_cm > 0),
    notes                TEXT,
    created_at           TIMESTAMP NOT NULL DEFAULT NOW(),
    CHECK (harvest_date IS NULL OR harvest_date >= planting_date)
);

-- ======================================================
-- 5) Treatment Logs
-- ======================================================
CREATE TABLE IF NOT EXISTS treatments (
    treatment_id         SERIAL PRIMARY KEY,
    planting_id          INT NOT NULL REFERENCES plantings(planting_id) ON DELETE CASCADE,
    treatment_type       VARCHAR(20) NOT NULL CHECK (treatment_type IN ('fertilizer', 'pesticide', 'herbicide', 'irrigation')),
    product_name         VARCHAR(100),
    application_date     DATE NOT NULL,
    rate_per_ha          NUMERIC(10, 2) CHECK (rate_per_ha IS NULL OR rate_per_ha >= 0),
    cost_usd             NUMERIC(10, 2) CHECK (cost_usd IS NULL OR cost_usd >= 0),
    notes                TEXT,
    created_at           TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ======================================================
-- 6) Observations
-- ======================================================
CREATE TABLE IF NOT EXISTS observations (
    observation_id       SERIAL PRIMARY KEY,
    planting_id          INT NOT NULL REFERENCES plantings(planting_id) ON DELETE CASCADE,
    observation_date     DATE NOT NULL,
    avg_plant_height_cm  INT CHECK (avg_plant_height_cm IS NULL OR avg_plant_height_cm >= 0),
    color_rating         INT CHECK (color_rating BETWEEN 1 AND 5),
    pest_presence        BOOLEAN NOT NULL DEFAULT FALSE,
    disease_presence     BOOLEAN NOT NULL DEFAULT FALSE,
    notes                TEXT,
    created_at           TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ======================================================
-- 7) Soil Moisture Readings
-- Added so the "Average Soil Moisture" dashboard metric is fully queryable.
-- ======================================================
CREATE TABLE IF NOT EXISTS soil_moisture_readings (
    moisture_id          SERIAL PRIMARY KEY,
    planting_id          INT NOT NULL REFERENCES plantings(planting_id) ON DELETE CASCADE,
    reading_time         TIMESTAMP NOT NULL DEFAULT NOW(),
    moisture_percent     NUMERIC(5, 2) NOT NULL CHECK (moisture_percent >= 0 AND moisture_percent <= 100),
    source               VARCHAR(30) DEFAULT 'sensor'
);

-- ======================================================
-- 8) Weather Events
-- ======================================================
CREATE TABLE IF NOT EXISTS weather_events (
    event_id             SERIAL PRIMARY KEY,
    field_id             INT NOT NULL REFERENCES fields(field_id) ON DELETE CASCADE,
    event_date           DATE NOT NULL,
    event_type           VARCHAR(30) NOT NULL,
    intensity            NUMERIC(8, 2),
    notes                TEXT,
    created_at           TIMESTAMP NOT NULL DEFAULT NOW()
);

-- ======================================================
-- 9) Yield Records
-- ======================================================
CREATE TABLE IF NOT EXISTS yields (
    yield_id             SERIAL PRIMARY KEY,
    planting_id          INT NOT NULL REFERENCES plantings(planting_id) ON DELETE CASCADE,
    harvest_date         DATE NOT NULL,
    yield_tons_per_ha    NUMERIC(8, 2) CHECK (yield_tons_per_ha IS NULL OR yield_tons_per_ha >= 0),
    quality_grade        VARCHAR(10),
    notes                TEXT,
    created_at           TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_yield_per_planting UNIQUE (planting_id)
);

-- ======================================================
-- Indexes for performance
-- ======================================================
CREATE INDEX IF NOT EXISTS idx_plantings_field ON plantings(field_id);
CREATE INDEX IF NOT EXISTS idx_plantings_variety ON plantings(variety_id);
CREATE INDEX IF NOT EXISTS idx_plantings_date ON plantings(planting_date);
CREATE INDEX IF NOT EXISTS idx_treatments_planting ON treatments(planting_id);
CREATE INDEX IF NOT EXISTS idx_treatments_app_date ON treatments(application_date);
CREATE INDEX IF NOT EXISTS idx_observations_planting ON observations(planting_id);
CREATE INDEX IF NOT EXISTS idx_observations_date ON observations(observation_date);
CREATE INDEX IF NOT EXISTS idx_soil_moisture_planting_time ON soil_moisture_readings(planting_id, reading_time DESC);
CREATE INDEX IF NOT EXISTS idx_weather_field_date ON weather_events(field_id, event_date DESC);
CREATE INDEX IF NOT EXISTS idx_yields_planting ON yields(planting_id);

-- ======================================================
-- Views for dashboard
-- ======================================================

DROP VIEW IF EXISTS yield_history;
DROP VIEW IF EXISTS pest_alerts;
DROP VIEW IF EXISTS treatment_summary;
DROP VIEW IF EXISTS active_crops;

-- 1) Active crops + growth status + latest moisture + most recent observations
CREATE VIEW active_crops AS
SELECT
    p.planting_id,
    f.field_name,
    v.variety_name,
    c.crop_name,
    p.planting_date,
    EXTRACT(DAY FROM (NOW() - p.planting_date))::INT AS days_since_planting,
    COALESCE(v.days_to_maturity, c.days_to_maturity) AS days_to_maturity,
    LEAST(
        100,
        ROUND(
            (
                EXTRACT(DAY FROM (NOW() - p.planting_date))
                / NULLIF(COALESCE(v.days_to_maturity, c.days_to_maturity), 0)
            ) * 100
        )
    )::INT AS growth_percent,
    CASE
        WHEN EXTRACT(DAY FROM (NOW() - p.planting_date)) < COALESCE(v.days_to_maturity, c.days_to_maturity) * 0.10 THEN 'Germination'
        WHEN EXTRACT(DAY FROM (NOW() - p.planting_date)) < COALESCE(v.days_to_maturity, c.days_to_maturity) * 0.30 THEN 'Vegetative'
        WHEN EXTRACT(DAY FROM (NOW() - p.planting_date)) < COALESCE(v.days_to_maturity, c.days_to_maturity) * 0.60 THEN 'Flowering'
        WHEN EXTRACT(DAY FROM (NOW() - p.planting_date)) < COALESCE(v.days_to_maturity, c.days_to_maturity) * 0.85 THEN 'Fruiting/Grain fill'
        WHEN EXTRACT(DAY FROM (NOW() - p.planting_date)) < COALESCE(v.days_to_maturity, c.days_to_maturity) THEN 'Maturation'
        ELSE 'Harvest ready'
    END AS growth_stage,
    lm.latest_moisture_percent,
    lo.last_observation_date,
    lo.latest_color_rating,
    lo.latest_pest_presence,
    lo.latest_disease_presence
FROM plantings p
JOIN fields f ON p.field_id = f.field_id
JOIN varieties v ON p.variety_id = v.variety_id
JOIN crops c ON v.crop_id = c.crop_id
LEFT JOIN LATERAL (
    SELECT smr.moisture_percent AS latest_moisture_percent
    FROM soil_moisture_readings smr
    WHERE smr.planting_id = p.planting_id
    ORDER BY smr.reading_time DESC
    LIMIT 1
) lm ON TRUE
LEFT JOIN LATERAL (
    SELECT
        o.observation_date AS last_observation_date,
        o.color_rating AS latest_color_rating,
        o.pest_presence AS latest_pest_presence,
        o.disease_presence AS latest_disease_presence
    FROM observations o
    WHERE o.planting_id = p.planting_id
    ORDER BY o.observation_date DESC, o.observation_id DESC
    LIMIT 1
) lo ON TRUE
WHERE p.harvest_date IS NULL;

-- 2) Treatments summary per active planting
CREATE VIEW treatment_summary AS
SELECT
    p.planting_id,
    f.field_name,
    c.crop_name,
    COUNT(t.treatment_id) AS total_treatments,
    SUM(CASE WHEN t.treatment_type = 'fertilizer' THEN 1 ELSE 0 END) AS fertilizer_applications,
    SUM(CASE WHEN t.treatment_type = 'pesticide' THEN 1 ELSE 0 END) AS pesticide_applications,
    SUM(CASE WHEN t.treatment_type = 'irrigation' THEN 1 ELSE 0 END) AS irrigation_events,
    COALESCE(SUM(t.cost_usd), 0) AS total_cost_usd
FROM plantings p
JOIN fields f ON p.field_id = f.field_id
JOIN varieties v ON p.variety_id = v.variety_id
JOIN crops c ON v.crop_id = c.crop_id
LEFT JOIN treatments t ON p.planting_id = t.planting_id
WHERE p.harvest_date IS NULL
GROUP BY p.planting_id, f.field_name, c.crop_name;

-- 3) Pest and disease alerts
CREATE VIEW pest_alerts AS
SELECT
    p.planting_id,
    f.field_name,
    c.crop_name,
    MAX(o.observation_date) AS last_observation,
    BOOL_OR(o.pest_presence) AS pest_detected,
    BOOL_OR(o.disease_presence) AS disease_detected,
    CASE
        WHEN BOOL_OR(o.pest_presence) AND BOOL_OR(o.disease_presence) THEN 'Pest and disease risk detected'
        WHEN BOOL_OR(o.pest_presence) THEN 'Pest risk detected'
        WHEN BOOL_OR(o.disease_presence) THEN 'Disease risk detected'
        ELSE 'No alerts'
    END AS alert_status
FROM plantings p
JOIN fields f ON p.field_id = f.field_id
JOIN varieties v ON p.variety_id = v.variety_id
JOIN crops c ON v.crop_id = c.crop_id
LEFT JOIN observations o ON p.planting_id = o.planting_id
WHERE p.harvest_date IS NULL
GROUP BY p.planting_id, f.field_name, c.crop_name
HAVING BOOL_OR(o.pest_presence) OR BOOL_OR(o.disease_presence);

-- 4) Yield history for completed plantings
CREATE VIEW yield_history AS
SELECT
    p.planting_id,
    f.field_name,
    c.crop_name,
    v.variety_name,
    p.planting_date,
    y.harvest_date,
    y.yield_tons_per_ha,
    y.quality_grade
FROM plantings p
JOIN fields f ON p.field_id = f.field_id
JOIN varieties v ON p.variety_id = v.variety_id
JOIN crops c ON v.crop_id = c.crop_id
JOIN yields y ON p.planting_id = y.planting_id
ORDER BY y.harvest_date DESC;

-- ======================================================
-- Sample data (safe inserts)
-- ======================================================

INSERT INTO crops (crop_name, crop_group, days_to_maturity, optimal_season, market_price_usd, use_category)
VALUES
    ('Maize', 'Cereal', 120, 'Summer', 385.00, 'Grain'),
    ('Tobacco', 'Cash', 90, 'Summer', 4250.00, 'Leaf'),
    ('Cotton', 'Fibre', 150, 'Summer', 1020.00, 'Fibre'),
    ('Tomatoes', 'Vegetable', 80, 'All', 520.00, 'Fresh')
ON CONFLICT (crop_name) DO NOTHING;

INSERT INTO varieties (crop_id, variety_name, seed_source, days_to_maturity)
SELECT c.crop_id, v.variety_name, v.seed_source, v.days_to_maturity
FROM (
    VALUES
      ('Maize', 'SC 403', 'SeedCo', 115),
      ('Maize', 'SC 513', 'SeedCo', 125),
      ('Tobacco', 'Kutsaga', 'Tobacco Research Board', 88),
      ('Cotton', 'Cotton 1', 'Cotton Research Institute', 145),
      ('Tomatoes', 'Heinz', 'SeedCo', 75)
) AS v(crop_name, variety_name, seed_source, days_to_maturity)
JOIN crops c ON c.crop_name = v.crop_name
ON CONFLICT (crop_id, variety_name) DO NOTHING;

INSERT INTO fields (field_name, size_ha, soil_type, gps_lat, gps_lon, elevation_m, climate_zone)
VALUES
    ('Field A', 5.20, 'Sandy Loam', -17.8248580, 31.0530280, 1450, 'Subtropical'),
    ('Field B', 3.80, 'Clay', -17.8300000, 31.0600000, 1400, 'Subtropical'),
    ('Greenhouse 1', 0.50, 'Loam', -17.8200000, 31.0550000, 1450, 'Controlled')
ON CONFLICT (field_name) DO NOTHING;

INSERT INTO plantings (field_id, variety_id, planting_date, crop_type, planting_density, row_spacing_cm, plant_spacing_cm, notes)
SELECT f.field_id, v.variety_id, p.planting_date, p.crop_type, p.planting_density, p.row_spacing_cm, p.plant_spacing_cm, p.notes
FROM (
    VALUES
      ('Field A', 'SC 403', DATE '2026-06-01', 'Maize', 55000, 75, 25, 'Tasseling stage'),
      ('Field B', 'Kutsaga', DATE '2026-06-15', 'Tobacco', 25000, 100, 50, 'Topping soon'),
      ('Greenhouse 1', 'Heinz', DATE '2026-07-01', 'Tomatoes', 30000, 80, 40, 'Fruit ripening')
) AS p(field_name, variety_name, planting_date, crop_type, planting_density, row_spacing_cm, plant_spacing_cm, notes)
JOIN fields f ON f.field_name = p.field_name
JOIN varieties v ON v.variety_name = p.variety_name
WHERE NOT EXISTS (
    SELECT 1
    FROM plantings x
    WHERE x.field_id = f.field_id
      AND x.variety_id = v.variety_id
      AND x.planting_date = p.planting_date
);

INSERT INTO treatments (planting_id, treatment_type, product_name, application_date, rate_per_ha, cost_usd, notes)
SELECT p.planting_id, 'fertilizer', 'Urea', DATE '2026-07-10', 150, 75, 'Nitrogen application'
FROM plantings p
JOIN fields f ON p.field_id = f.field_id
WHERE f.field_name = 'Field A'
  AND NOT EXISTS (
    SELECT 1
    FROM treatments t
    WHERE t.planting_id = p.planting_id
      AND t.treatment_type = 'fertilizer'
      AND t.application_date = DATE '2026-07-10'
);

INSERT INTO observations (planting_id, observation_date, avg_plant_height_cm, color_rating, pest_presence, disease_presence, notes)
SELECT p.planting_id, DATE '2026-07-20', 180, 4, FALSE, FALSE, 'Healthy'
FROM plantings p
JOIN fields f ON p.field_id = f.field_id
WHERE f.field_name = 'Field A'
  AND NOT EXISTS (
    SELECT 1
    FROM observations o
    WHERE o.planting_id = p.planting_id
      AND o.observation_date = DATE '2026-07-20'
);

INSERT INTO soil_moisture_readings (planting_id, reading_time, moisture_percent, source)
SELECT p.planting_id, TIMESTAMP '2026-07-22 08:00:00', 61.0, 'sensor'
FROM plantings p
JOIN fields f ON p.field_id = f.field_id
WHERE f.field_name = 'Field A'
  AND NOT EXISTS (
    SELECT 1
    FROM soil_moisture_readings s
    WHERE s.planting_id = p.planting_id
      AND s.reading_time = TIMESTAMP '2026-07-22 08:00:00'
);

INSERT INTO weather_events (field_id, event_date, event_type, intensity, notes)
SELECT f.field_id, DATE '2026-07-22', 'rain', 12.5, 'Good rain for tasseling'
FROM fields f
WHERE f.field_name = 'Field A'
  AND NOT EXISTS (
    SELECT 1
    FROM weather_events w
    WHERE w.field_id = f.field_id
      AND w.event_date = DATE '2026-07-22'
      AND w.event_type = 'rain'
);

INSERT INTO yields (planting_id, harvest_date, yield_tons_per_ha, quality_grade, notes)
SELECT p.planting_id, DATE '2026-09-20', 6.2, 'A', 'Excellent quality'
FROM plantings p
JOIN fields f ON p.field_id = f.field_id
WHERE f.field_name = 'Field A'
ON CONFLICT (planting_id) DO NOTHING;

COMMIT;

-- ======================================================
-- Key Dashboard Queries
-- ======================================================

-- Active crop plots count
-- SELECT COUNT(*) AS active_crop_plots FROM active_crops;

-- Average latest moisture for all active plantings
-- SELECT ROUND(AVG(latest_moisture_percent)::NUMERIC, 2) AS avg_soil_moisture
-- FROM active_crops
-- WHERE latest_moisture_percent IS NOT NULL;

-- Smart Alerts
-- SELECT * FROM pest_alerts WHERE alert_status <> 'No alerts';

-- Growth overview
-- SELECT crop_name, field_name, growth_percent, growth_stage
-- FROM active_crops
-- ORDER BY growth_percent DESC;

-- Treatment cost summary
-- SELECT field_name, total_cost_usd
-- FROM treatment_summary
-- ORDER BY total_cost_usd DESC;
