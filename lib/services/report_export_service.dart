import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:guidex/models/final_report_response.dart';

class ReportExportService {
  /// Generates and shares a PDF report matching the premium UI
  static Future<void> exportToPDF({
    required String studentName,
    required double studentCutoff,
    required String category,
    required String preferredCourse,
    required List<dynamic> safeColleges,
    required List<TargetCollegeResponse> targetColleges,
    required List<dynamic> dreamColleges,
  }) async {
    final pdf = pw.Document();

    // Load logo if possible (using splash image as fallback)
    pw.MemoryImage? logoImage;
    try {
      final logoData = await rootBundle.load('assets/image/splash.png');
      logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (_) {}

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(0), // Full bleed for background
        header: (context) => pw.Container(),
        footer: (context) => pw.Container(
          height: 30,
          padding: const pw.EdgeInsets.symmetric(horizontal: 32),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Generated: ${DateTime.now().toString().substring(0, 10)}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              pw.Text('NeXtep | Smart College Guidance', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              pw.Text('Page ${context.pageNumber} / ${context.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            ],
          ),
        ),
        build: (pw.Context context) {
          return [
            pw.Stack(
              children: [
                // Background Color
                pw.Container(
                  color: PdfColor.fromHex('#F3F6FF'),
                  constraints: pw.BoxConstraints(minHeight: PdfPageFormat.a4.height),
                ),
                
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 32, vertical: 32),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Header Card
                      pw.Container(
                        padding: const pw.EdgeInsets.all(20),
                        decoration: pw.BoxDecoration(
                          color: PdfColor.fromHex('#1A73E8'),
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                        ),
                        child: pw.Row(
                          children: [
                            if (logoImage != null)
                              pw.Container(
                                width: 40,
                                height: 40,
                                margin: const pw.EdgeInsets.only(right: 15),
                                child: pw.Image(logoImage),
                              ),
                            pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text('College Analysis Report',
                                    style: pw.TextStyle(color: PdfColors.white, fontSize: 24, fontWeight: pw.FontWeight.bold)),
                                pw.Text('Based on your cutoff and preferences',
                                    style: const pw.TextStyle(color: PdfColors.white, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 24),

                      // Student Summary Section
                      _buildSectionTitle('Student Summary', PdfColors.blue700),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(16),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                          boxShadow: [
                            const pw.BoxShadow(color: PdfColors.grey300, blurRadius: 4, offset: PdfPoint(0, 2)),
                          ],
                        ),
                        child: pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Expanded(
                              flex: 2,
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  _buildInfoItem('Name', studentName),
                                  pw.SizedBox(height: 12),
                                  _buildInfoItem('Selected Course', preferredCourse),
                                ],
                              ),
                            ),
                            pw.Expanded(
                              flex: 1,
                              child: pw.Container(
                                padding: const pw.EdgeInsets.all(12),
                                decoration: pw.BoxDecoration(
                                  color: PdfColor.fromHex('#E8F0FE'),
                                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                                ),
                                child: pw.Column(
                                  children: [
                                    pw.Text('Cutoff', style: const pw.TextStyle(fontSize: 10, color: PdfColors.blue800)),
                                    pw.Text(studentCutoff.toString(),
                                        style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1A73E8'))),
                                    pw.Text(category.toUpperCase(), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 24),

                      // Overall Insight
                      _buildSectionTitle('Overall Insight', PdfColors.blue700),
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.all(16),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.white,
                          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                        ),
                        child: pw.Row(
                          children: [
                            pw.Text('${targetColleges.length + safeColleges.length + dreamColleges.length}',
                                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#1A73E8'))),
                            pw.SizedBox(width: 10),
                            pw.Text('Total Matching Colleges', style: const pw.TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 24),

                      // Sections for Dream, Target, Safe
                      if (dreamColleges.isNotEmpty) ...[
                        _buildTypeHeader('Dream Colleges', 'Ambitious choices with lower probability', PdfColors.red),
                        _buildCollegeGrid(dreamColleges),
                        pw.SizedBox(height: 24),
                      ],

                      if (targetColleges.isNotEmpty) ...[
                        _buildTypeHeader('Target Colleges', 'Strong probability of admission', PdfColors.orange),
                        _buildCollegeGrid(targetColleges),
                        pw.SizedBox(height: 24),
                      ],

                      if (safeColleges.isNotEmpty) ...[
                        _buildTypeHeader('Safe Colleges', 'High probability based on history', PdfColors.green),
                        _buildCollegeGrid(safeColleges),
                        pw.SizedBox(height: 24),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: '${studentName}_NeXtep_Report.pdf');
  }

  static pw.Widget _buildSectionTitle(String title, PdfColor color) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        children: [
          pw.Icon(const pw.IconData(0xe873), color: color, size: 12),
          pw.SizedBox(width: 6),
          pw.Text(title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
        ],
      ),
    );
  }

  static pw.Widget _buildInfoItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        pw.Text(value, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
      ],
    );
  }

  static pw.Widget _buildTypeHeader(String title, String subtitle, PdfColor color) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          height: 2,
          color: color,
        ),
        pw.SizedBox(height: 8),
        pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: color)),
        pw.Text(subtitle, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        pw.SizedBox(height: 12),
      ],
    );
  }

  static pw.Widget _buildCollegeGrid(List<dynamic> colleges) {
    return pw.Wrap(
      spacing: 12,
      runSpacing: 12,
      children: colleges.map((college) {
        final String name = college is TargetCollegeResponse ? college.collegeName : (college.collegeName ?? '');
        final String course = college is TargetCollegeResponse ? college.course : (college.courseName ?? '');
        final double cutoffValue = college is TargetCollegeResponse ? college.cutoff : (college.ocCutoff ?? 0.0);
        final double score = college is TargetCollegeResponse ? college.scorePercentage : (college.probability ?? 0.0);

        return pw.Container(
          width: 250, // Approximately half width minus spacing
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.white,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            border: pw.Border.all(color: PdfColors.grey200, width: 0.5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(name, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold), maxLines: 2),
              pw.SizedBox(height: 4),
              pw.Text(course, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Cutoff: $cutoffValue', style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: pw.BoxDecoration(
                      color: score > 75 ? PdfColors.green100 : PdfColors.orange100,
                      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Text('${score.toStringAsFixed(1)}%', 
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: score > 75 ? PdfColors.green800 : PdfColors.orange800)),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Captures a GlobalKey and shares it as a PNG image
  static Future<void> exportToPNG({
    required GlobalKey boundaryKey,
    required String fileName,
  }) async {
    try {
      RenderRepaintBoundary? boundary =
          boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      
      if (boundary == null) return;

      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        Uint8List pngBytes = byteData.buffer.asUint8List();
        
        // Share PNG directly using printing package
        await Printing.sharePdf(
          bytes: await _convertImageToPdf(pngBytes),
          filename: '$fileName.pdf',
        );
      }
    } catch (e) {
      debugPrint('Error exporting PNG: $e');
    }
  }

  static Future<Uint8List> _convertImageToPdf(Uint8List imageBytes) async {
    final pdf = pw.Document();
    final image = pw.MemoryImage(imageBytes);
    pdf.addPage(pw.Page(
      build: (pw.Context context) => pw.Center(child: pw.Image(image)),
    ));
    return pdf.save();
  }
}
