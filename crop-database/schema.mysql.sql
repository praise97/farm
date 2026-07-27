-- FarmSmartPro Crop Database Schema (MySQL 8+ compatible)
-- MySQL variant of schema.postgres.sql for dual-support deployments.

SET NAMES utf8mb4;
SET time_zone = '+00:00';

CREATE TABLE IF NOT EXISTS crops (
    crop_id               INT AUTO_INCREMENT PRIMARY KEY,
    crop_name             VARCHAR(50) NOT NULL UNIQUE,
    crop_group            VARCHAR(30) NOT NULL,
    days_to_maturity      INT NOT NULL,
    optimal_season        VARCHAR(20),
    market_price_usd      DECIMAL(10, 2),
    use_category          VARCHAR(30),
    created_at            DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_crops_days CHECK (days_to_maturity > 0),
    CONSTRAINT chk_crops_price CHECK (market_price_usd IS NULL OR market_price_usd >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS varieties (
    variety_id            INT AUTO_INCREMENT PRIMARY KEY,
    crop_id               INT NOT NULL,
    variety_name          VARCHAR(50) NOT NULL,
    seed_source           VARCHAR(100),
    days_to_maturity      INT,
    created_at            DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_variety_per_crop UNIQUE (crop_id, variety_name),
    CONSTRAINT chk_variety_days CHECK (days_to_maturity IS NULL OR days_to_maturity > 0),
    CONSTRAINT fk_varieties_crop FOREIGN KEY (crop_id) REFERENCES crops(crop_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS fields (
    field_id              INT AUTO_INCREMENT PRIMARY KEY,
    field_name            VARCHAR(50) NOT NULL UNIQUE,
    size_ha               DECIMAL(8, 2) NOT NULL,
    soil_type             VARCHAR(30),
    gps_lat               DECIMAL(10, 7),
    gps_lon               DECIMAL(10, 7),
    elevation_m           INT,
    climate_zone          VARCHAR(20),
    created_at            DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_fields_size CHECK (size_ha > 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS plantings (
    planting_id           INT AUTO_INCREMENT PRIMARY KEY,
    field_id              INT NOT NULL,
    variety_id            INT NOT NULL,
    planting_date         DATE NOT NULL,
    harvest_date          DATE,
    crop_type             VARCHAR(30) NOT NULL,
    planting_density      INT,
    row_spacing_cm        INT,
    plant_spacing_cm      INT,
    notes                 TEXT,
    created_at            DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_planting_density CHECK (planting_density IS NULL OR planting_density > 0),
    CONSTRAINT chk_row_spacing CHECK (row_spacing_cm IS NULL OR row_spacing_cm > 0),
    CONSTRAINT chk_plant_spacing CHECK (plant_spacing_cm IS NULL OR plant_spacing_cm > 0),
    CONSTRAINT chk_harvest_after_planting CHECK (harvest_date IS NULL OR harvest_date >= planting_date),
    CONSTRAINT fk_plantings_field FOREIGN KEY (field_id) REFERENCES fields(field_id) ON DELETE CASCADE,
    CONSTRAINT fk_plantings_variety FOREIGN KEY (variety_id) REFERENCES varieties(variety_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS treatments (
    treatment_id          INT AUTO_INCREMENT PRIMARY KEY,
    planting_id           INT NOT NULL,
    treatment_type        ENUM('fertilizer', 'pesticide', 'herbicide', 'irrigation') NOT NULL,
    product_name          VARCHAR(100),
    application_date      DATE NOT NULL,
    rate_per_ha           DECIMAL(10, 2),
    cost_usd              DECIMAL(10, 2),
    notes                 TEXT,
    created_at            DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_rate_non_negative CHECK (rate_per_ha IS NULL OR rate_per_ha >= 0),
    CONSTRAINT chk_cost_non_negative CHECK (cost_usd IS NULL OR cost_usd >= 0),
    CONSTRAINT fk_treatments_planting FOREIGN KEY (planting_id) REFERENCES plantings(planting_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS observations (
    observation_id        INT AUTO_INCREMENT PRIMARY KEY,
    planting_id           INT NOT NULL,
    observation_date      DATE NOT NULL,
    avg_plant_height_cm   INT,
    color_rating          INT,
    pest_presence         TINYINT(1) NOT NULL DEFAULT 0,
    disease_presence      TINYINT(1) NOT NULL DEFAULT 0,
    notes                 TEXT,
    created_at            DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_height_non_negative CHECK (avg_plant_height_cm IS NULL OR avg_plant_height_cm >= 0),
    CONSTRAINT chk_color_rating CHECK (color_rating IS NULL OR color_rating BETWEEN 1 AND 5),
    CONSTRAINT fk_observations_planting FOREIGN KEY (planting_id) REFERENCES plantings(planting_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS soil_moisture_readings (
    moisture_id           INT AUTO_INCREMENT PRIMARY KEY,
    planting_id           INT NOT NULL,
    reading_time          DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    moisture_percent      DECIMAL(5, 2) NOT NULL,
    source                VARCHAR(30) DEFAULT 'sensor',
    CONSTRAINT chk_moisture_percent CHECK (moisture_percent >= 0 AND moisture_percent <= 100),
    CONSTRAINT fk_moisture_planting FOREIGN KEY (planting_id) REFERENCES plantings(planting_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS weather_events (
    event_id              INT AUTO_INCREMENT PRIMARY KEY,
    field_id              INT NOT NULL,
    event_date            DATE NOT NULL,
    event_type            VARCHAR(30) NOT NULL,
    intensity             DECIMAL(8, 2),
    notes                 TEXT,
    created_at            DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_weather_field FOREIGN KEY (field_id) REFERENCES fields(field_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS yields (
    yield_id              INT AUTO_INCREMENT PRIMARY KEY,
    planting_id           INT NOT NULL,
    harvest_date          DATE NOT NULL,
    yield_tons_per_ha     DECIMAL(8, 2),
    quality_grade         VARCHAR(10),
    notes                 TEXT,
    created_at            DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_yield_per_planting UNIQUE (planting_id),
    CONSTRAINT chk_yield_non_negative CHECK (yield_tons_per_ha IS NULL OR yield_tons_per_ha >= 0),
    CONSTRAINT fk_yields_planting FOREIGN KEY (planting_id) REFERENCES plantings(planting_id) ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE INDEX idx_plantings_field ON plantings(field_id);
CREATE INDEX idx_plantings_variety ON plantings(variety_id);
CREATE INDEX idx_plantings_date ON plantings(planting_date);
CREATE INDEX idx_treatments_planting ON treatments(planting_id);
CREATE INDEX idx_treatments_app_date ON treatments(application_date);
CREATE INDEX idx_observations_planting ON observations(planting_id);
CREATE INDEX idx_observations_date ON observations(observation_date);
CREATE INDEX idx_soil_moisture_planting_time ON soil_moisture_readings(planting_id, reading_time);
CREATE INDEX idx_weather_field_date ON weather_events(field_id, event_date);
CREATE INDEX idx_yields_planting ON yields(planting_id);

DROP VIEW IF EXISTS yield_history;
DROP VIEW IF EXISTS pest_alerts;
DROP VIEW IF EXISTS treatment_summary;
DROP VIEW IF EXISTS active_crops;

CREATE VIEW active_crops AS
SELECT
    p.planting_id,
    f.field_name,
    v.variety_name,
    c.crop_name,
    p.planting_date,
    DATEDIFF(CURDATE(), p.planting_date) AS days_since_planting,
    COALESCE(v.days_to_maturity, c.days_to_maturity) AS days_to_maturity,
    LEAST(
      100,
      ROUND(
        (DATEDIFF(CURDATE(), p.planting_date) / NULLIF(COALESCE(v.days_to_maturity, c.days_to_maturity), 0)) * 100
      )
    ) AS growth_percent,
    CASE
      WHEN DATEDIFF(CURDATE(), p.planting_date) < COALESCE(v.days_to_maturity, c.days_to_maturity) * 0.10 THEN 'Germination'
      WHEN DATEDIFF(CURDATE(), p.planting_date) < COALESCE(v.days_to_maturity, c.days_to_maturity) * 0.30 THEN 'Vegetative'
      WHEN DATEDIFF(CURDATE(), p.planting_date) < COALESCE(v.days_to_maturity, c.days_to_maturity) * 0.60 THEN 'Flowering'
      WHEN DATEDIFF(CURDATE(), p.planting_date) < COALESCE(v.days_to_maturity, c.days_to_maturity) * 0.85 THEN 'Fruiting/Grain fill'
      WHEN DATEDIFF(CURDATE(), p.planting_date) < COALESCE(v.days_to_maturity, c.days_to_maturity) THEN 'Maturation'
      ELSE 'Harvest ready'
    END AS growth_stage,
    (
      SELECT smr.moisture_percent
      FROM soil_moisture_readings smr
      WHERE smr.planting_id = p.planting_id
      ORDER BY smr.reading_time DESC, smr.moisture_id DESC
      LIMIT 1
    ) AS latest_moisture_percent,
    (
      SELECT o.observation_date
      FROM observations o
      WHERE o.planting_id = p.planting_id
      ORDER BY o.observation_date DESC, o.observation_id DESC
      LIMIT 1
    ) AS last_observation_date,
    (
      SELECT o.color_rating
      FROM observations o
      WHERE o.planting_id = p.planting_id
      ORDER BY o.observation_date DESC, o.observation_id DESC
      LIMIT 1
    ) AS latest_color_rating,
    (
      SELECT o.pest_presence
      FROM observations o
      WHERE o.planting_id = p.planting_id
      ORDER BY o.observation_date DESC, o.observation_id DESC
      LIMIT 1
    ) AS latest_pest_presence,
    (
      SELECT o.disease_presence
      FROM observations o
      WHERE o.planting_id = p.planting_id
      ORDER BY o.observation_date DESC, o.observation_id DESC
      LIMIT 1
    ) AS latest_disease_presence
FROM plantings p
JOIN fields f ON p.field_id = f.field_id
JOIN varieties v ON p.variety_id = v.variety_id
JOIN crops c ON v.crop_id = c.crop_id
WHERE p.harvest_date IS NULL;

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

CREATE VIEW pest_alerts AS
SELECT
    p.planting_id,
    f.field_name,
    c.crop_name,
    MAX(o.observation_date) AS last_observation,
    MAX(CASE WHEN o.pest_presence = 1 THEN 1 ELSE 0 END) AS pest_detected,
    MAX(CASE WHEN o.disease_presence = 1 THEN 1 ELSE 0 END) AS disease_detected,
    CASE
      WHEN MAX(CASE WHEN o.pest_presence = 1 THEN 1 ELSE 0 END) = 1
           AND MAX(CASE WHEN o.disease_presence = 1 THEN 1 ELSE 0 END) = 1 THEN 'Pest and disease risk detected'
      WHEN MAX(CASE WHEN o.pest_presence = 1 THEN 1 ELSE 0 END) = 1 THEN 'Pest risk detected'
      WHEN MAX(CASE WHEN o.disease_presence = 1 THEN 1 ELSE 0 END) = 1 THEN 'Disease risk detected'
      ELSE 'No alerts'
    END AS alert_status
FROM plantings p
JOIN fields f ON p.field_id = f.field_id
JOIN varieties v ON p.variety_id = v.variety_id
JOIN crops c ON v.crop_id = c.crop_id
LEFT JOIN observations o ON p.planting_id = o.planting_id
WHERE p.harvest_date IS NULL
GROUP BY p.planting_id, f.field_name, c.crop_name
HAVING pest_detected = 1 OR disease_detected = 1;

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

INSERT IGNORE INTO crops (crop_name, crop_group, days_to_maturity, optimal_season, market_price_usd, use_category) VALUES
('Maize', 'Cereal', 120, 'Summer', 385.00, 'Grain'),
('Tobacco', 'Cash', 90, 'Summer', 4250.00, 'Leaf'),
('Cotton', 'Fibre', 150, 'Summer', 1020.00, 'Fibre'),
('Tomatoes', 'Vegetable', 80, 'All', 520.00, 'Fresh');

INSERT IGNORE INTO varieties (crop_id, variety_name, seed_source, days_to_maturity)
SELECT c.crop_id, x.variety_name, x.seed_source, x.days_to_maturity
FROM (
  SELECT 'Maize' AS crop_name, 'SC 403' AS variety_name, 'SeedCo' AS seed_source, 115 AS days_to_maturity
  UNION ALL SELECT 'Maize', 'SC 513', 'SeedCo', 125
  UNION ALL SELECT 'Tobacco', 'Kutsaga', 'Tobacco Research Board', 88
  UNION ALL SELECT 'Cotton', 'Cotton 1', 'Cotton Research Institute', 145
  UNION ALL SELECT 'Tomatoes', 'Heinz', 'SeedCo', 75
) x
JOIN crops c ON c.crop_name = x.crop_name;

INSERT IGNORE INTO fields (field_name, size_ha, soil_type, gps_lat, gps_lon, elevation_m, climate_zone) VALUES
('Field A', 5.20, 'Sandy Loam', -17.8248580, 31.0530280, 1450, 'Subtropical'),
('Field B', 3.80, 'Clay', -17.8300000, 31.0600000, 1400, 'Subtropical'),
('Greenhouse 1', 0.50, 'Loam', -17.8200000, 31.0550000, 1450, 'Controlled');

INSERT INTO plantings (field_id, variety_id, planting_date, crop_type, planting_density, row_spacing_cm, plant_spacing_cm, notes)
SELECT f.field_id, v.variety_id, x.planting_date, x.crop_type, x.planting_density, x.row_spacing_cm, x.plant_spacing_cm, x.notes
FROM (
  SELECT 'Field A' AS field_name, 'SC 403' AS variety_name, '2026-06-01' AS planting_date, 'Maize' AS crop_type, 55000 AS planting_density, 75 AS row_spacing_cm, 25 AS plant_spacing_cm, 'Tasseling stage' AS notes
  UNION ALL SELECT 'Field B', 'Kutsaga', '2026-06-15', 'Tobacco', 25000, 100, 50, 'Topping soon'
  UNION ALL SELECT 'Greenhouse 1', 'Heinz', '2026-07-01', 'Tomatoes', 30000, 80, 40, 'Fruit ripening'
) x
JOIN fields f ON f.field_name = x.field_name
JOIN varieties v ON v.variety_name = x.variety_name
WHERE NOT EXISTS (
  SELECT 1
  FROM plantings p
  WHERE p.field_id = f.field_id
    AND p.variety_id = v.variety_id
    AND p.planting_date = x.planting_date
);

INSERT INTO treatments (planting_id, treatment_type, product_name, application_date, rate_per_ha, cost_usd, notes)
SELECT p.planting_id, 'fertilizer', 'Urea', '2026-07-10', 150, 75, 'Nitrogen application'
FROM plantings p
JOIN fields f ON p.field_id = f.field_id
WHERE f.field_name = 'Field A'
  AND NOT EXISTS (
    SELECT 1
    FROM treatments t
    WHERE t.planting_id = p.planting_id
      AND t.treatment_type = 'fertilizer'
      AND t.application_date = '2026-07-10'
  );

INSERT INTO observations (planting_id, observation_date, avg_plant_height_cm, color_rating, pest_presence, disease_presence, notes)
SELECT p.planting_id, '2026-07-20', 180, 4, 0, 0, 'Healthy'
FROM plantings p
JOIN fields f ON p.field_id = f.field_id
WHERE f.field_name = 'Field A'
  AND NOT EXISTS (
    SELECT 1
    FROM observations o
    WHERE o.planting_id = p.planting_id
      AND o.observation_date = '2026-07-20'
  );

INSERT INTO soil_moisture_readings (planting_id, reading_time, moisture_percent, source)
SELECT p.planting_id, '2026-07-22 08:00:00', 61.0, 'sensor'
FROM plantings p
JOIN fields f ON p.field_id = f.field_id
WHERE f.field_name = 'Field A'
  AND NOT EXISTS (
    SELECT 1
    FROM soil_moisture_readings s
    WHERE s.planting_id = p.planting_id
      AND s.reading_time = '2026-07-22 08:00:00'
  );

INSERT INTO weather_events (field_id, event_date, event_type, intensity, notes)
SELECT f.field_id, '2026-07-22', 'rain', 12.5, 'Good rain for tasseling'
FROM fields f
WHERE f.field_name = 'Field A'
  AND NOT EXISTS (
    SELECT 1
    FROM weather_events w
    WHERE w.field_id = f.field_id
      AND w.event_date = '2026-07-22'
      AND w.event_type = 'rain'
  );

INSERT IGNORE INTO yields (planting_id, harvest_date, yield_tons_per_ha, quality_grade, notes)
SELECT p.planting_id, '2026-09-20', 6.2, 'A', 'Excellent quality'
FROM plantings p
JOIN fields f ON p.field_id = f.field_id
WHERE f.field_name = 'Field A';

-- Key dashboard queries
-- SELECT COUNT(*) AS active_crop_plots FROM active_crops;
-- SELECT ROUND(AVG(latest_moisture_percent), 2) AS avg_soil_moisture FROM active_crops WHERE latest_moisture_percent IS NOT NULL;
-- SELECT * FROM pest_alerts WHERE alert_status <> 'No alerts';
-- SELECT crop_name, field_name, growth_percent, growth_stage FROM active_crops ORDER BY growth_percent DESC;
-- SELECT field_name, total_cost_usd FROM treatment_summary ORDER BY total_cost_usd DESC;
