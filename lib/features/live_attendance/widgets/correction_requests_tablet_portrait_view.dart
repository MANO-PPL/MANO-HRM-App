import 'package:flutter/material.dart';
import 'package:flutter_application/features/attendance/widgets/attendance_admin_view.dart';

class CorrectionRequestsView extends StatelessWidget {
  const CorrectionRequestsView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: AdminCorrectionRequests(),
    );
  }
}

// [mod:2026-02-23T11:30:00+05:30]
