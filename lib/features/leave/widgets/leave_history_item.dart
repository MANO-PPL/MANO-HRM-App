import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/leave_request_model.dart';
import './leave_details_dialog.dart';

class LeaveHistoryItem extends StatelessWidget {
  final LeaveRequest request;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const LeaveHistoryItem({
    super.key,
    required this.request,
    this.onDelete,
    this.onTap,
  });

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return const Color(0xFF10B981); // Emerald 500
      case 'rejected':
        return const Color(0xFFEF4444); // Red 500
      case 'pending':
        return const Color(0xFFF59E0B); // Amber 500
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _getStatusColor(request.status);

    return InkWell(
      onTap: onTap ?? () => LeaveDetailsDialog.showMobile(
        context,
        request: request,
        onWithdraw: request.status.toLowerCase() == 'pending' ? onDelete : null,
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161B22) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    request.status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

              ],
            ),
            const SizedBox(height: 12),
            Text(
              request.leaveType,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF30363D),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              request.reason,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : const Color(0xFF64748B),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: isDark ? Colors.white70 : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 6),
                Text(
                  '${DateFormat('MMM dd, yyyy').format(request.startDate)} - ${DateFormat('MMM dd, yyyy').format(request.endDate)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
