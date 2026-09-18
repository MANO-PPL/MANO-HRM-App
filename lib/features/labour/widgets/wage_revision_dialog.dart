import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application/features/labour/core/labour_models.dart';
import 'package:flutter_application/features/labour/core/labour_service.dart';
import 'package:flutter_application/features/labour/widgets/labour_common_widgets.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';

class WageRevisionDialog extends StatefulWidget {
  final LabourWorker worker;
  final LabourService labourService;
  final VoidCallback onRevisionUpdated;

  const WageRevisionDialog({
    super.key,
    required this.worker,
    required this.labourService,
    required this.onRevisionUpdated,
  });

  static Future<void> show(
    BuildContext context, {
    required LabourWorker worker,
    required LabourService labourService,
    required VoidCallback onRevisionUpdated,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => WageRevisionDialog(
        worker: worker,
        labourService: labourService,
        onRevisionUpdated: onRevisionUpdated,
      ),
    );
  }

  @override
  State<WageRevisionDialog> createState() => _WageRevisionDialogState();
}

class _WageRevisionDialogState extends State<WageRevisionDialog> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  List<LabourWageRevision> _history = [];

  // New Revision Form State
  bool _showAddForm = false;
  DateTime _newEffectiveDate = DateTime.now();
  final _newWageController = TextEditingController();
  final _newOtController = TextEditingController();
  final _newNotesController = TextEditingController();

  // Inline Edit State
  int? _editingRevisionId;
  DateTime? _editEffectiveDate;
  final _editWageController = TextEditingController();
  final _editOtController = TextEditingController();
  final _editNotesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Prepopulate default wage and ot rate from worker
    final dailyRate = widget.worker.wageType.toLowerCase().contains('fixed')
        ? (widget.worker.monthlySalary / 30.0)
        : (widget.worker.monthlySalary > 0 ? widget.worker.monthlySalary : 500.0);
    _newWageController.text = dailyRate.toStringAsFixed(0);
    _newOtController.text = widget.worker.overtimePayPerHour.toStringAsFixed(0);

    _loadHistory();
  }

  @override
  void dispose() {
    _newWageController.dispose();
    _newOtController.dispose();
    _newNotesController.dispose();
    _editWageController.dispose();
    _editOtController.dispose();
    _editNotesController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final res = await widget.labourService.getLabourWageHistory(widget.worker.labourId);
      if (mounted) {
        setState(() {
          _history = res.history;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        context.showExceptionToast(e, fallback: "Failed to load wage revision history.");
      }
    }
  }

  Future<void> _submitNewRevision() async {
    final wage = double.tryParse(_newWageController.text.trim());
    if (wage == null || wage <= 0) {
      context.showToast("Please enter a valid daily wage rate.", isError: true);
      return;
    }

    final ot = double.tryParse(_newOtController.text.trim()) ?? 0.0;
    final dateStr = DateFormat('yyyy-MM-dd').format(_newEffectiveDate);
    final notes = _newNotesController.text.trim();

    setState(() => _isSubmitting = true);
    try {
      final ok = await widget.labourService.addLabourWageRevision(
        widget.worker.labourId,
        effectiveDate: dateStr,
        dailyWage: wage,
        overtimePayPerHour: ot,
        notes: notes.isNotEmpty ? notes : null,
      );

      if (ok && mounted) {
        context.showToast("Wage revision logged successfully!", isSuccess: true);
        _newNotesController.clear();
        setState(() => _showAddForm = false);
        widget.onRevisionUpdated();
        await _loadHistory();
      }
    } catch (e) {
      if (mounted) {
        context.showExceptionToast(e, fallback: "Failed to record wage revision.");
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _startEditing(LabourWageRevision rev) {
    setState(() {
      _editingRevisionId = rev.id;
      _editEffectiveDate = DateTime.tryParse(rev.effectiveDate) ?? DateTime.now();
      _editWageController.text = rev.dailyWage.toStringAsFixed(0);
      _editOtController.text = rev.overtimePayPerHour.toStringAsFixed(0);
      _editNotesController.text = rev.notes ?? '';
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingRevisionId = null;
      _editEffectiveDate = null;
    });
  }

  Future<void> _submitEditRevision(int revisionId) async {
    final wage = double.tryParse(_editWageController.text.trim());
    if (wage == null || wage <= 0) {
      context.showToast("Please enter a valid daily wage rate.", isError: true);
      return;
    }

    final ot = double.tryParse(_editOtController.text.trim()) ?? 0.0;
    final dateStr = DateFormat('yyyy-MM-dd').format(_editEffectiveDate ?? DateTime.now());
    final notes = _editNotesController.text.trim();

    setState(() => _isSubmitting = true);
    try {
      final ok = await widget.labourService.updateLabourWageRevision(
        revisionId,
        effectiveDate: dateStr,
        dailyWage: wage,
        overtimePayPerHour: ot,
        notes: notes.isNotEmpty ? notes : null,
      );

      if (ok && mounted) {
        context.showToast("Wage revision updated successfully!", isSuccess: true);
        _cancelEditing();
        widget.onRevisionUpdated();
        await _loadHistory();
      }
    } catch (e) {
      if (mounted) {
        context.showExceptionToast(e, fallback: "Failed to update wage revision.");
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _deleteRevision(LabourWageRevision rev) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Delete Revision?", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
        content: Text(
          "Are you sure you want to delete the wage revision effective from ${rev.effectiveDate}?",
          style: GoogleFonts.poppins(fontSize: 12.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSubmitting = true);
    try {
      final ok = await widget.labourService.deleteLabourWageRevision(rev.id);
      if (ok && mounted) {
        context.showToast("Revision deleted.", isSuccess: true);
        widget.onRevisionUpdated();
        await _loadHistory();
      }
    } catch (e) {
      if (mounted) {
        context.showExceptionToast(e, fallback: "Failed to delete revision.");
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isTablet = size.width >= 600;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isTablet ? 40 : 16,
        vertical: 24,
      ),
      child: Container(
        width: isTablet ? 650 : double.infinity,
        constraints: BoxConstraints(maxHeight: size.height * 0.88),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header with Worker Info & Close Button
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.history_edu_rounded, color: Color(0xFF6366F1), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              "${widget.worker.name} • Wage History",
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SkillBadge(skill: widget.worker.role),
                        ],
                      ),
                      Text(
                        "Track rate changes & revisions over time",
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 2. Add New Revision Collapsible Button / Action Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Wage Records (${_history.length})",
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[300] : Colors.grey[800],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _showAddForm ? Colors.grey[700] : const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    minimumSize: Size.zero,
                  ),
                  onPressed: () => setState(() => _showAddForm = !_showAddForm),
                  icon: Icon(_showAddForm ? Icons.close : Icons.add_rounded, color: Colors.white, size: 14),
                  label: Text(
                    _showAddForm ? "Cancel" : "Add Revision",
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 3. New Revision Form Panel (When Expanded)
            if (_showAddForm) ...[
              _buildAddRevisionForm(isDark),
              const SizedBox(height: 12),
            ],

            // 4. Revision History Timeline List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
                  : _history.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history_toggle_off_rounded, size: 42, color: Colors.grey[500]),
                              const SizedBox(height: 8),
                              Text(
                                "No wage revision history recorded yet.",
                                style: GoogleFonts.poppins(fontSize: 12.5, color: Colors.grey[500]),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Current base rate applies for all historical attendance.",
                                style: GoogleFonts.poppins(fontSize: 10.5, color: Colors.grey[400]),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _history.length,
                          itemBuilder: (context, i) {
                            final rev = _history[i];
                            if (_editingRevisionId == rev.id) {
                              return _buildEditRevisionCard(rev, isDark);
                            }
                            return _buildRevisionCard(rev, isDark, isLatest: i == 0);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddRevisionForm(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "New Wage Revision",
            style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF6366F1)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Effective Date Picker
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Effective Date", style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500])),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _newEffectiveDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) setState(() => _newEffectiveDate = picked);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF161B22) : Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 12, color: Color(0xFF6366F1)),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                DateFormat('dd MMM yyyy').format(_newEffectiveDate),
                                style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Daily Wage Rate
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Daily Wage (₹)", style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500])),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 34,
                      child: TextField(
                        controller: _newWageController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: "500",
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          fillColor: isDark ? const Color(0xFF161B22) : Colors.white,
                          filled: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // OT Pay / hr
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("OT Rate (₹/h)", style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500])),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 34,
                      child: TextField(
                        controller: _newOtController,
                        keyboardType: TextInputType.number,
                        style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: "50",
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          fillColor: isDark ? const Color(0xFF161B22) : Colors.white,
                          filled: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Notes & Submit Button
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: TextField(
                    controller: _newNotesController,
                    style: GoogleFonts.poppins(fontSize: 11),
                    decoration: InputDecoration(
                      hintText: "Revision rationale/notes (optional)",
                      hintStyle: GoogleFonts.poppins(fontSize: 10.5, color: Colors.grey[500]),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      fillColor: isDark ? const Color(0xFF161B22) : Colors.white,
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  minimumSize: Size.zero,
                ),
                onPressed: _isSubmitting ? null : _submitNewRevision,
                child: _isSubmitting
                    ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text("Save Rate", style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRevisionCard(LabourWageRevision rev, bool isDark, {bool isLatest = false}) {
    DateTime? effectiveDt = DateTime.tryParse(rev.effectiveDate);
    String dateFmt = effectiveDt != null ? DateFormat('dd MMM yyyy').format(effectiveDt) : rev.effectiveDate;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isLatest
              ? const Color(0xFF10B981).withValues(alpha: 0.5)
              : (isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
          width: isLatest ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Calendar tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isLatest
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : (isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 11,
                      color: isLatest ? const Color(0xFF10B981) : (isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      dateFmt,
                      style: GoogleFonts.poppins(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isLatest ? const Color(0xFF10B981) : (isDark ? Colors.grey[300] : Colors.grey[800]),
                      ),
                    ),
                    if (isLatest) ...[
                      const SizedBox(width: 4),
                      Text("(Active)", style: GoogleFonts.poppins(fontSize: 8.5, fontWeight: FontWeight.w600, color: const Color(0xFF10B981))),
                    ],
                  ],
                ),
              ),
              const Spacer(),

              // Rate pills
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "₹${rev.dailyWage.toStringAsFixed(0)}/day",
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF6366F1)),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "OT: ₹${rev.overtimePayPerHour.toStringAsFixed(0)}/h",
                  style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFFF59E0B)),
                ),
              ),

              const SizedBox(width: 6),
              // Edit button
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 15, color: Color(0xFF6366F1)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _startEditing(rev),
                tooltip: "Edit revision",
              ),
              const SizedBox(width: 6),
              // Delete button
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFEF4444)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _deleteRevision(rev),
                tooltip: "Delete revision",
              ),
            ],
          ),
          if (rev.notes != null && rev.notes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              "Note: ${rev.notes}",
              style: GoogleFonts.poppins(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey[500]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEditRevisionCard(LabourWageRevision rev, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "Edit Revision",
                style: GoogleFonts.poppins(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFFF59E0B)),
              ),
              const Spacer(),
              TextButton(
                onPressed: _cancelEditing,
                child: const Text("Cancel", style: TextStyle(fontSize: 11)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                ),
                onPressed: _isSubmitting ? null : () => _submitEditRevision(rev.id),
                child: const Text("Save", style: TextStyle(fontSize: 11, color: Colors.white)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _editEffectiveDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) setState(() => _editEffectiveDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161B22) : Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1)),
                    ),
                    child: Text(
                      DateFormat('dd MMM yyyy').format(_editEffectiveDate ?? DateTime.now()),
                      style: GoogleFonts.poppins(fontSize: 11),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 34,
                  child: TextField(
                    controller: _editWageController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.poppins(fontSize: 11),
                    decoration: InputDecoration(
                      hintText: "Wage",
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      fillColor: isDark ? const Color(0xFF161B22) : Colors.white,
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 34,
                  child: TextField(
                    controller: _editOtController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.poppins(fontSize: 11),
                    decoration: InputDecoration(
                      hintText: "OT/hr",
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      fillColor: isDark ? const Color(0xFF161B22) : Colors.white,
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 34,
            child: TextField(
              controller: _editNotesController,
              style: GoogleFonts.poppins(fontSize: 11),
              decoration: InputDecoration(
                hintText: "Revision rationale/notes",
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                fillColor: isDark ? const Color(0xFF161B22) : Colors.white,
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
