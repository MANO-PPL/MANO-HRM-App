import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application/features/labour/core/labour_models.dart';
import 'package:flutter_application/features/labour/core/labour_service.dart';
import 'package:flutter_application/features/labour/widgets/labour_common_widgets.dart';

class LabourHistoryDialog extends StatefulWidget {
  final LabourWorker labour;
  final LabourService labourService;
  final bool isBottomSheet;

  const LabourHistoryDialog({
    super.key,
    required this.labour,
    required this.labourService,
    this.isBottomSheet = false,
  });

  @override
  State<LabourHistoryDialog> createState() => _LabourHistoryDialogState();
}

class _LabourHistoryDialogState extends State<LabourHistoryDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;
  LabourWorkHistoryResult? _historyData;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await widget.labourService.getLabourWorkHistory(widget.labour.labourId);
      if (mounted) {
        setState(() {
          _historyData = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final w = widget.labour;

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
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            w.name.isNotEmpty ? w.name[0].toUpperCase() : 'W',
                            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF6366F1)),
                          ),
                        ),
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
                                    w.name,
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SkillBadge(skill: w.role),
                              ],
                            ),
                            Text(
                              "Phone: ${w.phone ?? 'N/A'} • Daily Wage: ₹${w.monthlySalary.toStringAsFixed(0)} • OT Rate: ₹${w.overtimePayPerHour.toStringAsFixed(0)}/hr",
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
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

            // Content
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF6366F1)),
                ),
              )
            else if (_errorMessage != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 36, color: Color(0xFFEF4444)),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFFEF4444)),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _loadHistory,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
                        child: Text("Retry", style: GoogleFonts.poppins(fontSize: 12, color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              // KPI Totals Summary Bar
              Row(
                children: [
                  Expanded(
                    child: _buildMiniStat(
                      "Days Worked",
                      "${_historyData?.totals.totalDaysWorked ?? 0}",
                      Icons.event_available_rounded,
                      const Color(0xFF3B82F6),
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMiniStat(
                      "Total Earned",
                      "₹${(_historyData?.totals.totalEarned ?? 0).toStringAsFixed(0)}",
                      Icons.account_balance_wallet_rounded,
                      const Color(0xFF10B981),
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMiniStat(
                      "Advances Taken",
                      "₹${(_historyData?.totals.totalAdvances ?? 0).toStringAsFixed(0)}",
                      Icons.price_change_rounded,
                      const Color(0xFFF59E0B),
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMiniStat(
                      "Payouts Received",
                      "₹${(_historyData?.totals.totalPayoutsReceived ?? 0).toStringAsFixed(0)}",
                      Icons.payments_rounded,
                      const Color(0xFF8B5CF6),
                      isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Tab Bar
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: const Color(0xFF6366F1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: isDark ? Colors.grey[400] : Colors.grey[600],
                  labelStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500),
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: [
                    Tab(text: "Site Assignment History (${_historyData?.timeline.length ?? 0})"),
                    Tab(text: "Payouts & Advances (${_historyData?.payouts.length ?? 0})"),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTimelineTab(_historyData?.timeline ?? [], isDark),
                    _buildPayoutsTab(_historyData?.payouts ?? [], isDark),
                  ],
                ),
              ),
            ],
          ],
    );

    if (widget.isBottomSheet) {
      return Container(
        width: double.infinity,
        height: MediaQuery.of(context).size.height * 0.85,
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
            Expanded(child: bodyContent),
          ],
        ),
      );
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: 750,
        height: 620,
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

  Widget _buildMiniStat(String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF21262D) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineTab(List<LabourHistoryTimeline> timeline, bool isDark) {
    if (timeline.isEmpty) {
      return Center(
        child: Text("No site assignment records found", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500])),
      );
    }

    return ListView.builder(
      itemCount: timeline.length,
      itemBuilder: (context, i) {
        final t = timeline[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? const Color(0xFF21262D) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      t.siteName,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    "₹${t.totalEarned.toStringAsFixed(0)} Earned",
                    style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF10B981)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    "First Worked: ${t.firstWorked ?? 'N/A'} • Last Worked: ${t.lastWorked ?? 'N/A'}",
                    style: GoogleFonts.poppins(fontSize: 10, color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildPill("Days: ${t.totalDaysWorked}", const Color(0xFF3B82F6), isDark),
                  const SizedBox(width: 6),
                  _buildPill("Present: ${t.presentDays}", const Color(0xFF10B981), isDark),
                  const SizedBox(width: 6),
                  _buildPill("Half: ${t.halfDays}", const Color(0xFFF59E0B), isDark),
                  const SizedBox(width: 6),
                  _buildPill("OT: ${t.overtimeHours.toStringAsFixed(1)}h", const Color(0xFF8B5CF6), isDark),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPayoutsTab(List<LabourHistoryPayout> payouts, bool isDark) {
    if (payouts.isEmpty) {
      return Center(
        child: Text("No payout records logged yet", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500])),
      );
    }

    return ListView.builder(
      itemCount: payouts.length,
      itemBuilder: (context, i) {
        final p = payouts[i];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? const Color(0xFF21262D) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          p.month != null ? "Month: ${p.month}" : (p.paymentDate ?? 'Payout Record'),
                          style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            p.status.toUpperCase(),
                            style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.w600, color: const Color(0xFF10B981)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Site: ${p.siteName}${p.paymentDate != null ? ' • Date: ${p.paymentDate}' : ''}",
                      style: GoogleFonts.poppins(fontSize: 10, color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B)),
                    ),
                    if (p.notes != null && p.notes!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        "Notes: ${p.notes}",
                        style: GoogleFonts.poppins(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey[500]),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "₹${p.paidAmount.toStringAsFixed(0)}",
                    style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF10B981)),
                  ),
                  Text(
                    "Credit: ₹${p.accruedCredit.toStringAsFixed(0)} | Adv: ₹${p.advancesTaken.toStringAsFixed(0)}",
                    style: GoogleFonts.poppins(fontSize: 9.5, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPill(String text, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(fontSize: 9.5, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

// [upd:2026-04-13T17:00:00+05:30]
