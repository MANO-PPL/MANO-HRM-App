import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application/features/leave/widgets/admin_leave_requests.dart';
import 'package:flutter_application/features/leave/widgets/admin_leave_history.dart';

class AdminLeaveView extends StatefulWidget {
  const AdminLeaveView({super.key});

  @override
  State<AdminLeaveView> createState() => _AdminLeaveViewState();
}

class _AdminLeaveViewState extends State<AdminLeaveView> with SingleTickerProviderStateMixin {
  late TabController _adminTabController;

  @override
  void initState() {
    super.initState();
    _adminTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _adminTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Internal Sub-tabs for Admin
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF30363D) : Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: TabBar(
              controller: _adminTabController,
              indicator: BoxDecoration(
                color: isDark ? const Color(0xFF30363D) : Colors.white,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: isDark ? const Color(0xFF818CF8) : const Color(0xFF4338CA),
              unselectedLabelColor: Colors.grey[600],
              labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
              tabs: const [
                Tab(text: 'Pending'),
                Tab(text: 'History'),
              ],
            ),
          ),
        ),
        
        Expanded(
          child: TabBarView(
            controller: _adminTabController,
            children: const [
              AdminLeaveRequests(), // Existing pending view
              AdminLeaveHistory(),  // New history view
            ],
          ),
        ),
      ],
    );
  }
}
