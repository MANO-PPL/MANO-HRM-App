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
import '../../widgets/holiday_details_dialog.dart';
import '../../widgets/leave_details_dialog.dart';
import '../../models/leave_request_model.dart';
import '../../widgets/admin_leave_view.dart';

class LeaveTabletPortrait extends StatefulWidget {
  const LeaveTabletPortrait({super.key});

  @override
  State<LeaveTabletPortrait> createState() => _LeaveTabletPortraitState();
}

class _LeaveTabletPortraitState extends State<LeaveTabletPortrait>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late LeaveService _leaveService;
  late HolidayService _holidayService;

  bool _isLoadingLeaves = false;
  List<LeaveRequest> _leaves = [];
  String? _leavesError;

  bool _isLoadingHolidays = false;
  List<dynamic> _holidays = [];

  // Form State
  final _reasonController = TextEditingController();
  final _otherTypeController = TextEditingController(); // ADDED
  String _selectedType = 'Casual Leave';
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

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

  Future<void> _submitapplication() async {
    try {
      if (_selectedType == 'Other' &&
          _otherTypeController.text.trim().isEmpty) {
        context.showToast("Please specify the leave type.", isWarning: true);
        return;
      }

      await _leaveService.submitLeaveRequest({
        'leave_type': _selectedType == 'Other'
            ? _otherTypeController.text
            : _selectedType,
        'start_date': DateFormat('yyyy-MM-dd').format(_startDate),
        'end_date': DateFormat('yyyy-MM-dd').format(_endDate),
        'reason': _reasonController.text,
      });

      if (mounted) {
        Navigator.pop(context); // Close sheet
        context.showToast("Leave requested successfully.", isSuccess: true);
        _reasonController.clear();
        _otherTypeController.clear();
        setState(() {
          _selectedType = 'Casual Leave';
        });
        _fetchLeaves();
      }
    } catch (e) {
      String msg = "Submit Failed: $e";
      if (e is DioException &&
          e.response?.data != null &&
          e.response!.data is Map) {
        msg = e.response!.data['message'] ?? msg;
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
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

  void _showApplyLeaveDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0D1117) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF30363D)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + bottomInset),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      "New Leave Request",
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 24),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedType,
                      items: ['Casual Leave', 'Sick Leave', 'Other']
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedType = v!),
                      decoration: InputDecoration(
                        labelText: 'Leave Type',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.category_outlined),
                      ),
                    ),
                    if (_selectedType == 'Other') ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _otherTypeController,
                        decoration: InputDecoration(
                          labelText: 'Specify Custom Type',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: _startDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (d != null) setState(() => _startDate = d);
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Start Date',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(Icons.date_range),
                              ),
                              child: Text(
                                "${_startDate.toLocal()}".split(' ')[0],
                                style: GoogleFonts.poppins(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: _endDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (d != null) setState(() => _endDate = d);
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'End Date',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                prefixIcon: const Icon(Icons.event_busy),
                              ),
                              child: Text(
                                "${_endDate.toLocal()}".split(' ')[0],
                                style: GoogleFonts.poppins(),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _reasonController,
                      decoration: InputDecoration(
                        labelText: 'Reason',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.description_outlined),
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _submitapplication,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          "Submit Request",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTabs(context),

        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildHolidaysList(context),
              _buildLeaveList(context),
              if (_isAdmin) const AdminLeaveView(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabs(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF161B22)
            : const Color(0xFFF1F5F9), // Match MyAttendanceView
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
        labelColor: isDark
            ? Colors.white
            : const Color(0xFF5B60F6), // Match MyAttendanceView
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

  Widget _buildHolidaysList(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_isLoadingHolidays) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_holidays.isEmpty) {
      return Center(
        child: Text(
          "No holidays found",
          style: GoogleFonts.poppins(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: _holidays.length,
      itemBuilder: (context, index) {
        final holiday = _holidays[index];
        final dt = DateTime.parse(holiday.date);

        return InkWell(
          onTap: () =>
              HolidayDetailsDialog.showPortrait(context, holiday: holiday),
          child: GlassContainer(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
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
                          color: const Color(0xFF6366F1),
                        ),
                      ),
                      Text(
                        DateFormat('MMM').format(dt).toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF6366F1),
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
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        DateFormat('EEEE').format(dt),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.grey[600],
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

  Widget _buildLeaveList(BuildContext context) {
    if (_isLoadingLeaves) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_leavesError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            _leavesError!,
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.grey),
          ),
        ),
      );
    }
    if (_leaves.isEmpty) {
      return Center(
        child: Text(
          "No leave requests found",
          style: GoogleFonts.poppins(color: Colors.grey),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Row(
            children: [
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _showApplyLeaveDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text("Apply Leave"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: _leaves.length,
            itemBuilder: (context, index) {
              final LeaveRequest leave = _leaves[index];

              Color statusColor = Colors.grey;
              final status = leave.status.toLowerCase().trim();
              if (status == 'approved') statusColor = const Color(0xFF22C55E);
              if (status == 'rejected') statusColor = const Color(0xFFEF4444);
              if (status == 'pending') statusColor = const Color(0xFFF59E0B);

              return InkWell(
                onTap: () => LeaveDetailsDialog.showPortrait(
                  context,
                  request: leave,
                  onWithdraw: () => _withdrawRequest(leave.id),
                ),
                child: GlassContainer(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
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
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: statusColor.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              leave.status,
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 12,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "${DateFormat('yyyy-MM-dd').format(leave.startDate)} - ${DateFormat('yyyy-MM-dd').format(leave.endDate)}",
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        leave.reason,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey[500],
                        ),
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
}
