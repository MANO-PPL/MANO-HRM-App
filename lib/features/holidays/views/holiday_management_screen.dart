import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'dart:io';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/custom_dialog.dart';
import '../../../../shared/widgets/toast_helper.dart';
import '../../../../shared/services/auth_service.dart';
import 'package:provider/provider.dart';
import '../services/holiday_service.dart';
import '../models/holiday_model.dart';
// Import the new widget
import '../widgets/holiday_form_dialog.dart';

class HolidayManagementScreen extends StatefulWidget {
  final HolidayService holidayService;
  const HolidayManagementScreen({super.key, required this.holidayService});

  @override
  _HolidayManagementScreenState createState() =>
      _HolidayManagementScreenState();
}

class _HolidayManagementScreenState extends State<HolidayManagementScreen> {
  List<Holiday> _holidays = [];
  List<Holiday> _filteredHolidays = [];
  bool _isLoading = false;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchHolidays();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredHolidays = _holidays.where((h) {
        return h.name.toLowerCase().contains(query) ||
            h.date.contains(query) ||
            h.type.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _fetchHolidays() async {
    setState(() => _isLoading = true);
    try {
      final data = await widget.holidayService.getHolidays();
      setState(() {
        // Ensure data is not null
        _holidays = data;
        _filteredHolidays = data;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error fetching holidays: $e")));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteHoliday(int id) async {
    try {
      await widget.holidayService.deleteHolidays([id]);
      _fetchHolidays();
      if (mounted) {
        context.showToast("Holiday deleted successfully.", isSuccess: true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Delete failed: $e")));
      }
    }
  }

  void _showAddDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => HolidayFormDialog(
        onSubmit: (data) async {
          try {
            await widget.holidayService.addHoliday(data);
            if (!ctx.mounted) return;
            Navigator.pop(ctx);
            _fetchHolidays();
            if (mounted) {
              context.showToast("Holiday added successfully.", isSuccess: true);
            }
          } catch (e) {
            if (mounted)
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text("Error: $e")));
          }
        },
      ),
    );
  }

  void _showEditDialog(Holiday holiday) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => HolidayFormDialog(
        initialData: holiday,
        onSubmit: (data) async {
          try {
            await widget.holidayService.updateHoliday(holiday.id, data);
            if (!ctx.mounted) return;
            Navigator.pop(ctx);
            _fetchHolidays();
            if (mounted) {
              context.showToast(
                "Holiday updated successfully.",
                isSuccess: true,
              );
            }
          } catch (e) {
            if (mounted)
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text("Error: $e")));
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Background handling manually if not handled by parent layout
    // But usually this screen is nested. We'll assume the background is already consistent
    // (Dark gradient or Light grey). If it's pure transparent, the list might be hard to read
    // without a container, but the design shows a container.

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // 1. Header (Search + Actions)
            _buildHeader(context, isDark),
            const SizedBox(height: 20),

            // 2. Main Content (Table)
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredHolidays.isEmpty
                  ? Center(
                      child: Text(
                        "No holidays found",
                        style: GoogleFonts.poppins(color: Colors.grey),
                      ),
                    )
                  : _buildHolidayTable(context, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    // Layout:
    // [Search Bar (Expanded)]  [Import CSV]  [+ Add Holiday]
    // On Mobile: Search bar on one row, buttons on next? Or compressed.

    final isAdmin =
        Provider.of<AuthService>(context, listen: false).user?.isAdmin ?? false;

    final isMobile = MediaQuery.of(context).size.width < 600;

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSearchField(context, isDark),
          const SizedBox(height: 12),
          if (isAdmin)
            Row(
              children: [
                Expanded(child: _buildImportButton(context, isDark)),
                const SizedBox(width: 12),
                Expanded(child: _buildAddButton(context)),
              ],
            ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: _buildSearchField(context, isDark)),
        if (isAdmin) ...[
          const SizedBox(width: 16),
          _buildImportButton(context, isDark),
          const SizedBox(width: 12),
          _buildAddButton(context),
        ],
      ],
    );
  }

  Widget _buildSearchField(BuildContext context, bool isDark) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withAlpha(12) : Colors.grey.shade300,
        ),
      ),
      child: TextField(
        controller: _searchCtrl,
        style: GoogleFonts.poppins(
          color: isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: 'Search holidays...',
          hintStyle: GoogleFonts.poppins(color: Colors.grey),
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 13,
          ), // Center vertically
        ),
      ),
    );
  }

  Widget _buildImportButton(BuildContext context, bool isDark) {
    return TextButton.icon(
      onPressed: _importCSV,
      icon: Icon(
        Icons.upload_file,
        size: 18,
        color: isDark ? Colors.white70 : Colors.black87,
      ),
      label: Text(
        "Import CSV",
        style: GoogleFonts.poppins(
          color: isDark ? Colors.white70 : Colors.black87,
          fontWeight: FontWeight.w500,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isDark ? Colors.white.withAlpha(12) : Colors.grey.shade300,
          ),
        ),
      ),
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _showAddDialog,
      icon: const Icon(Icons.add, size: 18, color: Colors.white),
      label: Text(
        "Holiday",
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF6366F1), // Indigo Primary
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    );
  }

  Widget _buildHolidayTable(BuildContext context, bool isDark) {
    // If Mobile (< 700), use ListView of Cards.
    // If Tablet/Desktop (>= 700), use Header Row + ListView of Rows.
    final isMobile = MediaQuery.of(context).size.width < 700;
    final isAdmin =
        Provider.of<AuthService>(context, listen: false).user?.isAdmin ?? false;

    return GlassContainer(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      color: isDark ? const Color(0xFF161B22) : Colors.white,
      border: isDark ? null : Border.all(color: Colors.grey.shade200),
      child: Column(
        children: [
          // Table Header
          if (!isMobile)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Expanded(flex: 3, child: _tableHeader("HOLIDAY NAME")),
                  Expanded(flex: 2, child: _tableHeader("DATE")),
                  Expanded(flex: 2, child: _tableHeader("TYPE")),
                  if (isAdmin)
                    SizedBox(
                      width: 80,
                      child: _tableHeader("ACTIONS", alignRight: true),
                    ),
                ],
              ),
            ),

          if (!isMobile) const Divider(height: 1, color: Colors.white12),

          Expanded(
            child: ListView.separated(
              itemCount: _filteredHolidays.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: isDark
                    ? Colors.white.withAlpha(12)
                    : Colors.grey.shade100,
              ),
              itemBuilder: (context, index) {
                final holiday = _filteredHolidays[index];
                if (isMobile) {
                  return _buildMobileCard(holiday, isDark);
                } else {
                  return _buildDesktopRow(holiday, isDark);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tableHeader(String text, {bool alignRight = false}) {
    return Text(
      text,
      textAlign: alignRight ? TextAlign.end : TextAlign.start,
      style: GoogleFonts.poppins(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Colors.grey,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildDesktopRow(Holiday holiday, bool isDark) {
    final isAdmin =
        Provider.of<AuthService>(context, listen: false).user?.isAdmin ?? false;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          // 1. Name
          Expanded(
            flex: 3,
            child: InkWell(
              // Make name clickable for edit
              onTap: !isAdmin ? null : () => _showEditDialog(holiday),
              child: Text(
                holiday.name,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),

          // 2. Date
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: isDark ? Colors.white70 : Colors.grey[500],
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDate(holiday.date),
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),

          // 3. Type
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _buildTypeChip(holiday.type),
            ),
          ),

          // 4. Actions
          if (isAdmin)
            SizedBox(
              width: 80,
              child: Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: Colors.grey,
                  ),
                  onPressed: () => _showDeleteConfirm(holiday.id),
                  tooltip: "Delete",
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileCard(Holiday holiday, bool isDark) {
    final isAdmin =
        Provider.of<AuthService>(context, listen: false).user?.isAdmin ?? false;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: InkWell(
        onTap: !isAdmin ? null : () => _showEditDialog(holiday),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    holiday.name,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                _buildTypeChip(holiday.type),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: isDark ? Colors.white70 : Colors.grey[500],
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDate(holiday.date),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: isDark ? Colors.white : Colors.grey[700],
                  ),
                ),
                const Spacer(),
                if (isAdmin)
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: Colors.grey,
                    ),
                    onPressed: () => _showDeleteConfirm(holiday.id),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String type) {
    // Colors based on type
    Color bgColor;
    Color textColor;

    switch (type.toLowerCase()) {
      case 'public':
        bgColor = const Color(0xFF6366F1).withValues(alpha: 0.1); // Indigo tint
        textColor = const Color(0xFF818CF8);
        break;
      case 'optional':
        bgColor = const Color(0xFFF59E0B).withValues(alpha: 0.1); // Amber tint
        textColor = const Color(0xFFFBBF24);
        break;
      default:
        bgColor = Colors.grey.withValues(alpha: 0.1);
        textColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        type,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return DateFormat('EEE, d MMM yyyy').format(dt);
    } catch (e) {
      return isoDate;
    }
  }

  void _showDeleteConfirm(int id) {
    CustomDialog.show(
      context: context,
      title: "Delete Holiday?",
      message: "Are you sure you want to delete this holiday?",
      positiveButtonText: "Delete",
      isDestructive: true,
      onPositivePressed: () {
        _deleteHoliday(id);
      },
      negativeButtonText: "Cancel",
      onNegativePressed: () {},
      icon: Icons.delete_outline,
      iconColor: Colors.red,
    );
  }

  Future<void> _importCSV() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final input = file.openRead();
        final fields = await input
            .transform(utf8.decoder)
            .transform(const CsvToListConverter())
            .toList();

        if (fields.isEmpty) return;

        // Expect contents: Name, Date, Type
        // Skip header if first row looks like header
        int startRow = 0;
        if (fields[0].isNotEmpty &&
            fields[0][0].toString().toLowerCase().contains('name')) {
          startRow = 1;
        }

        final List<Map<String, dynamic>> batch = [];
        for (int i = startRow; i < fields.length; i++) {
          final row = fields[i];
          if (row.length < 2) continue; // Skip invalid rows

          // Safe row access
          final name = row[0].toString();
          // Date Parsing: Try to handle YYYY-MM-DD
          final date = row[1].toString();
          final type = row.length > 2 ? row[2].toString() : 'Public';

          if (name.isNotEmpty && date.isNotEmpty) {
            batch.add({
              "holiday_name": name,
              "holiday_date": date,
              "holiday_type": type,
            });
          }
        }

        if (batch.isNotEmpty) {
          setState(() => _isLoading = true);
          await widget.holidayService.addBulkHolidays(batch);
          _fetchHolidays();
          if (mounted) {
            context.showToast(
              "Imported ${batch.length} holidays successfully.",
              isSuccess: true,
            );
          }
        } else {
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("No valid data found in CSV")),
            );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Import Failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
