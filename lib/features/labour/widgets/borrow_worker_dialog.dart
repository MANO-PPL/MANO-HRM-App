import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application/features/labour/core/labour_models.dart';
import 'package:flutter_application/features/labour/widgets/labour_common_widgets.dart';

class BorrowWorkerDialog extends StatefulWidget {
  final int currentSiteId;
  final String currentSiteName;
  final List<LabourWorker> allWorkers;
  final Set<int> existingLabourIds;
  final Function(LabourWorker worker) onBorrow;
  final bool isBottomSheet;

  const BorrowWorkerDialog({
    super.key,
    required this.currentSiteId,
    required this.currentSiteName,
    required this.allWorkers,
    required this.existingLabourIds,
    required this.onBorrow,
    this.isBottomSheet = false,
  });

  @override
  State<BorrowWorkerDialog> createState() => _BorrowWorkerDialogState();
}

class _BorrowWorkerDialogState extends State<BorrowWorkerDialog> {
  String _searchQuery = '';
  String _selectedRole = 'All';

  List<LabourWorker> get _availableToBorrow {
    return widget.allWorkers.where((w) {
      // Exclude if already in today's roster
      if (widget.existingLabourIds.contains(w.labourId)) {
        return false;
      }

      // Role filter
      if (_selectedRole != 'All' && w.role != _selectedRole) {
        return false;
      }

      // Search query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = w.name.toLowerCase().contains(q);
        final matchPhone = w.phone?.toLowerCase().contains(q) ?? false;
        final matchRole = w.role.toLowerCase().contains(q);
        final matchSite = w.siteName.toLowerCase().contains(q);
        if (!matchName && !matchPhone && !matchRole && !matchSite) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final available = _availableToBorrow;
    final roles = ['All', ...{...widget.allWorkers.map((w) => w.role)}];

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
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.person_add_alt_rounded, color: Color(0xFF10B981), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Borrow Worker to Current Roster",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              "Add external or general pool workers to ${widget.currentSiteName}",
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

            // Search and Role Filter
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 38,
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val.trim()),
                      style: GoogleFonts.poppins(fontSize: 12, color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        hintText: "Search workers by name, phone or site...",
                        hintStyle: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[500]),
                        prefixIcon: const Icon(Icons.search, size: 16),
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: CustomDropdown<String>(
                    value: _selectedRole,
                    height: 38,
                    fontSize: 11,
                    items: roles.map((r) => DropdownMenuItem(value: r, child: Text(r == 'All' ? 'All Roles' : r))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedRole = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Worker List
            Expanded(
              child: available.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 36, color: Colors.grey[500]),
                          const SizedBox(height: 8),
                          Text(
                            "No available workers found to borrow",
                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: available.length,
                      itemBuilder: (context, i) {
                        final w = available[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark ? const Color(0xFF21262D) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    w.name.isNotEmpty ? w.name[0].toUpperCase() : 'W',
                                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: const Color(0xFF6366F1)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      w.name,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    Text(
                                      "Primary Site: ${w.siteName}",
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SkillBadge(skill: w.role),
                              const SizedBox(width: 8),
                              Text(
                                "₹${w.monthlySalary.toStringAsFixed(0)}/day",
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  minimumSize: Size.zero,
                                ),
                                onPressed: () {
                                  widget.onBorrow(w);
                                  Navigator.pop(context);
                                },
                                child: Text(
                                  "+ Add",
                                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
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
        width: 580,
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

// [upd:2026-04-13T11:30:00+05:30]
