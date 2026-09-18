import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application/features/labour/core/labour_models.dart';
import 'package:flutter_application/features/labour/widgets/labour_common_widgets.dart';

class SettlePayoutDialog extends StatefulWidget {
  final LabourPayoutSummary summary;
  final int? siteId;
  final String month;
  final bool isBottomSheet;
  final Function({
    required int labourId,
    int? siteId,
    required double amount,
    required String date,
    required String paymentMode,
    required String notes,
  }) onSave;

  const SettlePayoutDialog({
    super.key,
    required this.summary,
    this.siteId,
    required this.month,
    this.isBottomSheet = false,
    required this.onSave,
  });

  @override
  State<SettlePayoutDialog> createState() => _SettlePayoutDialogState();
}

class _SettlePayoutDialogState extends State<SettlePayoutDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  final TextEditingController _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String _paymentMode = 'Cash';

  @override
  void initState() {
    super.initState();
    final defaultAmt = widget.summary.netPayable > 0 ? widget.summary.netPayable : 0.0;
    _amountController = TextEditingController(
      text: defaultAmt == defaultAmt.roundToDouble()
          ? defaultAmt.toInt().toString()
          : defaultAmt.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final s = widget.summary;

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
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.payments_rounded, color: Color(0xFF10B981), size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Settle Wage Payout",
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  "${s.name} • Month: ${widget.month}",
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

                // Financial Breakdown Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? const Color(0xFF21262D) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Trade / Role", style: GoogleFonts.poppins(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                          SkillBadge(skill: s.role),
                        ],
                      ),
                      const Divider(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Days Worked (${s.daysPresent}P + ${s.halfDays}HD)", style: GoogleFonts.poppins(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                          Text("₹${(s.daysPresent * s.dailyRate + s.halfDays * s.dailyRate * 0.5).toStringAsFixed(0)}", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Overtime (${s.overtimeHours.toStringAsFixed(1)} hrs)", style: GoogleFonts.poppins(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                          Text("+ ₹${s.otEarning.toStringAsFixed(0)}", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF10B981))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Total Accrued Credit", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                          Text("₹${s.accruedCredit.toStringAsFixed(0)}", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF6366F1))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Less Advances Logged", style: GoogleFonts.poppins(fontSize: 11, color: const Color(0xFFEF4444))),
                          Text("- ₹${s.totalAdvance.toStringAsFixed(0)}", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFEF4444))),
                        ],
                      ),
                      const Divider(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Net Payable Balance", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                          Text("₹${s.netPayable.toStringAsFixed(0)}", style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: const Color(0xFF10B981))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Amount to Pay & Payment Mode
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "AMOUNT TO PAY (₹) *",
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
                            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87),
                            decoration: InputDecoration(
                              prefixText: "₹ ",
                              prefixStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF10B981)),
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
                                borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return "Amount required";
                              final amt = double.tryParse(val.trim());
                              if (amt == null || amt <= 0) return "Invalid amount";
                              return null;
                            },
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
                            label: "MODE OF PAYMENT",
                            value: _paymentMode,
                            height: 48,
                            fontSize: 12,
                            items: const [
                              DropdownMenuItem(value: 'Cash', child: Text("Cash")),
                              DropdownMenuItem(value: 'Bank Transfer', child: Text("Bank Transfer")),
                              DropdownMenuItem(value: 'UPI', child: Text("UPI")),
                              DropdownMenuItem(value: 'Cheque', child: Text("Cheque")),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _paymentMode = val);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Date
                Text(
                  "PAYMENT DATE",
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
                        const Icon(Icons.calendar_today, size: 16, color: Color(0xFF10B981)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Notes / Remarks
                Text(
                  "NOTES / TRANSACTION ID (OPTIONAL)",
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
                    hintText: "e.g. UPI Ref: 309182390123 / Final settlement",
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
                      borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
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
                        backgroundColor: const Color(0xFF10B981),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          final amt = double.tryParse(_amountController.text.trim()) ?? 0.0;
                          widget.onSave(
                            labourId: s.labourId,
                            siteId: widget.siteId,
                            amount: amt,
                            date: DateFormat('yyyy-MM-dd').format(_selectedDate),
                            paymentMode: _paymentMode,
                            notes: _notesController.text.trim(),
                          );
                          Navigator.pop(context);
                        }
                      },
                      child: Text(
                        "Confirm Payout",
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

// [upd:2026-04-13T17:00:00+05:30]
