import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'core/constants/app_constants.dart';
import 'firebase_options.dart';

/// Boots Firebase when configured; otherwise runs fully offline/demo.
Future<bool> initializeFirebase() async {
  if (!AppConstants.firebaseConfigured) {
    debugPrint('Roots: Firebase not configured — running in offline/demo mode.');
    return false;
  }
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    debugPrint('Roots: Firebase initialized for ${DefaultFirebaseOptions.currentPlatform.projectId}');
    return true;
  } catch (e, st) {
    debugPrint('Roots: Firebase init failed: $e\n$st');
    return false;
  }
}

/// Restore Firebase Auth session from persisted credentials.
Future<void> restoreFirebaseSession() async {
  if (!AppConstants.firebaseConfigured) return;
  await FirebaseAuth.instance.authStateChanges().first;
}
