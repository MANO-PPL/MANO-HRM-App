import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import '../../../shared/constants/api_constants.dart';
import '../models/report_history_model.dart';

class ReportService {
  final Dio _dio;
  static const String _historyKey = 'report_download_history';

  ReportService(this._dio);

  // 1. Get Report Preview (JSON Data from Backend)
  Future<Map<String, dynamic>> getPreview({
    required String type,
    String? month, // "YYYY-MM"
    String? date,  // "YYYY-MM-DD"
  }) async {
    try {
      final query = {
        'type': type,
        if (month != null) 'month': month,
        if (date != null) 'date': date,
      };

      final response = await _dio.get(ApiConstants.reportsPreview, queryParameters: query);
      
      if (response.statusCode == 200 && response.data['ok']) {
        return response.data['data']; 
      }
      return {'columns': [], 'rows': []};
    } catch (e) {
      debugPrint("API Error: $e. Using Mock Data for Preview.");
      return {
        'columns': ['DATE', 'EMPLOYEE', 'SHIFT', 'HOURS', 'STATUS'],
        'rows': [
          ['2023-10-24', 'MOCK DATA', '09:00 - 18:00', '9h 00m', 'Present'],
        ]
      };
    }
  }

  // 2. Export Report (Client-Side Generation)
  Future<String?> exportReport({
    required String type,
    required String format, // "xlsx", "csv", "pdf"
    String? month,
    String? date,
  }) async {
    try {
      // Step A: Fetch Data
      final data = await getPreview(type: type, month: month, date: date);
      
      if (data['columns'] == null || (data['columns'] as List).isEmpty) {
        throw Exception("No data available to export.");
      }

      final columns = List<String>.from(data['columns']);
      final rows = (data['rows'] as List).map((e) => List<dynamic>.from(e)).toList();

      // Step B: Generate File
      String? savePath;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = "Report_${type}_$timestamp.$format";

      if (format == 'xlsx') {
        savePath = await _generateExcel(fileName, columns, rows);
      } else if (format == 'pdf') {
        savePath = await _generatePdf(fileName, type, columns, rows);
      } else if (format == 'csv') {
        savePath = await _generateCsv(fileName, columns, rows);
      } else {
        throw Exception("Unsupported format: $format");
      }

      // Step C: Save History
      await _saveHistory(fileName, savePath, type);

      return savePath;
    } catch (e) {
      debugPrint("Export Failed: $e");
      rethrow;
    }
  }

  // --- File Generators ---

  Future<String> _generateExcel(String fileName, List<String> columns, List<List<dynamic>> rows) async {
    var excel = Excel.createExcel();
    Sheet sheet = excel['Sheet1'];

    // Add Header
    sheet.appendRow(columns.map((c) => TextCellValue(c)).toList());

    // Add Rows
    for (var row in rows) {
      sheet.appendRow(row.map((cell) => TextCellValue(cell?.toString() ?? '-')).toList());
    }

    final bytes = excel.save();
    if (bytes == null) throw Exception("Failed to encode Excel file");

    final path = await _getSavePath(fileName);
    final file = File(path);
    await file.writeAsBytes(bytes);
    return path;
  }

  Future<String> _generateCsv(String fileName, List<String> columns, List<List<dynamic>> rows) async {
    List<List<dynamic>> csvData = [
      columns,
      ...rows
    ];

    String csv = const ListToCsvConverter().convert(csvData);
    
    final path = await _getSavePath(fileName);
    final file = File(path);
    await file.writeAsString(csv);
    return path;
  }

  Future<String> _generatePdf(String fileName, String title, List<String> columns, List<List<dynamic>> rows) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text("Attendance Report - $title", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: columns,
              data: rows.map((row) => row.map((e) => e?.toString() ?? '-').toList()).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          ];
        },
      ),
    );

    final path = await _getSavePath(fileName);
    final file = File(path);
    await file.writeAsBytes(await pdf.save());
    return path;
  }

  Future<String> _getSavePath(String fileName) async {
    Directory? dir;
    if (Platform.isAndroid) {
      dir = await getExternalStorageDirectory(); // Internal Storage/Android/data/...
      // Or getDownloadsDirectory if available/scoped storage permits. 
      // ExternalStorageDirectory is safest for app-specific files.
    } else {
      dir = await getApplicationDocumentsDirectory();
    }
    
    if (dir == null) throw Exception("Storage directory not found");
    return "${dir.path}/$fileName";
  }

  // --- History Management (Local) ---

  Future<void> _saveHistory(String fileName, String path, String type) async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList(_historyKey) ?? [];

    final newRecord = ReportHistory(
      fileName: fileName, 
      path: path, 
      timestamp: DateFormat('MMM dd, hh:mm a').format(DateTime.now()), 
      type: type
    );

    historyJson.insert(0, jsonEncode(newRecord.toJson())); // Add to top
    
    // Limit to 50 items
    if (historyJson.length > 50) {
      historyJson.removeLast();
    }

    await prefs.setStringList(_historyKey, historyJson);
  }

  Future<List<ReportHistory>> getDownloadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList(_historyKey) ?? [];

    return historyJson.map((e) {
      try {
        return ReportHistory.fromJson(jsonDecode(e));
      } catch (_) {
        return null;
      }
    }).whereType<ReportHistory>().toList();
  }
}
