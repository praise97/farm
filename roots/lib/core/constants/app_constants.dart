/// App-wide constants for Roots.
class AppConstants {
  static const appName = 'Roots';
  static const tagline = 'AI-powered farm management';
  static const defaultFarmId = 'demo-farm-001';

  /// Set true after Firebase is configured (see FIREBASE_SETUP.md).
  static const firebaseConfigured = true;

  static const demoEmail = 'farmer@roots.app';
  static const demoPassword = 'roots123';
}

class HiveBoxes {
  static const animals = 'animals';
  static const equipment = 'equipment';
  static const inventory = 'inventory';
  static const finance = 'finance';
  static const tasks = 'tasks';
  static const crops = 'crops';
  static const alerts = 'alerts';
  static const users = 'users';
  static const farms = 'farms';
  static const timeline = 'timeline';
  static const syncQueue = 'sync_queue';
  static const settings = 'settings';
}

class FirestorePaths {
  static String farm(String farmId) => 'farms/$farmId';
  static String animals(String farmId) => 'farms/$farmId/animals';
  static String equipment(String farmId) => 'farms/$farmId/equipment';
  static String inventory(String farmId) => 'farms/$farmId/inventory';
  static String finance(String farmId) => 'farms/$farmId/finance';
  static String tasks(String farmId) => 'farms/$farmId/tasks';
  static String crops(String farmId) => 'farms/$farmId/crops';
  static String alerts(String farmId) => 'farms/$farmId/alerts';
  static String workers(String farmId) => 'farms/$farmId/workers';
  static String mapPoints(String farmId) => 'farms/$farmId/mapPoints';
}
