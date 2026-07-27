const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');

const app = express();
app.use(cors());
app.use(express.json());

const pool = new Pool({
  user: process.env.PGUSER || 'postgres',
  host: process.env.PGHOST || 'localhost',
  database: process.env.PGDATABASE || 'farm_db',
  password: process.env.PGPASSWORD || 'postgres',
  port: Number(process.env.PGPORT || 5432),
});

app.get('/health', async (_req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ ok: true });
  } catch (error) {
    res.status(500).json({ ok: false, error: error.message });
  }
});

app.get('/api/fields', async (_req, res) => {
  try {
    const result = await pool.query('SELECT field_id, field_name FROM fields ORDER BY field_name ASC;');
    res.json(result.rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/varieties', async (_req, res) => {
  try {
    const result = await pool.query(
      `
      SELECT
        v.variety_id,
        v.variety_name,
        v.crop_id,
        c.crop_name,
        v.days_to_maturity
      FROM varieties v
      JOIN crops c ON c.crop_id = v.crop_id
      ORDER BY c.crop_name ASC, v.variety_name ASC;
      `
    );
    res.json(result.rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/crops/active', async (_req, res) => {
  try {
    const result = await pool.query('SELECT * FROM active_crops ORDER BY growth_percent DESC, planting_date ASC;');
    res.json(result.rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/dashboard/summary', async (_req, res) => {
  try {
    const [activeCount, moistureAvg, alertCount] = await Promise.all([
      pool.query('SELECT COUNT(*)::INT AS total FROM active_crops;'),
      pool.query('SELECT ROUND(AVG(latest_moisture_percent)::NUMERIC, 2) AS avg_moisture FROM active_crops WHERE latest_moisture_percent IS NOT NULL;'),
      pool.query("SELECT COUNT(*)::INT AS total FROM pest_alerts WHERE alert_status <> 'No alerts';"),
    ]);

    res.json({
      active_crop_plots: activeCount.rows[0].total,
      avg_soil_moisture: moistureAvg.rows[0].avg_moisture,
      smart_alerts: alertCount.rows[0].total,
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.get('/api/alerts', async (_req, res) => {
  try {
    const result = await pool.query("SELECT * FROM pest_alerts WHERE alert_status <> 'No alerts' ORDER BY last_observation DESC NULLS LAST;");
    res.json(result.rows);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/plantings', async (req, res) => {
  const {
    field_id,
    variety_id,
    planting_date,
    crop_type,
    planting_density,
    row_spacing_cm,
    plant_spacing_cm,
    notes,
  } = req.body;

  if (!field_id || !variety_id || !planting_date || !crop_type) {
    return res.status(400).json({
      error: 'field_id, variety_id, planting_date, and crop_type are required',
    });
  }

  try {
    const result = await pool.query(
      `
      INSERT INTO plantings (
        field_id,
        variety_id,
        planting_date,
        crop_type,
        planting_density,
        row_spacing_cm,
        plant_spacing_cm,
        notes
      )
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
      RETURNING *;
      `,
      [
        field_id,
        variety_id,
        planting_date,
        crop_type,
        planting_density ?? null,
        row_spacing_cm ?? null,
        plant_spacing_cm ?? null,
        notes ?? null,
      ]
    );

    return res.status(201).json(result.rows[0]);
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

app.post('/api/soil-moisture', async (req, res) => {
  const {
    planting_id,
    moisture_percent,
    reading_time,
    source,
  } = req.body;

  if (!planting_id || moisture_percent == null) {
    return res.status(400).json({
      error: 'planting_id and moisture_percent are required',
    });
  }

  const moistureValue = Number(moisture_percent);
  if (Number.isNaN(moistureValue) || moistureValue < 0 || moistureValue > 100) {
    return res.status(400).json({
      error: 'moisture_percent must be a number between 0 and 100',
    });
  }

  try {
    const result = await pool.query(
      `
      INSERT INTO soil_moisture_readings (
        planting_id,
        reading_time,
        moisture_percent,
        source
      )
      VALUES ($1, COALESCE($2, NOW()), $3, COALESCE($4, 'sensor'))
      RETURNING *;
      `,
      [
        planting_id,
        reading_time || null,
        moistureValue,
        source || null,
      ]
    );

    return res.status(201).json(result.rows[0]);
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

app.post('/api/observations', async (req, res) => {
  const {
    planting_id,
    observation_date,
    avg_plant_height_cm,
    color_rating,
    pest_presence,
    disease_presence,
    notes,
  } = req.body;

  if (!planting_id || !observation_date) {
    return res.status(400).json({
      error: 'planting_id and observation_date are required',
    });
  }

  if (color_rating != null && (Number(color_rating) < 1 || Number(color_rating) > 5)) {
    return res.status(400).json({
      error: 'color_rating must be between 1 and 5',
    });
  }

  try {
    const result = await pool.query(
      `
      INSERT INTO observations (
        planting_id,
        observation_date,
        avg_plant_height_cm,
        color_rating,
        pest_presence,
        disease_presence,
        notes
      )
      VALUES ($1, $2, $3, $4, COALESCE($5, FALSE), COALESCE($6, FALSE), $7)
      RETURNING *;
      `,
      [
        planting_id,
        observation_date,
        avg_plant_height_cm ?? null,
        color_rating ?? null,
        pest_presence ?? null,
        disease_presence ?? null,
        notes ?? null,
      ]
    );

    return res.status(201).json(result.rows[0]);
  } catch (error) {
    return res.status(500).json({ error: error.message });
  }
});

const port = Number(process.env.PORT || 3000);
app.listen(port, () => {
  console.log(`FarmSmartPro API running on port ${port}`);
});
