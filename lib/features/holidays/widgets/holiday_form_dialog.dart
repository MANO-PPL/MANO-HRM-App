import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../shared/widgets/glass_date_picker.dart';
import '../models/holiday_model.dart';

class HolidayFormDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onSubmit;
  final Holiday? initialData;

  const HolidayFormDialog({super.key, required this.onSubmit, this.initialData});

  @override
  HolidayFormDialogState createState() => HolidayFormDialogState();
}

class HolidayFormDialogState extends State<HolidayFormDialog> {
  late TextEditingController _nameCtrl;
  late DateTime _selectedDate;
  late String _type;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialData?.name ?? '');
    _selectedDate = widget.initialData != null
        ? DateTime.parse(widget.initialData!.date)
        : DateTime.now();
    _type = widget.initialData?.type ?? "Public";
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _pickDate() async {
    showDialog(
      context: context,
      builder: (context) => GlassDatePicker(
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
        onDateSelected: (date) {
          setState(() => _selectedDate = date);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.white54 : Colors.black54;
    final sheetBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final fieldBg = isDark ? const Color(0xFF0D1117).withOpacity(0.6) : Colors.grey[100]!;
    final borderColor = isDark ? Colors.white10 : Colors.grey.shade300;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
            width: 1,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.initialData == null ? "Add Holiday" : "Edit Holiday",
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          Text(
                            widget.initialData == null
                                ? "Create a new public holiday"
                                : "Update holiday details",
                            style: GoogleFonts.poppins(fontSize: 13, color: hintColor),
                          ),
                        ],
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close, color: textColor, size: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Name Field
                  Text("Holiday Name",
                      style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w600, color: hintColor)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameCtrl,
                    style: GoogleFonts.poppins(color: textColor),
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Please enter a name' : null,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: fieldBg,
                      hintText: "e.g. New Year's Day",
                      hintStyle: GoogleFonts.poppins(color: Colors.grey),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF6366F1))),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Date Picker
                  Text("Date",
                      style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w600, color: hintColor)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: fieldBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.calendar_today,
                                  size: 16,
                                  color: isDark
                                      ? const Color(0xFF818CF8)
                                      : const Color(0xFF6366F1)),
                              const SizedBox(width: 12),
                              Text(
                                DateFormat('MMMM dd, yyyy').format(_selectedDate),
                                style: GoogleFonts.poppins(color: textColor),
                              ),
                            ],
                          ),
                          Icon(Icons.arrow_drop_down, size: 20, color: hintColor),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Type Dropdown
                  Text("Type",
                      style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w600, color: hintColor)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _type,
                    dropdownColor: isDark ? const Color(0xFF161B22) : Colors.white,
                    style: GoogleFonts.poppins(color: textColor),
                    items: ["Public", "Optional", "Observance"]
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (val) => setState(() => _type = val!),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: fieldBg,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF6366F1))),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(
                                color: isDark ? Colors.white24 : Colors.grey.shade300),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text("Cancel",
                              style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600, color: hintColor)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            if (!_formKey.currentState!.validate()) return;
                            widget.onSubmit({
                              "holiday_name": _nameCtrl.text,
                              "holiday_date":
                                  DateFormat('yyyy-MM-dd').format(_selectedDate),
                              "holiday_type": _type,
                            });
                          },
                          child: Text(
                            widget.initialData == null ? "Add Holiday" : "Update",
                            style:
                                GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
