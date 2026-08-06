import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/constants/app_constants.dart';
import '../../core/constants/enums.dart';
import '../../domain/entities/animal.dart';
import '../../domain/entities/crop_entities.dart';
import '../../domain/entities/farm_user.dart';
import '../../domain/entities/shared_entities.dart';
import '../../data/repositories/app_repository.dart';

/// Generates summary PDF documents for supervisors.
class FarmReportService {
  FarmReportService._();
  static final FarmReportService instance = FarmReportService._();

  static final _dateFmt = DateFormat('MMM d, y');
  static final _dateTimeFmt = DateFormat('MMM d, y HH:mm');

  Future<void> sharePdf(pw.Document doc, String filename) async {
    await Printing.sharePdf(bytes: await doc.save(), filename: filename);
  }

  Future<void> allLivestock({
    required String farmName,
    required List<Animal> animals,
  }) async {
    final doc = _doc(
      title: 'All Livestock Summary',
      farmName: farmName,
      body: [
        _table(
          headers: const ['Tag', 'Breed', 'Category', 'Gender', 'Age', 'Weight', 'Status', 'Location'],
          rows: animals
              .map((a) => [
                    a.tagNumber,
                    a.breed,
                    a.category,
                    a.gender.name,
                    a.ageLabel,
                    '${a.weight.toStringAsFixed(0)} kg',
                    a.status.label,
                    a.location ?? '—',
                  ])
              .toList(),
        ),
        pw.SizedBox(height: 12),
        pw.Text('Total: ${animals.length} animals', style: _bold),
      ],
    );
    await sharePdf(doc, 'roots_livestock_summary.pdf');
  }

  Future<void> perAnimal({
    required String farmName,
    required Animal animal,
    required List<AnimalTimelineEvent> timeline,
    VaccinationDueInfo? vaccination,
  }) async {
    final vaxLine = vaccination?.last != null
        ? 'Last: ${vaccination!.last!.title} · Next due: ${vaccination.nextDue != null ? _dateFmt.format(vaccination.nextDue!) : '—'}'
        : 'No vaccination records';

    final doc = _doc(
      title: 'Animal Report — ${animal.tagNumber}',
      farmName: farmName,
      body: [
        _section('Profile'),
        _kvTable([
          ['Tag', animal.tagNumber],
          ['Breed', animal.breed],
          ['Category', animal.category],
          ['Gender', animal.gender.name],
          ['Age', animal.ageLabel],
          ['Weight', '${animal.weight.toStringAsFixed(0)} kg'],
          ['Status', animal.status.label],
          ['Owner', animal.currentOwner],
          ['Location', animal.location ?? '—'],
          ['Colour', animal.colour ?? '—'],
        ]),
        pw.SizedBox(height: 16),
        _section('Vaccination'),
        pw.Text(vaxLine),
        pw.SizedBox(height: 16),
        _section('Timeline'),
        if (timeline.isEmpty)
          pw.Text('No timeline events recorded.')
        else
          _table(
            headers: const ['Date', 'Event', 'Notes'],
            rows: timeline
                .map((e) => [
                      _dateFmt.format(e.date),
                      e.title,
                      e.notes ?? e.meta.entries.map((m) => '${m.key}: ${m.value}').join(', '),
                    ])
                .toList(),
          ),
      ],
    );
    await sharePdf(doc, 'roots_animal_${animal.tagNumber.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.pdf');
  }

  Future<void> allCrops({
    required String farmName,
    required List<CropPlot> crops,
  }) async {
    final doc = _doc(
      title: 'All Crops Summary',
      farmName: farmName,
      body: [
        _table(
          headers: const ['Plot', 'Crop', 'Field', 'Growth', 'Stage', 'Moisture', 'Planted', 'Harvest'],
          rows: crops
              .map((c) => [
                    c.name,
                    c.cropType,
                    c.fieldName ?? '—',
                    '${c.growthPercent.toStringAsFixed(0)}%',
                    c.growthStage,
                    c.soilMoisture != null ? '${c.soilMoisture!.toStringAsFixed(0)}%' : '—',
                    _dateFmt.format(c.plantedAt),
                    c.expectedHarvest != null ? _dateFmt.format(c.expectedHarvest!) : '—',
                  ])
              .toList(),
        ),
        pw.SizedBox(height: 12),
        pw.Text('Active plots: ${crops.length}', style: _bold),
      ],
    );
    await sharePdf(doc, 'roots_crops_summary.pdf');
  }

  Future<void> perCrop({
    required String farmName,
    required CropPlot crop,
  }) async {
    final doc = _doc(
      title: 'Crop Report — ${crop.name}',
      farmName: farmName,
      body: [
        _kvTable([
          ['Plot name', crop.name],
          ['Crop type', crop.cropType],
          ['Variety', crop.varietyName ?? '—'],
          ['Field', crop.fieldName ?? '—'],
          ['Growth', '${crop.growthPercent.toStringAsFixed(0)}%'],
          ['Stage', crop.growthStage],
          ['Status', crop.statusNote],
          ['Soil moisture', crop.soilMoisture != null ? '${crop.soilMoisture!.toStringAsFixed(0)}%' : '—'],
          ['Planted', _dateFmt.format(crop.plantedAt)],
          ['Expected harvest', crop.expectedHarvest != null ? _dateFmt.format(crop.expectedHarvest!) : '—'],
          ['Days since planting', '${crop.daysSincePlanting}'],
          ['Pest presence', crop.pestPresence ? 'Yes' : 'No'],
          ['Disease presence', crop.diseasePresence ? 'Yes' : 'No'],
        ]),
      ],
    );
    await sharePdf(doc, 'roots_crop_${crop.name.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}.pdf');
  }

