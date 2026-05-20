import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../models/employee_model.dart';
import '../../services/employee_service.dart';
import '../../../../shared/services/auth_service.dart';
import '../../tablet/views/add_employee_view.dart';
import '../../widgets/bulk_upload_report_dialog.dart';
import '../../widgets/glass_confirmation_dialog.dart';
import '../../widgets/employee_detail_sheet.dart';
import '../../../../shared/widgets/toast_helper.dart';

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
      builder: (_) => WillPopScope(
        onWillPop: () async => false,
        child: const Center(child: CircularProgressIndicator()),
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
      context.showToast('Employee ${action}d successfully', isSuccess: true);
    } catch (e) {
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
      context.showToast('Employee restored from trash', isSuccess: true);
    } catch (e) {
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
      context.showToast('Employee permanently deleted', isSuccess: true);
    } catch (e) {
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
          builder: (_) => WillPopScope(
            onWillPop: () async => false,
            child: const Center(child: CircularProgressIndicator()),
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(employee == null ? 'Add Employee' : 'Edit Employee')),
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
        const SizedBox(height: 8),
        Expanded(
          child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _filteredEmployees.isEmpty 
                  ? const Center(child: Text('No employees found'))
                  : _buildEmployeeList(context),
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
      body: isLandscape
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
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
      child: _isSelectionMode 
          ? Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _exitSelectionMode,
                ),
                const SizedBox(width: 8),
                Text('${_selectedIds.length} Selected', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                const Spacer(),
                TextButton(
                  onPressed: _toggleSelectAll,
                  child: Text(
                    _selectedIds.length == _filteredEmployees.length ? 'Unselect All' : 'Select All',
                    style: TextStyle(color: Theme.of(context).primaryColor),
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
                    height: 50,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                     child: Row(
                      children: [
                        const Icon(Icons.search, size: 20, color: Colors.grey),
                         const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            onChanged: (val) {
                              _searchQuery = val;
                              _filterEmployees();
                            },
                            decoration: const InputDecoration(
                              hintText: 'Search...',
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!Provider.of<AuthService>(context, listen: false).user!.isEmployee) ...[
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: _downloadSampleTemplate, 
                    icon: const Icon(Icons.download),
                    tooltip: 'Download Template',
                  ),
                  IconButton(
                    onPressed: _handleBulkUpload, 
                    icon: const Icon(Icons.upload_file),
                    tooltip: 'Bulk Upload',
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildStatusTabs(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final containerBg = isDark ? const Color(0xFF161B22) : Colors.grey[200]!;
    final activeBg = isDark ? const Color(0xFF0D1117) : Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: containerBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: ['Active', 'Inactive', 'Deleted'].map((status) {
            final isSelected = _statusFilter == status;
            return Expanded(
              child: InkWell(
                onTap: () {
                  setState(() {
                    _statusFilter = status;
                    _filterEmployees();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? activeBg : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status == 'Deleted' ? 'Trash' : status,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected 
                          ? (isDark ? Colors.white : Colors.black87) 
                          : Colors.grey,
                    ),
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
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: _filteredEmployees.length,
      itemBuilder: (context, index) {
        final emp = _filteredEmployees[index];
        final isSelected = _selectedIds.contains(emp.userId);
        final isDark = Theme.of(context).brightness == Brightness.dark;

        final childContent = ListTile(
          contentPadding: const EdgeInsets.all(16),
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
                      border: isDark ? Border.all(color: Colors.blue, width: 2) : null,
                    ),
                    child: CircleAvatar(
                      backgroundColor: isDark ? const Color(0xFF30363D) : Theme.of(context).primaryColor.withOpacity(0.1),
                      child: emp.profileImage != null && emp.profileImage!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: CachedNetworkImage(
                                imageUrl: emp.profileImage!,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorWidget: (context, url, error) => Text(
                                  emp.userName.isNotEmpty ? emp.userName[0].toUpperCase() : '?',
                                  style: TextStyle(color: isDark ? Colors.white : Theme.of(context).primaryColor),
                                ),
                                placeholder: (context, url) => Text(
                                  emp.userName.isNotEmpty ? emp.userName[0].toUpperCase() : '?',
                                  style: TextStyle(color: isDark ? Colors.white : Theme.of(context).primaryColor),
                                ),
                              ),
                            )
                          : Text(
                              emp.userName.isNotEmpty ? emp.userName[0].toUpperCase() : '?',
                              style: TextStyle(color: isDark ? Colors.white : Theme.of(context).primaryColor),
                            ),
                    ),
                  ),
                ),
          title: Text(emp.userName, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: isDark ? Colors.white : null)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(emp.designation ?? 'N/A', style: GoogleFonts.poppins(fontSize: 12, color: isDark ? Colors.white70 : null)),
              Text(emp.phoneNo ?? 'N/A', style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
            ],
          ),
          trailing: (_isSelectionMode || Provider.of<AuthService>(context, listen: false).user!.isEmployee) 
              ? null 
              : IconButton(
                  icon: Icon(Icons.more_vert, color: isDark ? Colors.white70 : null),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: GlassContainer(
              child: childContent,
            ),
          );
        } else {
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.05) : Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: isSelected 
                  ? Theme.of(context).primaryColor 
                  : Colors.grey.withOpacity(0.2),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;
    final dividerColor = isDark ? const Color(0xFF30363D) : Colors.grey[200]!;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? const Color(0xFF8D96A0) : Colors.grey[600];
    final nameInitial = employee.userName.isNotEmpty ? employee.userName[0].toUpperCase() : '?';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
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
                  color: isDark ? const Color(0xFF2F81F7) : primaryColor,
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: 36,
                backgroundColor: isDark ? const Color(0xFF161B22) : primaryColor.withOpacity(0.1),
                child: employee.profileImage != null && employee.profileImage!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(36),
                        child: CachedNetworkImage(
                          imageUrl: employee.profileImage!,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Text(
                            nameInitial,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : primaryColor,
                              fontSize: 24,
                            ),
                          ),
                          placeholder: (context, url) => Text(
                            nameInitial,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : primaryColor,
                              fontSize: 24,
                            ),
                          ),
                        ),
                      )
                    : Text(
                        nameInitial,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : primaryColor,
                          fontSize: 24,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            employee.userName,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            employee.designation ?? 'N/A',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: subTextColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
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
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D1117) : Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: dividerColor),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _buildPaneDetailRow(context, Icons.email_outlined, 'Email', employee.email, isDark),
                Divider(height: 16, color: dividerColor),
                _buildPaneDetailRow(context, Icons.phone_outlined, 'Phone', employee.phoneNo ?? 'N/A', isDark),
                Divider(height: 16, color: dividerColor),
                _buildPaneDetailRow(context, Icons.work_outline, 'Department', employee.department ?? 'N/A', isDark),
                Divider(height: 16, color: dividerColor),
                _buildPaneDetailRow(context, Icons.access_time, 'Shift', employee.shift ?? 'N/A', isDark),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Allowed Geofences',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: textColor,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: employee.workLocations.isEmpty
                ? Text(
                    'All Locations (Universal Access)',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: subTextColor,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: employee.workLocations.map((loc) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: loc.isActive ? Colors.blue.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: loc.isActive ? Colors.blue.withOpacity(0.3) : Colors.grey.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_on_outlined, 
                              size: 10, 
                              color: loc.isActive ? Colors.blue : Colors.grey
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
          ),
          const SizedBox(height: 20),
          if (employee.status == 'Deleted') ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _restoreEmployee(employee),
                    icon: const Icon(Icons.restore, size: 16),
                    label: const Text('Restore', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _forceDeleteEmployee(employee),
                    icon: const Icon(Icons.delete_forever, size: 16, color: Colors.white),
                    label: const Text('Force Delete', style: TextStyle(color: Colors.white, fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                    onPressed: () => _navigateToAddEdit(employee: employee),
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryColor,
                      side: BorderSide(color: primaryColor.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _toggleStatus(employee),
                    icon: Icon(employee.isActive ? Icons.block : Icons.check_circle_outline, size: 16),
                    label: Text(employee.isActive ? 'Deactivate' : 'Activate', style: const TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: employee.isActive ? Colors.amber : Colors.green,
                      side: BorderSide(color: employee.isActive ? Colors.amber : Colors.green),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _deleteEmployee(employee.userId),
                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.white),
                label: const Text('Move to Trash', style: TextStyle(color: Colors.white, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDA3637),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaneDetailRow(BuildContext context, IconData icon, String label, String value, bool isDark) {
    return Row(
      children: [
        Icon(
          icon, 
          size: 16, 
          color: isDark ? const Color(0xFF2F81F7) : Theme.of(context).primaryColor,
        ),
        const SizedBox(width: 12),
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
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 12,
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
