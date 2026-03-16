import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:csv/csv.dart';
import '../models/concern.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';


class ReportService {
  Future<void> generateAndPrintReport(List<Concern> concerns, {String? category, String? department}) async {
    final pdf = pw.Document();
    final now = DateTime.now();


    var filtered = concerns;
    if (category != null) filtered = filtered.where((c) => c.category.name == category).toList();
    if (department != null) filtered = filtered.where((c) => c.assignedTo == department).toList();


    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('ConcernTrack Status Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.Text(DateFormat('yyyy-MM-dd').format(now)),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            if (category != null || department != null)
              pw.Text('Filters: ${category ?? "All Categories"} | ${department ?? "All Departments"}'),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: ['Title', 'Category', 'Status', 'Date', 'Dept'],
              data: filtered.map((c) => [
                c.title,
                c.category.name.toUpperCase(),
                c.status.name.toUpperCase(),
                DateFormat('MM/dd').format(c.createdAt),
                c.assignedTo ?? 'N/A',
              ]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            ),
            pw.SizedBox(height: 40),
            pw.Text('Summary Statistics', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            pw.Bullet(text: 'Total Concerns in Report: ${filtered.length}'),
            pw.Bullet(text: 'Resolved: ${filtered.where((c) => c.status == ConcernStatus.resolved).length}'),
            pw.Bullet(text: 'Escalated: ${filtered.where((c) => c.status == ConcernStatus.escalated).length}'),
          ];
        },
      ),
    );


    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'ConcernTrack_Report_${DateFormat('yyyyMMdd').format(now)}.pdf',
    );
  }


  Future<void> exportToCSV(List<Concern> concerns) async {
    List<List<dynamic>> rows = [];
    rows.add([
      "ID", "Title", "Description", "Category", "Status",
      "Created At", "Last Updated", "Is Anonymous", "Student ID",
      "Program", "Assigned To"
    ]);


    for (var c in concerns) {
      rows.add([
        c.id,
        c.title,
        c.description,
        c.category.name,
        c.status.name,
        c.createdAt.toIso8601String(),
        c.lastUpdatedAt?.toIso8601String() ?? "",
        c.isAnonymous,
        c.studentId,
        c.program,
        c.assignedTo ?? ""
      ]);
    }


    String csvData = const ListToCsvConverter().convert(rows);
    debugPrint('CSV Export Triggered. Data length: ${csvData.length}');
    // In a production app, you would use file_saver or anchor element for web downloads.
  }
}

