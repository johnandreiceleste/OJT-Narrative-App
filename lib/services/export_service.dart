import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:universal_html/html.dart' as html;
import '../models/report.dart';

class ExportService {
  // Update this URL to match your backend server
  static const String backendUrl = 'http://localhost:3001';

  Future<String> exportReportsToDocx(List<Report> reports) async {
    try {
      // Convert reports to JSON
      final reportsJson = reports
          .map((report) => {
                'id': report.id,
                'userId': report.userId,
                'date': report.date.toIso8601String(),
                'title': report.title,
                'narrative': report.narrative,
                'imageUrl': report.imageUrl,
                'createdAt': report.createdAt.toIso8601String(),
                'updatedAt': report.updatedAt.toIso8601String(),
              })
          .toList();

      // Call backend API
      final response = await http.post(
        Uri.parse('$backendUrl/api/export-reports'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'reports': reportsJson}),
      );

      if (response.statusCode == 200) {
        // Create blob and trigger download
        final blob = html.Blob([response.bodyBytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final fileName =
            'OJT_Reports_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.docx';

        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', fileName)
          ..click();

        html.Url.revokeObjectUrl(url);

        return fileName;
      } else {
        throw Exception('Failed to generate DOCX: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error exporting reports: $e');
    }
  }

  // Helper method to download images for embedding in DOCX
  Future<Uint8List?> downloadImage(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      print('Error downloading image: $e');
    }
    return null;
  }
}
