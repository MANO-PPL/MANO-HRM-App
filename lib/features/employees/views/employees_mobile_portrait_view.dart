import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
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

class EmployeesMobileView extends StatefulWidget {
  const EmployeesMobileView({super.key});

  @override
  State<EmployeesMobileView> createState() => _EmployeesMobileViewState();
}

class _EmployeesMobileViewState extends State<EmployeesMobileView> {
  late EmployeeService _employeeService;
  List<Employee> _employees = [];
  List<Employee> _filteredEmployees = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _statusFilter = 'Active';
  Employee? _selectedEmployeeForPane;
  
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
      if (!mounted) return;
      setState(() {
        _employees = employees;
        _filterEmployees();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      context.showToast('Error: $e', isError: true);
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
      // Keep selected employee if still in filtered list
      if (_selectedEmployeeForPane != null) {
        final matches = filtered.where((e) => e.userId == _selectedEmployeeForPane!.userId);
        if (matches.isEmpty) {
          _selectedEmployeeForPane = null;
        } else {
          _selectedEmployeeForPane = matches.first;
        }
      }
    });
  }

  Set<int> _selectedIds = {};
  bool _isSelectionMode = false;

  void _toggleSelection(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectedIds.length == _filteredEmployees.length) {
        _selectedIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedIds = _filteredEmployees.map((e) => e.userId).toSet();
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
      if (Navigator.canPop(context)) Navigator.pop(context); // Close loading

      _exitSelectionMode();
      _selectedEmployeeForPane = null;
      _fetchEmployees();
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
      _fetchEmployees();
      setState(() {
        _selectedEmployeeForPane = null;
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
      if (employee.userId == _selectedEmployeeForPane?.userId) {
        final updated = await _employeeService.getEmployee(employee.userId);
        setState(() {
          _selectedEmployeeForPane = updated;
        });
      }
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
        _selectedEmployeeForPane = null;
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
        _selectedEmployeeForPane = null;
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
    await [
      Permission.storage,
    ].request();

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
                message = 'File is too large for the server. Please try a smaller file.';
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

  void _navigateToAddEdit({Employee? employee}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF161B22) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              automaticallyImplyLeading: false,
              title: Text(
                employee == null ? 'Add Employee' : 'Edit Employee',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
            body: AddEmployeeView(
              employeeToEdit: employee,
              onCancel: () => Navigator.pop(context),
              onSuccess: () {
                Navigator.pop(context);
                _fetchEmployees();
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? const Color(0xFF30363D) : Colors.grey[200]!;

    Widget mainListContent = Column(
      children: [
        _buildHeader(context),
        _buildStatusTabs(context),
        const SizedBox(height: 4),
        Expanded(
          child: _employees.isEmpty && _isLoading
              ? const SizedBox.shrink()
              : (_filteredEmployees.isEmpty 
                  ? const Center(child: Text('No employees found'))
                  : _buildEmployeeList(context)),
        ),
      ],
    );

    return Scaffold(
      floatingActionButton: Provider.of<AuthService>(context, listen: false).user!.isEmployee 
          ? null 
          : FloatingActionButton(
              onPressed: () => _navigateToAddEdit(),
              backgroundColor: Theme.of(context).primaryColor,
              child: const Icon(Icons.add, color: Colors.white),
            ),
      body: LoadingScreen(
        isLoading: _isLoading,
        message: "Loading employees...",
        child: isLandscape
            ? Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: mainListContent,
                  ),
                  VerticalDivider(width: 1, color: dividerColor),
                  Expanded(
                    flex: 4,
                    child: _selectedEmployeeForPane == null
                        ? Center(
                            child: Text(
                              'Select an employee to view details',
                              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
                            ),
                          )
                        : _buildDetailPane(context, _selectedEmployeeForPane!),
                  ),
                ],
              )
            : mainListContent,
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
      child: _isSelectionMode 
          ? Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _exitSelectionMode,
                ),
                const SizedBox(width: 8),
                Text('${_selectedIds.length} Selected', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                const Spacer(),
                TextButton(
                  onPressed: _toggleSelectAll,
                  child: Text(
                    _selectedIds.length == _filteredEmployees.length ? 'Unselect All' : 'Select All',
                    style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: _bulkDelete,
                ),
              ],
            )
          : Row(
              children: [
                Expanded(
                  child: GlassContainer(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.search, size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        Expanded(
                          child: TextField(
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val;
                                _filterEmployees();
                              });
                            },
                            decoration: const InputDecoration(
                              hintText: 'Search employees...',
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                            ),
                            style: GoogleFonts.poppins(fontSize: 12),
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _searchQuery = '';
                                _filterEmployees();
                              });
                            },
                            child: const Icon(Icons.close, size: 14, color: Colors.grey),
                          ),
                      ],
                    ),
                  ),
                ),
                if (!Provider.of<AuthService>(context, listen: false).user!.isEmployee) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: _downloadSampleTemplate, 
                    icon: const Icon(Icons.download, size: 18),
                    tooltip: 'Download Template',
                    constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                    padding: EdgeInsets.zero,
                  ),
                  IconButton(
                    onPressed: _handleBulkUpload, 
                    icon: const Icon(Icons.upload_file, size: 18),
                    tooltip: 'Bulk Upload',
                    constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                    padding: EdgeInsets.zero,
                  ),
                ],
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: containerBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? const Color(0xFF30363D) : Colors.black.withValues(alpha: 0.05),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
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

            return Expanded(
              child: InkWell(
                onTap: () {
                  setState(() {
                    _statusFilter = status;
                    _filterEmployees();
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? activeBg : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
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
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        iconData,
                        size: 13,
                        color: isSelected ? activeColor : inactiveColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        label,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? activeColor : inactiveColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmployeeList(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 2, bottom: 72),
      itemCount: _filteredEmployees.length,
      itemBuilder: (context, index) {
        final emp = _filteredEmployees[index];
        final isSelected = _selectedIds.contains(emp.userId);
        final isDark = Theme.of(context).brightness == Brightness.dark;

        final hasDesignation = emp.designation != null && emp.designation!.isNotEmpty;
        final hasPhone = emp.phoneNo != null && emp.phoneNo!.isNotEmpty;

        final childContent = ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          leading: _isSelectionMode
              ? Checkbox(
                  value: isSelected,
                  onChanged: (_) => _toggleSelection(emp.userId),
                  activeColor: Theme.of(context).primaryColor,
                )
              : GestureDetector(
                  onTap: () {
                    if (emp.profileImage != null && emp.profileImage!.isNotEmpty) {
                      EmployeeDetailSheet.showFullscreenAvatar(context, emp.profileImage!, emp.userName);
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: isDark ? Border.all(color: Colors.blue, width: 1.5) : null,
                    ),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: isDark ? const Color(0xFF30363D) : Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      child: emp.profileImage != null && emp.profileImage!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: CachedNetworkImage(
                                imageUrl: emp.profileImage!,
                                width: 36,
                                height: 36,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) => Text(
                                  emp.userName.isNotEmpty ? emp.userName[0].toUpperCase() : '?',
                                  style: TextStyle(color: isDark ? Colors.white : Theme.of(context).primaryColor, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                placeholder: (context, url) => Text(
                                  emp.userName.isNotEmpty ? emp.userName[0].toUpperCase() : '?',
                                  style: TextStyle(color: isDark ? Colors.white : Theme.of(context).primaryColor, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                            )
                          : Text(
                              emp.userName.isNotEmpty ? emp.userName[0].toUpperCase() : '?',
                              style: TextStyle(color: isDark ? Colors.white : Theme.of(context).primaryColor, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ),
          title: Text(
            emp.userName, 
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: isDark ? Colors.white : null),
          ),
          subtitle: (hasDesignation || hasPhone)
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (hasDesignation)
                      Text(emp.designation!, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: isDark ? Colors.white70 : Colors.black87)),
                    if (hasPhone)
                      Text(emp.phoneNo!, style: GoogleFonts.poppins(fontSize: 10.5, fontWeight: FontWeight.w400, color: Colors.grey)),
                  ],
                )
              : null,
          trailing: (_isSelectionMode || Provider.of<AuthService>(context, listen: false).user!.isEmployee) 
              ? null 
              : IconButton(
                  icon: Icon(Icons.more_vert, size: 18, color: isDark ? Colors.white70 : null),
                  onPressed: () => _showEmployeeDetails(context, emp),
                ),
          onTap: () {
            if (_isSelectionMode) {
              _toggleSelection(emp.userId);
            } else {
              _showEmployeeDetails(context, emp);
            }
          },
          onLongPress: () {
            if (!_isSelectionMode && !Provider.of<AuthService>(context, listen: false).user!.isEmployee) {
              setState(() {
                _isSelectionMode = true;
                _toggleSelection(emp.userId);
              });
            }
          },
        );

        if (isDark) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2.5),
            child: GlassContainer(
              child: Material(
                color: Colors.transparent,
                clipBehavior: Clip.antiAlias,
                borderRadius: BorderRadius.circular(14),
                child: childContent,
              ),
            ),
          );
        } else {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2.5),
            color: isSelected ? Theme.of(context).primaryColor.withValues(alpha: 0.05) : Colors.white,
            elevation: 1.5,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isSelected 
                  ? Theme.of(context).primaryColor 
                  : Colors.grey.withValues(alpha: 0.15),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: childContent,
          );
        }
      },
    );
  }

  void _showEmployeeDetails(BuildContext context, Employee employee) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    if (isLandscape) {
      setState(() {
        _selectedEmployeeForPane = employee;
      });
    } else {
      EmployeeDetailSheet.show(
        context,
        employee: employee,
        onEdit: () => _navigateToAddEdit(employee: employee),
        onDelete: () => _deleteEmployee(employee.userId),
        onToggleStatus: () => _toggleStatus(employee),
        onRestore: () => _restoreEmployee(employee),
        onForceDelete: () => _forceDeleteEmployee(employee),
      );
    }
  }

  Widget _buildDetailPane(BuildContext context, Employee employee) {
    return EmployeeDetailSheet(
      employee: employee,
      isDrawer: true,
      onClose: () => setState(() => _selectedEmployeeForPane = null),
      onEdit: () => _navigateToAddEdit(employee: employee),
      onDelete: () => _deleteEmployee(employee.userId),
      onToggleStatus: () => _toggleStatus(employee),
      onRestore: () => _restoreEmployee(employee),
      onForceDelete: () => _forceDeleteEmployee(employee),
    );
  }
}

// [mod:2026-02-21T11:00:00+05:30]
