import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/services/animal_photo_service.dart';
import '../../core/theme/roots_theme.dart';

/// Two photo slots — camera capture for add/edit animal forms.
class AnimalPhotoCaptureRow extends StatelessWidget {
  const AnimalPhotoCaptureRow({
    super.key,
    required this.photo1Path,
    required this.photo2Path,
    required this.existingPhoto1Url,
    required this.existingPhoto2Url,
    required this.onPhoto1,
    required this.onPhoto2,
    this.enabled = true,
  });

  final String? photo1Path;
  final String? photo2Path;
  final String? existingPhoto1Url;
  final String? existingPhoto2Url;
  final ValueChanged<String?> onPhoto1;
  final ValueChanged<String?> onPhoto2;
  final bool enabled;

  Future<void> _capture(BuildContext context, ValueChanged<String?> onPicked) async {
    if (!enabled) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final file = await ImagePicker().pickImage(source: source, imageQuality: 80);
    if (file != null) onPicked(file.path);
  }

  Widget _slot(
    BuildContext context, {
    required String label,
    required String? localPath,
    required String? existingUrl,
    required VoidCallback onTap,
  }) {
    ImageProvider? provider;
    if (localPath != null && File(localPath).existsSync()) {
      provider = FileImage(File(localPath));
    } else {
      provider = AnimalPhotoService.instance.imageProvider(existingUrl);
    }

    return Expanded(
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Material(
              color: RootsColors.bg,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: enabled ? onTap : null,
                child: provider != null
                    ? Image(image: provider, fit: BoxFit.cover)
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined,
                              size: 32, color: enabled ? RootsColors.greenDeep : RootsColors.muted),
                          const SizedBox(height: 8),
                          Text(label,
                              style: TextStyle(
                                  color: enabled ? RootsColors.muted : RootsColors.line, fontSize: 12)),
                        ],
                      ),
              ),
            ),
          ),
          if (localPath != null || existingUrl != null)
            TextButton(
              onPressed: enabled ? onTap : null,
              child: const Text('Retake / Replace'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Animal photos (2 required)',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 4),
        const Text(
          'Capture front and side views. Every year you will be reminded to take new photos — old ones are deleted from storage to save space.',
          style: TextStyle(color: RootsColors.muted, fontSize: 12, height: 1.35),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _slot(
              context,
              label: 'Photo 1',
              localPath: photo1Path,
              existingUrl: existingPhoto1Url,
              onTap: () => _capture(context, onPhoto1),
            ),
            const SizedBox(width: 12),
            _slot(
              context,
              label: 'Photo 2',
              localPath: photo2Path,
              existingUrl: existingPhoto2Url,
              onTap: () => _capture(context, onPhoto2),
            ),
          ],
        ),
      ],
    );
  }
}
