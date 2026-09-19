import 'package:flutter/material.dart';
import 'package:flutter_application/features/attendance/core/correction_request.dart';
import 'package:flutter_application/features/attendance/widgets/correction_request_dialog.dart';

class CorrectionRequestDialogMobile extends StatelessWidget {
  final int? attendanceId;
  final DateTime? initialDate;
  final CorrectionType? initialType;

  const CorrectionRequestDialogMobile({
    super.key,
    this.attendanceId,
    this.initialDate,
    this.initialType,
  });

  static Future<void> show(
    BuildContext context, {
    int? attendanceId,
    DateTime? date,
    CorrectionType? type,
    VoidCallback? onSuccess,
  }) async {
    return CorrectionRequestDialog.show(
      context,
      attendanceId: attendanceId,
      date: date,
      type: type,
      onSuccess: onSuccess,
    );
  }

  @override
  Widget build(BuildContext context) {
    return CorrectionRequestDialog(
      attendanceId: attendanceId,
      initialDate: initialDate,
      initialType: initialType,
    );
  }
}
