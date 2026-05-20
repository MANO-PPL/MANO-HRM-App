import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../models/employee_model.dart';
import '../../services/employee_service.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/widgets/toast_helper.dart';

class AddEmployeeView extends StatefulWidget {
  final VoidCallback onCancel;
  final VoidCallback? onSuccess;
  final Employee? employeeToEdit;

  const AddEmployeeView({
    super.key, 
    required this.onCancel, 
    this.onSuccess,
    this.employeeToEdit
  });

  @override
  State<AddEmployeeView> createState() => _AddEmployeeViewState();
}

class _AddEmployeeViewState extends State<AddEmployeeView> {
  late EmployeeService _employeeService;
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  // Dropdown Data
  List<Department> _departments = [];
  List<Designation> _designations = [];
  List<Shift> _shifts = [];

  // Selected Values
  int? _selectedDeptId;
  int? _selectedDesgId;
  int? _selectedShiftId;
  String _selectedUserType = 'employee';

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    _employeeService = EmployeeService(authService);
    _loadDropdownData();
    if (widget.employeeToEdit != null) {
      _populateFormData();
    }
  }

  void _populateFormData() {
    final emp = widget.employeeToEdit!;
    _nameController.text = emp.userName;
    _emailController.text = emp.email;
    _phoneController.text = emp.phoneNo ?? '';
    _selectedDeptId = emp.departmentId;
    _selectedDesgId = emp.designationId;
    _selectedShiftId = emp.shiftId;
    _selectedUserType = emp.userType;
  }

  Future<void> _loadDropdownData() async {
    setState(() => _isLoading = true);
    try {
      final depts = await _employeeService.getDepartments();
      final desgs = await _employeeService.getDesignations();
      final shifts = await _employeeService.getShifts();
      
      setState(() {
        _departments = depts;
        _designations = desgs;
        _shifts = shifts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print("Error loading dropdowns: $e");
    }
  }

  Future<void> _saveEmployee() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      final Map<String, dynamic> data = {
        'user_name': _nameController.text,
        'email': _emailController.text,
        'phone_no': _phoneController.text,
        'dept_id': _selectedDeptId,
        'desg_id': _selectedDesgId,
        'shift_id': _selectedShiftId,
        'user_type': _selectedUserType,
      };

      if (widget.employeeToEdit == null) {
        // Create Mode - Password Required
        if (_passwordController.text.isEmpty) {
          context.showToast('Password is required for new users', isWarning: true);
          setState(() => _isLoading = false);
          return;
        }
        data['user_password'] = _passwordController.text;
        await _employeeService.createEmployee(data);
      } else {
        // Update Mode
        if (_passwordController.text.isNotEmpty) {
           data['user_password'] = _passwordController.text;
        }
        await _employeeService.updateEmployee(widget.employeeToEdit!.userId, data);
      }

      if (mounted) {
        context.showToast(
          widget.employeeToEdit == null ? 'Employee Created' : 'Employee Updated',
          isSuccess: true,
        );
        widget.onSuccess?.call();
      }
    } catch (e) {
      if (mounted) {
        context.showToast('Error: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _departments.isEmpty) {
      // Loading dropdowns initially
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: widget.onCancel,
                  icon: Icon(Icons.close, color: Theme.of(context).textTheme.bodyLarge?.color),
                  label: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontSize: 16,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveEmployee,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5B60F6),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _isLoading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      : const Icon(Icons.save, color: Colors.white, size: 20),
                  label: Text(
                    _isLoading ? 'Saving...' : 'Save Changes',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
  
            // Content Container
            GlassContainer(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Personal Information
                    _buildSectionHeader(context, 'PERSONAL INFORMATION', Icons.person_outline),
                    const SizedBox(height: 24),
                    
                    Row(
                      children: [
                        Expanded(child: _buildTextField(context, 'Full Name', 'Enter full name', _nameController, isRequired: true)),
                        const SizedBox(width: 24),
                        Expanded(child: _buildTextField(context, 'Password', '......', _passwordController, isPassword: true, isRequired: widget.employeeToEdit == null)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(child: _buildTextField(context, 'Email Address', 'Enter email', _emailController, isRequired: true)),
                        const SizedBox(width: 24),
                        Expanded(child: _buildTextField(context, 'Phone Number', 'Enter phone number', _phoneController)),
                      ],
                    ),
  
                    const SizedBox(height: 48),
  
                    // Work Details
                    _buildSectionHeader(context, 'WORK DETAILS', Icons.business_center_outlined),
                    const SizedBox(height: 24),
  
                    Row(
                      children: [
                        Expanded(child: _buildDropdown<int>(
                          context, 
                          'Department', 
                          _selectedDeptId, 
                          _departments.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
                          (val) => setState(() => _selectedDeptId = val),
                        )),
                        const SizedBox(width: 24),
                        Expanded(child: _buildDropdown<int>(
                          context, 
                          'Designation / Role', 
                          _selectedDesgId, 
                          _designations.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
                          (val) => setState(() => _selectedDesgId = val),
                        )),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(child: _buildDropdown<int>(
                          context, 
                          'Shift Time', 
                          _selectedShiftId, 
                          _shifts.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
                          (val) => setState(() => _selectedShiftId = val),
                        )),
                        const SizedBox(width: 24),
                        Expanded(child: _buildDropdown<String>(
                          context, 
                          'User Type', 
                          _selectedUserType, 
                          const [
                            DropdownMenuItem(value: 'employee', child: Text('Employee')),
                            DropdownMenuItem(value: 'admin', child: Text('Admin')),
                          ],
                          (val) => setState(() => _selectedUserType = val!),
                        )),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(BuildContext context, String label, String placeholder, TextEditingController controller, {bool isPassword = false, bool isRequired = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Theme.of(context).textTheme.bodyMedium?.color,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          // height: 50, // Remove fixed height to allow error message
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0D1117) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[300]!,
            ),
          ),
          child: TextFormField(
            controller: controller,
            obscureText: isPassword,
            validator: isRequired ? (val) => val == null || val.isEmpty ? 'Required' : null : null,
            style: GoogleFonts.poppins(
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: GoogleFonts.poppins(
                color: Colors.grey,
                fontSize: 14,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown<T>(BuildContext context, String label, T? value, List<DropdownMenuItem<T>> items, ValueChanged<T?> onChanged) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: Theme.of(context).textTheme.bodyMedium?.color,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0D1117) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[300]!,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
              style: GoogleFonts.poppins(
                 color: Theme.of(context).textTheme.bodyLarge?.color,
                 fontSize: 14,
              ),
              dropdownColor: isDark ? const Color(0xFF30363D) : Colors.white,
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
