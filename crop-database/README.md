# FarmSmartPro Crop Database

This folder contains relational schemas (PostgreSQL and MySQL) for the crop management dashboard, plus a minimal Node.js API scaffold.

## Files

- `schema.postgres.sql`: Full database setup (tables, constraints, indexes, views, sample seed data, and dashboard queries).
- `schema.mysql.sql`: MySQL 8+ compatible variant of the same schema and dashboard views.
- `api/server.js`: Express + pg API starter with endpoints for active crops, alerts, dashboard summary, and creating plantings.
- `api/package.json`: API dependencies.

## 1) Create database

Example (psql):

```bash
createdb farm_db
```

## 2) Apply schema (PostgreSQL)

From this folder:

```bash
psql -d farm_db -f schema.postgres.sql
```

## 2b) Apply schema (MySQL 8+)

```bash
mysql -u root -p farm_db < schema.mysql.sql
```

## 3) Start API

```bash
cd api
npm install
npm start
```

## 4) Environment variables (optional)

Defaults are set in `server.js`, but you can override:

- `PGUSER`
- `PGHOST`
- `PGDATABASE`
- `PGPASSWORD`
- `PGPORT`
- `PORT`

## API endpoints

- `GET /health`
- `GET /api/crops/active`
- `GET /api/dashboard/summary`
- `GET /api/alerts`
- `GET /api/fields`
- `GET /api/varieties`
- `POST /api/plantings`
- `POST /api/soil-moisture`
- `POST /api/observations`

## Dashboard-aligned SQL views

- `active_crops`
- `treatment_summary`
- `pest_alerts`
- `yield_history`

## Notes

- A `soil_moisture_readings` table is included so average moisture widgets can be queried directly.
- Frontend `crop-management.js` now reads from `GET /api/dashboard/summary`, `GET /api/crops/active`, and `GET /api/alerts`.
- Frontend Add Crop modal can submit directly to `POST /api/plantings` using API lookup data from `GET /api/fields` and `GET /api/varieties`.
- `schema.postgres.sql` uses PostgreSQL features (`LATERAL`, `BOOL_OR`), while `schema.mysql.sql` provides MySQL-safe equivalents.
