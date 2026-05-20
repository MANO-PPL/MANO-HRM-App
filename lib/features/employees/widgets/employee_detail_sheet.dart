import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../../shared/services/auth_service.dart';
import '../models/employee_model.dart';

class EmployeeDetailSheet extends StatelessWidget {
  final Employee employee;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onToggleStatus;
  final VoidCallback? onRestore;
  final VoidCallback? onForceDelete;

  const EmployeeDetailSheet({
    super.key,
    required this.employee,
    required this.onEdit,
    required this.onDelete,
    this.onToggleStatus,
    this.onRestore,
    this.onForceDelete,
  });

  static void show(
    BuildContext context, {
    required Employee employee,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
    VoidCallback? onToggleStatus,
    VoidCallback? onRestore,
    VoidCallback? onForceDelete,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 500),
      builder: (context) => EmployeeDetailSheet(
        employee: employee,
        onEdit: onEdit,
        onDelete: onDelete,
        onToggleStatus: onToggleStatus,
        onRestore: onRestore,
        onForceDelete: onForceDelete,
      ),
    );
  }

  static void showFullscreenAvatar(BuildContext context, String imageUrl, String name) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.9),
      builder: (context) => Stack(
        children: [
          Center(
            child: InteractiveViewer(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: Material(
              color: Colors.transparent,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 20,
            child: Material(
              color: Colors.transparent,
              child: Text(
                name,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authService = Provider.of<AuthService>(context, listen: false);
    final isAdmin = authService.user != null && !authService.user!.isEmployee;

    final bgColor = isDark ? const Color(0xFF161B22) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final dividerColor = isDark ? const Color(0xFF30363D) : Colors.grey[200]!;
    final subTextColor = isDark ? const Color(0xFF8D96A0) : Colors.grey[600];

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: isDark ? const Color(0xFF30363D) : Colors.grey[300]!, width: 1),
        ),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF30363D) : Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          
          // Header section
          Row(
            children: [
              Text(
                'Employee Details',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close, color: isDark ? Colors.white70 : Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Avatar (with Tap Preview)
          GestureDetector(
            onTap: () {
              if (employee.profileImage != null && employee.profileImage!.isNotEmpty) {
                showFullscreenAvatar(context, employee.profileImage!, employee.userName);
              }
            },
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? const Color(0xFF2F81F7) : Theme.of(context).primaryColor,
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 44,
                backgroundColor: isDark ? const Color(0xFF0D1117) : Theme.of(context).primaryColor.withOpacity(0.1),
                child: employee.profileImage != null && employee.profileImage!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(44),
                        child: CachedNetworkImage(
                          imageUrl: employee.profileImage!,
                          width: 88,
                          height: 88,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => _buildInitialAvatar(context, isDark),
                          placeholder: (context, url) => _buildInitialAvatar(context, isDark),
                        ),
                      )
                    : _buildInitialAvatar(context, isDark),
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Name and Designation
          Text(
            employee.userName,
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            employee.designation ?? 'N/A',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: subTextColor,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: employee.status == 'Active'
                  ? Colors.green.withOpacity(0.1)
                  : employee.status == 'Inactive'
                      ? Colors.amber.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              employee.status == 'Deleted' ? 'Trash' : employee.status,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: employee.status == 'Active'
                    ? Colors.green
                    : employee.status == 'Inactive'
                        ? Colors.amber
                        : Colors.red,
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D1117) : Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: dividerColor),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildDetailRow(context, Icons.email_outlined, 'Email', employee.email, isDark),
                Divider(height: 24, color: dividerColor),
                _buildDetailRow(context, Icons.phone_outlined, 'Phone', employee.phoneNo ?? 'N/A', isDark),
                Divider(height: 24, color: dividerColor),
                _buildDetailRow(context, Icons.work_outline, 'Department', employee.department ?? 'N/A', isDark),
                Divider(height: 24, color: dividerColor),
                _buildDetailRow(context, Icons.access_time, 'Shift', employee.shift ?? 'N/A', isDark),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          // Allowed Geofences Section
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Allowed Geofences',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: textColor,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: employee.workLocations.isEmpty
                ? Text(
                    'All Locations (Universal Access)',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: subTextColor,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: employee.workLocations.map((loc) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: loc.isActive ? Colors.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: loc.isActive ? Colors.blue.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_on_outlined, 
                              size: 12, 
                              color: loc.isActive ? Colors.blue : Colors.grey
                            ),
                            const SizedBox(width: 4),
                            Text(
                              loc.name,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: loc.isActive 
                                    ? (isDark ? Colors.blue[300] : Colors.blue[700]) 
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
          
          if (isAdmin) ...[
            const SizedBox(height: 24),
            if (employee.status == 'Deleted') ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onRestore?.call();
                      },
                      icon: const Icon(Icons.restore, size: 18),
                      label: const Text('Restore'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onForceDelete?.call();
                      },
                      icon: const Icon(Icons.delete_forever, size: 18, color: Colors.white),
                      label: const Text('Force Delete', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onEdit();
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit Profile'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? const Color(0xFF58A6FF) : Theme.of(context).primaryColor,
                        side: BorderSide(
                          color: isDark ? const Color(0xFF30363D) : Theme.of(context).primaryColor.withOpacity(0.5),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onToggleStatus?.call();
                      },
                      icon: Icon(employee.isActive ? Icons.block : Icons.check_circle_outline, size: 18),
                      label: Text(employee.isActive ? 'Deactivate' : 'Activate'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: employee.isActive ? Colors.amber : Colors.green,
                        side: BorderSide(color: employee.isActive ? Colors.amber : Colors.green),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onDelete();
                  },
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.white),
                  label: const Text('Move to Trash', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDA3637),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildInitialAvatar(BuildContext context, bool isDark) {
    return Text(
      employee.userName.isNotEmpty ? employee.userName[0].toUpperCase() : '?',
      style: GoogleFonts.poppins(
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white : Theme.of(context).primaryColor,
        fontSize: 32,
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, IconData icon, String label, String value, bool isDark) {
    return Row(
      children: [
        Icon(
          icon, 
          size: 20, 
          color: isDark ? const Color(0xFF2F81F7) : Theme.of(context).primaryColor,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label, 
                style: GoogleFonts.poppins(
                  fontSize: 12, 
                  color: isDark ? const Color(0xFF8D96A0) : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
