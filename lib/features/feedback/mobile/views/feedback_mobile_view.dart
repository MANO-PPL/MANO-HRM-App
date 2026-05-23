import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../shared/services/auth_service.dart';
import '../../../../shared/services/feedback_service.dart';
import '../../../../shared/services/mail_service.dart';
import '../../../../shared/widgets/toast_helper.dart';

class FeedbackMobileView extends StatefulWidget {
  const FeedbackMobileView({super.key});

  @override
  State<FeedbackMobileView> createState() => _FeedbackMobileViewState();
}

class _FeedbackMobileViewState extends State<FeedbackMobileView>
    with SingleTickerProviderStateMixin {
  TabController? _tabController; // 1. Nullable
  int _selectedTabIndex = 0; // Added declaration for _selectedTabIndex
  late FeedbackService
  _feedbackService; // Added declaration for _feedbackService

  final _bugFormKey = GlobalKey<FormState>();
  final _feedbackFormKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  List<File> _attachedFiles = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // 2. Init logic moved to helper or kept here?
    // We can keep it here for new instances, but for hot reload we need it in build.
    // Let's rely on _initTabController() called from both or just build.
    // Simpler: Just do it in build ??= logic is risky if build is called often?
    // TabController should only be created once.

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dio = Provider.of<AuthService>(context, listen: false).dio;
      _feedbackService = FeedbackService(dio);
    });
  }

  void _initTabController() {
    _tabController = TabController(length: 2, vsync: this);
    _tabController!.addListener(() {
      if (_tabController!.indexIsChanging ||
          _tabController!.index != _selectedTabIndex) {
        setState(() => _selectedTabIndex = _tabController!.index);
        FocusManager.instance.primaryFocus?.unfocus();
      }
    });
  }

  @override
  void dispose() {
    _tabController?.dispose(); // 4. Safe dispose
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    final activeKey = _selectedTabIndex == 0 ? _bugFormKey : _feedbackFormKey;
    if (!activeKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final type = _selectedTabIndex == 0
          ? 'BUG'
          : 'FEEDBACK'; // Map tabs to types
      final typeLabel = _selectedTabIndex == 0 ? 'Bug Report' : 'Feedback';

      await _feedbackService.submitFeedback(
        title: _titleController.text,
        description: _descController.text,
        type: type,
        files: _attachedFiles,
      );

      // Trigger Email (Async - don't await if you want faster UI, but user wants popup AFTER sending, so await is fine)
      await MailService().sendFeedbackEmail(
        title: _titleController.text,
        description: _descController.text,
        type: type,
        attachments: _attachedFiles,
      );

      if (mounted) {
        context.showToast(
          '$typeLabel submitted successfully.',
          isSuccess: true,
        );

        _titleController.clear();
        _descController.clear();
        setState(() => _attachedFiles = []);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Submit Failed: $e")));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
    );
    if (result != null) {
      setState(() {
        _attachedFiles.addAll(
          result.paths.where((p) => p != null).map((p) => File(p!)),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Lazy init for Hot Reload support
    if (_tabController == null) {
      _initTabController();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF5B60F6);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : Colors.white,
      body: SafeArea(
        top: false, // Prevent double padding with CustomAppBar
        child: Column(
          children: [
            // Tab Switcher Fixed at Top
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF161B22)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? const Color(0xFF30363D) : Colors.grey[300]!,
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.all(4),
                child: TabBar(
                  controller: _tabController!,
                  indicator: BoxDecoration(
                    color: isDark ? const Color(0xFF2D3139) : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF30363D)
                          : const Color(0xFFE2E8F0),
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
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: isDark ? Colors.white : const Color(0xFF4338CA),
                  unselectedLabelColor: isDark
                      ? const Color(0xFF94A3B8)
                      : Colors.grey[600],
                  labelStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  tabs: const [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.bug_report, size: 16),
                          SizedBox(width: 8),
                          Text("Bug Report"),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.feedback, size: 16),
                          SizedBox(width: 8),
                          Text("Feedback"),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController!,
                children: [
                  _buildFormContent(
                    isBugReport: true,
                    isDark: isDark,
                    primaryColor: primaryColor,
                  ),
                  _buildFormContent(
                    isBugReport: false,
                    isDark: isDark,
                    primaryColor: primaryColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormContent({
    required bool isBugReport,
    required bool isDark,
    required Color primaryColor,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Form(
        key: isBugReport ? _bugFormKey : _feedbackFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel(isBugReport ? "BUG TITLE" : "FEEDBACK TITLE"),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              style: GoogleFonts.poppins(fontSize: 14),
              validator: (v) => v!.isEmpty ? 'Required' : null,
              decoration: InputDecoration(
                hintText: isBugReport
                    ? "e.g., Error on Leave Page"
                    : "e.g., Suggestion for Dashboard",
                hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primaryColor),
                ),
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF161B22)
                    : const Color(0xFFF8FAFC),
              ),
            ),
            const SizedBox(height: 20),

            _buildLabel(isBugReport ? "BUG DESCRIPTION" : "DESCRIPTION"),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descController,
              minLines: 4,
              maxLines: null,
              style: GoogleFonts.poppins(fontSize: 14),
              validator: (v) => v!.isEmpty ? 'Required' : null,
              decoration: InputDecoration(
                hintText: isBugReport
                    ? "Describe the issue and steps to reproduce..."
                    : "Describe your feedback or suggestion...",
                hintStyle: GoogleFonts.poppins(color: Colors.grey[400]),
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primaryColor),
                ),
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF161B22)
                    : const Color(0xFFF8FAFC),
              ),
            ),
            const SizedBox(height: 20),

            _buildLabel("SCREENSHOTS (OPTIONAL)"),
            const SizedBox(height: 8),

            InkWell(
              onTap: _pickFiles,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF161B22)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.attach_file, color: primaryColor, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _attachedFiles.isEmpty
                            ? "Attach Screenshots (Optional)"
                            : "${_attachedFiles.length} file(s) attached",
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF475569),
                          fontWeight: _attachedFiles.isNotEmpty
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (_attachedFiles.isNotEmpty)
                      InkWell(
                        onTap: () => setState(() => _attachedFiles.clear()),
                        child: Icon(
                          Icons.close,
                          color: Colors.grey[400],
                          size: 18,
                        ),
                      )
                    else
                      Icon(
                        Icons.add_a_photo_outlined,
                        color: Colors.grey[400],
                        size: 18,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitFeedback,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isBugReport ? "Submit Bug Report" : "Submit Feedback",
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF64748B),
        letterSpacing: 0.5,
      ),
    );
  }
}
