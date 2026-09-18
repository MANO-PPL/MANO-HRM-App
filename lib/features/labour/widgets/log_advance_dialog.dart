import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application/features/labour/widgets/labour_common_widgets.dart';

class LogAdvanceDialog extends StatefulWidget {
  final int labourId;
  final String labourName;
  final int? siteId;
  final String siteName;
  final bool isBottomSheet;
  final Function({
    required int labourId,
    int? siteId,
    required double amount,
    required String date,
    required String notes,
  }) onSave;

  const LogAdvanceDialog({
    super.key,
    required this.labourId,
    required this.labourName,
    this.siteId,
    required this.siteName,
    this.isBottomSheet = false,
    required this.onSave,
  });

  @override
  State<LogAdvanceDialog> createState() => _LogAdvanceDialogState();
}

class _LogAdvanceDialogState extends State<LogAdvanceDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.price_change_rounded, color: Color(0xFFF59E0B), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Log Salary Advance",
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                widget.labourName,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: const Color(0xFF6366F1),
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
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

              // Advance Amount
              Text(
                "ADVANCE AMOUNT (₹) *",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: true,
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: "e.g. 500",
                  hintStyle: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.normal, color: Colors.grey[500]),
                  prefixText: "₹ ",
                  prefixStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFFF59E0B)),
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
                    borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return "Amount is required";
                  final amt = double.tryParse(val.trim());
                  if (amt == null || amt <= 0) return "Enter a valid positive amount";
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Date
              Text(
                "DISBURSEMENT DATE",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                onTap: () async {
                  final picked = await showLabourDatePicker(
                    context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 30)),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('dd MMM yyyy').format(_selectedDate),
                        style: GoogleFonts.poppins(fontSize: 13, color: isDark ? Colors.white : Colors.black87),
                      ),
                      const Icon(Icons.calendar_today, size: 16, color: Color(0xFFF59E0B)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Notes
              Text(
                "REASON / REMARKS (OPTIONAL)",
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                style: GoogleFonts.poppins(fontSize: 12, color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: "e.g. Festival advance / Medical emergency",
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
                    borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
              const SizedBox(height: 20),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Cancel", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        final amt = double.tryParse(_amountController.text.trim()) ?? 0.0;
                        widget.onSave(
                          labourId: widget.labourId,
                          siteId: widget.siteId,
                          amount: amt,
                          date: DateFormat('yyyy-MM-dd').format(_selectedDate),
                          notes: _notesController.text.trim(),
                        );
                        Navigator.pop(context);
                      }
                    },
                    child: Text(
                      "Log Advance",
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
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
        width: 440,
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
        child: formContent,
      ),
    );
  }
}

// [upd:2026-04-13T17:00:00+05:30]
