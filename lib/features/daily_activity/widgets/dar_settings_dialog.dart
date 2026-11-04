import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application/features/daily_activity/widgets/dar_admin_controller.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';

class DarSettingsDialog extends StatefulWidget {
  final DarAdminController ctrl;

  const DarSettingsDialog({super.key, required this.ctrl});

  static Future<void> show(BuildContext context, DarAdminController ctrl) {
    return showDialog(
      context: context,
      builder: (ctx) => DarSettingsDialog(ctrl: ctrl),
    );
  }

  @override
  State<DarSettingsDialog> createState() => _DarSettingsDialogState();
}

class _DarSettingsDialogState extends State<DarSettingsDialog> {
  late TextEditingController _bufferCtrl;
  final TextEditingController _newCatCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _bufferCtrl = TextEditingController(text: widget.ctrl.bufferMinutes.toString());
  }

  @override
  void dispose() {
    _bufferCtrl.dispose();
    _newCatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF161B22) : Colors.white;
    final border = isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0);

    return AnimatedBuilder(
      animation: widget.ctrl,
      builder: (context, _) {
        return Dialog(
          backgroundColor: bg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 440,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.settings_outlined,
                          color: Color(0xFF4F46E5), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DAR Configurations',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Buffer time & activity categories',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: isDark ? Colors.white54 : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close, size: 20, color: isDark ? Colors.white70 : Colors.black87),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Buffer Time Setting
                Text(
                  'Submission Buffer Minutes',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _bufferCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'e.g. 15',
                    suffixText: 'mins',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 16),

                // Categories Management
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Activity Categories (${widget.ctrl.categories.length})',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Add Category Row
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _newCatCtrl,
                        decoration: InputDecoration(
                          hintText: 'New category name...',
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () async {
                        if (_newCatCtrl.text.trim().isNotEmpty) {
                          await widget.ctrl.addCategory(_newCatCtrl.text.trim());
                          _newCatCtrl.clear();
                        }
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add'),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: const Color(0xFF4F46E5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Category Chips Wrap
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: widget.ctrl.categories.map((cat) {
                        return Chip(
                          label: Text(
                            cat,
                            style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500),
                          ),
                          deleteIcon: const Icon(Icons.close, size: 14),
                          onDeleted: () => widget.ctrl.removeCategory(cat),
                          backgroundColor: isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9),
                          side: BorderSide(color: border),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Save Action
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _isSaving
                          ? null
                          : () async {
                              setState(() => _isSaving = true);
                              final buf = int.tryParse(_bufferCtrl.text.trim()) ?? 0;
                              final success = await widget.ctrl.updateSettings(buffer: buf);
                              setState(() => _isSaving = false);
                              if (mounted) {
                                if (success) {
                                  context.showToast('DAR settings updated successfully!', isSuccess: true);
                                  Navigator.of(context).pop();
                                } else {
                                  context.showToast('Failed to update settings', isError: true);
                                }
                              }
                            },
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
                      child: _isSaving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Save Settings'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
