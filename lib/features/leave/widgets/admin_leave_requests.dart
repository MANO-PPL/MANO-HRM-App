import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application/features/leave/providers/leave_provider.dart';
import 'package:flutter_application/features/leave/models/leave_request_model.dart';
import 'package:flutter_application/features/leave/widgets/leave_history_item.dart';
import 'package:flutter_application/features/leave/widgets/leave_details_dialog.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';

class AdminLeaveRequests extends StatelessWidget {
  const AdminLeaveRequests({super.key});

  @override
  Widget build(BuildContext context) {
    // Trigger fetch on build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LeaveProvider>().fetchPendingRequests();
    });

    return Consumer<LeaveProvider>(
      builder: (context, provider, _) {
        if (provider.isLoadingPending) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.pendingError != null) {
          return Center(child: Text('Error: ${provider.pendingError}'));
        }

        if (provider.pendingRequests.isEmpty) {
          return const Center(child: Text('No pending requests'));
        }

        return ListView.builder(
          itemCount: provider.pendingRequests.length,
          itemBuilder: (context, index) {
            final request = provider.pendingRequests[index];
            return _buildAdminItem(context, request, provider);
          },
        );
      },
    );
  }

  Widget _buildAdminItem(
    BuildContext context,
    LeaveRequest request,
    LeaveProvider provider,
  ) {
    return LeaveHistoryItem(
      request: request,
      onTap: () => _showReviewDialog(context, request, provider),
    );
  }

  void _showReviewDialog(
    BuildContext context,
    LeaveRequest request,
    LeaveProvider provider,
  ) {
    LeaveDetailsDialog.showMobile(
      context,
      request: request,
      isReviewMode: true,
      onApprove: () {
        context.showToast(
          "Leave request approved successfully.",
          isSuccess: true,
        );
      },
      onReject: () {
        context.showToast("Leave request rejected.", isSuccess: true);
      },
    );
  }
}
