import 'package:flutter/material.dart';
import 'package:flutter_application/features/attendance/core/correction_request.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';
import 'package:flutter_application/features/attendance/widgets/correction_request_form.dart';

class CorrectionRequestDialog extends StatefulWidget {
  final int? attendanceId;
  final DateTime? initialDate;
  final CorrectionType? initialType;

  const CorrectionRequestDialog({
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
    final size = MediaQuery.of(context).size;
    final width = size.width;

    bool? result;

    if (width >= 900) {
      // 1. Tablet Landscape / Desktop: Render as elegant centered wide modal
      result = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        barrierColor: Colors.black.withValues(alpha: 0.5),
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 840,
                maxHeight: size.height * 0.90,
              ),
              child: CorrectionRequestDialog(
                attendanceId: attendanceId,
                initialDate: date,
                initialType: type,
              ),
            ),
          ),
        ),
      );
    } else if (width >= 600) {
      // 2. Tablet Portrait: Bottom sheet modal constrained to max 600px
      result = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        useSafeArea: true,
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: size.height * 0.92,
        ),
        builder: (context) => CorrectionRequestDialog(
          attendanceId: attendanceId,
          initialDate: date,
          initialType: type,
        ),
      );
    } else {
      // 3. Mobile Portrait: Full-width bottom sheet with swipe handle
      result = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        useSafeArea: true,
        constraints: BoxConstraints(
          maxHeight: size.height * 0.94,
        ),
        builder: (context) => CorrectionRequestDialog(
          attendanceId: attendanceId,
          initialDate: date,
          initialType: type,
        ),
      );
    }

    if (result == true) {
      if (context.mounted) {
        context.showToast("Your correction request has been sent for approval.", isSuccess: true);
      }
      onSuccess?.call();
    }
  }

  @override
  State<CorrectionRequestDialog> createState() => _CorrectionRequestDialogState();
}

class _CorrectionRequestDialogState extends State<CorrectionRequestDialog> {
  @override
  Widget build(BuildContext context) {
    return CorrectionRequestForm(
      initialDate: widget.initialDate,
      initialType: widget.initialType,
      onClose: () => Navigator.pop(context),
      onSuccess: () => Navigator.pop(context, true),
    );
  }
}
