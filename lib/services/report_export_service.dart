import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:guidex/models/final_report_response.dart';

class ReportExportService {
  /// Generates and shares a PDF report
  static Future<void> exportToPDF({
    required String studentName,
    required double studentCutoff,
    required String category,
    required String preferredCourse,
    required List<dynamic> safeColleges,
    required List<TargetCollegeResponse> targetColleges,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('NeXtep - Final College Report',
                      style: pw.TextStyle(
                          fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.Text(DateTime.now().toString().substring(0, 10)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Student Info
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Student Profile',
                      style: pw.TextStyle(
                          fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    children: [
                      pw.Expanded(child: pw.Text('Name: $studentName')),
                      pw.Expanded(child: pw.Text('Cutoff: $studentCutoff')),
                    ],
                  ),
                  pw.Row(
                    children: [
                      pw.Expanded(child: pw.Text('Category: ${category.toUpperCase()}')),
                      pw.Expanded(child: pw.Text('Course: $preferredCourse')),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // Preferred Colleges Section
            pw.Text('Preferred Colleges Analysis',
                style: pw.TextStyle(
                    fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue700)),
            pw.Divider(color: PdfColors.blue700),
            pw.SizedBox(height: 8),
            ...safeColleges.map((college) {
              final String name = college is TargetCollegeResponse ? college.collegeName : (college.collegeName ?? '');
              final String course = college is TargetCollegeResponse ? college.course : (college.courseName ?? '');
              final double prob = college is TargetCollegeResponse ? college.scorePercentage : (college.probability ?? 0.0);
              
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.Text(course, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        ],
                      ),
                    ),
                    pw.Text('${prob.toStringAsFixed(1)}%',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: prob >= 75 ? PdfColors.green700 : PdfColors.orange700)),
                  ],
                ),
              );
            }).toList(),
            
            if (safeColleges.isEmpty) pw.Text('No preferred colleges selected.'),
            pw.SizedBox(height: 32),

            // Target Colleges Section
            pw.Text('Recommended Target Colleges',
                style: pw.TextStyle(
                    fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.orange700)),
            pw.Divider(color: PdfColors.orange700),
            pw.SizedBox(height: 8),
            ...targetColleges.map((college) {
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 12),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Expanded(
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(college.collegeName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                          pw.Text(college.course, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        ],
                      ),
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('${college.scorePercentage}%', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text(college.chanceLabel, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
            
            if (targetColleges.isEmpty) pw.Text('No target colleges found in the 55-85% range.'),
            
            pw.SizedBox(height: 40),
            pw.Footer(
              margin: const pw.EdgeInsets.only(top: 20),
              trailing: pw.Text('Generated by NeXtep App', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500)),
            ),
          ];
        },
      ),
    );

    // Share/Print the PDF
    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: '${studentName}_Final_Report.pdf');
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
        
        // Use printing package to share the image bytes as a PDF container or directly
        // For simplicity and compatibility, we'll share it as a document
        final doc = pw.Document();
        final pwImage = pw.MemoryImage(pngBytes);
        
        doc.addPage(pw.Page(
          build: (pw.Context context) {
            return pw.Center(child: pw.Image(pwImage));
          },
        ));

        await Printing.sharePdf(bytes: await doc.save(), filename: '$fileName.pdf');
        // Note: Sharing as raw PNG is also possible but requires path_provider + share_plus
        // Using printing to share an image-only PDF is a robust fallback.
      }
    } catch (e) {
      debugPrint('Error exporting PNG: $e');
    }
  }
}
