import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'glass_confirmation_dialog.dart';

class EmployeeActionMenu extends StatelessWidget {
  final VoidCallback onEdit;
  final VoidCallback onDeleteConfirmed;

  const EmployeeActionMenu({
    super.key,
    required this.onEdit,
    required this.onDeleteConfirmed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: isDark ? Colors.white70 : Colors.grey),
      color: isDark ? const Color(0xFF161B22) : Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isDark ? BorderSide.none : BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      onSelected: (val) {
        if (val == 'edit') {
          onEdit();
        } else if (val == 'delete') {
          _showDeleteConfirmation(context);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 20, color: isDark ? Colors.white : Colors.black87),
              const SizedBox(width: 12),
              Text(
                'Edit', 
                style: GoogleFonts.poppins(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete_outline, size: 20, color: Colors.red),
              const SizedBox(width: 12),
              Text(
                'Delete',
                style: GoogleFonts.poppins(
                  color: Colors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showDeleteConfirmation(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => GlassConfirmationDialog(
        title: 'Confirm Delete',
        content: 'Are you sure you want to delete this employee? This action cannot be undone.',
        confirmLabel: 'Delete',
        onConfirm: () => Navigator.pop(context, true),
      ),
    );

    if (confirm == true) {
      onDeleteConfirmed();
    }
  }
}
