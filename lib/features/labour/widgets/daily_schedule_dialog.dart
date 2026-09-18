import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application/features/labour/core/labour_models.dart';
import 'package:flutter_application/features/labour/core/labour_service.dart';
import 'package:flutter_application/features/labour/widgets/labour_common_widgets.dart';

class DailyScheduleDialog extends StatefulWidget {
  final LabourWorker labour;
  final List<LabourSite> sites;
  final LabourService labourService;
  final VoidCallback onSaved;
  final bool isBottomSheet;

  const DailyScheduleDialog({
    super.key,
    required this.labour,
    required this.sites,
    required this.labourService,
    required this.onSaved,
    this.isBottomSheet = false,
  });

  @override
  State<DailyScheduleDialog> createState() => _DailyScheduleDialogState();
}

class _DailyScheduleDialogState extends State<DailyScheduleDialog> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  bool _isSaving = false;
  final Set<int> _selectedSiteIds = {};

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    setState(() => _isLoading = true);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    try {
      final siteIds = await widget.labourService.getLabourSchedule(
        labourId: widget.labour.labourId,
        date: dateStr,
      );
      if (mounted) {
        setState(() {
          _selectedSiteIds.clear();
          _selectedSiteIds.addAll(siteIds);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _selectedSiteIds.clear();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveSchedule() async {
    setState(() => _isSaving = true);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    try {
      await widget.labourService.saveLabourSchedule(
        labourId: widget.labour.labourId,
        date: dateStr,
        siteIds: _selectedSiteIds.toList(),
      );
      if (mounted) {
        widget.onSaved();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeSites = widget.sites.where((s) => s.status != 'Inactive').toList();

    final bodyContent = Column(
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
                        child: const Icon(Icons.calendar_month_rounded, color: Color(0xFF6366F1), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Daily Multi-Site Schedule Planner",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              widget.labour.name,
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
            const SizedBox(height: 14),

            // Date Navigator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  IconButton(
                    icon: const Icon(Icons.chevron_left, size: 20),
                    onPressed: () {
                      setState(() {
                        _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                      });
                      _loadSchedule();
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  InkWell(
                    onTap: () async {
                      final picked = await showLabourDatePicker(
                        context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 60)),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                        _loadSchedule();
                      }
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 15, color: Color(0xFF6366F1)),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('EEEE, dd MMMM yyyy').format(_selectedDate),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 20),
                    onPressed: () {
                      setState(() {
                        _selectedDate = _selectedDate.add(const Duration(days: 1));
                      });
                      _loadSchedule();
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Info Notice
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 16, color: Color(0xFF6366F1)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Scheduling a worker to 2+ sites allows concurrent attendance across multiple sites without duplicate conflict warnings.",
                      style: GoogleFonts.poppins(fontSize: 10, color: isDark ? const Color(0xFFC7D2FE) : const Color(0xFF3730A3)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Site Checklist
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
                  : activeSites.isEmpty
                      ? Center(child: Text("No construction sites available", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500])))
                      : ListView.builder(
                          itemCount: activeSites.length,
                          itemBuilder: (context, i) {
                            final site = activeSites[i];
                            final isChecked = _selectedSiteIds.contains(site.siteId);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isChecked
                                    ? const Color(0xFF6366F1).withValues(alpha: 0.08)
                                    : (isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC)),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isChecked
                                      ? const Color(0xFF6366F1).withValues(alpha: 0.4)
                                      : (isDark ? const Color(0xFF21262D) : const Color(0xFFE2E8F0)),
                                ),
                              ),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value: isChecked,
                                      activeColor: const Color(0xFF6366F1),
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            _selectedSiteIds.add(site.siteId);
                                          } else {
                                            _selectedSiteIds.remove(site.siteId);
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          site.siteName,
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        if (site.locationDetails != null && site.locationDetails!.isNotEmpty)
                                          Text(
                                            site.locationDetails!,
                                            style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey[500]),
                                          ),
                                      ],
                                    ),
                                  ),
                                  if (site.status == 'Completed')
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text("Completed", style: GoogleFonts.poppins(fontSize: 9, color: Colors.blue)),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
            const SizedBox(height: 14),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${_selectedSiteIds.length} site(s) scheduled for this date",
                  style: GoogleFonts.poppins(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("Cancel", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _isSaving ? null : _saveSchedule,
                      child: _isSaving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text("Save Daily Schedule", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ],
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
              child: bodyContent,
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
        height: 520,
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
        child: bodyContent,
      ),
    );
  }
}

// [upd:2026-04-13T14:00:00+05:30]
