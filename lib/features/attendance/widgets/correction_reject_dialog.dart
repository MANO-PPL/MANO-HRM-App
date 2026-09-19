import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';

/// Rejection reason dialog with quick preset pills, mirroring Web's rejection flow.
class CorrectionRejectDialog extends StatefulWidget {
  final String userName;
  final DateTime requestDate;
  final Future<void> Function(String reason) onConfirm;

  const CorrectionRejectDialog({
    super.key,
    required this.userName,
    required this.requestDate,
    required this.onConfirm,
  });

  static Future<void> show(
    BuildContext context, {
    required String userName,
    required DateTime requestDate,
    required Future<void> Function(String reason) onConfirm,
  }) {
    return showDialog(
      context: context,
      builder: (context) => CorrectionRejectDialog(
        userName: userName,
        requestDate: requestDate,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<CorrectionRejectDialog> createState() => _CorrectionRejectDialogState();
}

class _CorrectionRejectDialogState extends State<CorrectionRejectDialog> {
  final _reasonController = TextEditingController();
  bool _isLoading = false;

  final List<String> _presets = [
    'Biometric records contradict claimed timings',
    'Insufficient justification reason provided',
    'Supporting proof / documents missing or invalid',
    'Exceeds allowed correction window',
    'Punch timestamps overlap with existing approved logs',
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _handleConfirm() async {
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      context.showToast('Please provide or select a rejection reason.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await widget.onConfirm(reason);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        context.showToast('Error: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final borderColor = isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Container(
            decoration: BoxDecoration(
              color: dialogBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.cancel_outlined,
                        color: Color(0xFFEF4444),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Reject Correction Request',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                            ),
                          ),
                          Text(
                            'For ${widget.userName}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, size: 20, color: isDark ? Colors.white38 : Colors.grey[400]),
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Quick Preset Pills
                Text(
                  'QUICK REJECTION REASONS',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 8),

                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _presets.map((preset) {
                    final isSelected = _reasonController.text == preset;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _reasonController.text = preset;
                          _reasonController.selection = TextSelection.fromPosition(
                            TextPosition(offset: preset.length),
                          );
                        });
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                              : (isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFEF4444)
                                : (isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
                          ),
                        ),
                        child: Text(
                          preset,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected
                                ? const Color(0xFFEF4444)
                                : (isDark ? Colors.white70 : const Color(0xFF475569)),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // Reason input
                Text(
                  'JUSTIFICATION NOTE',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: isDark ? Colors.white54 : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 6),

                TextField(
                  controller: _reasonController,
                  maxLines: 3,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter specific reason or select a preset above...',
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
                    ),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFEF4444)),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),

                const SizedBox(height: 20),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.close_rounded, size: 15),
                                const SizedBox(width: 4),
                                Text(
                                  'Confirm Rejection',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
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
        ),
      ),
    );
  }
}
