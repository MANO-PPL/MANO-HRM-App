import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:flutter_application/shared/widgets/glass_container.dart';
import 'package:flutter_application/features/employees/core/employee_model.dart';
import 'package:flutter_application/features/employees/core/employee_service.dart';
import 'package:flutter_application/shared/services/auth_service.dart';
import 'package:flutter_application/features/employees/widgets/add_employee_view.dart';
import 'package:flutter_application/features/employees/widgets/bulk_upload_report_dialog.dart';
import 'package:flutter_application/features/employees/widgets/glass_confirmation_dialog.dart';
import 'package:flutter_application/features/employees/widgets/employee_detail_sheet.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';
import 'package:flutter_application/shared/widgets/loading_screen.dart';

class EmployeesView extends StatefulWidget {
  const EmployeesView({super.key});

  @override
  State<EmployeesView> createState() => _EmployeesViewState();
}

class _EmployeesViewState extends State<EmployeesView> {
  late EmployeeService _employeeService;
  List<Employee> _employees = [];
  List<Employee> _filteredEmployees = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _statusFilter = 'Active';
  Employee? _editingEmployee;
  bool _isAddingOrEditing = false;
  Set<int> _selectedIds = {};
  bool _isSelectionMode = false;

  bool _isDrawerOpen = false;
  Employee? _selectedEmployeeForDrawer;

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    _employeeService = EmployeeService(authService);
    _fetchEmployees();
  }

  Future<void> _fetchEmployees() async {
    setState(() => _isLoading = true);
    try {
      final employees = await _employeeService.getEmployees();
      setState(() {
        _employees = employees;
        _filterEmployees();
        _isLoading = false;
        _selectedIds.clear(); // Clear selection on refresh
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        context.showToast('Error: $e', isError: true);
      }
    }
  }

  void _filterEmployees() {
    List<Employee> filtered = _employees;

    // 1. Search Query filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((e) =>
        e.userName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        e.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        (e.phoneNo?.contains(_searchQuery) ?? false)
      ).toList();
    }

    // 2. Status Tab filter
    filtered = filtered.where((e) => e.status == _statusFilter).toList();

    // 3. Alphabetical sort by user_name
    filtered.sort((a, b) => a.userName.toLowerCase().compareTo(b.userName.toLowerCase()));

    setState(() {
      _filteredEmployees = filtered;
    });
  }

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleSelectAll(bool? value) {
    setState(() {
      if (value == true) {
        _selectedIds = _filteredEmployees.map((e) => e.userId).toSet();
      } else {
        _selectedIds.clear();
        _isSelectionMode = false;
      }
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectedIds.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _bulkDelete() async {
    if (_selectedIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => GlassConfirmationDialog(
        title: 'Confirm Bulk Delete',
        content: 'Are you sure you want to delete ${_selectedIds.length} employees?',
        confirmLabel: 'Delete',
        onConfirm: () => Navigator.pop(context, true),
      ),
    );

    if (confirm != true) return;

    // Show loading dialog
    if (!mounted) return;
    showDialog(
      context: context, 
      barrierDismissible: false, 
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );

    try {
      await _employeeService.bulkDeleteEmployees(_selectedIds.toList());
      
      if (!mounted) return;
      
      // Close Loading with defensive pop
      if (Navigator.canPop(context)) Navigator.pop(context);

      setState(() {
        _selectedIds.clear();
        _isDrawerOpen = false;
      });
      _fetchEmployees(); // Refresh list
      context.showToast('Selected employees deleted', isSuccess: true);
    } catch (e) {
      if (!mounted) return;
      if (Navigator.canPop(context)) Navigator.pop(context); // Close loading
      context.showToast('Failed to delete: $e', isError: true);
    }
  }

  Future<void> _deleteEmployee(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => GlassConfirmationDialog(
        title: 'Move to Trash',
        content: 'Are you sure you want to move this employee to trash? They will remain inactive until restored.',
        confirmLabel: 'Move to Trash',
        onConfirm: () => Navigator.pop(context, true),
      ),
    );

    if (confirm != true) return;

    try {
      await _employeeService.deleteEmployee(id);
      _fetchEmployees(); // Refresh list
      setState(() {
        _isDrawerOpen = false;
      });
      if (!mounted) return;
      context.showToast('Employee moved to trash', isSuccess: true);
    } catch (e) {
      if (!mounted) return;
      context.showToast('Failed to delete: $e', isError: true);
    }
  }

  Future<void> _toggleStatus(Employee employee) async {
    final newStatus = !employee.isActive;
    final action = newStatus ? "activate" : "deactivate";

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => GlassConfirmationDialog(
        title: '${newStatus ? "Activate" : "Deactivate"} Employee',
        content: 'Are you sure you want to $action ${employee.userName}?',
        confirmLabel: newStatus ? 'Activate' : 'Deactivate',
        onConfirm: () => Navigator.pop(context, true),
      ),
    );

    if (confirm != true) return;

    try {
      await _employeeService.toggleUserStatus(employee.userId, newStatus);
      _fetchEmployees();
      setState(() {
        _isDrawerOpen = false;
      });
      if (!mounted) return;
      context.showToast('Employee ${action}d successfully', isSuccess: true);
    } catch (e) {
      if (!mounted) return;
      context.showToast('Failed to update status: $e', isError: true);
    }
  }

  Future<void> _restoreEmployee(Employee employee) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => GlassConfirmationDialog(
        title: 'Restore Employee',
        content: 'Are you sure you want to restore ${employee.userName} from trash?',
        confirmLabel: 'Restore',
        onConfirm: () => Navigator.pop(context, true),
      ),
    );

    if (confirm != true) return;

    try {
      await _employeeService.restoreUser(employee.userId);
      _fetchEmployees();
      setState(() {
        _isDrawerOpen = false;
      });
      if (!mounted) return;
      context.showToast('Employee restored from trash', isSuccess: true);
    } catch (e) {
      if (!mounted) return;
      context.showToast('Failed to restore employee: $e', isError: true);
    }
  }

  Future<void> _forceDeleteEmployee(Employee employee) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => GlassConfirmationDialog(
        title: 'Permanently Delete',
        content: 'WARNING: This will permanently delete ${employee.userName} and cascade across all attendance records, leave requests, and logs. This action CANNOT be undone. Proceed?',
        confirmLabel: 'Delete Permanently',
        onConfirm: () => Navigator.pop(context, true),
      ),
    );

    if (confirm != true) return;

    try {
      await _employeeService.forceDeleteUser(employee.userId);
      _fetchEmployees();
      setState(() {
        _isDrawerOpen = false;
      });
      if (!mounted) return;
      context.showToast('Employee permanently deleted', isSuccess: true);
    } catch (e) {
      if (!mounted) return;
      context.showToast('Failed to permanently delete: $e', isError: true);
    }
  }

  Future<void> _downloadSampleTemplate() async {
    try {
      String path;
      if (Platform.isAndroid) {
        path = '/storage/emulated/0/Download/attendance_template.csv';
      } else {
        final dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
        path = '${dir.path}/attendance_template.csv';
      }
      
      final file = File(path);
      await file.writeAsString("Name,Email,Phone,Department,Designation,Password\n"
          "John Doe,john.doe@example.com,9876543210,Engineering,Manager,Mano@123\n"
          "Jane Smith,jane.smith@example.com,9876543211,Human Resources,HR Executive,Mano@123\n"
          "Alice Johnson,alice.j@example.com,9876543212,Sales,Sales Executive,Mano@123");
      
      if (!mounted) return;
      context.showToast('Template saved to $path', isSuccess: true);
    } catch (e) {
      if (!mounted) return;
      context.showToast('Failed to save template: $e', isError: true);
    }
  }

  Future<void> _handleBulkUpload() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
      );

      if (result != null) {
        final file = File(result.files.single.path!);
        
        if (file.lengthSync() > 5 * 1024 * 1024) {
          if (!mounted) return;
          context.showToast('File is too large. Max size is 5MB.', isWarning: true);
          return;
        }

        if (!mounted) return;
        
        showDialog(
          context: context, 
          barrierDismissible: false, 
          builder: (_) => const PopScope(
            canPop: false,
            child: Center(child: CircularProgressIndicator()),
          ),
        );
        
        try {
          final response = await _employeeService.bulkUploadUsers(file);
          
          if (!mounted) return;
          final nav = Navigator.of(context, rootNavigator: true);
          if (nav.canPop()) {
            nav.pop();
          }
          
          final report = response['report'];
          if (report != null) {
            await showDialog(
              context: context,
              builder: (context) => BulkUploadReportDialog(
                report: report,
              ),
            );
            _fetchEmployees();
          } else {
             context.showToast('Bulk Upload Processed (No Report)', isSuccess: true);
             _fetchEmployees();
          }
        } catch (e) {
             if (!mounted) return;
             final nav = Navigator.of(context, rootNavigator: true);
             if (nav.canPop()) {
               nav.pop();
             }
             
             String message = 'Upload Failed: $e';
             if (e.toString().contains('413') || e.toString().contains('Payload Too Large')) {
                message = 'File is too large for the server. Please check the file size limits.';
             }
             context.showToast(message, isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        context.showToast('Upload Failed: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAddingOrEditing) {
      return AddEmployeeView(
        employeeToEdit: _editingEmployee,
        onCancel: () {
          setState(() {
            _isAddingOrEditing = false;
            _editingEmployee = null;
          });
        },
        onSuccess: () {
          setState(() {
            _isAddingOrEditing = false;
            _editingEmployee = null;
          });
          _fetchEmployees();
        },
      );
    }

    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return LoadingScreen(
      isLoading: _isLoading,
      message: "Loading employees...",
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                _buildFilterSection(context),
                const SizedBox(height: 12),

                _employees.isEmpty && _isLoading
                    ? const SizedBox.shrink()
                    : _buildEmployeesTable(context),
                
                if (!_isLoading || _employees.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildPagination(context),
                ],
              ],
            ),
          ),
          if (isLandscape)
            _buildRightDrawer(context),
        ],
      ),
    );
  }

  Widget _buildStatusTabs(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final containerBg = isDark ? const Color(0xFF161B22) : const Color(0xFFF1F5F9);
    final activeBg = isDark ? const Color(0xFF2D3139) : Colors.white;
    final activeColor = isDark ? Colors.white : const Color(0xFF4F46E5);
    final inactiveColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['Active', 'Inactive', 'Deleted'].map((status) {
          final isSelected = _statusFilter == status;
          IconData iconData;
          String label;
          switch (status) {
            case 'Active':
              iconData = Icons.check_circle_outline_rounded;
              label = 'Active';
              break;
            case 'Inactive':
              iconData = Icons.remove_circle_outline_rounded;
              label = 'Inactive';
              break;
            case 'Deleted':
            default:
              iconData = Icons.delete_outline_rounded;
              label = 'Trash';
              break;
          }

          return InkWell(
            onTap: () {
              setState(() {
                _statusFilter = status;
                _filterEmployees();
                _isDrawerOpen = false; // Close drawer when tab changes
              });
            },
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? activeBg : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? (isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0))
                      : Colors.transparent,
                  width: 1,
                ),
                boxShadow: isSelected && !isDark
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
              child: Row(
                children: [
                  Icon(
                    iconData,
                    size: 15,
                    color: isSelected ? activeColor : inactiveColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? activeColor : inactiveColor,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFilterSection(BuildContext context) {
    if (_isSelectionMode) {
      return Row(
        children: [
          IconButton(
            onPressed: _exitSelectionMode, 
            icon: const Icon(Icons.close),
            tooltip: 'Exit Selection',
          ),
          const SizedBox(width: 8),
          Text(
            '${_selectedIds.length} Selected',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: () => _toggleSelectAll(_selectedIds.length != _filteredEmployees.length),
            icon: Icon(_selectedIds.length == _filteredEmployees.length ? Icons.deselect : Icons.select_all, size: 18),
            label: Text(
              _selectedIds.length == _filteredEmployees.length ? 'Unselect All' : 'Select All',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          const SizedBox(width: 12),
          _buildActionButton(
            context,
            label: 'Delete Selected',
            icon: Icons.delete_outline,
            isPrimary: false,
            onTap: _bulkDelete,
          ),
        ],
      );
    }

    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: GlassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                height: 42,
                borderRadius: 12,
                child: Row(
                  children: [
                    Icon(Icons.search, color: Theme.of(context).textTheme.bodySmall?.color, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        onChanged: (val) {
                          _searchQuery = val;
                          _filterEmployees();
                        },
                        decoration: InputDecoration(
                          hintText: 'Search employees...',
                          hintStyle: GoogleFonts.poppins(
                            color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                            fontSize: 13,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.only(bottom: 6),
                          isDense: true,
                        ),
                        style: GoogleFonts.poppins(
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            _buildStatusTabs(context),
          ],
        ),
        const SizedBox(height: 10),
        if (!Provider.of<AuthService>(context, listen: false).user!.isEmployee)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildActionButton(
                context, 
                label: 'Template', 
                icon: Icons.download,
                isPrimary: false,
                isCompact: isLandscape ? false : true, 
                onTap: _downloadSampleTemplate,
              ),
              const SizedBox(width: 10),
              _buildActionButton(
                context, 
                label: 'Bulk Upload', 
                icon: Icons.upload_file_outlined,
                isPrimary: false,
                isCompact: isLandscape ? false : true, 
                onTap: _handleBulkUpload,
              ),
              const SizedBox(width: 10),
              _buildActionButton(
                context, 
                label: 'Add Employee', 
                icon: Icons.add,
                isPrimary: true,
                onTap: () {
                  setState(() {
                    _editingEmployee = null;
                    _isAddingOrEditing = true;
                  });
                },
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, {
    required String label, 
    required IconData icon, 
    required bool isPrimary,
    bool isCompact = false,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return InkWell(
      onTap: onTap,
      child: Container(
        height: 40,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isPrimary ? primaryColor : (isDark ? const Color(0xFF161B22) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: isPrimary ? null : Border.all(
            color: isDark ? const Color(0xFF30363D) : primaryColor.withValues(alpha: 0.1)
          ),
          boxShadow: isPrimary ? [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            )
          ] : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon, 
              color: isPrimary ? Colors.white : (isDark ? Colors.white : primaryColor),
              size: 18,
            ),
             if (!isCompact) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: isPrimary ? Colors.white : (isDark ? Colors.white : primaryColor),
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeesTable(BuildContext context) {
    if (_filteredEmployees.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Text('No employees found', style: GoogleFonts.poppins(color: Colors.grey)),
      ));
    }

    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
  
    return GlassContainer(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: double.infinity,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.transparent),
            headingRowHeight: 40,
            dataRowMinHeight: 42,
            dataRowMaxHeight: 48,
            columnSpacing: 12, 
            horizontalMargin: 12, 
            showCheckboxColumn: false,
            columns: [
              if (_isSelectionMode)
                DataColumn(
                  label: Checkbox(
                    value: _filteredEmployees.isNotEmpty && _selectedIds.length == _filteredEmployees.length,
                    onChanged: (val) => _toggleSelectAll(val),
                    activeColor: Theme.of(context).primaryColor,
                    side: BorderSide(color: Theme.of(context).disabledColor),
                  ),
                ),
              _buildDataColumn(context, 'EMPLOYEE'),
              _buildDataColumn(context, 'ROLE & DEPT'),
              if (isLandscape) ...[
                _buildDataColumn(context, 'PHONE'),
                _buildDataColumn(context, 'SHIFT'),
              ],
              _buildDataColumn(context, 'GEOFENCES'),
              if (!Provider.of<AuthService>(context, listen: false).user!.isEmployee)
                 const DataColumn(label: Expanded(child: Text('ACTIONS', textAlign: TextAlign.right))), 
            ],
            rows: _filteredEmployees.map((e) => _buildDataRow(context, e)).toList(),
          ),
        ),
      ),
    );
  }

  DataColumn _buildDataColumn(BuildContext context, String label) {
    return DataColumn(
      label: Text(
        label,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: 11,
          letterSpacing: 0.5,
          color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  DataRow _buildDataRow(BuildContext context, Employee data) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subTextColor = Theme.of(context).textTheme.bodySmall?.color;
    final nameInitial = data.userName.isNotEmpty ? data.userName[0].toUpperCase() : '?';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return DataRow(
      onLongPress: () {
        if (!_isSelectionMode && !Provider.of<AuthService>(context, listen: false).user!.isEmployee) {
          setState(() {
            _isSelectionMode = true;
            _toggleSelection(data.userId);
          });
        }
      },
      onSelectChanged: (_) {
        if (_isSelectionMode) {
          _toggleSelection(data.userId);
        } else {
          _showEmployeeDetails(context, data);
        }
      },
      cells: [
        if (_isSelectionMode)
          DataCell(
            Checkbox(
              value: _selectedIds.contains(data.userId),
              onChanged: (val) => _toggleSelection(data.userId),
              activeColor: Theme.of(context).primaryColor,
              side: BorderSide(color: Theme.of(context).disabledColor),
            ),
          ),
        // Employee
        DataCell(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: isDark ? Border.all(color: Colors.blue, width: 1.5) : null,
                  ),
                  child: CircleAvatar(
                    radius: 15,
                    backgroundColor: isDark ? const Color(0xFF0D1117) : Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    child: data.profileImage != null && data.profileImage!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: CachedNetworkImage(
                              imageUrl: data.profileImage!,
                              width: 30,
                              height: 30,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) => Text(
                                nameInitial,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600, 
                                  color: isDark ? Colors.white : Theme.of(context).primaryColor,
                                  fontSize: 12,
                                ),
                              ),
                              placeholder: (context, url) => Text(
                                nameInitial,
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600, 
                                  color: isDark ? Colors.white : Theme.of(context).primaryColor,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          )
                        : Text(
                            nameInitial,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600, 
                              color: isDark ? Colors.white : Theme.of(context).primaryColor,
                              fontSize: 12,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(data.userName, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: textColor, fontSize: 13)),
                    Text(data.email, style: GoogleFonts.poppins(fontSize: 11, color: subTextColor)),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Role & Dept
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(data.designation ?? 'N/A', style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.w500, fontSize: 12)),
              const SizedBox(height: 1),
              Text(data.department ?? 'N/A', style: GoogleFonts.poppins(fontSize: 10.5, color: subTextColor)),
            ],
          ),
        ),
        // Phone
        if (isLandscape)
          DataCell(Text(data.phoneNo ?? 'N/A', style: GoogleFonts.poppins(fontSize: 12, color: subTextColor))),
        // Shift
        if (isLandscape)
          DataCell(Text(data.shift ?? 'N/A', style: GoogleFonts.poppins(fontSize: 12, color: subTextColor))),
        // Geofences
        DataCell(
          data.workLocations.isEmpty
              ? Text('All Locations', style: GoogleFonts.poppins(fontSize: 11.5, color: subTextColor))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: data.workLocations.take(2).map<Widget>((loc) {
                      return Container(
                        margin: const EdgeInsets.only(right: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          loc.name,
                          style: GoogleFonts.poppins(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.w500),
                        ),
                      );
                    }).toList()
                    ..addAll(data.workLocations.length > 2 
                        ? [Text(' +${data.workLocations.length - 2}', style: GoogleFonts.poppins(fontSize: 10, color: subTextColor))]
                        : []),
                  ),
                ),
        ),
        // Actions
        if (!Provider.of<AuthService>(context, listen: false).user!.isEmployee)
          DataCell(Align(alignment: Alignment.centerRight, child: _buildActionsMenu(context, data))),
      ],
    );
  }

  Widget _buildActionsMenu(BuildContext context, Employee employee) {
    return IconButton(
      icon: Icon(Icons.more_vert, color: Theme.of(context).textTheme.bodySmall?.color),
      onPressed: () => _showEmployeeDetails(context, employee),
    );
  }

  void _showEmployeeDetails(BuildContext context, Employee employee) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    if (isLandscape) {
      setState(() {
        _selectedEmployeeForDrawer = employee;
        _isDrawerOpen = true;
      });
    } else {
      EmployeeDetailSheet.show(
        context,
        employee: employee,
        onEdit: () {
          setState(() {
            _editingEmployee = employee;
            _isAddingOrEditing = true;
          });
        },
        onDelete: () => _deleteEmployee(employee.userId),
        onToggleStatus: () => _toggleStatus(employee),
        onRestore: () => _restoreEmployee(employee),
        onForceDelete: () => _forceDeleteEmployee(employee),
      );
    }
  }

  Widget _buildRightDrawer(BuildContext context) {
    final employee = _selectedEmployeeForDrawer;
    if (employee == null) return const SizedBox.shrink();

    return Stack(
      children: [
        if (_isDrawerOpen)
          GestureDetector(
            onTap: () {
              setState(() {
                _isDrawerOpen = false;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              color: Colors.black.withValues(alpha: 0.4),
            ),
          ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          right: _isDrawerOpen ? 0 : -440,
          top: 0,
          bottom: 0,
          width: 440,
          child: Container(
            decoration: const BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 16,
                  offset: Offset(-4, 0),
                ),
              ],
            ),
            child: SafeArea(
              child: EmployeeDetailSheet(
                employee: employee,
                isDrawer: true,
                onClose: () {
                  setState(() {
                    _isDrawerOpen = false;
                  });
                },
                onEdit: () {
                  setState(() {
                    _isDrawerOpen = false;
                    _editingEmployee = employee;
                    _isAddingOrEditing = true;
                  });
                },
                onDelete: () => _deleteEmployee(employee.userId),
                onToggleStatus: () => _toggleStatus(employee),
                onRestore: () => _restoreEmployee(employee),
                onForceDelete: () => _forceDeleteEmployee(employee),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPagination(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Showing ${_filteredEmployees.length} results', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey)),
        const Row(children: [Icon(Icons.chevron_left, size: 20), Icon(Icons.chevron_right, size: 20)]),
      ],
    );
  }
}

// [mod:2026-02-21T17:00:00+05:30]
