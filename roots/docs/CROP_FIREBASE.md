# Crop module (Firebase)

Partner relational schema from `crop-database/` is implemented in Roots as Firestore + Hive (offline-first). **Do not run MySQL or the Node API for the app.**

## Mapping

| MySQL / Postgres | Firestore path |
|------------------|----------------|
| crops | `farms/{farmId}/cropCatalog/{id}` |
| varieties | `farms/{farmId}/varieties/{id}` |
| fields | `farms/{farmId}/fields/{id}` |
| plantings / active_crops | `farms/{farmId}/crops/{id}` |
| treatments | `farms/{farmId}/treatments/{id}` |
| observations | `farms/{farmId}/observations/{id}` |
| soil_moisture_readings | stored on planting as `soilMoisture` |
| pest_alerts view | planting flags + `alerts` |

Growth % / stage match the partner `active_crops` view logic in Dart (`CropPlot.growthFor` / `stageFor`).

## UI

Crops screen tabs: Active crops · Fields · Catalog · Market  
Sidebar: Dashboard + FARM (Livestock, Crops, Inventory, Tasks)
