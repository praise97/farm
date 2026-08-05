import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/app_constants.dart';

/// Uploads animal photos to Firebase Storage (or local disk offline).
class AnimalPhotoService {
  AnimalPhotoService._();
  static final AnimalPhotoService instance = AnimalPhotoService._();

  Future<String> upload({
    required String farmId,
    required String animalId,
    required int slot,
    required String localPath,
  }) async {
    if (AppConstants.firebaseConfigured && !kIsWeb) {
      try {
        final ref = FirebaseStorage.instance.ref(
          'farms/$farmId/animals/$animalId/photo_${slot}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        await ref.putFile(File(localPath));
        return await ref.getDownloadURL();
      } catch (e) {
        debugPrint('Roots: Firebase photo upload failed, using local: $e');
      }
    }
    final dir = await getApplicationDocumentsDirectory();
    final destDir = Directory('${dir.path}/animal_photos/$farmId/$animalId');
    await destDir.create(recursive: true);
    final dest = File('${destDir.path}/photo_$slot.jpg');
    await File(localPath).copy(dest.path);
    return dest.path;
  }

  Future<void> deleteUrls(List<String?> urls) async {
    for (final url in urls) {
      if (url == null || url.isEmpty) continue;
      if (url.startsWith('http')) {
        try {
          await FirebaseStorage.instance.refFromURL(url).delete();
        } catch (e) {
          debugPrint('Roots: delete remote photo: $e');
        }
      } else {
        final file = File(url);
        if (file.existsSync()) {
          try {
            await file.delete();
          } catch (e) {
            debugPrint('Roots: delete local photo: $e');
          }
        }
      }
    }
  }

  bool isRemoteUrl(String? url) => url != null && url.startsWith('http');

  ImageProvider? imageProvider(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return NetworkImage(url);
    final file = File(url);
    if (file.existsSync()) return FileImage(file);
    return null;
  }
}
