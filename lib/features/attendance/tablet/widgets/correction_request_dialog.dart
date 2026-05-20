import 'package:flutter/material.dart';
import '../../../../shared/widgets/custom_dialog.dart';
import '../../../../shared/widgets/toast_helper.dart';
import '../../widgets/correction_request_form.dart';

class CorrectionRequestDialog extends StatefulWidget {
  final int? attendanceId; // Optional, if correcting a specific record
  final DateTime? initialDate;

  const CorrectionRequestDialog({super.key, this.attendanceId, this.initialDate});

  static Future<void> show(BuildContext context, {int? attendanceId, DateTime? date}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 500),
      builder: (context) => CorrectionRequestDialog(attendanceId: attendanceId, initialDate: date),
    );

    if (result == true && context.mounted) {
       context.showToast("Your correction request has been sent for approval.", isSuccess: true);
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
      onClose: () => Navigator.pop(context),
      onSuccess: () {
        Navigator.pop(context, true);
      },
    );
  }
}
