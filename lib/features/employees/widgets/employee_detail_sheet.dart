import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application/shared/services/auth_service.dart';
import 'package:flutter_application/features/employees/core/employee_model.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';

class EmployeeDetailSheet extends StatefulWidget {
  final Employee employee;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onToggleStatus;
  final VoidCallback? onRestore;
  final VoidCallback? onForceDelete;
  final bool isDrawer;
  final VoidCallback? onClose;

  const EmployeeDetailSheet({
    super.key,
    required this.employee,
    required this.onEdit,
    required this.onDelete,
    this.onToggleStatus,
    this.onRestore,
    this.onForceDelete,
    this.isDrawer = false,
    this.onClose,
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
      constraints: const BoxConstraints(maxWidth: 540),
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
      barrierColor: Colors.black.withValues(alpha: 0.9),
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
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  State<EmployeeDetailSheet> createState() => _EmployeeDetailSheetState();
}

class _EmployeeDetailSheetState extends State<EmployeeDetailSheet> {
  int _selectedTab = 0; // 0: Profile, 1: Checklist, 2: Documents, 3: AI Audit

  late List<Map<String, dynamic>> _checklistTasks;

  @override
  void initState() {
    super.initState();
    _checklistTasks = [
      {'id': 1, 'title': 'National ID & Address Verification', 'done': true},
      {'id': 2, 'title': 'Signed Employment Agreement', 'done': true},
      {'id': 3, 'title': 'Work Email & IT Equipment Provisioning', 'done': true},
      {'id': 4, 'title': 'Bank Account & Tax Declarations', 'done': true},
      {'id': 5, 'title': 'Team Introduction & Induction Meeting', 'done': false},
    ];
  }

  void _dismiss() {
    if (widget.isDrawer) {
      widget.onClose?.call();
    } else {
      if (Navigator.canPop(context)) Navigator.pop(context);
    }
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

    final employee = widget.employee;

    return Container(
      height: widget.isDrawer ? double.infinity : MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: widget.isDrawer ? BorderRadius.zero : const BorderRadius.vertical(top: Radius.circular(24)),
        border: widget.isDrawer
            ? Border(left: BorderSide(color: dividerColor, width: 1))
            : Border(
                top: BorderSide(color: isDark ? const Color(0xFF30363D) : Colors.grey[300]!, width: 1),
              ),
      ),
      child: Column(
        children: [
          // Drag handle & Top Header
          Padding(
            padding: EdgeInsets.fromLTRB(16, widget.isDrawer ? 12 : 10, 16, 0),
            child: Column(
              children: [
                if (!widget.isDrawer) ...[
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF30363D) : Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                Row(
                  children: [
                    // Avatar
                    GestureDetector(
                      onTap: () {
                        if (employee.profileImage != null && employee.profileImage!.isNotEmpty) {
                          EmployeeDetailSheet.showFullscreenAvatar(context, employee.profileImage!, employee.userName);
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
                          radius: 20,
                          backgroundColor: isDark ? const Color(0xFF0D1117) : Theme.of(context).primaryColor.withValues(alpha: 0.1),
                          child: employee.profileImage != null && employee.profileImage!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(20),
                                  child: CachedNetworkImage(
                                    imageUrl: employee.profileImage!,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorWidget: (context, url, error) => _buildInitialAvatar(context, isDark),
                                    placeholder: (context, url) => _buildInitialAvatar(context, isDark),
                                  ),
                                )
                              : _buildInitialAvatar(context, isDark),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  employee.userName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: employee.status == 'Active'
                                      ? Colors.green.withValues(alpha: 0.12)
                                      : employee.status == 'Inactive'
                                          ? Colors.amber.withValues(alpha: 0.12)
                                          : Colors.red.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  employee.status == 'Deleted' ? 'Trash' : employee.status,
                                  style: GoogleFonts.poppins(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color: employee.status == 'Active'
                                        ? Colors.green
                                        : employee.status == 'Inactive'
                                            ? Colors.amber
                                            : Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            employee.designation != null && employee.designation!.isNotEmpty
                                ? '${employee.designation} • ${employee.department ?? "General"}'
                                : (employee.department ?? 'Employee Details'),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: subTextColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: _dismiss,
                      icon: Icon(Icons.close, size: 20, color: isDark ? Colors.white70 : Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Horizontal 4-Tab Bar (Profile, Checklist, Documents, AI Audit)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                _buildTabButton(0, 'Profile', Icons.person_outline, isDark),
                _buildTabButton(1, 'Checklist', Icons.checklist_outlined, isDark),
                _buildTabButton(2, 'Docs', Icons.folder_outlined, isDark),
                _buildTabButton(3, 'AI Audit', Icons.verified_outlined, isDark),
              ],
            ),
          ),

          const SizedBox(height: 8),
          Divider(height: 1, color: dividerColor),

          // Scrollable Tab Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: _buildTabBody(context, isDark, isAdmin, textColor, subTextColor, dividerColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String title, IconData icon, bool isDark) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF21262D) : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSelected
                    ? const Color(0xFF6366F1)
                    : (isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 4),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? Colors.white : const Color(0xFF0F172A))
                      : (isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBody(
    BuildContext context,
    bool isDark,
    bool isAdmin,
    Color textColor,
    Color? subTextColor,
    Color dividerColor,
  ) {
    final employee = widget.employee;

    switch (_selectedTab) {
      case 1:
        return _buildChecklistTab(isDark, textColor, subTextColor);
      case 2:
        return _buildDocumentsTab(isDark, textColor, subTextColor);
      case 3:
        return _buildAiAuditTab(isDark, textColor, subTextColor);
      case 0:
      default:
        return _buildProfileTab(context, isDark, isAdmin, textColor, subTextColor, dividerColor, employee);
    }
  }

  // ──────────────── 1. Profile Tab ────────────────
  Widget _buildProfileTab(
    BuildContext context,
    bool isDark,
    bool isAdmin,
    Color textColor,
    Color? subTextColor,
    Color dividerColor,
    Employee employee,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Contact & Work Details
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0D1117) : Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: dividerColor),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            children: [
              _buildDetailRow(context, Icons.email_outlined, 'Email', employee.email, isDark),
              Divider(height: 12, color: dividerColor),
              _buildDetailRow(context, Icons.phone_outlined, 'Phone', employee.phoneNo ?? 'N/A', isDark),
              Divider(height: 12, color: dividerColor),
              _buildDetailRow(context, Icons.work_outline, 'Department', employee.department ?? 'N/A', isDark),
              Divider(height: 12, color: dividerColor),
              _buildDetailRow(context, Icons.badge_outlined, 'Designation', employee.designation ?? 'N/A', isDark),
              Divider(height: 12, color: dividerColor),
              _buildDetailRow(context, Icons.access_time, 'Shift', employee.shift ?? 'Default Shift', isDark),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Allowed Geofences Section
        Text(
          'Allowed Geofences',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 12,
            color: textColor,
          ),
        ),
        const SizedBox(height: 6),
        employee.workLocations.isEmpty
            ? Text(
                'All Locations Authorized',
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  color: subTextColor,
                  fontStyle: FontStyle.italic,
                ),
              )
            : Wrap(
                spacing: 6,
                runSpacing: 5,
                children: employee.workLocations.map((loc) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: loc.isActive ? Colors.blue.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: loc.isActive ? Colors.blue.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 11,
                          color: loc.isActive ? Colors.blue : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          loc.name,
                          style: GoogleFonts.poppins(
                            fontSize: 10,
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

        const SizedBox(height: 16),

        // Admin Action Buttons
        if (isAdmin) ...[
          if (employee.status == 'Deleted') ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _dismiss();
                      widget.onRestore?.call();
                    },
                    icon: const Icon(Icons.restore, size: 15),
                    label: const Text('Restore', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _dismiss();
                      widget.onForceDelete?.call();
                    },
                    icon: const Icon(Icons.delete_forever, size: 15, color: Colors.white),
                    label: const Text('Force Delete', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                      _dismiss();
                      widget.onEdit();
                    },
                    icon: const Icon(Icons.edit_outlined, size: 15),
                    label: const Text('Edit Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? const Color(0xFF58A6FF) : Theme.of(context).primaryColor,
                      side: BorderSide(
                        color: isDark ? const Color(0xFF30363D) : Theme.of(context).primaryColor.withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _dismiss();
                      widget.onToggleStatus?.call();
                    },
                    icon: Icon(employee.isActive ? Icons.block : Icons.check_circle_outline, size: 15),
                    label: Text(employee.isActive ? 'Deactivate' : 'Activate', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: employee.isActive ? Colors.amber : Colors.green,
                      side: BorderSide(color: employee.isActive ? Colors.amber : Colors.green),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  _dismiss();
                  widget.onDelete();
                },
                icon: const Icon(Icons.delete_outline, size: 15, color: Colors.white),
                label: const Text('Move to Trash', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDA3637),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  // ──────────────── 2. Checklist Tab ────────────────
  Widget _buildChecklistTab(bool isDark, Color textColor, Color? subTextColor) {
    final completedCount = _checklistTasks.where((t) => t['done'] == true).length;
    final totalCount = _checklistTasks.length;
    final pct = totalCount > 0 ? (completedCount / totalCount) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress Summary Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Onboarding Progress',
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
                  ),
                  Text(
                    '${(pct * 100).toInt()}%',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 6,
                  backgroundColor: isDark ? const Color(0xFF21262D) : const Color(0xFFE2E8F0),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$completedCount of $totalCount steps completed',
                style: GoogleFonts.poppins(fontSize: 10.5, color: subTextColor),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),
        Text(
          'Onboarding Checklist Tasks',
          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
        ),
        const SizedBox(height: 6),

        // Tasks list
        ..._checklistTasks.map((task) {
          final isDone = task['done'] == true;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D1117) : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDone
                    ? const Color(0xFF10B981).withValues(alpha: 0.3)
                    : (isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
              ),
            ),
            child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              leading: Checkbox(
                value: isDone,
                activeColor: const Color(0xFF10B981),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                onChanged: (val) {
                  setState(() {
                    task['done'] = val ?? false;
                  });
                },
              ),
              title: Text(
                task['title'],
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: isDone
                      ? (isDark ? Colors.white60 : Colors.black54)
                      : (isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: isDone ? TextDecoration.lineThrough : null,
                ),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isDone
                      ? const Color(0xFF10B981).withValues(alpha: 0.12)
                      : Colors.grey.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isDone ? 'Completed' : 'Pending',
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                    color: isDone ? const Color(0xFF10B981) : Colors.grey,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // ──────────────── 3. Documents Tab ────────────────
  Widget _buildDocumentsTab(bool isDark, Color textColor, Color? subTextColor) {
    final docs = [
      {'name': 'National ID Card (Aadhaar / Passport)', 'category': 'Identity', 'size': '1.4 MB', 'status': 'Verified'},
      {'name': 'Highest Educational Degree Certificate', 'category': 'Education', 'size': '2.1 MB', 'status': 'Verified'},
      {'name': 'Previous Relieving Letter & Experience', 'category': 'Work History', 'size': '890 KB', 'status': 'Verified'},
      {'name': 'Bank Passbook Copy / Voided Cheque', 'category': 'Payroll', 'size': '640 KB', 'status': 'Verified'},
      {'name': 'Signed Offer Letter & Confidentiality', 'category': 'Legal', 'size': '1.8 MB', 'status': 'Verified'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Employee Documents (${docs.length})',
              style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
            ),
            OutlinedButton.icon(
              onPressed: () {
                context.showToast('Document upload modal ready');
              },
              icon: const Icon(Icons.upload_file_outlined, size: 14),
              label: const Text('Upload Doc', style: TextStyle(fontSize: 11)),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        ...docs.map((d) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFF6366F1), size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d['name']!,
                        style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600, color: textColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${d['category']} • ${d['size']}',
                        style: GoogleFonts.poppins(fontSize: 10, color: subTextColor),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    d['status']!,
                    style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w600, color: const Color(0xFF10B981)),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ──────────────── 4. AI Audit Tab ────────────────
  Widget _buildAiAuditTab(bool isDark, Color textColor, Color? subTextColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Overall Auditor Score Banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF0F2027), const Color(0xFF203A43)]
                  : [const Color(0xFFF0FDF4), const Color(0xFFDCFCE7)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF10B981),
                ),
                child: const Center(
                  child: Icon(Icons.verified_user, color: Colors.white, size: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Authenticity Score: 96%',
                      style: GoogleFonts.poppins(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF065F46),
                      ),
                    ),
                    Text(
                      'High Confidence • All integrity checks passed',
                      style: GoogleFonts.poppins(
                        fontSize: 10.5,
                        color: isDark ? const Color(0xFF86EFAC) : const Color(0xFF047857),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),
        Text(
          'Automated Security Checks',
          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
        ),
        const SizedBox(height: 6),

        _buildAuditCheckItem('Hologram & Security Seal', 'Verified Authentic', true, isDark),
        _buildAuditCheckItem('Legibility & Blur Analysis', 'Crystal Clear (98% sharpness)', true, isDark),
        _buildAuditCheckItem('EXIF & Creation Metadata', 'Unmodified original file', true, isDark),
        _buildAuditCheckItem('Digital Manipulation / Photoshop', 'None Detected', true, isDark),

        const SizedBox(height: 14),
        Text(
          'Extracted OCR Metadata',
          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
        ),
        const SizedBox(height: 6),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0D1117) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              _buildOcrRow('Name Match', '100% Match with HR record', isDark),
              Divider(height: 10, color: isDark ? const Color(0xFF21262D) : Colors.grey[200]!),
              _buildOcrRow('Document Number', 'Verified Active against Registry', isDark),
              Divider(height: 10, color: isDark ? const Color(0xFF21262D) : Colors.grey[200]!),
              _buildOcrRow('Document Validity', 'Valid (Expires 2031)', isDark),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAuditCheckItem(String title, String detail, bool passed, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: passed
              ? const Color(0xFF10B981).withValues(alpha: 0.3)
              : Colors.red.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            passed ? Icons.check_circle_outline : Icons.cancel_outlined,
            size: 16,
            color: passed ? const Color(0xFF10B981) : Colors.red,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
                ),
                Text(
                  detail,
                  style: GoogleFonts.poppins(fontSize: 9.5, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOcrRow(String label, String value, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 10.5, color: Colors.grey)),
        Text(value, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF10B981))),
      ],
    );
  }

  Widget _buildInitialAvatar(BuildContext context, bool isDark) {
    return Text(
      widget.employee.userName.isNotEmpty ? widget.employee.userName[0].toUpperCase() : '?',
      style: GoogleFonts.poppins(
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : Theme.of(context).primaryColor,
        fontSize: 18,
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, IconData icon, String label, String value, bool isDark) {
    return Row(
      children: [
        Icon(
          icon,
          size: 15,
          color: isDark ? const Color(0xFF2F81F7) : Theme.of(context).primaryColor,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: isDark ? const Color(0xFF8D96A0) : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
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

// [mod:2026-02-21T11:00:00+05:30]

// [upd:2026-05-04T17:00:00+05:30]
