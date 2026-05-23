import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../../../shared/widgets/toast_helper.dart';
import '../services/holiday_service.dart';

class HolidayBulkUploadHelper {
  // 1. Pick and Upload Logic
  static Future<void> pickAndUpload(
    BuildContext context,
    HolidayService service,
    VoidCallback onSuccess,
  ) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'csv', 'xlsx'],
        withData: true, // Need data for parsing
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      List<Map<String, dynamic>> holidays = [];

      // Determine Type and Parse
      final ext = file.extension?.toLowerCase();

      if (ext == 'json') {
        holidays = _parseJson(file);
      } else if (ext == 'csv') {
        holidays = _parseCsv(file);
      } else if (ext == 'xlsx') {
        holidays = _parseExcel(file);
      } else {
        throw Exception("Unsupported file format: .$ext");
      }

      if (holidays.isEmpty) {
        throw Exception("No valid holidays found in file.");
      }

      // Upload
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const Center(child: CircularProgressIndicator()),
        );
      }

      // Artificial delay for UX if file is small (optional, skipped for now)

      try {
        await service.addBulkHolidays(holidays);
      } catch (e) {
        // Rethrow to catch below
        rethrow;
      }

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Dismiss loading
        context.showToast(
          "${holidays.length} holidays added successfully.",
          isSuccess: true,
        );
        onSuccess();
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).maybePop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Upload Failed: $e"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // 2. Parsers
  static List<Map<String, dynamic>> _parseJson(PlatformFile file) {
    String jsonString;
    if (file.bytes != null) {
      jsonString = utf8.decode(file.bytes!);
    } else {
      throw Exception("File content is empty or unreadable.");
    }

    final dynamic decoded = jsonDecode(jsonString);
    if (decoded is List) {
      return List<Map<String, dynamic>>.from(decoded);
    } else if (decoded is Map && decoded.containsKey('holidays')) {
      return List<Map<String, dynamic>>.from(decoded['holidays']);
    }
    throw Exception("Invalid JSON format.");
  }

  static List<Map<String, dynamic>> _parseCsv(PlatformFile file) {
    if (file.bytes == null) throw Exception("Cannot read CSV file content.");
    final csvString = utf8.decode(file.bytes!);
    final List<List<dynamic>> rows = const CsvToListConverter().convert(
      csvString,
      eol: '\n',
    );

    if (rows.length < 2)
      throw Exception("CSV file must have a header and at least one row.");

    // Simple Header Mapping
    final headers = rows.first
        .map((e) => e.toString().trim().toLowerCase())
        .toList();
    final nameIdx = headers.indexOf('holiday_name');
    final dateIdx = headers.indexOf('holiday_date');
    final typeIdx = headers.indexOf('holiday_type');

    if (nameIdx == -1 || dateIdx == -1) {
      throw Exception("Missing required columns: holiday_name, holiday_date");
    }

    List<Map<String, dynamic>> holidays = [];
    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length <= dateIdx || row.length <= nameIdx)
        continue; // Skip bad rows

      holidays.add({
        'holiday_name': row[nameIdx],
        'holiday_date': row[dateIdx], // Assume correct format 2024-01-01
        'holiday_type': (typeIdx != -1 && row.length > typeIdx)
            ? row[typeIdx]
            : 'Public',
      });
    }
    return holidays;
  }

  static List<Map<String, dynamic>> _parseExcel(PlatformFile file) {
    if (file.bytes == null) throw Exception("Cannot read Excel file content.");
    final excel = Excel.decodeBytes(file.bytes!);

    // Check first sheet
    final sheetName = excel.tables.keys.first;
    final sheet = excel.tables[sheetName];
    if (sheet == null) throw Exception("Excel file is empty.");

    // Assuming Row 1 is header
    if (sheet.maxRows < 2)
      throw Exception("Excel file must have headers and data.");

    // Find headers in first row
    final headerRow = sheet.rows.first;
    final headers = headerRow
        .map((cell) => cell?.value.toString().trim().toLowerCase() ?? "")
        .toList();

    final nameIdx = headers.indexOf('holiday_name');
    final dateIdx = headers.indexOf('holiday_date');
    final typeIdx = headers.indexOf('holiday_type');

    if (nameIdx == -1 || dateIdx == -1) {
      throw Exception("Missing required columns: holiday_name, holiday_date");
    }

    List<Map<String, dynamic>> holidays = [];
    // Start from index 1 (row 2)
    for (int i = 1; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      if (row.length <= nameIdx || row.length <= dateIdx) continue;

      final nameVal = row[nameIdx]?.value;
      final dateVal = row[dateIdx]?.value;
      final typeVal = (typeIdx != -1 && row.length > typeIdx)
          ? row[typeIdx]?.value
          : 'Public';

      if (nameVal == null || dateVal == null) continue;

      // Date Handling: Excel might give Date, Int, or String
      String dateStr = dateVal.toString();
      // If it's pure cell value which might be DateTime object if parsed or just string
      // The excel package returns CellValue, .value gives underlying.
      // For simplicity, we trust user entered formatted string YYYY-MM-DD or we cast.
      // Actually, if it's Excel Date, it might need conversion. But likely user inputs string.
      // Let's assume standard string for now as safer baseline.

      holidays.add({
        'holiday_name': nameVal.toString(),
        'holiday_date': dateStr,
        'holiday_type': typeVal?.toString() ?? 'Public',
      });
    }
    return holidays;
  }

  // 3. Download Template
  static Future<void> downloadTemplate(BuildContext context) async {
    try {
      // Create Excel
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Sheet1']; // default sheet

      // Headers
      List<String> headers = ['holiday_name', 'holiday_date', 'holiday_type'];
      sheetObject.appendRow(headers.map((e) => TextCellValue(e)).toList());

      // Dummy Data
      sheetObject.appendRow([
        TextCellValue('New Year'),
        TextCellValue('2024-01-01'),
        TextCellValue('Public'),
      ]);
      sheetObject.appendRow([
        TextCellValue('Good Friday'),
        TextCellValue('2024-03-29'),
        TextCellValue('Optional'),
      ]);

      // Save
      final fileBytes = excel.save();
      if (fileBytes == null) throw Exception("Failed to generate excel file");

      if (kIsWeb) {
        // Web handling would be different (FileSaver), but focusing on Mobile/Desktop checks env
        throw Exception("Web download not implemented yet");
      } else {
        // Mobile/Desktop
        final directory =
            await getApplicationDocumentsDirectory(); // Use generic docs or temp
        // Ideally getExternalStorage for Android user visibility, but open_filex works with app dirs too usually
        // Actually, for user to "see" it outside, External might be needed on Android.
        // Let's use temporary for "viewing" immediately.

        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/holiday_template.xlsx';
        final file = File(path);
        await file.writeAsBytes(fileBytes);

        // Open it
        final result = await OpenFilex.open(path);
        if (result.type != ResultType.done) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "File saved at $path but could not open: ${result.message}",
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Template Error: $e")));
    }
  }
}
