import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application/features/leave/widgets/admin_leave_requests.dart';
import 'package:flutter_application/features/leave/widgets/admin_leave_history.dart';

class AdminLeaveView extends StatefulWidget {
  const AdminLeaveView({super.key});

  @override
  State<AdminLeaveView> createState() => _AdminLeaveViewState();
}

class _AdminLeaveViewState extends State<AdminLeaveView> {
  String _activeTab = 'Pending';

  Widget _buildTabButton(String label, bool isActive, bool isDark) {
    final activeColor = isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5);
    return GestureDetector(
      onTap: () {
        if (_activeTab != label) {
          setState(() => _activeTab = label);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? activeColor
                : (isDark ? Colors.white24 : Colors.grey.withOpacity(0.3)),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: isActive
                ? Colors.white
                : (isDark ? Colors.white54 : Colors.grey[600]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Internal Sub-tabs for Admin
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              _buildTabButton('Pending', _activeTab == 'Pending', isDark),
              const SizedBox(width: 12),
              _buildTabButton('History', _activeTab == 'History', isDark),
            ],
          ),
        ),
        
        Expanded(
          child: _activeTab == 'Pending'
              ? const AdminLeaveRequests()
              : const AdminLeaveHistory(),
        ),
      ],
    );
  }
}
