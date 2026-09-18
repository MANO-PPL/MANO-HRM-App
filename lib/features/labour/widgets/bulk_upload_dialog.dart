import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_application/features/labour/core/labour_models.dart';
import 'package:flutter_application/features/labour/core/labour_service.dart';
import 'package:flutter_application/features/labour/widgets/labour_common_widgets.dart';

class BulkUploadDialog extends StatefulWidget {
  final LabourService labourService;
  final VoidCallback onSuccess;
  final bool isBottomSheet;

  const BulkUploadDialog({
    super.key,
    required this.labourService,
    required this.onSuccess,
    this.isBottomSheet = false,
  });

  @override
  State<BulkUploadDialog> createState() => _BulkUploadDialogState();
}

class _BulkUploadDialogState extends State<BulkUploadDialog> {
  bool _isParsing = false;
  bool _isSaving = false;
  bool _isDownloading = false;
  String? _parseError;
  String? _selectedFileName;
  List<ParsedLabourRow> _parsedRows = [];

  Future<void> _pickAndParseFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'csv', 'xls'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        setState(() => _parseError = "Failed to read file bytes. Please try another file.");
        return;
      }

      setState(() {
        _isParsing = true;
        _parseError = null;
        _selectedFileName = file.name;
        _parsedRows = [];
      });

      final rows = await widget.labourService.parseBulkLabours(
        fileBytes: bytes,
        filename: file.name,
      );

      if (mounted) {
        setState(() {
          _parsedRows = rows;
          _isParsing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _parseError = e.toString().replaceAll('Exception: ', '');
          _isParsing = false;
        });
      }
    }
  }

  Future<void> _downloadTemplate() async {
    setState(() => _isDownloading = true);
    try {
      final bytes = await widget.labourService.downloadBulkTemplate();
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/labour_bulk_upload_template.xlsx';
      final f = File(filePath);
      await f.writeAsBytes(bytes);
      await OpenFilex.open(filePath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Template downloaded successfully")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to download template: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _saveValidLabours() async {
    final valid = _parsedRows.where((r) => r.isValid).map((r) => r.toCreatePayload()).toList();
    if (valid.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      await widget.labourService.bulkCreateLabours(valid);
      if (mounted) {
        widget.onSuccess();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final validCount = _parsedRows.where((r) => r.isValid).length;
    final errorCount = _parsedRows.length - validCount;

    final bodyContent = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.upload_file_rounded, color: Color(0xFF6366F1), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Bulk Import Workers from Excel / CSV",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              "Upload worker directory sheet and validate entries before import",
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.close, size: 18, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Upload Box & Template Bar
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _isParsing ? null : _pickAndParseFile,
                    icon: _isParsing
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.file_upload_outlined, color: Colors.white, size: 18),
                    label: Text(
                      _selectedFileName ?? "Choose Excel / CSV File",
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    side: BorderSide(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
                  ),
                  onPressed: _isDownloading ? null : _downloadTemplate,
                  icon: _isDownloading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.download_rounded, size: 18, color: Color(0xFF6366F1)),
                  label: Text(
                    "Download Template",
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF6366F1)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Parse Error
            if (_parseError != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 16, color: Color(0xFFEF4444)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _parseError!,
                        style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFFEF4444)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Validation Summary Pills
            if (_parsedRows.isNotEmpty) ...[
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      "$validCount Valid Rows",
                      style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF10B981)),
                    ),
                  ),
                  if (errorCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "$errorCount Invalid Rows (Skipped)",
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFEF4444)),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    "Total Parsed: ${_parsedRows.length}",
                    style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],

            // Parsed Rows Table Preview
            Expanded(
              child: _parsedRows.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.table_view_rounded, size: 44, color: Colors.grey[500]),
                          const SizedBox(height: 10),
                          Text(
                            "Select a file above to parse and preview rows before importing",
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _parsedRows.length,
                      itemBuilder: (context, i) {
                        final r = _parsedRows[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: r.isValid
                                  ? (isDark ? const Color(0xFF21262D) : const Color(0xFFE2E8F0))
                                  : const Color(0xFFEF4444).withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: r.isValid
                                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                      : const Color(0xFFEF4444).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  r.isValid ? "VALID" : "ERROR",
                                  style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: r.isValid ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      r.name.isNotEmpty ? r.name : "(Empty Name)",
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    if (!r.isValid)
                                      Text(
                                        r.error,
                                        style: GoogleFonts.poppins(fontSize: 10, color: const Color(0xFFEF4444)),
                                      )
                                    else
                                      Text(
                                        "Phone: ${r.phone.isNotEmpty ? r.phone : 'None'} • Site: ${r.siteName.isNotEmpty ? r.siteName : 'Unassigned'}",
                                        style: GoogleFonts.poppins(fontSize: 10, color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B)),
                                      ),
                                  ],
                                ),
                              ),
                              SkillBadge(skill: r.role),
                              const SizedBox(width: 8),
                              Text(
                                "₹${r.monthlySalary}/day",
                                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF10B981)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 14),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: (validCount == 0 || _isSaving) ? null : _saveValidLabours,
                  icon: _isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                  label: Text(
                    "Import $validCount Valid Workers",
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
    );

    if (widget.isBottomSheet) {
      return Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161B22) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          border: Border(
            top: BorderSide(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Flexible(
              child: bodyContent,
            ),
          ],
        ),
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 780,
        height: 620,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161B22) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: bodyContent,
      ),
    );
  }
}

// [upd:2026-04-13T14:00:00+05:30]
