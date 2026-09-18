import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_application/features/labour/core/labour_models.dart';
import 'package:flutter_application/features/labour/widgets/labour_common_widgets.dart';

class BulkTransferDialog extends StatefulWidget {
  final List<LabourSite> sites;
  final List<LabourWorker> workers;
  final dynamic initialSourceSiteId;
  final List<int> initialSelectedLabourIds;
  final bool isBottomSheet;
  final Function({
    required dynamic sourceSiteId,
    required int destinationSiteId,
    required List<int> labourIds,
    required String roleFilter,
  }) onTransfer;

  const BulkTransferDialog({
    super.key,
    required this.sites,
    required this.workers,
    this.initialSourceSiteId = 'All',
    this.initialSelectedLabourIds = const [],
    this.isBottomSheet = false,
    required this.onTransfer,
  });

  @override
  State<BulkTransferDialog> createState() => _BulkTransferDialogState();
}

class _BulkTransferDialogState extends State<BulkTransferDialog> {
  late dynamic _sourceSiteId;
  int? _destinationSiteId;
  String _roleFilter = 'All';
  String _searchQuery = '';
  final Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _sourceSiteId = widget.initialSourceSiteId ?? 'All';
    _selectedIds.addAll(widget.initialSelectedLabourIds);

    final activeSites = widget.sites.where((s) => s.status == 'Active').toList();
    if (activeSites.isNotEmpty) {
      if (_sourceSiteId is int) {
        final other = activeSites.where((s) => s.siteId != _sourceSiteId).toList();
        if (other.isNotEmpty) _destinationSiteId = other.first.siteId;
      } else {
        _destinationSiteId = activeSites.first.siteId;
      }
    }
  }

  List<LabourWorker> get _filteredWorkers {
    return widget.workers.where((w) {
      // Source site filter
      if (_sourceSiteId != 'All' && _sourceSiteId != null) {
        final srcId = _sourceSiteId is int ? _sourceSiteId as int : int.tryParse(_sourceSiteId.toString());
        if (srcId != null && w.siteId != srcId && !w.siteIds.contains(srcId)) {
          return false;
        }
      }

      // Role filter
      if (_roleFilter != 'All' && w.role != _roleFilter) {
        return false;
      }

      // Search query
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = w.name.toLowerCase().contains(q);
        final matchPhone = w.phone?.toLowerCase().contains(q) ?? false;
        final matchRole = w.role.toLowerCase().contains(q);
        if (!matchName && !matchPhone && !matchRole) return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredWorkers;
    final allSelected = filtered.isNotEmpty && filtered.every((w) => _selectedIds.contains(w.labourId));
    final activeSites = widget.sites.where((s) => s.status == 'Active').toList();

    // Unique roles
    final roles = ['All', ...{...widget.workers.map((w) => w.role)}];

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
                        child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF6366F1), size: 22),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Bulk Worker Site Transfer",
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              "Transfer multiple workers between construction sites seamlessly",
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

            // Source & Destination Row
            Row(
              children: [
                // From Site
                Expanded(
                  child: CustomDropdown<dynamic>(
                    label: "FROM SOURCE SITE",
                    value: _sourceSiteId,
                    height: 42,
                    fontSize: 12,
                    items: [
                      const DropdownMenuItem(value: 'All', child: Text("All Sites / Unassigned")),
                      ...widget.sites.map((s) {
                        return DropdownMenuItem(value: s.siteId, child: Text(s.siteName, maxLines: 1, overflow: TextOverflow.ellipsis));
                      }),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _sourceSiteId = val;
                        _selectedIds.clear();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Arrow
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Icon(Icons.arrow_forward_rounded, size: 20, color: isDark ? Colors.grey[500] : Colors.grey[600]),
                ),
                const SizedBox(width: 12),
                // To Site
                Expanded(
                  child: CustomDropdown<int?>(
                    label: "TO DESTINATION SITE *",
                    value: _destinationSiteId,
                    height: 42,
                    fontSize: 12,
                    hintText: "Select Destination Site",
                    items: activeSites.map((s) {
                      return DropdownMenuItem<int?>(value: s.siteId, child: Text(s.siteName, maxLines: 1, overflow: TextOverflow.ellipsis));
                    }).toList(),
                    onChanged: (val) => setState(() => _destinationSiteId = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Search & Filter Toolbar
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
                        hintText: "Search workers by name...",
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
                    value: _roleFilter,
                    height: 38,
                    fontSize: 11,
                    items: roles.map((r) => DropdownMenuItem(value: r, child: Text(r == 'All' ? 'All Roles' : r))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _roleFilter = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Select All Header Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: allSelected,
                      activeColor: const Color(0xFF6366F1),
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            for (final w in filtered) {
                              _selectedIds.add(w.labourId);
                            }
                          } else {
                            for (final w in filtered) {
                              _selectedIds.remove(w.labourId);
                            }
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "SELECT ALL WORKERS (${filtered.length} AVAILABLE)",
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFF8B949E) : const Color(0xFF475569),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "${_selectedIds.length} Selected",
                      style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFF6366F1)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Worker List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        "No workers match the selected filters",
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final w = filtered[i];
                        final isSelected = _selectedIds.contains(w.labourId);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF6366F1).withValues(alpha: 0.08)
                                : (isDark ? const Color(0xFF0D1117) : Colors.white),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected
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
                                  value: isSelected,
                                  activeColor: const Color(0xFF6366F1),
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedIds.add(w.labourId);
                                      } else {
                                        _selectedIds.remove(w.labourId);
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
                                      w.name,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    Text(
                                      "Current Site: ${w.siteName}",
                                      style: GoogleFonts.poppins(
                                        fontSize: 10,
                                        color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SkillBadge(skill: w.role),
                              const SizedBox(width: 10),
                              Text(
                                "₹${w.monthlySalary.toStringAsFixed(0)}/day",
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF10B981),
                                ),
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
                  "${_selectedIds.length} worker(s) will be transferred",
                  style: GoogleFonts.poppins(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("Cancel", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: (_selectedIds.isEmpty || _destinationSiteId == null)
                          ? null
                          : () {
                              widget.onTransfer(
                                sourceSiteId: _sourceSiteId,
                                destinationSiteId: _destinationSiteId!,
                                labourIds: _selectedIds.toList(),
                                roleFilter: _roleFilter,
                              );
                              Navigator.pop(context);
                            },
                      icon: const Icon(Icons.check, color: Colors.white, size: 16),
                      label: Text(
                        "Execute Transfer (${_selectedIds.length})",
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
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
        width: 680,
        height: 600,
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
