import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/enums.dart';
import '../../../core/theme/roots_theme.dart';
import '../../../domain/entities/animal.dart';
import '../../providers/app_providers.dart';
import '../../widgets/animal_photo_capture.dart';

class AnimalFormScreen extends ConsumerStatefulWidget {
  const AnimalFormScreen({super.key, this.animalId});

  final String? animalId;

  @override
  ConsumerState<AnimalFormScreen> createState() => _AnimalFormScreenState();
}

class _AnimalFormScreenState extends ConsumerState<AnimalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _tag;
  late final TextEditingController _breed;
  late final TextEditingController _category;
  late final TextEditingController _weight;
  late final TextEditingController _colour;
  late final TextEditingController _location;
  late final TextEditingController _owner;
  AnimalGender _gender = AnimalGender.female;
  AnimalStatus _status = AnimalStatus.alive;
  DateTime _birthDate = DateTime.now().subtract(const Duration(days: 365));
  bool _saving = false;
  String? _photo1Path;
  String? _photo2Path;
  Animal? _existing;

  @override
  void initState() {
    super.initState();
    _existing = widget.animalId == null
        ? null
        : ref.read(appRepositoryProvider).animal(widget.animalId!);
    _tag = TextEditingController(text: _existing?.tagNumber ?? '');
    _breed = TextEditingController(text: _existing?.breed ?? '');
    _category = TextEditingController(text: _existing?.category ?? 'Cattle');
    _weight = TextEditingController(text: _existing?.weight.toString() ?? '');
    _colour = TextEditingController(text: _existing?.colour ?? '');
    _location = TextEditingController(text: _existing?.location ?? '');
    _owner = TextEditingController(
      text: _existing?.currentOwner ?? ref.read(authStateProvider).valueOrNull?.name ?? '',
    );
    if (_existing != null) {
      _gender = _existing!.gender;
      _status = _existing!.status;
      _birthDate = _existing!.birthDate;
    }
  }

  @override
  void dispose() {
    _tag.dispose();
    _breed.dispose();
    _category.dispose();
    _weight.dispose();
    _colour.dispose();
    _location.dispose();
    _owner.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final isNew = _existing == null;
    final photosEnabled = _status != AnimalStatus.dead && _status != AnimalStatus.sold;
    if (isNew && photosEnabled) {
      if (_photo1Path == null || _photo2Path == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please capture both photos (front and side).')),
        );
        return;
      }
    }

    setState(() => _saving = true);
    final user = ref.read(authStateProvider).valueOrNull!;
    final repo = ref.read(appRepositoryProvider);
    final now = DateTime.now();
    var animal = Animal(
      id: _existing?.id ?? repo.newId(),
      farmId: user.farmId,
      tagNumber: _tag.text.trim(),
      qrCode: _tag.text.trim(),
      breed: _breed.text.trim(),
      category: _category.text.trim(),
      gender: _gender,
      birthDate: _birthDate,
      weight: double.parse(_weight.text.trim()),
      colour: _colour.text.trim().isEmpty ? null : _colour.text.trim(),
      photo1Url: _existing?.photo1Url,
      photo2Url: _existing?.photo2Url,
      photosUpdatedAt: _existing?.photosUpdatedAt,
      currentOwner: _owner.text.trim(),
      location: _location.text.trim().isEmpty ? null : _location.text.trim(),
      status: _status,
      updatedAt: now,
      createdAt: _existing?.createdAt ?? now,
    );

    animal = await repo.saveAnimal(animal, previous: _existing);

    if (photosEnabled && (_photo1Path != null || _photo2Path != null)) {
      animal = await repo.saveAnimalPhotos(
        animal: animal,
        photo1LocalPath: _photo1Path,
        photo2LocalPath: _photo2Path,
      );
    }

    if (_existing == null) {
      await repo.addTimelineEvent(AnimalTimelineEvent(
        id: repo.newId(),
        animalId: animal.id,
        farmId: animal.farmId,
        type: TimelineEventType.tagIssued,
        title: 'Tag Issued',
        notes: animal.tagNumber,
        date: now,
      ));
    }

    bumpData(ref);
    if (!mounted) return;
    setState(() => _saving = false);
    context.go('/livestock/${animal.id}');
  }

  @override
  Widget build(BuildContext context) {
    final photosEnabled = _status != AnimalStatus.dead && _status != AnimalStatus.sold;

    return Scaffold(
      appBar: AppBar(title: Text(widget.animalId == null ? 'Add Animal' : 'Edit Animal')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (photosEnabled)
                  AnimalPhotoCaptureRow(
                    photo1Path: _photo1Path,
                    photo2Path: _photo2Path,
                    existingPhoto1Url: _existing?.photo1Url,
                    existingPhoto2Url: _existing?.photo2Url,
                    onPhoto1: (p) => setState(() => _photo1Path = p),
                    onPhoto2: (p) => setState(() => _photo2Path = p),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text(
                      'Photos removed — animal marked dead or sold to free storage.',
                      style: TextStyle(color: RootsColors.muted, fontSize: 13),
                    ),
                  ),
                if (photosEnabled) const SizedBox(height: 20),
                TextFormField(
                  controller: _tag,
                  decoration: const InputDecoration(labelText: 'Tag Number', prefixIcon: Icon(Icons.qr_code)),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _breed,
                  decoration: const InputDecoration(labelText: 'Breed'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _category,
                  decoration: const InputDecoration(labelText: 'Category (Cattle, Goat, Sheep…)'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<AnimalGender>(
                        value: _gender,
                        decoration: const InputDecoration(labelText: 'Gender'),
                        items: AnimalGender.values
                            .map((g) => DropdownMenuItem(value: g, child: Text(g.label)))
                            .toList(),
                        onChanged: (v) => setState(() => _gender = v!),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<AnimalStatus>(
                        value: _status,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: AnimalStatus.values
                            .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                            .toList(),
                        onChanged: (v) => setState(() => _status = v!),
                      ),
                    ),
                  ],
                ),
                if (_status == AnimalStatus.dead || _status == AnimalStatus.sold)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _status == AnimalStatus.dead
                          ? 'Marking dead deletes all photos from Firebase storage.'
                          : 'Marking sold deletes all photos from Firebase storage.',
                      style: const TextStyle(color: RootsColors.orange, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Birth Date'),
                  subtitle: Text(
                      '${_birthDate.year}-${_birthDate.month.toString().padLeft(2, '0')}-${_birthDate.day.toString().padLeft(2, '0')}'),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _birthDate,
                      firstDate: DateTime(1990),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _birthDate = picked);
                  },
                ),
                TextFormField(
                  controller: _weight,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Weight (kg)', suffixText: 'kg'),
                  validator: (v) => double.tryParse(v ?? '') == null ? 'Enter weight' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(controller: _colour, decoration: const InputDecoration(labelText: 'Colour')),
                const SizedBox(height: 12),
                TextFormField(controller: _location, decoration: const InputDecoration(labelText: 'Location / Pen')),
                const SizedBox(height: 12),
                TextFormField(controller: _owner, decoration: const InputDecoration(labelText: 'Current Owner')),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save Animal'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
