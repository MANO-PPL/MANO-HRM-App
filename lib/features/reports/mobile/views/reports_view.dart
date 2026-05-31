import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:open_filex/open_filex.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/glass_date_picker.dart';
import '../../../../shared/services/auth_service.dart';
import '../../services/report_service.dart';
import '../../models/report_history_model.dart';
import '../../../../shared/widgets/toast_helper.dart';

class MobileReportsContent extends StatefulWidget {
  const MobileReportsContent({super.key});

  @override
  State<MobileReportsContent> createState() => _MobileReportsContentState();
}

class _MobileReportsContentState extends State<MobileReportsContent> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ReportService _reportService;

  // State
  String _selectedReportType = 'matrix_monthly';
  String _selectedFormat = 'xlsx';
  DateTime _selectedDate = DateTime.now();

  Map<String, dynamic>? _previewData;
  bool _isLoadingPreview = false;
  bool _isDownloading = false;

  // History State
  List<ReportHistory> _history = [];
  bool _isLoadingHistory = false;

  final Map<String, String> _reportTypes = {
    'matrix_daily': 'Daily Matrix',
    'matrix_weekly': 'Weekly Matrix',
    'matrix_monthly': 'Monthly Matrix',
    'lateness_report': 'Lateness Report',
    'attendance_detailed': 'Detailed Log',
    'attendance_summary': 'Monthly Summary',
    'employee_master': 'Employee Master'
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Initialize Service
    final authService = Provider.of<AuthService>(context, listen: false);
    _reportService = ReportService(authService.dio);
    
    
    _fetchPreview();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);
    final history = await _reportService.getDownloadHistory();
    if (mounted) {
      setState(() {
        _history = history;
        _isLoadingHistory = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool get _requiresMonth => [
    'matrix_monthly', 'lateness_report', 'attendance_detailed', 'attendance_summary'
  ].contains(_selectedReportType);

  bool get _requiresDate => ['matrix_daily', 'matrix_weekly'].contains(_selectedReportType);

  String _fmtMonth(DateTime d) => "${d.year}-${d.month.toString().padLeft(2, '0')}";
  String _fmtDate(DateTime d) => "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";
  String _displayMonth(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return "${months[d.month-1]} ${d.year}";
  }

  Future<void> _fetchPreview() async {
    setState(() => _isLoadingPreview = true);
    try {
      final data = await _reportService.getPreview(
        type: _selectedReportType,
        month: _requiresMonth ? _fmtMonth(_selectedDate) : null,
        date: _requiresDate ? _fmtDate(_selectedDate) : null,
      );
      if (mounted) setState(() => _previewData = data);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Preview Failed: $e")));
    } finally {
      if (mounted) setState(() => _isLoadingPreview = false);
    }
  }

  Future<void> _handleDownload() async {
    setState(() => _isDownloading = true);
    try {
      final path = await _reportService.exportReport(
        type: _selectedReportType,
        format: _selectedFormat,
        month: _requiresMonth ? _fmtMonth(_selectedDate) : null,
        date: _requiresDate ? _fmtDate(_selectedDate) : null,
      );
      
      if (path != null && mounted) {
        _loadHistory(); // Refresh history
        
        // Show success toast
        context.showToast("Report downloaded successfully!", isSuccess: true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Export Failed: $e")));
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  Future<void> _pickDate(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => GlassDatePicker(
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
        onDateSelected: (date) {
          setState(() => _selectedDate = date);
          _fetchPreview();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      physics: const BouncingScrollPhysics(),
      children: [
        // Top Configuration Card (Stacked for Mobile)
        _buildConfigurationCard(context),
        const SizedBox(height: 24),

        // Tabs
        _buildTabs(context),
        const SizedBox(height: 16),

        // Tab Content
        AnimatedBuilder(
          animation: _tabController,
          builder: (context, child) {
            return _tabController.index == 0 
                ? _buildDataPreview(context)
                : _buildExportHistory(context);
          },
        ),
      ],
    );
  }

  Widget _buildConfigurationCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Select Month/Date
          if (_requiresMonth || _requiresDate) ...[
            Text(
              _requiresMonth ? 'SELECT MONTH' : 'SELECT DATE',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodySmall?.color,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _pickDate(context),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161B22) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: isDark ? const Color(0xFF818CF8) : Theme.of(context).primaryColor),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _requiresMonth ? _displayMonth(_selectedDate) : _fmtDate(_selectedDate),
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13, color: Theme.of(context).textTheme.bodyLarge?.color),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, size: 20, color: Theme.of(context).textTheme.bodySmall?.color),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 2. Report Type
          Text(
            'REPORT TYPE',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodySmall?.color,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161B22) : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[300]!),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _reportTypes.containsKey(_selectedReportType) ? _selectedReportType : _reportTypes.keys.first,
                icon: Icon(Icons.arrow_drop_down, color: Theme.of(context).textTheme.bodySmall?.color),
                isExpanded: true,
                elevation: 16,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontWeight: FontWeight.w500,
                ),
                dropdownColor: Theme.of(context).cardColor,
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedReportType = newValue;
                    });
                    _fetchPreview();
                  }
                },
                items: _reportTypes.entries.map<DropdownMenuItem<String>>((entry) {
                  return DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 3. File Format
          Text(
            'FILE FORMAT',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodySmall?.color,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 48,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: ['xlsx', 'csv', 'pdf'].map((format) {
                final isSelected = _selectedFormat == format;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedFormat = format),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white) 
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: isSelected && !isDark ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 2, offset: const Offset(0, 1))] : null,
                      ),
                      child: Text(
                        format.toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected 
                              ? Theme.of(context).textTheme.bodyLarge?.color 
                              : Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      
          const SizedBox(height: 24),

          // 4. Download Button
          SizedBox(
            height: 48,
            width: double.infinity, 
            child: ElevatedButton.icon(
              onPressed: _isDownloading ? null : _handleDownload,
              icon: _isDownloading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.download, size: 20),
              label: Text(
                _isDownloading ? 'Downloading...' : 'Export Report', 
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).brightness == Brightness.dark 
                    ? const Color(0xFF6366F1) // Brighter Indigo for Dark Mode
                    : Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF30363D) : Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: isDark ? const Color(0xFF2D3139) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        labelColor: isDark ? Colors.white : const Color(0xFF4338CA),
        unselectedLabelColor: isDark ? Colors.grey[500] : Colors.grey[600],
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13),
        tabs: [
          Tab(
            height: 42,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.table_chart_outlined, size: 16),
                  SizedBox(width: 6),
                  Text('Preview'),
                ],
              ),
            ),
          ), 
          Tab(
            height: 42,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.history, size: 16),
                  SizedBox(width: 6),
                  Text('History'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataPreview(BuildContext context) {
    if (_isLoadingPreview) {
      return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
    }
    
    if (_previewData == null || _previewData!['rows'] == null || (_previewData!['rows'] as List).isEmpty) {
      return Center(
         child: Padding(padding: const EdgeInsets.all(20), child: Text("No data available", style: GoogleFonts.poppins(color: Colors.grey)))
      );
    }

    final columns = _previewData!['columns'] as List;
    final rows = _previewData!['rows'] as List;

    return GlassContainer(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  columnSpacing: 20, 
                  horizontalMargin: 16,
                  headingRowColor: WidgetStateProperty.all(Colors.transparent),
                  dataRowMaxHeight: 60,
                  columns: columns.map((c) => _buildColumnHeader(context, c.toString())).toList(),
                  rows: rows.map((row) {
                       final cells = row as List;
                       return DataRow(
                         cells: cells.map((cell) => DataCell(
                           Text(
                             cell?.toString() ?? '-', 
                             style: GoogleFonts.poppins(fontSize: 12, color: Theme.of(context).textTheme.bodyLarge?.color)
                           )
                         )).toList()
                       );
                  }).toList(),
                ),
              ),
            ),
          );
        }
      ),
    );
  }

  DataColumn _buildColumnHeader(BuildContext context, String label) {
    return DataColumn(
      label: Text(
        label.toUpperCase(),
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          fontSize: 10,
          color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildExportHistory(BuildContext context) {
    if (_isLoadingHistory) return const Center(child: CircularProgressIndicator());
    
    if (_history.isEmpty) {
      return Center(
         child: Padding(padding: const EdgeInsets.all(20), child: Text("No download history", style: GoogleFonts.poppins(color: Colors.grey)))
      );
    }

    return Column(
      children: _history.map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GlassContainer(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (e.fileName.endsWith('pdf') ? Colors.red : Colors.green).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.table_chart, color: e.fileName.endsWith('pdf') ? Colors.red : Colors.green, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.fileName, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13, color: Theme.of(context).textTheme.bodyLarge?.color), overflow: TextOverflow.ellipsis),
                    Text(e.timestamp, style: GoogleFonts.poppins(fontSize: 11, color: Theme.of(context).textTheme.bodySmall?.color)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.open_in_new, size: 20, color: Colors.grey), 
                onPressed: () => OpenFilex.open(e.path),
                tooltip: 'Open File',
              ),
            ],
          ),
        ),
      )).toList(),
    );
  }
}
