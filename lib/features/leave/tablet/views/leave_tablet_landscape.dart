import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/toast_helper.dart';
import '../../../../shared/services/auth_service.dart';
import '../../services/leave_service.dart';
import '../../../holidays/services/holiday_service.dart';
import '../../widgets/leave_calendar.dart';
import '../../widgets/leave_form.dart';
import '../../widgets/holiday_details_dialog.dart';
import '../../widgets/leave_details_dialog.dart';
import '../../models/leave_request_model.dart';
import '../../widgets/admin_leave_view.dart';

class LeaveTabletLandscape extends StatefulWidget {
  const LeaveTabletLandscape({super.key});

  @override
  State<LeaveTabletLandscape> createState() => _LeaveTabletLandscapeState();
}

class _LeaveTabletLandscapeState extends State<LeaveTabletLandscape>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late LeaveService _leaveService;
  late HolidayService _holidayService;

  bool _isLoadingLeaves = false;
  List<LeaveRequest> _leaves = [];
  String? _leavesError;

  bool _isLoadingHolidays = false;
  List<dynamic> _holidays = [];

  DateTime _focusedMonth = DateTime.now();
  DateTime? _selectedStartDate;
  DateTime? _selectedEndDate;

  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthService>(context, listen: false);
    _isAdmin = auth.user?.isAdmin ?? false;
    _tabController = TabController(length: _isAdmin ? 3 : 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dio = auth.dio;
      _leaveService = LeaveService(dio);
      _holidayService = HolidayService(dio);

      _fetchLeaves();
      _fetchHolidays();
    });
  }

  Future<void> _fetchLeaves() async {
    setState(() => _isLoadingLeaves = true);
    try {
      final data = await _leaveService.getMyHistory();
      if (mounted) {
        setState(() {
          _leaves = data;
          _leavesError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _leaves = [];
          _leavesError = "Unable to load leave history. Please try again.";
        });
      }
    } finally {
      if (mounted) setState(() => _isLoadingLeaves = false);
    }
  }

  Future<void> _fetchHolidays() async {
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

  Future<void> _submitLeaveRequest(Map<String, dynamic> data) async {
    setState(
      () => _isLoadingLeaves = true,
    ); // Use local loading state or pass to form if needed
    try {
      // API expects formatted dates? typically YYYY-MM-DD
      // The form sends them as strings already split by 'T', checking..
      // Form: 'start_date': _startDate.toIso8601String().split('T')[0] -> Correct

      await _leaveService.submitLeaveRequest(data);
      if (mounted) {
        context.showToast("Leave requested successfully.", isSuccess: true);
        _fetchLeaves(); // Refresh history
        // Reset form? Form handles it or we re-build
      }
    } catch (e) {
      String msg = "Submit Failed";
      if (e is DioException) {
        msg += " (${e.response?.statusCode ?? 'No Status'})"; // Add Status Code
        if (e.response?.data != null && e.response!.data is Map) {
          msg += ": ${e.response!.data['message'] ?? e.message}";
        } else {
          msg += ": ${e.message}";
        }
      } else {
        msg += ": $e";
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 5)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingLeaves = false);
    }
  }

  Future<void> _withdrawRequest(int id) async {
    try {
      await _leaveService.withdrawRequest(id);
      if (mounted) {
        context.showToast(
          "Leave request withdrawn successfully.",
          isSuccess: true,
        );
        _fetchLeaves();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Withdraw Failed: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Panel: Content (Flex 1)
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTabs(context),
                const SizedBox(height: 24),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1: Holidays List
                      _buildHolidaysView(context),
                      // Tab 2: Leave Application
                      _buildLeaveApplicationView(context),
                      if (_isAdmin) const AdminLeaveView(),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 24),

          // Right Panel: Calendar (Flex 1) now takes 50%
          Expanded(
            flex: 1,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                children: [
                  // Calendar Widget
                  LeaveCalendar(
                    holidays: _holidays,
                    leaves: _leaves,
                    focusedDay: _focusedMonth,
                    onMonthChanged: (d) => setState(() => _focusedMonth = d),
                    rangeStart: _selectedStartDate, // Pass trace start
                    rangeEnd: _selectedEndDate, // Pass trace end
                  ),
                  // Could add Upcoming Events List below calendar here if needed
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : Colors.grey[300]!,
        ),
      ),
      child: TabBar(
        controller: _tabController,
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: isDark ? const Color(0xFF2D3139) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        dividerColor: Colors.transparent,
        labelColor: isDark ? Colors.white : const Color(0xFF5B60F6),
        unselectedLabelColor: isDark
            ? const Color(0xFF94A3B8)
            : const Color(0xFF64748B),
        labelStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        tabs: [
          Tab(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.calendar_today_outlined, size: 16),
                  SizedBox(width: 8),
                  Text("Holidays"),
                ],
              ),
            ),
          ),
          Tab(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.description_outlined, size: 16),
                  SizedBox(width: 8),
                  Text("My Leaves"),
                ],
              ),
            ),
          ),
          if (_isAdmin)
            Tab(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.admin_panel_settings, size: 16),
                    SizedBox(width: 8),
                    Text("Requests"),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHolidaysView(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF161B22) : Colors.white;
    final borderColor = isDark ? Colors.transparent : Colors.grey[200]!;

    return Column(
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: 'Search holidays..',
            hintStyle: GoogleFonts.poppins(color: Colors.grey),
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
            filled: true,
            fillColor: cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.transparent : Colors.grey[200]!,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.transparent : Colors.grey[200]!,
              ),
            ), // Clean white border
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 0,
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Month Header based on focusedMonth
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.transparent : Colors.grey[200]!,
            ),
          ),
          child: Text(
            DateFormat('MMMM yyyy').format(_focusedMonth),
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        Expanded(
          child: _holidays.isEmpty
              ? Center(
                  child: _isLoadingHolidays
                      ? const CircularProgressIndicator()
                      : const Text("No holidays"),
                )
              : ListView.separated(
                  itemCount: _holidays.length,
                  separatorBuilder: (c, i) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final holiday = _holidays[index];
                    final dt = DateTime.parse(holiday.date);

                    if (dt.month != _focusedMonth.month ||
                        dt.year != _focusedMonth.year) {
                      return const SizedBox.shrink();
                    }

                    return InkWell(
                      onTap: () => HolidayDetailsDialog.showLandscape(
                        context,
                        holiday: holiday,
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    DateFormat('dd').format(dt),
                                    style: GoogleFonts.poppins(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF6366F1),
                                    ),
                                  ),
                                  Text(
                                    DateFormat('EEE').format(dt).toUpperCase(),
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF6366F1),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 20),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  holiday.name,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.purple.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    "PUBLIC",
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.purple,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildLeaveApplicationView(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF161B22) : Colors.white;
    final borderColor = isDark ? Colors.transparent : Colors.grey[200]!;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.02) : borderColor,
              ),
            ),
            child: LeaveForm(
              onSubmit: _submitLeaveRequest,
              isLoading: _isLoadingLeaves,
              onDatesChanged: (start, end) {
                setState(() {
                  _selectedStartDate = start;
                  _selectedEndDate = end;
                });
              },
            ),
          ),

          const SizedBox(height: 32),

          // History Section (Restored)
          Text(
            "Leave History",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          // Summary Card
          if (_leavesError != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161B22) : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _leavesError!,
                style: GoogleFonts.poppins(
                  color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
                ),
              ),
            ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.02) : borderColor,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${_leaves.length} Records",
                      style: GoogleFonts.poppins(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF5B60F6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "Total Approved: ${_leaves.where((l) => l.status.toLowerCase() == 'approved').length} Days",
                        style: GoogleFonts.poppins(
                          color: const Color(0xFF5B60F6),
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.grey.withValues(alpha: 0.3),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "January",
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                  Icon(
                                    Icons.keyboard_arrow_down,
                                    size: 16,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 100,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.grey.withValues(alpha: 0.3),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "2026",
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                  Icon(
                                    Icons.keyboard_arrow_down,
                                    size: 16,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Cards List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _leaves.length,
            separatorBuilder: (c, i) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final LeaveRequest leave = _leaves[index];
              Color statusColor = Colors.grey;
              final status = leave.status.toLowerCase().trim();
              if (status == 'approved') statusColor = const Color(0xFF22C55E);
              if (status == 'rejected') statusColor = const Color(0xFFEF4444);
              if (status == 'pending') statusColor = const Color(0xFFF59E0B);

              return InkWell(
                onTap: () => LeaveDetailsDialog.showLandscape(
                  context,
                  request: leave,
                  onWithdraw: () => _withdrawRequest(leave.id),
                ),
                child: GlassContainer(
                  padding: const EdgeInsets.all(12),
                  borderRadius: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            leave.leaveType,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "● ${leave.status.toUpperCase()}",
                              style: GoogleFonts.poppins(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Divider(height: 1, color: Colors.grey.withValues(alpha: 0.1)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 12,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('MMM dd, yyyy').format(leave.appliedAt),
                            style: GoogleFonts.poppins(
                              color: Colors.grey,
                              fontSize: 11,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            "${leave.endDate.difference(leave.startDate).inDays + 1} Days",
                            style: GoogleFonts.poppins(
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      if (leave.status.toLowerCase() == 'pending') ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: InkWell(
                            onTap: () => _withdrawRequest(leave.id),
                            child: Padding(
                              padding: const EdgeInsets.all(2.0),
                              child: Text(
                                "Withdraw Request",
                                style: GoogleFonts.poppins(
                                  color: Colors.red,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
