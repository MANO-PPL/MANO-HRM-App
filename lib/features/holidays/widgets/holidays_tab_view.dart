import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:provider/provider.dart';

import 'package:flutter_application/features/holidays/core/holiday_model.dart';
import 'package:flutter_application/features/holidays/core/holiday_service.dart';
import 'package:flutter_application/features/holidays/widgets/holiday_calendar_card.dart';
import 'package:flutter_application/features/holidays/widgets/holiday_form_dialog.dart';
import 'package:flutter_application/features/holidays/widgets/holiday_detail_dialog.dart';
import 'package:flutter_application/shared/services/auth_service.dart';
import 'package:flutter_application/shared/widgets/custom_dialog.dart';
import 'package:flutter_application/shared/widgets/toast_helper.dart';

class HolidaysTabView extends StatefulWidget {
  final HolidayService holidayService;

  const HolidaysTabView({super.key, required this.holidayService});

  @override
  State<HolidaysTabView> createState() => _HolidaysTabViewState();
}

class _HolidaysTabViewState extends State<HolidaysTabView> {
  List<Holiday> _holidays = [];
  bool _isLoading = false;
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime? _selectedDate;
  final TextEditingController _searchCtrl = TextEditingController();
  bool _showCalendar = true;
  String _filterMode = 'month'; // 'month', 'upcoming', 'all'

  int get _monthHolidayCount {
    final y = _currentMonth.year;
    final m = _currentMonth.month;
    return _holidays.where((h) {
      try {
        final d = DateTime.parse(h.date);
        return d.year == y && d.month == m;
      } catch (_) {
        return false;
      }
    }).length;
  }

  int get _upcomingHolidayCount {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return _holidays.where((h) {
      try {
        final d = DateTime.parse(h.date);
        return !d.isBefore(today);
      } catch (_) {
        return false;
      }
    }).length;
  }

