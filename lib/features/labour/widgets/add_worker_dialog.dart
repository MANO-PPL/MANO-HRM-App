import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application/features/labour/core/labour_models.dart';
import 'package:flutter_application/features/labour/widgets/labour_common_widgets.dart';

class AddWorkerDialog extends StatefulWidget {
  final LabourWorker? initialWorker;
  final List<LabourSite> availableSites;
  final Function(Map<String, dynamic> data) onSave;
  final bool isBottomSheet;
  final VoidCallback? onOpenWageHistory;

  const AddWorkerDialog({
    super.key,
    this.initialWorker,
    required this.availableSites,
    required this.onSave,
    this.isBottomSheet = false,
    this.onOpenWageHistory,
  });

  @override
  State<AddWorkerDialog> createState() => _AddWorkerDialogState();
}

class _AddWorkerDialogState extends State<AddWorkerDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _dailyWageController;
  late TextEditingController _otRateController;
  late String _sex;
  late String _role;
  int? _selectedSiteId;

  final List<String> _skillsList = [
    'Mason',
    'Carpenter',
    'Electrician',
    'Plumber',
    'Welder',
    'Painter',
    'Helper',
    'Foreman',
    'Supervisor',
    'Bar Bender',
    'Tile Layer',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialWorker?.name ?? '');
    _phoneController = TextEditingController(text: widget.initialWorker?.phone ?? '');
    _dailyWageController = TextEditingController(
      text: widget.initialWorker != null
          ? (widget.initialWorker!.monthlySalary == widget.initialWorker!.monthlySalary.roundToDouble()
              ? widget.initialWorker!.monthlySalary.toInt().toString()
              : widget.initialWorker!.monthlySalary.toString())
          : '600',
    );
    _otRateController = TextEditingController(
      text: widget.initialWorker != null
          ? (widget.initialWorker!.overtimePayPerHour == widget.initialWorker!.overtimePayPerHour.roundToDouble()
              ? widget.initialWorker!.overtimePayPerHour.toInt().toString()
              : widget.initialWorker!.overtimePayPerHour.toString())
          : '100',
    );
    _sex = widget.initialWorker?.sex ?? 'Male';
    _role = widget.initialWorker?.role ?? 'Helper';
    _selectedSiteId = widget.initialWorker?.siteId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _dailyWageController.dispose();
    _otRateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEdit = widget.initialWorker != null;

    final formContent = Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF6366F1), size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isEdit ? "Edit Worker Profile" : "Register New Labour Worker",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.close, size: 18, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Name
                Text(
                  "WORKER FULL NAME *",
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  style: GoogleFonts.poppins(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: "e.g. Ramesh Kumar",
                    hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
                    fillColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  validator: (val) => val == null || val.trim().isEmpty ? "Worker name is required" : null,
                ),
                const SizedBox(height: 14),

                // Phone & Sex
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "PHONE NUMBER",
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: GoogleFonts.poppins(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                            decoration: InputDecoration(
                              hintText: "10-digit mobile number",
                              hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
                              fillColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomDropdown<String>(
                            label: "GENDER",
                            value: _sex,
                            height: 48,
                            fontSize: 13,
                            items: const [
                              DropdownMenuItem(value: 'Male', child: Text("Male")),
                              DropdownMenuItem(value: 'Female', child: Text("Female")),
                              DropdownMenuItem(value: 'Other', child: Text("Other")),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _sex = val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Skill / Role
                CustomDropdown<String>(
                  label: "TRADE SKILL / ROLE *",
                  value: _skillsList.contains(_role) ? _role : _skillsList.first,
                  height: 48,
                  fontSize: 13,
                  items: _skillsList.map((skill) {
                    return DropdownMenuItem(value: skill, child: Text(skill));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _role = val);
                  },
                ),
                const SizedBox(height: 14),

                // Daily Wage Rate & Overtime Pay Rate
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "DAILY WAGE (₹) *",
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              if (widget.onOpenWageHistory != null)
                                InkWell(
                                  onTap: widget.onOpenWageHistory,
                                  child: Text(
                                    "View Wage History",
                                    style: GoogleFonts.poppins(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF6366F1),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _dailyWageController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: GoogleFonts.poppins(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                            decoration: InputDecoration(
                              hintText: "e.g. 600",
                              hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
                              prefixText: "₹ ",
                              prefixStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF6366F1)),
                              fillColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return "Daily wage required";
                              if (double.tryParse(val.trim()) == null) return "Invalid number";
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "OVERTIME PAY / HR (₹)",
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _otRateController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: GoogleFonts.poppins(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                            decoration: InputDecoration(
                              hintText: "e.g. 100",
                              hintStyle: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
                              prefixText: "₹ ",
                              prefixStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF6366F1)),
                              fillColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
                              filled: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Primary Assigned Site
                CustomDropdown<int?>(
                  label: "INITIAL ASSIGNED CONSTRUCTION SITE",
                  value: widget.availableSites.any((s) => s.siteId == _selectedSiteId) ? _selectedSiteId : null,
                  height: 48,
                  fontSize: 13,
                  hintText: "Unassigned Site (Pool)",
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text("Unassigned Site (General Pool)"),
                    ),
                    ...widget.availableSites.map((s) {
                      return DropdownMenuItem<int?>(
                        value: s.siteId,
                        child: Text(s.siteName),
                      );
                    }),
                  ],
                  onChanged: (val) => setState(() => _selectedSiteId = val),
                ),
                const SizedBox(height: 22),

                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "Cancel",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          final dailyWage = double.tryParse(_dailyWageController.text.trim()) ?? 600.0;
                          final otRate = double.tryParse(_otRateController.text.trim()) ?? 0.0;

                          widget.onSave({
                            'name': _nameController.text.trim(),
                            'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
                            'sex': _sex,
                            'role': _role,
                            'wage_type': 'Daily Wage',
                            'monthly_salary': dailyWage,
                            'allowed_leaves': 0,
                            'site_id': _selectedSiteId,
                            'overtime_pay_per_hour': otRate,
                            'status': 'Active',
                          });
                          Navigator.pop(context);
                        }
                      },
                      child: Text(
                        isEdit ? "Save Profile" : "Register Worker",
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );

    if (widget.isBottomSheet) {
      return Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161B22) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          border: Border(
            top: BorderSide(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: formContent,
              ),
            ),
          ],
        ),
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161B22) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: formContent,
        ),
      ),
    );
  }
}

// [upd:2026-04-13T11:30:00+05:30]
