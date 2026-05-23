import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../shared/services/auth_service.dart';
import '../../../../shared/services/feedback_service.dart';
import '../../../../shared/services/mail_service.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../../../shared/widgets/dashed_container.dart';
import '../../../../shared/widgets/toast_helper.dart';

class FeedbackTabletLandscape extends StatefulWidget {
  const FeedbackTabletLandscape({super.key});

  @override
  State<FeedbackTabletLandscape> createState() =>
      _FeedbackTabletLandscapeState();
}

class _FeedbackTabletLandscapeState extends State<FeedbackTabletLandscape>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  int _selectedTabIndex = 0;
  late FeedbackService _feedbackService;

  final _bugFormKey = GlobalKey<FormState>();
  final _feedbackFormKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  List<File> _attachedFiles = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _initTabController();
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
    _tabController?.dispose();
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    final activeKey = _selectedTabIndex == 0 ? _bugFormKey : _feedbackFormKey;
    if (!activeKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final type = _selectedTabIndex == 0 ? 'BUG' : 'FEEDBACK';
      final typeLabel = _selectedTabIndex == 0 ? 'Bug Report' : 'Feedback';

      await _feedbackService.submitFeedback(
        title: _titleController.text,
        description: _descController.text,
        type: type,
        files: _attachedFiles,
      );

      // Trigger Email
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24.0), // Standardized padding
      child: Column(
        children: [
          // Standard Tab Switcher matching MyAttendanceView
          Container(
            margin: const EdgeInsets.only(bottom: 32),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161B22) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF30363D) : Colors.grey[300]!,
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: isDark ? const Color(0xFF2D3139) : Colors.white,
                borderRadius: BorderRadius.circular(8),
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
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              dividerColor: Colors.transparent,
              // We handle colors manually in children
              overlayColor: WidgetStateProperty.all(Colors.transparent),
              labelStyle: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              onTap: (index) => setState(() => _selectedTabIndex = index),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bug_report_outlined,
                        color: _selectedTabIndex == 0
                            ? const Color(0xFFEF4444)
                            : (isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Bug Report",
                        style: GoogleFonts.poppins(
                          color: _selectedTabIndex == 0
                              ? const Color(0xFFEF4444)
                              : (isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        color: _selectedTabIndex == 1
                            ? const Color(0xFF5B60F6)
                            : (isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Feedback",
                        style: GoogleFonts.poppins(
                          color: _selectedTabIndex == 1
                              ? const Color(0xFF5B60F6)
                              : (isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController!,
              children: [
                _buildFormContent(
                  isBugReport: true,
                  isDark: isDark,
                  primaryColor: const Color(0xFFEF4444),
                ),
                _buildFormContent(
                  isBugReport: false,
                  isDark: isDark,
                  primaryColor: const Color(0xFF5B60F6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormContent({
    required bool isBugReport,
    required bool isDark,
    required Color primaryColor,
  }) {
    return GlassContainer(
      padding: const EdgeInsets.all(32),
      borderRadius: 24,
      child: Form(
        key: isBugReport ? _bugFormKey : _feedbackFormKey,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // LEFT COLUMN: Inputs
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel(isBugReport ? "TITLE" : "TITLE"),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _titleController,
                    style: GoogleFonts.poppins(fontSize: 14),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                    decoration: InputDecoration(
                      hintText: isBugReport
                          ? "e.g., Error on Leave Page"
                          : "e.g., Suggestion for Dashboard",
                      hintStyle: GoogleFonts.poppins(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
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
                          color: isDark
                              ? Colors.white10
                              : const Color(0xFFE2E8F0),
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
                  const SizedBox(height: 24),

                  _buildLabel("DESCRIPTION"),
                  const SizedBox(height: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _descController,
                      expands: true,
                      maxLines: null,
                      textAlignVertical: TextAlignVertical.top,
                      style: GoogleFonts.poppins(fontSize: 14),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                      decoration: InputDecoration(
                        hintText: "Describe the issue or feedback in detail...",
                        hintStyle: GoogleFonts.poppins(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                        contentPadding: const EdgeInsets.all(16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark
                                ? Colors.white10
                                : const Color(0xFFE2E8F0),
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
                  ),
                ],
              ),
            ),

            const SizedBox(width: 32),

            // RIGHT COLUMN: Attachments & Submit
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel("SCREENSHOTS (OPTIONAL)"),
                  const SizedBox(height: 8),

                  Expanded(
                    child: InkWell(
                      onTap: _pickFiles,
                      borderRadius: BorderRadius.circular(16),
                      child: DashedContainer(
                        color: primaryColor.withValues(alpha: 0.3),
                        strokeWidth: 2,
                        borderRadius: 16,
                        gap: 6,
                        child: Container(
                          width: double.infinity,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.02)
                                : Colors.white.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.file_upload_outlined,
                                    color: primaryColor,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _attachedFiles.isEmpty
                                      ? "Click to upload images"
                                      : "${_attachedFiles.length} images attached",
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF475569),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "PNG, JPG up to 50MB",
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                                if (_attachedFiles.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: _attachedFiles
                                          .take(4)
                                          .map(
                                            (f) => Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                image: DecorationImage(
                                                  image: FileImage(f),
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitFeedback,
                      style: ElevatedButton.styleFrom(
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
                              "Submit Report",
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: const Color(0xFF64748B),
        letterSpacing: 0.5,
      ),
    );
  }
}
