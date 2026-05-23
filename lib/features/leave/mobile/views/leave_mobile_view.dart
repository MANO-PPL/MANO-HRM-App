import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/toast_helper.dart';
import '../../../../shared/services/auth_service.dart';
import 'package:flutter_application/features/leave/providers/leave_provider.dart';
import 'package:flutter_application/features/holidays/services/holiday_service.dart';
import 'package:flutter_application/features/leave/widgets/holiday_details_dialog.dart';
import 'package:flutter_application/features/leave/widgets/leave_history_item.dart';
import 'package:flutter_application/features/leave/widgets/leave_request_form.dart';
import 'package:flutter_application/features/leave/widgets/admin_leave_view.dart';
import 'package:flutter_application/features/holidays/widgets/holiday_form_dialog.dart'; // Import Form Dialog
import '../../../../shared/widgets/custom_dialog.dart';
import '../../../../features/holidays/models/holiday_model.dart'; // Import Holiday Model

class LeaveMobileView extends StatefulWidget {
  const LeaveMobileView({super.key});

  @override
  State<LeaveMobileView> createState() => _LeaveMobileViewState();
}

class _LeaveMobileViewState extends State<LeaveMobileView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late HolidayService _holidayService;

  bool _isLoadingHolidays = false;
  List<dynamic> _holidays = [];
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();

    // Check role safely in post frame callback or init
    // We defer tab controller init until we know the role,
    // but better to just use a higher length and hide one, or re-init.
    // Simpler: Check auth service directly here (it's synchronous for the user object usually)
    // But safely, we do it in post frame or just read it.

    final authService = Provider.of<AuthService>(context, listen: false);
    _isAdmin = authService.user?.isAdmin ?? false;

    _tabController = TabController(length: _isAdmin ? 3 : 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dio = authService.dio;
      _holidayService = HolidayService(dio);

      _fetchHolidays();
      // Fetch leaves via provider
      context.read<LeaveProvider>().fetchMyLeaves();
    });
  }

  Future<void> _fetchHolidays() async {
    if (!mounted) return;
    setState(() => _isLoadingHolidays = true);
    try {
      final data = await _holidayService.getHolidays();
      if (mounted) setState(() => _holidays = data);
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) setState(() => _isLoadingHolidays = false);
    }
  }

  void _showApplyLeaveSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LeaveRequestForm(
        onSuccess: () {
          Navigator.pop(context);
          context.showToast("Leave requested successfully.", isSuccess: true);
          // Refresh my leaves
          context.read<LeaveProvider>().fetchMyLeaves();
        },
      ),
    );
  }

  Future<void> _withdrawRequest(int id) async {
    debugPrint("LeaveMobileView: Attempting to withdraw request with ID: $id");
    try {
      final confirm = await CustomDialog.show(
        context: context,
        title: "Withdraw Request",
        message:
            "Are you sure you want to withdraw this leave request? This action cannot be undone.",
        positiveButtonText: "Withdraw",
        negativeButtonText: "Cancel",
        isDestructive: true,
        icon: Icons.warning_amber_rounded,
        iconColor: Colors.red,
        onPositivePressed: () {}, // Handled by show() returning true
      );

      if (confirm == true && mounted) {
        await context.read<LeaveProvider>().withdrawRequest(id);
        if (mounted) {
          context.showToast(
            "Leave request withdrawn successfully.",
            isSuccess: true,
          );
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Withdraw Failed: $e")));
    }
  }

  // Admin Actions
  void _showAddDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => HolidayFormDialog(
        onSubmit: (data) async {
          try {
            await _holidayService.addHoliday(data);
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
            await _holidayService.updateHoliday(holiday.id, data);
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

  Future<void> _deleteHoliday(int id) async {
    try {
      await _holidayService.deleteHolidays([id]);
      if (!mounted) return;
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
          if (!mounted) return;
          setState(() => _isLoadingHolidays = true);
          await _holidayService.addBulkHolidays(batch);
          if (!mounted) return;
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
      if (mounted) setState(() => _isLoadingHolidays = false);
    }
  }

  Future<void> _downloadHolidayTemplate(BuildContext context) async {
    try {
      String path;
      if (Platform.isAndroid) {
        path = '/storage/emulated/0/Download/holidays_template.csv';
      } else {
        final dir =
            await getDownloadsDirectory() ??
            await getApplicationDocumentsDirectory();
        path = '${dir.path}/holidays_template.csv';
      }

      final file = File(path);
      await file.writeAsString(
        "Name,Date,Type\n"
        "New Year's Day,2026-01-01,Public\n"
        "Good Friday,2026-04-03,Public\n"
        "Independence Day,2026-08-15,Public",
      );

      if (!context.mounted) return;
      context.showToast('Template saved to $path', isSuccess: true);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save template: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showBulkImportBottomSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.05),
                  width: 1,
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white24 : Colors.black12,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Text(
                        "Bulk Import Holidays",
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Upload a CSV file containing the list of holidays. Format should match the template below.",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Dummy CSV Reference",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? Colors.white10 : Colors.grey[200]!,
                          ),
                        ),
                        child: Table(
                          columnWidths: const {
                            0: FlexColumnWidth(2),
                            1: FlexColumnWidth(2),
                            2: FlexColumnWidth(1),
                          },
                          border: TableBorder.symmetric(
                            inside: BorderSide(
                              color: isDark
                                  ? Colors.white.withOpacity(0.05)
                                  : Colors.grey[200]!,
                            ),
                          ),
                          children: [
                            TableRow(
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withOpacity(0.02)
                                    : Colors.grey[50]!,
                              ),
                              children: [
                                _buildTableCell(
                                  "Name",
                                  isHeader: true,
                                  isDark: isDark,
                                ),
                                _buildTableCell(
                                  "Date",
                                  isHeader: true,
                                  isDark: isDark,
                                ),
                                _buildTableCell(
                                  "Type",
                                  isHeader: true,
                                  isDark: isDark,
                                ),
                              ],
                            ),
                            TableRow(
                              children: [
                                _buildTableCell(
                                  "New Year's Day",
                                  isHeader: false,
                                  isDark: isDark,
                                ),
                                _buildTableCell(
                                  "2026-01-01",
                                  isHeader: false,
                                  isDark: isDark,
                                ),
                                _buildTableCell(
                                  "Public",
                                  isHeader: false,
                                  isDark: isDark,
                                ),
                              ],
                            ),
                            TableRow(
                              children: [
                                _buildTableCell(
                                  "Good Friday",
                                  isHeader: false,
                                  isDark: isDark,
                                ),
                                _buildTableCell(
                                  "2026-04-03",
                                  isHeader: false,
                                  isDark: isDark,
                                ),
                                _buildTableCell(
                                  "Public",
                                  isHeader: false,
                                  isDark: isDark,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      InkWell(
                        onTap: () async {
                          await _downloadHolidayTemplate(context);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isDark
                                  ? Colors.white24
                                  : Colors.grey[300]!,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.download_outlined,
                                color: isDark
                                    ? const Color(0xFF818CF8)
                                    : const Color(0xFF4F46E5),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Download CSV Template",
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isDark
                                            ? Colors.white
                                            : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    Text(
                                      "Download sample holiday CSV file",
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _importCSV();
                          },
                          icon: const Icon(Icons.upload_file_outlined),
                          label: Text(
                            "Select & Import CSV",
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTableCell(
    String text, {
    required bool isHeader,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          color: isHeader
              ? (isDark ? Colors.white70 : Colors.black87)
              : (isDark ? Colors.white54 : Colors.grey[800]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool showFab = false;
    // Admin: Show "Add Holiday" on Tab 0 (Holidays)
    if (_isAdmin && _tabController.index == 0) {
      showFab = true;
    }
    // Admin/Employee: Show "Apply Leave" on Tab 1 (My Leaves)
    else if (_tabController.index == 1) {
      showFab = true;
    }

    return Scaffold(
      floatingActionButton: showFab
          ? FloatingActionButton(
              onPressed: () {
                if (_isAdmin && _tabController.index == 0) {
                  _showAddDialog();
                } else {
                  _showApplyLeaveSheet();
                }
              },
              backgroundColor: Theme.of(context).primaryColor,
              elevation: 4,
              child: Icon(
                (_isAdmin && _tabController.index == 0)
                    ? Icons.add
                    : Icons.add, // Both are add, but actions differ
                color: Colors.white,
              ),
            )
          : null,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _buildTabs(context),
                  if (_isAdmin && (!mounted || _tabController.index == 0))
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _showBulkImportBottomSheet(context),
                          icon: const Icon(Icons.upload_file, size: 18),
                          label: const Text("Bulk Import"),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildHolidaysList(context),
            _buildLeaveList(context),
            if (_isAdmin) AdminLeaveView(),
          ],
        ),
      ),
    );
  }

  Widget _buildHolidaysList(BuildContext context) {
    if (_isLoadingHolidays)
      return const Center(child: CircularProgressIndicator());
    if (_holidays.isEmpty)
      return Center(
        child: Text(
          "No holidays found",
          style: GoogleFonts.poppins(color: Colors.grey),
        ),
      );

    return ListView.builder(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 0, bottom: 80),
      itemCount: _holidays.length,
      itemBuilder: (context, index) {
        final holiday = _holidays[index];
        final dt = DateTime.parse(holiday.date);
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return InkWell(
          onTap: () => HolidayDetailsDialog.showMobile(
            context,
            holiday: holiday,
            isAdmin: _isAdmin,
            onEdit: () => _showEditDialog(holiday),
            onDelete: () => _showDeleteConfirm(holiday.id),
          ),
          child: GlassContainer(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF30363D)
                        : Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('d').format(dt),
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? const Color(0xFF818CF8)
                              : Theme.of(context).primaryColor,
                        ),
                      ),
                      Text(
                        DateFormat('MMM').format(dt).toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? const Color(0xFF818CF8)
                              : Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        holiday.name,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        DateFormat('EEEE').format(dt),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabs(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isNarrow = MediaQuery.of(context).size.width < 360;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Container(
        height: 48,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161B22) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? const Color(0xFF30363D)
                : Colors.black.withValues(alpha: 0.05),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TabBar(
          controller: _tabController,
          onTap: (index) => setState(() {}),
          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: isDark ? const Color(0xFF2D3139) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
              width: 1,
            ),
            boxShadow: isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          dividerColor: Colors.transparent,
          labelColor: isDark ? Colors.white : const Color(0xFF4F46E5),
          unselectedLabelColor: isDark
              ? const Color(0xFF94A3B8)
              : const Color(0xFF64748B),
          labelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          tabs: [
            Tab(
              height: 38,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.beach_access, size: 16),
                  const SizedBox(width: 4),
                  Text(isNarrow ? 'Hols' : 'Holidays'),
                ],
              ),
            ),
            Tab(
              height: 38,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.event_note, size: 16),
                  const SizedBox(width: 4),
                  Text(isNarrow ? 'Leaves' : 'My Leaves'),
                ],
              ),
            ),
            if (_isAdmin)
              Tab(
                height: 38,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.admin_panel_settings, size: 16),
                    const SizedBox(width: 4),
                    Text(isNarrow ? 'Reqs' : 'Requests'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeaveList(BuildContext context) {
    return Consumer<LeaveProvider>(
      builder: (context, provider, _) {
        if (provider.isLoadingMyLeaves) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.myLeavesError != null) {
          final raw = provider.myLeavesError!.toLowerCase();
          final isConnectionIssue =
              raw.contains('failed host lookup') ||
              raw.contains('connection error') ||
              raw.contains('socketexception') ||
              raw.contains('network');
          final message = isConnectionIssue
              ? "Unable to load leave history. Please check your internet connection and try again."
              : "Unable to load leave history right now. Please try again.";
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF8B949E)
                        : const Color(0xFF64748B),
                    size: 28,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? const Color(0xFF8B949E)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (provider.myLeaves.isEmpty) {
          return Center(
            child: Text(
              "No leave requests found",
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => provider.fetchMyLeaves(forceRefresh: true),
          child: ListView.builder(
            padding: const EdgeInsets.only(
              top: 8,
              bottom: 80,
            ), // bottom padding for FAB
            itemCount: provider.myLeaves.length,
            itemBuilder: (context, index) {
              final request = provider.myLeaves[index];
              return LeaveHistoryItem(
                request: request,
                onDelete: () => _withdrawRequest(request.id),
              );
            },
          ),
        );
      },
    );
  }
}