  @override
  void initState() {
    super.initState();
    _fetchHolidays();
    _searchCtrl.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchHolidays({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    try {
      final data = await widget.holidayService.getHolidays(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _holidays = data;
        });
      }
    } catch (e) {
      if (mounted) {
        context.showToast("Failed to load holidays: $e", isSuccess: false);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteHoliday(int id) async {
    try {
      await widget.holidayService.deleteHolidays([id]);
      _fetchHolidays(forceRefresh: true);
      if (mounted) {
        context.showToast("Holiday deleted successfully.", isSuccess: true);
      }
    } catch (e) {
      if (mounted) {
        context.showToast("Delete failed: $e", isSuccess: false);
      }
    }
  }

  void _showAddDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => HolidayFormDialog(
        onSubmit: (data) async {
          try {
            await widget.holidayService.addHoliday(data);
            if (!ctx.mounted) return;
            Navigator.pop(ctx);
            _fetchHolidays(forceRefresh: true);
            if (mounted) {
              context.showToast("Holiday added successfully.", isSuccess: true);
            }
          } catch (e) {
            if (mounted) {
              context.showToast("Error adding holiday: $e", isSuccess: false);
            }
          }
        },
      ),
    );
  }

  void _showEditDialog(Holiday holiday) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => HolidayFormDialog(
        initialData: holiday,
        onSubmit: (data) async {
          try {
            await widget.holidayService.updateHoliday(holiday.id, data);
            if (!ctx.mounted) return;
            Navigator.pop(ctx);
            _fetchHolidays(forceRefresh: true);
            if (mounted) {
              context.showToast("Holiday updated successfully.", isSuccess: true);
            }
          } catch (e) {
            if (mounted) {
              context.showToast("Error updating holiday: $e", isSuccess: false);
            }
          }
        },
      ),
    );
  }

  void _confirmDelete(Holiday holiday) {
    CustomDialog.show(
      context: context,
      title: "Delete Holiday?",
      message: "Are you sure you want to delete '${holiday.name}'?",
      positiveButtonText: "Delete",
      isDestructive: true,
      onPositivePressed: () => _deleteHoliday(holiday.id),
      negativeButtonText: "Cancel",
      onNegativePressed: () {},
      icon: Icons.delete_outline,
      iconColor: Colors.redAccent,
    );
  }

  Future<void> _importCSV() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final input = file.openRead();
        final fields = await input
            .transform(utf8.decoder)
            .transform(const CsvToListConverter())
            .toList();

        if (fields.isEmpty) return;

        int startRow = 0;
        if (fields[0].isNotEmpty &&
            fields[0][0].toString().toLowerCase().contains('name')) {
          startRow = 1;
        }

        final List<Map<String, dynamic>> batch = [];
        for (int i = startRow; i < fields.length; i++) {
          final row = fields[i];
          if (row.length < 2) continue;

          final name = row[0].toString().trim();
          final date = row[1].toString().trim();
          final type = row.length > 2 ? row[2].toString().trim() : 'Public';

          if (name.isNotEmpty && date.isNotEmpty) {
            batch.add({
              "holiday_name": name,
              "holiday_date": date,
              "holiday_type": type,
            });
          }
        }

        if (batch.isNotEmpty) {
          setState(() => _isLoading = true);
          await widget.holidayService.addBulkHolidays(batch);
          _fetchHolidays(forceRefresh: true);
          if (mounted) {
            context.showToast(
              "Imported ${batch.length} holidays successfully.",
              isSuccess: true,
            );
          }
        } else {
          if (mounted) {
            context.showToast("No valid holiday rows in CSV.", isSuccess: false);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        context.showToast("Import failed: $e", isSuccess: false);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Holiday> _getVisibleHolidays() {
    final query = _searchCtrl.text.trim().toLowerCase();

    // 1. If searching, search across all holidays
    if (query.isNotEmpty) {
      return _holidays.where((h) {
        return h.name.toLowerCase().contains(query) ||
            h.date.toLowerCase().contains(query) ||
            h.type.toLowerCase().contains(query);
      }).toList();
    }

    // 2. If a specific date is selected on the calendar
    if (_selectedDate != null) {
      final selectedDateStr = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      return _holidays.where((h) => h.date == selectedDateStr).toList();
    }

    // 3. Filter mode based
    if (_filterMode == 'all') {
      return List<Holiday>.from(_holidays);
    }

    if (_filterMode == 'upcoming') {
      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      return _holidays.where((h) {
        try {
          final d = DateTime.parse(h.date);
          return !d.isBefore(today);
        } catch (_) {
          return false;
        }
      }).toList();
    }

    // Default: 'month'
    final currentYear = _currentMonth.year;
    final currentMonthNum = _currentMonth.month;

    return _holidays.where((h) {
      try {
        final d = DateTime.parse(h.date);
        return d.year == currentYear && d.month == currentMonthNum;
      } catch (_) {
        return false;
      }
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final isAdmin = authService.user?.isAdmin ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final visibleHolidays = _getVisibleHolidays();
    final monthName = DateFormat('MMMM').format(_currentMonth);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLandscape = constraints.maxWidth >= 900;
        final isTabletPortrait = constraints.maxWidth >= 600 && !isLandscape;

        return RefreshIndicator(
          onRefresh: () => _fetchHolidays(forceRefresh: true),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              isLandscape ? 16 : (isTabletPortrait ? 14 : 10),
              2,
              isLandscape ? 16 : (isTabletPortrait ? 14 : 10),
              10,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Search + Actions Sub-bar
                _buildSubBar(isAdmin, isDark),

                // Compact Filter Bar & Calendar Toggle
                _buildFilterBar(isDark),

                const SizedBox(height: 6),

                // Responsive Body Content
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : (isLandscape
                          ? _buildLandscapeLayout(visibleHolidays, monthName, isAdmin, isDark)
                          : (isTabletPortrait
                              ? _buildTabletPortraitLayout(visibleHolidays, monthName, isAdmin, isDark)
                              : _buildMobileLayout(visibleHolidays, monthName, isAdmin, isDark))),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterBar(bool isDark) {
    if (_searchCtrl.text.trim().isNotEmpty) return const SizedBox.shrink();

    final options = [
      {'id': 'month', 'label': '${DateFormat('MMM').format(_currentMonth)} ($_monthHolidayCount)'},
      {'id': 'upcoming', 'label': 'Upcoming ($_upcomingHolidayCount)'},
      {'id': 'all', 'label': 'All (${_holidays.length})'},
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 28,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: options.length,
                separatorBuilder: (_, _) => const SizedBox(width: 5),
                itemBuilder: (context, i) {
                  final opt = options[i];
                  final isSelected = _selectedDate == null && _filterMode == opt['id'];

                  return ChoiceChip(
                    label: Text(opt['label']!),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        _selectedDate = null;
                        _filterMode = opt['id']!;
                      });
                    },
                    selectedColor: const Color(0xFF6366F1),
                    backgroundColor: isDark ? const Color(0xFF161B22) : Colors.white,
                    labelStyle: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : (isDark ? Colors.white70 : Colors.grey.shade700),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: isSelected
                            ? const Color(0xFF6366F1)
                            : (isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
                      ),
                    ),
                    showCheckmark: false,
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Calendar Toggle Button
          InkWell(
            onTap: () => setState(() => _showCalendar = !_showCalendar),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: _showCalendar
                    ? const Color(0xFF6366F1).withValues(alpha: isDark ? 0.25 : 0.1)
                    : (isDark ? const Color(0xFF161B22) : Colors.white),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _showCalendar
                      ? const Color(0xFF6366F1)
                      : (isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _showCalendar ? Icons.calendar_month : Icons.calendar_month_outlined,
                    size: 13,
                    color: _showCalendar ? const Color(0xFF6366F1) : (isDark ? Colors.white60 : Colors.grey.shade600),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Calendar',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _showCalendar ? const Color(0xFF6366F1) : (isDark ? Colors.white60 : Colors.grey.shade600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 1. Sub-bar: Search field + (Admin) Import and Add buttons
  Widget _buildSubBar(bool isAdmin, bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;
        final double barHeight = isNarrow ? 36 : 42;

        final searchField = Container(
          height: barHeight,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : Colors.white,
            borderRadius: BorderRadius.circular(isNarrow ? 8 : 10),
            border: Border.all(
              color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
            ),
          ),
          child: TextField(
            controller: _searchCtrl,
            style: GoogleFonts.inter(
              fontSize: isNarrow ? 12 : 13,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              hintText: isNarrow ? 'Search holidays...' : 'Search holidays...',
              hintStyle: GoogleFonts.inter(
                fontSize: isNarrow ? 11.5 : 13,
                color: isDark ? const Color(0xFF8B949E) : const Color(0xFF94A3B8),
              ),
              prefixIcon: Icon(
                Icons.search,
                size: isNarrow ? 16 : 18,
                color: isDark ? const Color(0xFF8B949E) : const Color(0xFF94A3B8),
              ),
              prefixIconConstraints: BoxConstraints(
                minWidth: isNarrow ? 32 : 38,
                minHeight: isNarrow ? 32 : 38,
              ),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.close, size: isNarrow ? 14 : 16),
                      onPressed: () => _searchCtrl.clear(),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(minWidth: isNarrow ? 28 : 36),
                    )
                  : null,
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: isNarrow ? 8 : 11),
            ),
          ),
        );

        if (!isAdmin) {
          // Employee: Full width compact search bar
          return searchField;
        }

        // Admin Actions (Import & Add)
        final importButton = InkWell(
          onTap: _importCSV,
          borderRadius: BorderRadius.circular(isNarrow ? 8 : 10),
          child: Container(
            height: barHeight,
            padding: EdgeInsets.symmetric(horizontal: isNarrow ? 10 : 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF21262D) : Colors.white,
              borderRadius: BorderRadius.circular(isNarrow ? 8 : 10),
              border: Border.all(
                color: isDark ? const Color(0xFF30363D) : const Color(0xFFCBD5E1),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.upload_file_outlined,
                  size: isNarrow ? 14 : 16,
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                ),
                SizedBox(width: isNarrow ? 4 : 8),
                Text(
                  'Import',
                  style: GoogleFonts.inter(
                    fontSize: isNarrow ? 11.5 : 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
        );

        final addButton = ElevatedButton.icon(
          onPressed: _showAddDialog,
          icon: Icon(Icons.add, size: isNarrow ? 15 : 17, color: Colors.white),
          label: Text(
            'Add',
            style: GoogleFonts.inter(
              fontSize: isNarrow ? 11.5 : 13,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6366F1), // Vibrant Indigo
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isNarrow ? 8 : 10)),
            padding: EdgeInsets.symmetric(horizontal: isNarrow ? 12 : 18, vertical: isNarrow ? 8 : 12),
            minimumSize: Size(0, barHeight),
          ),
        );

        return Row(
          children: [
            Expanded(child: searchField),
            SizedBox(width: isNarrow ? 6 : 10),
            importButton,
            SizedBox(width: isNarrow ? 6 : 8),
            addButton,
          ],
        );
      },
    );
  }

  // 2. Landscape: Left List + Right Calendar Card (if toggled)
  Widget _buildLandscapeLayout(
    List<Holiday> visibleHolidays,
    String monthName,
    bool isAdmin,
    bool isDark,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Main Container (Holidays List or Empty State)
        Expanded(
          child: _buildMainHolidayCard(visibleHolidays, monthName, isAdmin, isDark),
        ),

        if (_showCalendar) ...[
          const SizedBox(width: 12),
          // Right Calendar Card
          SizedBox(
            width: 290,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: _buildCalendarCard(),
            ),
          ),
        ],
      ],
    );
  }

  // 3. Tablet Portrait Layout
  Widget _buildTabletPortraitLayout(
    List<Holiday> visibleHolidays,
    String monthName,
    bool isAdmin,
    bool isDark,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildMainHolidayCard(visibleHolidays, monthName, isAdmin, isDark),
        ),
        if (_showCalendar) ...[
          const SizedBox(width: 10),
          SizedBox(
            width: 270,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: _buildCalendarCard(),
            ),
          ),
        ],
      ],
    );
  }

  // 4. Mobile Portrait Layout (Compact & tight spacing)
  Widget _buildMobileLayout(
    List<Holiday> visibleHolidays,
    String monthName,
    bool isAdmin,
    bool isDark,
  ) {
    final isSearching = _searchCtrl.text.trim().isNotEmpty;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        if (!isSearching && _showCalendar) ...[
          _buildCalendarCard(),
          const SizedBox(height: 8),
        ],
        _buildMainHolidayCard(visibleHolidays, monthName, isAdmin, isDark, shrinkWrap: true),
      ],
    );
  }

  Widget _buildCalendarCard() {
    final now = DateTime.now();
    return HolidayCalendarCard(
      currentMonth: _currentMonth,
      selectedDate: _selectedDate,
      holidays: _holidays,
      onMonthChanged: (newMonth) {
        setState(() {
          _currentMonth = newMonth;
          _selectedDate = null;
        });
      },
      onDateSelected: (date) {
        setState(() {
          _selectedDate = date;
          if (date.month != _currentMonth.month || date.year != _currentMonth.year) {
            _currentMonth = DateTime(date.year, date.month, 1);
          }
        });
      },
      onTodayPressed: () {
        setState(() {
          _currentMonth = DateTime(now.year, now.month, 1);
          _selectedDate = now;
        });
      },
    );
  }

  // Main Card Container (matching web HolidaysTab.jsx month grouping)
  Widget _buildMainHolidayCard(
    List<Holiday> visibleHolidays,
    String monthName,
    bool isAdmin,
    bool isDark, {
    bool shrinkWrap = false,
  }) {
    final hasSearch = _searchCtrl.text.trim().isNotEmpty;
    final hasSelection = _selectedDate != null;

    if (visibleHolidays.isEmpty) {
      final emptyCard = Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161B22) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasSearch
                  ? Icons.search_off_rounded
                  : (hasSelection ? Icons.event_busy_rounded : Icons.beach_access_outlined),
              size: 28,
              color: isDark ? Colors.white38 : Colors.grey.shade400,
            ),
            const SizedBox(height: 6),
            Text(
              hasSearch
                  ? "No holidays found matching '${_searchCtrl.text.trim()}'"
                  : (hasSelection
                      ? "No holidays on ${DateFormat('d MMMM yyyy').format(_selectedDate!)}"
                      : "No holidays in $monthName"),
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
              ),
              textAlign: TextAlign.center,
            ),
            if (!hasSearch && _filterMode == 'month' && _upcomingHolidayCount > 0) ...[
              const SizedBox(height: 8),
              InkWell(
                onTap: () => setState(() {
                  _selectedDate = null;
                  _filterMode = 'upcoming';
                }),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.25 : 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF6366F1)),
                      const SizedBox(width: 4),
                      Text(
                        'View Upcoming Holidays ($_upcomingHolidayCount)',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6366F1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      );

      if (shrinkWrap) return emptyCard;
      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: emptyCard,
      );
    }

    // Group holidays by Month Year (matching web HolidaysTab.jsx)
    final Map<String, List<Holiday>> groups = {};
    for (final h in visibleHolidays) {
      DateTime d;
      try {
        d = DateTime.parse(h.date);
      } catch (_) {
        d = DateTime.now();
      }
      final key = DateFormat('MMMM yyyy').format(d);
      groups.putIfAbsent(key, () => []).add(h);
    }

    final groupWidgets = <Widget>[];
    groups.forEach((monthYear, hList) {
      groupWidgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF161B22) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Month Heading with Indigo Pill Accent (Matching Web)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 14,
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          monthYear,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        '${hList.length} ${hList.length == 1 ? "Holiday" : "Holidays"}',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Divider(
                height: 1,
                color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
              ),

              // Holiday items in month
              ...List.generate(hList.length, (idx) {
                final holiday = hList[idx];
                return Column(
                  children: [
                    _buildHolidayItem(holiday, isAdmin, isDark),
                    if (idx < hList.length - 1)
                      Divider(
                        height: 1,
                        indent: 10,
                        endIndent: 10,
                        color: isDark ? const Color(0xFF21262D) : const Color(0xFFF1F5F9),
                      ),
                  ],
                );
              }),
            ],
          ),
        ),
      );
    });

    if (shrinkWrap) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: groupWidgets,
      );
    }

    return ListView(
      children: groupWidgets,
    );
  }

  Widget _buildHolidayItem(Holiday holiday, bool isAdmin, bool isDark) {
    DateTime parsedDate;
    try {
      parsedDate = DateTime.parse(holiday.date);
    } catch (_) {
      parsedDate = DateTime.now();
    }

    final dayNum = DateFormat('d').format(parsedDate);
    final weekday = DateFormat('EEE').format(parsedDate).toUpperCase();
    final isPublic = holiday.type.toLowerCase() == 'public';

    return InkWell(
      onTap: () => HolidayDetailDialog.show(context, holiday),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            // Date Badge (Day + Weekday)
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dayNum,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    weekday,
                    style: GoogleFonts.inter(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // Holiday Name + Date formatted
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    holiday.name,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('d MMMM yyyy').format(parsedDate),
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Type Chip (PUBLIC or OPTIONAL)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: isPublic
                    ? const Color(0xFF9333EA).withValues(alpha: 0.15)
                    : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isPublic
                    ? const Color(0xFF9333EA).withValues(alpha: 0.4)
                    : const Color(0xFFF59E0B).withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                holiday.type.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  color: isPublic ? const Color(0xFFA855F7) : const Color(0xFFFBBF24),
                ),
              ),
            ),

            // Admin Actions (Edit & Delete)
            if (isAdmin) ...[
              const SizedBox(width: 6),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 15),
                color: isDark ? Colors.white60 : Colors.black54,
                onPressed: () => _showEditDialog(holiday),
                tooltip: "Edit",
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                padding: EdgeInsets.zero,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 15),
                color: Colors.redAccent.withValues(alpha: 0.8),
                onPressed: () => _confirmDelete(holiday),
                tooltip: "Delete",
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                padding: EdgeInsets.zero,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