  Future<void> marketSales({
    required String farmName,
    required List<FinanceEntry> entries,
  }) async {
    final sales = entries.where((e) => e.type == FinanceType.income).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final total = sales.fold<double>(0, (s, e) => s + e.amount);

    final doc = _doc(
      title: 'Market Sales Report',
      farmName: farmName,
      body: [
        pw.Text('Income / market sales only', style: const pw.TextStyle(color: PdfColors.grey700)),
        pw.SizedBox(height: 12),
        _table(
          headers: const ['Date', 'Category', 'Description', 'Amount (USD)'],
          rows: sales
              .map((e) => [
                    _dateFmt.format(e.date),
                    e.category,
                    e.description,
                    e.amount.toStringAsFixed(2),
                  ])
              .toList(),
        ),
        pw.SizedBox(height: 12),
        pw.Text('Total sales: \$${total.toStringAsFixed(2)}', style: _bold),
      ],
    );
    await sharePdf(doc, 'roots_market_sales.pdf');
  }

  Future<void> dutyRoster({
    required String farmName,
    required List<FarmTask> tasks,
    required List<FarmUser> staff,
  }) async {
    final workers = staff.where((u) => u.role == UserRole.worker).toList();
    final sections = <pw.Widget>[];

    for (final w in workers) {
      final mine = tasks.where((t) => t.assigneeId == w.id).toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
      sections.addAll([
        _section(w.name),
        if (mine.isEmpty)
          pw.Text('No assigned duties.')
        else
          _table(
            headers: const ['Task', 'Due', 'Priority', 'Status', 'Notes'],
            rows: mine
                .map((t) => [
                      t.title,
                      _dateFmt.format(t.dueDate),
                      t.priority.label,
                      t.status.label,
                      t.workerNotes ?? t.description ?? '—',
                    ])
                .toList(),
          ),
        pw.SizedBox(height: 14),
      ]);
    }

    final doc = _doc(
      title: 'Employee Duty Roster',
      farmName: farmName,
      body: [
        pw.Text('Assigned tasks per worker — ${workers.length} staff', style: _bold),
        pw.SizedBox(height: 12),
        ...sections,
      ],
    );
    await sharePdf(doc, 'roots_duty_roster.pdf');
  }

  Future<void> staffAccounts({
    required String farmName,
    required List<FarmUser> staff,
  }) async {
    final doc = _doc(
      title: 'Staff & User Accounts',
      farmName: farmName,
      body: [
        pw.Text(
          'Default passwords: Workers ${AppConstants.defaultWorkerPassword} · Admins ${AppConstants.defaultAdminPassword}',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 12),
        _table(
          headers: const ['Name', 'Email', 'Role', 'Created', 'Default pwd'],
          rows: staff
              .map((u) => [
                    u.name,
                    u.email,
                    u.role == UserRole.owner || u.role == UserRole.manager ? 'Supervisor' : 'Worker',
                    _dateFmt.format(u.createdAt),
                    u.role == UserRole.owner
                        ? '(owner set)'
                        : AppConstants.defaultPasswordForRole(u.role),
                  ])
              .toList(),
        ),
      ],
    );
    await sharePdf(doc, 'roots_staff_accounts.pdf');
  }

  Future<void> farmPerformance({
    required String farmName,
    required String csvBody,
  }) async {
    final lines = csvBody.split('\n').where((l) => l.trim().isNotEmpty).toList();
    final doc = _doc(
      title: 'Farm Performance Report',
      farmName: farmName,
      body: lines.map((line) {
        if (line.contains(',') && !line.startsWith('Roots')) {
          final cells = _parseCsvLine(line);
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Text(cells.join(' · '), style: const pw.TextStyle(fontSize: 10)),
          );
        }
        return pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Text(line, style: line == lines.first ? _bold : const pw.TextStyle(fontSize: 11)),
        );
      }).toList(),
    );
    await sharePdf(doc, 'roots_farm_performance.pdf');
  }

  List<String> _parseCsvLine(String line) {
    final out = <String>[];
    var cur = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        inQuotes = !inQuotes;
      } else if (c == ',' && !inQuotes) {
        out.add(cur.toString());
        cur = StringBuffer();
      } else {
        cur.write(c);
      }
    }
    out.add(cur.toString());
    return out;
  }

  pw.Document _doc({
    required String title,
    required String farmName,
    required List<pw.Widget> body,
  }) {
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(AppConstants.appName, style: pw.TextStyle(fontSize: 11, color: PdfColors.green800)),
                pw.Text(_dateTimeFmt.format(DateTime.now()), style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Text(farmName, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
            pw.Divider(color: PdfColors.green800, thickness: 1),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (ctx) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 9)),
        ),
        build: (ctx) => body,
      ),
    );
    return doc;
  }

  pw.Widget _section(String title) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Text(title, style: _bold),
      );

  pw.Widget _kvTable(List<List<String>> rows) => pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
        columnWidths: {0: const pw.FlexColumnWidth(2), 1: const pw.FlexColumnWidth(3)},
        children: rows
            .map(
              (r) => pw.TableRow(
                children: [
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(r[0], style: _bold)),
                  pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(r[1])),
                ],
              ),
            )
            .toList(),
      );

  pw.Widget _table({required List<String> headers, required List<List<String>> rows}) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.green50),
          children: headers
              .map((h) => pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(h, style: _bold),
                  ))
              .toList(),
        ),
        ...rows.map(
          (row) => pw.TableRow(
            children: row
                .map((c) => pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(c, style: const pw.TextStyle(fontSize: 9)),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  static final _bold = pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11);
}
